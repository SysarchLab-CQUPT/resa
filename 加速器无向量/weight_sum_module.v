`timescale 1ns / 1ns
module weight_sum_module #(
    parameter dim = 8, // 设置为常量参数，确保综合支持
    parameter TOP = 0  // 标记是否为顶端 WSM
) (
    input wire clk,
    input wire reset_n,
    // in_sum: 18-bit partial sum input, fixed-point format, range [0, 2^18-1]
    input wire [17:0] in_sum,  // 输入的部分和

    // 将并行 8 路的 18-bit 向量扁平化为 144 bit
    input wire [143:0] in_sums_flat, // 原: input wire [17:0] in_sums[0:7]

    input wire [4:0] in_exp,  // 输入的指数部分

    // control: 3-bit control signal, determines operation mode
    input wire [2:0] control,
    output reg [17:0] out_port,

    // 扁平化输出 8 路，每路 18 bit -> 144 bit
    output wire [143:0] out_ports_flat // 原: output reg [17:0] out_ports[0:7]
);

  // ...existing code...
  reg [17:0] sum_reg;
  reg signed [4:0] exp;
  reg [17:0] c;
  reg signed [4:0] c_exp;

  reg [17:0] w1;
  reg [17:0] w2;
  reg [17:0] buffer[0:dim-1];  // dim 现在为常量参数，综合工具可支持

  reg [31:0] cnt;
  wire ismax = (cnt == (dim - 1));

  reg [$clog2(dim/8)-1:0] cnt_batch;
  wire ismax_batch = (cnt_batch == ($clog2(dim/8)'((dim / 8 - 1)))); // 计算批次数量

  wire [17:0] shifted_sum;
  wire [17:0] shifted_in_sum;
  wire [4:0] max_exp;

  wire [17:0] new_value = (w1 * buffer[cnt] + w2 * in_sum) >>> 8;// 计算新的加权和
  wire [17:0] new_values[0:7];// 并行计算的8个新加权和

  // 内部解包：把扁平输入切片到数组，便于后续使用
  wire [17:0] in_sums[0:7];
  genvar gi;
  generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : UNPACK_IN_SUMS
      assign in_sums[gi] = in_sums_flat[(gi+1)*18-1 -: 18];
    end
  endgenerate

  // 内部寄存器数组用于驱动输出（保留 reg 行为）
  reg [17:0] out_ports_arr [0:7];

  // 把内部寄存器数组打包回扁平输出
  generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : PACK_OUT_PORTS
      assign out_ports_flat[(gi+1)*18-1 -: 18] = out_ports_arr[gi];
    end
  endgenerate

  // 新增函数：有符号数算术右移（保留符号位）
  function signed [17:0] signed_shift_right;
    input signed [17:0] data;
    input [4:0] shift_amount;
    begin
      if (shift_amount == 0) begin
        signed_shift_right = data;  // 不移位直接返回
      end else begin
        signed_shift_right = data >>> shift_amount;  // Verilog原生算术右移
        // 手动处理符号扩展（兼容不支持>>>的仿真器）
        if (data[17]) begin  // 负数
          signed_shift_right = signed_shift_right | (~0 << (18 - shift_amount));
        end
      end
    end
  endfunction


assign shifted_sum = (($signed(exp) < $signed(in_exp)) ? 
        signed_shift_right(sum_reg, in_exp - exp) : sum_reg); // 指数对齐（带符号右移）

assign shifted_in_sum = (($signed(exp) >= $signed(in_exp)) ?
        signed_shift_right(in_sum, exp - in_exp) : in_sum); // 指数对齐（带符号右移）

assign max_exp = ($signed(exp) < $signed(in_exp)) ? in_exp : exp; // 取较大指数

  always @(posedge clk or negedge reset_n) begin
    integer i;
    if (!reset_n) begin
        for (i = 0; i < dim; i = i + 1) begin
            buffer[i] <= 0;
        end
        sum_reg <= 0;
        exp <= 0;
        cnt <= 0;
        cnt_batch <= 0;
        // 初始化输出数组也清零
        for (i = 0; i < 8; i = i + 1) out_ports_arr[i] <= 18'd0;
    end else begin
    if (control == 3'b000) begin // 初始化
      for (i = 0; i < dim; i = i + 1) begin
        buffer[i] <= 0;
      end
      sum_reg <= 0;
      exp <= 0;
      cnt <= 0;
      cnt_batch <= 0;
      // 初始化输出数组也清零
      for (i = 0; i < 8; i = i + 1) out_ports_arr[i] <= 18'd0;
    end else if (control == 3'b001) begin // 计算加权和
      c <= shifted_sum + shifted_in_sum;
      c_exp <= max_exp;
      w1 <= shifted_sum;
      w2 <= shifted_in_sum;
      for (i = 0; i < dim; i = i + 1) begin
        buffer[i] <= buffer[i] >> (c_exp - exp);
      end
    end else if (control == 3'b010) begin 
      if (c != 0 && $signed(c) > -18'h100 && $signed(c) < 18'h100) begin
        w1 <= (({w1, 4'b0} / {{4{c[17]}}, c}) >> 4);
        w2 <= ((18'h100 / {{4{c[17]}}, c}) >> 4);
      end else begin
        w1 <= 0;
        w2 <= 0;
      end
      sum_reg <= c;
      exp <= c_exp;
    end else if (control == 3'b011) begin
      buffer[cnt] <= new_value;
      out_port <= new_value;
      cnt <= cnt + 1;
    end else if (control == 3'b100) begin
      // 并行处理8个输入
      cnt_batch <= cnt_batch + 1;
      for (i = 0; i < 8; i = i + 1) begin
        buffer[cnt_batch * 8 + i] <= new_values[i];
        // 改为驱动内部 reg 数组
        out_ports_arr[i] <= new_values[i];
      end
    end
  end
  end

  generate
    genvar i;
    for (i = 0; i < 8; i = i + 1) begin : parallel_processing
            wire [31:0] idx = cnt_batch * 8 + i;
            assign new_values[i] = (w1 * buffer[idx] + w2 * in_sums[i]) >>> 8;
    end
  endgenerate 
endmodule



`timescale 1ns / 1ns
module PE #(
    parameter TOP_PE = 0,  // 标记是否为顶端 PE
    parameter BOTTOM_PE = 0,  // 标记是否为底端 PE
    parameter MID_PE = 0,  // 标记是否为中间 PE
    parameter LEFT_MOST = 0  //标记是否为最左端PE
) (
    input wire clk,
    input wire reset_n,

    // 数据输入
    input wire [ 8:0] q_in,          // 查询向量输入 (9bit)
    input wire [ 8:0] kv_in,         // 键值向量输入 (9bit)
    input wire [17:0] sum_in,        // 来自同列其他 PE 的输入 (18bit)
    input wire [ 4:0] sum_exp_in,    // 来自同列其他 PE 的指数输入 (5bit)
    input wire [ 8:0] bar_result_to_pe,  // 来自 Bar 的 kv_in (9bit)
    input wire [17:0] bar_sum_to_pe, // 来自 Bar 的 col_sum_in (18bit)

    // 阶段控制
    input wire [1:0] stage_ctrl,  // 阶段控制信号
    input wire [1:0] mode_ctrl,   // 模式控制信号,00为global一个q对多个k, 01为global一个k对多个q, 10为random模式,11为滑动窗口模式
    input wire LUT_enable,  // 查表使能信号

    // 权重控制
    //input wire [1:0] weight_ctrl,  // 暂未使用，保留

    // 垂直方向 sum 传递（行方向）

    // 顶部 PE 的垂直方向信号定义
    // 所有可能的端口都声明在模块头部，由参数控制其实际用途
    input wire top_pulse,  // 来自顶部的脉冲信号（仅TOP_PE或MID_PE有效）
    input wire bottom_pulse,  // 来自底部的脉冲信号（仅BOTTOM_PE或MID_PE有效）
    input wire [17:0] sum_up_in,  // 来自上一行 PE 的 sum（仅TOP_PE或MID_PE有效）
    input wire [17:0] sum_down_in,  // 来自下一行 PE 的 sum（仅BOTTOM_PE或MID_PE有效）
    output wire sum_pulse_out,      // 向下一行或上一行 PE 发送的脉冲信号（仅TOP_PE或BOTTOM_PE有效）


    // 计算结果输出
    output reg [17:0] sum_out,     // 累加和小数部分
    output reg [ 4:0] sum_exp_out, // 累加和指数（暂时固定）
    //output reg [17:0] result_out,   // 最终结果（查表值 / 小数等）

    // 传递数据输出
    output wire [17:0] col_sum_out,  // 当前 PE 的累加和作为列总和候选
    //output wire [17:0] lookup_result_out,
    output reg [8:0] q_out,  // 输出寄存器，传递给下一列 PE
    output reg [8:0] kv_out, // 输出寄存器，传递给下一对角列 PE
    output reg [1:0] stage_ctrl_out // 传递阶段控制信号给下一列 PE
);
  //assign lookup_result_out = acc_reg;
  //assign q_out = q_in;
  // ===== 参数定义 =====
  parameter BITS = 9;
  parameter POINT_WIDE = 4;
  parameter ACC_WIDTH = 18;
  parameter EXP_WIDTH = 5;

  localparam MAX_VAL = 18'sh1FFFF;  // 131071
  localparam MIN_VAL = 18'sh20000;  // -131072

  // ===== 内部寄存器或信号 =====
  reg [ACC_WIDTH-1:0] acc_reg;  // 累加器：q * kv 或查表前数据
  //reg [17:0] sum_reg;           // 累加和寄存器，stage3，4计算
  reg [EXP_WIDTH-1:0] exp_reg;  // 指数（暂时未动态计算，可扩展）
  reg random_flag;  // random 模式标志,为0表示输入为 q,为1表示输入为 k
  reg col_sum_pulse_d;  // 列累加脉冲寄存器
  assign sum_pulse_out = col_sum_pulse_d;  // 顶部或底部 PE 输出脉冲信号
  assign col_sum_out   = acc_reg;
  // 指数对齐相关
  wire [ACC_WIDTH-1:0] shifted_acc;  // 对齐后的累加值
  wire [ACC_WIDTH-1:0] shifted_sum;  // 对齐后的输入 sum


  // ===== LUT 表（查表用）=====
  reg  [     BITS-1:0] lut_k                                   [0:3];  // 斜率 LUT
  reg  [ACC_WIDTH-1:0] lut_b                                   [0:3];  // 截距 LUT

  // 初始化 LUT（固定值，可配置）
  initial begin
    lut_k[0] = 9'd38;  // 示例值
    lut_k[1] = 9'd45;
    lut_k[2] = 9'd53;
    lut_k[3] = 9'd64;

    lut_b[0] = 18'd499;
    lut_b[1] = 18'd481;
    lut_b[2] = 18'd439;
    lut_b[3] = 18'd362;
  end

  // ===== 信号定义 =====

  wire [4:0] integer_bits;
  wire [BITS-1:0] fraction_bits;
  wire [1:0] lut_addr;
  wire [BITS-1:0] k;
  wire [ACC_WIDTH-1:0] b;

  //===== LUT逻辑实现 =====

  wire [ACC_WIDTH-1:0] lut_input_source;

  // 根据模式选择LUT的数据源
  // 示例：当 mode_ctrl 为 '11' 时，使用 bar_sum_to_pe，否则使用 acc_reg
  // 您可以根据您的具体设计修改此处的条件
  assign lut_input_source = (mode_ctrl != 2'b11) ? bar_sum_to_pe : acc_reg;

  assign integer_bits = lut_input_source[15:11];
  assign fraction_bits = {5'b0, lut_input_source[10:7]};
  assign lut_addr = lut_input_source[2*POINT_WIDE+2 : 2*POINT_WIDE+1];
  assign k = lut_k[lut_addr];
  assign b = lut_b[lut_addr];



  // 指数对齐（带符号右移）
assign shifted_acc = (!LEFT_MOST) ? 
    (($signed(exp_reg) < $signed(sum_exp_in)) ? 
        signed_shift_right(acc_reg, sum_exp_in - exp_reg) : acc_reg) 
    : acc_reg;

assign shifted_sum = (!LEFT_MOST) ? 
    (($signed(exp_reg) < $signed(sum_exp_in)) ? 
        sum_in : signed_shift_right(sum_in, exp_reg - sum_exp_in)) 
    : sum_in;
  /*assign exp_reg = (!LEFT_MOST) ? 
        (($signed(exp_reg) < $signed(sum_exp_in)) ? sum_exp_in : exp_reg)
        : reg_max_exp;*/

  // ===== 饱和运算辅助函数 =====
  // 两数饱和加法：对两个有符号18位数求和并饱和到范围 [-131072, 131071]
  function signed [17:0] sat_add2;
    input signed [17:0] a;
    input signed [17:0] b;
    reg signed [18:0] tmp;
    begin
      tmp = a + b;
      if (tmp[18])
        sat_add2 = (tmp[17]) ? 18'sh1FFFF : 18'sh20000;  // overflow: positive->MAX, negative->MIN
      else
        sat_add2 = tmp[17:0];
    end
  endfunction

  // 乘加（MAC）：acc + (x * y) 带饱和
  // x, y 在调用前应是已经带符号扩展到合适位宽（这里用 18 位带符号输入）
  function signed [17:0] mac;
    input signed [17:0] acc; // 当前累加器
    input signed [8:0] x;   // 乘数 a
    input signed [8:0] y;   // 乘数 b
    reg signed [17:0] prod;  // 9x9 = 18 位有符号乘积
    begin
      prod = x * y; // 9-bit * 9-bit = 18-bit signed product
      mac = sat_add2(acc, prod);
      end
  endfunction

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

  // ===== 垂直方向 sum 传递 =====
  /*assign sum_up_out  = sum_reg;
    assign sum_down_out = sum_reg;
    assign col_sum_out  = sum_reg; // 可选：该 PE 的累加和作为列总和候选*/


  // ===== 寄存器更新与阶段逻辑 =====
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      q_out       <= 9'b0;
      kv_out      <= 9'b0;
      acc_reg     <= 18'b0;
      sum_exp_out <= 5'b0;
      sum_out     <= 18'b0;
      random_flag <= 1'b0;
      col_sum_pulse_d <= 1'b0;
      exp_reg     <= 5'b0;
      stage_ctrl_out <= 2'b0;
    end else begin

      case (stage_ctrl)
        2'b00: begin  // Stage 0: q * k 累加
            if (mode_ctrl == 2'b00) begin  // global一个q对多个k
            acc_reg <= mac(acc_reg, $signed(q_in), $signed(bar_result_to_pe));
            q_out   <= q_in;
          end else if (mode_ctrl == 2'b01) begin // global一个k对多个q,此时q_in实际上是k的数据，但需要使用q的传播方式，需要在外部切换“q_in”的数据源
            acc_reg <= mac(acc_reg, $signed(q_in), $signed(bar_result_to_pe));
            q_out   <= q_in;
          end else if (mode_ctrl == 2'b10) begin  // random模式
            if (random_flag == 1'b0) begin  // 输入为 q
              q_out <= bar_result_to_pe;
              random_flag <= 1'b1;  // 切换到 k
            end else begin  // 输入为 k
              acc_reg <= mac(acc_reg, $signed(q_out), $signed(bar_result_to_pe));
              random_flag <= 1'b0;  // 切换到 q
            end
          end else begin  // 滑动窗口模式
            acc_reg <= mac(acc_reg, $signed(q_in), $signed(kv_in));
            q_out   <= q_in;
            kv_out  <= kv_in;
          end
        end

        2'b01: begin  // Stage 1: 垂直累加 (sum_up_in + sum_down_in + acc_reg),查表计算
          //sum_reg <= saturating_add(saturating_add(acc_reg, sum_down_in), sum_up_in);
          if(mode_ctrl != 2'b11) begin //判断为global一个k对多个q或者random模式                  
            if (TOP_PE) begin
              if (top_pulse) begin
                col_sum_pulse_d <= 1'b1;
                acc_reg <= sat_add2(acc_reg, sum_down_in);  // 顶部 PE 接收到脉冲，触发列累加输出
              end else begin
                col_sum_pulse_d <= 1'b0;
              end
            end else if (BOTTOM_PE) begin
              if (bottom_pulse) begin
                col_sum_pulse_d <= 1'b1;  // 底部 PE 接收到脉冲，触发列累加输出
                acc_reg <= sat_add2(acc_reg, sum_up_in);
              end else begin
                col_sum_pulse_d <= 1'b0;
              end
            end else begin  // MID_PE
              if (top_pulse) begin
                acc_reg <= sat_add2(acc_reg, sum_up_in);  // 中间 PE 接收到顶部脉冲，累加上方 sum
              end else if (bottom_pulse) begin
                acc_reg <= sat_add2(acc_reg, sum_down_in);  // 中间 PE 接收到底部脉冲，累加下方 sum
              end
            end
            if (LUT_enable) begin
              // 查表计算: acc = b + k * fraction_bits
              acc_reg <= mac($signed(b), $signed(k), $signed(fraction_bits));  // 查表计算
              exp_reg <= integer_bits;  // 整数部分作为指数
            end
          end else begin // 滑动窗口模式
            // 使用饱和加法：b + k * fraction_bits
            acc_reg <= mac($signed(b), $signed(k), $signed(fraction_bits));
          end
        end

        2'b10: begin  // Stage 2: S值传递
          if (!LEFT_MOST) begin
            // 指数对齐（带符号右移）
            if ($signed(exp_reg) < $signed(sum_exp_in)) begin
              sum_exp_out <= sum_exp_in;
            end else begin
              sum_exp_out <= exp_reg;
            end
          end
          // 饱和加法
          sum_out <= sat_add2(shifted_acc, shifted_sum);
        end


        2'b11: begin  // Stage 3: v * s 计算以求和
          if (!LEFT_MOST) begin
            // 指数对齐（带符号右移）
            if ($signed(exp_reg) < $signed(sum_exp_in)) begin
              sum_exp_out <= sum_exp_in;
            end else begin
              sum_exp_out <= exp_reg;
            end
          end
          if(mode_ctrl == 2'b00 || mode_ctrl == 2'b10) begin // global一个q对多个k或random模式
      sum_out <= mac(shifted_sum, $signed(bar_result_to_pe), $signed(shifted_acc));
            //kv_out <= kv_in;
          end else if (mode_ctrl == 2'b01) begin // global一个k对多个q,此时q_in实际上是v的数据，但需要使用q的传播方式，需要在外部切换“kv_in”的数据源
            sum_out <= mac(shifted_sum, $signed(q_in), $signed(shifted_acc));
            //kv_out <= kv_in;
          end else begin  // 滑动窗口模式
            sum_out <= mac(shifted_sum, $signed(kv_in), $signed(shifted_acc));
            kv_out  <= kv_in;
          end
        end

        default: begin
          acc_reg <= 18'b0;
        end
      endcase
    end
  end


endmodule

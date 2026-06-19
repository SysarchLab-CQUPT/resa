`timescale 1ns / 1ns
module PEArray (
        input wire clk,
    input wire reset_n,

    // 模式控制
    input wire [1:0] mode_ctrl,

    // 外部接口已扁平化，内部再 unpack 回数组
    input  wire [ 71:0] q_in_flat,      // 8 * 9 = 72 bits
    input  wire [134:0] kv_in_flat,     // 15 * 9 = 135 bits
    input  wire [575:0] q_in_sp_flat,   // 64 * 9 = 576 bits
    input  wire [575:0] kv_in_sp_flat,  // 64 * 9 = 576 bits

    input  wire        sum_pulse,       // stage2 完成 sum 计算的脉冲
    input  wire [ 1:0] stage_ctrl,      // 当前整体 stage 控制信号

    input  wire [23:0] weight_ctrl_flat, // 8 * 3 = 24 bits

    // 扁平化输出
    output wire [143:0] result_out_flat,   // 8 * 18 = 144 bits
    output wire [1151:0] results_out_flat  // 64 * 18 = 1152 bits
);
  //reg [1:0] stage_ctrl[0:7];  // 每列的当前 stage (2-bit)
  // Bar 输出给 col=0 的每个 PE 的 kv_in 数据
  wire [17:0] bar_result_to_pe[0:63];     // 原 [0:7][0:7] -> [0:63]
  wire [17:0] bar_results_to_WSM[0:63];   // 原 [0:7][0:7] -> [0:63]
  wire [4:0] bar_result_exp_to_WSM[0:7];  // bar_result_exp_to_WSM[col=0~7]
  // ===========================
  // 状态控制信号
  // ===========================
  //wire [1:0] mode_ctrl;  // 模式控制
  // ===========================
  // PE 和相关信号
  // ===========================
  wire [17:0] pe_sum_out[0:63];          // 原 [0:7][0:7] -> [0:63]
  wire [4:0] pe_sum_exp_out[0:63];        // 原 [0:7][0:7] -> [0:63]
  //wire [17:0] pe_result_out[0:7][0:7];
  wire [17:0] col_sum_out[0:63];
  wire [17:0] col_sum_to_bar[0:7];
  //wire [4:0] col_sum_exp_to_bar;
  wire pulse_out[0:63];
  wire LUT_enable_out[0:7];
  wire [1:0] stage_ctrl_out[0:63];

  wire [8:0] pe_q_out[0:63];
  wire [8:0] pe_kv_out[0:63];
 // 在模块内部恢复为与原来一致的数组接口（便于复用原有代码）
    // q_in[0..7]  each 9 bits
    wire [8:0] q_in [0:7];
    // kv_in[0..14] each 9 bits
    wire [8:0] kv_in [0:14];
    // flat-sp arrays 64 entries
    wire [8:0] q_in_sp [0:63];
    wire [8:0] kv_in_sp [0:63];
    // weight_ctrl 8 entries of 3 bits
    wire [2:0] weight_ctrl [0:7];

    // unpack q_in_flat -> q_in
    genvar gi;
    generate
      for (gi = 0; gi < 8; gi = gi + 1) begin : UNPACK_Q_IN
        assign q_in[gi] = q_in_flat[(gi+1)*9-1 -: 9];
      end
      // kv_in: 15 entries
      for (gi = 0; gi < 15; gi = gi + 1) begin : UNPACK_KV_IN
        assign kv_in[gi] = kv_in_flat[(gi+1)*9-1 -: 9];
      end
      // q_in_sp / kv_in_sp: 64 entries
      for (gi = 0; gi < 64; gi = gi + 1) begin : UNPACK_SP
        assign q_in_sp[gi] = q_in_sp_flat[(gi+1)*9-1 -: 9];
        assign kv_in_sp[gi] = kv_in_sp_flat[(gi+1)*9-1 -: 9];
      end
      // weight_ctrl: 8 * 3 bits
      for (gi = 0; gi < 8; gi = gi + 1) begin : UNPACK_WEIGHT
        assign weight_ctrl[gi] = weight_ctrl_flat[(gi+1)*3-1 -: 3];
      end
    endgenerate

    // 为兼容原代码，声明内部用于驱动输出的数组
    wire [17:0] result_out [0:7];
    wire [17:0] results_out [0:63];

    // 把内部数组打包回扁平输出
    generate
      for (gi = 0; gi < 8; gi = gi + 1) begin : PACK_RESULT_OUT
        assign result_out_flat[(gi+1)*18-1 -: 18] = result_out[gi];
      end
      for (gi = 0; gi < 64; gi = gi + 1) begin : PACK_RESULTS_OUT
        assign results_out_flat[(gi+1)*18-1 -: 18] = results_out[gi];
      end
    endgenerate
 

  // ===========================
  // PE 实例化：控制 q 传递 & 收集 lookup_result_out
  // ===========================
  generate
    for (genvar col = 0; col < 8; col++) begin : gen_cols
      wire [17:0] sum_up_in[0:3];  // from row-1 (上方 PE)
      wire top_pulse[0:3];
      wire [17:0] sum_down_in[0:4];  // from row+1 (下方 PE)
      wire bottom_pulse[0:4];
      for (genvar row = 0; row < 8; row++) begin : gen_rows
        // -------------------------------
        // 1. 构建垂直方向的 sum 传递
        // -------------------------------

        if (row >= 4) begin :gen_bottom // sum_down_in: from row+1 (下方 PE)
          if (row == 7) begin
            assign sum_down_in[row-3]  = 18'b0;
            assign bottom_pulse[row-3] = sum_pulse;  // row=7 没有下方 PE
          end else begin
            assign sum_down_in[row-3]  = col_sum_out[(row+1)*8 + col];// 来自下方 PE 的 sum_down_in
            assign bottom_pulse[row-3] = pulse_out[(row+1)*8 + col];  // 来自下方 PE 的脉冲
          end
          PE #(
              .TOP_PE(0),
              .BOTTOM_PE(1),
              .MID_PE(0),
              .LEFT_MOST( (col == 0) ? 1 : 0)  // 实例化底端 PE，并根据列号设置 LEFT_MOST
          ) pe_inst_bottom (
              .clk(clk),
              .reset_n(reset_n),
              .q_in(actual_q_in),
              .kv_in(actual_kv_in),
              .mode_ctrl(mode_ctrl),
              .sum_in(col == 0 ? 18'b0 : pe_sum_out[row*8 + col-1]), // 左侧 PE 的 sum_out 作为输入
              .sum_exp_in(col == 0 ? 5'b0 : pe_sum_exp_out[row*8 + col-1]), // 左侧 PE 的 sum_exp_out 作为输入
              .bar_result_to_pe(bar_result_to_pe[col*8 + row]),  // 来自 Bar 的 kv_in
              .bar_sum_to_pe(bar_result_to_pe[col*8 + row]),  // 来自 Bar 的 col_sum
              .top_pulse(1'b0),// 不需要来自上方 PE 的脉冲
              .bottom_pulse(bottom_pulse[row-3]),  // 来自下方 PE 的脉冲
              .sum_up_in(18'b0),// 不需要来自上方 PE 的 sum
              .sum_down_in(sum_down_in[row-3]),  // 来自下方 PE 的 sum_down_in
              .LUT_enable(LUT_enable_out[col]),  // 查表使能信号
              .sum_pulse_out(pulse_out[row*8 + col]), // 向上方 PE 发送脉冲
              .stage_ctrl(col == 0 ? stage_ctrl : stage_ctrl_out[row*8 + col-1]), // 当前阶段控制信号，col=0 时来自外部，其余列来自左侧 PE
              //.weight_ctrl(weight_ctrl),
              .sum_out(pe_sum_out[row*8 + col]),
              .sum_exp_out(pe_sum_exp_out[row*8 + col]),
              //.result_out(pe_result_out[row][col]),
              .col_sum_out(col_sum_out[row*8 + col]),  // 输出到列部分和网络
              .q_out(pe_q_out[row*8 + col]),  // 输出给下一列
              .kv_out(pe_kv_out[row*8 + col]),  // 输出给下一列
              .stage_ctrl_out(stage_ctrl_out[row*8 + col]) // 输出当前阶段控制信号给下一列
              //.lookup_result_out(pe_lookup_result_out[row][col])  // 查表结果输出
          );
        end else if (row <= 3) begin : gen_top // sum_up_in: from row+1 (上方 PE)
          if (row == 0) begin
            assign sum_up_in[row] = 18'b0;
            assign top_pulse[row] = sum_pulse;  // row=0 没有上方 PE
          end else begin
            assign sum_up_in[row] = col_sum_out[(row-1)*8 + col];  // 来自上方 PE 的 sum_up_in
            assign top_pulse[row] = pulse_out[(row-1)*8 + col];  // 来自上方 PE 的脉冲
          end
          PE #(
              .TOP_PE(1),
              .BOTTOM_PE(0),
              .MID_PE(0),
              .LEFT_MOST( (col == 0) ? 1 : 0)  // 实例化顶端 PE，并根据列号设置 LEFT_MOST
          ) pe_inst_top (
              .clk(clk),
              .reset_n(reset_n),
              .q_in(actual_q_in),
              .kv_in(actual_kv_in),
              .mode_ctrl(mode_ctrl),
              .sum_in(col == 0 ? 18'b0 : pe_sum_out[row*8 + (col-1)]),
              .sum_exp_in(col == 0 ? 5'b0 : pe_sum_exp_out[row*8 + (col-1)]),
              .bar_result_to_pe(bar_result_to_pe[col*8 + row]),  // 来自 Bar 的 kv_in
              .bar_sum_to_pe(bar_result_to_pe[col*8 + row]),  // 来自 Bar 的 col_sum
              .top_pulse(top_pulse[row]),
              .bottom_pulse(1'b0),
              .sum_up_in(sum_up_in[row]),
              .sum_down_in(18'b0),
              .stage_ctrl(col == 0 ? stage_ctrl : stage_ctrl_out[row*8 + (col-1)]),
              .LUT_enable(LUT_enable_out[col]),
              .sum_out(pe_sum_out[row*8 + col]),
              .sum_exp_out(pe_sum_exp_out[row*8 + col]),
              .col_sum_out(col_sum_out[row*8 + col]),
              .q_out(pe_q_out[row*8 + col]),
              .kv_out(pe_kv_out[row*8 + col]),
              .stage_ctrl_out(stage_ctrl_out[row*8 + col]),
              .sum_pulse_out(pulse_out[row*8 + col])
          );
        end else begin : gen_mid  // 中间 PE
          assign sum_up_in[row-4] = col_sum_out[(row-1)*8 + col];  // 来自上方
          assign sum_down_in[row-3] = col_sum_out[(row+1)*8 + col];  // 来自下方
          assign top_pulse[row-4] = pulse_out[(row-1)*8 + col];
          assign bottom_pulse[row-3] = pulse_out[(row+1)*8 + col];
          PE #(
              .TOP_PE(0),
              .BOTTOM_PE(0),
              .MID_PE(1),
              .LEFT_MOST( (col == 0) ? 1 : 0)  // 实例化中间 PE，并根据列号设置 LEFT_MOST
          ) pe_inst_mid (
              .clk(clk),
              .reset_n(reset_n),
              .q_in(actual_q_in),
              .kv_in(actual_kv_in),
              .mode_ctrl(mode_ctrl),
              .sum_in(col == 0 ? 18'b0 : pe_sum_out[row*8 + (col-1)]),
              .sum_exp_in(col == 0 ? 5'b0 : pe_sum_exp_out[row*8 + (col-1)]),
              .bar_result_to_pe(bar_result_to_pe[col*8 + row]),  // 来自 Bar 的 kv_in
              .bar_sum_to_pe(bar_result_to_pe[col*8 + row]),  // 来自 Bar 的 col_sum
              .top_pulse(top_pulse[row-4]),
              .bottom_pulse(bottom_pulse[row-3]),
              .sum_up_in(sum_up_in[row-4]),
              .sum_down_in(sum_down_in[row-3]),
              .stage_ctrl(col == 0 ? stage_ctrl : stage_ctrl_out[row*8 + (col-1)]),
              .LUT_enable(LUT_enable_out[col]),
              .sum_out(pe_sum_out[row*8 + col]),
              .sum_exp_out(pe_sum_exp_out[row*8 + col]),
              .col_sum_out(col_sum_to_bar[col]),
              .q_out(pe_q_out[row*8 + col]),
              .kv_out(pe_kv_out[row*8 + col]),
              .stage_ctrl_out(stage_ctrl_out[row*8 + col]),
              .sum_pulse_out(pulse_out[row*8 + col])
          );
        end

        // 🟡 q_in 控制：col == 0 时为输入 q_in[row]，否则来自左边 PE 的 q_out

        wire [8:0] actual_q_in;
        if (col == 0) begin
          assign actual_q_in = q_in[row];
        end else begin
          assign actual_q_in = pe_q_out[row*8 + col-1];
        end

        //  kv_in 控制：col == 0 或 row == 0 时为输入 kv_in[row]，否则来自左上角 PE 的 kv_out
        wire [8:0] actual_kv_in;
        if (row == 0) begin
          assign actual_kv_in = kv_in[7-col];  // 对角线传递
        end else if (col == 0) begin
          assign actual_kv_in = kv_in[7+row];  // 对角线传递
        end else begin
          assign actual_kv_in = pe_kv_out[(row-1)*8 + col-1];  // 来自左上角 PE 的 kv_out
        end

        // -------------------------------
        // 3. 导出当前 PE 的 sum_up / sum_down 输出
        // -------------------------------
        //assign pe_sum_up_out[row][col]   = pe_inst.sum_up_out;
        //assign pe_sum_down_out[row][col] = pe_inst.sum_down_out;
      end
    end
  endgenerate

  // ===========================
  // Bar 实例化 & 数据流动控制
  // ===========================

  generate
    for (genvar col = 0; col < 8; col++) begin : gen_bars
      // 2. 收集普通 sum_exp（某一个 PE 的 sum_exp_out）（只需收集一个，因为都相同）
      wire [4:0] col_sum_exp_to_bar;
      assign col_sum_exp_to_bar = pe_sum_exp_out[3*8 + col]; // 选择 row=3 的 sum_exp 作为该列汇总

      // 3. 选择 row=3 的 sum，在 stage1 时作为 leader sum 上传
      wire [143:0] col_sums;
      for (genvar row = 0; row < 8; row++) begin
        assign col_sums[(row+1)*18-1 -: 18] = pe_sum_out[row*8 + col]; // 收集某一列的PE的sum_out
      end
      
      //  q_in 和 kv_in 的切片
      wire [71:0] q_in_slice ;
      wire [71:0] kv_in_slice ;
      for (genvar row = 0; row < 8; row++) begin
        assign q_in_slice[(row+1)*9-1 -: 9] = q_in_sp[col*8 + row];
        assign kv_in_slice[(row+1)*9-1 -: 9] = kv_in_sp[col*8 + row];
      end

      wire [143:0] bar_result_to_pe_flat;
      wire [143:0] final_int_out_flat;
      wire LUT_enable_flat;
      for(genvar row =0; row <8; row = row +1) begin
        assign bar_result_to_pe[col*8 + row] = bar_result_to_pe_flat[(row+1)*18-1 -: 18];
        assign bar_results_to_WSM[col*8 + row] = final_int_out_flat[(row+1)*18-1 -: 18];
      end


      Bar bar_inst (
          .clk(clk),
          .reset_n(reset_n),
          .stage_ctrl(col == 0 ? stage_ctrl : stage_ctrl_out[0 + col-1]), // 当前阶段控制信号，col=0 时来自外部，其余列来自左侧 PE
          .mode_ctrl(mode_ctrl),
          .q_in_flat(q_in_slice),
          .kv_in_flat(kv_in_slice),
          .col_sum_in_flat(col_sums),  // 来自该列 PE 的 sum_out
          .col_sum_exp_in(col_sum_exp_to_bar),
          .result_out_flat(bar_result_to_pe_flat),  // 输出给 PEArray
          .LUT_enable(LUT_enable_out[col]),  // 查表使能信号
          //.weight_ctrl(weight_ctrl),
          .final_int_out_flat(final_int_out_flat),  // 最终结果的小数部分
          .final_exp_out(bar_result_exp_to_WSM[col]),  // 最终结果的指数部分
          .sum_leader(col_sum_to_bar[col])// 来自 PEArray，作为该列汇总 sum
      );
    end
  endgenerate

  // ===========================
  // WeightedSumModule 实例化
  // ===========================
  generate
    for (genvar row = 0; row < 8; row++) begin : gen_weight_sum_modules
      wire [17:0] actual_sum_in;
      wire [17:0] actual_sums_in[0:7];
      wire [ 4:0] actual_sum_exp_in;
      wire [17:0] last_col[0:7];
      for (genvar c = 0; c < 8; c++) begin
        assign last_col[c] = pe_sum_out[c*8 + 7];  // 收集最后一列的 sum_out
      end
      // 动态选择逻辑，mode_ctrl == 2'b00 时仅 row == 0 有效
      assign actual_sum_in = (mode_ctrl == 2'b00 && row != 0) ? 18'sd0 :
                            (mode_ctrl[0] == mode_ctrl[1]) ? pe_sum_out[row*8 + 7] : bar_results_to_WSM[row*8 + 0];
      for (genvar i = 0; i < 8; i = i + 1) begin : assign_actual_sums_in
      	assign actual_sums_in[i] = (mode_ctrl == 2'b00 && row != 0) ? 18'b0 :
                                (mode_ctrl == 2'b00 || row == 0) ? last_col[i] :
                                bar_results_to_WSM[row*8 + i];
    	end  // 展平 slice
      assign actual_sum_exp_in = (mode_ctrl == 2'b00 && row != 0) ? 5'sd0 :
                                (mode_ctrl[0] == mode_ctrl[1]) ? pe_sum_exp_out[row*8 + 7] : bar_result_exp_to_WSM[row];
      wire [143:0]in_sums_flat;
      wire [143:0]out_ports_flat;
      for(genvar c =0; c <8; c = c +1) begin
        assign in_sums_flat[(c+1)*18-1 -:18] = actual_sums_in[c];
        assign results_out[row*8 + c] = out_ports_flat[(c+1)*18-1 -:18];
      end
      weight_sum_module #(
          .dim(64),// 单头维度
          .TOP( (row == 0) ? 1 : 0)  // 标记是否为顶端 WSM
      ) weight_sum_module_inst (
          .clk     (clk),
          .reset_n (reset_n),
          .control (weight_ctrl[row]),           // 来自对应 PE 的 stage 控制信号
          .in_sum  (actual_sum_in),         // 来自对应 PE 行的 sum_out
          .in_sums_flat (in_sums_flat),   // 来自对应 PE 的所有 sum_out
          .in_exp  (actual_sum_exp_in),     // 来自对应 PE 行的 sum_exp_out
          .out_port(result_out[row]),  //
          .out_ports_flat(out_ports_flat)  // 输出给外部
      );
    end
  endgenerate


endmodule

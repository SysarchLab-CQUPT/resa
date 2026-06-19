`timescale 1ns / 1ns
module Bar (
    input  wire         clk,                // 时钟信号
    input  wire         reset_n,            // 异步复位（低有效）
    input  wire [1:0]   stage_ctrl,
    input  wire [1:0]   mode_ctrl,

    // 扁平化端口：8 * 9 = 72 位
    input  wire [71:0]  q_in_flat,
    input  wire [71:0]  kv_in_flat,

    // Stage2输入扁平化：8 * 18 = 144 位
    input  wire [143:0] col_sum_in_flat,
    input  wire [4:0]   col_sum_exp_in,

    // 扁平化输出
    output wire [143:0] result_out_flat,     // 8 * 18
    output reg  LUT_enable,
    output wire [143:0] final_int_out_flat,  // 8 * 18
    output reg  [4:0]   final_exp_out,

    input  wire [17:0]  sum_leader
);

    // 在模块内部恢复数组，便于原有逻辑
    wire signed [8:0] q_in_arr [0:7];
    wire signed [8:0] kv_in_arr [0:7];
    wire       [17:0] col_sum_in_arr [0:7];

    genvar gi;
    generate
        for (gi = 0; gi < 8; gi = gi + 1) begin : UNPACK
            assign q_in_arr[gi]      = q_in_flat[(gi+1)*9-1 -: 9];
            assign kv_in_arr[gi]     = kv_in_flat[(gi+1)*9-1 -: 9];
            assign col_sum_in_arr[gi]= col_sum_in_flat[(gi+1)*18-1 -: 18];
        end
    endgenerate

    // 内部寄存器数组（原来的行为）
    reg [17:0] result_out_arr [0:7];
    reg [17:0] final_int_out_arr [0:7];
    generate
        for (gi = 0; gi < 8; gi = gi + 1) begin : PACK
            // 每个 slice 连续赋值到输出 wire 的对应位
            assign result_out_flat[(gi+1)*18-1 -: 18] = result_out_arr[gi];
            assign final_int_out_flat[(gi+1)*18-1 -: 18] = final_int_out_arr[gi];
        end
    endgenerate
    reg [2:0] stage2_wait_cnt;
    reg cache_select;

    integer i;
    // 时序逻辑：与原代码一致，但使用内部数组
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                result_out_arr[i] <= 18'b0;
                final_int_out_arr[i] <= 18'b0;    
            end
            LUT_enable <= 1'b0;
            final_exp_out <= 5'b0;
            stage2_wait_cnt <= 3'b0;
            cache_select <= 1'b0;
        end else if (stage_ctrl == 2'b00) begin
            for (i = 0; i < 8; i = i + 1) begin
                if (mode_ctrl == 2'b00) begin
                    result_out_arr[i] <= {{9{kv_in_arr[i][8]}}, kv_in_arr[i]};
                end else if (mode_ctrl == 2'b01) begin
                    result_out_arr[i] <= {{9{q_in_arr[i][8]}}, q_in_arr[i]};
                end else if (mode_ctrl == 2'b10) begin
                    if (cache_select == 1'b0) begin
                        result_out_arr[i] <= {{9{q_in_arr[i][8]}}, q_in_arr[i]};
                        cache_select <= ~cache_select;
                    end else begin
                        result_out_arr[i] <= {{9{kv_in_arr[i][8]}}, kv_in_arr[i]};
                        cache_select <= ~cache_select;
                    end
                end else begin
                    result_out_arr[i] <= 18'b0;
                end
            end
        end else if (stage_ctrl == 2'b01) begin
            if (stage2_wait_cnt < 3'd5) begin
                stage2_wait_cnt <= stage2_wait_cnt + 1'b1;
            end else if(stage2_wait_cnt == 3'd5)begin
                for (i = 0; i < 8; i = i + 1) begin
                    result_out_arr[i] <= sum_leader; 
                end
                LUT_enable <= 1'b1;
                stage2_wait_cnt <= stage2_wait_cnt + 1'b1;
            end else begin
                LUT_enable <= 1'b0;
            end
        end else if (stage_ctrl == 2'b10) begin
            if (mode_ctrl == 2'b01 || mode_ctrl == 2'b10) begin
                final_int_out_arr[0] <= col_sum_in_arr[0];
                final_exp_out <= col_sum_exp_in;
            end
            if (mode_ctrl == 2'b10) begin
                for (i = 0; i < 8; i = i + 1) begin
                    result_out_arr[i] <= {{9{kv_in_arr[i][8]}}, kv_in_arr[i]};
                end
            end
        end else if (stage_ctrl == 2'b11) begin
            if (mode_ctrl == 2'b01 || mode_ctrl == 2'b10) begin
                for (i = 0; i < 8; i = i + 1) begin
                    final_int_out_arr[i] <= col_sum_in_arr[i];
                end
            end
            if (mode_ctrl == 2'b00 || mode_ctrl == 2'b10) begin
                for (i = 0; i < 8; i = i + 1) begin
                    result_out_arr[i] <= {{9{kv_in_arr[i][8]}}, kv_in_arr[i]};
                end
            end
        end
    end


endmodule

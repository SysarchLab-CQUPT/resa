`timescale 1ns / 1ns
module tb_PEArray;
  // 信号声明
  reg clk = 0;
  reg reset_n = 0;
  reg [1:0] mode_ctrl;
  reg [1:0] stage_ctrl;
  reg sum_pulse;
  reg [2:0] weight_ctrl [0:7];
  // 扁平化输入总线
  reg signed [71:0]  q_in_flat;     // 8 * 9 = 72 bits
  reg signed [134:0] kv_in_flat;    // 15 * 9 = 135 bits
  reg signed [575:0] q_in_sp_flat;  // 64 * 9 = 576 bits
  reg signed [575:0] kv_in_sp_flat; // 64 * 9 = 576 bits
  // 扁平化输出总线（由 DUT 驱动）
  wire [143:0] result_out_flat;     // 8 * 18 = 144 bits
  wire [1151:0] results_out_flat;   // 64 * 18 = 1152 bits

  // 实例化 PEArray
  PEArray dut (
      .clk(clk),
      .reset_n(reset_n),
      .mode_ctrl(mode_ctrl),
      .q_in_flat(q_in_flat),
      .kv_in_flat(kv_in_flat),
      .q_in_sp_flat(q_in_sp_flat),
      .kv_in_sp_flat(kv_in_sp_flat),
      .sum_pulse(sum_pulse),
      .stage_ctrl(stage_ctrl),
      .weight_ctrl_flat({
        weight_ctrl[7],
        weight_ctrl[6],
        weight_ctrl[5],
        weight_ctrl[4],
        weight_ctrl[3],
        weight_ctrl[2],
        weight_ctrl[1],
        weight_ctrl[0]
      }),  // pack array -> flat (MSB first)
      .result_out_flat(result_out_flat),
      .results_out_flat(results_out_flat)
  );

  // 时钟生成：1GHz (1ns 周期)
  always #1 clk = ~clk;
  always @(clk) begin
    $display("%0t clk=%b",$time, clk);
  end
  // 初始化输入
  integer i, j, r, mode_instance;
  initial begin
    // 初始化 VCD 文件，用于动态功耗分析
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_PEArray);

    // 复位
    clk = 0;
    reset_n = 0;
    sum_pulse = 0;
    mode_ctrl = 2'b00;
    stage_ctrl = 2'b00;
    // 清零输入信号 
    // q_in_flat / q_in_sp_flat / kv_in_sp_flat
    for (i = 0; i < 8; i = i + 1) begin
      q_in_flat[(i+1)*9-1-:9] = 0;
      for (j = 0; j < 8; j = j + 1) begin
        q_in_sp_flat[(i*8+j+1)*9-1-:9]  = 0;
        kv_in_sp_flat[(i*8+j+1)*9-1-:9] = 0;
      end
    end
    // kv_in_flat (15 entries)
    for (i = 0; i < 15; i = i + 1) begin
      kv_in_flat[(i+1)*9-1-:9] = 0;
    end

    #2 reset_n = 1;  // 复位后保持高电平

    // 模拟 Transformer qkv 值（使用简单随机生成，模拟 Gaussian 分布，缩放到 9-bit 有符号范围 -256 ~ 255）
    // 这里使用工具生成的样本作为起点，然后随机化
    // q_in_flat / q_in_sp_flat / kv_in_sp_flat
    for (i = 0; i < 8; i = i + 1) begin
      r = $random;
      q_in_flat[(i+1)*9-1-:9] = r[8:0];
      for (j = 0; j < 8; j = j + 1) begin
        r = $random;
        q_in_sp_flat[(i*8+j+1)*9-1-:9] = r[8:0];
        r = $random;
        kv_in_sp_flat[(i*8+j+1)*9-1-:9] = r[8:0];
      end
    end
    // kv_in_flat (15 entries)
    for (i = 0; i < 15; i = i + 1) begin
      r = $random;
      kv_in_flat[(i+1)*9-1-:9] = r[8:0];
    end


    // 测试全局 mode 00 (一个 q 对多个 k)，模拟 4 个实例 (代表 32/8)
    mode_ctrl = 2'b00;
    for (i = 0; i < 8; i = i + 1)
    weight_ctrl[i] = 3'b000;  // 根据模式设置 weight_ctrl (假设 00)
    for (mode_instance = 0; mode_instance < 4; mode_instance = mode_instance + 1) begin
      randomize_inputs();  // 随机化输入模拟新块
      run_stages();
    end

    // 测试全局 mode 01 (一个 k 对多个 q)，模拟 4 个实例
    mode_ctrl = 2'b01;
    for (i = 0; i < 8; i = i + 1) weight_ctrl[i] = 3'b000;  // 假设 01
    for (mode_instance = 0; mode_instance < 4; mode_instance = mode_instance + 1) begin
      randomize_inputs();
      run_stages();
    end

    // 测试随机 mode 10，模拟 4 个实例 (代表 32/8)
    mode_ctrl = 2'b10;
    for (i = 0; i < 8; i = i + 1) weight_ctrl[i] = 3'b000;  // 假设 10
    for (mode_instance = 0; mode_instance < 4; mode_instance = mode_instance + 1) begin
      randomize_inputs();
      run_stages();
    end

    // 测试滑动窗口 mode 11，大小 64 (模拟窗口滚动)，模拟 4 个实例
    mode_ctrl = 2'b11;
    for (i = 0; i < 8; i = i + 1) weight_ctrl[i] = 3'b000;  // 假设 11
    for (mode_instance = 0; mode_instance < 4; mode_instance = mode_instance + 1) begin
      randomize_inputs();  // 模拟窗口数据
      run_stages();
    end

    #10 $finish;  // 结束仿真
  end

  // 任务：随机化输入，模拟 Transformer qkv
  task randomize_inputs;
    integer i, j;
    integer r;
    begin

      // q_in_flat / q_in_sp_flat / kv_in_sp_flat
      for (i = 0; i < 8; i = i + 1) begin
        r = $random;
        q_in_flat[(i+1)*9-1-:9] = r[8:0];
        for (j = 0; j < 8; j = j + 1) begin
          r = $random;
          q_in_sp_flat[(i*8+j+1)*9-1-:9] = r[8:0];
          r = $random;
          kv_in_sp_flat[(i*8+j+1)*9-1-:9] = r[8:0];
        end
      end
      // kv_in_flat (15 entries)
      for (i = 0; i < 15; i = i + 1) begin
        r = $random;
        kv_in_flat[(i+1)*9-1-:9] = r[8:0];
      end
    end
  endtask

  // 任务：运行所有阶段
  task run_stages;
    integer stage0_cycles, stage1_cycles, stage2_cycles, stage3_cycles;
    integer stage3_repeat;
    integer cnt;  // 新增计数器，用于模拟 repeat
    begin
      // 根据 mode_ctrl 设置每个 stage 的周期数（不变）
      if (mode_ctrl == 2'b00 || mode_ctrl == 2'b01) begin
        stage0_cycles = 8;
        stage1_cycles = 7;
        stage2_cycles = 1;
        stage3_cycles = 8;
      end else if (mode_ctrl == 2'b10) begin
        stage0_cycles = 16;
        stage1_cycles = 7;
        stage2_cycles = 1;
        stage3_cycles = 16;
      end else if (mode_ctrl == 2'b11) begin
        stage0_cycles = 64;
        stage1_cycles = 1;
        stage2_cycles = 1;
        stage3_cycles = 64;
      end else begin
        stage0_cycles = 64;
        stage1_cycles = 7;
        stage2_cycles = 1;
        stage3_cycles = 64;
        $display("Warning: Invalid mode_ctrl = %b, using default cycles.", mode_ctrl);
      end

      stage3_repeat = stage3_cycles - 3;
      if (stage3_repeat < 0) begin
        $display("Error: stage3_cycles too small (%d), setting repeat to 0.", stage3_cycles);
        stage3_repeat = 0;
      end

      // Stage 0: 使用 for 循环 + @(posedge clk)
      stage_ctrl = 2'b00;
      for (cnt = 0; cnt < stage0_cycles; cnt = cnt + 1) begin
        @(posedge clk);
      end

      // Stage 1
      stage_ctrl = 2'b01;
      if (mode_ctrl != 2'b11) begin
        sum_pulse = 1;
        @(posedge clk);
        sum_pulse = 0;
        for (cnt = 1; cnt < stage1_cycles; cnt = cnt + 1) begin  // 从1开始，已用一个@
          @(posedge clk);
        end
      end else begin
        for (cnt = 0; cnt < stage1_cycles; cnt = cnt + 1) begin
          @(posedge clk);
        end
      end

      // Stage 2
      stage_ctrl = 2'b10;
      for (cnt = 0; cnt < stage2_cycles; cnt = cnt + 1) begin
        @(posedge clk);
      end

      // Stage 3
      stage_ctrl = 2'b11;
      for (i = 0; i < 8; i = i + 1) weight_ctrl[i] = 3'b001;
      @(posedge clk);  // 第一个变化
      for (i = 0; i < 8; i = i + 1) weight_ctrl[i] = 3'b010;
      @(posedge clk);  // 第二个
      for (i = 0; i < 8; i = i + 1) weight_ctrl[i] = (mode_ctrl == 2'b11) ? 3'b011 : 3'b100;
      @(posedge clk);  // 第三个
      for (cnt = 0; cnt < stage3_repeat; cnt = cnt + 1) begin
        @(posedge clk);
      end
    end
  endtask
endmodule

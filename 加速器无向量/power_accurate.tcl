# 基于门级仿真VCD的精确功耗分析脚本

# 1. 读入所有必要的库和设计文件
read_lef ./NangateOpenCellLibrary.tech.lef
read_lef ./NangateOpenCellLibrary.macro.lef
read_liberty ./NangateOpenCellLibrary_typical.lib
read_verilog ./6_final.v
link_design PEArray

# 2. 定义时钟
create_clock -name clk -period 10.0 [get_ports clk]

# 3. 读取VCD文件，指定正确的scope：dut
puts "Info: 正在从VCD文件 (scope: dut) 读取信号活动..."
read_vcd -scope dut ./dump.vcd

# 4. 报告功耗
puts "\n========================================="
puts "基于门级仿真的精确功耗报告"
puts "========================================="
report_power

exit

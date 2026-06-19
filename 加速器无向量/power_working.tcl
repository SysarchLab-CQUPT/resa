# 1. 读 LEF 文件
read_lef ./NangateOpenCellLibrary.tech.lef
read_lef ./NangateOpenCellLibrary.macro.lef

# 2. 读 Liberty
read_liberty ./NangateOpenCellLibrary_typical.lib

# 3. 读 Verilog 网表
read_verilog ./6_final.v

# 4. 链接设计（PEArray 是顶层模块）
link_design PEArray

# 5. 创建时钟
create_clock -name clk -period 10.0 [get_ports clk]

# 6. 读 VCD（使用正确的 scope 路径）
puts "正在读取 VCD 文件..."
read_vcd -scope TOP.tb_PEArray.dut ./dump.vcd

# 7. 验证活动率
puts "\n=== 验证 VCD 读取情况 ==="
report_activity_annotation > activity_working.rpt

# 8. 生成功耗报告
set_power_global -verbose
set_power_activity -input_activity 0.5 -output_activity 0.5
report_power -corner typical -digits 6 > power_working.txt
report_power -hierarchy -digits 6 > power_hierarchy_working.txt

puts "\n========================================"
puts "功耗分析完成！生成文件："
puts "  - activity_working.rpt"
puts "  - power_working.txt"
puts "  - power_hierarchy_working.txt"
puts "========================================"

exit

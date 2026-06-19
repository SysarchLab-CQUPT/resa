# 1. 读 Liberty（就在当前目录！）
read_liberty ./NangateOpenCellLibrary_typical.lib

# 2. 读 Verilog 网表
read_verilog ./6_final.v

# 3. 链接设计
link_design tb_PEArray

# 4. 创建时钟
create_clock -name clk -period 10.0 [get_ports clk]

# 5. 读 VCD
puts "正在读取 VCD 文件..."
read_vcd -scope TOP.tb_PEArray ./dump.vcd

# 6. 验证活动率
puts "\n=== 验证 VCD 读取情况 ==="
report_activity_annotation > activity_from_vcd.rpt
report_checks -unannotated > unannotated_pins.rpt

# 7. 生成功耗报告
set_power_global -verbose
set_power_activity -input_activity 0.5 -output_activity 0.5
report_power -corner typical -digits 6 > power_report.txt
report_power -hierarchy -digits 6 > power_hierarchy.txt

puts "\n========================================"
puts "功耗分析完成！生成文件："
puts "  - activity_from_vcd.rpt"
puts "  - unannotated_pins.rpt"
puts "  - power_report.txt"
puts "  - power_hierarchy.txt"
puts "========================================"

exit

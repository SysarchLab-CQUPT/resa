# 读取所有必需文件
read_lef ./NangateOpenCellLibrary.tech.lef
read_lef ./NangateOpenCellLibrary.macro.lef
read_liberty ./NangateOpenCellLibrary_typical.lib
read_verilog ./6_final.v
link_design tb_PEArray
create_clock -name clk -period 10.0 [get_ports clk]

# 读取 VCD
puts "正在读取 VCD 文件..."
if {[catch {read_vcd -scope TOP.tb_PEArray ./dump.vcd} msg]} {
    puts "尝试其他 scope..."
    read_vcd -scope tb_PEArray ./dump.vcd
}

# 生成功耗报告
set_power_global -verbose
set_power_activity -input_activity 0.5 -output_activity 0.5
report_power -corner typical -digits 6 > power_report.txt
report_power -hierarchy -digits 6 > power_hierarchy.txt
report_activity_annotation > activity_report.txt

puts "功耗分析完成！"
puts "生成文件："
puts "  - power_report.txt"
puts "  - power_hierarchy.txt"
puts "  - activity_report.txt"
exit

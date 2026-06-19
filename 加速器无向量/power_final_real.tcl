read_lef ./NangateOpenCellLibrary.tech.lef
read_lef ./NangateOpenCellLibrary.macro.lef
read_liberty ./NangateOpenCellLibrary_typical.lib
read_verilog ./6_final.v
link_design PEArray
create_clock -name clk -period 10.0 [get_ports clk]

puts "正在读取完整 SAIF 文件..."
read_saif -instance TOP/PEArray ./dump_full.saif

puts "\n=== 基于完整 SAIF 的精确功耗报告 ==="
report_power

exit

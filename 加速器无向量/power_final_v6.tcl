read_lef ./NangateOpenCellLibrary.tech.lef
read_lef ./NangateOpenCellLibrary.macro.lef
read_liberty ./NangateOpenCellLibrary_typical.lib
read_verilog ./6_final.v
link_design PEArray
create_clock -name clk -period 10.0 [get_ports clk]
read_vcd -scope dut ./dump.vcd
report_power > power_final.txt
report_power -hierarchy > power_hierarchy.txt
puts "功耗分析完成！"
exit

read_lef ./NangateOpenCellLibrary.tech.lef
read_lef ./NangateOpenCellLibrary.macro.lef
read_liberty ./NangateOpenCellLibrary_typical.lib
read_verilog ./6_final.v
link_design PEArray
create_clock -name clk -period 10.0 [get_ports clk]

# 先看看设计中有什么
puts "设计中的模块："
report_components

# 读取 SAIF
puts "\n读取 SAIF..."
read_saif ./dump_full.saif

# 看看哪些信号被标注
puts "\n被标注的引脚："
report_annotated_pins

puts "\n未被标注的引脚："
report_annotated_pins -unannotated

exit

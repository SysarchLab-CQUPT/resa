read_lef ./NangateOpenCellLibrary.tech.lef
read_lef ./NangateOpenCellLibrary.macro.lef
read_liberty ./NangateOpenCellLibrary_typical.lib
read_verilog ./6_final.v
link_design PEArray
create_clock -name clk -period 10.0 [get_ports clk]

# 读取 SAIF，去掉顶层路径
puts "正在读取 SAIF 文件..."
read_saif -strip_path /workspace/dut ./dump_full.saif

# 验证标注
report_annotated_pins

puts "\n=== 功耗报告 ==="
report_power

exit

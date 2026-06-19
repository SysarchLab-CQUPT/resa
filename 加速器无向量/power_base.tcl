# 1. 读 LEF 文件
read_lef ./NangateOpenCellLibrary.tech.lef
read_lef ./NangateOpenCellLibrary.macro.lef

# 2. 读 Liberty
read_liberty ./NangateOpenCellLibrary_typical.lib

# 3. 读 Verilog 网表
read_verilog ./6_final.v

# 4. 链接设计
link_design PEArray

# 5. 创建时钟
create_clock -name clk -period 10.0 [get_ports clk]

# 6. 读 VCD
puts "正在读取 VCD 文件..."
read_vcd -scope TOP.tb_PEArray ./dump.vcd

# 7. 直接生成功耗报告
puts "\n=== 功耗报告 ==="
report_power > power_base.txt

# 8. 查看有多少信号被标注
puts "\n=== 统计 ==="
report_annotated_assertion

puts "完成！"
exit

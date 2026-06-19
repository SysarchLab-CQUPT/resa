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

# 6. 读 VCD（使用正确的 scope：tb_PEArray.dut）
puts "正在读取门级仿真 VCD 文件..."
read_vcd -scope tb_PEArray.dut ./dump.vcd

# 7. 直接生成功耗报告
puts "\n=== 功耗报告 ==="
report_power > power_final_result.txt
report_power -hierarchy > power_final_hierarchy.txt

puts "\n========================================"
puts "基于门级仿真的功耗分析完成！"
puts "生成文件："
puts "  - power_final_result.txt"
puts "  - power_final_hierarchy.txt"
puts "========================================"

exit

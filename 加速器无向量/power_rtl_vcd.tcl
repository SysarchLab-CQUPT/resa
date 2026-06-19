# 假设你已经 read_liberty, read_lef, read_verilog/link_design, create_clock 过了
# 如果没有，先加这些（根据你之前的脚本）

read_liberty ./NangateOpenCellLibrary_typical.lib
read_lef ./NangateOpenCellLibrary.tech.lef
read_lef ./NangateOpenCellLibrary.macro.lef
read_verilog ./6_final.v
link_design PEArray   ;# 或 tb_PEArray，根据 netlist top
create_clock -name clk -period 10.0 [get_ports clk]

# 尝试 RTL VCD + 传播活动（即使部分匹配，也可能标注一些 top-level 和 clock）
puts "尝试读取 RTL VCD 并传播活动..."
read_vcd -scope TOP.tb_PEArray ./dump.vcd

# OpenSTA 没有官方的 "power_activity_propagation" 变量（从文档和 issue 看，没有这个 set 命令）
# 但你可以试这些相关选项（如果支持）或直接依赖默认传播
# set power_propagate_activity true   ;# 可能不存在，忽略如果报错
# 替代：用 set_power_activity 设置 fallback，但别覆盖 VCD
# set_power_activity -input_activity 0.2 -default false   ;# 只对未标注的

# 关键检查：看标注了多少
report_activity_annotation > rtl_vcd_activity.rpt
report_checks -unannotated > rtl_unannotated.rpt

# 报告功耗（即使 annotated 少，也会用部分 VCD + 默认传播）
report_power -corner typical -digits 6 > power_rtl_vcd_total.rpt
report_power -hierarchy -digits 6 > power_rtl_vcd_hier.rpt

puts "RTL VCD 分析完成。检查："
puts " - rtl_vcd_activity.rpt （标注 pin 数量）"
puts " - power_rtl_vcd_hier.rpt （动态功耗是否有变化）"

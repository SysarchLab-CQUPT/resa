#!/bin/bash

echo "=========================================="
echo "     加速器设计完整分析报告"
echo "=========================================="
echo ""

# 1. 基本信息
echo "1. 设计基本信息"
echo "----------------------------------------"
echo "设计名称: PEArray (Processing Element Array)"
echo "工艺节点: 45nm (NangateOpenCellLibrary)"
echo "分析时间: $(date)"
echo ""

# 2. 单元统计
echo "2. 标准单元统计"
echo "----------------------------------------"

# 从之前的Yosys输出中提取总单元数
TOTAL_CELLS=182085
echo "总标准单元数量: $(printf "%'d" $TOTAL_CELLS) 个"
echo ""

# 计算DFF数量
DFF_COUNT=$((10186 + 2 + 333 + 93))
echo "时序单元统计:"
echo "  - DFFR_X1: 10,186 个"
echo "  - DFF_X1:   333 个"
echo "  - DFF_X2:    93 个"
echo "  - DFFR_X2:    2 个"
echo "  总计: $(printf "%'d" $DFF_COUNT) 个 (占总数 $(echo "scale=1; $DFF_COUNT*100/$TOTAL_CELLS" | bc)%)"
echo ""

# 主要单元类型TOP10
echo "主要单元类型 TOP10 (按数量):"
cat << 'TOP10'
 1. BUF_X1       : 23,383 个
 2. MUX2_X1      : 21,634 个
 3. NAND2_X1     : 18,670 个
 4. OAI21_X1     : 16,023 个
 5. INV_X1       : 14,886 个
 6. DFFR_X1      : 10,186 个
 7. AOI21_X1     :  9,657 个
 8. FA_X1        :  8,350 个
 9. NOR2_X1      :  7,936 个
10. BUF_X2       :  6,224 个
TOP10
echo ""

# 3. 面积计算
echo "3. 芯片面积详细计算"
echo "----------------------------------------"

# 使用Python进行精确计算
python3 << 'PYTHON_SCRIPT'
import re

# 单元统计
cell_stats = {
    'AND2_X1': 1946, 'AND2_X2': 28, 'AND3_X1': 358, 'AND3_X2': 1,
    'AND4_X1': 117, 'AND4_X2': 1, 'AOI211_X2': 1, 'AOI21_X1': 9657,
    'AOI21_X2': 50, 'AOI21_X4': 25, 'AOI221_X1': 1691, 'AOI221_X2': 60,
    'AOI222_X1': 269, 'AOI222_X2': 2, 'AOI22_X1': 5013, 'AOI22_X2': 15,
    'AOI22_X4': 2, 'BUF_X1': 23383, 'BUF_X16': 32, 'BUF_X2': 6224,
    'BUF_X32': 1, 'BUF_X4': 4054, 'BUF_X8': 1045, 'CLKBUF_X1': 902,
    'CLKBUF_X2': 14, 'CLKBUF_X3': 1894, 'DFFR_X1': 10186, 'DFFR_X2': 2,
    'DFF_X1': 333, 'DFF_X2': 93, 'FA_X1': 8350, 'HA_X1': 4228,
    'INV_X1': 14886, 'INV_X16': 3, 'INV_X2': 372, 'INV_X4': 74,
    'INV_X8': 58, 'LOGIC0_X1': 576, 'MUX2_X1': 21634, 'NAND2_X1': 18670,
    'NAND2_X2': 63, 'NAND2_X4': 97, 'NAND3_X1': 2551, 'NAND3_X2': 16,
    'NAND3_X4': 2, 'NAND4_X1': 568, 'NAND4_X2': 23, 'NAND4_X4': 6,
    'NOR2_X1': 7936, 'NOR2_X2': 127, 'NOR2_X4': 129, 'NOR3_X1': 2175,
    'NOR3_X2': 23, 'NOR3_X4': 5, 'NOR4_X1': 680, 'NOR4_X2': 87,
    'NOR4_X4': 22, 'OAI21_X1': 16023, 'OAI21_X2': 56, 'OAI21_X4': 25,
    'OAI221_X1': 2684, 'OAI221_X2': 8, 'OAI222_X1': 301, 'OAI22_X1': 4751,
    'OAI22_X2': 6, 'OAI33_X1': 61, 'OR2_X1': 2703, 'OR2_X2': 21,
    'OR2_X4': 6, 'OR3_X1': 1142, 'OR3_X2': 1, 'OR4_X1': 89,
    'OR4_X2': 1, 'OR4_X4': 1, 'XNOR2_X1': 2815, 'XNOR2_X2': 59,
    'XOR2_X1': 546, 'XOR2_X2': 26,
}

# DFF单元面积（从库文件中提取）
dff_areas = {
    'DFFR_X1': 5.320, 'DFFR_X2': 5.852,
    'DFF_X1': 4.522, 'DFF_X2': 5.054,
}

# 其他单元面积（从之前的提取中获取）
other_areas = {
    'MUX2_X1': 1.862, 'FA_X1': 4.256, 'BUF_X1': 0.798, 'OAI21_X1': 1.064,
    'NAND2_X1': 0.798, 'HA_X1': 2.660, 'AOI21_X1': 1.064, 'INV_X1': 0.532,
    'BUF_X4': 1.862, 'AOI22_X1': 1.330, 'BUF_X2': 1.064, 'NOR2_X1': 0.798,
    'OAI22_X1': 1.330, 'XNOR2_X1': 1.596, 'OAI221_X1': 1.596, 'BUF_X8': 3.458,
    'OR2_X1': 1.064, 'NAND3_X1': 1.064, 'AOI221_X1': 1.596, 'CLKBUF_X3': 1.330,
    'NOR3_X1': 1.064, 'AND2_X1': 1.064, 'OR3_X1': 1.330, 'NOR4_X1': 1.330,
    'XOR2_X1': 1.596, 'NAND4_X1': 1.330, 'CLKBUF_X1': 0.798, 'OAI222_X1': 2.128,
    'AOI222_X1': 2.128, 'AND3_X1': 1.330, 'NOR2_X4': 2.394, 'LOGIC0_X1': 0.532,
    'INV_X2': 0.798, 'NAND2_X4': 2.394, 'BUF_X16': 6.650, 'NOR4_X2': 2.394,
    'AND4_X1': 1.596, 'AOI221_X2': 2.926, 'NOR2_X2': 1.330, 'XNOR2_X2': 2.660,
    'OR4_X1': 1.596, 'INV_X8': 2.394, 'OAI33_X1': 1.862, 'NOR4_X4': 4.788,
    'OAI21_X2': 1.862, 'INV_X4': 1.330, 'AOI21_X2': 1.862, 'AOI21_X4': 3.458,
    'OAI21_X4': 3.458, 'NAND2_X2': 1.330, 'XOR2_X2': 2.394, 'NAND4_X2': 2.394,
    'NOR3_X2': 1.862, 'AND2_X2': 1.330, 'AOI22_X2': 2.394, 'NAND3_X2': 1.862,
    'NAND4_X4': 4.788, 'OR2_X2': 1.330, 'OAI221_X2': 2.926, 'NOR3_X4': 3.724,
    'CLKBUF_X2': 1.064, 'OAI22_X2': 2.394, 'OR2_X4': 2.394, 'INV_X16': 4.522,
    'BUF_X32': 13.034, 'AOI22_X4': 4.522, 'AOI222_X2': 3.724, 'NAND3_X4': 3.458,
    'OR4_X4': 3.458, 'AOI211_X2': 2.394, 'AND4_X2': 1.862, 'OR4_X2': 1.862,
    'AND3_X2': 1.596, 'OR3_X2': 1.596,
}

# 合并所有面积
all_areas = {**dff_areas, **other_areas}

# 计算总面积
total_area = 0
combo_area = 0
dff_area = 0

for cell_name, count in cell_stats.items():
    if cell_name in all_areas:
        area = all_areas[cell_name]
        cell_total = area * count
        total_area += cell_total
        if cell_name in dff_areas:
            dff_area += cell_total
        else:
            combo_area += cell_total

print(f"组合逻辑面积: {combo_area:>10,.2f} μm²  ({combo_area/1e6:.4f} mm²)")
print(f"时序单元面积: {dff_area:>10,.2f} μm²  ({dff_area/1e6:.4f} mm²)")
print(f"{'─' * 50}")
print(f"总芯片面积:   {total_area:>10,.2f} μm²  ({total_area/1e6:.4f} mm²)")
print()

# 主要面积贡献
print("主要面积贡献单元 TOP10:")
cell_totals = []
for cell_name, count in cell_stats.items():
    if cell_name in all_areas:
        area = all_areas[cell_name]
        cell_total = area * count
        cell_totals.append((cell_name, count, area, cell_total))

cell_totals.sort(key=lambda x: x[3], reverse=True)
for i, (cell_name, count, area, cell_total) in enumerate(cell_totals[:10], 1):
    percentage = cell_total / total_area * 100
    print(f"  {i:2d}. {cell_name:<15} {count:>6,}个 × {area:>6.3f}μm² = {cell_total:>9,.2f}μm² ({percentage:>5.1f}%)")

PYTHON_SCRIPT

# 4. 功耗分析
echo ""
echo "4. 功耗分析"
echo "----------------------------------------"
echo "总功耗: 125 mW"
echo ""
echo "功耗分布:"
echo "  - Internal Power: 77.2 mW (61.9%)"
echo "  - Switching Power: 40.9 mW (32.8%)"
echo "  - Leakage Power:   6.6 mW (5.3%)"
echo ""

# 5. 功耗密度计算
echo "5. 功耗密度分析"
echo "----------------------------------------"

# 获取总面积（从Python输出中提取，这里使用计算值）
TOTAL_AREA_MM2=0.2834
POWER_MW=125
POWER_DENSITY=$(echo "scale=1; $POWER_MW / $TOTAL_AREA_MM2" | bc)

echo "芯片面积: ${TOTAL_AREA_MM2} mm²"
echo "总功耗: ${POWER_MW} mW"
echo "功耗密度: ${POWER_DENSITY} mW/mm² (${POWER_DENSITY}/1000 W/mm²)"
echo ""

# 6. 性能估算（如果有频率信息）
echo "6. 性能指标估算"
echo "----------------------------------------"

# 估算等效门数
GATE_COUNT=$((TOTAL_CELLS / 2))  # 粗略估算
echo "等效门数: 约 $(printf "%'d" $GATE_COUNT) 门"

# 估算门密度
GATE_DENSITY=$(echo "scale=0; $GATE_COUNT / $TOTAL_AREA_MM2" | bc)
echo "门密度: 约 ${GATE_DENSITY} 门/mm²"

# 7. 总结
echo ""
echo "=========================================="
echo "             分析总结"
echo "=========================================="
echo ""
echo "┌────────────────────────────────────────┐"
echo "│ 设计指标                   数值       │"
echo "├────────────────────────────────────────┤"
printf "│ 总标准单元数      %'13d 个 │\n" 182085
printf "│ 时序单元数        %'13d 个 │\n" 10614
printf "│ 芯片面积          %'13.4f mm² │\n" 0.2834
printf "│ 总功耗            %'13d mW │\n" 125
printf "│ 功耗密度          %'13.1f mW/mm² │\n" 441
printf "│ 等效门数          %'13d 门 │\n" $((182085 / 2))
echo "└────────────────────────────────────────┘"
echo ""

# 8. 保存报告到文件
REPORT_FILE="design_analysis_report.txt"

cat > $REPORT_FILE << 'EOF'
==========================================
     加速器设计完整分析报告
==========================================

1. 设计基本信息
----------------------------------------
设计名称: PEArray (Processing Element Array)
工艺节点: 45nm (NangateOpenCellLibrary)

2. 标准单元统计
----------------------------------------
总标准单元数量: 182,085 个

时序单元统计:
  - DFFR_X1: 10,186 个
  - DFF_X1:   333 个
  - DFF_X2:    93 个
  - DFFR_X2:    2 个
  总计: 10,614 个 (占总数 5.8%)

主要单元类型 TOP10 (按数量):
 1. BUF_X1       : 23,383 个
 2. MUX2_X1      : 21,634 个
 3. NAND2_X1     : 18,670 个
 4. OAI21_X1     : 16,023 个
 5. INV_X1       : 14,886 个
 6. DFFR_X1      : 10,186 个
 7. AOI21_X1     :  9,657 个
 8. FA_X1        :  8,350 个
 9. NOR2_X1      :  7,936 个
10. BUF_X2       :  6,224 个

3. 芯片面积
----------------------------------------
组合逻辑面积: 227,173.58 μm² (0.2272 mm²)
时序单元面积:  56,177.07 μm² (0.0562 mm²)
─────────────────────────────────────────
总芯片面积:   283,350.65 μm² (0.2834 mm²)

主要面积贡献单元 TOP10:
 1. MUX2_X1     : 21,634个 × 1.862μm² = 40,282.51μm² (14.2%)
 2. FA_X1       :  8,350个 × 4.256μm² = 35,537.60μm² (12.5%)
 3. DFFR_X1     : 10,186个 × 5.320μm² = 54,189.52μm² (19.1%)
 4. BUF_X1      : 23,383个 × 0.798μm² = 18,659.63μm² (6.6%)
 5. OAI21_X1    : 16,023个 × 1.064μm² = 17,048.47μm² (6.0%)
 6. NAND2_X1    : 18,670个 × 0.798μm² = 14,898.66μm² (5.3%)
 7. HA_X1       :  4,228个 × 2.660μm² = 11,246.48μm² (4.0%)
 8. AOI21_X1    :  9,657个 × 1.064μm² = 10,275.05μm² (3.6%)
 9. INV_X1      : 14,886个 × 0.532μm² =  7,919.35μm² (2.8%)
10. BUF_X4      :  4,054个 × 1.862μm² =  7,548.55μm² (2.7%)

4. 功耗分析
----------------------------------------
总功耗: 125 mW

功耗分布:
  - Internal Power: 77.2 mW (61.9%)
  - Switching Power: 40.9 mW (32.8%)
  - Leakage Power:   6.6 mW (5.3%)

功耗密度: 441 mW/mm²

5. 设计评估
----------------------------------------
✓ 面积合理: 0.2834 mm² 对于18万门设计是合适的
✓ 时序单元占比: 19.8% 符合典型数字设计
⚠ 功耗密度较高: 441 mW/mm² 需要注意散热
✓ 主要面积消耗: MUX和加法器，符合加速器特性

==========================================

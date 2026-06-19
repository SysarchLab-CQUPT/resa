#!/usr/bin/env python3

# 单元统计（从Yosys输出中整理）
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

# 从库文件中提取所有单元和面积
print("正在读取库文件...")
cell_areas = {}
with open('NangateOpenCellLibrary_typical.lib', 'r') as f:
    content = f.read()
    
# 使用正则表达式提取cell和area
import re
# 匹配 cell (CELL_NAME) { ... area : XXX; ... }
pattern = r'cell\s+\((\w+)\)\s*\{[^}]*?area\s*:\s*([\d.]+)\s*;'
matches = re.findall(pattern, content, re.DOTALL)

for cell_name, area in matches:
    cell_areas[cell_name] = float(area)

print(f"从库文件中提取了 {len(cell_areas)} 个单元的面积信息")

# 计算总面积
total_area = 0
found_cells = 0
missing_cells = []

print("\n" + "="*90)
print("单元面积详细计算")
print("="*90)
print(f"{'单元类型':<20} {'数量':>10} {'面积(μm²)':>12} {'总面积(μm²)':>15} {'占比(%)':>10}")
print("-"*90)

# 按总面积排序
cell_totals = []
for cell_name, count in cell_stats.items():
    if cell_name in cell_areas:
        area = cell_areas[cell_name]
        cell_total = area * count
        total_area += cell_total
        found_cells += 1
        cell_totals.append((cell_name, count, area, cell_total))
    else:
        missing_cells.append(cell_name)

# 按总面积排序并显示
cell_totals.sort(key=lambda x: x[3], reverse=True)

for cell_name, count, area, cell_total in cell_totals:
    percentage = (cell_total / total_area * 100) if total_area > 0 else 0
    print(f"{cell_name:<20} {count:>10} {area:>12.3f} {cell_total:>15.2f} {percentage:>9.2f}%")

if missing_cells:
    print("-"*90)
    print(f"未找到面积的单元 ({len(missing_cells)}个):")
    # 只显示前10个缺失的
    for cell in missing_cells[:10]:
        print(f"  - {cell}")
    if len(missing_cells) > 10:
        print(f"  ... 还有 {len(missing_cells)-10} 个")

print("-"*90)
print(f"{'总计':<20} {sum(cell_stats.values()):>10} {'':>12} {total_area:>15.2f} {'100.00%':>10}")
print("="*90)

# 输出统计信息
total_cells = sum(cell_stats.values())
area_mm2 = total_area / 1e6

print(f"\n{'='*50}")
print(f"面积统计汇总")
print(f"{'='*50}")
print(f"  总单元数: {total_cells:,} 个")
print(f"  找到面积的单元类型: {found_cells}/{len(cell_stats)}")
print(f"  找到面积的单元数量覆盖: {sum(cell_stats[c] for c in cell_stats if c in cell_areas):,} / {total_cells:,}")
print(f"\n  总芯片面积: {total_area:,.2f} μm²")
print(f"  总芯片面积: {area_mm2:.4f} mm²")
print(f"  总芯片面积: {area_mm2*1e6:.2f} μm² (等效)")

# 功耗密度计算
power_mw = 125  # 从您的功耗报告
if area_mm2 > 0:
    power_density = power_mw / area_mm2
    print(f"\n功耗密度估算 (基于125mW总功耗):")
    print(f"  功耗密度: {power_density:.2f} mW/mm²")
    print(f"  或: {power_density/1000:.3f} W/mm²")

# 按单元类型分类统计
print(f"\n{'='*50}")
print(f"按功能分类统计")
print(f"{'='*50}")

# 分类
seq_cells = ['DFFR_X1', 'DFFR_X2', 'DFF_X1', 'DFF_X2']
buf_cells = ['BUF_X1', 'BUF_X2', 'BUF_X4', 'BUF_X8', 'BUF_X16', 'BUF_X32']
clkbuf_cells = ['CLKBUF_X1', 'CLKBUF_X2', 'CLKBUF_X3']
logic_cells = [c for c in cell_stats.keys() if c not in seq_cells + buf_cells + clkbuf_cells]

seq_area = sum(cell_areas.get(c, 0) * cell_stats.get(c, 0) for c in seq_cells if c in cell_areas)
buf_area = sum(cell_areas.get(c, 0) * cell_stats.get(c, 0) for c in buf_cells if c in cell_areas)
clkbuf_area = sum(cell_areas.get(c, 0) * cell_stats.get(c, 0) for c in clkbuf_cells if c in cell_areas)
logic_area = total_area - seq_area - buf_area - clkbuf_area

print(f"  时序单元面积: {seq_area:,.2f} μm² ({seq_area/total_area*100:.1f}%)")
print(f"  缓冲器面积: {buf_area:,.2f} μm² ({buf_area/total_area*100:.1f}%)")
print(f"  时钟缓冲面积: {clkbuf_area:,.2f} μm² ({clkbuf_area/total_area*100:.1f}%)")
print(f"  组合逻辑面积: {logic_area:,.2f} μm² ({logic_area/total_area*100:.1f}%)")


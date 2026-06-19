#!/usr/bin/env python3

# 单元统计（从Yosys输出中手动整理）
cell_stats = {
    'AND2_X1': 1946,
    'AND2_X2': 28,
    'AND3_X1': 358,
    'AND3_X2': 1,
    'AND4_X1': 117,
    'AND4_X2': 1,
    'AOI211_X2': 1,
    'AOI21_X1': 9657,
    'AOI21_X2': 50,
    'AOI21_X4': 25,
    'AOI221_X1': 1691,
    'AOI221_X2': 60,
    'AOI222_X1': 269,
    'AOI222_X2': 2,
    'AOI22_X1': 5013,
    'AOI22_X2': 15,
    'AOI22_X4': 2,
    'BUF_X1': 23383,
    'BUF_X16': 32,
    'BUF_X2': 6224,
    'BUF_X32': 1,
    'BUF_X4': 4054,
    'BUF_X8': 1045,
    'CLKBUF_X1': 902,
    'CLKBUF_X2': 14,
    'CLKBUF_X3': 1894,
    'DFFR_X1': 10186,
    'DFFR_X2': 2,
    'DFF_X1': 333,
    'DFF_X2': 93,
    'FA_X1': 8350,
    'HA_X1': 4228,
    'INV_X1': 14886,
    'INV_X16': 3,
    'INV_X2': 372,
    'INV_X4': 74,
    'INV_X8': 58,
    'LOGIC0_X1': 576,
    'MUX2_X1': 21634,
    'NAND2_X1': 18670,
    'NAND2_X2': 63,
    'NAND2_X4': 97,
    'NAND3_X1': 2551,
    'NAND3_X2': 16,
    'NAND3_X4': 2,
    'NAND4_X1': 568,
    'NAND4_X2': 23,
    'NAND4_X4': 6,
    'NOR2_X1': 7936,
    'NOR2_X2': 127,
    'NOR2_X4': 129,
    'NOR3_X1': 2175,
    'NOR3_X2': 23,
    'NOR3_X4': 5,
    'NOR4_X1': 680,
    'NOR4_X2': 87,
    'NOR4_X4': 22,
    'OAI21_X1': 16023,
    'OAI21_X2': 56,
    'OAI21_X4': 25,
    'OAI221_X1': 2684,
    'OAI221_X2': 8,
    'OAI222_X1': 301,
    'OAI22_X1': 4751,
    'OAI22_X2': 6,
    'OAI33_X1': 61,
    'OR2_X1': 2703,
    'OR2_X2': 21,
    'OR2_X4': 6,
    'OR3_X1': 1142,
    'OR3_X2': 1,
    'OR4_X1': 89,
    'OR4_X2': 1,
    'OR4_X4': 1,
    'XNOR2_X1': 2815,
    'XNOR2_X2': 59,
    'XOR2_X1': 546,
    'XOR2_X2': 26,
}

# 读取单元面积数据
cell_areas = {}
with open('cell_areas.txt', 'r') as f:
    for line in f:
        parts = line.strip().split()
        if len(parts) >= 2:
            cell_name = parts[0]
            area = float(parts[1])
            cell_areas[cell_name] = area

# 计算总面积
total_area = 0
found_cells = 0
missing_cells = []

print("=" * 80)
print("单元面积详细计算")
print("=" * 80)
print(f"{'单元类型':<20} {'数量':>10} {'面积(μm²)':>12} {'总面积(μm²)':>15}")
print("-" * 80)

for cell_name, count in sorted(cell_stats.items(), key=lambda x: x[1], reverse=True):
    if cell_name in cell_areas:
        area = cell_areas[cell_name]
        cell_total = area * count
        total_area += cell_total
        found_cells += 1
        print(f"{cell_name:<20} {count:>10} {area:>12.3f} {cell_total:>15.2f}")
    else:
        missing_cells.append(cell_name)
        print(f"{cell_name:<20} {count:>10} {'N/A':>12} {'N/A':>15} (面积未找到)")

print("-" * 80)
print(f"{'总计':<20} {sum(cell_stats.values()):>10} {'':>12} {total_area:>15.2f}")
print("=" * 80)

# 输出统计信息
print(f"\n面积统计:")
print(f"  总单元数: {sum(cell_stats.values()):,} 个")
print(f"  找到面积的单元类型: {found_cells}/{len(cell_stats)}")
print(f"  总芯片面积: {total_area:.2f} μm²")
print(f"  总芯片面积: {total_area/1e6:.4f} mm²")

if missing_cells:
    print(f"\n未找到面积的单元类型 ({len(missing_cells)}个):")
    for cell in missing_cells[:20]:  # 只显示前20个
        print(f"  - {cell}")
    if len(missing_cells) > 20:
        print(f"  ... 还有 {len(missing_cells)-20} 个")

# 功耗密度计算
power_mw = 125  # 从您的功耗报告
area_mm2 = total_area / 1e6
power_density = power_mw / area_mm2 if area_mm2 > 0 else 0

print(f"\n功耗密度估算 (基于125mW总功耗):")
print(f"  功耗密度: {power_density:.2f} mW/mm²")
print(f"  或: {power_density/1000:.2f} W/mm²")


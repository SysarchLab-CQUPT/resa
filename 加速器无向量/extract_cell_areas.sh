#!/bin/bash

# 从lib文件中提取所有cell和对应的面积
awk '/cell\(/{cell=$0; gsub(/.*cell\(/, "", cell); gsub(/\).*/, "", cell)} /area[[:space:]]*:/{area=$0; gsub(/.*area[[:space:]]*:[[:space:]]*/, "", area); gsub(/;.*/, "", area); print cell, area}' NangateOpenCellLibrary_typical.lib > cell_areas.txt

echo "单元面积提取完成，共 $(wc -l < cell_areas.txt) 个单元"
head -20 cell_areas.txt

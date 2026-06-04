---
name: upset
description: >-
  Draw Nature-style UpSet diagrams for FT-ICR MS DOM assigned molecular formula
  sets across pre-ozonation dosages. Use when the user asks to call upset,
  make/upset plot, draw ML/OL molecular formula intersections, or create
  publication-ready UpSet figures from stable formula CSV/XLSX files.
---

# UpSet Figure Skill

用于 FT-ICR MS DOM 稳定分子式集合的 UpSet 图绘制，适合比较 ML/OL 在不同预臭氧剂量下 assigned molecular formulas 的交集关系。

## 适用数据

输入目录应包含每个条件一个稳定分子式文件，支持 `.csv`, `.xlsx`, `.xls`。默认识别：

- `ML-0`, `ML-0.5`, `ML-0.8`, `ML-1`
- `OL-0`, `OL-0.5`, `OL-0.8`, `OL-1`

文件中需要有分子式列，自动识别以下列名：

- `Formula`
- `Molecular Formula`
- `molecular_formula`
- `formula`
- `Assigned formula`

本 skill 假设输入文件已经完成去重和三平行稳定筛选；绘图时不再重新做三平行交集筛选。

## 默认图形设计

图形为左右两部分：

- 左侧：set-size bar，显示每个剂量组的 formula count。
- 右侧上方：exclusive intersection size bar，灰色柱子。
- 右侧下方：combination matrix，行背景、活跃圆点和连接线均与对应剂量颜色匹配，背景使用低饱和浅色。

默认剂量颜色：

ML:

- `1` = `#E5086A`
- `0.5` = `#D35F27`
- `0.8` = `#604E98`
- `0` = `#046586`

OL:

- `1` = `#E41A1C`
- `0.8` = `#6BAF45`
- `0` = `#F07F7F`
- `0.5` = `#F5A623`

坐标轴使用白底、黑色轴线、清晰刻度、Arial 字体，并导出 Illustrator 友好的 PDF。

## 调用流程

1. 确认用户给出输入文件夹，或从上下文找到包含稳定分子式文件的目录。
2. 使用 `scripts/make_upset_nature_matched.R` 生成图。
3. 输出 ML 和 OL 两张图的 PDF/PNG，以及用于核查的 set size 和 intersection CSV。
4. 若用户需要投稿 source data，整理为两个 sheet：
   - set sizes
   - intersections with dose membership

## 推荐运行命令

```powershell
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" `
  "path\to\upset\scripts\make_upset_nature_matched.R" `
  --input_dir "C:\path\to\stable_formula_files" `
  --output_dir "C:\path\to\output"
```

也可以直接用系统默认 `Rscript`：

```bash
Rscript scripts/make_upset_nature_matched.R --input_dir ./stable_formula_files --output_dir ./UpSet_nature_matched
```

## 输出文件

- `ML_upset_nature_matched.pdf`
- `ML_upset_nature_matched.png`
- `OL_upset_nature_matched.pdf`
- `OL_upset_nature_matched.png`
- `upset_nature_matched_set_size_audit.csv`
- `ML_upset_nature_matched_intersections.csv`
- `OL_upset_nature_matched_intersections.csv`

PNG 默认 600 dpi；PDF 使用 `cairo_pdf`，便于 Adobe Illustrator 后期编辑。

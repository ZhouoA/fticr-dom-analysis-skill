---
name: VK-marginal distribution
description: >-
  Draw Nature-style Van Krevelen scatter plots with marginal O/C and H/C density
  distributions for FT-ICR MS DOM precursor, product, and resistant formula
  datasets. Use when the user asks to call VK-marginal distribution, make VK
  marginal plots, or draw Fig. S8-style 2 x 3 ML/OL pre-ozonation panels.
---

# VK-Marginal Distribution

用于绘制 FT-ICR MS DOM 的 “Van Krevelen + marginal distribution” 图，尤其适合 precursor、product、resistant 三类分子式在 ML/OL 不同预臭氧剂量下的比较。

## 输入数据

默认读取一个文件夹中的 6 个 Excel 文件：

```text
final_classification_for_analysis_ML0 vs. 0.5.xlsx
final_classification_for_analysis_ML0 vs. 0.8.xlsx
final_classification_for_analysis_ML0 vs. 1.xlsx
final_classification_for_analysis_OL0 vs. 0.5.xlsx
final_classification_for_analysis_OL0 vs. 0.8.xlsx
final_classification_for_analysis_OL0 vs. 1.xlsx
```

每个文件应包含 3 个 sheet：

```text
final_precursor
final_product
final_resistant
```

每个 sheet 至少需要 `O/C` 和 `H/C` 列。分子式列可为 `Formula`、`Molecular Formula`、`molecular_formula` 或 `Assigned formula`。

## 绘图规则

- 主图：x 轴为 `O/C`，y 轴为 `H/C`。
- 上方边际图：O/C density distribution。
- 右侧边际图：H/C density distribution。
- Stage 颜色固定：
  - Precursor: blue `#4E79A7`
  - Product: red `#E15759`
  - Resistant: green `#59A14F`
- 不使用 RI，不按 RI 加权，也不用 RI 控制点大小、透明度或颜色。
- VK compound-class 参考虚线沿用项目中 vk-figure 的边界。
- 坐标范围为 `O/C = -0.02–1.22`、`H/C = -0.05–2.55`，刻度保留 `0.0` 并在 0 左侧/下方留白。
- 图例放在每个主图右下角，显示原始 sheet 行数 `raw_n`，例如 `Precursor (n=3304)`。
- 如果少数点超出统一坐标范围，它们不会显示在散点图中，但图例 n 仍使用原始分类数量。

## 输出

默认输出到 `INPUT_DIR/Fig_S8_VK_marginal`：

```text
Fig_S8_VK_marginal_combined.pdf
Fig_S8_VK_marginal_combined.png
Fig_S8_ML_0p5_VK_marginal.pdf/png
Fig_S8_ML_0p8_VK_marginal.pdf/png
Fig_S8_ML_1p0_VK_marginal.pdf/png
Fig_S8_OL_0p5_VK_marginal.pdf/png
Fig_S8_OL_0p8_VK_marginal.pdf/png
Fig_S8_OL_1p0_VK_marginal.pdf/png
Fig_S8_stage_counts.csv
Fig_S8_caption.txt
```

PDF 使用 `cairo_pdf`，PNG 为 600 dpi。

## 调用方式

```bash
Rscript skills/vk-marginal-distribution/scripts/vk_marginal_distribution.R \
  --input_dir INPUT_DIR \
  --output_dir OUTPUT_DIR \
  --prefix Fig_S8
```

如果不提供 `--output_dir`，默认输出到：

```text
INPUT_DIR/Fig_S8_VK_marginal
```

## 注意

1. 不改变 precursor、product、resistant 的分类逻辑，Stage 直接来自 sheet 名。
2. 不改变颜色映射逻辑。
3. 图例 n 使用原始 sheet 行数，而不是坐标范围内可见点数。
4. 生成图后应预览 PNG，确认 a/b 行标在图外侧、样品名位置一致、图例在右下角。

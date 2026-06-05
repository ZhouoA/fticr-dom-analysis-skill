---
name: PMD-Radar plots
description: >-
  Draw Nature-style circular PMD reaction radar plots from FT-ICR MS precursor-product
  network edge tables. Use when the user asks to call PMD-Radar plots, plot PMD
  reaction distributions, draw reaction polar/radar plots, or visualize ML/OL
  ozonation reaction pathways with outer category rings.
---

# PMD-Radar Plots

用于把 PMD/linkage 匹配得到的 precursor-product reaction pair 结果画成论文级环形雷达图。该 skill 适合展示 ML/OL 在不同臭氧剂量下的 reaction pair 数量分布，并用外圈彩色条带标注反应大类。

## 输入数据

核心输入是 `all_network_edge.csv`，至少需要包含：

```text
Leachate
Dose
Reaction
```

典型来源是 precursor-product 匹配脚本输出的：

```text
reaction_results/all_network_edge.csv
```

`Leachate` 应包含 `ML` 和/或 `OL`；`Dose` 推荐为 `0.5`、`0.8`、`1.0`；`Reaction` 应与脚本内置的 36 个反应代码一致，例如：

```text
1+3O
1+H2O2
1-S
1-C2H4
1-NH2+NO2
```

## 绘图规则

- 内圈为极坐标雷达图，半径表示每种 reaction 的匹配数量 Count。
- 半径使用平方根缩放，但径向刻度文字显示原始 Count，提高低值区可读性。
- 0.5、0.8、1.0 三个剂量使用轻微角度错位，避免点完全重叠。
- Formula difference 使用真正的 en dash `–`，例如 `–C2H4`、`–SO2`。
- Formula difference 标签位于彩色条带内侧。
- 最外圈彩色条带表示 reaction category。
- Reaction category 标签沿外圈切线方向放置。
- `a ML`、`b OL` 标注放在图外左上角，不放在圆心。
- 图例为放大的线 + 圆点样式。

## 反应大类

脚本内置 36 个 reaction 的顺序和分类：

```text
Dealkylation
Oxygen addition
Decarboxylation
Deamination
Desulfonation
Other reactions
```

如需修改分类或顺序，优先编辑脚本中的 `reaction_map` 表，不要改输入 edge 表。

## 调用方式

```bash
Rscript skills/pmd-radar-plots/scripts/pmd_radar_plots.R \
  --input_edges reaction_results/all_network_edge.csv \
  --output_dir reaction_results/reaction_polar_figures \
  --prefix reaction_polar_ring
```

如果在包含 `all_network_edge.csv` 的目录中运行，也可以省略输入路径：

```bash
Rscript skills/pmd-radar-plots/scripts/pmd_radar_plots.R
```

## 输出文件

默认输出到 `all_network_edge.csv` 所在目录下的 `reaction_polar_figures`：

```text
reaction_polar_ring_ML.svg/pdf/tiff/png
reaction_polar_ring_OL.svg/pdf/tiff/png
reaction_polar_ring_ML_OL_combined.svg/pdf/tiff/png
source_data_reaction_polar_ring.csv
reaction_category_mapping.csv
```

优先用于投稿和 Illustrator 微调的文件：

```text
reaction_polar_ring_ML.pdf
reaction_polar_ring_OL.pdf
reaction_polar_ring_ML_OL_combined.pdf
```

## 质量检查

生成后必须预览 PNG，重点检查：

1. Formula difference 是否没有被外圈彩色条带压住。
2. `a ML` / `b OL` 是否位于图外左上角。
3. 中间数据点是否能区分 0.5、0.8、1.0 三个剂量。
4. 图例是否为线 + 圆点，且字号足够大。
5. SVG/PDF/TIFF/PNG 是否都已输出。

## 示例图

示例图位于：

```text
assets/reaction_polar_ring_ML_example.png
assets/reaction_polar_ring_OL_example.png
```

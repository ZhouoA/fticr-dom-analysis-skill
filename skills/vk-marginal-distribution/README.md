# VK-marginal distribution：VK 散点图 + 边际分布图

这个 skill 用来绘制论文风格的 “Van Krevelen + marginal distribution” 图。它适合展示 precursor、product、resistant 三类分子式在 ML 和 OL 不同预臭氧剂量下的 O/C 与 H/C 分布。

## 最终图预览

![VK marginal distribution final example](assets/Fig_S8_VK_marginal_combined_final_v3.png)

## 这个图表达什么

每个子图由三部分组成：

1. 中间：Van Krevelen 散点图，x 轴为 O/C，y 轴为 H/C。
2. 上方：O/C 的边际密度分布。
3. 右侧：H/C 的边际密度分布。

颜色固定为：

| Stage | 颜色 | Hex |
|---|---|---|
| Precursor | 蓝色 | `#4E79A7` |
| Product | 红色 | `#E15759` |
| Resistant | 绿色 | `#59A14F` |

这张图不使用 RI，不按 RI 加权，也不用 RI 控制点大小、透明度或颜色。

## 输入文件要求

输入文件夹中应包含 6 个 Excel 文件：

```text
final_classification_for_analysis_ML0 vs. 0.5.xlsx
final_classification_for_analysis_ML0 vs. 0.8.xlsx
final_classification_for_analysis_ML0 vs. 1.xlsx
final_classification_for_analysis_OL0 vs. 0.5.xlsx
final_classification_for_analysis_OL0 vs. 0.8.xlsx
final_classification_for_analysis_OL0 vs. 1.xlsx
```

每个 Excel 文件中应包含：

```text
final_precursor
final_product
final_resistant
```

每个 sheet 至少包含：

```text
O/C
H/C
```

分子式列可为：

```text
Formula
Molecular Formula
molecular_formula
Assigned formula
```

## 图形版式

最终输出为 2 × 3 总图：

```text
第一行：ML-0.5, ML-0.8, ML-1.0
第二行：OL-0.5, OL-0.8, OL-1.0
```

行标：

```text
a = ML 行
b = OL 行
```

行标放在每行最左侧图外，不放在每个子图内部。

每个子图内部左上角标注样品名，例如：

```text
ML-0.5
OL-1.0
```

图例放在每个主图右下角，显示原始分类数量：

```text
Precursor (n=3304)
Product (n=3368)
Resistant (n=2962)
```

注意：图例 n 使用原始 sheet 行数。如果个别点超出统一坐标范围，图中不显示，但 n 仍保留原始分类数量。

## 坐标和 VK 参考线

坐标范围：

```text
O/C: -0.02–1.22
H/C: -0.05–2.55
```

刻度显示保留 0.0，并在 0.0 左侧和下方留出少量空白，对标 vk-figure 风格。

VK compound-class 参考虚线沿用项目已有 VK 分类边界，使用浅灰色但可见的虚线。

## 调用方式

在 Codex 里可以说：

```text
调用 VK-marginal distribution，读取这个文件夹，帮我画 Fig. S8 这种 VK 边际分布图
```

命令行示例：

```bash
Rscript skills/vk-marginal-distribution/scripts/vk_marginal_distribution.R \
  --input_dir 输入文件夹 \
  --output_dir 输出文件夹 \
  --prefix Fig_S8
```

Windows PowerShell 示例：

```powershell
Rscript skills/vk-marginal-distribution/scripts/vk_marginal_distribution.R `
  --input_dir "C:\Users\周周\Desktop\NCFT\02DOM数据处理\pre-pro" `
  --output_dir "C:\Users\周周\Desktop\NCFT\02DOM数据处理\pre-pro\Fig_S8_VK_marginal" `
  --prefix Fig_S8
```

## 输出文件

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

PDF 为 Illustrator 友好版；PNG 为 600 dpi。

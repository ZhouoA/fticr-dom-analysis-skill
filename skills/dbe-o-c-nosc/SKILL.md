---
name: dbe-o-c-nosc
description: Generate publication-ready (DBE-O)/C-NOSC molecular-state figures from ML/OL FT-ICR MS classification workbooks, including precursor/product/resistant scatter panels and precursor/product RI stacked bars. Use when the user asks to call (DBE–O)/C-NOSC, reproduce Fig. S12, compare ozonation-response classes in NOSC versus (DBE-O)/C space, or summarize saturated/unsaturated and oxidized/reduced molecular states.
---

# (DBE–O)/C-NOSC

使用 R 从 ML/OL 的 precursor、product 和 resistant 分类工作簿生成论文级组合图。

## 输入

将 `--input_dir` 指向包含 6 个分类工作簿的文件夹：

```text
final_classification_for_analysis_ML0 vs. 0.5.xlsx
final_classification_for_analysis_ML0 vs. 0.8.xlsx
final_classification_for_analysis_ML0 vs. 1.xlsx
final_classification_for_analysis_OL0 vs. 0.5.xlsx
final_classification_for_analysis_OL0 vs. 0.8.xlsx
final_classification_for_analysis_OL0 vs. 1.xlsx
```

每个工作簿必须包含：

```text
final_precursor
final_product
final_resistant
```

每个工作表需要 `NOSC` 和 `(DBE-O)/C`。如果没有 `(DBE-O)/C`，脚本使用 `DBE-O / C` 计算；如果没有 `C`，则从 `Formula` 解析。

RI 列规则：

```text
precursor: mean_RI_before，或 RI / RI (%) / Relative intensity
product:   mean_RI_after，或 RI / RI (%) / Relative intensity
resistant: 仅用于散点图，不参与 RI 堆叠柱状图
```

## 运行

```bash
Rscript skills/dbe-o-c-nosc/scripts/dbe_o_c_nosc_figure.R \
  --input_dir 输入文件夹 \
  --output_dir 输出文件夹 \
  --prefix Fig_S12 \
  --dpi 600
```

Windows PowerShell：

```powershell
Rscript skills/dbe-o-c-nosc/scripts/dbe_o_c_nosc_figure.R `
  --input_dir "C:\path\to\pre-pro" `
  --output_dir "C:\path\to\pre-pro" `
  --prefix "Fig_S12" `
  --dpi 600
```

## 图形结构

- `a`：ML-0.5、ML-0.8、ML-1 的 `(DBE–O)/C–NOSC` 散点图。
- `b`：OL-0.5、OL-0.8、OL-1 的 `(DBE–O)/C–NOSC` 散点图。
- `c`：ML 和 OL 的 precursor/product 四类分子状态 RI (%) 堆叠柱状图。
- 散点颜色固定为 precursor 蓝、product 红、resistant 绿。
- 横轴显示 `-2, -1, 0, 1, 2`，纵轴显示 `-1.0, -0.5, 0, 0.5, 1.0`。
- 画布边界在端点刻度外保留少量空间，避免端点刻度压住边框。
- ML 柱状图纵轴为 `0-80`；OL 柱状图纵轴为 `0-40`，刻度间隔为 10。
- 点层以 600 dpi 栅格化，文字、坐标轴和边框在 PDF 中保持矢量。

## 四类分子状态

```text
Unsaturated and reduced:  NOSC < 0  且 (DBE-O)/C > 0
Unsaturated and oxidized: NOSC >= 0 且 (DBE-O)/C > 0
Saturated and reduced:    NOSC < 0  且 (DBE-O)/C <= 0
Saturated and oxidized:   NOSC >= 0 且 (DBE-O)/C <= 0
```

## 输出

```text
<prefix>.pdf
<prefix>.png
<prefix>_source_data.xlsx
```

源数据工作簿包含：

```text
Scatter_data
Stacked_bar_data
Metadata
```

## 质量检查

运行后必须检查：

1. 六个工作簿和 18 个 Leachate × Dose × Category 组合均被识别。
2. 左上、左下区域文字没有被边框裁切。
3. 横纵坐标端点刻度没有压在边框角点。
4. OL 柱状图显示 `0, 10, 20, 30, 40`。
5. PNG 为 600 dpi，PDF 为单页，源数据包含散点和柱状图数据。

示例图：

```text
assets/Fig_S12_example.png
assets/Fig_S12_example.pdf
```

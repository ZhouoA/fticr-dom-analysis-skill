# FT-ICR DOM Analysis Skills

这个仓库保存用于 FT-ICR MS / DOM 数据处理的 Codex skills。当前包含两个主要能力：

1. `$fticr-dom-analysis`：给分子式表格补充分子性质、VK 分类、PMD/Gephi 分析文件。
2. `$vk-figure`：从含 `O/C`、`H/C`、`RI` 的样品 CSV 文件夹生成论文级 Van Krevelen RI 合并图。

## 1. 分子性质分析：`$fticr-dom-analysis`

用途：处理 FT-ICR MS / DOM 分子式表格，保留原始列，并追加分子性质分析结果。

主要输出列：

```text
ΔG0cox
λ
VK
(DBE-O)/C
```

典型调用：

```text
用 $fticr-dom-analysis 处理这个 FT-ICR MS 表格
```

脚本位置：

```text
scripts/molecular_property_analysis.py
scripts/molecular_PMD_analysis.py
scripts/gephi_analysis.py
```

命令示例：

```bash
python scripts/molecular_property_analysis.py input.xlsx output.xlsx
python scripts/molecular_property_analysis.py input.csv output.csv
python scripts/molecular_PMD_analysis.py processed
python scripts/gephi_analysis.py processed --clean
```

## 2. VK 绘图：`$vk-figure`

用途：当你有一批类似 `L10consensus_vk.csv` 这样的样品文件，每个文件中包含：

```text
O/C
H/C
RI
```

就可以调用 `$vk-figure` 自动完成 RI 分档检查、颜色分箱、VK 区域虚线、横向 RI 图例、合并图排版，并输出 **Adobe Illustrator 友好版** 文件。

典型调用：

```text
用 $vk-figure 读取这个文件夹，先检查 RI 分布并推荐分箱，然后按我选择的分箱画 VK 合并图
```

### 关键工作流

第一步：先检查 RI 分布，不直接画图。

```bash
Rscript skills/vk-figure/scripts/vk_figure_workflow.R --input 输入文件夹 --mode check
```

这一步会输出：

```text
输入文件夹/vk_figure_outputs/RI_classification_check/RI_quantiles_by_sample.csv
输入文件夹/vk_figure_outputs/RI_classification_check/candidate_bin_counts_by_sample.csv
输入文件夹/vk_figure_outputs/RI_classification_check/candidate_bin_counts_overall.csv
```

看这些表后，选择合适的 RI 分箱。默认候选包括：

```text
raw8              直接用原始 RI，8 档，适合当前 VK 图
raw6              直接用原始 RI，6 档，图例更简洁
original9         直接用原始 RI 套旧 9 档，容易过度集中在最低档
RIx10_original9   先 RI×10，再套旧 9 档
```

第二步：按选择的分箱画图。

```bash
Rscript skills/vk-figure/scripts/vk_figure_workflow.R --input 输入文件夹 --mode plot --scheme raw8
```

如果你想指定样品顺序：

```bash
Rscript skills/vk-figure/scripts/vk_figure_workflow.R --input 输入文件夹 --mode plot --scheme raw8 --order L10consensus_vk,L114consensus_vk,L130consensus_vk,L138consensus_vk,L20consensus_vk,L22consensus_vk,L25consensus_vk,L28consensus_vk
```

如果你想使用自定义 breaks 和 labels：

```bash
Rscript skills/vk-figure/scripts/vk_figure_workflow.R ^
  --input 输入文件夹 ^
  --mode plot ^
  --breaks "-Inf,0.00002,0.00004,0.00006,0.00010,0.00020,0.00050,0.001,Inf" ^
  --labels "<0.00002|[0.00002,0.00004)|[0.00004,0.00006)|[0.00006,0.00010)|[0.00010,0.00020)|[0.00020,0.00050)|[0.00050,0.001)|>=0.001"
```

注意：`labels` 之间用 `|` 分隔，因为区间标签里面本身有逗号。

### VK-figure 的绘图规范

`$vk-figure` 默认会按这次最终版的风格输出：

- 样品名直接使用表格文件名，不自动做 ML/OL 重命名。
- 根据 `RI` 做颜色分档，并先输出分箱统计供你选择。
- 使用 Nature 风格 RI 配色。
- 使用紧凑横向 RI 色带图例，放在合并图上方。
- 每个小图右下角写 `n=` 数量。
- 每行第一个面板外侧添加 `a`、`b` 等面板标注。
- 点层栅格化为 600 dpi，文字、坐标轴、虚线、边框和图例仍保持矢量。
- 输出文件一定是 Illustrator 友好版，避免 Adobe Illustrator 打开时特别卡。

### VK-figure 输出文件

默认输出目录：

```text
输入文件夹/vk_figure_outputs
```

主要文件：

```text
combined_vk_RI_AI_friendly.pdf
combined_vk_RI_AI_friendly.svg
combined_vk_RI_AI_friendly.png
combined_vk_RI_AI_friendly.tiff
all_samples_RI_bin_counts.csv
每个样品_RI_bin_counts.csv
```

建议在 Adobe Illustrator 中优先打开：

```text
combined_vk_RI_AI_friendly.pdf
```

如果仍然卡，可以打开 SVG，或者用 PNG/TIFF 作为排版参考。

## R 依赖

`$vk-figure` 需要以下 R 包：

```r
install.packages(c("ggplot2", "patchwork", "ragg", "svglite", "ggrastr"))
```

其中 `ggrastr` 用于只栅格化散点层，这是 Illustrator 友好版的关键。

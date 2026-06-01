# group-vk-figure 中文说明

`group-vk-figure` 用于把 FT-ICR MS / DOM 数据中已经统计好的 Group 和 VK 分类结果，绘制成论文用的两联堆叠柱状图。图形格式与当前已经确定的版本一致：左边为 Group，右边为 VK，两个图并排放在同一张画布里，图例在各自柱状图上方。

## 输入数据

输入文件可以是 `.xlsx` 或 `.csv`。表格至少需要包含以下列：

```text
Sample
Dimension
Category
RI sum
```

其中：

- `Sample` 是样品名，例如 `ML-0-1`、`ML-0-2`、`ML-0-3`。
- `Dimension` 为 `Group` 或 `VK`。
- `Category` 为具体分类名称。
- `RI sum` 为该分类的 RI 总和，脚本会自动乘以 100，转换为 `RI (%)`。

三个平行样品会自动按样品名最后的 `-1`、`-2`、`-3` 合并，例如：

```text
ML-0-1、ML-0-2、ML-0-3 取平均后显示为 ML-0
OL-1-1、OL-1-2、OL-1-3 取平均后显示为 OL-1
```

## 运行方法

在仓库根目录下运行：

```bash
Rscript skills/group-vk-figure/scripts/group_vk_stacked_figure.R --input-summary 输入文件.xlsx
```

指定输出文件夹和文件名前缀：

```bash
Rscript skills/group-vk-figure/scripts/group_vk_stacked_figure.R ^
  --input-summary 输入文件.xlsx ^
  --output-dir 输出文件夹 ^
  --prefix DOM_Group_VK_ML_OL_stacked
```

默认输出到输入文件所在目录下的：

```text
Group_VK_RI_stacked_figures
```

## 输出文件

脚本会同时输出：

```text
<prefix>.svg
<prefix>.pdf
<prefix>.tiff
<prefix>.png
<prefix>_source_data.csv
```

建议投稿排版或 Adobe Illustrator 修改时优先使用 `.svg` 或 `.pdf`。

## 图形长宽

当前固定尺寸为：

```text
宽度：16.93 in
高度：5.64 in
比例：宽度约为高度的 3 倍
布局：一排两个图，Group 在左，VK 在右
```

这个尺寸用于和前面已经做好的图保持一致。若要和其它面板拼图，优先保持高度不变。

## 字号设置

当前固定字号为：

```text
坐标标题：18 pt，加粗
坐标刻度数字：14 pt
横坐标样品名称：14 pt
图例文字：10 pt
```

坐标标题统一为：

```text
RI (%)
```

图上不显示 `Group` 或 `VK` 的面板标题。

## 柱状图和坐标轴

```text
Y 轴范围：0-100
Y 轴刻度：0、25、50、75、100
柱子宽度：0.68
柱子分段边线：白色，0.18 pt
面板边框：黑色，0.70 pt
坐标刻度线：黑色，0.45 pt
```

## 图例设置

图例放在对应柱状图的上方。

Group 图例为一排：

```text
CHO
CHON
CHONS
CHOS
Others
```

VK 图例为两排，顺序为：

```text
Lipids
Aliphatic/proteins
Lignin/CRAM-like structures
Carbohydrates
Unsaturated hydrocarbons
Aromatic structures
Tannin
Others
```

图例色块为正方形：

```text
宽：3.4 mm
高：3.4 mm
```

## Group 配色

```text
CHO     #5B8DB8
CHON    #D89070
CHONS   #78A978
CHOS    #C6A15B
Others  #B8B8B8
```

## VK 配色

```text
Lipids                         #7FA6C9
Aliphatic/proteins             #E2B47A
Lignin/CRAM-like structures    #8F8CC0
Carbohydrates                  #86B8B2
Unsaturated hydrocarbons       #A7C8A2
Aromatic structures            #C78282
Tannin                         #B996C6
Others                         #B7B7B7
```

## R 依赖

需要安装：

```r
install.packages(c("readxl", "readr", "dplyr", "tidyr", "ggplot2", "patchwork", "ragg", "svglite"))
```

## 结果检查

脚本运行结束后会在终端输出 QA 表。每个样品的 Group 和 VK 堆叠总和应接近：

```text
100
```

如果明显不是 100，通常说明输入表中的 `RI sum` 不是完整分类总和，或部分分类名称没有正确对应到预设分类中。

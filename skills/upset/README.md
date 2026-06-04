# upset：FT-ICR MS DOM 分子式 UpSet 图绘图 skill

这个 skill 用来把已经完成去重和三平行稳定筛选的 FT-ICR MS DOM 分子式文件，绘制成论文投稿可用的 Nature 风格 UpSet diagram。

## 这个 skill 能做什么

它会读取 ML 和 OL 在不同预臭氧剂量下的稳定 assigned molecular formulas，并分别输出两张 UpSet 图：

- 第一张：ML 的分子式交集图。
- 第二张：OL 的分子式交集图。

最终图包含三部分：

1. 左侧彩色横向柱：每个剂量组的 formula count。
2. 右上灰色柱状图：不同剂量组合的 exclusive intersection size。
3. 右下 matrix：显示每根交集柱对应哪些剂量组。

## 输入文件要求

输入文件夹中应包含 8 个条件文件：

```text
ML-0.csv
ML-0.5.csv
ML-0.8.csv
ML-1.csv
OL-0.csv
OL-0.5.csv
OL-0.8.csv
OL-1.csv
```

也支持 `.xlsx` 或 `.xls`。

文件需要有分子式列，常见列名均可自动识别：

```text
Formula
Molecular Formula
molecular_formula
formula
Assigned formula
```

注意：这些文件应已经是每个条件最终用于分析的 stable molecular formulas。本 skill 不再重新做三平行交集筛选，也不再重新去重。

## 颜色对应关系

ML 图：

| 剂量 | 颜色 |
|---|---|
| 1 | 粉红 `#E5086A` |
| 0.5 | 橙色 `#D35F27` |
| 0.8 | 紫色 `#604E98` |
| 0 | 蓝绿色 `#046586` |

OL 图：

| 剂量 | 颜色 |
|---|---|
| 1 | 红色 `#E41A1C` |
| 0.8 | 绿色 `#6BAF45` |
| 0 | 浅红色 `#F07F7F` |
| 0.5 | 橙色 `#F5A623` |

右侧 intersection bar 统一为灰色；matrix 的行背景、圆点和连接线与对应剂量颜色匹配，但背景会降低饱和度，避免过艳。

## 如何调用

在 Codex 里可以直接说：

```text
调用 upset，读取这个文件夹，帮我画 ML 和 OL 的 UpSet 图
```

也可以明确给路径：

```text
调用 upset，输入文件夹为 C:\...\01汇总筛选3，输出到 UpSet_nature_matched
```

脚本运行命令示例：

```powershell
Rscript upset/scripts/make_upset_nature_matched.R `
  --input_dir "C:\Users\周周\Desktop\NCFT\02DOM数据处理\01汇总筛选3" `
  --output_dir "C:\Users\周周\Desktop\NCFT\02DOM数据处理\01汇总筛选3\UpSet_nature_matched"
```

## 输出文件

运行后会生成：

```text
ML_upset_nature_matched.pdf
ML_upset_nature_matched.png
OL_upset_nature_matched.pdf
OL_upset_nature_matched.png
upset_nature_matched_set_size_audit.csv
ML_upset_nature_matched_intersections.csv
OL_upset_nature_matched_intersections.csv
```

其中：

- PDF 为 Illustrator 友好版，适合后期排版。
- PNG 为 600 dpi，适合预览和投稿检查。
- `set_size_audit.csv` 用于检查每个剂量组的 formula count。
- `intersections.csv` 用于检查每根 UpSet 交集柱对应的组合和数量。

## 最终图样式

最终图采用白色背景、黑色坐标轴、灰色 intersection 柱、彩色 set-size bar 和剂量匹配的 matrix 点线。整体布局为横向论文版，适合 Supplementary Figure 或主文扩展图使用。

## 投稿 source data 建议

如果 Nature Communications 或其他期刊要求 source data，建议精简为两个 sheet：

1. `set sizes`：包含 leachate、dose、formula_count。
2. `intersections`：包含 leachate、intersection_order、combination、dose membership、intersection_size。

通常不需要把所有 molecular formula 长名单全部放入 Fig. source data，除非编辑部明确要求。

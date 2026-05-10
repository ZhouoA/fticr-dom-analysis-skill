# FT-ICR 分子特性分析 Skill

这是一个用于处理 FT-ICR MS / DOM 分子式表格的 Codex skill。它可以读取 `.csv`、`.xlsx`、`.xls` 文件，保留原始表格所有列，并在末尾追加分子特性分析结果。

## Skill 名称

在 Codex 中调用：

```text
$fticr-dom-analysis
```

示例：

```text
用 $fticr-dom-analysis 处理这个 FT-ICR MS 表格
```

## 主要功能

- 支持 CSV 和 Excel 表格。
- Excel 不指定 sheet 时，自动处理所有工作表，并保留原 sheet 名。
- 优先读取元素列：`C`, `H`, `N`, `O`, `S`, `P`, `Cl`, `Br`。
- 如果没有元素列，则从 `MolForm` 解析分子式组成。
- 计算 `ΔG0cox`。
- 计算 O2-based substrate-explicit model 的 `λ`。
- 对含 `Cl` 或 `Br` 的卤代分子，`ΔG0cox` 正常计算，`λ` 留空。
- 对 `C <= 0` 或模型不适用的行，相关结果留空。
- 按 Van Krevelen 条件生成 `VK` 分子类别。
- 计算 `(DBE-O)/C`。

## 输出列

输出表格保留原始所有列，并只追加以下列：

```text
ΔG0cox
λ
VK
(DBE-O)/C
```

## 直接运行脚本

脚本位于：

```text
scripts/molecular_property_analysis.py
```

命令示例：

```bash
python scripts/molecular_property_analysis.py input.xlsx output.xlsx
python scripts/molecular_property_analysis.py input.xlsx output.xlsx --sheet Sheet1
python scripts/molecular_property_analysis.py input.csv output.csv
```

## VK 分类规则

按以下条件顺序匹配，未匹配的归为 `Other`：

```text
Lipids:        0 <= O/C < 0.3     and 1.5 <= H/C <= 2.0
Aliphatic:     0.3 <= O/C < 0.67  and 1.5 <= H/C <= 2.2
Lignin:        0.1 < O/C <= 0.67  and 0.7 <= H/C < 1.5
Carbohydrates: 0.67 <= O/C <= 1.2 and 1.5 <= H/C <= 2.4
Unsaturated:   0 <= O/C <= 0.1    and 0.7 <= H/C < 1.5
Aromatic:      0 <= O/C <= 0.67   and 0.2 <= H/C < 0.7
Tannin:        0.67 < O/C <= 1.0  and 0.6 <= H/C < 1.5
Other:         all unmatched rows
```

## 依赖

需要 Python 以及：

```bash
pip install pandas openpyxl
```

Codex 内置的 spreadsheet Python runtime 通常已经包含这些依赖。
 
## PMD network analysis

After generating the molecular-property workbooks, run:

```bash
python scripts/molecular_PMD_analysis.py processed
```

The input directory should contain `network_edge*.csv`, `reaction_delta.csv`,
and analysis workbooks named like `生物段MLA_fticr_dom_analysis.xlsx`.

This workflow creates Source and Target row-preserving match tables, then writes
VK and Group reaction statistics. Count columns are grouped together, RI-sum
columns are multiplied by 100 and named `RI_sum（%）`, Dataset sum rows and
reaction-group sum rows are added, and all `_sum` rows are bolded. `VK_stats`
includes `Other`; `Group_stats` counts non-`CHO`/`CHON`/`CHONS`/`CHOS` formulas
as `Other`. It also creates `*_percent_of_dataset_sum.xlsx` workbooks, where
each numeric value is divided by the matching Dataset `_sum` row value and
multiplied by 100.

## Gephi analysis

After PMD matching, run:

```bash
python scripts/gephi_analysis.py processed --clean
```

The script writes Gephi-ready files to `processed/gephi`: VK node tables,
Group node tables, and labeled edge tables. Node tables contain `ID`, `Label`,
`type`, and `color`; edge tables keep `Source`, `Target`, and `Reaction`, then
add `label`, `label2`, and `color`. The workflow includes the local color
palettes for VK classes, Group classes, and reaction-label classes.

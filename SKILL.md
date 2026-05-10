---
name: fticr-dom-analysis
description: 分析 FT-ICR MS / DOM 分子式表格的分子特性。Use this skill when the user wants molecular property analysis for CSV or Excel formula tables, including ΔG0cox, O2-based λ, Van Krevelen category (VK), (DBE-O)/C, multi-sheet Excel handling, and formula-derived table augmentation from element columns or MolForm.
---

# FT-ICR 分子特性分析

## Overview

Use this skill for FT-ICR MS / DOM molecular property analysis. It processes molecular formula tables and appends four analysis columns: `ΔG0cox`, `λ`, `VK`, and `(DBE-O)/C`.

功能包括：

- 读取 `.csv`、`.xlsx`、`.xls` 分子式表格。
- Excel 不指定 `--sheet` 时自动处理所有工作表，并保留原 sheet 名。
- 从已有元素列或 `MolForm` 解析 `C`, `H`, `N`, `O`, `S`, `P`, `Cl`, `Br`。
- 计算 NOSC-derived `ΔG0cox`。
- 计算 O2-based substrate-explicit model 的 `λ`，含卤素或不适用行留空。
- 按 Van Krevelen 条件添加 `VK` 分子类别。
- 计算 `(DBE-O)/C`。

## Workflow

1. Locate the input table and choose an output path.
2. Run `scripts/molecular_property_analysis.py` with the Codex bundled Python when available, because it includes spreadsheet dependencies.
3. Verify the output keeps all original columns and appends exactly `ΔG0cox`, `λ`, `VK`, and `(DBE-O)/C`.
4. For Excel workbooks, confirm all expected worksheets are present.

## Command

```bash
python scripts/molecular_property_analysis.py input.xlsx output.xlsx
python scripts/molecular_property_analysis.py input.xlsx output.xlsx --sheet Sheet1
python scripts/molecular_property_analysis.py input.csv output.csv
```

## PMD Network Workflow

Use `scripts/molecular_PMD_analysis.py` after molecular-property workbooks have
already been generated. The input directory should contain:

- `network_edge*.csv` files with `Source`, `Target`, and `Reaction` columns.
- `reaction_delta.csv` with a `reaction` column, used as the reaction order.
- Matching analysis workbooks named `生物段{tag}_fticr_dom_analysis.xlsx`,
  where `{tag}` matches the suffix of `network_edge{tag}.csv`.

Command:

```bash
python scripts/molecular_PMD_analysis.py processed
```

Outputs:

- `source_reaction_matches/source_reaction_{tag}_matched_analysis.xlsx`
- `target_reaction_matches/target_reaction_{tag}_matched_analysis.xlsx`
- `source_reaction_matches/source_reaction_VK_Group_statistics.xlsx`
- `target_reaction_matches/target_reaction_VK_Group_statistics.xlsx`
- `source_reaction_matches/source_reaction_VK_Group_statistics_percent_of_dataset_sum.xlsx`
- `target_reaction_matches/target_reaction_VK_Group_statistics_percent_of_dataset_sum.xlsx`

The Source/Target match tables preserve every network edge row in order and do
not deduplicate formulas. The statistics workbooks include `VK_stats` and
`Group_stats`, count columns first, RI-sum percentage columns second, per-Dataset
sum rows, and reaction-group sum rows such as `1-CH_sum`, `1+CHO_sum`,
`1-CHON_sum`, and `1+CHOS_sum`. `VK_stats` includes `Other`; `Group_stats`
counts non-`CHO`/`CHON`/`CHONS`/`CHOS` formulas as `Other`. Sum rows are bolded.
The percent-of-Dataset statistics divide each numeric value by the corresponding
Dataset sum-row value and multiply by 100.

## Element Handling

- Prefer existing element columns: `C`, `H`, `N`, `O`, `S`, `P`, `Cl`, `Br`.
- Missing element columns are treated as `0`.
- If no element columns exist, parse `MolForm` for `C`, `H`, `N`, `O`, `S`, `P`, `Cl`, and `Br`.

## Thermodynamic Rules

- Rows with `C <= 0` output blank values for `ΔG0cox` and `λ`.
- Rows containing `Cl` or `Br` still receive `ΔG0cox`, but `λ` is blank because the O2-based SXM model does not explicitly support halogen products.
- Other thermodynamically inapplicable rows also leave `λ` blank.

## VK Classification

Assign `VK` using the first matching rule below; rows that do not match any rule are `Other`.

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

Use existing `O/C` and `H/C` columns when present; otherwise compute them from element counts.

## Output

The output table keeps every original column unchanged and appends only:

```text
ΔG0cox
λ
VK
(DBE-O)/C
```

`(DBE-O)/C` is calculated as `(DBE - O) / C`; if required values are missing or `C` is zero, leave it blank.

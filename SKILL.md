---
name: fticr-dom-analysis
description: Process FT-ICR MS molecular formula tables from CSV or Excel files by computing ΔG0cox, O2-based λ, Van Krevelen category (VK), and (DBE-O)/C. Use when the user wants DOM/FT-ICR MS data processing, multi-sheet Excel handling, thermodynamic outputs, VK biochemical class assignment, or formula-derived table augmentation from element columns or MolForm.
---

# FT-ICR DOM Analysis

## Overview

Use this skill to process FT-ICR MS molecular formula tables and append four analysis columns: `ΔG0cox`, `λ`, `VK`, and `(DBE-O)/C`.

The bundled script supports `.csv`, `.xlsx`, and `.xls` input/output. For Excel workbooks, no `--sheet` means process all worksheets and preserve sheet names; specifying `--sheet` processes only that sheet.

## Workflow

1. Locate the input table and choose an output path.
2. Run `scripts/calculate_deltaG_lambda.py` with the Codex bundled Python when available, because it includes spreadsheet dependencies.
3. Verify the output keeps all original columns and appends exactly `ΔG0cox`, `λ`, `VK`, and `(DBE-O)/C`.
4. For Excel workbooks, confirm all expected worksheets are present.

## Command

```bash
python scripts/calculate_deltaG_lambda.py input.xlsx output.xlsx
python scripts/calculate_deltaG_lambda.py input.xlsx output.xlsx --sheet Sheet1
python scripts/calculate_deltaG_lambda.py input.csv output.csv
```

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
Lipids:        0 <= O/C < 0.3    and 1.5 <= H/C <= 2.0
Aliphatic:     0.3 <= O/C < 0.67 and 1.5 <= H/C <= 2.2
Lignin:        0.1 < O/C <= 0.67 and 0.7 <= H/C < 1.5
Carbohydrates: 0.67 <= O/C <= 1.2 and 1.5 <= H/C <= 2.4
Unsaturated:   0 <= O/C <= 0.1   and 0.7 <= H/C < 1.5
Aromatic:      0 <= O/C <= 0.67  and 0.2 <= H/C < 0.7
Tannin:        0.67 < O/C <= 1.0 and 0.6 <= H/C < 1.5
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

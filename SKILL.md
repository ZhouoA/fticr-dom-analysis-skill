---
name: fticr-dom-analysis
description: Analyze FT-ICR MS / DOM molecular formula tables, PMD reaction outputs, Gephi network files, and Raw FTICRMS UpSet figures. Use this skill when the user wants formula-table augmentation with Delta G0cox, O2-based lambda, Van Krevelen category (VK), (DBE-O)/C, PMD precursor/product matching summaries, Gephi node/edge exports, or the `upset` command for publication-style YL/OL/ML formula-overlap UpSet plots from FT-ICR MS Excel files.
---

# FT-ICR DOM Analysis

## Overview

Use this skill for reproducible FT-ICR MS / DOM formula-table analysis and figure-ready source data.

Supported workflows:

- Molecular-property augmentation: append `Delta G0cox`, `lambda`, `VK`, and `(DBE-O)/C`.
- PMD reaction matching and summary tables.
- Gephi node and edge exports for DOM molecular networks.
- `upset`: Raw FTICRMS YL/OL/ML molecular formula overlap UpSet plots.

## Molecular Property Workflow

Run `scripts/molecular_property_analysis.py` for `.csv`, `.xlsx`, or `.xls` formula tables.

```bash
python scripts/molecular_property_analysis.py input.xlsx output.xlsx
python scripts/molecular_property_analysis.py input.xlsx output.xlsx --sheet Sheet1
python scripts/molecular_property_analysis.py input.csv output.csv
```

Rules:

- Prefer existing element columns: `C`, `H`, `N`, `O`, `S`, `P`, `Cl`, `Br`.
- Treat missing element columns as `0`.
- If no element columns exist, parse `MolForm`.
- Use existing `O/C` and `H/C` when present; otherwise compute them from element counts.
- Leave `Delta G0cox` and `lambda` blank when `C <= 0`.
- Leave `lambda` blank for halogen-containing formulas because the O2-based substrate-explicit model does not explicitly support halogen products.
- Calculate `(DBE-O)/C` as `(DBE - O) / C`; leave blank if required values are missing or `C` is zero.

VK classification uses the first matching rule:

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

## PMD Network Workflow

Run `scripts/molecular_PMD_analysis.py` after molecular-property workbooks have been generated.

Input directory should contain:

- `network_edge*.csv` files with `Source`, `Target`, and `Reaction` columns.
- `reaction_delta.csv` with a `reaction` column.
- Matching analysis workbooks named for the local workflow.

Command:

```bash
python scripts/molecular_PMD_analysis.py processed
```

Outputs include source/target matched workbooks and VK/Group reaction statistics under:

```text
source_reaction_matches/
target_reaction_matches/
```

## Gephi Workflow

Run `scripts/gephi_analysis.py` after PMD matching has produced network formula matches.

```bash
python scripts/gephi_analysis.py processed --clean
```

Outputs are written to `processed/gephi` by default and include:

```text
nodes_{tag}_VK.xlsx
nodes_{tag}_Group.xlsx
network_edge{tag}_labeled.xlsx
```

## upset Workflow

Use `scripts/upset.R` when the user asks for `upset`, Raw FTICRMS UpSet, formula-overlap UpSet, or a YL/OL/ML molecular formula intersection figure.

Expected input:

- One Excel workbook per sample in `--input_dir`.
- Each workbook must contain a `Formula` column.
- Default sample order is `YL,OL,ML`.
- Default input filenames are `YL.xlsx`, `OL.xlsx`, and `ML.xlsx`.

Command:

```bash
Rscript scripts/upset.R \
  --input_dir path/to/FTICRMS/Raw \
  --output_dir path/to/output \
  --prefix Raw_FTICRMS_UpSet \
  --sample_order YL,OL,ML \
  --width_in 7.2 \
  --height_in 4.6 \
  --dpi 600
```

Outputs:

```text
Raw_FTICRMS_UpSet.pdf
Raw_FTICRMS_UpSet.svg
Raw_FTICRMS_UpSet.png
Raw_FTICRMS_UpSet.tiff
Raw_FTICRMS_UpSet_intersection_sizes.csv
Raw_FTICRMS_UpSet_set_sizes.csv
Raw_FTICRMS_UpSet_formula_membership.csv
```

Style invariants:

- Keep the lower matrix panel aligned to the upper barplot coordinate space.
- Keep `YL/OL/ML` as a separate narrow label column so row labels do not change the matrix coordinate frame.
- Draw inactive grey points first, then blue connector lines, then active blue points.
- Use black visible axes and tick marks.
- Export editable SVG/PDF plus high-resolution PNG/TIFF.

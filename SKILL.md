---
name: fticr-dom-analysis
description: Analyze FT-ICR MS / DOM molecular formula tables, PMD reaction outputs, Gephi network files, Raw FTICRMS UpSet figures, and shared-formula Raw VK figures. Use this skill when the user wants formula-table augmentation with Delta G0cox, O2-based lambda, Van Krevelen category (VK), (DBE-O)/C, PMD precursor/product matching summaries, Gephi node/edge exports, the `upset` command, the `raw-VK图` command for a publication-style Van Krevelen diagram of molecular formulas shared by YL/OL/ML, or the `Violin plot图` command for Nature-style YL/ML/OL molecular-property violin plots with Wilcoxon-BH significance letters.
---

# FT-ICR DOM Analysis

## Overview

Use this skill for reproducible FT-ICR MS / DOM formula-table analysis and figure-ready source data.

Supported workflows:

- Molecular-property augmentation: append `Delta G0cox`, `lambda`, `VK`, and `(DBE-O)/C`.
- PMD reaction matching and summary tables.
- Gephi node and edge exports for DOM molecular networks.
- `upset`: Raw FTICRMS YL/OL/ML molecular formula overlap UpSet plots.
- `raw-VK图`: Van Krevelen plots of molecular formulas shared by raw YL/OL/ML.
- `Violin plot图`: Nature-style molecular-property violin plots for MW, DBE, O/C, H/C, N/C, S/C, AImod, and NOSC across YL/ML/OL.

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

## raw-VK图 Workflow

Use `skills/raw-vk-figure/scripts/raw_vk_figure.R` when the user asks for
`raw-VK图`, Raw shared VK, or the Van Krevelen distribution of formulas shared by
YL, OL, and ML.

```bash
Rscript skills/raw-vk-figure/scripts/raw_vk_figure.R \
  --input_dir path/to/FTICRMS/Raw \
  --output_dir path/to/output \
  --prefix Raw_Shared_VK \
  --sample_order YL,OL,ML
```

The script identifies the three-way formula intersection, writes source data, and exports
editable SVG/PDF plus PNG/TIFF. Read `skills/raw-vk-figure/SKILL.md` for the fixed axis,
boundary, point, annotation, and spacing rules. Use
`skills/raw-vk-figure/assets/Raw_Shared_VK.svg` as the exact visual reference.

## Violin plot图 Workflow

Use `skills/violin-plot/scripts/violin_plot_workflow.R` when the user asks for `Violin plot图`, molecular-property violin plots, or the current YL/ML/OL Raw_Molecular_Properties_Violin figure.

```bash
Rscript skills/violin-plot/scripts/violin_plot_workflow.R \
  --input_csv path/to/FigS5a_VK_points.csv \
  --figure_dir path/to/output/figures \
  --table_dir path/to/output/tables \
  --prefix Raw_Molecular_Properties_Violin \
  --width_mm 183 \
  --height_mm 100 \
  --dpi 600
```

The script generates a 2 x 4 Nature-style violin figure for `MW`, `DBE`, `O/C`, `H/C`, `N/C`, `S/C`, `AImod`, and `NOSC` across `YL`, `ML`, and `OL`. It exports editable SVG/PDF, high-resolution PNG/TIFF, source data, RI-weighted summary values, compact significance letters, Wilcoxon-BH statistics, QA, and caption text. Read `skills/violin-plot/SKILL.md` for the fixed colors, axis presets, significance-letter convention, and input schema. Use `skills/violin-plot/assets/Raw_Molecular_Properties_Violin.svg` and `.png` as the exact visual reference.

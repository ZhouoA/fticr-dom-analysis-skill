---
name: raw-vk-figure
description: Generate the shared-formula Raw Van Krevelen diagram for YL, ML, and OL FT-ICR MS datasets. Use when the user asks for `raw-VK图`, Raw shared VK, three-leachate shared molecular formulas, or a publication-ready Van Krevelen plot of formulas shared by YL/ML/OL, with the established purple points, 13 grey short-dashed VK boundaries, matched axis spacing, dynamic n value, source data, and editable SVG/PDF exports.
---

# Raw VK Figure

Use the bundled R script to reproduce the established Van Krevelen diagram of molecular
formulas shared by three raw leachates.

## Input

Prefer direct workbook mode:

```text
INPUT_DIR/
  YL.xlsx
  OL.xlsx
  ML.xlsx
```

Each workbook must contain `Formula` plus either:

```text
O/C and H/C
```

or:

```text
C, H, and O
```

The script also accepts a prepared CSV containing `Formula`, `O_C`, and `H_C`.

## Command

Directly identify formulas shared by YL, OL, and ML:

```bash
Rscript skills/raw-vk-figure/scripts/raw_vk_figure.R \
  --input_dir path/to/FTICRMS/Raw \
  --output_dir path/to/output \
  --prefix Raw_Shared_VK \
  --sample_order YL,OL,ML
```

Reuse prepared source data:

```bash
Rscript skills/raw-vk-figure/scripts/raw_vk_figure.R \
  --input_csv path/to/Raw_Shared_VK_source_data.csv \
  --output_dir path/to/output \
  --prefix Raw_Shared_VK
```

## Fixed Style

- Keep the coordinate limits at `O/C = -0.02 to 1.22` and `H/C = -0.05 to 2.55`.
- Keep ticks at `0.3` for O/C and `0.5` for H/C.
- Draw all 13 VK classification boundaries with `#737373`, width `0.4`, and short dashes `2 2`.
- Draw shared formulas in purple `#7A6AA8` at alpha `0.8`.
- Keep x-axis tick-number spacing visually equal to y-axis tick-number spacing.
- Keep `O/C`-to-number spacing visually equal to `H/C`-to-number spacing.
- Keep `Shared` at the upper left and the dynamic `n=` label at the lower right.
- Do not change data, coordinate limits, boundary positions, or annotation text while polishing.

Use `assets/Raw_Shared_VK.svg` as the exact visual reference.

## Output

```text
Raw_Shared_VK.svg
Raw_Shared_VK.pdf
Raw_Shared_VK.png
Raw_Shared_VK.tiff
Raw_Shared_VK_source_data.csv
Raw_Shared_VK_plot_QA.csv
```

The SVG keeps text, points, axes, and dashed boundaries editable.

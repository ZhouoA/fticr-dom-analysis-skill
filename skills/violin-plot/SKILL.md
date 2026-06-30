---
name: violin-plot
description: Generate Nature-style FT-ICR MS DOM molecular-property violin plots for YL/ML/OL groups. Use this skill when the user asks for `Violin plot图`, molecular property violin plots, MW/DBE/O_C/H_C/N_C/S_C/AImod/NOSC distributions, Wilcoxon-BH significance letters, or the current Raw_Molecular_Properties_Violin figure style.
---

# Violin Plot Figure

Use `scripts/violin_plot_workflow.R` to reproduce the YL/ML/OL molecular-property violin figure.

## Input

The input CSV should contain one row per molecular formula and at least these columns:

```text
sample_id
Formula
C
H
O
N
S
Mass
RI
DBE
O_C
H_C
AImod
NOSC
```

Rules:

- `sample_id` must contain `YL`, `ML`, and `OL`.
- `MW` is calculated from `Mass`.
- `N/C` is calculated as `N / C`.
- `S/C` is calculated as `S / C`.
- RI-weighted means are exported to the summary table, but the figure uses compact significance letters above the violins.
- Pairwise statistics use two-sided Wilcoxon rank-sum tests and Benjamini-Hochberg FDR correction across all 24 comparisons.

## Command

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

Windows PowerShell example:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\R.exe" --vanilla --slave `
  -f "skills\violin-plot\scripts\violin_plot_workflow.R" --args `
  --input_csv "C:\path\to\FigS5a_VK_points.csv" `
  --figure_dir "C:\path\to\figures" `
  --table_dir "C:\path\to\tables" `
  --prefix "Raw_Molecular_Properties_Violin" `
  --width_mm 183 `
  --height_mm 100 `
  --dpi 600
```

If R packages are installed in a custom library, pass:

```bash
--r_lib path/to/R/library
```

## Outputs

```text
Raw_Molecular_Properties_Violin.pdf
Raw_Molecular_Properties_Violin.svg
Raw_Molecular_Properties_Violin.png
Raw_Molecular_Properties_Violin.tiff
Raw_Molecular_Properties_Violin_source_data.csv
Raw_Molecular_Properties_Violin_summary.csv
Raw_Molecular_Properties_Violin_significance_letters.csv
Raw_Molecular_Properties_Violin_Wilcoxon_BH_results.csv
Raw_Molecular_Properties_Violin_QA.csv
Raw_Molecular_Properties_Violin_caption.txt
```

## Figure Layout

Panel order:

```text
c MW      d DBE      e O/C      f H/C
g N/C     h S/C      i AImod    j NOSC
```

Group order and colors:

```text
YL  #26A69A
ML  #5E8EC8
OL  #E87878
```

Style rules:

- Use 2 x 4 panels at Nature double-column size, default `183 x 100 mm`.
- Use semi-transparent violins, white boxplots, and white mean dots.
- Put compact significance letters above violins.
- Use the same letter when two groups are not significantly different after BH correction.
- Keep axes black, horizontal gridlines light grey, and no duplicate legend.
- Export editable SVG/PDF and 600 dpi PNG/TIFF.

## Axis Presets

The current figure uses these manually curated y-axis ticks:

```text
MW:    250, 500, 750
DBE:   0, 10, 20
O/C:   0.0, 0.5, 1.0
H/C:   automatic pretty breaks
N/C:   0.0, 0.1, 0.2, 0.3
S/C:   0.0, 0.1, 0.2, 0.3
AImod: 0.0, 0.5, 1.0, 1.5
NOSC:  -2, 0, 2
```

Keep these axis choices when reproducing the current paper figure unless the user explicitly asks for different limits or ticks.

## R Dependencies

```r
install.packages(c("ggplot2", "patchwork", "svglite", "ragg"))
```

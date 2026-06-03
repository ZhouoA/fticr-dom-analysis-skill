---
name: 2-ven-violin
description: Generate a publication-ready combined figure for ML-0 vs OL-0 DOM analysis, including a Venn diagram, shared-formula Van Krevelen scatter plot, and significant molecular-property violin plots with RI-weighted mean annotations. Use when the user has Venn counts/shared formula outputs, shared VK source data, and completed Wilcoxon/weighted-mean files and wants the final a-j combined figure.
---

# 2-Ven-Violin

Use this skill to combine three existing analysis outputs into one Nature-style figure:

```text
a  Venn diagram        b  Shared VK scatter

c  MW      d  DBE      e  O/C      f  H/C
g  N/C     h  S/C      i  AImod    j  NOSC
```

The skill does **not** recompute Wilcoxon tests, replicate intersections, or weighted means. It only
draws the final combined figure from completed source files.

## Expected Input Folder

Pass `--input` as the parent folder that contains these subfolders:

```text
INPUT_DIR/
  Venn_ML0_OL0/
    ML0_OL0_venn_counts.csv
  Shared_VK_scatter/
    Shared_5662_VK_scatter_source_data.csv
  Wilcoxon rank-sum test/
    ML0_OL0_final_property_values_long_format.csv
    ML0_OL0_RI_weighted_mean_Wilcoxon_summary.csv
```

The default output folder is:

```text
INPUT_DIR/Combined_shared_VK_violin_figure
```

## Script

Run with R:

```bash
Rscript skills/2-ven-violin/scripts/2_ven_violin_workflow.R --input INPUT_DIR
```

Optional arguments:

```bash
Rscript skills/2-ven-violin/scripts/2_ven_violin_workflow.R ^
  --input INPUT_DIR ^
  --output OUTPUT_DIR ^
  --prefix ML0_OL0_shared_VK_violin_combined ^
  --dpi 600
```

## Figure Style

- `a`: Venn diagram of ML and OL formula overlap.
- `b`: shared Formula VK scatter, without RI colour mapping.
- `c-j`: violin plots for significant molecular properties.
- Violin panels use `ML` and `OL` on the x-axis, not `ML-0` and `OL-0`.
- Violin labels show RI-weighted mean annotations, e.g. `DBEwa=6.419`.
- Panel labels are lowercase letters without parentheses: `a`, `b`, `c`, ...
- The final a-panel Venn circle diameter is tuned to about 4/5 of the b-panel y-axis length.
- The b-panel axis is aligned with the e/f column grid in the combined layout.

## Output

The script writes:

```text
ML0_OL0_shared_VK_violin_combined.pdf
ML0_OL0_shared_VK_violin_combined.png
ML0_OL0_shared_VK_violin_combined.tiff
```

Use the PDF for Illustrator editing and the PNG/TIFF as high-resolution layout references.

## Required R Packages

```r
install.packages(c("ggplot2", "patchwork", "ragg", "ggrastr"))
```

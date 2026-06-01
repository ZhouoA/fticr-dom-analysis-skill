---
name: group-vk-figure
description: Draw publication-ready paired stacked bar figures for FT-ICR MS / DOM Group and VK category summaries. Use this skill when the user has a summary table containing Sample, Dimension, Category, and RI sum columns and wants Group and VK stacked RI (%) bar charts with replicate averaging, fixed ML/OL sample order, Nature-style colors, top legends, and SVG/PDF/PNG/TIFF exports.
---

# Group/VK Figure

Use this skill to draw the paired Group and VK stacked bar figure used for DOM RI
composition summaries. The figure contains two panels in one row:

```text
Group stacked bar chart | VK stacked bar chart
```

The expected input is a summary table produced from DOM data. It must contain:

```text
Sample
Dimension
Category
RI sum
```

`Dimension` must contain `Group` and/or `VK`. Replicates are averaged by removing the
final `-1`, `-2`, or `-3` suffix from `Sample`.

## Workflow

1. Locate the summary workbook or CSV.
2. Run the bundled R script with `--input-summary`.
3. Verify that the QA table reports each stacked bar total close to `100`.
4. Use the exported SVG/PDF for manuscript layout or Illustrator editing.

## Command

```bash
Rscript skills/group-vk-figure/scripts/group_vk_stacked_figure.R --input-summary INPUT.xlsx
```

For an explicit output folder and file prefix:

```bash
Rscript skills/group-vk-figure/scripts/group_vk_stacked_figure.R ^
  --input-summary INPUT.xlsx ^
  --output-dir OUTPUT_DIR ^
  --prefix DOM_Group_VK_ML_OL_stacked
```

If the repository is not the current working directory, pass the full script path.

## Fixed Category Orders

Group legend and stacking order:

```text
CHO
CHON
CHONS
CHOS
Others
```

VK legend and stacking order:

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

## Fixed Sample Order

The default sample order is:

```text
ML-0
ML-0.2
ML-0.5
ML-1
OL-0
OL-0.2
OL-0.5
OL-1
```

Pass `--sample-order` to override it:

```bash
Rscript skills/group-vk-figure/scripts/group_vk_stacked_figure.R ^
  --input-summary INPUT.xlsx ^
  --sample-order "ML-0,ML-0.2,ML-0.5,ML-1,OL-0,OL-0.2,OL-0.5,OL-1"
```

## Figure Specifications

Keep these values unless the user explicitly asks to revise the established style:

```text
Canvas width: 16.93 in
Canvas height: 5.64 in
Panel layout: one row, two equal-width panels
Y axis title: RI (%)
Y axis range: 0-100
Y axis breaks: 0, 25, 50, 75, 100
Axis title font size: 18 pt, bold
Axis tick and sample label font size: 14 pt
Legend text font size: 10 pt
Legend key: square, 3.4 mm x 3.4 mm
Panel border: black, 0.70 pt
Axis tick width: 0.45 pt
Bar width: 0.68
Bar segment outline: white, 0.18 pt
Export formats: SVG, PDF, TIFF 600 dpi LZW, PNG 240 dpi, source CSV
```

Do not add visible panel titles such as `Group` or `VK`. The legends identify each panel.

## Colors

Group colors:

```text
CHO     #5B8DB8
CHON    #D89070
CHONS   #78A978
CHOS    #C6A15B
Others  #B8B8B8
```

VK colors:

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

## Output

By default, outputs are written to:

```text
<input folder>/Group_VK_RI_stacked_figures
```

The script creates:

```text
<prefix>.svg
<prefix>.pdf
<prefix>.tiff
<prefix>.png
<prefix>_source_data.csv
```

## Required R Packages

Install missing packages in R:

```r
install.packages(c("readxl", "readr", "dplyr", "tidyr", "ggplot2", "patchwork", "ragg", "svglite"))
```

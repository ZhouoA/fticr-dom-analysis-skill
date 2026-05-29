---
name: vk-figure
description: Generate publication-ready Van Krevelen RI figures from FT-ICR MS / DOM CSV folders. Use this skill when the user provides VK-style tables with O/C, H/C, and RI columns and wants RI bin checking, user-selected RI color classes, compact horizontal RI legends, two-row/four-column VK panels, and Illustrator-friendly PDF/SVG/PNG/TIFF exports.
---

# VK Figure

Use this skill to build publication-ready Van Krevelen scatter figures from a folder of
FT-ICR MS / DOM CSV files. The expected input is one CSV per sample, with at least:

```text
O/C
H/C
RI
```

The workflow is intentionally two-stage:

1. **Check RI classification first**: summarize RI quantiles and candidate bin counts.
2. **Plot after the user chooses bins**: generate a compact multi-panel VK figure with an
   RI colorbar legend and Illustrator-friendly exports.

Do not rename sample labels unless the user explicitly asks. By default, panel labels use
the input CSV file stem.

## Core Workflow

1. Locate the input folder containing the sample CSV files.
2. Run the bundled R script in `check` mode to create RI distribution and bin-count tables.
3. Show the user the candidate bin summaries and ask which bin scheme to use.
4. Run the same script in `plot` mode with the selected scheme or custom breaks/labels.
5. Verify the output PNG visually and prefer the `*_AI_friendly.pdf` for Adobe Illustrator.

## Script

Use:

```bash
Rscript skills/vk-figure/scripts/vk_figure_workflow.R --input INPUT_DIR --mode check
Rscript skills/vk-figure/scripts/vk_figure_workflow.R --input INPUT_DIR --mode plot --scheme raw8
```

If the repository is not the current working directory, pass the full script path.

## RI Bin Selection

The script writes check files into:

```text
INPUT_DIR/vk_figure_outputs/RI_classification_check
```

Key files:

```text
RI_quantiles_by_sample.csv
candidate_bin_counts_by_sample.csv
candidate_bin_counts_overall.csv
```

Default schemes:

```text
raw8: direct RI, eight bins; good default for the user's current VK figures
raw6: direct RI, six bins; simpler legend for dense manuscript figures
original9: direct RI, original narrow bins; often too skewed unless data are scaled
RIx10_original9: RI multiplied by 10, then original nine bins
```

When direct RI is appropriate, prefer `raw8` unless the check table shows severe imbalance.

## Custom Breaks

If the user gives exact breaks and labels, use:

```bash
Rscript skills/vk-figure/scripts/vk_figure_workflow.R ^
  --input INPUT_DIR ^
  --mode plot ^
  --breaks "-Inf,0.00002,0.00004,0.00006,0.00010,0.00020,0.00050,0.001,Inf" ^
  --labels "<0.00002|[0.00002,0.00004)|[0.00004,0.00006)|[0.00006,0.00010)|[0.00010,0.00020)|[0.00020,0.00050)|[0.00050,0.001)|>=0.001"
```

Use `|` between labels to avoid comma ambiguity inside interval labels.

## Figure Style

The final figure should match the established workflow:

- Use the Nature-style RI palette bundled in the script.
- Use a compact horizontal RI colorbar centered above the panel grid.
- Use dashed VK region boundaries.
- Use sample labels inside each panel at the upper-left.
- Add `n=` at the lower-right of each panel.
- Add row tags `a`, `b`, ... outside the first panel of each row.
- Export AI-friendly outputs by rasterizing only the scatter points at 600 dpi while
  keeping text, axes, dashed boundaries, and the colorbar editable as vector objects.

## Required R Packages

The script checks for these packages and stops with a clear message if any are missing:

```text
ggplot2
patchwork
ragg
svglite
ggrastr
```

Install missing packages in R:

```r
install.packages(c("ggplot2", "patchwork", "ragg", "svglite", "ggrastr"))
```

## Output

Plot outputs are written to:

```text
INPUT_DIR/vk_figure_outputs
```

Important files:

```text
combined_vk_RI_AI_friendly.pdf
combined_vk_RI_AI_friendly.svg
combined_vk_RI_AI_friendly.png
combined_vk_RI_AI_friendly.tiff
*_RI_bin_counts.csv
```

Use the PDF for Illustrator editing. If Illustrator is still slow, use the SVG or the
600 dpi PNG/TIFF as layout references.

---
name: marginal-group
description: "Generate the confirmed `marginal+group` FT-ICR MS composite figure for three paired comparisons: Van Krevelen scatterplots with marginal densities and Removed/Produced/Shared formula fates, plus compound-class and formula-class percentage stacked bars. Use when the user asks for `marginal+group`, VK marginal + group/VK bars, pretreatment molecular fate, A/O molecular fate, or an editable PDF/SVG reproduction of this three-pair layout."
---

# Marginal + Group

Use R and the bundled scripts. Classify formulas by presence/absence only:

- `Removed`: detected only in the left sample.
- `Produced`: detected only in the right sample.
- `Shared`: detected in both samples.

Do not use RI for classification or percentage bars.

## Run

```bash
Rscript skills/marginal-group/scripts/marginal_group_figure.R \
  --input_dir path/to/input \
  --output_dir path/to/output \
  --prefix Pretreatment_VK_Class_Composite \
  --sample_order YL,ML,OL \
  --left_files YL.xlsx,ML.xlsx,OL.xlsx \
  --right_files YLr.csv,MLr.csv,OLr.csv \
  --left_ids YL,ML,OL \
  --right_ids YLr,MLr,OLr
```

All six tables must contain `Formula`, `O/C`, `H/C`, `VK`, and `Group`.

Use `left_files=YLr.csv,MLr.csv,OLr.csv` and
`right_files=YLo.csv,MLo.csv,OLo.csv` for the A/O comparison.

## Fixed visual contract

- Panel `a`: three VK plots with top/right marginal densities.
- Colors: Removed `#4E79A7`, Produced `#E15759`, Shared `#59A14F`.
- Panel `b`: VK compound-class percentages.
- Panel `c`: CHO/CHON/CHONS/CHOS/Other percentages.
- Formula pools are ordered Removed, Produced, Shared within each age.
- Axes and ticks are black with linewidth `0.40`.
- Panel `a` legends remain inside the lower-right VK region.
- Panel `b/c` x-axis text is `6.4 pt`; legend swatches are square.
- Figure size defaults to `9 x 6.6 in`.
- Preserve editable text and vector objects in PDF/SVG.

Use `assets/Pretreatment_VK_Class_Composite_AI.pdf` and
`assets/Pretreatment_VK_Class_Composite_preview.png` as the confirmed reference.

## Outputs

```text
<prefix>.pdf
<prefix>.svg
<prefix>.png
<prefix>.tiff
<prefix>_formula_classification.csv
<prefix>_stage_counts.csv
<prefix>_pair_QA.csv
<prefix>_class_contributions_source_data.csv
<prefix>_class_contributions_QA.csv
<prefix>_caption.txt
```

Require every pair balance and every percentage sum QA check to pass before delivery.

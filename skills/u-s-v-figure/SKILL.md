---
name: u-s-v-figure
description: "Generate the confirmed Nature-style U-S-V composite figure from three FT-ICR MS datasets: UpSet formula overlap, shared-formula Van Krevelen diagram, and eight molecular-property violin panels with Wilcoxon-BH significance letters. Use when the user asks for U-S-V图, U-S-V figure, UpSet-Shared VK-Violin composite, or wants to reproduce the current FigS6_reproduced layout as editable SVG/PDF."
---

# U-S-V Figure

Use the bundled two-step workflow. Keep the plotting backend in R.

## 1. Prepare three Excel workbooks

```bash
python skills/u-s-v-figure/scripts/prepare_usv_inputs.py \
  --input_dir path/to/FTICRMS/Raw \
  --output_dir path/to/usv_inputs \
  --sample_ids YL,ML,OL
```

Expected files are `<sample_id>.xlsx`. Each workbook must contain `Formula`, `Mass`,
`Intensity`, `RI`, `DBE`, `O/C`, `H/C`, `N/C`, `S/C`, `AImod`, `NOSC`, and element
columns `C,H,O,N,S,P,Cl`. Missing `Br` is filled with zero.

## 2. Draw the composite

```bash
Rscript skills/u-s-v-figure/scripts/u_s_v_figure_workflow.R \
  --input_dir path/to/usv_inputs \
  --figure_dir path/to/output/figures \
  --table_dir path/to/output/tables \
  --prefix FigS6_reproduced \
  --sample_order YL,ML,OL \
  --upset_order YL,OL,ML \
  --figure_number "Fig. S6." \
  --sample_description "young (YL), medium (ML), and old (OL) leachates" \
  --width_mm 183 \
  --height_mm 165 \
  --dpi 600
```

`sample_order` controls violin x-axis order and colors. `upset_order` controls the
UpSet membership order and must contain the same three IDs.

## Fixed visual contract

- Panel `a`: UpSet bars, set-size bars, and membership matrix share one aligned rank axis.
- Panel `b`: purple shared-formula points and 13 grey short-dashed VK boundaries.
- Panels `c-j`: MW, DBE, O/C, H/C, N/C, S/C, AImod, and NOSC.
- Colors by sample order: teal `#26A69A`, blue `#5E8EC8`, red `#E87878`.
- White boxes show quartiles and medians; white dots show arithmetic means.
- Letters show compact groups from two-sided Wilcoxon tests with BH-FDR correction.
- The confirmed Raw axis presets are retained, including `c: 250,500,750`,
  `f: 0,1,2,3`, and `g/h: 0.0,0.1,0.2,0.3`.
- SVG/PDF remain editable; PNG/TIFF are exported at 600 dpi by default.

## Outputs

The workflow writes:

```text
<prefix>.svg
<prefix>.pdf
<prefix>.png
<prefix>.tiff
<prefix>_a_intersection_sizes.csv
<prefix>_a_set_sizes.csv
<prefix>_a_formula_membership.csv
<prefix>_b_shared_VK.csv
<prefix>_c-j_molecular_properties.csv
<prefix>_c-j_summary.csv
<prefix>_c-j_significance_letters.csv
<prefix>_c-j_Wilcoxon_BH_results.csv
<prefix>_QA.csv
<prefix>_caption.txt
```

Use `assets/U_S_V_figure_example.svg` as the exact editable visual reference.

# Fig. S12: NOSC-(DBE-O)/C distributions and RI-based molecular-state composition

parse_args <- function(args) {
  options <- list(
    input_dir = NULL,
    output_dir = NULL,
    prefix = "Fig_S12",
    dpi = 600
  )
  if ("--help" %in% args || "-h" %in% args) {
    cat(
      "Usage:\n",
      "  Rscript dbe_o_c_nosc_figure.R --input_dir DIR ",
      "[--output_dir DIR] [--prefix Fig_S12] [--dpi 600]\n"
    )
    quit(status = 0)
  }
  i <- 1
  while (i <= length(args)) {
    key <- sub("^--", "", args[[i]])
    if (!key %in% names(options) || i == length(args)) {
      stop("Unknown option or missing value: ", args[[i]])
    }
    options[[key]] <- args[[i + 1]]
    i <- i + 2
  }
  if (is.null(options$input_dir)) {
    stop("Missing required option: --input_dir")
  }
  options$dpi <- as.integer(options$dpi)
  options
}

args <- parse_args(commandArgs(trailingOnly = TRUE))

required_packages <- c(
  "readxl", "dplyr", "tidyr", "stringr", "ggplot2",
  "cowplot", "ggrastr", "openxlsx", "ragg", "scales"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(ggplot2)
  library(cowplot)
  library(ggrastr)
  library(openxlsx)
  library(ragg)
  library(scales)
})

input_dir <- normalizePath(args$input_dir, winslash = "/", mustWork = TRUE)
output_dir <- if (is.null(args$output_dir)) input_dir else args$output_dir
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)
prefix <- args$prefix
output_pdf <- file.path(output_dir, paste0(prefix, ".pdf"))
output_png <- file.path(output_dir, paste0(prefix, ".png"))
output_xlsx <- file.path(output_dir, paste0(prefix, "_source_data.xlsx"))

normalize_name <- function(x) {
  x |>
    str_replace_all("–", "-") |>
    str_to_lower() |>
    str_replace_all("[^a-z0-9]", "")
}

find_column <- function(data, aliases, required = TRUE) {
  idx <- match(normalize_name(aliases), normalize_name(names(data)))
  idx <- idx[!is.na(idx)]
  if (length(idx) > 0) return(names(data)[idx[1]])
  if (required) {
    stop(
      "Cannot identify column. Expected one of: ",
      paste(aliases, collapse = ", "),
      "\nAvailable columns: ",
      paste(names(data), collapse = ", ")
    )
  }
  NULL
}

parse_element <- function(formula, element) {
  matched <- str_match(as.character(formula), paste0(element, "([0-9]*)"))
  ifelse(
    is.na(matched[, 1]),
    0,
    ifelse(matched[, 2] == "", 1, as.numeric(matched[, 2]))
  )
}

files <- list.files(
  input_dir,
  pattern = "^final_classification_for_analysis_.*\\.(xlsx|xls)$",
  full.names = TRUE,
  ignore.case = TRUE
)
files <- files[!str_starts(basename(files), "~\\$")]

if (length(files) != 6) {
  cat("\nRecognized files:\n")
  print(basename(files))
  if (length(files) > 0) {
    for (file in files) {
      cat("\nFILE:", basename(file), "\n")
      cat("SHEETS:", paste(excel_sheets(file), collapse = " | "), "\n")
      for (sheet in excel_sheets(file)) {
        preview <- read_excel(file, sheet = sheet, n_max = 3)
        cat(" ", sheet, ":", paste(names(preview), collapse = " | "), "\n")
      }
    }
  }
  stop("Expected six ML/OL classification workbooks. Data audit printed above.")
}

read_one_sheet <- function(file, sheet, leachate, dose, category) {
  data <- read_excel(file, sheet = sheet)
  names(data) <- str_trim(names(data))

  formula_col <- find_column(
    data,
    c("Formula", "MolForm", "Molecular Formula", "molecular formula"),
    required = FALSE
  )
  nosc_col <- find_column(data, "NOSC")
  ratio_col <- find_column(
    data,
    c("(DBE-O)/C", "(DBE–O)/C", "DBE-O/C", "DBE_O_C"),
    required = FALSE
  )
  dbe_o_col <- find_column(data, c("DBE-O", "DBE–O", "DBE_O"), required = FALSE)
  c_col <- find_column(data, "C", required = FALSE)

  if (is.null(ratio_col)) {
    if (is.null(dbe_o_col)) {
      stop(
        "Cannot calculate (DBE-O)/C in ", basename(file), " / ", sheet,
        ": DBE-O is missing.\nColumns: ", paste(names(data), collapse = ", ")
      )
    }
    if (is.null(c_col)) {
      if (is.null(formula_col)) {
        stop(
          "Cannot calculate (DBE-O)/C in ", basename(file), " / ", sheet,
          ": both C and molecular formula are missing.\nColumns: ",
          paste(names(data), collapse = ", ")
        )
      }
      carbon <- parse_element(data[[formula_col]], "C")
    } else {
      carbon <- suppressWarnings(as.numeric(data[[c_col]]))
    }
    dbe_o_c <- suppressWarnings(as.numeric(data[[dbe_o_col]])) / carbon
  } else {
    dbe_o_c <- suppressWarnings(as.numeric(data[[ratio_col]]))
  }

  ri <- rep(NA_real_, nrow(data))
  if (category == "Precursor") {
    ri_col <- find_column(
      data,
      c("mean_RI_before", "RI", "RI (%)", "Relative intensity")
    )
    ri <- suppressWarnings(as.numeric(data[[ri_col]]))
  } else if (category == "Product") {
    ri_col <- find_column(
      data,
      c("mean_RI_after", "RI", "RI (%)", "Relative intensity")
    )
    ri <- suppressWarnings(as.numeric(data[[ri_col]]))
  }

  tibble(
    Leachate = leachate,
    Dose = dose,
    Category = category,
    Formula = if (is.null(formula_col)) NA_character_ else as.character(data[[formula_col]]),
    NOSC = suppressWarnings(as.numeric(data[[nosc_col]])),
    DBE_O_C = dbe_o_c,
    RI = ri,
    Source_file = basename(file),
    Source_sheet = sheet
  ) |>
    filter(is.finite(NOSC), is.finite(DBE_O_C))
}

scatter_parts <- list()
part_index <- 1

for (file in files) {
  filename <- basename(file)
  leachate <- str_extract(filename, "(?i)ML|OL") |> str_to_upper()
  dose_text <- str_match(
    filename,
    "(?i)vs\\.?\\s*(0\\.5|0\\.8|1(?:\\.0)?)"
  )[, 2]

  sheets <- excel_sheets(file)
  precursor_sheet <- sheets[str_detect(str_to_lower(sheets), "precursor")][1]
  product_sheet <- sheets[str_detect(str_to_lower(sheets), "product")][1]
  resistant_sheet <- sheets[str_detect(str_to_lower(sheets), "resistant")][1]

  if (
    is.na(leachate) || is.na(dose_text) ||
      is.na(precursor_sheet) || is.na(product_sheet) || is.na(resistant_sheet)
  ) {
    cat("\nCannot identify grouping for:", filename, "\n")
    cat("Sheets:", paste(sheets, collapse = " | "), "\n")
    for (sheet in sheets) {
      preview <- read_excel(file, sheet = sheet, n_max = 3)
      cat(" ", sheet, ":", paste(names(preview), collapse = " | "), "\n")
    }
    stop("File/group identification failed. Audit printed above.")
  }

  dose <- as.numeric(dose_text)
  sheet_map <- c(
    Precursor = precursor_sheet,
    Product = product_sheet,
    Resistant = resistant_sheet
  )

  for (category in names(sheet_map)) {
    scatter_parts[[part_index]] <- read_one_sheet(
      file, sheet_map[[category]], leachate, dose, category
    )
    part_index <- part_index + 1
  }
}

scatter_data <- bind_rows(scatter_parts) |>
  mutate(
    Leachate = factor(Leachate, levels = c("ML", "OL")),
    Dose = factor(Dose, levels = c(0.5, 0.8, 1.0)),
    Category = factor(Category, levels = c("Precursor", "Product", "Resistant")),
    Panel = case_when(
      Leachate == "ML" & Dose == "0.5" ~ "ML-0.5",
      Leachate == "ML" & Dose == "0.8" ~ "ML-0.8",
      Leachate == "ML" & Dose == "1" ~ "ML-1",
      Leachate == "OL" & Dose == "0.5" ~ "OL-0.5",
      Leachate == "OL" & Dose == "0.8" ~ "OL-0.8",
      Leachate == "OL" & Dose == "1" ~ "OL-1"
    )
  )

expected_groups <- tidyr::expand_grid(
  Leachate = factor(c("ML", "OL"), levels = c("ML", "OL")),
  Dose = factor(c(0.5, 0.8, 1.0), levels = c(0.5, 0.8, 1.0)),
  Category = factor(
    c("Precursor", "Product", "Resistant"),
    levels = c("Precursor", "Product", "Resistant")
  )
)
actual_groups <- scatter_data |>
  distinct(Leachate, Dose, Category)
if (nrow(anti_join(expected_groups, actual_groups, by = c("Leachate", "Dose", "Category"))) > 0) {
  print(actual_groups)
  stop("Not all required Leachate x Dose x Category groups were identified.")
}

state_levels <- c(
  "Saturated and oxidized",
  "Saturated and reduced",
  "Unsaturated and oxidized",
  "Unsaturated and reduced"
)

bar_source <- scatter_data |>
  filter(Category %in% c("Precursor", "Product")) |>
  mutate(
    Category = factor(as.character(Category), levels = c("Precursor", "Product")),
    State = case_when(
      NOSC < 0 & DBE_O_C > 0 ~ "Unsaturated and reduced",
      NOSC >= 0 & DBE_O_C > 0 ~ "Unsaturated and oxidized",
      NOSC < 0 & DBE_O_C <= 0 ~ "Saturated and reduced",
      NOSC >= 0 & DBE_O_C <= 0 ~ "Saturated and oxidized"
    ),
    State = factor(State, levels = state_levels)
  )

if (any(is.na(bar_source$RI))) {
  bad <- bar_source |> filter(is.na(RI)) |> distinct(Source_file, Source_sheet)
  print(bad)
  stop("Missing RI values were found in precursor/product data.")
}

bar_summary <- bar_source |>
  group_by(Leachate, Dose, Category, State) |>
  summarise(
    Formula_number = n(),
    RI_percent = sum(RI, na.rm = TRUE) * 100,
    .groups = "drop"
  ) |>
  complete(
    Leachate, Dose, Category,
    State = factor(state_levels, levels = state_levels),
    fill = list(Formula_number = 0, RI_percent = 0)
  ) |>
  mutate(
    Category = factor(Category, levels = c("Precursor", "Product")),
    x_pos = case_when(
      Category == "Precursor" & Dose == "0.5" ~ 1,
      Category == "Precursor" & Dose == "0.8" ~ 2,
      Category == "Precursor" & Dose == "1" ~ 3,
      Category == "Product" & Dose == "0.5" ~ 5,
      Category == "Product" & Dose == "0.8" ~ 6,
      Category == "Product" & Dose == "1" ~ 7
    )
  ) |>
  arrange(Leachate, Category, Dose, State)

point_colors <- c(
  Precursor = "#4C78A8",
  Product = "#D6655A",
  Resistant = "#58A56B"
)
state_colors <- c(
  "Saturated and oxidized" = "#7FA6C9",
  "Saturated and reduced" = "#D9A06F",
  "Unsaturated and oxidized" = "#86B89A",
  "Unsaturated and reduced" = "#A993C3"
)

x_limits <- c(-2.06, 2.06)
y_limits <- c(-1.04, 1.04)

region_labels <- tibble(
  x = c(-1.30, 1.30, -1.30, 1.30),
  y = c(0.86, 0.86, -0.86, -0.86),
  label = c(
    "Unsaturated\nand reduced",
    "Unsaturated\nand oxidized",
    "Saturated\nand reduced",
    "Saturated\nand oxidized"
  )
)

theme_scatter <- theme_classic(base_family = "Arial", base_size = 7.5) +
  theme(
    panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.55),
    axis.line = element_blank(),
    axis.ticks = element_line(linewidth = 0.45, colour = "black"),
    axis.ticks.length = unit(1.6, "mm"),
    axis.title = element_text(size = 8.4, face = "bold", colour = "black"),
    axis.text = element_text(size = 7.2, colour = "black"),
    plot.title = element_text(size = 8.5, face = "bold", hjust = 0.5),
    legend.position = "none",
    plot.margin = margin(5, 6, 5, 6)
  )

make_scatter <- function(leachate, dose, show_y = TRUE, show_x = TRUE) {
  plot_data <- scatter_data |>
    filter(Leachate == leachate, Dose == as.character(dose)) |>
    arrange(Category)

  title_text <- if (dose == 1) {
    paste0(leachate, "-1")
  } else {
    paste0(leachate, "-", dose)
  }

  p <- ggplot(plot_data, aes(NOSC, DBE_O_C, colour = Category)) +
    ggrastr::geom_point_rast(
      size = 0.56,
      alpha = 0.35,
      stroke = 0,
      raster.dpi = 600
    ) +
    geom_vline(xintercept = 0, linetype = "dashed", linewidth = 0.35, colour = "#555555") +
    geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.35, colour = "#555555") +
    geom_text(
      data = region_labels,
      aes(x, y, label = label),
      inherit.aes = FALSE,
      size = 2.15,
      lineheight = 0.9,
      colour = "#4F4F4F",
      family = "Arial"
    ) +
    scale_colour_manual(values = point_colors, drop = FALSE) +
    scale_x_continuous(
      limits = x_limits,
      breaks = c(-2, -1, 0, 1, 2),
      expand = expansion(mult = 0)
    ) +
    scale_y_continuous(
      limits = y_limits,
      breaks = c(-1.0, -0.5, 0, 0.5, 1.0),
      expand = expansion(mult = 0)
    ) +
    labs(
      title = title_text,
      x = if (show_x) "NOSC" else NULL,
      y = if (show_y) "(DBE\u2013O)/C" else NULL
    ) +
    theme_scatter

  if (!show_y) {
    p <- p + theme(axis.text.y = element_blank(), axis.ticks.y = element_blank())
  }
  if (!show_x) {
    p <- p + theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())
  }
  p
}

p_ml_05 <- make_scatter("ML", 0.5, show_y = TRUE, show_x = TRUE)
p_ml_08 <- make_scatter("ML", 0.8, show_y = TRUE, show_x = TRUE)
p_ml_10 <- make_scatter("ML", 1.0, show_y = TRUE, show_x = TRUE)
p_ol_05 <- make_scatter("OL", 0.5, show_y = TRUE, show_x = TRUE)
p_ol_08 <- make_scatter("OL", 0.8, show_y = TRUE, show_x = TRUE)
p_ol_10 <- make_scatter("OL", 1.0, show_y = TRUE, show_x = TRUE)

legend_plot <- ggplot(
  tibble(
    x = 1:3,
    y = 1,
    Category = factor(
      c("Precursor", "Product", "Resistant"),
      levels = c("Precursor", "Product", "Resistant")
    )
  ),
  aes(x, y, colour = Category)
) +
  geom_point(size = 2.5) +
  scale_colour_manual(values = point_colors, drop = FALSE) +
  guides(
    colour = guide_legend(
      title = NULL,
      override.aes = list(size = 2.7, alpha = 1)
    )
  ) +
  theme_void(base_family = "Arial") +
  theme(
    legend.position = "top",
    legend.direction = "horizontal",
    legend.text = element_text(size = 8),
    legend.spacing.x = unit(2.5, "mm")
  )
point_legend <- cowplot::get_legend(legend_plot)

scatter_row_a <- plot_grid(
  p_ml_05, p_ml_08, p_ml_10,
  nrow = 1, align = "hv", axis = "tblr"
)
scatter_row_a <- ggdraw() +
  draw_plot(scatter_row_a, x = 0.028, y = 0, width = 0.968, height = 1) +
  draw_label("a", x = 0.002, y = 0.995, hjust = 0, vjust = 1, size = 10, fontface = "bold")

scatter_row_b <- plot_grid(
  p_ol_05, p_ol_08, p_ol_10,
  nrow = 1, align = "hv", axis = "tblr"
)
scatter_row_b <- ggdraw() +
  draw_plot(scatter_row_b, x = 0.028, y = 0, width = 0.968, height = 1) +
  draw_label("b", x = 0.002, y = 0.995, hjust = 0, vjust = 1, size = 10, fontface = "bold")

theme_bar <- theme_classic(base_family = "Arial", base_size = 7.5) +
  theme(
    panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.55),
    axis.line = element_blank(),
    axis.ticks = element_line(linewidth = 0.45, colour = "black"),
    axis.ticks.length = unit(1.6, "mm"),
    axis.title = element_text(size = 8.4, face = "bold", colour = "black"),
    axis.title.x = element_text(
      size = 8.4, face = "bold", colour = "black",
      margin = margin(t = 5)
    ),
    axis.title.y = element_text(
      size = 8.4, face = "bold", colour = "black",
      margin = margin(r = 8)
    ),
    axis.text = element_text(size = 7.2, colour = "black"),
    legend.position = "none",
    plot.margin = margin(7, 8, 7, 10)
  )

make_bar <- function(leachate, show_y = TRUE) {
  data <- bar_summary |> filter(Leachate == leachate)
  y_max <- if (leachate == "OL") 40 else 80
  y_pad <- if (leachate == "OL") 1.3 else 2.6
  y_breaks <- if (leachate == "OL") seq(0, 40, by = 10) else seq(0, 80, by = 20)
  ggplot(data, aes(x = x_pos, y = RI_percent, fill = State)) +
    geom_col(width = 0.72, colour = "white", linewidth = 0.18) +
    geom_vline(xintercept = 4, linetype = "dashed", linewidth = 0.4, colour = "#666666") +
    annotate(
      "text", x = 2, y = y_max * 0.955,
      label = paste0(leachate, "-Precursor"),
      size = 2.7, fontface = "bold", family = "Arial"
    ) +
    annotate(
      "text", x = 6, y = y_max * 0.955,
      label = paste0(leachate, "-Product"),
      size = 2.7, fontface = "bold", family = "Arial"
    ) +
    scale_fill_manual(values = state_colors, breaks = state_levels, drop = FALSE) +
    scale_x_continuous(
      breaks = c(1, 2, 3, 5, 6, 7),
      labels = c("0.5", "0.8", "1.0", "0.5", "0.8", "1.0"),
      limits = c(0.35, 7.65),
      expand = expansion(mult = 0)
    ) +
    scale_y_continuous(
      limits = c(-y_pad, y_max + y_pad),
      breaks = y_breaks,
      expand = expansion(mult = c(0, 0))
    ) +
    labs(
      x = "Ozone dosage (g O₃·(g DOC)⁻¹)",
      y = if (show_y) "RI (%)" else NULL
    ) +
    theme_bar +
    if (!show_y) {
      theme(axis.text.y = element_blank(), axis.ticks.y = element_blank())
    } else {
      theme()
    }
}

p_bar_ml <- make_bar("ML", show_y = TRUE)
p_bar_ol <- make_bar("OL", show_y = TRUE)

bar_legend_plot <- ggplot(
  tibble(
    x = 1:4,
    y = 1,
    State = factor(state_levels, levels = state_levels)
  ),
  aes(x, y, fill = State)
) +
  geom_col() +
  scale_fill_manual(values = state_colors, breaks = state_levels, drop = FALSE) +
  guides(fill = guide_legend(title = NULL, nrow = 2, byrow = TRUE)) +
  theme_void(base_family = "Arial") +
  theme(
    legend.position = "bottom",
    legend.text = element_text(size = 7.2),
    legend.key.size = unit(3.5, "mm"),
    legend.spacing.x = unit(2, "mm")
  )
bar_legend <- cowplot::get_legend(bar_legend_plot)

bar_row <- plot_grid(
  p_bar_ml, p_bar_ol,
  nrow = 1, align = "hv", axis = "tblr",
  rel_widths = c(1, 1)
)
bar_row <- ggdraw() +
  draw_plot(bar_row, x = 0.028, y = 0, width = 0.968, height = 0.97) +
  draw_label("c", x = 0.002, y = 0.995, hjust = 0, vjust = 1, size = 10, fontface = "bold")

final_figure <- plot_grid(
  point_legend,
  scatter_row_a,
  scatter_row_b,
  bar_row,
  bar_legend,
  ncol = 1,
  rel_heights = c(0.075, 0.84, 0.84, 0.78, 0.13)
)

figure_width_mm <- 200
figure_height_mm <- 220
figure_width_in <- figure_width_mm / 25.4
figure_height_in <- figure_height_mm / 25.4
pdf_temp <- file.path(output_dir, paste0(prefix, "_rendering.pdf"))

if (file.exists(pdf_temp)) unlink(pdf_temp)
grDevices::cairo_pdf(
  pdf_temp,
  width = figure_width_in,
  height = figure_height_in,
  family = "Arial"
)
print(final_figure)
dev.off()
pdf_candidates <- c(
  output_pdf,
  file.path(
    output_dir,
    paste0(prefix, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".pdf")
  )
)
pdf_written <- FALSE
for (candidate in pdf_candidates) {
  if (suppressWarnings(file.copy(pdf_temp, candidate, overwrite = TRUE))) {
    output_pdf <- candidate
    pdf_written <- TRUE
    break
  }
}
if (!pdf_written) {
  stop("The revised PDF could not be written to any output filename.")
}
if (basename(output_pdf) != paste0(prefix, ".pdf")) {
  warning(
    paste0(prefix, ".pdf is open; the revised PDF was saved as "),
    basename(output_pdf), "."
  )
}
unlink(pdf_temp)

ragg::agg_png(
  output_png,
  width = figure_width_in,
  height = figure_height_in,
  units = "in",
  res = args$dpi,
  background = "white"
)
print(final_figure)
dev.off()

scatter_export <- scatter_data |>
  transmute(
    Leachate = as.character(Leachate),
    Dose = as.numeric(as.character(Dose)),
    Category = as.character(Category),
    Formula,
    NOSC,
    `(DBE-O)/C` = DBE_O_C,
    RI,
    Source_file,
    Source_sheet
  )

bar_export <- bar_summary |>
  transmute(
    Leachate = as.character(Leachate),
    Dose = as.numeric(as.character(Dose)),
    Category = as.character(Category),
    State = as.character(State),
    Formula_number,
    `RI (%)` = RI_percent,
    x_position = x_pos
  )

metadata <- data.frame(
  Item = c(
    "Figure",
    "Scatter x-axis",
    "Scatter y-axis",
    "Scatter display x-range",
    "Scatter display y-range",
    "Stacked-bar calculation",
    "Saturated and oxidized",
    "Saturated and reduced",
    "Unsaturated and oxidized",
    "Unsaturated and reduced",
    "Scatter colours",
    "State colours"
  ),
  Definition = c(
    prefix,
    "NOSC",
    "(DBE-O)/C",
    paste(x_limits, collapse = " to "),
    paste(y_limits, collapse = " to "),
    "Sum of RI x 100 within each Leachate x Dose x Category x State; resistant excluded",
    "NOSC >= 0 and (DBE-O)/C <= 0",
    "NOSC < 0 and (DBE-O)/C <= 0",
    "NOSC >= 0 and (DBE-O)/C > 0",
    "NOSC < 0 and (DBE-O)/C > 0",
    paste(names(point_colors), point_colors, sep = "=", collapse = "; "),
    paste(names(state_colors), state_colors, sep = "=", collapse = "; ")
  ),
  stringsAsFactors = FALSE
)

wb <- createWorkbook()
addWorksheet(wb, "Scatter_data")
writeDataTable(wb, "Scatter_data", scatter_export, tableStyle = "TableStyleLight9")
freezePane(wb, "Scatter_data", firstRow = TRUE)
setColWidths(wb, "Scatter_data", 1:ncol(scatter_export), widths = "auto")

addWorksheet(wb, "Stacked_bar_data")
writeDataTable(wb, "Stacked_bar_data", bar_export, tableStyle = "TableStyleLight9")
freezePane(wb, "Stacked_bar_data", firstRow = TRUE)
setColWidths(wb, "Stacked_bar_data", 1:ncol(bar_export), widths = "auto")

addWorksheet(wb, "Metadata")
writeDataTable(wb, "Metadata", metadata, tableStyle = "TableStyleLight9")
setColWidths(wb, "Metadata", 1, 30)
setColWidths(wb, "Metadata", 2, 95)
saveWorkbook(wb, output_xlsx, overwrite = TRUE)

clipped_count <- scatter_data |>
  summarise(
    n = n(),
    outside = sum(
      NOSC < x_limits[1] | NOSC > x_limits[2] |
        DBE_O_C < y_limits[1] | DBE_O_C > y_limits[2]
    )
  )

cat("\nRecognized workbooks:\n")
print(basename(files))
cat("\nScatter groups and formula counts:\n")
print(
  scatter_data |>
    count(Leachate, Dose, Category, name = "Formula_number"),
  n = Inf
)
cat("\nStacked-bar RI summary:\n")
print(bar_summary, n = Inf)
cat(
  "\nScatter display range contains ",
  clipped_count$n - clipped_count$outside,
  " of ", clipped_count$n, " formulas; ",
  clipped_count$outside,
  " extreme values remain in source data but fall outside the common plotting window.\n",
  sep = ""
)
cat("\nOutput files:\n")
cat(normalizePath(output_pdf, winslash = "/", mustWork = FALSE), "\n")
cat(normalizePath(output_png, winslash = "/", mustWork = FALSE), "\n")
cat(normalizePath(output_xlsx, winslash = "/", mustWork = FALSE), "\n")

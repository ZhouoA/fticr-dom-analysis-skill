options(stringsAsFactors = FALSE)

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  values <- list(input_dir = ".", output_dir = NULL, prefix = "Fig_S8")
  i <- 1
  while (i <= length(args)) {
    key <- args[[i]]
    if (key %in% c("--input_dir", "--output_dir", "--prefix")) {
      if (i == length(args)) stop("Missing value for ", key, call. = FALSE)
      values[[sub("^--", "", key)]] <- args[[i + 1]]
      i <- i + 2
    } else {
      i <- i + 1
    }
  }
  if (is.null(values$output_dir)) {
    values$output_dir <- file.path(values$input_dir, paste0(values$prefix, "_VK_marginal"))
  }
  values
}

args <- parse_args()

required_packages <- c("openxlsx", "dplyr", "tidyr", "stringr", "ggplot2", "patchwork", "readr")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

library(openxlsx)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(patchwork)
library(readr)

input_dir <- normalizePath(args$input_dir, winslash = "/", mustWork = TRUE)
output_dir <- args$output_dir
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)

stage_levels <- c("Precursor", "Product", "Resistant")
stage_colors <- c(
  "Precursor" = "#4E79A7",
  "Product" = "#E15759",
  "Resistant" = "#59A14F"
)

normalize_col <- function(x) {
  x %>%
    trimws() %>%
    str_replace_all("\\s+", "_") %>%
    str_replace_all("\\.", "_") %>%
    str_replace_all("/", "_") %>%
    str_replace_all("[()]", "") %>%
    tolower()
}

find_col <- function(dat, candidates) {
  normalized <- normalize_col(names(dat))
  candidates_norm <- normalize_col(candidates)
  idx <- match(candidates_norm, normalized)
  idx <- idx[!is.na(idx)]
  if (length(idx) == 0) return(NA_character_)
  names(dat)[idx[1]]
}

parse_file_meta <- function(path) {
  nm <- tools::file_path_sans_ext(basename(path))
  leachate <- if (str_detect(nm, "ML0")) "ML" else if (str_detect(nm, "OL0")) "OL" else NA_character_
  dose <- str_match(nm, "vs\\.\\s*([0-9.]+)$")[, 2]
  if (is.na(leachate) || is.na(dose)) {
    stop("Cannot parse leachate/dose from file name: ", basename(path), call. = FALSE)
  }
  dose <- ifelse(dose == "1", "1.0", dose)
  list(leachate = leachate, dose = dose)
}

stage_from_sheet <- function(sheet) {
  s <- tolower(sheet)
  if (str_detect(s, "precursor")) return("Precursor")
  if (str_detect(s, "product")) return("Product")
  if (str_detect(s, "resistant")) return("Resistant")
  NA_character_
}

read_one_file <- function(path) {
  meta <- parse_file_meta(path)
  sheets <- openxlsx::getSheetNames(path)
  keep_sheets <- sheets[!is.na(vapply(sheets, stage_from_sheet, character(1)))]
  bind_rows(lapply(keep_sheets, function(sheet) {
    dat <- openxlsx::read.xlsx(path, sheet = sheet)
    oc_col <- find_col(dat, c("O/C", "O_C", "OC"))
    hc_col <- find_col(dat, c("H/C", "H_C", "HC"))
    formula_col <- find_col(dat, c("Formula", "Molecular Formula", "molecular_formula", "Assigned formula"))
    if (is.na(oc_col) || is.na(hc_col)) {
      stop("Missing O/C or H/C in ", basename(path), " sheet ", sheet, call. = FALSE)
    }
    tibble(
      source_file = basename(path),
      source_sheet = sheet,
      Leachate = meta$leachate,
      Dose = meta$dose,
      Stage = stage_from_sheet(sheet),
      Formula = if (!is.na(formula_col)) as.character(dat[[formula_col]]) else NA_character_,
      O_C = suppressWarnings(as.numeric(dat[[oc_col]])),
      H_C = suppressWarnings(as.numeric(dat[[hc_col]]))
    )
  }))
}

vk_segments <- tibble::tribble(
  ~x, ~xend, ~y, ~yend,
  0, 0.3, 2.0, 2.0,
  0.3, 0.67, 2.2, 2.2,
  0.67, 1.2, 2.4, 2.4,
  0, 1.2, 1.5, 1.5,
  0, 0.67, 0.7, 0.7,
  0, 0.67, 0.2, 0.2,
  0.1, 0.1, 0.7, 1.5,
  0.3, 0.3, 1.5, 2.2,
  0.67, 0.67, 0.2, 2.4,
  1.0, 1.0, 0.6, 1.5,
  1.2, 1.2, 1.5, 2.4,
  0, 0, 0.2, 2.0,
  0.67, 1.0, 0.6, 0.6
)

files <- list.files(input_dir, pattern = "^final_classification_for_analysis_.*\\.xlsx$", full.names = TRUE)
if (length(files) == 0) stop("No final classification xlsx files found in ", input_dir, call. = FALSE)

cat("Recognized input files and columns:\n")
for (f in files) {
  cat("\n", basename(f), "\n", sep = "")
  for (s in openxlsx::getSheetNames(f)) {
    dat_head <- openxlsx::read.xlsx(f, sheet = s, rows = 1:2)
    cat("  sheet=", s, "\n", sep = "")
    cat("  columns=", paste(names(dat_head), collapse = " | "), "\n", sep = "")
  }
}

raw_data <- bind_rows(lapply(files, read_one_file)) %>%
  filter(Stage %in% stage_levels) %>%
  mutate(
    Stage = factor(Stage, levels = stage_levels),
    Leachate = factor(Leachate, levels = c("ML", "OL")),
    Dose = factor(Dose, levels = c("0.5", "0.8", "1.0"))
  )

plot_data <- raw_data %>%
  filter(is.finite(O_C), is.finite(H_C), O_C >= 0, O_C <= 1.2, H_C >= 0, H_C <= 2.5)

raw_count_summary <- raw_data %>%
  count(Leachate, Dose, Stage, name = "raw_n") %>%
  complete(Leachate, Dose, Stage, fill = list(raw_n = 0)) %>%
  arrange(Leachate, Dose, Stage)

plotted_count_summary <- plot_data %>%
  count(Leachate, Dose, Stage, name = "plotted_n") %>%
  complete(Leachate, Dose, Stage, fill = list(plotted_n = 0)) %>%
  arrange(Leachate, Dose, Stage)

count_summary <- raw_count_summary %>%
  left_join(plotted_count_summary, by = c("Leachate", "Dose", "Stage")) %>%
  mutate(points_outside_axis_range = raw_n - plotted_n)

readr::write_csv(count_summary, file.path(output_dir, paste0(args$prefix, "_stage_counts.csv")))

cat("\nPoint counts by Leachate x Dose x Stage:\n")
print(count_summary, n = Inf)

theme_vk <- theme_classic(base_family = "Arial", base_size = 8) +
  theme(
    axis.line = element_line(linewidth = 0.65, colour = "black"),
    axis.ticks = element_line(linewidth = 0.65, colour = "black"),
    axis.ticks.length = unit(0.16, "cm"),
    axis.text = element_text(size = 9, colour = "black"),
    axis.title = element_text(size = 12, colour = "black", face = "bold"),
    plot.margin = margin(1, 1, 1, 1),
    legend.position = "none",
    panel.grid = element_blank()
  )

dose_label <- function(dose) {
  paste0(dose, " g O3\u00b7(g DOC)\u207b\u00b9")
}

make_panel <- function(dat, panel_label, raw_counts_panel) {
  leachate <- as.character(unique(dat$Leachate))
  dose <- as.character(unique(dat$Dose))
  counts <- raw_counts_panel %>%
    select(Stage, raw_n) %>%
    rename(n = raw_n) %>%
    complete(Stage = factor(stage_levels, levels = stage_levels), fill = list(n = 0)) %>%
    arrange(Stage)
  legend_labels <- paste0(as.character(counts$Stage), " (n=", counts$n, ")")

  label_layers <- list()
  sample_x <- 0.055
  if (!is.na(panel_label) && panel_label != "") {
    label_layers <- list(
      annotate("text", x = 0.035, y = 2.40, label = panel_label, hjust = 0, vjust = 1,
               size = 4.2, family = "Arial", fontface = "bold")
    )
  }

  main <- ggplot(dat, aes(x = O_C, y = H_C)) +
    geom_segment(
      data = vk_segments,
      aes(x = x, xend = xend, y = y, yend = yend),
      inherit.aes = FALSE,
      colour = "#6F6F6F",
      linewidth = 0.40,
      linetype = "dashed"
    ) +
    geom_point(aes(colour = Stage), size = 0.72, alpha = 0.62, stroke = 0) +
    scale_colour_manual(values = stage_colors, drop = FALSE) +
    scale_x_continuous(limits = c(-0.02, 1.22), breaks = c(0.0, 0.3, 0.6, 0.9, 1.2), expand = c(0, 0)) +
    scale_y_continuous(limits = c(-0.05, 2.55), breaks = c(0.0, 0.5, 1.0, 1.5, 2.0, 2.5), expand = c(0, 0)) +
    labs(x = "O/C", y = "H/C") +
    label_layers +
    annotate("text", x = sample_x, y = 2.40, label = paste0(leachate, "-", dose), hjust = 0, vjust = 1, size = 3.6, family = "Arial", fontface = "bold") +
    annotate("point", x = 0.80, y = 0.43, colour = stage_colors[1], size = 1.6, alpha = 0.9) +
    annotate("text", x = 0.84, y = 0.43, label = legend_labels[1], hjust = 0, vjust = 0.5, size = 2.35, family = "Arial") +
    annotate("point", x = 0.80, y = 0.28, colour = stage_colors[2], size = 1.6, alpha = 0.9) +
    annotate("text", x = 0.84, y = 0.28, label = legend_labels[2], hjust = 0, vjust = 0.5, size = 2.35, family = "Arial") +
    annotate("point", x = 0.80, y = 0.13, colour = stage_colors[3], size = 1.6, alpha = 0.9) +
    annotate("text", x = 0.84, y = 0.13, label = legend_labels[3], hjust = 0, vjust = 0.5, size = 2.35, family = "Arial") +
    theme_vk

  top_density <- ggplot(dat, aes(x = O_C, colour = Stage, fill = Stage)) +
    geom_density(linewidth = 0.30, alpha = 0.20, adjust = 0.9, na.rm = TRUE) +
    scale_colour_manual(values = stage_colors, drop = FALSE) +
    scale_fill_manual(values = stage_colors, drop = FALSE) +
    scale_x_continuous(limits = c(-0.02, 1.22), expand = c(0, 0)) +
    theme_void(base_family = "Arial") +
    theme(
      legend.position = "none",
      plot.margin = margin(1, 1, 0, 1)
    )

  right_density <- ggplot(dat, aes(x = H_C, colour = Stage, fill = Stage)) +
    geom_density(linewidth = 0.30, alpha = 0.20, adjust = 0.9, na.rm = TRUE) +
    scale_colour_manual(values = stage_colors, drop = FALSE) +
    scale_fill_manual(values = stage_colors, drop = FALSE) +
    scale_x_continuous(limits = c(-0.05, 2.55), expand = c(0, 0)) +
    coord_flip() +
    theme_void(base_family = "Arial") +
    theme(
      legend.position = "none",
      plot.margin = margin(1, 1, 1, 0)
    )

  top_row <- wrap_plots(top_density, plot_spacer(), ncol = 2, widths = c(4.2, 0.85))
  bottom_row <- wrap_plots(main, right_density, ncol = 2, widths = c(4.2, 0.85))
  wrap_plots(top_row, bottom_row, ncol = 1, heights = c(0.72, 4.0)) +
    plot_layout(heights = c(0.72, 4.0))
}

panel_grid <- tibble::tribble(
  ~Leachate, ~Dose, ~panel_label,
  "ML", "0.5", "",
  "ML", "0.8", "",
  "ML", "1.0", "",
  "OL", "0.5", "",
  "OL", "0.8", "",
  "OL", "1.0", ""
)

panel_plots <- vector("list", nrow(panel_grid))
for (i in seq_len(nrow(panel_grid))) {
  dat_i <- plot_data %>%
    filter(as.character(Leachate) == panel_grid$Leachate[i], as.character(Dose) == panel_grid$Dose[i])
  raw_counts_i <- raw_count_summary %>%
    filter(as.character(Leachate) == panel_grid$Leachate[i], as.character(Dose) == panel_grid$Dose[i])
  if (nrow(dat_i) == 0) stop("No data for ", panel_grid$Leachate[i], "-", panel_grid$Dose[i], call. = FALSE)
  panel_plots[[i]] <- make_panel(dat_i, panel_grid$panel_label[i], raw_counts_i)
  base <- file.path(output_dir, paste0(args$prefix, "_", panel_grid$Leachate[i], "_", gsub("\\.", "p", panel_grid$Dose[i]), "_VK_marginal"))
  cairo_pdf(paste0(base, ".pdf"), width = 4.2, height = 3.6, family = "Arial")
  print(panel_plots[[i]])
  dev.off()
  png(paste0(base, ".png"), width = 4.2, height = 3.6, units = "in", res = 600, type = "cairo")
  print(panel_plots[[i]])
  dev.off()
}

row_label_plot <- function(label) {
  ggplot() +
    annotate("text", x = 0.98, y = 0.83, label = label, hjust = 1, vjust = 1,
             family = "Arial", fontface = "bold", size = 5.0) +
    coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), clip = "off") +
    theme_void()
}

row1 <- wrap_plots(row_label_plot("a"), panel_plots[[1]], panel_plots[[2]], panel_plots[[3]],
                   ncol = 4, widths = c(0.08, 1, 1, 1))
row2 <- wrap_plots(row_label_plot("b"), panel_plots[[4]], panel_plots[[5]], panel_plots[[6]],
                   ncol = 4, widths = c(0.08, 1, 1, 1))
combined <- wrap_plots(row1, row2, ncol = 1, heights = c(1, 1))

combined_pdf <- file.path(output_dir, paste0(args$prefix, "_VK_marginal_combined.pdf"))
combined_png <- file.path(output_dir, paste0(args$prefix, "_VK_marginal_combined.png"))
cairo_pdf(combined_pdf, width = 12.4, height = 7.2, family = "Arial")
print(combined)
dev.off()
png(combined_png, width = 12.4, height = 7.2, units = "in", res = 600, type = "cairo")
print(combined)
dev.off()

caption <- "Fig. S8. Van Krevelen and marginal distribution diagrams of precursor, product, and resistant formulas in ML and OL under different pre-ozonation dosages. Points in blue represent precursor, points in red represent product, and points in green represent resistant."
writeLines(caption, file.path(output_dir, paste0(args$prefix, "_caption.txt")), useBytes = TRUE)

cat("\nOutput files:\n")
cat(combined_pdf, "\n")
cat(combined_png, "\n")
cat(file.path(output_dir, paste0(args$prefix, "_caption.txt")), "\n")
for (i in seq_len(nrow(panel_grid))) {
  base <- file.path(output_dir, paste0(args$prefix, "_", panel_grid$Leachate[i], "_", gsub("\\.", "p", panel_grid$Dose[i]), "_VK_marginal"))
  cat(paste0(base, ".pdf"), "\n")
  cat(paste0(base, ".png"), "\n")
}

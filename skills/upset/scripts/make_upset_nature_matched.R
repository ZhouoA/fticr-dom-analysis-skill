options(stringsAsFactors = FALSE)

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  values <- list(input_dir = ".", output_dir = NULL, nintersects = 30)
  i <- 1
  while (i <= length(args)) {
    key <- args[[i]]
    if (key %in% c("--input_dir", "--output_dir", "--nintersects")) {
      if (i == length(args)) stop("Missing value for ", key, call. = FALSE)
      values[[sub("^--", "", key)]] <- args[[i + 1]]
      i <- i + 2
    } else {
      i <- i + 1
    }
  }
  values$nintersects <- as.integer(values$nintersects)
  if (is.null(values$output_dir)) values$output_dir <- file.path(values$input_dir, "UpSet_nature_matched")
  values
}

args <- parse_args()

required_packages <- c("readr", "openxlsx", "dplyr", "tidyr", "ggplot2", "patchwork")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

library(readr)
library(openxlsx)
library(dplyr)
library(tidyr)
library(ggplot2)
library(patchwork)

input_dir <- normalizePath(args$input_dir, winslash = "/", mustWork = TRUE)
output_dir <- args$output_dir
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)

formula_col_candidates <- c("Formula", "Molecular Formula", "molecular_formula", "formula", "Assigned formula")

read_formula_set <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext == "csv") {
    dat <- suppressMessages(readr::read_csv(path, show_col_types = FALSE, locale = locale(encoding = "UTF-8")))
  } else {
    dat <- openxlsx::read.xlsx(path, sheet = 1)
  }
  formula_col <- names(dat)[tolower(trimws(names(dat))) %in% tolower(formula_col_candidates)]
  if (length(formula_col) == 0) {
    stop("Cannot find Formula column in ", basename(path), call. = FALSE)
  }
  formulas <- trimws(as.character(dat[[formula_col[1]]]))
  unique(formulas[!is.na(formulas) & formulas != ""])
}

load_sets <- function(leachate, dose_order) {
  sets <- lapply(dose_order, function(dose) {
    stem <- if (dose == "1") paste0(leachate, "-1") else paste0(leachate, "-", dose)
    paths <- file.path(input_dir, paste0(stem, c(".csv", ".xlsx", ".xls")))
    path <- paths[file.exists(paths)][1]
    if (is.na(path)) stop("Missing file for ", stem, call. = FALSE)
    read_formula_set(path)
  })
  names(sets) <- dose_order
  sets
}

make_intersections <- function(sets, nintersects = 30) {
  all_formula <- sort(unique(unlist(sets, use.names = FALSE)))
  membership <- lapply(sets, function(x) all_formula %in% x)
  mem_df <- as.data.frame(membership, check.names = FALSE)
  mem_df$molecular_formula <- all_formula
  mem_df$combo <- apply(mem_df[names(sets)], 1, function(z) paste(names(sets)[as.logical(z)], collapse = "||"))
  counts <- mem_df %>%
    filter(combo != "") %>%
    count(combo, name = "intersection_size") %>%
    arrange(desc(intersection_size), combo) %>%
    slice_head(n = nintersects) %>%
    mutate(x = row_number())
  list(counts = counts, membership = mem_df)
}

lighten_color <- function(x, amount = 0.78, alpha_value = 0.52) {
  rgb <- grDevices::col2rgb(x) / 255
  mixed <- rgb + (1 - rgb) * amount
  grDevices::rgb(mixed[1], mixed[2], mixed[3], alpha = alpha_value)
}

build_plot <- function(leachate, panel_label, dose_order, dose_colors, nintersects, width = 8.4, height = 5.2) {
  sets <- load_sets(leachate, dose_order)
  intersections <- make_intersections(sets, nintersects)
  counts <- intersections$counts
  n_rows <- length(dose_order)

  row_info <- tibble(
    dose = dose_order,
    y = seq(n_rows, 1),
    set_size = vapply(sets, length, integer(1)),
    color = unname(dose_colors[dose_order]),
    band_color = vapply(unname(dose_colors[dose_order]), lighten_color, character(1))
  )

  matrix_df <- tidyr::expand_grid(x = counts$x, dose = dose_order) %>%
    left_join(row_info, by = "dose") %>%
    left_join(counts %>% select(x, combo), by = "x") %>%
    mutate(active = mapply(function(d, c) d %in% strsplit(c, "\\|\\|", fixed = FALSE)[[1]], dose, combo))

  segment_list <- lapply(seq_len(nrow(counts)), function(i) {
    active_doses <- strsplit(counts$combo[i], "\\|\\|", fixed = FALSE)[[1]]
    yy <- row_info$y[match(active_doses, row_info$dose)]
    yy <- sort(yy)
    if (length(yy) < 2) return(tibble())
    tibble(
      x = counts$x[i],
      y = yy[-length(yy)],
      yend = yy[-1],
      dose = row_info$dose[match(yy[-length(yy)], row_info$y)]
    )
  })
  segment_df <- bind_rows(segment_list)

  top_plot <- ggplot(counts, aes(x = x, y = intersection_size)) +
    geom_col(width = 0.55, fill = "#BDBDBD", colour = NA) +
    geom_text(aes(label = intersection_size), vjust = -0.28, size = 3.0, family = "Arial", colour = "black") +
    scale_x_continuous(limits = c(0.4, max(counts$x) + 0.6), expand = expansion(mult = c(0, 0))) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
    labs(x = NULL, y = "Intersection size") +
    theme_classic(base_family = "Arial", base_size = 10) +
    theme(
      axis.line = element_line(linewidth = 0.45, colour = "black"),
      axis.line.x = element_line(linewidth = 0.7, colour = "black"),
      axis.ticks = element_line(linewidth = 0.45, colour = "black"),
      axis.ticks.length = unit(0.22, "cm"),
      axis.ticks.x = element_blank(),
      axis.text.x = element_blank(),
      axis.title.y = element_text(size = 16, colour = "black", margin = margin(r = 8)),
      axis.text.y = element_text(size = 11, colour = "black"),
      plot.margin = margin(5, 4, 0, 2)
    )

  matrix_plot <- ggplot() +
    geom_rect(
      data = row_info,
      aes(xmin = 0.4, xmax = max(counts$x) + 0.6, ymin = y - 0.48, ymax = y + 0.48, fill = dose),
      alpha = 0.28,
      inherit.aes = FALSE
    ) +
    geom_segment(
      data = segment_df,
      aes(x = x, xend = x, y = y, yend = yend, colour = dose),
      linewidth = 0.75,
      lineend = "round"
    ) +
    geom_point(data = matrix_df %>% filter(!active), aes(x = x, y = y), size = 2.35, colour = "#D9D9D9") +
    geom_point(data = matrix_df %>% filter(active), aes(x = x, y = y, colour = dose), size = 2.9) +
    scale_fill_manual(values = setNames(row_info$band_color, row_info$dose), guide = "none") +
    scale_colour_manual(values = dose_colors, guide = "none") +
    scale_x_continuous(limits = c(0.4, max(counts$x) + 0.6), expand = expansion(mult = c(0, 0))) +
    scale_y_continuous(limits = c(0.5, n_rows + 0.5), breaks = row_info$y, labels = row_info$dose, expand = c(0, 0)) +
    labs(x = NULL, y = NULL) +
    theme_classic(base_family = "Arial", base_size = 10) +
    theme(
      axis.line.x = element_blank(),
      axis.line.y = element_blank(),
      axis.ticks = element_blank(),
      axis.text.x = element_blank(),
      axis.text.y = element_text(size = 11, colour = "black", margin = margin(r = 3)),
      plot.margin = margin(0, 4, 5, 2)
    )

  left_plot <- ggplot(row_info) +
    geom_rect(aes(xmin = 0, xmax = set_size, ymin = y - 0.21, ymax = y + 0.21, fill = dose), colour = NA) +
    scale_fill_manual(values = dose_colors, guide = "none") +
    scale_y_continuous(limits = c(0.5, n_rows + 0.5), breaks = row_info$y, labels = NULL, expand = c(0, 0)) +
    scale_x_reverse(limits = c(max(row_info$set_size) * 1.06, 0), expand = expansion(mult = c(0, 0.02))) +
    labs(x = "Formula count", y = NULL) +
    theme_classic(base_family = "Arial", base_size = 10) +
    theme(
      axis.line = element_line(linewidth = 0.45, colour = "black"),
      axis.line.y = element_blank(),
      axis.ticks.y = element_blank(),
      axis.ticks.length = unit(0.22, "cm"),
      axis.text.y = element_blank(),
      axis.title.x = element_text(size = 12, colour = "black", margin = margin(t = 4)),
      axis.text.x = element_text(size = 10, colour = "black"),
      plot.margin = margin(0, 4, 5, 5)
    )

  label_plot <- ggplot() +
    annotate("text", x = 0.05, y = 0.92, label = panel_label, family = "Arial", fontface = "bold", size = 8) +
    coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), clip = "off") +
    theme_void() +
    theme(plot.margin = margin(5, 0, 0, 2))

  combined <- (label_plot + top_plot + plot_layout(widths = c(0.27, 0.73))) /
    (left_plot + matrix_plot + plot_layout(widths = c(0.27, 0.73))) +
    plot_layout(heights = c(0.72, 0.28))

  base <- file.path(output_dir, paste0(leachate, "_upset_nature_matched"))
  cairo_pdf(paste0(base, ".pdf"), width = width, height = height, family = "Arial")
  print(combined)
  dev.off()
  png(paste0(base, ".png"), width = width, height = height, units = "in", res = 600, type = "cairo")
  print(combined)
  dev.off()

  list(files = c(paste0(base, ".pdf"), paste0(base, ".png")), counts = counts, row_info = row_info)
}

ml_colors <- c("1" = "#E5086A", "0.5" = "#D35F27", "0.8" = "#604E98", "0" = "#046586")
ol_colors <- c("1" = "#E41A1C", "0.8" = "#6BAF45", "0" = "#F07F7F", "0.5" = "#F5A623")

ml_result <- build_plot("ML", "(a)", c("1", "0.5", "0.8", "0"), ml_colors, args$nintersects)
ol_result <- build_plot("OL", "(b)", c("1", "0.8", "0", "0.5"), ol_colors, args$nintersects)

audit <- bind_rows(
  ml_result$row_info %>% transmute(leachate = "ML", dose, set_size),
  ol_result$row_info %>% transmute(leachate = "OL", dose, set_size)
)
readr::write_csv(audit, file.path(output_dir, "upset_nature_matched_set_size_audit.csv"))
readr::write_csv(ml_result$counts, file.path(output_dir, "ML_upset_nature_matched_intersections.csv"))
readr::write_csv(ol_result$counts, file.path(output_dir, "OL_upset_nature_matched_intersections.csv"))

cat("\nNature-matched UpSet plots completed.\n")
cat("Input directory: ", input_dir, "\n", sep = "")
cat("Output directory: ", output_dir, "\n", sep = "")
cat("ML dose-color mapping: ", paste(names(ml_colors), ml_colors, sep = "=", collapse = "; "), "\n", sep = "")
cat("OL dose-color mapping: ", paste(names(ol_colors), ol_colors, sep = "=", collapse = "; "), "\n", sep = "")
cat("Output files:\n")
cat(paste(c(ml_result$files, ol_result$files), collapse = "\n"), "\n")

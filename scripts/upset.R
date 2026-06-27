#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(readxl)
  library(readr)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(patchwork)
  library(ragg)
  library(svglite)
})

parse_args <- function(args) {
  out <- list(
    input_dir = "input",
    output_dir = "output",
    prefix = "Raw_FTICRMS_UpSet",
    sample_order = "YL,OL,ML",
    width_in = "7.2",
    height_in = "4.6",
    dpi = "600"
  )
  i <- 1
  while (i <= length(args)) {
    key <- args[[i]]
    if (!startsWith(key, "--")) stop("Unexpected argument: ", key, call. = FALSE)
    name <- sub("^--", "", key)
    if (!name %in% names(out)) stop("Unknown argument: ", key, call. = FALSE)
    if (i == length(args) || startsWith(args[[i + 1]], "--")) {
      stop("Missing value for ", key, call. = FALSE)
    }
    out[[name]] <- args[[i + 1]]
    i <- i + 2
  }
  out$width_in <- as.numeric(out$width_in)
  out$height_in <- as.numeric(out$height_in)
  out$dpi <- as.integer(out$dpi)
  out$sample_order <- trimws(strsplit(out$sample_order, ",", fixed = TRUE)[[1]])
  out
}

read_formula_set <- function(input_dir, sample_id) {
  path <- file.path(input_dir, paste0(sample_id, ".xlsx"))
  if (!file.exists(path)) stop("Missing input file: ", path, call. = FALSE)
  dat <- readxl::read_excel(path)
  if (!"Formula" %in% names(dat)) stop(path, " lacks Formula column", call. = FALSE)
  dat %>%
    transmute(
      sample_id = sample_id,
      Formula = as.character(.data$Formula)
    ) %>%
    filter(!is.na(.data$Formula), nzchar(.data$Formula)) %>%
    distinct()
}

make_upset_data <- function(input_dir, sample_order) {
  formula_sets <- bind_rows(lapply(sample_order, function(x) read_formula_set(input_dir, x)))
  presence <- formula_sets %>%
    mutate(present = TRUE) %>%
    pivot_wider(
      names_from = .data$sample_id,
      values_from = .data$present,
      values_fill = FALSE
    )

  for (sample_id in sample_order) {
    if (!sample_id %in% names(presence)) presence[[sample_id]] <- FALSE
  }

  presence <- presence %>%
    mutate(
      intersection_key = apply(
        as.data.frame(across(all_of(sample_order))),
        1,
        function(x) paste(sample_order[as.logical(x)], collapse = "&")
      ),
      intersection_degree = rowSums(across(all_of(sample_order)))
    ) %>%
    filter(.data$intersection_degree > 0)

  intersections <- presence %>%
    count(.data$intersection_key, .data$intersection_degree, name = "intersection_size") %>%
    arrange(desc(.data$intersection_size), desc(.data$intersection_degree), .data$intersection_key) %>%
    mutate(intersection_rank = row_number())

  matrix_data <- tidyr::expand_grid(
    intersection_key = intersections$intersection_key,
    sample_id = sample_order
  ) %>%
    left_join(intersections, by = "intersection_key") %>%
    mutate(
      present = vapply(
        seq_along(.data$intersection_key),
        function(i) sample_id[[i]] %in% strsplit(intersection_key[[i]], "&", fixed = TRUE)[[1]],
        logical(1)
      ),
      sample_id = factor(.data$sample_id, levels = rev(sample_order)),
      intersection_key = factor(.data$intersection_key, levels = intersections$intersection_key)
    )

  line_data <- matrix_data %>%
    filter(.data$present) %>%
    group_by(.data$intersection_key, .data$intersection_rank) %>%
    summarise(
      y_min = min(as.numeric(.data$sample_id)),
      y_max = max(as.numeric(.data$sample_id)),
      n_present = n(),
      .groups = "drop"
    ) %>%
    filter(.data$n_present > 1)

  set_sizes <- formula_sets %>%
    count(.data$sample_id, name = "formula_count") %>%
    mutate(sample_id = factor(.data$sample_id, levels = rev(sample_order)))

  list(
    formula_sets = formula_sets,
    presence = presence,
    intersections = intersections,
    matrix_data = matrix_data,
    line_data = line_data,
    set_sizes = set_sizes
  )
}

theme_nature_axis <- function(base_size = 8) {
  theme_classic(base_size = base_size, base_family = "Arial") +
    theme(
      axis.line = element_line(linewidth = 0.32, colour = "black"),
      axis.ticks = element_line(linewidth = 0.30, colour = "black"),
      axis.ticks.length = grid::unit(1.5, "mm"),
      axis.text = element_text(colour = "#303030", face = "plain"),
      axis.title = element_text(colour = "black", face = "plain"),
      panel.grid = element_blank(),
      plot.margin = margin(2, 3, 2, 3)
    )
}

plot_upset <- function(upset, sample_order) {
  samples_rev <- rev(sample_order)
  band_colors <- c(
    "YL" = "#BFE8E4",
    "OL" = "#F5D4D4",
    "ML" = "#D6E3F2"
  )
  set_colors <- c(
    "YL" = "#26A69A",
    "OL" = "#E87878",
    "ML" = "#5E8EC8"
  )
  dot_color <- "#2B67A5"
  inactive_dot <- "#D0D0D0"

  intersections <- upset$intersections %>%
    mutate(intersection_rank = as.numeric(.data$intersection_rank))
  n_intersections <- nrow(intersections)

  matrix_data <- upset$matrix_data %>%
    mutate(
      intersection_rank = as.numeric(.data$intersection_rank),
      y_num = as.numeric(.data$sample_id)
    )

  band_df <- data.frame(
    sample_id = factor(samples_rev, levels = samples_rev),
    y_num = seq_along(samples_rev),
    fill = band_colors[samples_rev]
  )

  line_data <- upset$line_data %>%
    mutate(intersection_rank = as.numeric(.data$intersection_rank))

  p_top <- ggplot(intersections, aes(x = .data$intersection_rank, y = .data$intersection_size)) +
    geom_col(width = 0.56, fill = "#B7B7B7", colour = NA) +
    geom_text(
      aes(label = .data$intersection_size),
      vjust = -0.28,
      size = 2.25,
      family = "Arial",
      fontface = "plain",
      colour = "#303030"
    ) +
    scale_x_continuous(limits = c(0.5, n_intersections + 0.5), expand = c(0, 0)) +
    scale_y_continuous(
      expand = expansion(mult = c(0, 0.12)),
      breaks = scales::pretty_breaks(n = 5)
    ) +
    labs(x = NULL, y = "Intersection size") +
    theme_nature_axis(base_size = 8) +
    theme(
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      axis.title.y = element_text(size = 10.5, margin = margin(r = 4)),
      axis.text.y = element_text(size = 7.0),
      plot.margin = margin(2, 3, 0, 3)
    )

  p_matrix <- ggplot() +
    geom_rect(
      data = band_df,
      aes(
        xmin = 0.5,
        xmax = n_intersections + 0.5,
        ymin = .data$y_num - 0.5,
        ymax = .data$y_num + 0.5,
        fill = .data$sample_id
      ),
      alpha = 0.88,
      inherit.aes = FALSE
    ) +
    geom_point(
      data = matrix_data,
      aes(x = .data$intersection_rank, y = .data$y_num),
      size = 1.25,
      colour = inactive_dot
    ) +
    geom_segment(
      data = line_data,
      aes(
        x = .data$intersection_rank,
        xend = .data$intersection_rank,
        y = .data$y_min,
        yend = .data$y_max
      ),
      linewidth = 0.95,
      colour = dot_color,
      lineend = "round"
    ) +
    geom_point(
      data = filter(matrix_data, .data$present),
      aes(x = .data$intersection_rank, y = .data$y_num),
      size = 2.35,
      colour = dot_color
    ) +
    scale_fill_manual(values = band_colors, guide = "none") +
    scale_y_continuous(
      breaks = seq_along(samples_rev),
      labels = rep("4000", length(samples_rev)),
      limits = c(0.5, length(samples_rev) + 0.5),
      expand = c(0, 0)
    ) +
    scale_x_continuous(limits = c(0.5, n_intersections + 0.5), expand = c(0, 0)) +
    coord_cartesian(clip = "off") +
    labs(x = NULL, y = "Intersection size") +
    theme_nature_axis(base_size = 8) +
    theme(
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      axis.line.x = element_blank(),
      axis.title.x = element_blank(),
      axis.title.y = element_text(size = 10.5, margin = margin(r = 4), colour = "transparent"),
      axis.text.y = element_text(size = 7.0, colour = "transparent"),
      axis.ticks.y = element_line(linewidth = 0.30, colour = "transparent"),
      axis.line.y = element_line(linewidth = 0.32, colour = "transparent"),
      plot.margin = margin(0, 3, 1, 3)
    )

  set_sizes_plot <- upset$set_sizes %>%
    mutate(
      sample_id_chr = as.character(.data$sample_id),
      y_num = match(.data$sample_id_chr, samples_rev)
    )
  max_formula_count <- max(set_sizes_plot$formula_count)

  p_left <- ggplot(set_sizes_plot, aes(fill = .data$sample_id_chr)) +
    geom_rect(
      aes(
        xmin = 0,
        xmax = .data$formula_count,
        ymin = .data$y_num - 0.23,
        ymax = .data$y_num + 0.23
      ),
      colour = NA
    ) +
    scale_fill_manual(values = set_colors, guide = "none") +
    scale_x_reverse(
      breaks = c(8000, 6000, 4000, 2000, 0),
      expand = c(0, 0)
    ) +
    scale_y_continuous(
      limits = c(0.5, length(samples_rev) + 0.5),
      breaks = seq_along(samples_rev),
      labels = samples_rev,
      expand = c(0, 0)
    ) +
    coord_cartesian(xlim = c(max_formula_count * 1.03, 0), clip = "off") +
    labs(x = "Formula count", y = NULL) +
    theme_nature_axis(base_size = 7.5) +
    theme(
      axis.line.y = element_blank(),
      axis.ticks.y = element_blank(),
      axis.text.y = element_blank(),
      axis.title.x = element_text(size = 7.2, margin = margin(t = 1)),
      axis.text.x = element_text(size = 5.2),
      plot.margin = margin(0, 0, 5, 4)
    )

  p_row_labels <- ggplot(
    data.frame(y_num = seq_along(samples_rev), label = samples_rev),
    aes(x = 1, y = .data$y_num, label = .data$label)
  ) +
    geom_text(
      hjust = 1,
      size = 2.65,
      family = "Arial",
      fontface = "plain",
      colour = "black"
    ) +
    scale_y_continuous(
      limits = c(0.5, length(samples_rev) + 0.5),
      expand = c(0, 0)
    ) +
    scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
    coord_cartesian(clip = "off") +
    theme_void(base_family = "Arial") +
    theme(plot.margin = margin(0, 2, 5, 0))

  blank <- ggplot() + theme_void()

  final <- (blank + blank + p_top + plot_layout(widths = c(0.265, 0.015, 0.720))) /
    (p_left + p_row_labels + p_matrix + plot_layout(widths = c(0.265, 0.015, 0.720))) +
    plot_layout(heights = c(0.72, 0.28)) &
    theme(
      plot.margin = margin(3, 5, 3, 5)
    )
  final
}

write_outputs <- function(upset, output_dir, prefix) {
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  readr::write_csv(upset$intersections, file.path(output_dir, paste0(prefix, "_intersection_sizes.csv")))
  readr::write_csv(upset$set_sizes, file.path(output_dir, paste0(prefix, "_set_sizes.csv")))
  readr::write_csv(upset$presence, file.path(output_dir, paste0(prefix, "_formula_membership.csv")))
}

save_figure <- function(plot, output_dir, prefix, width_in, height_in, dpi) {
  base <- file.path(output_dir, prefix)
  svglite::svglite(paste0(base, ".svg"), width = width_in, height = height_in)
  print(plot)
  dev.off()

  grDevices::cairo_pdf(paste0(base, ".pdf"), width = width_in, height = height_in, family = "Arial")
  print(plot)
  dev.off()

  ragg::agg_png(paste0(base, ".png"), width = width_in, height = height_in, units = "in", res = dpi, background = "white")
  print(plot)
  dev.off()

  ragg::agg_tiff(paste0(base, ".tiff"), width = width_in, height = height_in, units = "in", res = dpi, compression = "lzw", background = "white")
  print(plot)
  dev.off()
}

main <- function() {
  args <- parse_args(commandArgs(trailingOnly = TRUE))
  upset <- make_upset_data(args$input_dir, args$sample_order)
  plot <- plot_upset(upset, args$sample_order)
  write_outputs(upset, args$output_dir, args$prefix)
  save_figure(plot, args$output_dir, args$prefix, args$width_in, args$height_in, args$dpi)

  qa <- upset$set_sizes %>%
    mutate(sample_id = as.character(.data$sample_id)) %>%
    arrange(match(.data$sample_id, args$sample_order))
  print(qa)
  print(upset$intersections)
  message("Saved outputs to: ", normalizePath(args$output_dir, winslash = "/", mustWork = TRUE))
}

main()

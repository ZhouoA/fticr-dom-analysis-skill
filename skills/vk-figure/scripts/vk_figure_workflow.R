#!/usr/bin/env Rscript

parse_args <- function(args) {
  out <- list(
    input = NULL,
    output = NULL,
    mode = "check",
    scheme = "raw8",
    breaks = NULL,
    labels = NULL,
    order = NULL,
    ncol = 4,
    dpi = 600
  )
  i <- 1
  while (i <= length(args)) {
    key <- args[[i]]
    if (!startsWith(key, "--")) {
      stop(sprintf("Unexpected argument: %s", key), call. = FALSE)
    }
    name <- substring(key, 3)
    if (!name %in% names(out)) {
      stop(sprintf("Unknown option: %s", key), call. = FALSE)
    }
    if (i == length(args)) {
      stop(sprintf("Missing value for %s", key), call. = FALSE)
    }
    out[[name]] <- args[[i + 1]]
    i <- i + 2
  }
  out$ncol <- as.integer(out$ncol)
  out$dpi <- as.integer(out$dpi)
  out
}

require_packages <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop(
      sprintf(
        "Missing R package(s): %s\nInstall with: install.packages(c(%s))",
        paste(missing, collapse = ", "),
        paste(sprintf('"%s"', missing), collapse = ", ")
      ),
      call. = FALSE
    )
  }
}

to_numeric_vec <- function(text) {
  parts <- trimws(strsplit(text, ",", fixed = TRUE)[[1]])
  vapply(parts, function(x) {
    if (tolower(x) == "-inf") return(-Inf)
    if (tolower(x) == "inf") return(Inf)
    as.numeric(x)
  }, numeric(1))
}

to_label_vec <- function(text) {
  trimws(strsplit(text, "|", fixed = TRUE)[[1]])
}

scheme_config <- function(name) {
  configs <- list(
    raw8 = list(
      multiplier = 1,
      breaks = c(-Inf, 0.00002, 0.00004, 0.00006, 0.00010,
                 0.00020, 0.00050, 0.001, Inf),
      labels = c(
        "<0.00002",
        "[0.00002,0.00004)",
        "[0.00004,0.00006)",
        "[0.00006,0.00010)",
        "[0.00010,0.00020)",
        "[0.00020,0.00050)",
        "[0.00050,0.001)",
        ">=0.001"
      )
    ),
    raw6 = list(
      multiplier = 1,
      breaks = c(-Inf, 0.00003, 0.00006, 0.00012, 0.00030, 0.001, Inf),
      labels = c(
        "<0.00003",
        "[0.00003,0.00006)",
        "[0.00006,0.00012)",
        "[0.00012,0.00030)",
        "[0.00030,0.001)",
        ">=0.001"
      )
    ),
    original9 = list(
      multiplier = 1,
      breaks = c(-Inf, 0.00008, 0.0001, 0.0002, 0.0004,
                 0.0006, 0.0008, 0.001, 0.002, Inf),
      labels = c(
        "<0.00008",
        "[0.00008,0.0001)",
        "[0.0001,0.0002)",
        "[0.0002,0.0004)",
        "[0.0004,0.0006)",
        "[0.0006,0.0008)",
        "[0.0008,0.001)",
        "[0.001,0.002)",
        ">=0.002"
      )
    ),
    RIx10_original9 = list(
      multiplier = 10,
      breaks = c(-Inf, 0.00008, 0.0001, 0.0002, 0.0004,
                 0.0006, 0.0008, 0.001, 0.002, Inf),
      labels = c(
        "<0.00008",
        "[0.00008,0.0001)",
        "[0.0001,0.0002)",
        "[0.0002,0.0004)",
        "[0.0004,0.0006)",
        "[0.0006,0.0008)",
        "[0.0008,0.001)",
        "[0.001,0.002)",
        ">=0.002"
      )
    )
  )
  if (!name %in% names(configs)) {
    stop(sprintf("Unknown scheme '%s'. Use one of: %s", name, paste(names(configs), collapse = ", ")), call. = FALSE)
  }
  configs[[name]]
}

list_csv_files <- function(input_dir, order_text = NULL) {
  files <- list.files(input_dir, pattern = "\\.csv$", full.names = TRUE)
  files <- files[!grepl("_RI_bin_counts\\.csv$|candidate_bin_counts|RI_quantiles", basename(files))]
  if (length(files) == 0) {
    stop(sprintf("No CSV files found in %s", input_dir), call. = FALSE)
  }
  if (!is.null(order_text) && nzchar(order_text)) {
    requested <- trimws(strsplit(order_text, ",", fixed = TRUE)[[1]])
    stems <- tools::file_path_sans_ext(basename(files))
    ordered <- unlist(lapply(requested, function(x) {
      hit <- files[stems == x | basename(files) == x | stems == tools::file_path_sans_ext(x)]
      if (length(hit) == 0) stop(sprintf("Order item not found: %s", x), call. = FALSE)
      hit[[1]]
    }))
    remaining <- setdiff(files, ordered)
    files <- c(ordered, sort(remaining))
  } else {
    files <- sort(files)
  }
  files
}

read_sample <- function(path) {
  dat <- read.csv(path, check.names = FALSE)
  required <- c("O/C", "H/C", "RI")
  missing <- setdiff(required, names(dat))
  if (length(missing) > 0) {
    stop(sprintf("%s is missing required columns: %s", basename(path), paste(missing, collapse = ", ")), call. = FALSE)
  }
  out <- dat[, required]
  names(out) <- c("O_C", "H_C", "RI")
  out <- out[is.finite(out$O_C) & is.finite(out$H_C) & is.finite(out$RI), ]
  out$sample <- tools::file_path_sans_ext(basename(path))
  out
}

write_check_outputs <- function(files, output_dir) {
  check_dir <- file.path(output_dir, "RI_classification_check")
  dir.create(check_dir, showWarnings = FALSE, recursive = TRUE)
  qs <- c(0, 0.01, 0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99, 1)
  quant_rows <- do.call(rbind, lapply(files, function(path) {
    dat <- read_sample(path)
    data.frame(
      sample = dat$sample[[1]],
      n = nrow(dat),
      t(as.data.frame(quantile(dat$RI, qs, na.rm = TRUE))),
      mean = mean(dat$RI),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }))
  names(quant_rows)[3:(2 + length(qs))] <- paste0("q", qs * 100)
  write.csv(quant_rows, file.path(check_dir, "RI_quantiles_by_sample.csv"), row.names = FALSE)

  scheme_names <- c("raw8", "raw6", "original9", "RIx10_original9")
  by_sample <- do.call(rbind, lapply(scheme_names, function(scheme_name) {
    cfg <- scheme_config(scheme_name)
    do.call(rbind, lapply(files, function(path) {
      dat <- read_sample(path)
      x <- dat$RI * cfg$multiplier
      bins <- cut(x, cfg$breaks, labels = cfg$labels, right = FALSE, include.lowest = TRUE)
      tab <- as.data.frame(table(bins), stringsAsFactors = FALSE)
      names(tab) <- c("class", "n")
      tab$percent <- round(tab$n / sum(tab$n) * 100, 2)
      tab$sample <- dat$sample[[1]]
      tab$scheme <- scheme_name
      tab[, c("scheme", "sample", "class", "n", "percent")]
    }))
  }))
  overall <- aggregate(n ~ scheme + class, by_sample, sum)
  overall$percent <- ave(overall$n, overall$scheme, FUN = function(x) round(x / sum(x) * 100, 2))
  write.csv(by_sample, file.path(check_dir, "candidate_bin_counts_by_sample.csv"), row.names = FALSE)
  write.csv(overall, file.path(check_dir, "candidate_bin_counts_overall.csv"), row.names = FALSE)
  message(sprintf("Wrote RI check outputs to: %s", check_dir))
  print(overall, row.names = FALSE)
}

nature_ri_colors <- c(
  "#D8D8D8", "#DDF3DE", "#AADCA9", "#8BCF8B",
  "#42949E", "#3775BA", "#9A4D8E", "#B64342", "#B64342"
)

vk_segments <- data.frame(
  x = c(0, 0.3, 0.67, 0, 0, 0, 0.1, 0.3, 0.67, 1.0, 1.2, 0, 0.67),
  xend = c(0.3, 0.67, 1.2, 1.2, 0.67, 0.67, 0.1, 0.3, 0.67, 1.0, 1.2, 0, 1.0),
  y = c(2.0, 2.2, 2.4, 1.5, 0.7, 0.2, 0.7, 1.5, 0.2, 0.6, 1.5, 0.2, 0.6),
  yend = c(2.0, 2.2, 2.4, 1.5, 0.7, 0.2, 1.5, 2.2, 2.4, 1.5, 2.4, 2.0, 0.6)
)

theme_vk_panel <- function() {
  ggplot2::theme_classic(base_size = 14, base_family = "Arial") +
    ggplot2::theme(
      panel.border = ggplot2::element_rect(colour = "black", fill = NA, linewidth = 0.7),
      axis.line = ggplot2::element_line(colour = "black", linewidth = 0.45),
      axis.ticks = ggplot2::element_line(colour = "black", linewidth = 0.45),
      axis.ticks.length = grid::unit(1.6, "mm"),
      axis.title = ggplot2::element_text(size = 18, face = "bold", colour = "black"),
      axis.text = ggplot2::element_text(size = 14, colour = "black"),
      plot.title = ggplot2::element_blank(),
      plot.margin = ggplot2::margin(3, 11, 3, 3),
      legend.position = "none"
    )
}

format_legend_number <- function(x) {
  y <- x * 100 / 1e-3
  ifelse(abs(y - round(y)) < 1e-8, as.character(round(y)), formatC(y, format = "fg", digits = 3))
}

make_colorbar_legend <- function(cfg) {
  colors <- nature_ri_colors[seq_along(cfg$labels)]
  bar_x0 <- 3.02
  bar_width <- 1.72
  step <- bar_width / length(colors)
  legend_df <- data.frame(
    xmin = bar_x0 + (seq_along(colors) - 1) * step,
    xmax = bar_x0 + seq_along(colors) * step,
    ymin = 0,
    ymax = 1,
    fill = factor(seq_along(colors))
  )
  internal_breaks <- cfg$breaks[is.finite(cfg$breaks)]
  tick_df <- data.frame(
    x = bar_x0 + seq_along(internal_breaks) * step,
    label = format_legend_number(internal_breaks)
  )
  bar_x1 <- bar_x0 + bar_width

  ggplot2::ggplot() +
    ggplot2::geom_rect(
      data = legend_df,
      ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = fill),
      colour = NA
    ) +
    ggplot2::geom_rect(
      ggplot2::aes(xmin = bar_x0, xmax = bar_x1, ymin = 0, ymax = 1),
      fill = NA,
      colour = "black",
      linewidth = 0.45
    ) +
    ggplot2::geom_segment(
      data = tick_df,
      ggplot2::aes(x = x, xend = x, y = 0, yend = -0.15),
      linewidth = 0.42,
      colour = "black"
    ) +
    ggplot2::geom_text(
      data = tick_df,
      ggplot2::aes(x = x, y = -0.36, label = label),
      size = 4.92,
      fontface = "bold",
      family = "Arial",
      vjust = 1
    ) +
    ggplot2::annotate(
      "text",
      x = bar_x1 + 0.07,
      y = 0.64,
      label = "RI (%)",
      hjust = 0,
      vjust = 0.5,
      size = 4.92,
      fontface = "bold",
      family = "Arial"
    ) +
    ggplot2::annotate(
      "text",
      x = bar_x1 + 0.07,
      y = 0.18,
      label = "paste('\u00d7', 10^{-3})",
      parse = TRUE,
      hjust = 0,
      vjust = 0.5,
      size = 4.92,
      fontface = "bold",
      family = "Arial"
    ) +
    ggplot2::scale_fill_manual(values = colors, guide = "none") +
    ggplot2::scale_x_continuous(expand = c(0, 0), limits = c(0, 7.76)) +
    ggplot2::scale_y_continuous(expand = c(0, 0), limits = c(-0.95, 1.12)) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::theme_void(base_family = "Arial") +
    ggplot2::theme(plot.margin = ggplot2::margin(1, 1, 0, 1))
}

make_panel <- function(path, cfg, row_tag = NULL, dpi = 600) {
  dat <- read_sample(path)
  dat$RI_plot <- dat$RI * cfg$multiplier
  dat <- dat[order(dat$RI_plot), ]
  dat$RI_Category <- cut(dat$RI_plot, cfg$breaks, labels = cfg$labels, right = FALSE, include.lowest = TRUE)
  counts <- as.data.frame(table(dat$RI_Category), stringsAsFactors = FALSE)
  names(counts) <- c("RI_category", "n")
  counts$sample <- dat$sample[[1]]
  counts$percent <- round(counts$n / sum(counts$n) * 100, 2)

  n_label <- paste0("n=", format(nrow(dat), big.mark = ",", trim = TRUE))
  p <- ggplot2::ggplot(dat, ggplot2::aes(x = O_C, y = H_C)) +
    ggrastr::geom_point_rast(
      ggplot2::aes(colour = RI_Category),
      size = 0.72,
      alpha = 0.82,
      stroke = 0,
      raster.dpi = dpi
    ) +
    ggplot2::geom_segment(
      data = vk_segments,
      ggplot2::aes(x = x, xend = xend, y = y, yend = yend),
      inherit.aes = FALSE,
      colour = "black",
      linetype = "dashed",
      linewidth = 0.23
    ) +
    ggplot2::annotate(
      "text",
      x = 1.17,
      y = 0.05,
      label = n_label,
      hjust = 1,
      vjust = 0,
      size = 5.62,
      fontface = "bold",
      family = "Arial",
      colour = "black"
    ) +
    ggplot2::annotate(
      "text",
      x = 0.03,
      y = 2.43,
      label = dat$sample[[1]],
      hjust = 0,
      vjust = 1,
      size = 5.62,
      fontface = "bold",
      family = "Arial",
      colour = "black"
    ) +
    ggplot2::scale_colour_manual(
      name = "RI",
      values = stats::setNames(nature_ri_colors[seq_along(cfg$labels)], cfg$labels),
      breaks = cfg$labels,
      drop = FALSE
    ) +
    ggplot2::scale_x_continuous(limits = c(-0.02, 1.22), expand = c(0, 0), breaks = seq(0, 1.2, by = 0.3)) +
    ggplot2::scale_y_continuous(limits = c(-0.05, 2.55), expand = c(0, 0), breaks = seq(0, 2.5, by = 0.5)) +
    ggplot2::labs(x = "O/C", y = "H/C") +
    ggplot2::coord_cartesian(clip = "off") +
    theme_vk_panel()

  if (!is.null(row_tag)) {
    p <- p +
      ggplot2::labs(tag = row_tag) +
      ggplot2::theme(
        plot.tag = ggplot2::element_text(size = 27, face = "bold", family = "Arial", colour = "black"),
        plot.tag.position = c(0.030, 1),
        plot.margin = ggplot2::margin(9, 11, 3, 42)
      )
  }

  list(plot = p, counts = counts)
}

save_combined <- function(plot, output_dir, dpi = 600, width_mm = 430, height_mm = 225) {
  base <- file.path(output_dir, "combined_vk_RI_AI_friendly")
  width_in <- width_mm / 25.4
  height_in <- height_mm / 25.4

  svglite::svglite(paste0(base, ".svg"), width = width_in, height = height_in)
  print(plot)
  grDevices::dev.off()

  grDevices::cairo_pdf(paste0(base, ".pdf"), width = width_in, height = height_in, family = "Arial")
  print(plot)
  grDevices::dev.off()

  ragg::agg_png(paste0(base, ".png"), width = width_in, height = height_in, units = "in", res = dpi, background = "white")
  print(plot)
  grDevices::dev.off()

  ragg::agg_tiff(paste0(base, ".tiff"), width = width_in, height = height_in, units = "in", res = dpi, background = "white", compression = "lzw")
  print(plot)
  grDevices::dev.off()
}

run_plot <- function(files, output_dir, cfg, ncol = 4, dpi = 600) {
  require_packages(c("ggplot2", "patchwork", "ragg", "svglite", "ggrastr"))
  suppressPackageStartupMessages({
    library(ggplot2)
    library(patchwork)
    library(ragg)
    library(svglite)
    library(ggrastr)
  })
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  tags <- letters[seq_len(ceiling(length(files) / ncol))]
  panel_objs <- vector("list", length(files))
  all_counts <- list()
  for (i in seq_along(files)) {
    row_index <- ceiling(i / ncol)
    row_tag <- if (((i - 1) %% ncol) == 0) tags[[row_index]] else NULL
    obj <- make_panel(files[[i]], cfg, row_tag = row_tag, dpi = dpi)
    panel_objs[[i]] <- obj$plot
    all_counts[[i]] <- obj$counts
    write.csv(obj$counts, file.path(output_dir, paste0(obj$counts$sample[[1]], "_RI_bin_counts.csv")), row.names = FALSE)
  }
  write.csv(do.call(rbind, all_counts), file.path(output_dir, "all_samples_RI_bin_counts.csv"), row.names = FALSE)

  rows <- split(panel_objs, ceiling(seq_along(panel_objs) / ncol))
  row_plots <- lapply(rows, function(row) {
    Reduce(`|`, row)
  })
  grid_plot <- Reduce(`/`, row_plots)
  final_plot <- make_colorbar_legend(cfg) / grid_plot +
    patchwork::plot_layout(heights = c(0.26, rep(1, length(row_plots)))) &
    ggplot2::theme(plot.margin = ggplot2::margin(2, 10, 2, 2))

  height_mm <- 45 + length(row_plots) * 90
  width_mm <- max(180, ncol * 100 + 30)
  save_combined(final_plot, output_dir, dpi = dpi, width_mm = width_mm, height_mm = height_mm)
  message(sprintf("Wrote AI-friendly VK figure outputs to: %s", output_dir))
}

main <- function() {
  args <- parse_args(commandArgs(trailingOnly = TRUE))
  if (is.null(args$input)) {
    stop("Use --input INPUT_DIR", call. = FALSE)
  }
  input_dir <- normalizePath(args$input, winslash = "/", mustWork = TRUE)
  output_dir <- if (is.null(args$output)) file.path(input_dir, "vk_figure_outputs") else args$output
  files <- list_csv_files(input_dir, args$order)

  if (tolower(args$mode) == "check") {
    write_check_outputs(files, output_dir)
    return(invisible(NULL))
  }

  if (tolower(args$mode) != "plot") {
    stop("Use --mode check or --mode plot", call. = FALSE)
  }

  cfg <- scheme_config(args$scheme)
  if (!is.null(args$breaks) || !is.null(args$labels)) {
    if (is.null(args$breaks) || is.null(args$labels)) {
      stop("Custom bins require both --breaks and --labels", call. = FALSE)
    }
    cfg$breaks <- to_numeric_vec(args$breaks)
    cfg$labels <- to_label_vec(args$labels)
    cfg$multiplier <- 1
    if (length(cfg$labels) != length(cfg$breaks) - 1) {
      stop("Number of labels must equal number of breaks minus one", call. = FALSE)
    }
  }
  run_plot(files, output_dir, cfg, ncol = args$ncol, dpi = args$dpi)
}

main()

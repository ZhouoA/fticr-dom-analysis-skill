#!/usr/bin/env Rscript

parse_args <- function(args) {
  out <- list(
    input_csv = "FigS5a_VK_points.csv",
    figure_dir = "Violin_plot_outputs/figures",
    table_dir = "Violin_plot_outputs/tables",
    prefix = "Raw_Molecular_Properties_Violin",
    width_mm = "183",
    height_mm = "100",
    dpi = "600",
    r_lib = ""
  )
  i <- 1L
  while (i <= length(args)) {
    key <- args[[i]]
    if (!startsWith(key, "--")) stop("Unexpected argument: ", key, call. = FALSE)
    name <- sub("^--", "", key)
    if (!name %in% names(out)) stop("Unknown argument: ", key, call. = FALSE)
    if (i == length(args) || startsWith(args[[i + 1L]], "--")) {
      stop("Missing value for ", key, call. = FALSE)
    }
    out[[name]] <- args[[i + 1L]]
    i <- i + 2L
  }
  out$width_mm <- as.numeric(out$width_mm)
  out$height_mm <- as.numeric(out$height_mm)
  out$dpi <- as.integer(out$dpi)
  out
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
if (nzchar(args$r_lib) && dir.exists(args$r_lib)) {
  .libPaths(c(args$r_lib, .libPaths()))
}

required_packages <- c("ggplot2", "patchwork", "svglite", "ragg")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0L) {
  stop(
    "Missing R package(s): ", paste(missing_packages, collapse = ", "),
    ". Install them before running this script.", call. = FALSE
  )
}

library(ggplot2)
library(patchwork)

palette <- c(
  YL = "#26A69A",
  ML = "#5E8EC8",
  OL = "#E87878"
)
group_levels <- c("YL", "ML", "OL")

property_specs <- data.frame(
  key = c("MW", "DBE", "O_C", "H_C", "N_C", "S_C", "AImod", "NOSC"),
  label = c("MW", "DBE", "O/C", "H/C", "N/C", "S/C", "AImod", "NOSC"),
  tag = letters[3:10],
  force_zero = c(FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE),
  digits = c(3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L),
  stringsAsFactors = FALSE
)

read_input <- function(path) {
  dat <- read.csv(
    path,
    check.names = FALSE,
    stringsAsFactors = FALSE,
    fileEncoding = "UTF-8-BOM"
  )
  required <- c(
    "sample_id", "Formula", "C", "H", "O", "N", "S", "Mass",
    "RI", "DBE", "O_C", "H_C", "AImod", "NOSC"
  )
  missing <- setdiff(required, names(dat))
  if (length(missing) > 0L) {
    stop("Missing required column(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  dat <- dat[dat$sample_id %in% group_levels, ]
  dat$sample_id <- factor(dat$sample_id, levels = group_levels)
  dat$MW <- suppressWarnings(as.numeric(dat$Mass))
  dat$N_C <- suppressWarnings(as.numeric(dat$N)) / suppressWarnings(as.numeric(dat$C))
  dat$S_C <- suppressWarnings(as.numeric(dat$S)) / suppressWarnings(as.numeric(dat$C))
  for (key in property_specs$key) dat[[key]] <- suppressWarnings(as.numeric(dat[[key]]))
  dat$RI <- suppressWarnings(as.numeric(dat$RI))
  dat
}

make_long_data <- function(dat) {
  pieces <- lapply(seq_len(nrow(property_specs)), function(i) {
    key <- property_specs$key[[i]]
    data.frame(
      sample_id = dat$sample_id,
      Formula = dat$Formula,
      RI = dat$RI,
      property = key,
      property_label = property_specs$label[[i]],
      value = dat[[key]],
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, pieces)
  out <- out[is.finite(out$value) & is.finite(out$RI) & out$RI >= 0, ]
  out$sample_id <- factor(out$sample_id, levels = group_levels)
  out$property <- factor(out$property, levels = property_specs$key)
  rownames(out) <- NULL
  out
}

summarize_properties <- function(long_dat) {
  rows <- vector("list", nrow(property_specs) * length(group_levels))
  k <- 0L
  for (key in property_specs$key) {
    for (group in group_levels) {
      k <- k + 1L
      x <- long_dat[
        long_dat$property == key & long_dat$sample_id == group,
        c("value", "RI")
      ]
      rows[[k]] <- data.frame(
        property = key,
        sample_id = group,
        n_formulas = nrow(x),
        arithmetic_mean = mean(x$value),
        median = median(x$value),
        q1 = unname(quantile(x$value, 0.25)),
        q3 = unname(quantile(x$value, 0.75)),
        RI_sum = sum(x$RI),
        RI_weighted_mean = weighted.mean(x$value, x$RI),
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

run_wilcoxon <- function(long_dat) {
  comparisons <- combn(group_levels, 2L, simplify = FALSE)
  rows <- vector("list", nrow(property_specs) * length(comparisons))
  k <- 0L
  for (key in property_specs$key) {
    for (comparison in comparisons) {
      k <- k + 1L
      x <- long_dat$value[
        long_dat$property == key & long_dat$sample_id == comparison[[1]]
      ]
      y <- long_dat$value[
        long_dat$property == key & long_dat$sample_id == comparison[[2]]
      ]
      test <- wilcox.test(x, y, alternative = "two.sided", exact = FALSE)
      rows[[k]] <- data.frame(
        property = key,
        group_1 = comparison[[1]],
        group_2 = comparison[[2]],
        n_1 = length(x),
        n_2 = length(y),
        statistic_W = unname(test$statistic),
        p_raw = test$p.value,
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  out$p_BH_FDR <- p.adjust(out$p_raw, method = "BH")
  out$p_raw_display <- format_p(out$p_raw)
  out$p_BH_FDR_display <- format_p(out$p_BH_FDR)
  out$FDR_class <- ifelse(
    out$p_BH_FDR < 0.001, "p < 0.001",
    ifelse(out$p_BH_FDR < 0.05, "p < 0.05", "not significant")
  )
  out
}

format_p <- function(x) {
  floor_value <- .Machine$double.xmin
  vapply(x, function(value) {
    if (!is.finite(value)) return(NA_character_)
    if (value == 0) return(paste0("<", format(floor_value, scientific = TRUE, digits = 3)))
    if (value < 0.001) return(format(value, scientific = TRUE, digits = 3))
    formatC(value, format = "f", digits = 4)
  }, character(1))
}

format_weighted <- function(x, digits) {
  formatC(x, format = "f", digits = digits)
}

make_sig_letters <- function(summary_dat, stats_dat) {
  out <- summary_dat[, c("property", "sample_id", "median")]
  out$sig_letter <- NA_character_
  alpha <- 0.05
  base_letters <- letters
  for (key in unique(out$property)) {
    idx <- out$property == key
    groups <- as.character(out$sample_id[idx])
    medians <- out$median[idx]
    prop_stats <- stats_dat[stats_dat$property == key, ]

    is_sig <- function(g1, g2) {
      hit <- prop_stats[
        (prop_stats$group_1 == g1 & prop_stats$group_2 == g2) |
          (prop_stats$group_1 == g2 & prop_stats$group_2 == g1),
      ]
      if (nrow(hit) == 0L) return(FALSE)
      is.finite(hit$p_BH_FDR[[1]]) && hit$p_BH_FDR[[1]] < alpha
    }

    non_sig <- function(g1, g2) !is_sig(g1, g2)
    letters <- setNames(rep(NA_character_, length(groups)), groups)
    ordered_groups <- groups[order(medians, decreasing = TRUE)]

    if (all(vapply(combn(groups, 2L, simplify = FALSE), function(pair) {
      non_sig(pair[[1]], pair[[2]])
    }, logical(1)))) {
      letters[] <- "a"
    } else if (all(vapply(combn(groups, 2L, simplify = FALSE), function(pair) {
      is_sig(pair[[1]], pair[[2]])
    }, logical(1)))) {
      letters[ordered_groups] <- base_letters[seq_along(ordered_groups)]
    } else {
      shared_pair <- NULL
      for (pair in combn(groups, 2L, simplify = FALSE)) {
        if (non_sig(pair[[1]], pair[[2]])) {
          shared_pair <- pair
          break
        }
      }
      if (is.null(shared_pair)) {
        letters[ordered_groups] <- base_letters[seq_along(ordered_groups)]
      } else {
        other_group <- setdiff(groups, shared_pair)
        letters[shared_pair] <- "a"
        letters[other_group] <- "b"
      }
    }
    out$sig_letter[idx] <- unname(letters[groups])
  }
  out[, c("property", "sample_id", "sig_letter")]
}

panel_limits <- function(values, force_zero) {
  values <- values[is.finite(values)]
  data_min <- min(values)
  data_max <- max(values)
  span <- data_max - data_min
  if (!is.finite(span) || span <= 0) span <- max(abs(data_max), 1)
  lower <- if (force_zero && data_min >= 0) 0 else data_min - 0.06 * span
  upper <- data_max + 0.22 * span
  annotation_y <- data_max + 0.095 * span
  c(lower = lower, upper = upper, annotation_y = annotation_y)
}

y_breaks_for_property <- function(key, values) {
  if (key == "MW") return(c(250, 500, 750))
  if (key == "DBE") return(c(0, 10, 20))
  if (key == "O_C") return(c(0.0, 0.5, 1.0))
  if (key %in% c("N_C", "S_C")) return(c(0.0, 0.1, 0.2, 0.3))
  if (key == "AImod") return(c(0.0, 0.5, 1.0, 1.5))
  if (key == "NOSC") return(c(-2, 0, 2))
  scales::breaks_pretty(n = 4)(values)
}

visual_limits_for_property <- function(key, limits) {
  fixed_limits <- switch(
    key,
    MW = c(lower = 100, upper = 950),
    DBE = c(lower = -3, upper = 30),
    O_C = c(lower = 0, upper = 1.25),
    N_C = c(lower = -0.04, upper = 0.36),
    S_C = c(lower = -0.04, upper = 0.36),
    AImod = c(lower = -0.12, upper = 1.80),
    NOSC = c(lower = -3.5, upper = 3.6),
    NULL
  )
  if (is.null(fixed_limits)) return(limits)
  limits[["lower"]] <- fixed_limits[["lower"]]
  limits[["upper"]] <- fixed_limits[["upper"]]
  limits[["annotation_y"]] <- fixed_limits[["upper"]] - 0.08 * diff(fixed_limits)
  limits
}

lower_padding_for_property <- function(key, limits) {
  if (!key %in% c("N_C", "S_C", "AImod")) return(limits)
  span <- limits[["upper"]] - limits[["lower"]]
  limits[["lower"]] <- limits[["lower"]] - 0.075 * span
  limits
}

make_panel <- function(key, label, tag, force_zero, digits, long_dat, summary_dat, sig_letters) {
  dat <- long_dat[long_dat$property == key, ]
  dat$sample_id <- factor(dat$sample_id, levels = group_levels)
  annotations <- summary_dat[summary_dat$property == key, ]
  annotations <- merge(
    annotations,
    sig_letters[sig_letters$property == key, ],
    by = c("property", "sample_id"),
    all.x = TRUE,
    sort = FALSE
  )
  annotations$sample_id <- factor(annotations$sample_id, levels = group_levels)
  limits <- panel_limits(dat$value, force_zero)
  limits <- visual_limits_for_property(key, limits)
  y_breaks <- y_breaks_for_property(key, c(limits[["lower"]], limits[["upper"]]))
  annotations$y <- limits[["annotation_y"]]
  annotations$label <- annotations$sig_letter
  guides <- data.frame(
    x = seq_along(group_levels),
    sample_id = factor(group_levels, levels = group_levels)
  )

  ggplot(dat, aes(x = sample_id, y = value, fill = sample_id)) +
    geom_vline(
      data = guides,
      aes(xintercept = x, colour = sample_id),
      inherit.aes = FALSE,
      linewidth = 0.28,
      alpha = 0.18
    ) +
    geom_violin(
      width = 0.82,
      trim = TRUE,
      scale = "width",
      alpha = 0.60,
      colour = NA
    ) +
    geom_boxplot(
      width = 0.17,
      outlier.shape = NA,
      fill = "white",
      colour = "#202020",
      linewidth = 0.28,
      alpha = 0.95
    ) +
    stat_summary(
      fun = mean,
      geom = "point",
      shape = 21,
      size = 1.55,
      stroke = 0.28,
      fill = "white",
      colour = "#202020"
    ) +
    geom_text(
      data = annotations,
      aes(x = sample_id, y = y, label = label),
      inherit.aes = FALSE,
      family = "Arial",
      size = 2.35,
      colour = "#202020",
      vjust = 0.5,
      fontface = "bold"
    ) +
    scale_fill_manual(values = palette, guide = "none") +
    scale_colour_manual(values = palette, guide = "none") +
    scale_x_discrete(drop = FALSE) +
    scale_y_continuous(
      expand = c(0, 0),
      breaks = y_breaks
    ) +
    coord_cartesian(
      ylim = c(limits[["lower"]], limits[["upper"]]),
      clip = "off"
    ) +
    labs(x = NULL, y = label, tag = tag) +
    theme_classic(base_size = 7.2, base_family = "Arial") +
    theme(
      panel.grid.major.y = element_line(colour = "#E4E4E4", linewidth = 0.25),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      axis.line = element_line(colour = "black", linewidth = 0.35),
      axis.ticks = element_line(colour = "black", linewidth = 0.32),
      axis.ticks.length = grid::unit(1.4, "mm"),
      axis.text = element_text(colour = "black", size = 6.2),
      axis.text.x = element_text(margin = margin(t = 2.0)),
      axis.text.y = element_text(margin = margin(r = 2.0)),
      axis.title.y = element_text(
        colour = "black", size = 7.0, face = "bold", margin = margin(r = 3.0)
      ),
      plot.tag = element_text(
        family = "Arial", face = "bold", size = 8.0, colour = "black"
      ),
      plot.tag.position = c(-0.08, 1.03),
      plot.margin = margin(5.5, 5.5, 4.5, 7.5)
    )
}

write_caption <- function(path) {
  caption <- paste(
    "Distributions of molecular properties in YL, ML, and OL.",
    "Violin plots show molecular-formula-level density distributions; boxes denote",
    "interquartile ranges with median lines, and white dots indicate arithmetic means.",
    "Letters above violins indicate compact pairwise significance groups; groups",
    "sharing a letter are not significantly different after Benjamini-Hochberg correction.",
    "Pairwise differences were assessed using two-sided Wilcoxon rank-sum tests with",
    "Benjamini-Hochberg FDR correction across 24 comparisons.",
    "All adjusted comparisons had p < 0.001 except all MW comparisons and the YL-OL",
    "comparison for S/C.",
    "These tests describe molecular-formula distributions and do not represent",
    "site-level inference based on biological replicates."
  )
  writeLines(caption, path, useBytes = TRUE)
}

write_qa <- function(dat, long_dat, summary_dat, stats_dat, path) {
  sample_counts <- table(factor(dat$sample_id, levels = group_levels))
  expected <- c(YL = 3765L, ML = 8807L, OL = 8250L)
  qa <- rbind(
    data.frame(
      check = paste0("sample_count_", group_levels),
      value = as.character(as.integer(sample_counts)),
      expected = as.character(expected[group_levels]),
      status = ifelse(as.integer(sample_counts) == expected[group_levels], "PASS", "FAIL")
    ),
    data.frame(
      check = paste0("RI_sum_", group_levels),
      value = formatC(
        vapply(group_levels, function(g) sum(dat$RI[dat$sample_id == g]), numeric(1)),
        format = "f", digits = 12
      ),
      expected = "1.000000000000",
      status = ifelse(
        abs(vapply(group_levels, function(g) sum(dat$RI[dat$sample_id == g]), numeric(1)) - 1) < 1e-8,
        "PASS", "FAIL"
      )
    ),
    data.frame(
      check = c("property_rows_long", "weighted_summary_rows", "wilcoxon_tests", "FDR_lt_0.001_tests"),
      value = as.character(c(nrow(long_dat), nrow(summary_dat), nrow(stats_dat), sum(stats_dat$p_BH_FDR < 0.001))),
      expected = as.character(c(nrow(dat) * 8L, 24L, 24L, 20L)),
      status = ifelse(
        c(
          nrow(long_dat) == nrow(dat) * 8L,
          nrow(summary_dat) == 24L,
          nrow(stats_dat) == 24L,
          sum(stats_dat$p_BH_FDR < 0.001) == 20L
        ),
        "PASS", "FAIL"
      )
    )
  )
  write.csv(qa, path, row.names = FALSE, fileEncoding = "UTF-8")
}

export_figure <- function(plot, base, width_mm, height_mm, dpi) {
  width_in <- width_mm / 25.4
  height_in <- height_mm / 25.4

  svglite::svglite(
    paste0(base, ".svg"),
    width = width_in,
    height = height_in,
    bg = "white",
    system_fonts = list(sans = "Arial")
  )
  print(plot)
  grDevices::dev.off()

  grDevices::cairo_pdf(
    paste0(base, ".pdf"),
    width = width_in,
    height = height_in,
    family = "Arial",
    bg = "white"
  )
  print(plot)
  grDevices::dev.off()

  grDevices::png(
    paste0(base, ".png"),
    width = width_in,
    height = height_in,
    units = "in",
    res = dpi,
    bg = "white",
    type = "cairo-png"
  )
  print(plot)
  grDevices::dev.off()

  grDevices::tiff(
    paste0(base, ".tiff"),
    width = width_in,
    height = height_in,
    units = "in",
    res = dpi,
    compression = "lzw",
    bg = "white",
    type = "cairo"
  )
  print(plot)
  grDevices::dev.off()
}

dir.create(args$figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(args$table_dir, recursive = TRUE, showWarnings = FALSE)

dat <- read_input(args$input_csv)
long_dat <- make_long_data(dat)
summary_dat <- summarize_properties(long_dat)
stats_dat <- run_wilcoxon(long_dat)
sig_letters <- make_sig_letters(summary_dat, stats_dat)

panels <- lapply(seq_len(nrow(property_specs)), function(i) {
  make_panel(
    property_specs$key[[i]],
    property_specs$label[[i]],
    property_specs$tag[[i]],
    property_specs$force_zero[[i]],
    property_specs$digits[[i]],
    long_dat,
    summary_dat,
    sig_letters
  )
})
combined <- wrap_plots(panels, ncol = 4L, byrow = TRUE) +
  plot_layout(guides = "collect") &
  theme(plot.background = element_rect(fill = "white", colour = NA))

figure_base <- file.path(args$figure_dir, args$prefix)
table_base <- file.path(args$table_dir, args$prefix)

write.csv(
  dat[, c(
    "sample_id", "Formula", "RI", "MW", "DBE", "O_C", "H_C",
    "N_C", "S_C", "AImod", "NOSC"
  )],
  paste0(table_base, "_source_data.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)
write.csv(
  summary_dat,
  paste0(table_base, "_summary.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)
write.csv(
  sig_letters,
  paste0(table_base, "_significance_letters.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)
write.csv(
  stats_dat,
  paste0(table_base, "_Wilcoxon_BH_results.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)
write_qa(
  dat, long_dat, summary_dat, stats_dat,
  paste0(table_base, "_QA.csv")
)
write_caption(paste0(table_base, "_caption.txt"))
export_figure(combined, figure_base, args$width_mm, args$height_mm, args$dpi)

message("Saved figure outputs to: ", normalizePath(args$figure_dir, winslash = "/"))
message("Saved source/statistics outputs to: ", normalizePath(args$table_dir, winslash = "/"))
message("Formula counts: ", paste(names(table(dat$sample_id)), as.integer(table(dat$sample_id)), collapse = ", "))

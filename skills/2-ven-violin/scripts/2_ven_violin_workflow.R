#!/usr/bin/env Rscript

# Combined Nature-style figure:
# a Venn diagram; b shared-formula VK scatter;
# c-j significant molecular-property violin plots.

parse_args <- function(args) {
  out <- list(
    input = NULL,
    output = NULL,
    prefix = "ML0_OL0_shared_VK_violin_combined",
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
  out$dpi <- as.integer(out$dpi)
  out
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
if (is.null(args$input)) {
  stop("Use --input INPUT_DIR. INPUT_DIR should contain Venn_ML0_OL0, Shared_VK_scatter, and Wilcoxon rank-sum test.", call. = FALSE)
}

base_dir <- normalizePath(args$input, winslash = "/", mustWork = TRUE)
venn_dir <- file.path(base_dir, "Venn_ML0_OL0")
vk_dir <- file.path(base_dir, "Shared_VK_scatter")
wilcox_dir <- file.path(base_dir, "Wilcoxon rank-sum test")
output_dir <- if (is.null(args$output)) file.path(base_dir, "Combined_shared_VK_violin_figure") else args$output
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

required_pkgs <- c("ggplot2", "patchwork", "ragg", "ggrastr")
missing <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  stop(
    sprintf(
      "Missing R package(s): %s\nInstall with: install.packages(c(%s))",
      paste(missing, collapse = ", "),
      paste(sprintf("\"%s\"", missing), collapse = ", ")
    ),
    call. = FALSE
  )
}

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
  library(ragg)
  library(ggrastr)
})

fmt_int <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)

theme_panel_tag <- function() {
  theme(
    plot.tag = element_text(size = 10.5, face = "bold", colour = "black", family = "Arial"),
    plot.tag.position = c(0.015, 0.985)
  )
}

circle_df <- function(cx, cy, r, id, n = 720) {
  theta <- seq(0, 2 * pi, length.out = n)
  data.frame(x = cx + r * cos(theta), y = cy + r * sin(theta), id = id)
}

make_venn_panel <- function() {
  counts <- read.csv(file.path(venn_dir, "ML0_OL0_venn_counts.csv"), stringsAsFactors = FALSE)
  get_count <- function(name) counts$molecular_count[counts$category == name][[1]]
  ml_only <- get_count("ML-0 only")
  shared <- get_count("Shared")
  ol_only <- get_count("OL-0 only")
  ml_total <- get_count("ML-0 total")
  ol_total <- get_count("OL-0 total")

  circles <- rbind(
    circle_df(4.15, 3.15, 2.86, "ML"),
    circle_df(5.85, 3.15, 2.86, "OL")
  )

  ggplot(circles, aes(x, y, group = id, fill = id, colour = id)) +
    geom_polygon(alpha = 0.46, linewidth = 0.7) +
    annotate("text", x = 2.75, y = 3.25, label = fmt_int(ml_only), size = 5.0, fontface = "bold", family = "Arial") +
    annotate("text", x = 5.00, y = 3.25, label = fmt_int(shared), size = 5.0, fontface = "bold", family = "Arial") +
    annotate("text", x = 7.25, y = 3.25, label = fmt_int(ol_only), size = 5.0, fontface = "bold", family = "Arial") +
    annotate("text", x = 2.75, y = 2.75, label = "ML only", size = 3.0, family = "Arial") +
    annotate("text", x = 5.00, y = 2.75, label = "Shared", size = 3.0, family = "Arial") +
    annotate("text", x = 7.25, y = 2.75, label = "OL only", size = 3.0, family = "Arial") +
    annotate("text", x = 3.00, y = 6.72, label = "ML", size = 4.0, fontface = "bold", family = "Arial", colour = "#1F4E79") +
    annotate("text", x = 7.00, y = 6.72, label = "OL", size = 4.0, fontface = "bold", family = "Arial", colour = "#9C2F32") +
    annotate("text", x = 3.00, y = 6.34, label = paste0("n = ", fmt_int(ml_total)), size = 2.65, family = "Arial", colour = "#1F4E79") +
    annotate("text", x = 7.00, y = 6.34, label = paste0("n = ", fmt_int(ol_total)), size = 2.65, family = "Arial", colour = "#9C2F32") +
    scale_fill_manual(values = c("ML" = "#9FB8CF", "OL" = "#F0A3A5"), guide = "none") +
    scale_colour_manual(values = c("ML" = "#1F4E79", "OL" = "#9C2F32"), guide = "none") +
    coord_equal(xlim = c(0.75, 9.25), ylim = c(0.15, 7.22), clip = "off") +
    labs(tag = "a") +
    theme_void(base_family = "Arial") +
    theme(plot.margin = margin(7, 7, 7, 7)) +
    theme_panel_tag()
}

vk_segments <- data.frame(
  x = c(0, 0.3, 0.67, 0, 0, 0, 0.1, 0.3, 0.67, 1.0, 1.2, 0, 0.67),
  xend = c(0.3, 0.67, 1.2, 1.2, 0.67, 0.67, 0.1, 0.3, 0.67, 1.0, 1.2, 0, 1.0),
  y = c(2.0, 2.2, 2.4, 1.5, 0.7, 0.2, 0.7, 1.5, 0.2, 0.6, 1.5, 0.2, 0.6),
  yend = c(2.0, 2.2, 2.4, 1.5, 0.7, 0.2, 1.5, 2.2, 2.4, 1.5, 2.4, 2.0, 0.6)
)

theme_vk_panel <- function() {
  theme_classic(base_size = 9, base_family = "Arial") +
    theme(
      panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.55),
      axis.line = element_line(colour = "black", linewidth = 0.35),
      axis.ticks = element_line(colour = "black", linewidth = 0.35),
      axis.ticks.length = grid::unit(1.3, "mm"),
      axis.title = element_text(size = 10.2, face = "bold", colour = "black"),
      axis.text = element_text(size = 8.2, colour = "black"),
      plot.margin = margin(7, 10, 7, 7),
      legend.position = "none"
    ) +
    theme_panel_tag()
}

make_vk_panel <- function() {
  dat <- read.csv(file.path(vk_dir, "Shared_5662_VK_scatter_source_data.csv"), check.names = FALSE)
  if ("O/C" %in% names(dat)) names(dat)[names(dat) == "O/C"] <- "O_C"
  if ("H/C" %in% names(dat)) names(dat)[names(dat) == "H/C"] <- "H_C"
  dat$O_C <- as.numeric(dat$O_C)
  dat$H_C <- as.numeric(dat$H_C)
  dat <- dat[is.finite(dat$O_C) & is.finite(dat$H_C), ]
  n_label <- paste0("n=", fmt_int(nrow(dat)))

  ggplot(dat, aes(O_C, H_C)) +
    ggrastr::geom_point_rast(size = 0.62, alpha = 0.78, stroke = 0, colour = "#2B83BA", raster.dpi = args$dpi) +
    geom_segment(
      data = vk_segments,
      aes(x = x, xend = xend, y = y, yend = yend),
      inherit.aes = FALSE,
      colour = "black",
      linetype = "dashed",
      linewidth = 0.20
    ) +
    annotate("text", x = 0.03, y = 2.43, label = "Shared", hjust = 0, vjust = 1, size = 3.5, fontface = "bold", family = "Arial") +
    annotate("text", x = 1.17, y = 0.05, label = n_label, hjust = 1, vjust = 0, size = 3.2, fontface = "bold", family = "Arial") +
    scale_x_continuous(limits = c(-0.02, 1.22), expand = c(0, 0), breaks = seq(0, 1.2, by = 0.3)) +
    scale_y_continuous(limits = c(-0.05, 2.55), expand = c(0, 0), breaks = seq(0, 2.5, by = 0.5)) +
    labs(x = "O/C", y = "H/C", tag = "b") +
    coord_cartesian(clip = "off") +
    theme_vk_panel()
}

label_map <- c(
  Neutral_mz = "MW",
  DBE = "DBE",
  O_C = "O/C",
  H_C = "H/C",
  N_C = "N/C",
  S_C = "S/C",
  AImod = "AImod",
  NOSC = "NOSC"
)

display_label <- function(prop) {
  if (prop %in% names(label_map)) return(unname(label_map[[prop]]))
  prop
}

format_wa <- function(x) formatC(as.numeric(x), format = "f", digits = 3)

theme_violin_panel <- function() {
  theme_classic(base_size = 8, base_family = "Arial") +
    theme(
      plot.background = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA),
      axis.line = element_line(colour = "black", linewidth = 0.42),
      axis.ticks = element_line(colour = "black", linewidth = 0.35),
      axis.ticks.length = grid::unit(1.2, "mm"),
      axis.text.x = element_text(size = 7.7, colour = "black"),
      axis.text.y = element_text(size = 7.7, colour = "black"),
      axis.title.x = element_blank(),
      axis.title.y = element_text(size = 8.7, face = "bold", colour = "black"),
      legend.position = "none",
      panel.grid.major.y = element_line(colour = "#EAEAEA", linewidth = 0.22),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      plot.margin = margin(5, 7, 4, 7)
    ) +
    theme_panel_tag()
}

make_violin_panel <- function(prop, tag) {
  long_df <- read.csv(file.path(wilcox_dir, "ML0_OL0_final_property_values_long_format.csv"), check.names = FALSE)
  weighted <- read.csv(file.path(wilcox_dir, "ML0_OL0_RI_weighted_mean_Wilcoxon_summary.csv"), check.names = FALSE)
  dat <- long_df[long_df$property == prop & long_df$group %in% c("ML-0", "OL-0"), ]
  dat$value <- suppressWarnings(as.numeric(dat$value))
  dat <- dat[is.finite(dat$value), ]
  dat$group <- factor(dat$group, levels = c("ML-0", "OL-0"))
  meta <- weighted[weighted$property == prop, ]
  prop_label <- display_label(prop)
  ann <- data.frame(
    group = factor(c("ML-0", "OL-0"), levels = c("ML-0", "OL-0")),
    label = c(
      paste0(prop_label, "wa=", format_wa(meta[["ML-0 weighted mean across replicates"]][[1]])),
      paste0(prop_label, "wa=", format_wa(meta[["OL-0 weighted mean across replicates"]][[1]]))
    )
  )
  y_range <- range(dat$value, na.rm = TRUE)
  y_span <- diff(y_range)
  if (!is.finite(y_span) || y_span == 0) y_span <- 1
  y_top <- y_range[[2]] + y_span * 0.18
  y_label <- y_range[[2]] + y_span * 0.095
  y_bottom <- y_range[[1]] - y_span * 0.06
  ann$y <- y_label

  ggplot(dat, aes(group, value, fill = group)) +
    geom_violin(width = 0.78, trim = FALSE, alpha = 0.64, colour = NA) +
    geom_boxplot(width = 0.18, outlier.shape = NA, alpha = 0.96, fill = "white", colour = "black", linewidth = 0.32) +
    stat_summary(fun = mean, geom = "point", shape = 21, size = 1.65, stroke = 0.32, fill = "white", colour = "black") +
    geom_text(data = ann, aes(x = group, y = y, label = label), inherit.aes = FALSE, hjust = 0.5, vjust = 1, size = 2.05, family = "Arial") +
    scale_fill_manual(values = c("ML-0" = "#5DA5B3", "OL-0" = "#E79A9A")) +
    scale_x_discrete(labels = c("ML-0" = "ML", "OL-0" = "OL")) +
    scale_y_continuous(expand = c(0, 0)) +
    labs(y = prop_label, tag = tag) +
    coord_cartesian(ylim = c(y_bottom, y_top), clip = "off") +
    theme_violin_panel()
}

props <- c("Neutral_mz", "DBE", "O_C", "H_C", "N_C", "S_C", "AImod", "NOSC")
tags <- letters[3:10]
violins <- Map(make_violin_panel, props, tags)

top <- make_venn_panel() + make_vk_panel() +
  patchwork::plot_layout(widths = c(1, 1))
row1 <- patchwork::wrap_plots(violins[1:4], nrow = 1)
row2 <- patchwork::wrap_plots(violins[5:8], nrow = 1)

combined <- top / row1 / row2 +
  patchwork::plot_layout(heights = c(1.08, 1, 1)) &
  theme(plot.background = element_rect(fill = "white", colour = NA))

base <- file.path(output_dir, args$prefix)
width_mm <- 225
height_mm <- 185
width_in <- width_mm / 25.4
height_in <- height_mm / 25.4

grDevices::cairo_pdf(paste0(base, ".pdf"), width = width_in, height = height_in, family = "Arial")
print(combined)
grDevices::dev.off()

ragg::agg_png(paste0(base, ".png"), width = width_in, height = height_in, units = "in", res = args$dpi, background = "white")
print(combined)
grDevices::dev.off()

ragg::agg_tiff(paste0(base, ".tiff"), width = width_in, height = height_in, units = "in", res = args$dpi, background = "white", compression = "lzw")
print(combined)
grDevices::dev.off()

cat("Combined figure output directory:", output_dir, "\n")
cat("PDF:", paste0(base, ".pdf"), "\n")
cat("PNG:", paste0(base, ".png"), "\n")
cat("TIFF:", paste0(base, ".tiff"), "\n")

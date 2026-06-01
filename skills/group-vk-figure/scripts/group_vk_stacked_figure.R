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
  out <- list()
  i <- 1
  while (i <= length(args)) {
    key <- args[[i]]
    if (!startsWith(key, "--")) {
      stop("Unexpected argument: ", key, call. = FALSE)
    }
    name <- sub("^--", "", key)
    if (i == length(args) || startsWith(args[[i + 1]], "--")) {
      out[[name]] <- TRUE
      i <- i + 1
    } else {
      out[[name]] <- args[[i + 1]]
      i <- i + 2
    }
  }
  out
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
if (is.null(args[["input-summary"]])) {
  stop("Missing required argument: --input-summary", call. = FALSE)
}

input_summary <- normalizePath(args[["input-summary"]], winslash = "/", mustWork = TRUE)
input_dir <- dirname(input_summary)
sheet_name <- if (!is.null(args[["sheet"]])) args[["sheet"]] else "汇总表"
output_dir <- if (!is.null(args[["output-dir"]])) args[["output-dir"]] else file.path(input_dir, "Group_VK_RI_stacked_figures")
output_dir <- normalizePath(output_dir, winslash = "/", mustWork = FALSE)
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

prefix <- if (!is.null(args[["prefix"]])) args[["prefix"]] else "DOM_Group_VK_ML_OL_stacked"
source_out <- file.path(output_dir, paste0(prefix, "_source_data.csv"))

sample_levels <- if (!is.null(args[["sample-order"]])) {
  trimws(strsplit(args[["sample-order"]], ",", fixed = TRUE)[[1]])
} else {
  c("ML-0", "ML-0.2", "ML-0.5", "ML-1", "OL-0", "OL-0.2", "OL-0.5", "OL-1")
}

group_levels <- c("CHO", "CHON", "CHONS", "CHOS", "Others")
vk_levels <- c(
  "Lipids",
  "Aliphatic/proteins",
  "Lignin/CRAM-like structures",
  "Carbohydrates",
  "Unsaturated hydrocarbons",
  "Aromatic structures",
  "Tannin",
  "Others"
)

group_colors <- c(
  "CHO" = "#5B8DB8",
  "CHON" = "#D89070",
  "CHONS" = "#78A978",
  "CHOS" = "#C6A15B",
  "Others" = "#B8B8B8"
)

vk_colors <- c(
  "Lipids" = "#7FA6C9",
  "Aliphatic/proteins" = "#E2B47A",
  "Lignin/CRAM-like structures" = "#8F8CC0",
  "Carbohydrates" = "#86B8B2",
  "Unsaturated hydrocarbons" = "#A7C8A2",
  "Aromatic structures" = "#C78282",
  "Tannin" = "#B996C6",
  "Others" = "#B7B7B7"
)

vk_legend_labels <- c(
  "Lipids" = "Lipids",
  "Aliphatic/proteins" = "Aliphatic/proteins",
  "Lignin/CRAM-like structures" = "Lignin/CRAM-like structures",
  "Carbohydrates" = "Carbohydrates",
  "Unsaturated hydrocarbons" = "Unsaturated hydrocarbons",
  "Aromatic structures" = "Aromatic structures",
  "Tannin" = "Tannin",
  "Others" = "Others"
)

read_summary <- function(path, sheet) {
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("xlsx", "xls")) {
    available_sheets <- readxl::excel_sheets(path)
    selected_sheet <- if (sheet %in% available_sheets) sheet else available_sheets[[1]]
    readxl::read_excel(path, sheet = selected_sheet)
  } else if (ext %in% c("csv", "txt")) {
    readr::read_csv(path, show_col_types = FALSE)
  } else {
    stop("Unsupported input file type: ", ext, call. = FALSE)
  }
}

summary_dat <- read_summary(input_summary, sheet_name)
names(summary_dat) <- trimws(names(summary_dat))

required_cols <- c("Sample", "Dimension", "Category", "RI sum")
missing_cols <- setdiff(required_cols, names(summary_dat))
if (length(missing_cols) > 0) {
  stop("Input summary is missing required columns: ", paste(missing_cols, collapse = ", "), call. = FALSE)
}

panel_data <- summary_dat %>%
  mutate(
    Sample = as.character(.data$Sample),
    Dimension = as.character(.data$Dimension),
    Category = as.character(.data$Category),
    `RI sum` = as.numeric(.data$`RI sum`),
    SampleGroup = sub("-[123]$", "", .data$Sample),
    L_class = if_else(grepl("^ML", .data$SampleGroup), "ML", "OL"),
    Category = case_when(
      .data$Dimension == "Group" & .data$Category %in% group_levels ~ .data$Category,
      .data$Dimension == "Group" ~ "Others",
      .data$Dimension == "VK" & .data$Category %in% vk_levels ~ .data$Category,
      .data$Dimension == "VK" ~ "Others",
      TRUE ~ .data$Category
    )
  ) %>%
  filter(.data$Dimension %in% c("Group", "VK")) %>%
  group_by(.data$L_class, .data$SampleGroup, .data$Dimension, .data$Category) %>%
  summarise(
    RI_percent = mean(.data$`RI sum`, na.rm = TRUE) * 100,
    n_replicates = n(),
    .groups = "drop"
  ) %>%
  mutate(SampleGroup = factor(.data$SampleGroup, levels = sample_levels))

complete_panel <- function(dat, dimension, levels_vec) {
  dat %>%
    filter(.data$Dimension == dimension) %>%
    complete(
      SampleGroup = factor(sample_levels, levels = sample_levels),
      Category = levels_vec,
      fill = list(RI_percent = 0, n_replicates = 0)
    ) %>%
    mutate(
      Dimension = dimension,
      Category = factor(.data$Category, levels = levels_vec),
      SampleGroup = factor(.data$SampleGroup, levels = sample_levels)
    )
}

theme_dom_bar <- function(base_size = 14) {
  theme_classic(base_size = base_size, base_family = "Arial") +
    theme(
      panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.70),
      axis.line = element_blank(),
      axis.ticks = element_line(colour = "black", linewidth = 0.45),
      axis.ticks.length = unit(1.6, "mm"),
      axis.text = element_text(colour = "black", size = 14),
      axis.title = element_text(colour = "black", size = 18, face = "bold"),
      plot.title = element_blank(),
      legend.position = "top",
      legend.title = element_blank(),
      legend.text = element_text(size = base_size - 4.0),
      legend.text.align = 0,
      legend.key.width = unit(3.4, "mm"),
      legend.key.height = unit(3.4, "mm"),
      legend.spacing.x = unit(0.6, "mm"),
      legend.spacing.y = unit(0.6, "mm"),
      legend.box.margin = margin(0, 0, 2, 0),
      plot.margin = margin(3, 4, 3, 4)
    )
}

make_bar <- function(dat, fill_values, legend_nrow = 1, fill_labels = waiver()) {
  first_sample <- as.character(dat$SampleGroup[which(!is.na(dat$SampleGroup))[1]])
  legend_dummy <- data.frame(
    SampleGroup = factor(rep(first_sample, length(fill_values)), levels = sample_levels),
    RI_percent = rep(50, length(fill_values)),
    Category = factor(names(fill_values), levels = names(fill_values))
  )

  ggplot(dat, aes(x = .data$SampleGroup, y = .data$RI_percent, fill = .data$Category)) +
    geom_col(width = 0.68, colour = "white", linewidth = 0.18, show.legend = FALSE) +
    geom_point(
      data = legend_dummy,
      aes(x = .data$SampleGroup, y = .data$RI_percent, fill = .data$Category),
      inherit.aes = FALSE,
      shape = 22,
      size = 4.0,
      colour = "transparent",
      alpha = 0,
      show.legend = TRUE
    ) +
    scale_fill_manual(
      values = fill_values,
      breaks = names(fill_values),
      labels = fill_labels,
      drop = FALSE,
      name = NULL
    ) +
    guides(fill = guide_legend(
      nrow = legend_nrow,
      byrow = TRUE,
      keywidth = unit(3.4, "mm"),
      keyheight = unit(3.4, "mm"),
      override.aes = list(shape = 22, size = 3.6, alpha = 1, colour = "transparent", linewidth = 0)
    )) +
    scale_y_continuous(
      limits = c(0, 100),
      breaks = seq(0, 100, 25),
      expand = expansion(mult = c(0, 0.02))
    ) +
    labs(x = NULL, y = "RI (%)", title = NULL) +
    coord_cartesian(clip = "off") +
    theme_dom_bar()
}

p_group <- make_bar(
  complete_panel(panel_data, "Group", group_levels),
  group_colors,
  legend_nrow = 1
)

p_vk <- make_bar(
  complete_panel(panel_data, "VK", vk_levels),
  vk_colors,
  legend_nrow = 2,
  fill_labels = vk_legend_labels
)

combined <- p_group + p_vk +
  plot_layout(nrow = 1, widths = c(1, 1), guides = "keep")

readr::write_csv(panel_data, source_out)

base_out <- file.path(output_dir, prefix)
ggsave(paste0(base_out, ".svg"), combined, width = 16.93, height = 5.64, units = "in", device = svglite::svglite)
ggsave(paste0(base_out, ".pdf"), combined, width = 16.93, height = 5.64, units = "in", device = cairo_pdf)
ragg::agg_tiff(paste0(base_out, ".tiff"), width = 16.93, height = 5.64, units = "in", res = 600, compression = "lzw")
print(combined)
dev.off()
ragg::agg_png(paste0(base_out, ".png"), width = 16.93, height = 5.64, units = "in", res = 240)
print(combined)
dev.off()

qa <- panel_data %>%
  group_by(.data$L_class, .data$SampleGroup, .data$Dimension) %>%
  summarise(total_RI_percent = sum(.data$RI_percent), .groups = "drop")

print(qa)
message("Saved figure base: ", base_out)

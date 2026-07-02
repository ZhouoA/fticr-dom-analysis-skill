options(stringsAsFactors = FALSE)

args <- getOption(
  "pretreatment_script_args",
  commandArgs(trailingOnly = TRUE)
)
input_dir <- if (length(args) >= 1) args[[1]] else "."
output_dir <- if (length(args) >= 2) args[[2]] else file.path(input_dir, "output")
prefix <- if (length(args) >= 3) args[[3]] else "Pretreatment_VK_Marginal"

required_packages <- c(
  "openxlsx", "dplyr", "tidyr", "ggplot2", "patchwork",
  "readr", "svglite", "ragg"
)
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0) {
  stop("Missing R packages: ", paste(missing_packages, collapse = ", "), call. = FALSE)
}

library(openxlsx)
library(dplyr)
library(tidyr)
library(ggplot2)
library(patchwork)
library(readr)

input_dir <- normalizePath(input_dir, winslash = "/", mustWork = TRUE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)

stage_levels <- c("Removed", "Produced", "Shared")
age_levels <- getOption("dom_pair_age_levels", c("YL", "ML", "OL"))
stage_colors <- c(
  "Removed" = "#4E79A7",
  "Produced" = "#E15759",
  "Shared" = "#59A14F"
)

sample_pairs <- getOption(
  "dom_pair_sample_pairs",
  tibble::tribble(
    ~Age, ~Raw, ~Reservoir,
    "YL", "YL.xlsx", "YLr.csv",
    "ML", "ML.xlsx", "MLr.csv",
    "OL", "OL.xlsx", "OLr.csv"
  )
)
left_ids <- getOption(
  "dom_pair_left_ids",
  c("YL" = "YL", "ML" = "ML", "OL" = "OL")
)
right_ids <- getOption(
  "dom_pair_right_ids",
  c("YL" = "YLr", "ML" = "MLr", "OL" = "OLr")
)
pair_labels <- getOption(
  "dom_pair_labels",
  c(
    "YL" = "YL vs. YLr",
    "ML" = "ML vs. MLr",
    "OL" = "OL vs. OLr"
  )
)

read_formula_table <- function(path, sample_id) {
  if (!file.exists(path)) stop("Missing input: ", path, call. = FALSE)
  dat <- if (tolower(tools::file_ext(path)) == "xlsx") {
    openxlsx::read.xlsx(path)
  } else {
    readr::read_csv(path, show_col_types = FALSE)
  }
  required <- c("Formula", "O/C", "H/C")
  missing <- setdiff(required, names(dat))
  if (length(missing) > 0) {
    stop(sample_id, " missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  out <- dat %>%
    transmute(
      Sample = sample_id,
      Formula = trimws(as.character(Formula)),
      O_C = suppressWarnings(as.numeric(`O/C`)),
      H_C = suppressWarnings(as.numeric(`H/C`))
    )
  if (any(is.na(out$Formula) | out$Formula == "")) {
    stop(sample_id, " contains blank formulas", call. = FALSE)
  }
  if (anyDuplicated(out$Formula) > 0) {
    stop(sample_id, " contains duplicated formulas", call. = FALSE)
  }
  out
}

classify_pair <- function(age, raw_file, reservoir_file) {
  raw_id <- unname(left_ids[[age]])
  reservoir_id <- unname(right_ids[[age]])
  raw <- read_formula_table(file.path(input_dir, raw_file), raw_id)
  reservoir <- read_formula_table(file.path(input_dir, reservoir_file), reservoir_id)

  shared_formulas <- intersect(raw$Formula, reservoir$Formula)
  removed_formulas <- setdiff(raw$Formula, reservoir$Formula)
  produced_formulas <- setdiff(reservoir$Formula, raw$Formula)

  shared_raw <- raw %>%
    filter(Formula %in% shared_formulas) %>%
    arrange(Formula)
  shared_reservoir <- reservoir %>%
    filter(Formula %in% shared_formulas) %>%
    arrange(Formula)
  if (!identical(shared_raw$Formula, shared_reservoir$Formula)) {
    stop(age, ": shared formula alignment failed", call. = FALSE)
  }

  max_oc_difference <- if (nrow(shared_raw) > 0) {
    max(abs(shared_raw$O_C - shared_reservoir$O_C), na.rm = TRUE)
  } else {
    NA_real_
  }
  max_hc_difference <- if (nrow(shared_raw) > 0) {
    max(abs(shared_raw$H_C - shared_reservoir$H_C), na.rm = TRUE)
  } else {
    NA_real_
  }

  classified <- bind_rows(
    raw %>% filter(Formula %in% removed_formulas) %>% mutate(Stage = "Removed"),
    reservoir %>% filter(Formula %in% produced_formulas) %>% mutate(Stage = "Produced"),
    shared_raw %>% mutate(Stage = "Shared")
  ) %>%
    mutate(
      Age = age,
      Pair = paste0(age, " vs. ", reservoir_id),
      Stage = factor(Stage, levels = stage_levels)
    ) %>%
    select(Age, Pair, Stage, Sample, Formula, O_C, H_C)

  pair_qa <- tibble(
    Age = age,
    raw_sample = raw_id,
    reservoir_sample = reservoir_id,
    raw_formula_count = nrow(raw),
    reservoir_formula_count = nrow(reservoir),
    removed_formula_count = length(removed_formulas),
    produced_formula_count = length(produced_formulas),
    shared_formula_count = length(shared_formulas),
    raw_balance = length(removed_formulas) + length(shared_formulas),
    reservoir_balance = length(produced_formulas) + length(shared_formulas),
    max_shared_O_C_difference = max_oc_difference,
    max_shared_H_C_difference = max_hc_difference,
    status = ifelse(
      length(removed_formulas) + length(shared_formulas) == nrow(raw) &&
        length(produced_formulas) + length(shared_formulas) == nrow(reservoir),
      "PASS", "FAIL"
    )
  )
  list(data = classified, qa = pair_qa)
}

classified_list <- lapply(seq_len(nrow(sample_pairs)), function(i) {
  classify_pair(
    sample_pairs$Age[[i]],
    sample_pairs$Raw[[i]],
    sample_pairs$Reservoir[[i]]
  )
})

all_data <- bind_rows(lapply(classified_list, `[[`, "data")) %>%
  mutate(
    Age = factor(Age, levels = age_levels),
    Stage = factor(Stage, levels = stage_levels)
  )
pair_qa <- bind_rows(lapply(classified_list, `[[`, "qa"))

plot_data <- all_data %>%
  filter(
    is.finite(O_C), is.finite(H_C),
    O_C >= 0, O_C <= 1.2,
    H_C >= 0, H_C <= 2.5
  )

stage_counts <- all_data %>%
  count(Age, Stage, name = "raw_n") %>%
  complete(Age, Stage = factor(stage_levels, levels = stage_levels), fill = list(raw_n = 0)) %>%
  left_join(
    plot_data %>%
      count(Age, Stage, name = "plotted_n") %>%
      complete(Age, Stage = factor(stage_levels, levels = stage_levels), fill = list(plotted_n = 0)),
    by = c("Age", "Stage")
  ) %>%
  mutate(points_outside_axis_range = raw_n - plotted_n) %>%
  arrange(Age, Stage)

readr::write_csv(
  all_data %>% mutate(Stage = as.character(Stage), Age = as.character(Age)),
  file.path(output_dir, paste0(prefix, "_formula_classification.csv"))
)
readr::write_csv(stage_counts, file.path(output_dir, paste0(prefix, "_stage_counts.csv")))
readr::write_csv(pair_qa, file.path(output_dir, paste0(prefix, "_QA.csv")))

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

theme_vk <- theme_classic(base_family = "Arial", base_size = 6.5) +
  theme(
    axis.line = element_blank(),
    axis.ticks = element_line(linewidth = 0.40, colour = "black"),
    axis.ticks.length = unit(0.10, "cm"),
    axis.text = element_text(size = 6.2, colour = "black"),
    axis.title = element_text(size = 7.0, colour = "black", face = "bold"),
    plot.margin = margin(0.5, 0.5, 0.5, 0.5),
    panel.grid = element_blank(),
    legend.position = "none"
  )

make_panel <- function(age) {
  dat <- plot_data %>% filter(as.character(Age) == age)
  counts <- stage_counts %>%
    filter(as.character(Age) == age) %>%
    arrange(Stage)
  legend_labels <- paste0(as.character(counts$Stage), " (n=", counts$raw_n, ")")

  main <- ggplot(dat, aes(O_C, H_C)) +
    geom_segment(
      data = vk_segments,
      aes(x = x, xend = xend, y = y, yend = yend),
      inherit.aes = FALSE,
      colour = "grey45",
      linewidth = 0.40,
      linetype = "22"
    ) +
    geom_point(aes(colour = Stage), size = 0.58, alpha = 0.62, stroke = 0) +
    scale_colour_manual(values = stage_colors, drop = FALSE) +
    scale_x_continuous(
      limits = c(-0.02, 1.22),
      breaks = c(0.0, 0.3, 0.6, 0.9, 1.2),
      expand = c(0, 0)
    ) +
    scale_y_continuous(
      limits = c(-0.05, 2.55),
      breaks = c(0.0, 0.5, 1.0, 1.5, 2.0, 2.5),
      expand = c(0, 0)
    ) +
    labs(x = "O/C", y = "H/C") +
    annotate(
      "text", x = 0.02, y = 2.48,
      label = unname(pair_labels[[age]]),
      hjust = 0, vjust = 1, family = "Arial",
      fontface = "bold", size = 2.7
    ) +
    annotate(
      "point", x = 0.74, y = 0.43,
      colour = stage_colors[["Removed"]], shape = 16,
      size = 1.25, alpha = 0.95
    ) +
    annotate(
      "text", x = 0.77, y = 0.43,
      label = legend_labels[[1]], hjust = 0, vjust = 0.5,
      family = "Arial", size = 1.50
    ) +
    annotate(
      "point", x = 0.74, y = 0.28,
      colour = stage_colors[["Produced"]], shape = 16,
      size = 1.25, alpha = 0.95
    ) +
    annotate(
      "text", x = 0.77, y = 0.28,
      label = legend_labels[[2]], hjust = 0, vjust = 0.5,
      family = "Arial", size = 1.50
    ) +
    annotate(
      "point", x = 0.74, y = 0.13,
      colour = stage_colors[["Shared"]], shape = 16,
      size = 1.25, alpha = 0.95
    ) +
    annotate(
      "text", x = 0.77, y = 0.13,
      label = legend_labels[[3]], hjust = 0, vjust = 0.5,
      family = "Arial", size = 1.50
    ) +
    annotate(
      "segment",
      x = -0.019, xend = -0.019,
      y = -0.05, yend = 2.55,
      colour = "black", linewidth = 0.40,
      lineend = "square"
    ) +
    annotate(
      "segment",
      x = -0.019, xend = 1.22,
      y = -0.049, yend = -0.049,
      colour = "black", linewidth = 0.40,
      lineend = "square"
    ) +
    theme_vk

  top_density <- ggplot(dat, aes(O_C, colour = Stage, fill = Stage)) +
    geom_density(linewidth = 0.28, alpha = 0.20, adjust = 0.9, na.rm = TRUE) +
    scale_colour_manual(values = stage_colors, drop = FALSE) +
    scale_fill_manual(values = stage_colors, drop = FALSE) +
    scale_x_continuous(limits = c(-0.02, 1.22), expand = c(0, 0)) +
    theme_void(base_family = "Arial") +
    theme(
      legend.position = "none",
      plot.margin = margin(0, 0.5, 0, 0.5)
    )

  right_density <- ggplot(dat, aes(H_C, colour = Stage, fill = Stage)) +
    geom_density(linewidth = 0.28, alpha = 0.20, adjust = 0.9, na.rm = TRUE) +
    scale_colour_manual(values = stage_colors, drop = FALSE) +
    scale_fill_manual(values = stage_colors, drop = FALSE) +
    scale_x_continuous(limits = c(-0.05, 2.55), expand = c(0, 0)) +
    coord_flip() +
    theme_void(base_family = "Arial") +
    theme(
      legend.position = "none",
      plot.margin = margin(0.5, 0, 0.5, 0)
    )

  top_row <- wrap_plots(top_density, plot_spacer(), ncol = 2, widths = c(4.2, 0.82))
  bottom_row <- wrap_plots(main, right_density, ncol = 2, widths = c(4.2, 0.82))
  wrap_plots(top_row, bottom_row, ncol = 1, heights = c(0.72, 4.0))
}

panels <- lapply(age_levels, make_panel)
panel_label <- ggplot() +
  annotate(
    "text", x = 1, y = 0.985, label = "a",
    hjust = 1, vjust = 1, family = "Arial",
    fontface = "bold", size = 3.2
  ) +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), clip = "off") +
  theme_void()
combined <- wrap_plots(
  panel_label, panels[[1]], panels[[2]], panels[[3]],
  nrow = 1, widths = c(0.035, 1, 1, 1)
)

combined_pdf <- file.path(output_dir, paste0(prefix, "_combined.pdf"))
combined_svg <- file.path(output_dir, paste0(prefix, "_combined.svg"))
combined_png <- file.path(output_dir, paste0(prefix, "_combined.png"))
combined_tiff <- file.path(output_dir, paste0(prefix, "_combined.tiff"))

grDevices::cairo_pdf(combined_pdf, width = 183 / 25.4, height = 76 / 25.4, family = "Arial")
print(combined)
dev.off()

svglite::svglite(combined_svg, width = 183 / 25.4, height = 76 / 25.4)
print(combined)
dev.off()

ragg::agg_png(
  combined_png, width = 183 / 25.4, height = 76 / 25.4,
  units = "in", res = 600, background = "white"
)
print(combined)
dev.off()

ragg::agg_tiff(
  combined_tiff, width = 183 / 25.4, height = 76 / 25.4,
  units = "in", res = 600, compression = "lzw", background = "white"
)
print(combined)
dev.off()

for (i in seq_along(panels)) {
  age <- age_levels[[i]]
  base <- file.path(output_dir, paste0(prefix, "_", age))
  grDevices::cairo_pdf(paste0(base, ".pdf"), width = 65 / 25.4, height = 76 / 25.4, family = "Arial")
  print(panels[[i]])
  dev.off()
  svglite::svglite(paste0(base, ".svg"), width = 65 / 25.4, height = 76 / 25.4)
  print(panels[[i]])
  dev.off()
}

caption <- paste(
  "Fig. 1a. Van Krevelen and marginal distribution diagrams of DOM molecular",
  "formulas in YL, ML and OL before and after front-end pretreatment.",
  "Blue points indicate formulas detected only in raw leachate (removed), red",
  "points indicate formulas detected only in regulating-reservoir effluent",
  "(produced), and green points indicate formulas shared by both samples.",
  "Marginal density distributions are based on molecular-formula counts and are",
  "not weighted by relative intensity."
)
writeLines(caption, file.path(output_dir, paste0(prefix, "_caption.txt")), useBytes = TRUE)

cat("Created:\n")
cat(combined_pdf, "\n")
cat(combined_svg, "\n")
cat(combined_png, "\n")
cat(combined_tiff, "\n")
print(stage_counts, n = Inf)
print(pair_qa, n = Inf)

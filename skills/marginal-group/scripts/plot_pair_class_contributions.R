options(stringsAsFactors = FALSE)

args <- getOption(
  "pretreatment_script_args",
  commandArgs(trailingOnly = TRUE)
)
input_dir <- if (length(args) >= 1) args[[1]] else "."
output_dir <- if (length(args) >= 2) args[[2]] else file.path(input_dir, "output")
prefix <- if (length(args) >= 3) args[[3]] else "Pretreatment_Class_Contributions"

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

suppressPackageStartupMessages({
  library(openxlsx)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(patchwork)
  library(readr)
})

input_dir <- normalizePath(input_dir, winslash = "/", mustWork = TRUE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)

age_levels <- getOption("dom_pair_age_levels", c("YL", "ML", "OL"))
stage_levels <- c("Removed", "Produced", "Shared")

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
  required <- c("Formula", "VK", "Group")
  missing <- setdiff(required, names(dat))
  if (length(missing) > 0) {
    stop(sample_id, " missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  out <- dat %>%
    transmute(
      Sample = sample_id,
      Formula = trimws(as.character(Formula)),
      VK = trimws(as.character(VK)),
      Group = trimws(as.character(Group))
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
  left_id <- unname(left_ids[[age]])
  right_id <- unname(right_ids[[age]])
  raw <- read_formula_table(file.path(input_dir, raw_file), left_id)
  reservoir <- read_formula_table(
    file.path(input_dir, reservoir_file),
    right_id
  )
  shared <- intersect(raw$Formula, reservoir$Formula)
  removed <- setdiff(raw$Formula, reservoir$Formula)
  produced <- setdiff(reservoir$Formula, raw$Formula)

  bind_rows(
    raw %>% filter(Formula %in% removed) %>% mutate(Stage = "Removed"),
    reservoir %>% filter(Formula %in% produced) %>% mutate(Stage = "Produced"),
    raw %>% filter(Formula %in% shared) %>% mutate(Stage = "Shared")
  ) %>%
    mutate(Age = age) %>%
    select(Age, Stage, Sample, Formula, VK, Group)
}

classified <- bind_rows(lapply(seq_len(nrow(sample_pairs)), function(i) {
  classify_pair(
    sample_pairs$Age[[i]],
    sample_pairs$Raw[[i]],
    sample_pairs$Reservoir[[i]]
  )
})) %>%
  mutate(
    Age = factor(Age, levels = age_levels),
    Stage = factor(Stage, levels = stage_levels)
  )

category_data <- bind_rows(
  classified %>%
    transmute(
      Age, Stage, Formula,
      Dimension = "VK",
      Category = case_when(
        VK == "Lipids" ~ "Lipids",
        VK == "Aliphatic" ~ "Aliphatic/proteins",
        VK == "Lignin" ~ "Lignin/CRAM-like structures",
        VK == "Carbohydrates" ~ "Carbohydrates",
        VK == "Unsaturated" ~ "Unsaturated hydrocarbons",
        VK == "Aromatic" ~ "Aromatic structures",
        VK == "Tannin" ~ "Tannin",
        TRUE ~ "Others"
      )
    ),
  classified %>%
    transmute(
      Age, Stage, Formula,
      Dimension = "Group",
      Category = if_else(Group %in% group_levels[1:4], Group, "Others")
    )
)

summarize_dimension <- function(dat, dimension, category_levels) {
  dat %>%
    filter(Dimension == dimension) %>%
    count(Age, Stage, Category, name = "Formula_count") %>%
    complete(
      Age = factor(age_levels, levels = age_levels),
      Stage = factor(stage_levels, levels = stage_levels),
      Category = category_levels,
      fill = list(Formula_count = 0)
    ) %>%
    group_by(Age, Stage) %>%
    mutate(
      Total_formulas = sum(Formula_count),
      Relative_contribution = Formula_count / Total_formulas * 100
    ) %>%
    ungroup() %>%
    mutate(
      Dimension = dimension,
      Age = factor(Age, levels = age_levels),
      Stage = factor(Stage, levels = stage_levels),
      Category = factor(Category, levels = category_levels)
    )
}

vk_data <- summarize_dimension(category_data, "VK", vk_levels)
group_data <- summarize_dimension(category_data, "Group", group_levels)
x_position_key <- tidyr::crossing(
  Age = factor(age_levels, levels = age_levels),
  Stage = factor(stage_levels, levels = stage_levels)
) %>%
  arrange(Age, Stage) %>%
  mutate(x_pos = row_number())

source_data <- bind_rows(vk_data, group_data) %>%
  left_join(x_position_key, by = c("Age", "Stage")) %>%
  mutate(
    x_label = as.character(Stage),
    comparison = paste0(as.character(Age), "-", as.character(Stage))
  )

qa <- source_data %>%
  group_by(Age, Stage, Dimension) %>%
  summarise(
    Formula_count = sum(Formula_count),
    Relative_contribution_sum = sum(Relative_contribution),
    status = ifelse(abs(Relative_contribution_sum - 100) < 1e-8, "PASS", "FAIL"),
    .groups = "drop"
  )

readr::write_csv(
  source_data %>%
    mutate(
      Age = as.character(Age),
      Stage = as.character(Stage),
      Category = as.character(Category)
    ),
  file.path(output_dir, paste0(prefix, "_source_data.csv"))
)
readr::write_csv(qa, file.path(output_dir, paste0(prefix, "_QA.csv")))

theme_dom_bar <- function(show_y_title = TRUE) {
  theme_classic(base_size = 9, base_family = "Arial") +
    theme(
      panel.border = element_blank(),
      axis.line = element_blank(),
      axis.ticks = element_line(colour = "black", linewidth = 0.40),
      axis.ticks.length = unit(1.0, "mm"),
      axis.text = element_text(colour = "black", size = 8.2),
      axis.text.x = element_text(
        size = 6.4, angle = 45,
        hjust = 1, vjust = 1
      ),
      axis.title.y = if (show_y_title) {
        element_text(colour = "black", size = 9.2, face = "bold")
      } else {
        element_blank()
      },
      axis.title.x = element_blank(),
      legend.position = "top",
      legend.justification = "center",
      legend.title = element_blank(),
      legend.text = element_text(size = 7.5, colour = "black"),
      legend.key.size = unit(3.5, "mm"),
      legend.key.width = unit(3.5, "mm"),
      legend.key.height = unit(3.5, "mm"),
      legend.spacing.x = unit(0.7, "mm"),
      legend.spacing.y = unit(0.2, "mm"),
      legend.box.margin = margin(0, 0, 2.0, 0),
      plot.tag = element_text(
        family = "Arial", face = "bold",
        size = 16, colour = "black"
      ),
      plot.tag.position = c(0.005, 0.995),
      plot.margin = margin(2, 4, 3, 4)
    )
}

make_bar <- function(dat, fill_values, legend_nrow, panel_tag, show_y_title) {
  ggplot(
    dat,
    aes(x = x_pos, y = Relative_contribution, fill = Category)
  ) +
    geom_col(
      width = 0.68, colour = "white", linewidth = 0.18,
      key_glyph = draw_key_point
    ) +
    geom_vline(
      xintercept = c(3.5, 6.5),
      linetype = "dashed", colour = "grey45", linewidth = 0.4
    ) +
    annotate(
      "text", x = c(2, 5, 8), y = 105,
      label = unname(pair_labels[age_levels]),
      family = "Arial", fontface = "bold", size = 3.0
    ) +
    annotate(
      "segment",
      x = 0.5, xend = 9.5, y = 0, yend = 0,
      colour = "black", linewidth = 0.40, lineend = "square"
    ) +
    annotate(
      "segment",
      x = 0.5, xend = 0.5, y = 0, yend = 110,
      colour = "black", linewidth = 0.40, lineend = "square"
    ) +
    annotate(
      "segment",
      x = 9.5, xend = 9.5, y = 0, yend = 110,
      colour = "black", linewidth = 0.40, lineend = "square"
    ) +
    annotate(
      "segment",
      x = 0.5, xend = 9.5, y = 110, yend = 110,
      colour = "black", linewidth = 0.40, lineend = "square"
    ) +
    scale_fill_manual(
      values = fill_values,
      breaks = names(fill_values),
      drop = FALSE
    ) +
    guides(
      fill = guide_legend(
        nrow = legend_nrow,
        byrow = TRUE,
        keywidth = unit(3.5, "mm"),
        keyheight = unit(3.5, "mm"),
        override.aes = list(
          shape = 22, size = 3.5,
          colour = NA, stroke = 0, alpha = 1
        )
      )
    ) +
    scale_x_continuous(
      breaks = 1:9,
      labels = rep(stage_levels, times = 3),
      limits = c(0.5, 9.5),
      expand = c(0, 0)
    ) +
    scale_y_continuous(
      breaks = c(0, 25, 50, 75, 100),
      limits = c(0, 110),
      expand = c(0, 0)
    ) +
    labs(
      x = NULL,
      y = if (show_y_title) "Proportion of molecular formulas (%)" else NULL,
      tag = panel_tag
    ) +
    theme_dom_bar(show_y_title = show_y_title)
}

p_vk <- make_bar(
  vk_data %>% left_join(x_position_key, by = c("Age", "Stage")),
  vk_colors, legend_nrow = 3, panel_tag = "b", show_y_title = TRUE
)
p_group <- make_bar(
  group_data %>% left_join(x_position_key, by = c("Age", "Stage")),
  group_colors, legend_nrow = 1, panel_tag = "c", show_y_title = FALSE
)

combined <- p_vk + p_group +
  plot_layout(nrow = 1, widths = c(1, 1), guides = "keep")

base_out <- file.path(output_dir, "figure_bc_relayout")
width_in <- 12
height_in <- 4.8

ggsave(
  paste0(base_out, ".png"), combined,
  width = width_in, height = height_in, units = "in",
  dpi = 600, device = ragg::agg_png, bg = "white"
)

ggsave(
  paste0(base_out, ".pdf"), combined,
  width = width_in, height = height_in, units = "in",
  device = grDevices::cairo_pdf
)

ggsave(
  paste0(base_out, ".svg"), combined,
  width = width_in, height = height_in, units = "in",
  device = svglite::svglite
)

ggsave(
  paste0(base_out, ".tiff"), combined,
  width = width_in, height = height_in, units = "in",
  dpi = 600, device = ragg::agg_tiff,
  compression = "lzw", bg = "white"
)

readr::write_csv(
  source_data %>%
    mutate(
      Age = as.character(Age),
      Stage = as.character(Stage),
      Category = as.character(Category)
    ),
  file.path(output_dir, "figure_bc_relayout_source_data.csv")
)
readr::write_csv(qa, file.path(output_dir, "figure_bc_relayout_QA.csv"))

caption <- paste(
  "b,c, Relative contributions of molecular formulas (%) assigned to compound",
  "classes (b) and formula classes (c) within the removed, produced and shared",
  "molecular pools. Percentages are based on molecular-formula counts and are",
  "not weighted by relative intensity."
)
writeLines(caption, file.path(output_dir, paste0(prefix, "_caption.txt")), useBytes = TRUE)

cat("Created figure base: ", base_out, "\n", sep = "")
print(qa, n = Inf)

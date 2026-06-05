suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(readr)
  library(tidyr)
  library(stringr)
  library(purrr)
  library(tibble)
  library(svglite)
  library(ragg)
  library(patchwork)
  library(scales)
})

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
}

parse_args <- function(args) {
  out <- list()
  i <- 1
  while (i <= length(args)) {
    key <- args[[i]]
    if (str_starts(key, "--")) {
      name <- str_remove(key, "^--")
      value <- TRUE
      if (i < length(args) && !str_starts(args[[i + 1]], "--")) {
        value <- args[[i + 1]]
        i <- i + 1
      }
      out[[name]] <- value
    }
    i <- i + 1
  }
  out
}

cli <- parse_args(commandArgs(trailingOnly = TRUE))

input_path <- cli$input_edges %||% cli$input %||% cli$input_path %||% NA_character_
if (is.na(input_path)) {
  candidates <- c(
    file.path(getwd(), "all_network_edge.csv"),
    file.path(getwd(), "reaction_results", "all_network_edge.csv")
  )
  hit <- candidates[file.exists(candidates)]
  if (length(hit) > 0) input_path <- hit[[1]]
}

if (is.na(input_path) || !file.exists(input_path)) {
  stop(
    "Input edge table was not found. Provide --input_edges path/to/all_network_edge.csv.",
    call. = FALSE
  )
}

output_dir <- cli$output_dir %||% file.path(dirname(input_path), "reaction_polar_figures")
prefix <- cli$prefix %||% "reaction_polar_ring"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

reaction_map <- tribble(
  ~Order, ~Category, ~Description, ~Reaction, ~Formula_difference,
   1, "Dealkylation", "Demethylation", "1-CH2", "\u2013CH2",
   2, "Dealkylation", "Dealkylation", "1-C2H2", "\u2013C2H2",
   3, "Dealkylation", "Di-demethylation or deethylation", "1-C2H4", "\u2013C2H4",
   4, "Dealkylation", "Dealkylation", "1-C2H6", "\u2013C2H6",
   5, "Dealkylation", "De-cyclopropyl", "1-C3H4", "\u2013C3H4",
   6, "Dealkylation", "De-isopropyl", "1-C3H6", "\u2013C3H6",
   7, "Oxygen addition", "Hydroxylation/N or S-oxidation", "1+O", "+O",
   8, "Oxygen addition", "Carbonylation/methyl to aldehyde/alcohol to carboxylic acid", "1+O-2H", "+O-2H",
   9, "Oxygen addition", "Hydration", "1+H2O", "+H2O",
  10, "Oxygen addition", "Methyl to carboxylic acid", "1+2O-2H", "+2O-2H",
  11, "Oxygen addition", "Oxygen addition", "1+2O", "+2O",
  12, "Oxygen addition", "Di-hydroxylation", "1+H2O2", "+H2O2",
  13, "Oxygen addition", "Oxygen addition", "1+3O", "+3O",
  14, "Decarboxylation", "Reductive displacement of carboxylic acid", "1-CO", "\u2013CO",
  15, "Decarboxylation", "Decarboxylation", "1-CO2", "\u2013CO2",
  16, "Decarboxylation", "Loss of methanol", "1-CH2O", "\u2013CH2O",
  17, "Decarboxylation", "Loss of acetic acid", "1-C2H2O2", "\u2013C2H2O2",
  18, "Decarboxylation", "Loss of acrylic acid", "1-C3H2O2", "\u2013C3H2O2",
  19, "Decarboxylation", "Loss of maleic acid", "1-C4H2O4", "\u2013C4H2O4",
  20, "Deamination", "Loss of N atom", "1-N+3H", "\u2013N+3H",
  21, "Deamination", "Oxidative displacement of amine", "1-NH2+OH", "\u2013NH2+OH",
  22, "Deamination", "Amino group substituted by methyl group", "1-NH2+CH3", "\u2013NH2+CH3",
  23, "Deamination", "Nitration of the amine group", "1-NH2+NO2", "\u2013NH2+NO2",
  24, "Deamination", "Oxidative deamination", "1-NH3+2O", "\u2013NH3+2O",
  25, "Deamination", "Cleavage of triazine", "1-2N-CO", "\u20132N\u2013CO",
  26, "Desulfonation", "Oxidative desulfonation", "1-SH2", "\u2013SH2",
  27, "Desulfonation", "Desulfonation", "1-SO", "\u2013SO",
  28, "Desulfonation", "Desulfonation", "1-SO3", "\u2013SO3",
  29, "Desulfonation", "Desulfonation", "1-SO2", "\u2013SO2",
  30, "Desulfonation", "Oxidative desulfonation", "1-S", "\u2013S",
  31, "Desulfonation", "Desulfonation", "1-S2", "\u2013S2",
  32, "Desulfonation", "Oxidative desulfonation", "1-SH", "\u2013SH",
  33, "Other reactions", "Dehydrogenation", "1-2H", "\u20132H",
  34, "Other reactions", "Dehydration", "1-H2O", "\u2013H2O",
  35, "Other reactions", "Loss of oxygen", "1-O2", "\u2013O2",
  36, "Other reactions", "Deacetylation", "1-C2H2O", "\u2013C2H2O"
) |>
  mutate(
    Category = factor(
      Category,
      levels = c(
        "Dealkylation", "Oxygen addition", "Decarboxylation",
        "Deamination", "Desulfonation", "Other reactions"
      )
    )
  )

category_colors <- c(
  "Dealkylation" = "#8E63C7",
  "Oxygen addition" = "#4C78A8",
  "Decarboxylation" = "#59A14F",
  "Deamination" = "#9C755F",
  "Desulfonation" = "#B279A2",
  "Other reactions" = "#F28E2B"
)

dose_colors <- c(
  "0.5" = "#E69F00",
  "0.8" = "#4E79A7",
  "1.0" = "#E15759"
)

dose_shapes <- c("0.5" = 21, "0.8" = 21, "1.0" = 21)

theme_set(
  theme_void(base_size = 7, base_family = "Arial") +
    theme(
      legend.title = element_blank(),
      legend.text = element_text(size = 8.2, colour = "black"),
      plot.title = element_text(size = 11, face = "bold", colour = "black", hjust = 0.02, margin = margin(b = 2)),
      plot.margin = margin(18, 18, 18, 18, "pt")
    )
)

raw_edges <- read_csv(input_path, show_col_types = FALSE)
required_edge_cols <- c("Leachate", "Dose", "Reaction")
missing_cols <- setdiff(required_edge_cols, names(raw_edges))
if (length(missing_cols) > 0) {
  stop(
    "Input edge table is missing required columns: ",
    paste(missing_cols, collapse = ", "),
    call. = FALSE
  )
}

count_data <- raw_edges |>
  mutate(
    Dose = case_when(
      as.character(Dose) %in% c("1", "1.0") ~ "1.0",
      TRUE ~ as.character(Dose)
    )
  ) |>
  count(Leachate, Dose, Reaction, name = "Count") |>
  right_join(
    expand_grid(
      Leachate = sort(unique(raw_edges$Leachate)),
      Dose = c("0.5", "0.8", "1.0"),
      Reaction = reaction_map$Reaction
    ),
    by = c("Leachate", "Dose", "Reaction")
  ) |>
  mutate(Count = replace_na(Count, 0L)) |>
  left_join(reaction_map, by = "Reaction") |>
  arrange(Leachate, Dose, Order)

unknown <- setdiff(unique(raw_edges$Reaction), reaction_map$Reaction)
if (length(unknown) > 0) {
  warning("Unmapped reactions were found and excluded: ", paste(unknown, collapse = ", "), call. = FALSE)
}

label_data <- reaction_map |>
  mutate(
    angle_raw = 90 - 360 * (Order - 0.5) / n(),
    angle = if_else(angle_raw < -90, angle_raw + 180, angle_raw),
    hjust = if_else(angle_raw < -90, 1, 0)
  )

category_band <- reaction_map |>
  group_by(Category) |>
  summarise(
    xmin = min(Order) - 0.46,
    xmax = max(Order) + 0.46,
    mid = mean(c(min(Order), max(Order))),
    .groups = "drop"
  ) |>
  mutate(
    angle_raw = 90 - 360 * (mid - 0.5) / nrow(reaction_map),
    tangent_raw = angle_raw - 90,
    tangent_angle = case_when(
      tangent_raw < -90 ~ tangent_raw + 180,
      tangent_raw > 90 ~ tangent_raw - 180,
      TRUE ~ tangent_raw
    ),
    hjust = 0.5
  )

save_pub_r <- function(plot, filename, width_mm = 112, height_mm = 112, dpi = 600) {
  w <- width_mm / 25.4
  h <- height_mm / 25.4
  unlink(paste0(filename, c(".svg", ".pdf", ".tiff", ".png")), force = TRUE)

  svglite(paste0(filename, ".svg"), width = w, height = h)
  print(plot)
  dev.off()

  cairo_pdf(paste0(filename, ".pdf"), width = w, height = h, family = "Arial")
  print(plot)
  dev.off()

  agg_tiff(paste0(filename, ".tiff"), width = w, height = h, units = "in", res = dpi, compression = "lzw")
  print(plot)
  dev.off()

  agg_png(paste0(filename, ".png"), width = w, height = h, units = "in", res = 240)
  print(plot)
  dev.off()
}

make_arc_text <- function(category_df, radius, n_positions = nrow(reaction_map)) {
  map_dfr(seq_len(nrow(category_df)), function(i) {
    row <- category_df[i, ]
    letters <- strsplit(as.character(row$Category_label), "")[[1]]
    letters <- letters[letters != " "]
    usable_span <- min((row$xmax - row$xmin) * 0.82, max(1.6, length(letters) * 0.24))
    x_values <- seq(row$mid - usable_span / 2, row$mid + usable_span / 2, length.out = length(letters))

    tibble(
      Category = row$Category,
      x = x_values,
      y = radius,
      label = letters
    ) |>
      mutate(
        angle_raw = 90 - 360 * (x - 0.5) / n_positions,
        tangent_raw = angle_raw - 90,
        angle = case_when(
          tangent_raw < -90 ~ tangent_raw + 180,
          tangent_raw > 90 ~ tangent_raw - 180,
          TRUE ~ tangent_raw
        )
      )
  })
}

make_polar_plot <- function(leachate, panel_label) {
  dat <- count_data |>
    filter(Leachate == leachate) |>
    mutate(
      Dose = factor(Dose, levels = c("0.5", "0.8", "1.0")),
      Count = as.numeric(Count),
      DoseOffset = case_when(
        Dose == "0.5" ~ -0.18,
        Dose == "0.8" ~ 0,
        Dose == "1.0" ~ 0.18,
        TRUE ~ 0
      ),
      OrderPlot = Order + DoseOffset,
      PlotValue = sqrt(Count)
    )

  max_count <- max(dat$Count, na.rm = TRUE)
  grid_step <- if (max_count <= 200) 50 else 100
  grid_max <- ceiling(max_count / grid_step) * grid_step
  if (grid_max == 0) grid_max <- grid_step
  plot_max <- sqrt(grid_max)

  reaction_label_r <- plot_max * 1.12
  ring_inner <- plot_max * 1.82
  ring_outer <- plot_max * 1.96
  category_label_r <- plot_max * 2.18
  panel_label_r <- plot_max * 2.10
  category_label_data <- category_band |>
    mutate(
      Category_label = recode(
        as.character(Category),
        "Oxygen addition" = "Oxygenation",
        "Other reactions" = "Other"
      )
    )

  grid_data <- tibble(
    raw_y = seq(grid_step, grid_max, by = grid_step),
    y = sqrt(raw_y)
  )
  spoke_data <- tibble(Order = reaction_map$Order)

  p <- ggplot() +
    geom_hline(
      data = grid_data,
      aes(yintercept = y),
      colour = "#C7C7C7",
      linewidth = 0.28,
      linetype = "dashed"
    ) +
    geom_vline(
      data = spoke_data,
      aes(xintercept = Order),
      colour = "#E3E3E3",
      linewidth = 0.22
    ) +
    geom_rect(
      data = category_band,
      aes(xmin = xmin, xmax = xmax, ymin = ring_inner, ymax = ring_outer, fill = Category),
      colour = "white",
      linewidth = 1.35
    ) +
    geom_path(
      data = dat,
      aes(x = OrderPlot, y = PlotValue, colour = Dose, group = Dose),
      linewidth = 0.46,
      alpha = 0.78
    ) +
    geom_point(
      data = dat,
      aes(x = OrderPlot, y = PlotValue, colour = Dose, fill = Dose),
      shape = 21,
      size = 1.42,
      stroke = 0.28,
      alpha = 0.96
    ) +
    geom_text(
      data = label_data,
      aes(x = Order, y = reaction_label_r, label = Formula_difference, angle = angle, hjust = hjust, colour = Category),
      size = 2.18,
      fontface = "bold",
      vjust = 0.5
    ) +
    geom_text(
      data = category_label_data,
      aes(x = mid, y = category_label_r, label = Category_label, angle = tangent_angle, hjust = hjust, colour = Category),
      size = 3.1,
      fontface = "bold",
      vjust = 0.5
    ) +
    geom_text(
      data = grid_data,
      aes(x = 0.6, y = y, label = raw_y),
      size = 2.05,
      colour = "#4D4D4D",
      hjust = 0.5,
      fontface = "bold"
    ) +
    labs(title = paste(panel_label, leachate)) +
    scale_x_continuous(limits = c(0.5, nrow(reaction_map) + 0.5), expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, category_label_r * 1.12), expand = c(0, 0)) +
    scale_fill_manual(values = c(category_colors, dose_colors), breaks = names(dose_colors)) +
    scale_colour_manual(values = c(category_colors, dose_colors), breaks = names(dose_colors)) +
    scale_shape_manual(values = dose_shapes) +
    guides(
      fill = "none",
      colour = guide_legend(
        override.aes = list(
          fill = unname(dose_colors),
          shape = 21,
          linewidth = 1.0,
          size = 3.4
        )
      ),
      shape = "none"
    ) +
    coord_polar(theta = "x", start = 0, clip = "off") +
    theme(
      legend.position = c(0.77, 0.06),
      legend.justification = c(0, 0),
      legend.key.width = unit(7, "mm"),
      legend.key.height = unit(4.2, "mm")
    )

  p
}

p_ml <- make_polar_plot("ML", "a")
p_ol <- make_polar_plot("OL", "b")
p_combined <- p_ml + p_ol + plot_layout(ncol = 2, guides = "collect") &
  theme(legend.position = "bottom")

save_pub_r(p_ml, file.path(output_dir, paste0(prefix, "_ML")), width_mm = 145, height_mm = 145)
save_pub_r(p_ol, file.path(output_dir, paste0(prefix, "_OL")), width_mm = 145, height_mm = 145)
save_pub_r(p_combined, file.path(output_dir, paste0(prefix, "_ML_OL_combined")), width_mm = 280, height_mm = 145)

source_data <- count_data |>
  select(Leachate, Dose, Order, Category, Reaction, Formula_difference, Description, Count) |>
  arrange(Leachate, Dose, Order)

write_csv(source_data, file.path(output_dir, "source_data_reaction_polar_ring.csv"))
write_csv(reaction_map, file.path(output_dir, "reaction_category_mapping.csv"))

message("Exported reaction polar ring figures to: ", output_dir)

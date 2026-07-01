#!/usr/bin/env Rscript

.libPaths(c(
  "C:/Users/Public/Rlibs/4.5",
  "D:/R/library",
  .libPaths()
))

required_packages <- c(
  "ggplot2", "patchwork", "svglite", "ragg", "scales"
)
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0L) {
  stop(
    "Missing R package(s): ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})

parse_args <- function(values) {
  args <- list(
    input_dir = NULL,
    figure_dir = NULL,
    table_dir = NULL,
    prefix = "U_S_V_figure",
    sample_order = "YL,ML,OL",
    upset_order = "YL,OL,ML",
    figure_number = "Fig. S6.",
    sample_description = "young (YL), medium (ML), and old (OL) leachates",
    width_mm = "183",
    height_mm = "165",
    dpi = "600"
  )
  index <- 1L
  while (index <= length(values)) {
    key <- values[[index]]
    if (!startsWith(key, "--")) stop("Unexpected argument: ", key, call. = FALSE)
    name <- sub("^--", "", key)
    if (!name %in% names(args)) stop("Unknown argument: ", key, call. = FALSE)
    if (index == length(values)) stop("Missing value for ", key, call. = FALSE)
    args[[name]] <- values[[index + 1L]]
    index <- index + 2L
  }
  if (is.null(args$input_dir) || is.null(args$figure_dir) || is.null(args$table_dir)) {
    stop("--input_dir, --figure_dir, and --table_dir are required.", call. = FALSE)
  }
  args$sample_order <- trimws(strsplit(args$sample_order, ",", fixed = TRUE)[[1]])
  args$upset_order <- trimws(strsplit(args$upset_order, ",", fixed = TRUE)[[1]])
  if (length(args$sample_order) != 3L || length(args$upset_order) != 3L) {
    stop("sample_order and upset_order must each contain exactly three IDs.", call. = FALSE)
  }
  if (!setequal(args$sample_order, args$upset_order)) {
    stop("sample_order and upset_order must contain the same IDs.", call. = FALSE)
  }
  args$width_mm <- as.numeric(args$width_mm)
  args$height_mm <- as.numeric(args$height_mm)
  args$dpi <- as.integer(args$dpi)
  args
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
input_dir <- args$input_dir
figure_dir <- args$figure_dir
table_dir <- args$table_dir
caption_path <- file.path(table_dir, paste0(args$prefix, "_caption.txt"))
output_base <- file.path(figure_dir, args$prefix)

group_levels <- args$sample_order
upset_order <- args$upset_order
palette <- setNames(c("#26A69A", "#5E8EC8", "#E87878"), group_levels)
band_palette <- setNames(c("#BFE8E4", "#D6E3F2", "#F5D4D4"), group_levels)
vk_point_colour <- "#7A6AA8"

dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(caption_path), recursive = TRUE, showWarnings = FALSE)

read_sample <- function(sample_id) {
  path <- file.path(input_dir, paste0(sample_id, ".csv"))
  if (!file.exists(path)) stop("Missing input: ", path, call. = FALSE)
  dat <- read.csv(
    path,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  required <- c(
    "Formula", "Intensity", "Mass", "RI", "O/C", "H/C", "DBE",
    "NOSC", "AImod", "C", "H", "N", "O", "S", "P", "Cl", "Br",
    "N/C", "S/C"
  )
  missing <- setdiff(required, names(dat))
  if (length(missing) > 0L) {
    stop(
      sample_id,
      " lacks required column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  dat <- dat[!is.na(dat$Formula) & nzchar(dat$Formula), ]
  if (anyDuplicated(dat$Formula)) {
    stop(sample_id, " contains duplicated formulas.", call. = FALSE)
  }
  data.frame(
    sample_id = sample_id,
    Formula = dat$Formula,
    RI = as.numeric(dat$RI),
    Intensity = as.numeric(dat$Intensity),
    MW = as.numeric(dat$Mass),
    DBE = as.numeric(dat$DBE),
    O_C = as.numeric(dat[["O/C"]]),
    H_C = as.numeric(dat[["H/C"]]),
    N_C = as.numeric(dat[["N/C"]]),
    S_C = as.numeric(dat[["S/C"]]),
    AImod = as.numeric(dat$AImod),
    NOSC = as.numeric(dat$NOSC),
    C = as.numeric(dat$C),
    H = as.numeric(dat$H),
    O = as.numeric(dat$O),
    N = as.numeric(dat$N),
    S = as.numeric(dat$S),
    P = as.numeric(dat$P),
    Cl = as.numeric(dat$Cl),
    Br = as.numeric(dat$Br),
    stringsAsFactors = FALSE
  )
}

sample_data <- setNames(lapply(group_levels, read_sample), group_levels)
all_data <- do.call(rbind, sample_data)
rownames(all_data) <- NULL
all_data$sample_id <- factor(all_data$sample_id, levels = group_levels)

make_upset_data <- function(sample_data) {
  all_formulas <- sort(unique(unlist(lapply(sample_data, function(x) x$Formula))))
  presence <- data.frame(Formula = all_formulas, stringsAsFactors = FALSE)
  for (sample_id in upset_order) {
    presence[[sample_id]] <- all_formulas %in% sample_data[[sample_id]]$Formula
  }
  presence$intersection_key <- apply(
    presence[, upset_order, drop = FALSE],
    1,
    function(x) paste(upset_order[as.logical(x)], collapse = "&")
  )
  presence$intersection_degree <- rowSums(presence[, upset_order, drop = FALSE])

  intersection_table <- as.data.frame(
    table(presence$intersection_key),
    stringsAsFactors = FALSE
  )
  names(intersection_table) <- c("intersection_key", "intersection_size")
  intersection_table$intersection_size <- as.integer(intersection_table$intersection_size)
  intersection_table$intersection_degree <- vapply(
    strsplit(intersection_table$intersection_key, "&", fixed = TRUE),
    length,
    integer(1)
  )
  intersection_table <- intersection_table[
    order(
      -intersection_table$intersection_size,
      -intersection_table$intersection_degree,
      intersection_table$intersection_key
    ),
  ]
  rownames(intersection_table) <- NULL
  intersection_table$intersection_rank <- seq_len(nrow(intersection_table))

  matrix_data <- expand.grid(
    intersection_rank = intersection_table$intersection_rank,
    sample_id = upset_order,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  matrix_data$intersection_key <- intersection_table$intersection_key[
    matrix_data$intersection_rank
  ]
  matrix_data$present <- mapply(
    function(key, sample_id) {
      sample_id %in% strsplit(key, "&", fixed = TRUE)[[1]]
    },
    matrix_data$intersection_key,
    matrix_data$sample_id
  )
  matrix_data$y_num <- match(matrix_data$sample_id, rev(upset_order))

  line_rows <- lapply(intersection_table$intersection_rank, function(rank) {
    active <- matrix_data[
      matrix_data$intersection_rank == rank & matrix_data$present,
    ]
    if (nrow(active) < 2L) return(NULL)
    data.frame(
      intersection_rank = rank,
      y_min = min(active$y_num),
      y_max = max(active$y_num)
    )
  })
  line_data <- do.call(rbind, line_rows)
  if (is.null(line_data)) {
    line_data <- data.frame(
      intersection_rank = numeric(),
      y_min = numeric(),
      y_max = numeric()
    )
  }

  set_sizes <- data.frame(
    sample_id = upset_order,
    formula_count = vapply(
      upset_order,
      function(x) length(sample_data[[x]]$Formula),
      integer(1)
    ),
    stringsAsFactors = FALSE
  )
  set_sizes$y_num <- match(set_sizes$sample_id, rev(upset_order))

  list(
    presence = presence,
    intersections = intersection_table,
    matrix_data = matrix_data,
    line_data = line_data,
    set_sizes = set_sizes
  )
}

theme_axis <- function(base_size = 7) {
  theme_classic(base_size = base_size, base_family = "Arial") +
    theme(
      axis.line = element_line(linewidth = 0.34, colour = "black"),
      axis.ticks = element_line(linewidth = 0.31, colour = "black"),
      axis.ticks.length = grid::unit(1.25, "mm"),
      axis.text = element_text(colour = "black", face = "plain"),
      axis.title = element_text(colour = "black", face = "plain"),
      panel.grid = element_blank(),
      plot.background = element_rect(fill = "white", colour = NA)
    )
}

make_upset_plot <- function(upset) {
  intersections <- upset$intersections
  n_intersections <- nrow(intersections)
  samples_rev <- rev(upset_order)

  band_data <- data.frame(
    sample_id = samples_rev,
    y_num = seq_along(samples_rev),
    stringsAsFactors = FALSE
  )

  p_top <- ggplot(
    intersections,
    aes(x = intersection_rank, y = intersection_size)
  ) +
    geom_col(width = 0.56, fill = "#B7B7B7", colour = NA) +
    geom_text(
      aes(label = intersection_size),
      vjust = -0.28,
      size = 2.15,
      family = "Arial",
      colour = "#303030"
    ) +
    scale_x_continuous(
      limits = c(0.5, n_intersections + 0.5),
      expand = c(0, 0)
    ) +
    scale_y_continuous(
      breaks = scales::breaks_pretty(n = 5),
      expand = expansion(mult = c(0, 0.14))
    ) +
    labs(x = NULL, y = "Intersection size") +
    theme_axis(7) +
    theme(
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      axis.title.y = element_text(
        size = 7.3,
        margin = margin(r = 3),
        face = "plain"
      ),
      axis.text.y = element_text(size = 5.9),
      plot.margin = margin(2, 3, 0, 3)
    )

  p_matrix <- ggplot() +
    geom_rect(
      data = band_data,
      aes(
        xmin = 0.5,
        xmax = n_intersections + 0.5,
        ymin = y_num - 0.5,
        ymax = y_num + 0.5,
        fill = sample_id
      ),
      alpha = 0.88,
      colour = NA
    ) +
    geom_point(
      data = upset$matrix_data,
      aes(x = intersection_rank, y = y_num),
      size = 0.92,
      colour = "#D0D0D0"
    ) +
    geom_segment(
      data = upset$line_data,
      aes(
        x = intersection_rank,
        xend = intersection_rank,
        y = y_min,
        yend = y_max
      ),
      linewidth = 0.78,
      colour = "#2B67A5",
      lineend = "round"
    ) +
    geom_point(
      data = upset$matrix_data[upset$matrix_data$present, ],
      aes(x = intersection_rank, y = y_num),
      size = 1.62,
      colour = "#2B67A5"
    ) +
    scale_fill_manual(values = band_palette, guide = "none") +
    scale_x_continuous(
      limits = c(0.5, n_intersections + 0.5),
      expand = c(0, 0)
    ) +
    scale_y_continuous(
      limits = c(0.5, 3.5),
      breaks = 1:3,
      labels = rep("", 3),
      expand = c(0, 0)
    ) +
    coord_cartesian(clip = "off") +
    labs(x = NULL, y = NULL) +
    theme_axis(7) +
    theme(
      axis.line = element_blank(),
      axis.ticks = element_blank(),
      axis.text = element_blank(),
      plot.margin = margin(0, 3, 1, 3)
    )

  max_set <- max(upset$set_sizes$formula_count)
  set_breaks <- pretty(c(0, max_set), n = 4)
  set_breaks <- sort(unique(c(set_breaks[set_breaks >= 0 & set_breaks <= max_set], 0)))

  p_left <- ggplot(upset$set_sizes, aes(fill = sample_id)) +
    geom_rect(
      aes(
        xmin = 0,
        xmax = formula_count,
        ymin = y_num - 0.23,
        ymax = y_num + 0.23
      ),
      colour = NA
    ) +
    scale_fill_manual(values = palette, guide = "none") +
    scale_x_reverse(breaks = rev(set_breaks), expand = c(0, 0)) +
    scale_y_continuous(
      limits = c(0.5, 3.5),
      breaks = 1:3,
      labels = rep("", 3),
      expand = c(0, 0)
    ) +
    coord_cartesian(xlim = c(max_set * 1.04, 0), clip = "off") +
    labs(x = "Formula count", y = NULL) +
    theme_axis(6.5) +
    theme(
      axis.line.y = element_blank(),
      axis.ticks.y = element_blank(),
      axis.text.y = element_blank(),
      axis.title.x = element_text(size = 6.0, margin = margin(t = 0.8)),
      axis.text.x = element_text(size = 4.7),
      plot.margin = margin(0, 0, 5, 4)
    )

  p_labels <- ggplot(
    data.frame(
      y_num = 1:3,
      label = samples_rev,
      stringsAsFactors = FALSE
    ),
    aes(x = 1, y = y_num, label = label)
  ) +
    geom_text(
      hjust = 1,
      size = 2.25,
      family = "Arial",
      colour = "black"
    ) +
    scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
    scale_y_continuous(limits = c(0.5, 3.5), expand = c(0, 0)) +
    coord_cartesian(clip = "off") +
    theme_void(base_family = "Arial") +
    theme(plot.margin = margin(0, 2, 5, 0))

  p_tag <- ggplot() +
    annotate(
      "text",
      x = 0,
      y = 1,
      label = "a",
      hjust = 0,
      vjust = 1,
      family = "Arial",
      fontface = "bold",
      size = 3.1
    ) +
    xlim(0, 1) +
    ylim(0, 1) +
    theme_void()

  blank <- ggplot() + theme_void()

  (p_tag + blank + p_top +
    plot_layout(widths = c(0.265, 0.015, 0.720))) /
    (p_left + p_labels + p_matrix +
      plot_layout(widths = c(0.265, 0.015, 0.720))) +
    plot_layout(heights = c(0.72, 0.28))
}

vk_segments <- data.frame(
  x = c(0, 0.3, 0.67, 0, 0, 0, 0.1, 0.3, 0.67, 1.0, 1.2, 0, 0.67),
  xend = c(0.3, 0.67, 1.2, 1.2, 0.67, 0.67, 0.1, 0.3, 0.67, 1.0, 1.2, 0, 1.0),
  y = c(2.0, 2.2, 2.4, 1.5, 0.7, 0.2, 0.7, 1.5, 0.2, 0.6, 1.5, 0.2, 0.6),
  yend = c(2.0, 2.2, 2.4, 1.5, 0.7, 0.2, 1.5, 2.2, 2.4, 1.5, 2.4, 2.0, 0.6)
)

make_shared_data <- function(sample_data) {
  shared_formulas <- Reduce(
    intersect,
    lapply(sample_data, function(x) x$Formula)
  )
  reference_sample <- group_levels[[1]]
  shared <- sample_data[[reference_sample]][
    match(shared_formulas, sample_data[[reference_sample]]$Formula),
    c(
      "Formula", "C", "H", "O", "N", "S", "P", "Cl", "Br",
      "O_C", "H_C", "DBE", "AImod", "NOSC"
    )
  ]
  for (sample_id in group_levels) {
    matched <- sample_data[[sample_id]][
      match(shared$Formula, sample_data[[sample_id]]$Formula),
    ]
    shared[[paste0("RI_", sample_id)]] <- matched$RI
    shared[[paste0("Intensity_", sample_id)]] <- matched$Intensity
  }
  shared[order(shared$Formula), ]
}

make_vk_plot <- function(shared_data) {
  ggplot(shared_data, aes(x = O_C, y = H_C)) +
    geom_segment(
      data = vk_segments,
      aes(x = x, xend = xend, y = y, yend = yend),
      inherit.aes = FALSE,
      colour = "grey45",
      linewidth = 0.4,
      linetype = "22"
    ) +
    geom_point(
      size = 0.62,
      alpha = 0.8,
      colour = vk_point_colour
    ) +
    annotate(
      "text",
      x = 0.01,
      y = 2.49,
      label = "Shared",
      hjust = 0,
      vjust = 1,
      family = "Arial",
      fontface = "bold",
      size = 3.0
    ) +
    annotate(
      "text",
      x = 1.18,
      y = 0.03,
      label = paste0("n=", format(nrow(shared_data), big.mark = ",")),
      hjust = 1,
      vjust = 0,
      family = "Arial",
      fontface = "bold",
      size = 2.7
    ) +
    scale_x_continuous(
      breaks = seq(0, 1.2, 0.3),
      labels = function(x) format(x, nsmall = 1),
      limits = c(-0.02, 1.22),
      expand = c(0, 0)
    ) +
    scale_y_continuous(
      breaks = seq(0, 2.5, 0.5),
      labels = function(x) format(x, nsmall = 1),
      limits = c(-0.05, 2.55),
      expand = c(0, 0)
    ) +
    labs(x = "O/C", y = "H/C", tag = "b") +
    theme_bw(base_size = 7, base_family = "Arial") +
    theme(
      panel.grid = element_blank(),
      panel.border = element_rect(
        colour = "black",
        fill = NA,
        linewidth = 0.42
      ),
      axis.line = element_blank(),
      axis.ticks = element_line(colour = "black", linewidth = 0.32),
      axis.ticks.length = grid::unit(1.0, "mm"),
      axis.text = element_text(colour = "black", size = 6.1),
      axis.text.x = element_text(margin = margin(t = 0)),
      axis.text.y = element_text(margin = margin(r = 2)),
      axis.title = element_text(
        colour = "black",
        size = 8.1,
        face = "bold"
      ),
      axis.title.x = element_text(margin = margin(t = 2)),
      axis.title.y = element_text(margin = margin(r = 4)),
      plot.tag = element_text(
        family = "Arial",
        face = "bold",
        size = 9.0
      ),
      plot.tag.position = c(-0.10, 1.04),
      plot.margin = margin(7, 5, 5, 13)
    )
}

property_specs <- data.frame(
  key = c("MW", "DBE", "O_C", "H_C", "N_C", "S_C", "AImod", "NOSC"),
  label = c("MW", "DBE", "O/C", "H/C", "N/C", "S/C", "AImod", "NOSC"),
  tag = letters[3:10],
  stringsAsFactors = FALSE
)

make_long_data <- function(dat) {
  pieces <- lapply(seq_len(nrow(property_specs)), function(i) {
    key <- property_specs$key[[i]]
    data.frame(
      sample_id = as.character(dat$sample_id),
      Formula = dat$Formula,
      RI = dat$RI,
      property = key,
      value = as.numeric(dat[[key]]),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, pieces)
  out <- out[
    is.finite(out$value) &
      is.finite(out$RI) &
      out$RI >= 0,
  ]
  out$sample_id <- factor(out$sample_id, levels = group_levels)
  out$property <- factor(out$property, levels = property_specs$key)
  rownames(out) <- NULL
  out
}

summarize_properties <- function(long_data) {
  rows <- list()
  index <- 0L
  for (property in property_specs$key) {
    for (sample_id in group_levels) {
      index <- index + 1L
      dat <- long_data[
        long_data$property == property &
          long_data$sample_id == sample_id,
        c("value", "RI")
      ]
      rows[[index]] <- data.frame(
        property = property,
        sample_id = sample_id,
        n_formulas = nrow(dat),
        arithmetic_mean = mean(dat$value),
        median = median(dat$value),
        q1 = unname(quantile(dat$value, 0.25)),
        q3 = unname(quantile(dat$value, 0.75)),
        RI_sum = sum(dat$RI),
        RI_weighted_mean = weighted.mean(dat$value, dat$RI),
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

format_p <- function(x) {
  vapply(x, function(value) {
    if (!is.finite(value)) return(NA_character_)
    if (value == 0) return("<2.23e-308")
    if (value < 0.001) return(format(value, scientific = TRUE, digits = 3))
    formatC(value, format = "f", digits = 4)
  }, character(1))
}

run_wilcoxon <- function(long_data) {
  comparisons <- combn(group_levels, 2L, simplify = FALSE)
  rows <- list()
  index <- 0L
  for (property in property_specs$key) {
    for (comparison in comparisons) {
      index <- index + 1L
      x <- long_data$value[
        long_data$property == property &
          long_data$sample_id == comparison[[1]]
      ]
      y <- long_data$value[
        long_data$property == property &
          long_data$sample_id == comparison[[2]]
      ]
      result <- wilcox.test(
        x,
        y,
        alternative = "two.sided",
        exact = FALSE
      )
      rows[[index]] <- data.frame(
        property = property,
        group_1 = comparison[[1]],
        group_2 = comparison[[2]],
        n_1 = length(x),
        n_2 = length(y),
        statistic_W = unname(result$statistic),
        p_raw = result$p.value,
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  out$p_BH_FDR <- p.adjust(out$p_raw, method = "BH")
  out$p_raw_display <- format_p(out$p_raw)
  out$p_BH_FDR_display <- format_p(out$p_BH_FDR)
  out$FDR_class <- ifelse(
    out$p_BH_FDR < 0.001,
    "p < 0.001",
    ifelse(out$p_BH_FDR < 0.05, "p < 0.05", "not significant")
  )
  out
}

make_sig_letters <- function(summary_data, stats_data) {
  output <- summary_data[, c("property", "sample_id", "median")]
  output$sig_letter <- NA_character_

  for (property in property_specs$key) {
    rows <- output$property == property
    medians <- setNames(output$median[rows], output$sample_id[rows])
    property_stats <- stats_data[stats_data$property == property, ]
    sig_pairs <- property_stats[property_stats$p_BH_FDR < 0.05, ]
    letters_out <- setNames(rep(NA_character_, 3), group_levels)

    if (nrow(sig_pairs) == 0L) {
      letters_out[] <- "a"
    } else if (nrow(sig_pairs) == 3L) {
      ordered <- names(sort(medians, decreasing = TRUE))
      letters_out[ordered] <- c("a", "b", "c")
    } else if (nrow(sig_pairs) == 1L) {
      pair <- c(sig_pairs$group_1[[1]], sig_pairs$group_2[[1]])
      ordered_pair <- pair[order(medians[pair], decreasing = TRUE)]
      third <- setdiff(group_levels, pair)
      letters_out[ordered_pair[[1]]] <- "a"
      letters_out[ordered_pair[[2]]] <- "b"
      letters_out[third] <- "ab"
    } else {
      all_pairs <- combn(group_levels, 2L, simplify = FALSE)
      nonsig_pair <- NULL
      for (pair in all_pairs) {
        hit <- property_stats[
          (property_stats$group_1 == pair[[1]] &
             property_stats$group_2 == pair[[2]]) |
            (property_stats$group_1 == pair[[2]] &
               property_stats$group_2 == pair[[1]]),
        ]
        if (nrow(hit) == 1L && hit$p_BH_FDR[[1]] >= 0.05) {
          nonsig_pair <- pair
          break
        }
      }
      other <- setdiff(group_levels, nonsig_pair)
      letters_out[nonsig_pair] <- "a"
      letters_out[other] <- "b"
    }
    output$sig_letter[rows] <- letters_out[output$sample_id[rows]]
  }
  output[, c("property", "sample_id", "sig_letter")]
}

property_axes <- function(key) {
  switch(
    key,
    MW = list(limits = c(100, 950), breaks = c(250, 500, 750)),
    DBE = list(limits = c(-3, 30), breaks = c(0, 10, 20)),
    O_C = list(limits = c(0, 1.22), breaks = c(0.0, 0.5, 1.0)),
    H_C = list(limits = c(0, 3.6), breaks = c(0, 1, 2, 3)),
    N_C = list(limits = c(-0.04, 0.36), breaks = seq(0, 0.3, 0.1)),
    S_C = list(limits = c(-0.04, 0.36), breaks = seq(0, 0.3, 0.1)),
    AImod = list(limits = c(-0.12, 1.8), breaks = c(0.0, 0.5, 1.0, 1.5)),
    NOSC = list(limits = c(-3.5, 3.6), breaks = c(-2, 0, 2))
  )
}

make_violin_panel <- function(
  key,
  label,
  tag,
  long_data,
  summary_data,
  significance_letters
) {
  dat <- long_data[long_data$property == key, ]
  annotation <- merge(
    summary_data[summary_data$property == key, ],
    significance_letters[significance_letters$property == key, ],
    by = c("property", "sample_id"),
    all.x = TRUE,
    sort = FALSE
  )
  dat$sample_id <- factor(dat$sample_id, levels = group_levels)
  annotation$sample_id <- factor(annotation$sample_id, levels = group_levels)
  axes <- property_axes(key)
  annotation$y <- axes$limits[[2]] - 0.09 * diff(axes$limits)
  guides <- data.frame(
    x = seq_along(group_levels),
    sample_id = factor(group_levels, levels = group_levels)
  )

  ggplot(dat, aes(x = sample_id, y = value, fill = sample_id)) +
    geom_vline(
      data = guides,
      aes(xintercept = x, colour = sample_id),
      inherit.aes = FALSE,
      linewidth = 0.26,
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
      size = 1.40,
      stroke = 0.27,
      fill = "white",
      colour = "#202020"
    ) +
    geom_text(
      data = annotation,
      aes(x = sample_id, y = y, label = sig_letter),
      inherit.aes = FALSE,
      family = "Arial",
      size = 2.25,
      colour = "#202020",
      fontface = "bold"
    ) +
    scale_fill_manual(values = palette, guide = "none") +
    scale_colour_manual(values = palette, guide = "none") +
    scale_x_discrete(drop = FALSE) +
    scale_y_continuous(
      breaks = axes$breaks,
      expand = c(0, 0)
    ) +
    coord_cartesian(ylim = axes$limits, clip = "on") +
    labs(x = NULL, y = label, tag = tag) +
    theme_classic(base_size = 7, base_family = "Arial") +
    theme(
      panel.grid.major.y = element_line(
        colour = "#E4E4E4",
        linewidth = 0.24
      ),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      axis.line = element_line(colour = "black", linewidth = 0.35),
      axis.ticks = element_line(colour = "black", linewidth = 0.32),
      axis.ticks.length = grid::unit(1.25, "mm"),
      axis.text = element_text(colour = "black", size = 5.8),
      axis.text.x = element_text(margin = margin(t = 1.5)),
      axis.text.y = element_text(margin = margin(r = 1.5)),
      axis.title.y = element_text(
        colour = "black",
        size = 7.0,
        face = "bold",
        margin = margin(r = 2.5)
      ),
      plot.tag = element_text(
        family = "Arial",
        face = "bold",
        size = 8.4,
        colour = "black"
      ),
      plot.tag.position = c(-0.09, 1.03),
      plot.margin = margin(5.5, 5.5, 4.5, 7.5)
    )
}

upset_data <- make_upset_data(sample_data)
shared_data <- make_shared_data(sample_data)
long_data <- make_long_data(all_data)
summary_data <- summarize_properties(long_data)
stats_data <- run_wilcoxon(long_data)
significance_letters <- make_sig_letters(summary_data, stats_data)

p_upset <- make_upset_plot(upset_data)
p_vk <- make_vk_plot(shared_data)
violin_panels <- lapply(seq_len(nrow(property_specs)), function(index) {
  make_violin_panel(
    property_specs$key[[index]],
    property_specs$label[[index]],
    property_specs$tag[[index]],
    long_data,
    summary_data,
    significance_letters
  )
})

top_row <- wrap_plots(
  list(wrap_elements(full = p_upset), p_vk),
  ncol = 2L,
  widths = c(1.08, 1.00)
)
bottom_grid <- wrap_plots(violin_panels, ncol = 4L, byrow = TRUE)
final_figure <- wrap_plots(
  list(top_row, wrap_elements(full = bottom_grid)),
  ncol = 1L,
  heights = c(0.40, 0.60)
) &
  theme(plot.background = element_rect(fill = "white", colour = NA))

write.csv(
  upset_data$intersections,
  file.path(table_dir, paste0(args$prefix, "_a_intersection_sizes.csv")),
  row.names = FALSE
)
write.csv(
  upset_data$set_sizes[, c("sample_id", "formula_count")],
  file.path(table_dir, paste0(args$prefix, "_a_set_sizes.csv")),
  row.names = FALSE
)
write.csv(
  upset_data$presence,
  file.path(table_dir, paste0(args$prefix, "_a_formula_membership.csv")),
  row.names = FALSE
)
write.csv(
  shared_data,
  file.path(table_dir, paste0(args$prefix, "_b_shared_VK.csv")),
  row.names = FALSE
)
write.csv(
  all_data[, c(
    "sample_id", "Formula", "RI", "MW", "DBE", "O_C", "H_C",
    "N_C", "S_C", "AImod", "NOSC"
  )],
  file.path(table_dir, paste0(args$prefix, "_c-j_molecular_properties.csv")),
  row.names = FALSE
)
write.csv(
  summary_data,
  file.path(table_dir, paste0(args$prefix, "_c-j_summary.csv")),
  row.names = FALSE
)
write.csv(
  significance_letters,
  file.path(table_dir, paste0(args$prefix, "_c-j_significance_letters.csv")),
  row.names = FALSE
)
write.csv(
  stats_data,
  file.path(table_dir, paste0(args$prefix, "_c-j_Wilcoxon_BH_results.csv")),
  row.names = FALSE
)

qa <- data.frame(
  check = c(
    paste0("formula_count_", group_levels),
    paste0("RI_sum_", group_levels),
    "shared_formula_count",
    "intersection_total",
    "wilcoxon_test_count",
    "editable_svg_text_elements"
  ),
  value = c(
    vapply(group_levels, function(x) nrow(sample_data[[x]]), integer(1)),
    vapply(group_levels, function(x) sum(sample_data[[x]]$RI), numeric(1)),
    nrow(shared_data),
    sum(upset_data$intersections$intersection_size),
    nrow(stats_data),
    NA
  ),
  status = c(
    rep("PASS", 3),
    ifelse(
      abs(vapply(
        group_levels,
        function(x) sum(sample_data[[x]]$RI),
        numeric(1)
      ) - 1) < 1e-6,
      "PASS",
      "FAIL"
    ),
    ifelse(nrow(shared_data) > 0, "PASS", "FAIL"),
    ifelse(
      sum(upset_data$intersections$intersection_size) ==
        nrow(upset_data$presence),
      "PASS",
      "FAIL"
    ),
    ifelse(nrow(stats_data) == 24L, "PASS", "FAIL"),
    "PENDING"
  ),
  stringsAsFactors = FALSE
)

caption <- paste(
  args$figure_number,
  "Molecular formula overlap and molecular-property distributions of DOM in",
  paste0(args$sample_description, "."),
  "a, UpSet plot showing the",
  paste0(
    "numbers of unique and shared molecular formulas among ",
    paste(group_levels, collapse = ", "),
    "; horizontal"
  ),
  "bars indicate the",
  "total formula count in each leachate. b, Van Krevelen diagram of the molecular",
  "formulas shared by all three leachates. Dashed boxes indicate the predefined",
  "molecular-class regions. c-j, Distributions of molecular weight (MW), double-bond",
  "equivalents (DBE), O/C, H/C, N/C, S/C, modified aromaticity index (AImod), and",
  "nominal oxidation state of carbon (NOSC), respectively. Violin plots show",
  "formula-level density distributions; boxes denote interquartile ranges with",
  "median lines, and white dots indicate arithmetic means. Different letters",
  "indicate significant differences between leachates (two-sided Wilcoxon rank-sum",
  "tests with Benjamini-Hochberg false-discovery-rate correction; adjusted P < 0.05).",
  "These comparisons describe molecular-formula distributions and do not represent",
  "site-level inference based on biological replicates."
)
writeLines(caption, caption_path, useBytes = TRUE)

width_in <- args$width_mm / 25.4
height_in <- args$height_mm / 25.4

svglite::svglite(
  paste0(output_base, ".svg"),
  width = width_in,
  height = height_in,
  bg = "white",
  system_fonts = list(sans = "Arial")
)
print(final_figure)
grDevices::dev.off()

grDevices::cairo_pdf(
  paste0(output_base, ".pdf"),
  width = width_in,
  height = height_in,
  family = "Arial",
  bg = "white"
)
print(final_figure)
grDevices::dev.off()

grDevices::png(
  paste0(output_base, ".png"),
  width = width_in,
  height = height_in,
  units = "in",
  res = args$dpi,
  bg = "white",
  type = "cairo-png"
)
print(final_figure)
grDevices::dev.off()

grDevices::tiff(
  paste0(output_base, ".tiff"),
  width = width_in,
  height = height_in,
  units = "in",
  res = args$dpi,
  compression = "lzw",
  bg = "white",
  type = "cairo"
)
print(final_figure)
grDevices::dev.off()

svg_lines <- readLines(paste0(output_base, ".svg"), warn = FALSE)
text_count <- sum(grepl("<text", svg_lines, fixed = TRUE))
qa$value[qa$check == "editable_svg_text_elements"] <- text_count
qa$status[qa$check == "editable_svg_text_elements"] <- ifelse(
  text_count > 0,
  "PASS",
  "FAIL"
)
write.csv(
  qa,
  file.path(table_dir, paste0(args$prefix, "_QA.csv")),
  row.names = FALSE
)

message("Saved U-S-V figure outputs to: ", normalizePath(figure_dir, winslash = "/"))
message(
  "Formula counts: ",
  paste(
    group_levels,
    vapply(group_levels, function(x) nrow(sample_data[[x]]), integer(1)),
    collapse = ", "
  )
)
message("Shared formulas: ", nrow(shared_data))

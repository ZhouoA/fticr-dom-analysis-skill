#!/usr/bin/env Rscript

parse_args <- function(args) {
  out <- list(
    input_dir = "",
    input_csv = "",
    output_dir = "raw_vk_outputs",
    prefix = "Raw_Shared_VK",
    sample_order = "YL,OL,ML",
    sheet = "",
    width_in = "3.60",
    height_in = "2.25",
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
  if (length(out$sample_order) != 3L) {
    stop("--sample_order must contain exactly three sample names.", call. = FALSE)
  }
  if (!nzchar(out$input_csv) && !nzchar(out$input_dir)) {
    stop("Provide either --input_dir or --input_csv.", call. = FALSE)
  }
  out
}

vk_segments <- data.frame(
  x = c(0, 0.3, 0.67, 0, 0, 0, 0.1, 0.3, 0.67, 1.0, 1.2, 0, 0.67),
  xend = c(0.3, 0.67, 1.2, 1.2, 0.67, 0.67, 0.1, 0.3, 0.67, 1.0, 1.2, 0, 1.0),
  y = c(2.0, 2.2, 2.4, 1.5, 0.7, 0.2, 0.7, 1.5, 0.2, 0.6, 1.5, 0.2, 0.6),
  yend = c(2.0, 2.2, 2.4, 1.5, 0.7, 0.2, 1.5, 2.2, 2.4, 1.5, 2.4, 2.0, 0.6)
)

vk_xlim <- c(-0.02, 1.22)
vk_ylim <- c(-0.05, 2.55)
vk_x_breaks <- seq(0, 1.2, by = 0.3)
vk_y_breaks <- seq(0, 2.5, by = 0.5)
vk_tick_len_pt <- 2.8
vk_region_col <- "#737373"
vk_region_lwd <- 0.4
vk_region_lty <- "22"
point_col <- "#7A6AA8"
point_alpha <- 0.8
point_cex <- 0.23
point_svg_radius <- 0.92

canonical_names <- function(x) {
  gsub("[^a-z0-9]+", "", tolower(x))
}

find_column <- function(dat, candidates, required = TRUE) {
  normalized <- canonical_names(names(dat))
  hit <- match(canonical_names(candidates), normalized, nomatch = 0L)
  hit <- hit[hit > 0L]
  if (length(hit) > 0L) return(names(dat)[hit[[1]]])
  if (required) {
    stop("Missing required column. Expected one of: ",
         paste(candidates, collapse = ", "), call. = FALSE)
  }
  NULL
}

standardize_formula_table <- function(dat, source_name = "input") {
  formula_col <- find_column(dat, c("Formula", "Molecular Formula", "MolForm"))
  oc_col <- find_column(dat, c("O/C", "O_C", "OC"), required = FALSE)
  hc_col <- find_column(dat, c("H/C", "H_C", "HC"), required = FALSE)
  c_col <- find_column(dat, "C", required = FALSE)
  h_col <- find_column(dat, "H", required = FALSE)
  o_col <- find_column(dat, "O", required = FALSE)

  formula <- trimws(as.character(dat[[formula_col]]))
  if (!is.null(oc_col)) {
    oc <- suppressWarnings(as.numeric(dat[[oc_col]]))
  } else {
    if (is.null(c_col) || is.null(o_col)) {
      stop(source_name, " needs O/C (or both C and O columns).", call. = FALSE)
    }
    carbon <- suppressWarnings(as.numeric(dat[[c_col]]))
    oc <- suppressWarnings(as.numeric(dat[[o_col]])) / carbon
  }
  if (!is.null(hc_col)) {
    hc <- suppressWarnings(as.numeric(dat[[hc_col]]))
  } else {
    if (is.null(c_col) || is.null(h_col)) {
      stop(source_name, " needs H/C (or both C and H columns).", call. = FALSE)
    }
    carbon <- suppressWarnings(as.numeric(dat[[c_col]]))
    hc <- suppressWarnings(as.numeric(dat[[h_col]])) / carbon
  }

  out <- data.frame(Formula = formula, O_C = oc, H_C = hc, stringsAsFactors = FALSE)
  out <- out[nzchar(out$Formula) & is.finite(out$O_C) & is.finite(out$H_C), ]
  out <- out[!duplicated(out$Formula), ]
  rownames(out) <- NULL
  out
}

read_source <- function(path) {
  dat <- read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  standardize_formula_table(dat, basename(path))
}

find_sample_workbook <- function(input_dir, sample_name) {
  files <- list.files(input_dir, pattern = "\\.xlsx?$", full.names = TRUE)
  stems <- tools::file_path_sans_ext(basename(files))
  hit <- which(tolower(stems) == tolower(sample_name))
  if (length(hit) != 1L) {
    stop("Expected exactly one workbook named ", sample_name,
         ".xlsx or ", sample_name, ".xls in ", input_dir, call. = FALSE)
  }
  files[hit]
}

read_shared_workbooks <- function(input_dir, sample_order, sheet = "") {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("Package 'readxl' is required for --input_dir mode. ",
         "Install it with install.packages('readxl').", call. = FALSE)
  }
  tables <- lapply(sample_order, function(sample_name) {
    path <- find_sample_workbook(input_dir, sample_name)
    dat <- if (nzchar(sheet)) {
      readxl::read_excel(path, sheet = sheet)
    } else {
      readxl::read_excel(path, sheet = 1)
    }
    standardize_formula_table(as.data.frame(dat, check.names = FALSE), basename(path))
  })
  names(tables) <- sample_order

  shared <- Reduce(intersect, lapply(tables, `[[`, "Formula"))
  shared <- sort(unique(shared))
  if (length(shared) == 0L) {
    stop("No molecular formulas are shared by all three samples.", call. = FALSE)
  }

  reference <- tables[[1]][match(shared, tables[[1]]$Formula), ]
  for (i in seq_along(tables)[-1]) {
    candidate <- tables[[i]][match(shared, tables[[i]]$Formula), ]
    missing_ratio <- !is.finite(reference$O_C) | !is.finite(reference$H_C)
    reference$O_C[missing_ratio] <- candidate$O_C[missing_ratio]
    reference$H_C[missing_ratio] <- candidate$H_C[missing_ratio]
  }
  reference <- reference[is.finite(reference$O_C) & is.finite(reference$H_C), ]
  rownames(reference) <- NULL
  reference
}

svg_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x
}

write_editable_svg <- function(dat, path, width_in, height_in) {
  width <- width_in * 72
  height <- height_in * 72
  left <- 38
  right <- 7
  top <- 7
  bottom <- 29
  plot_w <- width - left - right
  plot_h <- height - top - bottom

  sx <- function(x) left + ((x - vk_xlim[1]) / diff(vk_xlim)) * plot_w
  sy <- function(y) top + (1 - (y - vk_ylim[1]) / diff(vk_ylim)) * plot_h

  con <- file(path, open = "w", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)

  writeLines(sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" width="%.3fin" height="%.3fin" viewBox="0 0 %.3f %.3f">',
    width_in, height_in, width, height
  ), con)
  writeLines('<rect width="100%" height="100%" fill="white"/>', con)
  writeLines('<g font-family="Arial, Helvetica, sans-serif" fill="black">', con)
  writeLines(sprintf(
    '<rect x="%.3f" y="%.3f" width="%.3f" height="%.3f" fill="none" stroke="black" stroke-width="0.75"/>',
    left, top, plot_w, plot_h
  ), con)

  for (i in seq_len(nrow(vk_segments))) {
    writeLines(sprintf(
      '<line x1="%.3f" y1="%.3f" x2="%.3f" y2="%.3f" stroke="%s" stroke-width="%.2f" stroke-dasharray="2 2"/>',
      sx(vk_segments$x[i]), sy(vk_segments$y[i]), sx(vk_segments$xend[i]), sy(vk_segments$yend[i]),
      vk_region_col, vk_region_lwd
    ), con)
  }

  for (x in vk_x_breaks) {
    writeLines(sprintf(
      '<line x1="%.3f" y1="%.3f" x2="%.3f" y2="%.3f" stroke="black" stroke-width="0.55"/>',
      sx(x), top + plot_h, sx(x), top + plot_h + vk_tick_len_pt
    ), con)
    writeLines(sprintf(
      '<text x="%.3f" y="%.3f" font-size="6.2" text-anchor="middle">%s</text>',
      sx(x), top + plot_h + 8.9, format(x, nsmall = 1)
    ), con)
  }

  for (y in vk_y_breaks) {
    writeLines(sprintf(
      '<line x1="%.3f" y1="%.3f" x2="%.3f" y2="%.3f" stroke="black" stroke-width="0.55"/>',
      left - vk_tick_len_pt, sy(y), left, sy(y)
    ), con)
    writeLines(sprintf(
      '<text x="%.3f" y="%.3f" font-size="6.2" text-anchor="start">%s</text>',
      left - 13.3, sy(y) + 1.4, format(y, nsmall = 1)
    ), con)
  }

  point_df <- dat[is.finite(dat$O_C) & is.finite(dat$H_C), c("O_C", "H_C")]
  for (i in seq_len(nrow(point_df))) {
    writeLines(sprintf(
      '<circle cx="%.3f" cy="%.3f" r="%.2f" fill="%s" fill-opacity="%.2f"/>',
      sx(point_df$O_C[i]), sy(point_df$H_C[i]), point_svg_radius, point_col, point_alpha
    ), con)
  }

  writeLines(sprintf(
    '<text x="%.3f" y="%.3f" font-size="7.3" font-weight="700" text-anchor="start">%s</text>',
    46.6, 19.1, svg_escape("Shared")
  ), con)
  writeLines(sprintf(
    '<text x="%.3f" y="%.3f" font-size="7.0" font-weight="700" text-anchor="start">%s</text>',
    217.7, 128.2, svg_escape(paste0("n=", format(nrow(dat), big.mark = ",", trim = TRUE)))
  ), con)
  writeLines(sprintf(
    '<text x="%.3f" y="%.3f" font-size="7.4" font-weight="700" text-anchor="start">%s</text>',
    139.6, 151.2, svg_escape("O/C")
  ), con)
  writeLines(sprintf(
    '<text x="%.3f" y="%.3f" font-size="7.4" font-weight="700" text-anchor="start" transform="rotate(-90 %.3f %.3f)">%s</text>',
    20.7, 76.7, 20.7, 76.7, svg_escape("H/C")
  ), con)
  writeLines("</g>", con)
  writeLines("</svg>", con)
}

draw_shared_vk <- function(dat) {
  old_par <- par(no.readonly = TRUE)
  on.exit(par(old_par), add = TRUE)

  par(
    family = "sans",
    mar = c(2.45, 2.72, 0.52, 0.42),
    mgp = c(1.10, 0.22, 0),
    tcl = -0.16,
    las = 1,
    xaxs = "i",
    yaxs = "i"
  )

  plot(
    NA,
    xlim = vk_xlim,
    ylim = vk_ylim,
    xlab = "O/C",
    ylab = "H/C",
    axes = FALSE,
    ann = FALSE
  )

  segments(
    vk_segments$x,
    vk_segments$y,
    vk_segments$xend,
    vk_segments$yend,
    col = vk_region_col,
    lty = vk_region_lty,
    lwd = vk_region_lwd
  )

  points(
    dat$O_C,
    dat$H_C,
    pch = 16,
    cex = point_cex,
    col = grDevices::adjustcolor(point_col, alpha.f = point_alpha)
  )

  axis(
    1,
    at = vk_x_breaks,
    labels = FALSE,
    col = "black",
    col.axis = "black",
    col.ticks = "black",
    lwd = 0,
    lwd.ticks = 0.55
  )
  mtext(
    format(vk_x_breaks, nsmall = 1),
    side = 1,
    at = vk_x_breaks,
    line = -0.05,
    cex = 0.43
  )
  axis(
    2,
    at = vk_y_breaks,
    labels = format(vk_y_breaks, nsmall = 1),
    col = "black",
    col.axis = "black",
    col.ticks = "black",
    lwd = 0,
    lwd.ticks = 0.55,
    cex.axis = 0.43,
    mgp = c(1.10, 0.22, 0)
  )
  box(col = "black", lwd = 0.75)
  mtext("O/C", side = 1, line = 0.62, cex = 0.54, font = 2)
  mtext("H/C", side = 2, line = 1.48, cex = 0.54, font = 2, las = 0)
  text(0.03, 2.43, "Shared", adj = c(0, 1), cex = 0.46, font = 2)
  text(
    1.17,
    0.05,
    paste0("n=", format(nrow(dat), big.mark = ",", trim = TRUE)),
    adj = c(1, 0),
    cex = 0.45,
    font = 2
  )
}

save_all <- function(dat, output_dir, prefix, width_in, height_in, dpi) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  base <- file.path(output_dir, prefix)

  write_editable_svg(dat, paste0(base, ".svg"), width_in, height_in)

  grDevices::cairo_pdf(paste0(base, ".pdf"), width = width_in, height = height_in, family = "sans")
  draw_shared_vk(dat)
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
  draw_shared_vk(dat)
  grDevices::dev.off()

  grDevices::tiff(
    paste0(base, ".tiff"),
    width = width_in,
    height = height_in,
    units = "in",
    res = dpi,
    compression = "lzw",
    bg = "white"
  )
  draw_shared_vk(dat)
  grDevices::dev.off()
}

write_plot_qa <- function(dat, output_dir, prefix) {
  qa <- data.frame(
    metric = c("plotted_formula_count", "O_C_min", "O_C_max", "H_C_min", "H_C_max"),
    value = c(
      nrow(dat),
      min(dat$O_C, na.rm = TRUE),
      max(dat$O_C, na.rm = TRUE),
      min(dat$H_C, na.rm = TRUE),
      max(dat$H_C, na.rm = TRUE)
    )
  )
  write.csv(qa, file.path(output_dir, paste0(prefix, "_plot_QA.csv")), row.names = FALSE)
}

main <- function() {
  args <- parse_args(commandArgs(trailingOnly = TRUE))
  if (nzchar(args$input_csv)) {
    dat <- read_source(args$input_csv)
  } else {
    dat <- read_shared_workbooks(args$input_dir, args$sample_order, args$sheet)
  }
  dir.create(args$output_dir, recursive = TRUE, showWarnings = FALSE)
  write.csv(
    dat,
    file.path(args$output_dir, paste0(args$prefix, "_source_data.csv")),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  save_all(dat, args$output_dir, args$prefix, args$width_in, args$height_in, args$dpi)
  write_plot_qa(dat, args$output_dir, args$prefix)
  message("Saved shared VK outputs to: ", normalizePath(args$output_dir, winslash = "/", mustWork = TRUE))
  message("plotted_formula_count=", nrow(dat))
}

main()

options(stringsAsFactors = FALSE)

`%||%` <- function(x, y) if (is.null(x)) y else x

parse_cli <- function(x) {
  out <- list()
  i <- 1L
  while (i <= length(x)) {
    if (!startsWith(x[[i]], "--")) {
      stop("Unexpected argument: ", x[[i]], call. = FALSE)
    }
    key <- sub("^--", "", x[[i]])
    if (i == length(x) || startsWith(x[[i + 1L]], "--")) {
      out[[key]] <- TRUE
      i <- i + 1L
    } else {
      out[[key]] <- x[[i + 1L]]
      i <- i + 2L
    }
  }
  out
}

split_csv <- function(x) trimws(strsplit(x, ",", fixed = TRUE)[[1]])

args <- parse_cli(commandArgs(trailingOnly = TRUE))
required <- c("input_dir", "output_dir")
missing <- required[!vapply(required, function(x) !is.null(args[[x]]), logical(1))]
if (length(missing) > 0) {
  stop("Missing arguments: ", paste0("--", missing, collapse = ", "), call. = FALSE)
}

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
  library(ggplot2)
  library(patchwork)
  library(readr)
})

sample_order <- split_csv(args$sample_order %||% "YL,ML,OL")
left_files <- split_csv(args$left_files %||% "YL.xlsx,ML.xlsx,OL.xlsx")
right_files <- split_csv(args$right_files %||% "YLr.csv,MLr.csv,OLr.csv")
left_ids <- split_csv(args$left_ids %||% paste(sample_order, collapse = ","))
right_ids <- split_csv(args$right_ids %||% "YLr,MLr,OLr")

list_lengths <- c(
  sample_order = length(sample_order),
  left_files = length(left_files),
  right_files = length(right_files),
  left_ids = length(left_ids),
  right_ids = length(right_ids)
)
if (length(unique(list_lengths)) != 1L || list_lengths[[1]] != 3L) {
  stop("sample_order and all file/ID lists must contain exactly three values.", call. = FALSE)
}

input_dir <- normalizePath(args$input_dir, winslash = "/", mustWork = TRUE)
dir.create(args$output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(args$output_dir, winslash = "/", mustWork = TRUE)
prefix <- args$prefix %||% "Marginal_Group_Composite"
width_in <- as.numeric(args$width_in %||% "9")
height_in <- as.numeric(args$height_in %||% "6.6")
dpi <- as.integer(args$dpi %||% "600")

for (file in c(left_files, right_files)) {
  path <- file.path(input_dir, file)
  if (!file.exists(path)) stop("Missing input file: ", path, call. = FALSE)
}

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) {
  stop("Could not determine the script directory.", call. = FALSE)
}
script_path <- normalizePath(
  sub("^--file=", "", script_arg[[1]]),
  winslash = "/", mustWork = TRUE
)
script_dir <- dirname(script_path)
source_dir <- file.path(output_dir, paste0(prefix, "_intermediate"))
dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)

options(
  dom_pair_age_levels = sample_order,
  dom_pair_sample_pairs = data.frame(
    Age = sample_order,
    Raw = left_files,
    Reservoir = right_files,
    stringsAsFactors = FALSE
  ),
  dom_pair_left_ids = stats::setNames(left_ids, sample_order),
  dom_pair_right_ids = stats::setNames(right_ids, sample_order),
  dom_pair_labels = stats::setNames(
    paste(left_ids, "vs.", right_ids),
    sample_order
  )
)

options(
  pretreatment_script_args = c(
    input_dir, source_dir, paste0(prefix, "_VK_marginal")
  )
)
vk_env <- new.env(parent = globalenv())
sys.source(file.path(script_dir, "plot_pair_vk_marginal.R"), envir = vk_env)
a_plot <- vk_env$combined

options(
  pretreatment_script_args = c(
    input_dir, source_dir, paste0(prefix, "_class_contributions")
  )
)
bc_env <- new.env(parent = globalenv())
sys.source(file.path(script_dir, "plot_pair_class_contributions.R"), envir = bc_env)
bc_plot <- bc_env$combined

bc_plot_for_composite <- bc_plot &
  theme(
    plot.tag = element_text(
      family = "Arial", face = "bold",
      size = 9.1, colour = "black"
    )
  )

a_plot_fixed <- free(a_plot)
bc_plot_fixed <- free(bc_plot_for_composite)
bc_plot_aligned <- wrap_plots(
  bc_plot_fixed, plot_spacer(),
  nrow = 1, widths = c(0.964, 0.036)
)
final_plot <- a_plot_fixed / bc_plot_aligned +
  plot_layout(ncol = 1, heights = c(76, 91.5))

base <- file.path(output_dir, prefix)
grDevices::cairo_pdf(
  paste0(base, ".pdf"),
  width = width_in, height = height_in,
  family = "Arial", onefile = TRUE
)
print(final_plot)
dev.off()

svglite::svglite(
  paste0(base, ".svg"),
  width = width_in, height = height_in
)
print(final_plot)
dev.off()

ragg::agg_png(
  paste0(base, ".png"),
  width = width_in, height = height_in,
  units = "in", res = dpi, background = "white"
)
print(final_plot)
dev.off()

ragg::agg_tiff(
  paste0(base, ".tiff"),
  width = width_in, height = height_in,
  units = "in", res = dpi,
  compression = "lzw", background = "white"
)
print(final_plot)
dev.off()

write_csv(
  vk_env$all_data |>
    dplyr::mutate(
      Age = as.character(Age),
      Stage = as.character(Stage)
    ),
  paste0(base, "_formula_classification.csv")
)
write_csv(vk_env$stage_counts, paste0(base, "_stage_counts.csv"))
write_csv(vk_env$pair_qa, paste0(base, "_pair_QA.csv"))
write_csv(
  bc_env$source_data |>
    dplyr::mutate(
      Age = as.character(Age),
      Stage = as.character(Stage),
      Category = as.character(Category)
    ),
  paste0(base, "_class_contributions_source_data.csv")
)
write_csv(
  bc_env$qa,
  paste0(base, "_class_contributions_QA.csv")
)

caption <- paste0(
  "Molecular formula fates and compositional shifts between ",
  paste(paste(left_ids, "and", right_ids), collapse = ", "),
  ". Removed formulas were detected only in the left sample, produced formulas ",
  "only in the right sample, and shared formulas in both samples. Percentages ",
  "were calculated from molecular-formula counts and were not RI weighted."
)
writeLines(caption, paste0(base, "_caption.txt"), useBytes = TRUE)

if (any(vk_env$pair_qa$status != "PASS") || any(bc_env$qa$status != "PASS")) {
  stop("QA failed. Inspect the pair and class-contribution QA files.", call. = FALSE)
}

cat("Created marginal+group figure: ", base, "\n", sep = "")

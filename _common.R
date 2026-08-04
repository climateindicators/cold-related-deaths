# Helpers available to every page. Quarto sources this via the setup chunk on
# each .qmd.
#
# HARD RULE: a page reads data/ and nothing else. It never opens data-raw/,
# never reaches the network, and never re-derives a number. If a page needs a
# value that is not in data/, the fix is to add it to R/build_data.R and
# regenerate, so that the number is tested and reproducible rather than computed
# inline where nothing checks it.

suppressPackageStartupMessages({
  library(ggplot2)
})

#' Read a generated indicator dataset.
#'
#' Values are stored as text so the source file's precision survives byte for
#' byte (see R/utils/epa_csv.R). This is where they become numeric, once, for
#' plotting. Rows carrying a suppression flag get NA, which is what makes the
#' chart draw a gap instead of a zero.
read_indicator <- function(file) {
  d <- readr::read_csv(
    here::here("data", file),
    col_types = readr::cols(.default = readr::col_character()),
    na = character(), progress = FALSE
  )
  d$value <- suppressWarnings(as.numeric(d$value))
  if ("year" %in% names(d)) d$year <- as.integer(d$year)
  if ("date" %in% names(d)) d$date <- as.Date(d$date)
  d
}

#' Read the generated data dictionary.
read_meta <- function() {
  yaml::read_yaml(here::here("data", "meta.yml"))
}

#' Pull one dataset's entry out of meta.yml by filename.
meta_for <- function(file, meta = read_meta()) {
  hit <- Filter(function(d) identical(d$file, file), meta$datasets)
  if (length(hit) != 1L) stop("No meta.yml entry for ", file, call. = FALSE)
  hit[[1]]
}

# Shared chart styling. The font family is left as the theme default rather than
# named explicitly: SVG text metrics are resolved at build time, so pinning a
# family that is not installed everywhere makes the same chart render
# differently on a different machine.
theme_indicator <- function(base_size = 13) {
  theme_minimal(base_size = base_size) %+replace%
    theme(
      panel.grid.minor   = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(colour = "#dcdcd7", linewidth = 0.4),
      axis.title         = element_text(colour = "#464646", size = rel(0.9)),
      axis.text          = element_text(colour = "#464646"),
      axis.line.x        = element_line(colour = "#464646", linewidth = 0.4),
      plot.title         = element_blank(),   # the caption block carries the title
      plot.margin        = margin(4, 4, 4, 4),
      strip.text         = element_text(colour = "#1e1e1e", face = "bold",
                                        hjust = 0, size = rel(0.95)),
      legend.position    = "none"             # each figure sets its own legend
    )
}

# Series colours, keyed by the machine-readable series key from data/. Never by
# position, to keep the same convention as every other indicator built from
# this template even though this one has no position/legend-order mismatch to
# guard against.
#
# Palette is the validated two-slot categorical set (blue/orange,
# CVD delta-E >= 8, checked with dataviz/scripts/validate_palette.js),
# assigned by a fixed rule rather than cycled: slot 1 (blue) is always the
# baseline/narrower series, slot 2 (orange) is the broader series most worth
# the reader's attention.
INDICATOR_COLOURS <- c(
  # Figure 1: underlying-cause-only is the narrower, longer-running measure
  # and is the baseline; underlying-or-contributing is the broader, higher
  # picture and gets the attention colour.
  underlying                 = "#2a78d6",
  underlying_or_contributing = "#eb6834"
)

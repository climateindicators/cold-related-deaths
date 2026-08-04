# The two interactive figures for index.qmd.
#
# Sourced from a page's setup chunk, after _common.R. Each fig_*() function
# reads data/ (never data-raw/) and returns a girafe htmlwidget: build-time
# SVG, hover tooltips, no CDN dependency. See _common.R for
# INDICATOR_COLOURS and theme_indicator().
#
# Two figures, not three like heat-related-deaths: EPA's published indicator
# page has exactly one chart (Figure 1). The second figure here, Figure TD-1
# (deaths by month), is EPA's own supplementary chart from the technical
# documentation rather than the published page -- see data-raw/PROVENANCE.md
# for why it is built anyway, and index.qmd for how it is labelled so a
# reader is never told it is something EPA's page itself shows.
#
# These are built to represent the data honestly and read clearly, not to
# reproduce EPA's own chart design:
#
#   - Figure 1's ICD-9/ICD-10 break (1998/1999) is a real column,
#     icd_revision, not a hand-placed gap: the line is split by pasting it
#     onto series_key, so nothing here has to know the year 1998 is special.
#   - Series are labelled with a plain legend above the plot rather than
#     end-of-line direct labels, for the same collision reason
#     heat-related-deaths' Figure 1 uses one: "Underlying and contributing
#     causes of death" is long enough to fight the line it would sit beside.
#   - Colour is a fixed categorical palette (blue/orange), validated for
#     CVD-safe separation with dataviz/scripts/validate_palette.js, assigned
#     by role rather than cycled: blue is the narrower underlying-cause
#     series, orange the broader underlying-or-contributing series that is
#     most worth the reader's attention. See _common.R.
#   - Figure TD-1 is a bar chart with a fixed January-December x order, not
#     the alphabetical order a bare factor would give month names.
#     R/utils/pick_chart.R independently reaches "categorical x -> bar" from
#     the data shape alone; R/build_data.R runs it as a sanity check.

suppressPackageStartupMessages({
  library(ggiraph)
})

GIRAFE_OPTS <- list(
  opts_hover(css = "stroke-width:3.5;"),
  opts_hover_inv(css = "opacity:0.3;"),
  opts_tooltip(css = paste(
    "background:#1e1e1e;color:#fff;padding:6px 10px;border-radius:4px;",
    "font-family:sans-serif;font-size:12px;"
  )),
  opts_toolbar(saveaspng = FALSE),
  opts_sizing(rescale = TRUE, width = 1)
)

girafe_indicator <- function(p, height = 4.2) {
  ggiraph::girafe(
    ggobj = p, width_svg = 8, height_svg = height,
    options = GIRAFE_OPTS
  )
}

# Map a data frame's label column to INDICATOR_COLOURS and to a legend order,
# both driven by an explicit key order rather than alphabetising the label
# text (ggplot's default for a character aesthetic).
label_colours <- function(d, key_col, label_col, order) {
  lab <- d[[label_col]][match(order, d[[key_col]])]
  setNames(unname(INDICATOR_COLOURS[order]), lab)
}
label_order <- function(d, key_col, label_col, order) {
  d[[label_col]][match(order, d[[key_col]])]
}

legend_top <- function() {
  theme(
    legend.position   = "top",
    legend.title      = element_blank(),
    legend.justification = "left",
    legend.margin     = margin(0, 0, 6, 0),
    legend.text       = element_text(size = rel(0.85)),
    legend.key.width  = unit(1.4, "lines")
  )
}

# ---- Figure 1: annual cold-related death rates -------------------------------

# *_plot() builds the plain ggplot object; fig_1()/fig_td1() wrap it for the
# page. The split exists so the plot can be ggsave()'d for a static
# side-by-side comparison against data-raw's own workbook without pulling in
# the htmlwidget machinery.
fig_1_plot <- function() {
  d <- read_indicator("cold_deaths_annual.csv")
  # icd_revision splits the underlying-cause line at the classification
  # change; series_key alone would draw straight through 1998/1999.
  d$seg <- paste(d$series_key, d$icd_revision, sep = "/")
  order <- c("underlying", "underlying_or_contributing")

  ggplot(d, aes(x = year, y = value, colour = series_label, group = seg)) +
    geom_line_interactive(linewidth = 0.9) +
    geom_point_interactive(
      aes(
        data_id = series_key,
        tooltip = sprintf(
          "%d — %s\n%.2f deaths per million (%s)",
          year, series_label, value, icd_revision
        )
      ),
      size = 2.2
    ) +
    scale_colour_manual(values = label_colours(d, "series_key", "series_label", order),
                       breaks = label_order(d, "series_key", "series_label", order)) +
    guides(colour = guide_legend(nrow = 2, byrow = TRUE)) +
    scale_x_continuous(breaks = seq(1980, 2015, 5)) +
    scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.06))) +
    labs(x = NULL, y = "Death rate (per million people)") +
    theme_indicator() +
    legend_top()
}

fig_1 <- function() girafe_indicator(fig_1_plot())

fig_1_table <- function() {
  d <- read_indicator("cold_deaths_annual.csv")
  tidyr::pivot_wider(d, id_cols = year, names_from = series_label, values_from = value)
}

# ---- Figure TD-1: cold-related deaths by month, 1999-2015 --------------------

MONTH_LEVELS <- c(
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"
)

fig_td1_plot <- function() {
  d <- read_indicator("cold_deaths_monthly.csv")
  d$month <- factor(d$month, levels = MONTH_LEVELS)

  ggplot(d, aes(x = month, y = value)) +
    geom_col_interactive(
      aes(
        data_id = month,
        tooltip = sprintf("%s\n%d deaths (1999–2015 total)", month, value)
      ),
      fill = unname(INDICATOR_COLOURS["underlying_or_contributing"]),
      width = 0.7
    ) +
    scale_x_discrete(labels = substr(MONTH_LEVELS, 1, 3)) +
    scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.06))) +
    labs(x = NULL, y = "Total deaths, 1999–2015") +
    theme_indicator()
}

fig_td1 <- function() girafe_indicator(fig_td1_plot())

fig_td1_table <- function() {
  d <- read_indicator("cold_deaths_monthly.csv")
  d$month <- factor(d$month, levels = MONTH_LEVELS)
  d <- d[order(d$month), ]
  data.frame(Month = as.character(d$month), `Total deaths` = d$value, check.names = FALSE)
}

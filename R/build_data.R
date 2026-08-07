# Build tidy long-format data for the Cold-Related Deaths indicator.
#
#   Rscript R/build_data.R
#
# Reads two sheets of ERG's indicator workbook in data-raw/ and writes
# data/*.csv plus data/meta.yml. See CLAUDE.md for the rules this file follows.
#
# The vendored source is ERG's internal xlsx workbook rather than EPA's public
# per-figure CSV (see data-raw/PROVENANCE.md), so R/utils/epa_csv.R does not
# apply: there is no preamble to read, and values arrive as IEEE 754 doubles
# via readxl rather than as precision-preserving text.

suppressPackageStartupMessages({
  library(dplyr)
  library(readxl)
})

root <- here::here()
source(file.path(root, "R", "utils", "write_stable.R"))

raw_dir <- file.path(root, "data-raw")
out_dir <- file.path(root, "data")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

xlsx_path <- file.path(raw_dir, "cold-deaths_figure-1-and-TD1_04-08-19.xlsx")

# ---- Indicator constants -----------------------------------------------------

# Deaths through 1998 are coded under ICD-9, 1999 onward under ICD-10 -- see
# data-raw's Methods and Notes sheet. EPA marks this only as a visual gap in
# Figure 1; carrying it as a data column is what lets the chart split the
# line without a hand-placed break.
ICD10_FIRST_YEAR <- 1999L

EN_DASH <- intToUtf8(0x2013)

# Rounding, not preserved source-text precision: values arrive as doubles via
# readxl, not parsed from formatted text, so there is no original decimal
# string to keep byte for byte the way R/utils/epa_csv.R does for a published
# CSV. 8 decimal places exceeds CDC WONDER's own stated precision setting (9
# decimal places at the per-100,000 scale the workbook's Methods and Notes
# sheet describes pulling, i.e. 8 at the per-million scale used here), so
# nothing meaningful is lost, and it is fixed so reruns are byte-identical.
RATE_DECIMALS <- 8L

INDICATOR <- list(
  name                    = "Cold-Related Deaths",
  slug                    = "cold-related-deaths",
  publisher               = "U.S. Environmental Protection Agency",
  source_page             = "https://19january2025snapshot.epa.gov/climate-indicators/climate-change-indicators-cold-related-deaths",
  technical_documentation = "https://19january2025snapshot.epa.gov/sites/default/files/2021-04/documents/cold-deaths_td.pdf",
  rights                  = "Public domain, work of the U.S. Government (17 U.S.C. 105)"
)

# Verified against EPA's live public CSV download for Figure 1 (byte-checked
# against this workbook, see data-raw/PROVENANCE.md) and, for TD-1, against
# the technical documentation PDF at INDICATOR$technical_documentation. There
# is no preamble in this xlsx to read these from programmatically, so they are
# literal strings, same treatment build_data.R already gives source_page and
# technical_documentation above.
FIG1_TITLE       <- paste0("Figure 1. Deaths Classified as \u201cCold-Related\u201d in the United States, 1979", EN_DASH, "2016")
FIG1_DATA_SOURCE <- "CDC, 2018"
FIG1_WEB_UPDATE  <- "April 2021"
FIG1_UNITS       <- "death rate per million people"

FIGTD1_TITLE       <- paste0("Figure TD-1. Deaths Classified as \u201cCold-Related\u201d in the United States by Month, 1999", EN_DASH, "2015")
FIGTD1_DATA_SOURCE <- "CDC, 2018b"
FIGTD1_WEB_UPDATE  <- "March 2018" # workbook's own "Last updated" date; TD-1 is not on the live page (see PROVENANCE.md)
FIGTD1_UNITS       <- "deaths"     # a count, not a rate -- unlike Figure 1

FIG1_SERIES <- tibble::tribble(
  ~series_key,                  ~series_label,
  "underlying",                 "Underlying cause of death",
  "underlying_or_contributing", "Underlying and contributing causes of death"
)

MONTH_LEVELS <- c(
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"
)

# ---- Figure 1: annual cold-related death rates -------------------------------
#
# "Data for Figure 1" lays out two blocks side by side sharing the generic
# header "Year" / "Crude rate per 1,000,000": columns A:B are the underlying-
# cause series (1979-2016), columns D:E are the underlying-or-contributing
# series (1999-2015). Read by explicit range, then the header cells are
# asserted against what the build expects, since a generic "Year" header
# cannot be matched by string the way R/utils/epa_csv.R matches a CSV column.

assert_block_header <- function(hdr, what) {
  expected <- c("Year", "Crude rate per 1,000,000")
  if (!identical(hdr, expected)) {
    stop(
      "Header cells for ", what, " are not what this build expects.\n",
      "  expected: ", paste(sQuote(expected), collapse = ", "), "\n",
      "  actual:   ", paste(sQuote(hdr), collapse = ", "), "\n",
      "If EPA's workbook changed shape, update the range in R/build_data.R.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

f1_underlying_raw <- read_excel(xlsx_path, sheet = "Data for Figure 1", range = "A3:B41", col_names = TRUE)
assert_block_header(names(f1_underlying_raw), "Figure 1 underlying-cause block")
f1_underlying <- f1_underlying_raw |>
  transmute(
    year        = as.integer(Year),
    series_key  = "underlying",
    value       = round(`Crude rate per 1,000,000`, RATE_DECIMALS)
  )

f1_contrib_raw <- read_excel(xlsx_path, sheet = "Data for Figure 1", range = "D3:E20", col_names = TRUE)
assert_block_header(names(f1_contrib_raw), "Figure 1 underlying-or-contributing block")
f1_contrib <- f1_contrib_raw |>
  transmute(
    year        = as.integer(Year),
    series_key  = "underlying_or_contributing",
    value       = round(`Crude rate per 1,000,000`, RATE_DECIMALS)
  )

stopifnot(
  "underlying-cause series should cover 1979-2016 with no gaps" =
    identical(sort(f1_underlying$year), 1979:2016),
  "underlying-or-contributing series should cover 1999-2015 with no gaps" =
    identical(sort(f1_contrib$year), 1999:2015)
)

f1 <- bind_rows(f1_underlying, f1_contrib) |>
  mutate(
    icd_revision = if_else(year < ICD10_FIRST_YEAR, "ICD-9", "ICD-10"),
    measure      = "death_rate",
    unit         = FIG1_UNITS
  ) |>
  left_join(FIG1_SERIES, by = "series_key") |>
  arrange(year, match(series_key, FIG1_SERIES$series_key)) |>
  select(year, series_key, series_label, icd_revision, measure, unit, value)

# ---- Figure TD-1: cold-related deaths by month, 1999-2015 --------------------
#
# Not on the published indicator page -- see data-raw/PROVENANCE.md for why
# this build includes it anyway. It is the same underlying-or-contributing
# 1999-2015 data as Figure 1's second series, aggregated by calendar month
# instead of by year.

td1_raw <- read_excel(xlsx_path, sheet = "Data for Figure TD-1")
assert_headers_td1 <- c("Month", "Month number", "Total deaths, 1999-2015")
if (!identical(names(td1_raw), assert_headers_td1)) {
  stop(
    "Header cells for Figure TD-1 are not what this build expects.\n",
    "  expected: ", paste(sQuote(assert_headers_td1), collapse = ", "), "\n",
    "  actual:   ", paste(sQuote(names(td1_raw)), collapse = ", "), "\n",
    "If EPA's workbook changed shape, update R/build_data.R.",
    call. = FALSE
  )
}

td1 <- td1_raw |>
  transmute(
    month     = Month,
    month_num = as.integer(`Month number`),
    measure   = "monthly_total_deaths",
    unit      = FIGTD1_UNITS,
    value     = as.integer(`Total deaths, 1999-2015`)
  ) |>
  arrange(month_num)

stopifnot(
  "TD-1 should have all twelve months, no more, no fewer" =
    identical(sort(td1$month), sort(MONTH_LEVELS)),
  "TD-1 month_num should run 1:12" =
    identical(td1$month_num, 1:12)
)

# Conservation check: TD-1's 12 monthly totals and the raw CDC monthly pull
# ("Contributing cause data - CDC", one row per year/month, 1999-2015) are two
# different aggregations of the same underlying counts and must agree exactly.
# This is the check that would catch TD-1 having been built from a different
# vintage of the data than it claims.
raw_monthly <- read_excel(xlsx_path, sheet = "Contributing cause data - CDC", skip = 1)
stopifnot(
  "TD-1 total must equal the sum of the raw monthly CDC pull" =
    sum(td1$value) == sum(raw_monthly$Count)
)

# ---- Write ------------------------------------------------------------------

write_csv_stable(f1, file.path(out_dir, "cold_deaths_annual.csv"))
write_csv_stable(td1, file.path(out_dir, "cold_deaths_monthly.csv"))

# ---- Data dictionary ---------------------------------------------------------

col <- function(name, type, description) {
  list(name = name, type = type, description = description)
}

meta <- list(
  indicator = INDICATOR,
  datasets = list(
    list(
      file            = "cold_deaths_annual.csv",
      figure          = "Figure 1",
      figure_title    = FIG1_TITLE,
      source_file     = "cold-deaths_figure-1-and-TD1_04-08-19.xlsx",
      source_sheet    = "Data for Figure 1",
      source_sha256   = file_sha256(xlsx_path),
      data_source     = FIG1_DATA_SOURCE,
      web_update      = FIG1_WEB_UPDATE,
      unit            = FIG1_UNITS,
      rows            = nrow(f1),
      columns = list(
        col("year", "integer", "Calendar year"),
        col("series_key", "string", "Machine-readable series identifier"),
        col("series_label", "string", "Display label"),
        col("icd_revision", "string", paste0(
          "ICD revision in force for that year: ICD-9 through ",
          ICD10_FIRST_YEAR - 1L, ", ICD-10 from ", ICD10_FIRST_YEAR,
          ". Added by this build; not a column in the source workbook."
        )),
        col("measure", "string", "What is measured"),
        col("unit", "string", "Unit of `value`"),
        col("value", "number", "Death rate, rounded to 8 decimal places (see data-raw/PROVENANCE.md).")
      ),
      series = list(
        list(
          key      = "underlying",
          label    = FIG1_SERIES$series_label[FIG1_SERIES$series_key == "underlying"],
          coverage = "1979-2016",
          note     = paste(
            "Deaths for which exposure to excessive natural cold was the",
            "underlying cause. Values before and after the ICD-9 to ICD-10",
            "change are not directly comparable, which is why EPA draws this",
            "line with a break."
          )
        ),
        list(
          key      = "underlying_or_contributing",
          label    = FIG1_SERIES$series_label[FIG1_SERIES$series_key == "underlying_or_contributing"],
          coverage = "1999-2015",
          note     = paste(
            "Deaths for which cold was the underlying or a contributing",
            "cause. Based on a broader analysis that, at present, can only",
            "be evaluated for 1999-2015."
          )
        )
      )
    ),
    list(
      file            = "cold_deaths_monthly.csv",
      figure          = "Figure TD-1",
      figure_title    = FIGTD1_TITLE,
      source_file     = "cold-deaths_figure-1-and-TD1_04-08-19.xlsx",
      source_sheet    = "Data for Figure TD-1",
      source_sha256   = file_sha256(xlsx_path),
      data_source     = FIGTD1_DATA_SOURCE,
      web_update      = FIGTD1_WEB_UPDATE,
      unit            = FIGTD1_UNITS,
      rows            = nrow(td1),
      columns = list(
        col("month", "string", "Calendar month name"),
        col("month_num", "integer", "Calendar month, 1 = January"),
        col("measure", "string", "What is measured"),
        col("unit", "string", "Unit of `value`: a count, not a rate"),
        col("value", "integer", "Total deaths for that calendar month, summed over 1999-2015")
      ),
      note = paste(
        "Not on EPA's published indicator page -- this is EPA's own",
        "supplementary Figure TD-1 from the technical documentation, built",
        "here as a second figure because the data exists and shows the",
        "seasonal pattern behind Figure 1's underlying-or-contributing",
        "series. See data-raw/PROVENANCE.md."
      )
    )
  )
)

write_yaml_stable(meta, file.path(out_dir, "meta.yml"))

# ---- Verify what was written -------------------------------------------------

written <- file.path(out_dir, c("cold_deaths_annual.csv", "cold_deaths_monthly.csv", "meta.yml"))
invisible(lapply(written, assert_clean_output))

cat("\nWrote:\n")
for (p in written) {
  cat(sprintf("  %-30s %6d bytes  %s\n", basename(p), file.size(p), substr(file_sha256(p), 1, 12)))
}
cat(sprintf("\nRows: figure 1 = %d, figure TD-1 = %d\n", nrow(f1), nrow(td1)))

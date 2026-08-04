# Regression checks on the generated data files.
#
#   Rscript tests/test-data.R
#
# These are value snapshots, deliberately separate from R/build_data.R. The
# build asserts structural invariants that survive a data update (header
# match, conservation, series coverage); this file pins the actual numbers,
# so after an update it tells you exactly what changed instead of silently
# accepting it.
#
# When the data is legitimately updated, expect failures here and update the
# expectations after checking each one against the new source workbook.

setwd(here::here())
source("R/utils/write_stable.R")

failures <- character()
check <- function(label, ok) {
  ok <- isTRUE(ok)
  cat(sprintf("  [%s] %s\n", if (ok) "PASS" else "FAIL", label))
  if (!ok) failures <<- c(failures, label)
  invisible(ok)
}

rd <- function(f) {
  readr::read_csv(file.path("data", f),
                  col_types = readr::cols(.default = readr::col_character()),
                  na = character(), progress = FALSE)
}

f1  <- rd("cold_deaths_annual.csv")
td1 <- rd("cold_deaths_monthly.csv")

val <- function(df, ...) {
  conds <- list(...)
  keep <- rep(TRUE, nrow(df))
  for (nm in names(conds)) keep <- keep & df[[nm]] == conds[[nm]]
  df$value[keep]
}

cat("\nFigure 1 (cold_deaths_annual.csv)\n")
check("55 rows", nrow(f1) == 55L)
check("columns as documented",
      identical(names(f1), c("year", "series_key", "series_label",
                             "icd_revision", "measure", "unit", "value")))
check("1979 underlying = 1.5847903",
      identical(val(f1, year = "1979", series_key = "underlying"), "1.5847903"))
check("2016 underlying = 2.2622648",
      identical(val(f1, year = "2016", series_key = "underlying"), "2.2622648"))
check("1999 underlying_or_contributing = 4.46889066",
      identical(val(f1, year = "1999", series_key = "underlying_or_contributing"), "4.46889066"))
check("2015 underlying_or_contributing = 5.44149842",
      identical(val(f1, year = "2015", series_key = "underlying_or_contributing"), "5.44149842"))
check("no 2016 underlying_or_contributing row",
      length(val(f1, year = "2016", series_key = "underlying_or_contributing")) == 0L)
check("no 1998 underlying_or_contributing row",
      length(val(f1, year = "1998", series_key = "underlying_or_contributing")) == 0L)
check("1998 is ICD-9",
      identical(unique(f1$icd_revision[f1$year == "1998"]), "ICD-9"))
check("1999 is ICD-10",
      identical(unique(f1$icd_revision[f1$year == "1999"]), "ICD-10"))
check("underlying series covers 1979-2016 with no gaps",
      identical(sort(as.integer(f1$year[f1$series_key == "underlying"])), 1979:2016))
check("underlying_or_contributing series covers 1999-2015 with no gaps",
      identical(sort(as.integer(f1$year[f1$series_key == "underlying_or_contributing"])), 1999:2015))
check("underlying_or_contributing is always higher than underlying where both exist", {
  wide <- tidyr::pivot_wider(f1, id_cols = year, names_from = series_key, values_from = value)
  wide <- wide[!is.na(wide$underlying_or_contributing), ]
  all(as.numeric(wide$underlying_or_contributing) > as.numeric(wide$underlying))
})

cat("\nFigure TD-1 (cold_deaths_monthly.csv)\n")
check("12 rows", nrow(td1) == 12L)
check("columns as documented",
      identical(names(td1), c("month", "month_num", "measure", "unit", "value")))
check("January = 5534 (highest month)",
      identical(val(td1, month = "January"), "5534") &&
        max(as.integer(td1$value)) == 5534L)
check("August = 276 (lowest month)",
      identical(val(td1, month = "August"), "276") &&
        min(as.integer(td1$value)) == 276L)
check("December = 4554",
      identical(val(td1, month = "December"), "4554"))
check("month_num runs 1:12 in month order",
      identical(as.integer(td1$month_num), 1:12))
check("total across all months = 23352",
      sum(as.integer(td1$value)) == 23352L)
check("winter months (Dec-Feb) account for more than a third of all deaths", {
  winter <- sum(as.integer(td1$value[td1$month %in% c("December", "January", "February")]))
  winter / sum(as.integer(td1$value)) > 1 / 3
})

cat("\nFile hygiene\n")
for (f in list.files("data", full.names = TRUE)) {
  check(sprintf("%s is UTF-8, LF, no BOM, no mojibake", basename(f)),
        tryCatch({ assert_clean_output(f); TRUE }, error = function(e) { cat("      ", conditionMessage(e), "\n"); FALSE }))
}

meta <- yaml::read_yaml("data/meta.yml")
check("meta.yml documents both datasets", length(meta$datasets) == 2L)
check("meta.yml has no timestamp",
      !any(grepl("\\d{4}-\\d{2}-\\d{2}T|Sys\\.time|generated_at",
                 readLines("data/meta.yml", warn = FALSE))))
for (ds in meta$datasets) {
  cols <- vapply(ds$columns, function(x) x$name, character(1))
  actual <- names(rd(ds$file))
  check(sprintf("meta.yml dictionary matches %s columns", ds$file),
        identical(cols, actual))
  check(sprintf("meta.yml row count matches %s", ds$file),
        ds$rows == nrow(rd(ds$file)))
}

cat("\n")
if (length(failures)) {
  cat(sprintf("%d FAILED:\n", length(failures)))
  for (f in failures) cat("  -", f, "\n")
  quit(status = 1L)
}
cat("All data checks passed.\n")

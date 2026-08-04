# Tests for the mechanical chart selector.
#
#   Rscript tests/test-pick-chart.R
#
# This is the indicator-agnostic half of heat-related-deaths' original test
# file: synthetic fixtures only, so it runs unmodified in this template with
# no data-raw/ files present. heat-related-deaths' version additionally
# exercises R/utils/pick_chart.R against its own real figures (built from
# data-raw/heat-deaths_*.csv) — once this indicator's R/build_data.R and
# data-raw/ exist, consider adding the same kind of real-data cases back in.

# Run from the repository root.
stopifnot("run this from the repository root" = dir.exists("R/utils"))

source("R/utils/epa_csv.R")
source("R/utils/pick_chart.R")

pass <- 0L; fail <- 0L
check <- function(what, ok) {
  if (isTRUE(ok)) {
    pass <<- pass + 1L; cat("  ok   ", what, "\n")
  } else {
    fail <<- fail + 1L; cat("  FAIL ", what, "\n")
  }
}

# ---- synthetic edge cases ----------------------------------------------------

cat("\n== synthetic edge cases ==\n")

one <- data.frame(year = 2000:2010, series_key = "a",
                  unit = "u", value = as.character(1:11), stringsAsFactors = FALSE)
s <- pick_chart(one)
check("single series -> no labelling",  s$label_style == "none" && s$n_series == 1L)

cat_x <- data.frame(x = c("North", "South", "East", "West"), series_key = "a",
                    unit = "u", value = c("3", "1", "4", "2"), stringsAsFactors = FALSE)
s <- pick_chart(cat_x)
check("categorical x -> bar",           s$chart == "bar" && s$x_type == "categorical")

many <- do.call(rbind, lapply(letters[1:9], function(k) {
  data.frame(year = 2000:2005, series_key = k, unit = "u",
             value = as.character(1:6), stringsAsFactors = FALSE)
}))
err <- tryCatch({ pick_chart(many); NULL }, error = function(e) conditionMessage(e))
check("9 series -> refuses",            !is.null(err) && grepl("Refusing", err))

six <- do.call(rbind, lapply(letters[1:6], function(k) {
  data.frame(year = 2000:2005, series_key = k, unit = "u",
             value = as.character(1:6), stringsAsFactors = FALSE)
}))
s <- pick_chart(six)
check("6 series -> legend not direct",  s$label_style == "legend")

three_u <- do.call(rbind, lapply(1:3, function(i) {
  data.frame(year = 2000:2005, series_key = paste0("s", i), unit = paste0("u", i),
             value = as.character(1:6), stringsAsFactors = FALSE)
}))
s <- pick_chart(three_u)
check("3 units -> 3 panels",            s$n_panels == 3L && s$layout == "small_multiples")

icd <- data.frame(
  year = c(1997:2000, 1997:2000), series_key = "a", unit = "u",
  value = as.character(1:8), stringsAsFactors = FALSE
)
icd$icd_revision <- ifelse(icd$year < 1999L, "ICD-9", "ICD-10")
s <- pick_chart(icd, partition = "icd_revision")
check("partition suppressible", {
  s2 <- pick_chart(icd, partition = NA)
  is.null(s2$partition) && length(s2$broken) == 0L
})

# ---- real-data cases ---------------------------------------------------------
#
# Now that data/ exists (see R/build_data.R), pick_chart() is exercised
# against this indicator's own two figures, mirroring the synthetic checks
# above but against the actual generated tables rather than fixtures.

if (dir.exists("data") && file.exists("data/cold_deaths_annual.csv")) {
  cat("\n== cold-related-deaths real data ==\n")

  rd <- function(f) {
    readr::read_csv(file.path("data", f),
                    col_types = readr::cols(.default = readr::col_character()),
                    na = character(), progress = FALSE)
  }

  f1 <- rd("cold_deaths_annual.csv")
  s  <- pick_chart(f1, x = "year", series = "series_key", partition = "icd_revision")
  check("Figure 1: line chart",              s$chart == "line")
  check("Figure 1: 2 series",                s$n_series == 2L)
  check("Figure 1: direct labelling",        s$label_style == "direct")
  check("Figure 1: underlying is broken by icd_revision",
        identical(s$broken, "underlying"))
  check("Figure 1: single panel (one unit)", s$layout == "single")

  td1 <- rd("cold_deaths_monthly.csv")
  s2  <- pick_chart(td1, x = "month", series = NULL, partition = NA)
  check("Figure TD-1: bar chart",            s2$chart == "bar")
  check("Figure TD-1: categorical x",        s2$x_type == "categorical")
  check("Figure TD-1: single series",        s2$n_series == 1L)
} else {
  cat("\n(skipping real-data cases: data/ not built yet -- run R/build_data.R)\n")
}

cat(sprintf("\n%d passed, %d failed\n", pass, fail))
if (fail > 0L) quit(status = 1L)

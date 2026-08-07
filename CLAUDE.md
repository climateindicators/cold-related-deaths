# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**This file is the only place project rules live.** Code comments explain the
specific line or block they sit above — why *this* header is asserted, why
*this* value is rounded — and nothing broader. If a comment would apply to more
than one file, it belongs here instead.

## Project Overview

This repository is the **data and narrative pipeline for a single EPA climate
indicator, Cold-Related Deaths**. It takes the raw source files EPA/ERG
produced, in `data-raw/`, and turns them into two products:

1. `data/` — tidy long-format CSVs plus `data/meta.yml`, a machine-readable
   data dictionary
2. `narrative.qmd` — EPA's own published prose, extracted from the source Word
   documents

Both are consumed by the website repository, `../climateindicators.us`
(published at [climateindicators.us](https://climateindicators.us)): `data/` is
fetched off `raw.githubusercontent.com` at render time, and the prose in
`narrative.qmd` was lifted into `indicators/cold-related-deaths.qmd` there.

**This repository is not a website and draws no figures.** All chart code lives
in the site repository, in `R/cold-related-deaths.R`. Nothing here should
produce a plot, a theme, a palette, or an htmlwidget, and nothing here should
be rendered.

Source of the indicator, and the canonical reference for any wording question:
<https://19january2025snapshot.epa.gov/climate-indicators/climate-change-indicators-cold-related-deaths>

The repo was cloned from `heat-related-deaths` with its git history preserved,
so stale heat-specific text can still surface — treat any mention of Figure 2,
race/ethnicity series, or `Suppressed` values as leftover template content, not
as a description of this indicator.

## Common Commands

```sh
Rscript R/build_data.R      # data-raw/*.xlsx -> data/*.csv + data/meta.yml
Rscript R/gen_narrative.R   # data-raw/*.docx -> narrative.qmd
Rscript tests/test-data.R   # regression checks on the generated data
```

There is no test runner and no `testthat`: each file under `tests/` is a
standalone script run with `Rscript` from the repository root, printing
PASS/FAIL lines and exiting non-zero on failure. To run one check, edit or
comment within that script — there is no selector.

`R/build_data.R` never touches the network. Rerunning it with unchanged inputs
must produce byte-identical output.

## Architecture

### Two pipelines, both one-way

**Data.** `data-raw/cold-deaths_figure-1-and-TD1_04-08-19.xlsx` (ERG's internal
workbook, not EPA's public per-figure CSV) → `R/build_data.R` → two tidy CSVs
and `data/meta.yml`. Two figures come out of it:

- `cold_deaths_annual.csv` — Figure 1, the only chart on EPA's published page.
  Two series (`underlying`, 1979–2016; `underlying_or_contributing`,
  1999–2015), crude death rate per million.
- `cold_deaths_monthly.csv` — Figure TD-1, deaths by month 1999–2015. **Not on
  EPA's published page** — it is EPA's own supplementary figure from the
  technical documentation, built here because the workbook carries the data.
  Anything presenting it must say so; see `data-raw/PROVENANCE.md`.

`data/meta.yml` is generated, never hand-edited. It is what the site repository
reads for figure titles, data-source lines, web-update dates, units, and column
descriptions, so a caption on the website cannot drift from the build.

**Narrative.** The source Word documents in `data-raw/` → `R/gen_narrative.R` →
`narrative.qmd`. EPA splits this indicator's prose across two files: the
indicator page text (`cold-deaths_April 2021.docx`) and the technical
documentation (`cold-deaths_TD.docx`), which is where Figure TD-1's own title
and caption live.

**`narrative.qmd` is generated, not hand-edited** — rerunning the generator
overwrites it. A wording problem is fixed in `R/gen_narrative.R`, or it is not
a wording problem but a deliberate editorial change, which belongs on the page
in the site repository. Wording that differs from EPA's docx is a bug here.

### `R/utils/` — shared, indicator-agnostic readers

- `read_docx.R` — parses `word/document.xml` with `xml2` directly. Never
  `officer::docx_summary()`, which leaks deleted text. The published EPA page
  equals the accept-all-tracked-changes rendering of the docx, and this reader
  reproduces exactly that. Raw bytes go to `read_xml()` as a raw vector, never
  through `rawToChar()`, or every curly quote and en dash becomes mojibake.
  Also carries Word endnote markers through as `^rawid^` tokens.
- `write_stable.R` — byte-stable CSV/YAML/lines writers plus
  `assert_clean_output()` and `file_sha256()`.
- `epa_csv.R` — reader for EPA's public per-figure CSV downloads (five-line
  preamble, windows-1252). **Unused by this indicator**, which reads an xlsx
  workbook instead; kept because it is shared across indicator repositories.

Endnote *display* numbering (the 1..14 a reader sees) is derived in
`gen_narrative.R`, not in the shared reader: Word ids need not be contiguous or
start at 1, so numbering follows the order `w:endnoteReference` markers appear
in the body.

### Hard rules

- **`data-raw/` is immutable input.** Files there are reproduced unmodified and
  hashed in `data-raw/PROVENANCE.md`. To update the data, replace the workbook
  and rerun the build.
- **Read source columns by their header cells, never by position.** A renamed
  or reordered column must stop the build rather than silently swap two series.
  `assert_block_header()` in `R/build_data.R` exists for this; Figure 1's two
  side-by-side blocks share the generic headers `Year` / `Crude rate per
  1,000,000`, so an explicit range plus a header assertion is the only defense.
- **Never re-derive a published number outside `R/build_data.R`.** If something
  downstream needs a value `data/` does not carry, add it to the build and
  regenerate, so it is tested and reproducible.
- **Generated output must be byte-identical across reruns and machines.** No
  timestamps in generated files (provenance is the source checksum), no
  locale-dependent sorting (order rows with `match()` against an explicit level
  vector), LF endings and UTF-8 without BOM. `RATE_DECIMALS = 8L` is fixed for
  this reason — values arrive as doubles via `readxl`, so unlike a parsed CSV
  there is no source text precision to preserve.
- **Structural invariants belong in the build; value snapshots belong in the
  tests.** `R/build_data.R` asserts what should survive a data update (headers
  match, series coverage has no gaps, TD-1's monthly totals equal the raw CDC
  pull). `tests/test-data.R` pins the actual numbers, so a legitimate data
  update fails loudly there and tells you exactly what changed.

### Tests

`tests/` holds data-quality checks and nothing else — schema, coverage,
documented invariants, value snapshots, file hygiene (UTF-8/LF/no BOM), and
agreement between `data/meta.yml` and the CSVs it documents.

## History: what this repo used to be

Each indicator was once a standalone Quarto website. That scaffolding has been
removed — `_quarto.yml`, `css/`, `images/`, `404.qmd`, `index.qmd`, the
"Data & Downloads" page `data.qmd`, `R/figures.R`, the chart styling in
`R/_common.R`, and the chart selector `R/utils/pick_chart.R` with its test. If
you find a reference to any of those, it is stale; the figures live in the site
repository now.

Do not reintroduce a rendered page here. The one thing `data.qmd` did that has
no successor is present `data/meta.yml` as a human-readable data dictionary —
if that is wanted again, it belongs on the site, generated from the same
`meta.yml`, not as a second Quarto project in this repo.

## Rights

EPA text, captions, and data are U.S. Government works, not subject to domestic
copyright (17 U.S.C. 105). Code and the derived data schema are CC-BY-SA. This
is an independent project, not affiliated with or endorsed by EPA or CDC. See
`NOTICE.md` and `data-raw/PROVENANCE.md`.

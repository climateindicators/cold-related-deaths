# cold-related-deaths

A rebuild of the U.S. EPA climate indicator **Cold-Related Deaths**, as a
Quarto website: EPA's published text and data, presented with interactive
charts and analysis-ready downloads.

This is a **template repo**, cloned from `heat-related-deaths` with its git
history preserved, then stripped of heat-specific content. Part of the
[climateindicators.us](https://climateindicators.us) project, which rebuilds
the EPA *Climate Change Indicators* preserved in the
[January 19, 2025 snapshot](https://19january2025snapshot.epa.gov/climate-indicators/view-indicators/index.html).

Original page: <https://19january2025snapshot.epa.gov/climate-indicators/climate-change-indicators-cold-related-deaths/index.html>

This indicator's site departs from EPA's published page in one place: Figure
TD-1 (deaths by month) is not on the live indicator page at all — it is
EPA's own supplementary figure from the technical documentation, built here
as a second figure because the source workbook has the data and it shows the
seasonal pattern behind Figure 1's underlying-or-contributing series. See
`data-raw/PROVENANCE.md`.

## Build

R is not assumed to be on `PATH`.

```sh
"C:\Program Files\R\R-4.5.3\bin\Rscript.exe" R/build_data.R    # data-raw/ -> data/
"C:\Program Files\R\R-4.5.3\bin\Rscript.exe" tests/test-data.R # verify
quarto render                                                   # -> _site/
quarto preview                                                  # dev server
```

## Getting started with a new indicator

1. Drop the raw EPA source files into `data-raw/`, and record them in
   `data-raw/PROVENANCE.md`.
2. Rewrite `R/build_data.R`'s "Indicator constants" and series lookup table
   sections for the new data's shape. The rest of the file (helpers, write
   step) is close to mechanical — see the comment at the top of that file.
3. Rewrite `R/figures.R` for however many figures this indicator actually has
   (heat-related-deaths has three; that count is not universal).
4. If the indicator's prose comes from an archived EPA Word doc, adapt
   `R/gen_narrative.R` — point it at the new `.docx`, and use
   `docx_sections()` in `R/utils/read_docx.R` to find this document's
   heading boundaries rather than reusing heat-related-deaths' paragraph
   index ranges, which are specific to that document.
5. Fill in `index.qmd`'s TODOs with the extracted prose, cross-checked
   paragraph by paragraph against the live EPA snapshot page.
6. Update `_quarto.yml`'s `website: title` / `description`, `DESCRIPTION`,
   `NOTICE.md`, and this README's TODOs.
7. Rewrite `tests/test-data.R`'s value snapshots against the new data.
   `tests/test-pick-chart.R`'s synthetic edge-case section (bottom of the
   file) tests `R/utils/pick_chart.R` itself and needs no changes; the
   fixture-based section above it is heat-specific and should be replaced.

Once real data lands, `R/build_data.R` should be deterministic again: rerunning
it with unchanged inputs produces byte-identical output, so a rebuild never
shows up as noise in the diff.

## Layout

| Path | What it is |
|---|---|
| `data-raw/` | EPA's published files, unmodified, plus `PROVENANCE.md` |
| `data/` | Generated tidy long-format CSVs and `meta.yml`; committed |
| `R/utils/` | `epa_csv.R`, `write_stable.R`, `pick_chart.R`, `read_docx.R`; indicator-agnostic, meant for reuse |
| `R/build_data.R` | Indicator-specific: reads `data-raw/`, writes `data/` |
| `R/figures.R` | Indicator-specific: builds the interactive figures for `index.qmd` |
| `R/gen_narrative.R` | Indicator-specific, one-shot: extracts prose from an archived source `.docx` |
| `index.qmd` | The indicator page. EPA's text lives here, not in a Word file. |
| `data.qmd` | Downloads and the full data dictionary — already indicator-agnostic, driven entirely by `data/meta.yml` |
| `tests/` | Structural invariants plus value snapshots |

A page reads `data/` and nothing else. It never opens `data-raw/` and never
touches the network.

## Rights

EPA's text and data are works of the U.S. Government and are not subject to
domestic copyright (17 U.S.C. 105). See `NOTICE.md`. The code in this repository
is CC-BY-SA. This is an independent rebuild, not affiliated with or endorsed by
EPA.

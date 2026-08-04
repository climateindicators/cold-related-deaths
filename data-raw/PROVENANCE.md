# Provenance of raw inputs

Everything in this folder is a work of the U.S. Government prepared by EPA staff
as part of their official duties, and is therefore not subject to domestic
copyright (17 U.S.C. 105). It is reproduced here unmodified.

Indicator page (the canonical source, January 19 2025 snapshot):
<https://19january2025snapshot.epa.gov/climate-indicators/climate-change-indicators-cold-related-deaths>

Technical documentation (PDF, not vendored here):
<https://19january2025snapshot.epa.gov/sites/default/files/2021-04/documents/cold-deaths_td.pdf>

## Files

| File | sha256 | Origin |
|---|---|---|
| `cold-deaths_figure-1-and-TD1_04-08-19.xlsx` | `4751ee5b…943d5` | ERG's internal indicator workbook |

Copied from the local archive at
`…/archive/Excel Files - Indicator Workbooks (for published indicator updates as of 7-23-2026)/Cold-related deaths/`
and verified byte-identical to that copy (both hash to `4751ee5b…943d5`).

This is one level more raw than heat-related-deaths' vendored CSVs: it is
ERG's own internal workbook (data pulls, unit-conversion calculations, and the
two chart sheets), not EPA's public per-figure CSV download. EPA does publish
a public CSV for Figure 1 (`cold-deaths_fig-1.csv`, web-updated April 2021,
at `https://19january2025snapshot.epa.gov/sites/default/files/2021-04/cold-deaths_fig-1.csv`)
and its numbers were checked against this workbook's `Data for Figure 1` sheet
byte for byte (values agree to the public file's own precision, which is 3
decimal places for the underlying-cause column and 9 for the underlying-or-
contributing column — an inconsistency in EPA's own publication, not
introduced here). The workbook was kept as the vendored source, by request,
because `R/build_data.R` reads two of its sheets directly:

- `Data for Figure 1` (annual crude death rate per million, both series) — the
  only figure on the published indicator page.
- `Data for Figure TD-1` (deaths by month, 1999–2015, totalled across the
  period of record) — **not** on the published indicator page. It is EPA's
  own supplementary Figure TD-1, published only in the technical
  documentation (see the PDF above, page 6, and `cold-deaths_TD.docx` below).
  It is built here anyway, as a second figure on this site, because the data
  exists, is genuinely useful (it is the seasonality behind Figure 1's blue
  line — see `R/build_data.R`'s conservation check tying the two together),
  and `R/utils/pick_chart.R` picks a bar chart for it cleanly (categorical
  month axis, single series). Both figures are labelled honestly in
  `index.qmd`: TD-1's block says outright that it is not part of the
  published page.

Six further sheets in the workbook (`Calculations`, `Contributing cause data -
CDC`, `Underlying deaths 1979-1998`, `Underlying deaths 1999-2016`, and the
two chart sheets `Figure 1` / `Figure TD-1`) are ERG's working data behind the
two sheets above. They are reproduced as part of the vendored file but nothing
in `R/build_data.R` reads them; `Data for Figure 1` and `Data for Figure TD-1`
are already the finished, chart-ready numbers.

## Source documents deliberately NOT vendored

The indicator prose was extracted once from these archived Word files, which
live in the local archive and are **not** copied into this repository:

| File | sha256 |
|---|---|
| `cold-deaths_April 2021.docx` | `21c08bd3…7cb190` |
| `cold-deaths_TD.docx` | `d3bccad3…8ec0a4e` |

Reasons they stay out, same as heat-related-deaths: the prose now lives in
`index.qmd`, the artifact the site renders, and a second copy in a binary
format invites the two to disagree; and Word documents of this kind routinely
carry tracked-change and reviewer metadata that is not part of the published
page.

`cold-deaths_April 2021.docx` is the indicator page text: Key Points,
Background, About the Indicator, Indicator Notes, Data Sources, and Figure 1's
own title/caption, plus 14 numbered citations. Unlike heat-related-deaths'
source document, this one cites sources with real Word endnotes
(`w:endnoteReference` + `word/endnotes.xml`), not typed superscript numbers;
`R/utils/read_docx.R` was extended to read those generically, and
`R/gen_narrative.R` derives the 1–14 a reader sees from the order those
markers appear in the body (Word's internal ids are not guaranteed to be
contiguous or to start at 1).

`cold-deaths_TD.docx` is the technical documentation (methodology, data
limitations, QA/QC) — the source of the PDF linked above, and the only place
Figure TD-1's own title, caption, and "Data source: CDC, 2018b" line exist in
EPA's own words. `R/gen_narrative.R` pulls only that one figure block from it;
the rest of the technical documentation is linked, not reproduced, exactly as
heat-related-deaths does.

`R/gen_narrative.R` can regenerate the prose from the archive for anyone who
has it. The checksums above identify the exact revisions used.

## Precision

Values are read from the workbook as IEEE 754 doubles (via `readxl`), not
parsed from formatted text, so there is no source-file decimal precision to
preserve byte for byte the way `R/utils/epa_csv.R` preserves a published CSV's
digits. `R/build_data.R` rounds every rate to 8 decimal places: enough to
exceed CDC WONDER's own stated precision setting (9 decimal places at the
per-100,000 scale, i.e. 8 at the per-million scale this indicator uses — see
the workbook's `Methods and Notes` sheet), so nothing meaningful is lost, and
fixed so reruns are byte-identical.

## Updating the data

Replace the workbook in this folder and rerun `R/build_data.R`. The build
reads `Data for Figure 1` and `Data for Figure TD-1` by their header cells,
not by column position, so a renamed or reordered column stops the build with
a clear error instead of silently mismatching a series. Update the table above
with the new sha256.

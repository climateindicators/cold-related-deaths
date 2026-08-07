# Rights and attribution

## EPA content

The indicator text, figure captions, and underlying data reproduced in this
repository are works of the U.S. Environmental Protection Agency, prepared by
officers or employees of the U.S. Government as part of their official duties.
Under 17 U.S.C. 105 such works are not subject to copyright protection in the
United States.

Source: *Climate Change Indicators in the United States: Cold-Related Deaths*,
U.S. EPA, as preserved in the January 19, 2025 snapshot of epa.gov.

<https://19january2025snapshot.epa.gov/climate-indicators/climate-change-indicators-cold-related-deaths>

The underlying data are from the U.S. Centers for Disease Control and
Prevention (CDC): the CDC WONDER database for the 1979–2016 underlying-cause
series, and CDC's Environmental Public Health Tracking Program for the
1999–2015 underlying-or-contributing-cause series and the supplementary
monthly figure. See the indicator's technical documentation for details.

Files in `data-raw/` are reproduced unmodified. Files in `data/` are
reformatted, not altered: rates are rounded to 8 decimal places, beyond the
source's own meaningful precision (see `data-raw/PROVENANCE.md`). Every
transformation is in `R/build_data.R` and is checked by `tests/test-data.R`.
`narrative.qmd` is EPA's published wording, extracted from the Word documents
in `data-raw/` by `R/gen_narrative.R`.

## This rebuild

Code and the derived data schema are licensed CC-BY-SA.

This is an independent project. It is **not** affiliated with, endorsed by, or
approved by the U.S. Environmental Protection Agency or the U.S. Centers for
Disease Control and Prevention (the underlying data source agency). Where this
project departs from EPA's published presentation — most notably, Figure TD-1
is not part of EPA's published indicator page — those departures are
documented in `data-raw/PROVENANCE.md`.

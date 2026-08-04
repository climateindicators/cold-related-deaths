# Rights and attribution

## EPA content

The indicator text, figure captions, and underlying data reproduced in this
repository are works of the U.S. Environmental Protection Agency, prepared by
officers or employees of the U.S. Government as part of their official duties.
Under 17 U.S.C. 105 such works are not subject to copyright protection in the
United States.

Source: *Climate Change Indicators in the United States: TODO Indicator Name*,
U.S. EPA, as preserved in the January 19, 2025 snapshot of epa.gov.

<TODO: link to this indicator's page on the snapshot>

The underlying data are from TODO (e.g. CDC WONDER, NOAA, etc., as cited by
EPA — check the indicator's technical documentation for the actual source).

Files in `data-raw/` are reproduced unmodified. Files in `data/` are
reformatted, not altered: values are copied across as text, so the source
precision is preserved exactly. Every transformation is in `R/build_data.R` and
is checked against the originals by `tests/test-data.R`.

## This rebuild

Code, site design, and the derived data schema are licensed CC-BY-SA.

This is an independent project. It is **not** affiliated with, endorsed by, or
approved by the U.S. Environmental Protection Agency or TODO (the underlying
data source agency). Where this site departs from EPA's published
presentation, those departures are documented in `README.md` and on the
Data & Downloads page.

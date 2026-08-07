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

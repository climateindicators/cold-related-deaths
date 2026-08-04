# ONE-SHOT generator, not a build step. Extracts EPA's prose from the archived
# source Word documents and writes it to narrative_generated.md for manual
# assembly into index.qmd.
#
#   "C:\Program Files\R\R-4.5.3\bin\Rscript.exe" R/gen_narrative.R
#
# Requires the archive at the paths below (not part of this repo, see
# data-raw/PROVENANCE.md). Once index.qmd is edited and signed off, the docx
# files are out of the loop: index.qmd is the source of truth from then on,
# and rerunning this script does not overwrite it. This script exists so the
# extraction is reproducible and auditable, not so it runs on every build.
#
# Two source documents, not one, because EPA splits this indicator's prose
# across two files: the indicator page text (Key Points, Background, etc.)
# and the technical documentation, which is where Figure TD-1's own title and
# caption live (TD-1 is not on the published indicator page at all -- see
# data-raw/PROVENANCE.md for why this build includes it anyway).
#
# This document cites sources with real Word endnotes (w:endnoteReference),
# not the typed superscript numbers heat-related-deaths' source docx used, so
# R/utils/read_docx.R was extended (not reimplemented here) to carry endnote
# markers through as "^rawid^" tokens and to read word/endnotes.xml via
# docx_endnotes(). What IS indicator-specific, and lives here rather than in
# the shared reader, is turning those raw ids into the 1..14 numbers a reader
# actually sees: Word ids need not be contiguous or start at 1 in general, so
# display numbering is derived from the order w:endnoteReference markers
# actually appear in the body, not from the id column directly.
#
# Cross-checked paragraph by paragraph against the live page (January 2025
# snapshot) and against the technical documentation PDF at the URL in
# R/build_data.R: both matched this docx's wording exactly, so unlike
# heat-related-deaths' extraction, no post-hoc text correction is applied
# here.

source(here::here("R/utils/read_docx.R"))

ARCHIVE_ROOT <- paste0(
  "C:/Users/alyko/Desktop/archive/",
  "Word Files - Indicator Text and TD  (for published indicator updates as of 7-23-2026)/",
  "Cold-related deaths/"
)
ARCHIVE_TEXT_DOCX <- paste0(ARCHIVE_ROOT, "cold-deaths_April 2021.docx")
ARCHIVE_TD_DOCX   <- paste0(ARCHIVE_ROOT, "cold-deaths_TD.docx")

for (p in c(ARCHIVE_TEXT_DOCX, ARCHIVE_TD_DOCX)) {
  if (!file.exists(p)) {
    stop(
      "Archive not found at:\n  ", p,
      "\nThis script is a one-shot generator; see data-raw/PROVENANCE.md.",
      call. = FALSE
    )
  }
}

# ---- Indicator text (cold-deaths_April 2021.docx) ----------------------------

df  <- read_docx_paragraphs(ARCHIVE_TEXT_DOCX)
sec <- docx_sections(df)

get <- function(rng) paste(df$text_md[rng], collapse = "\n\n")

subtitle <- df$text_plain[df$style == "Subtitle"][1]

# Key Points is a bulleted list; the section's raw paragraph range also
# contains the Figure 1 title/caption/source block that Word placed after the
# bullets and before the "Indicator Notes" heading, so bullets are selected by
# style within that range rather than by taking the whole range verbatim.
kp_idx     <- sec[["Key Points"]]
key_points <- df$text_md[kp_idx][df$style[kp_idx] == "Bullet2" & !df$empty[kp_idx]]

background          <- get(sec[["Background"]])
about_the_indicator  <- get(sec[["About the Indicator"]])
indicator_notes      <- get(sec[["Indicator Notes"]])
data_sources         <- get(sec[["Data Sources"]])

# Figure 1's own title/caption/footnote/source line, embedded inside the Key
# Points range (see above) rather than under its own heading. trimws() drops a
# trailing manual line break Word stored inside the Caption paragraph itself.
fig1_idx     <- kp_idx[df$style[kp_idx] %in% c("Caption", "FigureCaption", "SourceText")]
fig1_title   <- trimws(df$text_plain[fig1_idx][df$style[fig1_idx] == "Caption"])
fig1_caption <- paste(df$text_md[fig1_idx][df$style[fig1_idx] == "FigureCaption"], collapse = "\n\n")
# SourceText, not text_plain: this line carries its own endnote markers
# ("^13,14^"), and text_plain strips the caret markup that keeps them visible.
fig1_source  <- trimws(df$text_md[fig1_idx][df$style[fig1_idx] == "SourceText"])

# ---- References: raw endnote ids -> the 1..14 a reader actually sees --------

body_doc <- docx_body_xml(ARCHIVE_TEXT_DOCX)
appearance_ids <- unique(xml2::xml_attr(
  xml2::xml_find_all(body_doc, "//w:endnoteReference"), "id"
))
ref_map <- stats::setNames(seq_along(appearance_ids), appearance_ids)

# Body superscript reference markers carry raw docx ids, e.g. "^3,4^" is ids
# 3 and 4; remap each to its display number and to a "[N](#ref-N)" link,
# preserving the comma-joined shape for markers that cite more than one
# source in the same spot.
remap_refs <- function(x) {
  m <- gregexpr("\\^[0-9,]+\\^", x)
  regmatches(x, m) <- lapply(regmatches(x, m), function(hits) {
    vapply(hits, function(h) {
      raw_ids <- strsplit(sub("^\\^", "", sub("\\^$", "", h)), ",")[[1]]
      nums <- unname(ref_map[raw_ids])
      if (anyNA(nums)) stop("Unmapped endnote id in marker: ", h, call. = FALSE)
      paste0("^", paste0("[", nums, "](#ref-", nums, ")", collapse = ","), "^")
    }, character(1))
  })
  x
}
background           <- remap_refs(background)
about_the_indicator   <- remap_refs(about_the_indicator)
key_points            <- remap_refs(key_points)
indicator_notes       <- remap_refs(indicator_notes)
data_sources          <- remap_refs(data_sources)
fig1_source           <- remap_refs(fig1_source)

endnotes <- docx_endnotes(ARCHIVE_TEXT_DOCX)
ordered  <- endnotes[match(appearance_ids, endnotes$id), ]
stopifnot(
  "every referenced endnote id must exist in word/endnotes.xml" = !anyNA(ordered$id)
)
references_html <- paste0(
  '<ol class="references">\n',
  paste0('  <li id="ref-', seq_along(ordered$text_md), '">', ordered$text_md, "</li>", collapse = "\n"),
  "\n</ol>"
)

# ---- Figure TD-1 (cold-deaths_TD.docx) ---------------------------------------
#
# Not on the published indicator page (see data-raw/PROVENANCE.md); this is
# the technical documentation's own title/caption/source for it, extracted so
# index.qmd's TD-1 block can carry EPA's real wording rather than an invented
# caption.

td_df <- read_docx_paragraphs(ARCHIVE_TD_DOCX)
td1_title_i <- td_df$i[grepl("^Figure TD-1", td_df$text_md)][1]
stopifnot("Figure TD-1 title paragraph not found in TD docx" = !is.na(td1_title_i))
td1_title   <- td_df$text_plain[td1_title_i]
td1_caption <- td_df$text_md[td1_title_i + 2L]
td1_source  <- td_df$text_plain[td1_title_i + 3L]

# ---- Write --------------------------------------------------------------------

out <- c(
  "<!-- Generated by R/gen_narrative.R from the archived source docx files.",
  "     This is a one-shot output for hand-assembly into index.qmd, not",
  "     itself rendered. -->",
  "",
  "## Subtitle", "",
  subtitle, "",
  "## Key Points", "",
  paste0("- ", key_points, collapse = "\n\n"), "",
  "## Background", "",
  background, "",
  "## About the Indicator", "",
  about_the_indicator, "",
  "## Indicator Notes", "",
  indicator_notes, "",
  "## Data Sources", "",
  data_sources, "",
  "## References", "",
  references_html, "",
  "## Figure 1 (title / caption / source)", "",
  paste0("**", fig1_title, "**"), "",
  fig1_caption, "",
  fig1_source, "",
  "## Figure TD-1 (title / caption / source)", "",
  paste0("**", td1_title, "**"), "",
  td1_caption, "",
  td1_source, ""
)

writeLines(out, here::here("narrative_generated.md"), useBytes = TRUE)
cat("Wrote narrative_generated.md,", length(out), "lines.\n")
cat("References:", length(ordered$text_md), "\n")

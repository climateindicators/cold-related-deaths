# Extract EPA's published prose for the Cold-Related Deaths indicator and write
# it to narrative.qmd.
#
#   Rscript R/gen_narrative.R
#
# Two source documents, not one, because EPA splits this indicator's prose
# across two files: the indicator page text (Key Points, Background, etc.) and
# the technical documentation, which is where Figure TD-1's own title and
# caption live. See CLAUDE.md for the rules this file follows.

root <- here::here()
source(file.path(root, "R", "utils", "read_docx.R"))
source(file.path(root, "R", "utils", "write_stable.R"))

raw_dir   <- file.path(root, "data-raw")
TEXT_DOCX <- file.path(raw_dir, "cold-deaths_April 2021.docx")
TD_DOCX   <- file.path(raw_dir, "cold-deaths_TD.docx")
OUT_QMD   <- file.path(root, "narrative.qmd")

for (p in c(TEXT_DOCX, TD_DOCX)) {
  if (!file.exists(p)) {
    stop("Source document not found: ", p, call. = FALSE)
  }
}

# ---- Indicator text (cold-deaths_April 2021.docx) ----------------------------

df  <- read_docx_paragraphs(TEXT_DOCX)
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
about_the_indicator <- get(sec[["About the Indicator"]])
indicator_notes     <- get(sec[["Indicator Notes"]])
data_sources        <- get(sec[["Data Sources"]])

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
#
# Word ids need not be contiguous or start at 1, so display numbering is
# derived from the order w:endnoteReference markers appear in the body, not
# from the id column directly.

body_doc <- docx_body_xml(TEXT_DOCX)
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
background          <- remap_refs(background)
about_the_indicator <- remap_refs(about_the_indicator)
key_points          <- remap_refs(key_points)
indicator_notes     <- remap_refs(indicator_notes)
data_sources        <- remap_refs(data_sources)
fig1_source         <- remap_refs(fig1_source)

endnotes <- docx_endnotes(TEXT_DOCX)
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
# TD-1 is not on the published indicator page (see data-raw/PROVENANCE.md).
# This is the technical documentation's own title/caption/source for it, so
# anything presenting the figure can carry EPA's real wording rather than an
# invented caption.

td_df <- read_docx_paragraphs(TD_DOCX)
td1_title_i <- td_df$i[grepl("^Figure TD-1", td_df$text_md)][1]
stopifnot("Figure TD-1 title paragraph not found in TD docx" = !is.na(td1_title_i))
td1_title   <- td_df$text_plain[td1_title_i]
td1_caption <- td_df$text_md[td1_title_i + 2L]
td1_source  <- td_df$text_plain[td1_title_i + 3L]

# ---- Write --------------------------------------------------------------------

out <- c(
  "---",
  'title: "Cold-Related Deaths"',
  paste0('subtitle: "', subtitle, '"'),
  "---",
  "",
  "<!-- Generated by R/gen_narrative.R from the Word documents in data-raw/.",
  "     Do not edit by hand: rerunning the generator overwrites this file. -->",
  "",
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
  "## Figure 1", "",
  paste0("**", fig1_title, "**"), "",
  fig1_caption, "",
  fig1_source, "",
  "## Figure TD-1", "",
  paste0("**", td1_title, "**"), "",
  td1_caption, "",
  td1_source, "",
  "## References", "",
  references_html, ""
)

write_lines_stable(out, OUT_QMD)
assert_clean_output(OUT_QMD)

cat("Wrote", basename(OUT_QMD), "-", length(out), "lines,",
    length(ordered$text_md), "references.\n")

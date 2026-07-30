#!/usr/bin/env python3
"""
Competitor Landscape Slide Deck Generator
Uses python-pptx to create polished Lilly-branded presentations.

Design: White background, plain text boxes (no card panels, no footer bar).
Figures folder: All images (BNMA plots, press release pages) go in figures/

Generated: 2026-07-29
Target: Zumilokibart (APG777) — APEX Phase 2 Part B in Atopic Dermatitis
Mode: Detailed presenter deck
"""

import os
import sys
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE

# ═══════════════════════════════════════════════════════════════════
# PATHS
# ═══════════════════════════════════════════════════════════════════

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIGURES_DIR = os.path.join(BASE_DIR, "figures")

# ═══════════════════════════════════════════════════════════════════
# DESIGN SYSTEM CONSTANTS (13.33 × 7.50 widescreen)
# ═══════════════════════════════════════════════════════════════════

PRIMARY_COLOR = RGBColor(0xE1, 0x25, 0x1B)       # Lilly Red 2024
DARK_TEXT = RGBColor(0x21, 0x21, 0x21)            # Dark gray body text
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
ACCENT_GOLD = RGBColor(0xFF, 0xC7, 0x09)          # Gold for highlights
SECTION_HEADER_COLOR = RGBColor(0xC8, 0x10, 0x2E) # Lilly Red for section headers
CAVEAT_COLOR = RGBColor(0x66, 0x66, 0x66)         # Medium gray for footnotes

HEADER_FONT = "Arial"
BODY_FONT = "Arial"

# Slide dimensions (widescreen 16:9)
SLIDE_WIDTH = Inches(13.33)
SLIDE_HEIGHT = Inches(7.50)


# ═══════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════

def set_slide_bg(slide, color):
    bg = slide.background
    fill = bg.fill
    fill.solid()
    fill.fore_color.rgb = color


def add_text_box(slide, left, top, width, height, text, font_size=11,
                 font_name=None, color=None, bold=False, italic=False,
                 align=PP_ALIGN.LEFT, valign=MSO_ANCHOR.TOP):
    font_name = font_name or BODY_FONT
    color = color or DARK_TEXT
    txBox = slide.shapes.add_textbox(left, top, width, height)
    tf = txBox.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = valign
    p = tf.paragraphs[0]
    p.text = text
    p.font.size = Pt(font_size)
    p.font.name = font_name
    p.font.color.rgb = color
    p.font.bold = bold
    p.font.italic = italic
    p.alignment = align
    return txBox


def add_section_bullets(slide, left, top, width, height, header, bullets,
                        header_size=16, bullet_size=13, header_color=None,
                        bullet_color=None):
    """Add a section header followed by bullet points — plain text, no card."""
    header_color = header_color or SECTION_HEADER_COLOR
    bullet_color = bullet_color or DARK_TEXT
    txBox = slide.shapes.add_textbox(left, top, width, height)
    tf = txBox.text_frame
    tf.word_wrap = True

    # Header
    p = tf.paragraphs[0]
    p.text = header
    p.font.size = Pt(header_size)
    p.font.name = HEADER_FONT
    p.font.color.rgb = header_color
    p.font.bold = True
    p.space_after = Pt(6)

    # Bullets
    for bullet in bullets:
        p = tf.add_paragraph()
        p.text = f"• {bullet}"
        p.font.size = Pt(bullet_size)
        p.font.name = BODY_FONT
        p.font.color.rgb = bullet_color
        p.level = 0
        p.space_after = Pt(4)


def add_top_bar(slide, title):
    """Simple top bar with primary color and white title text."""
    shape = slide.shapes.add_shape(
        MSO_SHAPE.RECTANGLE, Inches(0), Inches(0), SLIDE_WIDTH, Inches(1.0)
    )
    shape.fill.solid()
    shape.fill.fore_color.rgb = PRIMARY_COLOR
    shape.line.fill.background()

    txBox = slide.shapes.add_textbox(Inches(0.6), Inches(0.05), Inches(12), Inches(0.9))
    tf = txBox.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    p = tf.paragraphs[0]
    p.text = title
    p.font.size = Pt(26)
    p.font.name = HEADER_FONT
    p.font.color.rgb = WHITE
    p.font.bold = True


def add_disclaimer(slide, text=None):
    """Small disclaimer text at the bottom — no bar, just text."""
    text = text or "Review is required before disclosure."
    add_text_box(slide, Inches(0.5), Inches(7.0), Inches(12), Inches(0.4),
                 text, font_size=8.5, color=CAVEAT_COLOR, italic=True)


def add_speaker_notes(slide, notes_text):
    notes_slide = slide.notes_slide
    notes_slide.notes_text_frame.text = notes_text


def add_image_safe(slide, path, left, top, width=None, height=None):
    """Add image, print warning if missing."""
    if not os.path.exists(path):
        print(f"  Warning: Image not found: {path}", file=sys.stderr)
        add_text_box(slide, left, top, Inches(6), Inches(1),
                     f"[Image not found: {os.path.basename(path)}]",
                     font_size=12, color=CAVEAT_COLOR)
        return None
    kwargs = {"left": left, "top": top}
    if width:
        kwargs["width"] = width
    if height:
        kwargs["height"] = height
    return slide.shapes.add_picture(path, **kwargs)


# ═══════════════════════════════════════════════════════════════════
# SLIDE BUILDERS
# ═══════════════════════════════════════════════════════════════════

def build_title_slide(prs, data):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_slide_bg(slide, PRIMARY_COLOR)
    add_text_box(slide, Inches(1.3), Inches(1.8), Inches(10.7), Inches(2.0),
                 data["title"], font_size=36, font_name=HEADER_FONT,
                 color=WHITE, bold=True, align=PP_ALIGN.CENTER,
                 valign=MSO_ANCHOR.MIDDLE)
    add_text_box(slide, Inches(1.3), Inches(3.9), Inches(10.7), Inches(1.0),
                 data["subtitle"], font_size=18, font_name=BODY_FONT,
                 color=RGBColor(0xF5, 0xD6, 0xB0), align=PP_ALIGN.CENTER)
    add_text_box(slide, Inches(1.3), Inches(5.2), Inches(10.7), Inches(1.0),
                 data["date"] + "\nCONFIDENTIAL — For Internal Use Only",
                 font_size=12, font_name=BODY_FONT, color=WHITE,
                 align=PP_ALIGN.CENTER)
    add_text_box(slide, Inches(1.3), Inches(6.5), Inches(10.7), Inches(0.5),
                 "Review is required before disclosure.",
                 font_size=9, font_name=BODY_FONT,
                 color=RGBColor(0xF5, 0xD6, 0xB0),
                 italic=True, align=PP_ALIGN.CENTER)
    add_speaker_notes(slide, data.get("speakerNotes", ""))


def build_content_slide(prs, data):
    """Content slide with multiple sections — white bg, plain text.
    Optionally embeds an image below the sections if 'imagePath' is provided."""
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_slide_bg(slide, WHITE)
    add_top_bar(slide, data["title"])

    for section in data["sections"]:
        x = section.get("x", 0.5)
        y = section.get("y", 1.2)
        w = section.get("w", 12.3)
        h = section.get("h", 2.0)
        add_section_bullets(slide, Inches(x), Inches(y), Inches(w), Inches(h),
                            section["header"], section["bullets"],
                            header_size=section.get("headerSize", 16),
                            bullet_size=section.get("bulletSize", 13))

    # Optional embedded image (e.g., study design figure below text)
    if "imagePath" in data and data["imagePath"]:
        pos = data.get("imagePosition", {"x": 0.5, "y": 3.5, "w": 12.3, "h": 3.5})
        add_image_safe(slide, data["imagePath"],
                       Inches(pos["x"]), Inches(pos["y"]),
                       width=Inches(pos["w"]), height=Inches(pos["h"]))

    add_disclaimer(slide, data.get("disclaimer"))
    add_speaker_notes(slide, data.get("speakerNotes", ""))


def build_image_slide(prs, data):
    """Embed an image (press release figure, study design, etc.)."""
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_slide_bg(slide, WHITE)
    add_top_bar(slide, data["title"])
    image_path = data.get("imagePath", "")
    add_image_safe(slide, image_path,
                   Inches(0.4), Inches(1.15),
                   width=Inches(12.5), height=Inches(5.6))
    add_disclaimer(slide, data.get("disclaimer"))
    add_speaker_notes(slide, data.get("speakerNotes", ""))


def build_bnma_slide(prs, data):
    """Key findings on left + BNMA plot on right."""
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_slide_bg(slide, WHITE)
    add_top_bar(slide, data["title"])

    # Interpretation bullets on left
    add_section_bullets(slide, Inches(0.5), Inches(1.2), Inches(4.5), Inches(5.5),
                        "Key Findings", data.get("interpretation", []),
                        header_size=16, bullet_size=13)

    # BNMA image on right
    image_path = data.get("imagePath", "")
    add_image_safe(slide, image_path,
                   Inches(5.2), Inches(1.2),
                   width=Inches(7.8), height=Inches(5.5))

    add_disclaimer(slide, "Random-effects BNMA; indirect comparison only. Review is required before disclosure.")
    add_speaker_notes(slide, data.get("speakerNotes", ""))


def build_two_column_slide(prs, data):
    """Two-column layout — left text + right text OR right image."""
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_slide_bg(slide, WHITE)
    add_top_bar(slide, data["title"])

    # Left column (always text)
    left = data.get("leftColumn", {})
    if left:
        add_section_bullets(slide, Inches(0.5), Inches(1.2), Inches(5.8), Inches(5.5),
                            left["header"], left["bullets"],
                            header_size=16, bullet_size=13)

    # Right side: either image or text column
    if "rightImage" in data and data["rightImage"]:
        add_image_safe(slide, data["rightImage"],
                       Inches(6.5), Inches(1.2),
                       width=Inches(6.5), height=Inches(5.5))
    elif "rightColumn" in data:
        right = data["rightColumn"]
        add_section_bullets(slide, Inches(6.8), Inches(1.2), Inches(5.8), Inches(5.5),
                            right["header"], right["bullets"],
                            header_size=16, bullet_size=13)

    add_disclaimer(slide, data.get("disclaimer"))
    add_speaker_notes(slide, data.get("speakerNotes", ""))


def build_summary_slide(prs, data):
    """Key takeaways — white background with bullet points."""
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_slide_bg(slide, WHITE)
    add_top_bar(slide, data["title"] if "title" in data else "Key Takeaways")

    takeaways = data.get("takeaways", [])
    takeaway_text = "\n".join(f"• {t}" for t in takeaways)
    add_text_box(slide, Inches(0.8), Inches(1.3), Inches(11.5), Inches(3.2),
                 takeaway_text, font_size=13, font_name=BODY_FONT, color=DARK_TEXT)

    actions = data.get("actions", [])
    if actions:
        add_text_box(slide, Inches(0.8), Inches(4.7), Inches(11.5), Inches(0.5),
                     "Recommended Actions", font_size=16, font_name=HEADER_FONT,
                     color=SECTION_HEADER_COLOR, bold=True)
        actions_text = "\n".join(f"• {a}" for a in actions)
        add_text_box(slide, Inches(0.8), Inches(5.3), Inches(11.5), Inches(1.8),
                     actions_text, font_size=13, font_name=BODY_FONT, color=DARK_TEXT)

    add_speaker_notes(slide, data.get("speakerNotes", ""))


def build_table_slide(prs, data):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_slide_bg(slide, WHITE)
    add_top_bar(slide, data["title"])
    table_data = data.get("table", {})
    headers = table_data.get("headers", [])
    rows = table_data.get("rows", [])
    if headers:
        num_rows = len(rows) + 1
        num_cols = len(headers)
        tbl = slide.shapes.add_table(
            num_rows, num_cols,
            Inches(0.4), Inches(1.3), Inches(12.5), Inches(5.5)
        ).table
        for i, h in enumerate(headers):
            cell = tbl.cell(0, i)
            cell.text = h
            cell.fill.solid()
            cell.fill.fore_color.rgb = PRIMARY_COLOR
            p = cell.text_frame.paragraphs[0]
            p.font.size = Pt(10)
            p.font.name = BODY_FONT
            p.font.color.rgb = WHITE
            p.font.bold = True
        for r_idx, row in enumerate(rows):
            for c_idx, val in enumerate(row):
                cell = tbl.cell(r_idx + 1, c_idx)
                cell.text = str(val)
                p = cell.text_frame.paragraphs[0]
                p.font.size = Pt(9.5)
                p.font.name = BODY_FONT
                p.font.color.rgb = DARK_TEXT
                if r_idx % 2 == 1:
                    cell.fill.solid()
                    cell.fill.fore_color.rgb = RGBColor(0xF5, 0xF5, 0xF5)
    add_disclaimer(slide, data.get("disclaimer"))
    add_speaker_notes(slide, data.get("speakerNotes", ""))




# ═══════════════════════════════════════════════════════════════════
# CONFIG LOADING
# ═══════════════════════════════════════════════════════════════════

import json


def load_config(config_path):
    """Load slide deck configuration from a JSON file.

    Image paths in the JSON should be relative to the project root
    (e.g., "figures/page-10.png"). They are resolved to absolute paths here.
    """
    with open(config_path, 'r') as f:
        config = json.load(f)

    # Resolve relative image paths to absolute paths
    for slide in config.get("slides", []):
        for key in ("imagePath", "rightImage"):
            if key in slide and slide[key] and not os.path.isabs(slide[key]):
                slide[key] = os.path.join(BASE_DIR, slide[key])

    return config


# ═══════════════════════════════════════════════════════════════════
# BUILD DECK
# ═══════════════════════════════════════════════════════════════════

BUILDERS = {
    "title": build_title_slide,
    "content": build_content_slide,
    "image": build_image_slide,
    "bnma": build_bnma_slide,
    "twoColumn": build_two_column_slide,
    "summary": build_summary_slide,
    "table": build_table_slide,
}


def main():
    # Load config: from CLI argument (JSON file) or print usage
    if len(sys.argv) > 1:
        config_path = sys.argv[1]
        if not os.path.isabs(config_path):
            config_path = os.path.join(BASE_DIR, config_path)
        if not os.path.exists(config_path):
            print(f"Error: Config file not found: {config_path}", file=sys.stderr)
            sys.exit(1)
        data = load_config(config_path)
    else:
        print("Usage: python3 scripts/generate_deck.py <config.json>")
        print()
        print("Examples:")
        print("  python3 scripts/generate_deck.py configs/zumilokibart_apex_2026-07-29.json")
        print("  python3 scripts/generate_deck.py configs/envudeucitinib_zasocitinib_pso_2026-07-29.json")
        print()
        # List available configs
        configs_dir = os.path.join(BASE_DIR, "configs")
        if os.path.isdir(configs_dir):
            configs = [f for f in os.listdir(configs_dir) if f.endswith('.json')]
            if configs:
                print("Available configs:")
                for c in sorted(configs):
                    print(f"  configs/{c}")
        sys.exit(0)

    # Build the presentation
    prs = Presentation()
    prs.slide_width = SLIDE_WIDTH
    prs.slide_height = SLIDE_HEIGHT

    for slide_data in data["slides"]:
        builder = BUILDERS.get(slide_data["type"])
        if builder:
            builder(prs, slide_data)
        else:
            print(f"Warning: Unknown slide type '{slide_data['type']}'", file=sys.stderr)

    output_file = os.path.join(BASE_DIR, data["outputFile"])
    prs.save(output_file)

    print(f"✓ Saved: {output_file}")
    print(f"  Mode: {data['mode']}")
    print(f"  Slides: {len(data['slides'])}")
    bnma_count = sum(1 for s in data["slides"] if s["type"] == "bnma")
    image_count = sum(1 for s in data["slides"] if s["type"] == "image")
    if image_count > 0:
        print(f"  Press release figures embedded: {image_count}")
    if bnma_count > 0:
        print(f"  BNMA plots embedded: {bnma_count}")


if __name__ == "__main__":
    main()

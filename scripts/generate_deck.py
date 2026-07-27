#!/usr/bin/env python3
"""
Competitor Landscape Slide Deck Generator
Uses python-pptx to create polished Lilly-branded presentations.

Design: White background, plain text boxes (no card panels, no footer bar).
Figures folder: All images (BNMA plots, press release pages) go in figures/

Generated: 2026-07-26
Target: Zumilokibart (APG777) — APEX Phase 2 Part B in Atopic Dermatitis
Mode: Quick 5-slide deck
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
# DATA — Zumilokibart (APG777) APEX Phase 2 Part B | Detailed Mode
# ═══════════════════════════════════════════════════════════════════

DATA = {
    "mode": "detailed",
    "outputFile": "Zumilokibart_APG777_APEX_PartB_Detailed_2026-07-26.pptx",
    "slides": [
        # ─── Slide 1: Title ───
        {
            "type": "title",
            "title": "Competitor Landscape Update:\nZumilokibart (APG777)",
            "subtitle": "Atopic Dermatitis — APEX Phase 2 Part B 16-Week Data",
            "date": "July 2026",
            "speakerNotes": "This deck summarizes the APEX Phase 2 Part B 16-week topline data for zumilokibart (APG777), presented by Apogee Therapeutics on May 27, 2026. Zumilokibart is a next-generation anti-IL-13 antibody with an extended half-life enabling Q12W–Q24W dosing. This readout supports Phase 3 (ADventure) initiation in 2H 2026 with a planned 2029 launch."
        },

        # ─── Slide 2: Drug Overview ───
        {
            "type": "content",
            "title": "Drug Overview: Zumilokibart (APG777)",
            "sections": [
                {
                    "header": "Drug Profile",
                    "bullets": [
                        "Generic: zumilokibart | Code: APG777",
                        "Sponsor: Apogee Therapeutics (founded 2022; Blackstone commercialization deal)",
                        "Modality: Anti-IL-13 monoclonal antibody (YTE half-life extension)",
                        "Target: IL-13 (same target as lebrikizumab & tralokinumab)",
                        "Route: Subcutaneous injection",
                        "Dosing: 4 loading injections (W0, W2, W4, W12) then Q12W or Q24W maintenance",
                        "Phase: Phase 2 Part B complete; Phase 3 (ADventure) planned 2H 2026",
                        "Planned launch: 2029"
                    ],
                    "x": 0.5, "y": 1.15, "w": 12.3, "h": 5.5
                }
            ],
            "speakerNotes": "Zumilokibart is Apogee Therapeutics' lead asset. It targets IL-13 — the same cytokine as lebrikizumab (Ebglyss) and tralokinumab (Adbry). The key differentiator is the YTE Fc modification that extends the half-life, enabling much less frequent dosing (Q12W or Q24W maintenance vs Q2W for dupilumab/lebrikizumab). Apogee was founded in 2022, has a Blackstone financing deal for commercialization. Also developing APG273 (anti-TSLP). NCT05964504."
        },

        # ─── Slide 3: Mechanism of Action ───
        {
            "type": "content",
            "title": "Mechanism of Action & Differentiation",
            "sections": [
                {
                    "header": "IL-13 Pathway Blockade",
                    "bullets": [
                        "Binds and neutralizes IL-13, a key Type 2 cytokine",
                        "IL-13 drives epidermal barrier disruption, itch, and fibrosis",
                        "Does NOT block IL-4 (unlike dupilumab which is IL-4Rα)",
                        "Same target as lebrikizumab and tralokinumab",
                        "IL-13-selective → may have cleaner safety (less infection risk)"
                    ],
                    "x": 0.5, "y": 1.15, "w": 12.3, "h": 2.2
                },
                {
                    "header": "Key Differentiators (YTE Fc Extension)",
                    "bullets": [
                        "YTE Fc extension: ~4x longer half-life vs standard IgG",
                        "Only 4 dosing days in 16-week induction (vs 9 for dupilumab)",
                        "Maintenance: 2–4 annual dosing days (vs 26 for dupilumab, 13–26 for lebrikizumab)",
                        "Potential for Q24W (every 6 months) dosing",
                        "Could be first AD biologic with Q3M + Q6M options"
                    ],
                    "x": 0.5, "y": 3.5, "w": 12.3, "h": 2.2
                }
            ],
            "speakerNotes": "The YTE modification (M252Y/S254T/T256E in the Fc region) increases FcRn binding affinity and extends serum half-life. For lebrikizumab, dosing is Q2W induction then Q2W or Q4W maintenance. Zumilokibart's dosing convenience advantage is substantial: 2-4 annual injections vs 26 for dupilumab. However, all IL-13 agents carry conjunctivitis risk. The question is whether efficacy is maintained at these extended intervals."
        },

        # ─── Slide 4: Study Design (text + figure) ───
        {
            "type": "twoColumn",
            "title": "APEX Part B — Study Design",
            "leftColumn": {
                "header": "Trial Overview",
                "bullets": [
                    "Phase 2, randomized, double-blind, PBO-controlled",
                    "N=346 (mITT): Low (N=86), Mid (N=85), High (N=87), PBO (N=88)",
                    "Randomized 1:1:1:1",
                    "Moderate-to-severe AD (EASI ≥16, vIGA ≥3, BSA ≥10%)",
                    "Dosing: SC at W0, W2, W4, W12",
                    "Maintenance: Q12W or Q24W",
                    "Primary: EASI-75 at Wk16",
                    "Estimand: MCMC-MI",
                    "Baseline: EASI ~26, age ~37y, BSA ~40%"
                ]
            },
            "rightImage": os.path.join(FIGURES_DIR, "page-10.png"),
            "disclaimer": "Source: Apogee Therapeutics APEX Part B presentation, May 2026. Review is required before disclosure.",
            "speakerNotes": "STUDY DESIGN:\n- 347 patients randomized but 1 not dosed → 346 mITT population\n- Mid dose is the planned Phase 3 dose (same as Part A)\n- Primary analysis: Markov Chain Monte Carlo Multiple Imputation (MCMC-MI)\n- Rescue medication or discontinuation for lack of efficacy = non-responder\n\nBASELINE (Mid dose): Age 39.9y, Female 52.9%, Weight 76.4kg, EASI 26.0, vIGA(4) 36.5%, I-NRS 7.0, BSA 40.0%"
        },

        # ─── Slide 5: Key Efficacy Results ───
        {
            "type": "content",
            "title": "Key Efficacy Results at Week 16",
            "sections": [
                {
                    "header": "Primary Endpoint — Mid Dose (Planned Phase 3 Dose, N=85)",
                    "bullets": [
                        "EASI-75 (primary): 65.9% vs 23.4% PBO (Δ=41.9; p<0.001)",
                        "IGA 0/1: 46.0% vs 10.9% PBO (Δ=34.8; p<0.001)",
                        "EASI-90: 47.4% vs 9.3% PBO (Δ=37.8; p<0.001)",
                        "I-NRS ≥4 (itch): 50.5% vs 13.9% PBO (Δ=36.7; p<0.001)",
                        "EASI-100: 16.5% vs 3.4% PBO (p<0.01)"
                    ],
                    "x": 0.5, "y": 1.15, "w": 12.3, "h": 2.2
                },
                {
                    "header": "Dose-Response & Key Observations",
                    "bullets": [
                        "Mid & High doses showed similar clinical activity throughout",
                        "Low dose showed relatively lower but still significant activity",
                        "Rapid onset: significant EASI reduction by Week 1; EASI-75 significant by Week 2",
                        "Part B results generally similar to Part A (confirming dose selection)",
                        "Placebo rate 23.4% — higher than historical AD trials (10–15%); Δ is more reliable for cross-trial comparison"
                    ],
                    "x": 0.5, "y": 3.5, "w": 12.3, "h": 2.2
                }
            ],
            "disclaimer": "Review is required before disclosure.",
            "speakerNotes": "KEY RESULTS (all arms at Wk16):\n- EASI-75: Low 52.3%, Mid 65.9%, High 63.2%, PBO 23.4%\n- IGA 0/1: Low 31.4%, Mid 46.0%, High 42.5%, PBO 10.9%\n- EASI-90: Low 33.7%, Mid 47.4%, High 44.8%, PBO 9.3%\n- I-NRS4: Low 37.2%, Mid 50.5%, High 50.6%, PBO 13.9%\n\nNOTE: 65.9% EASI-75 is notably high for Phase 2 (N=85). Placebo rate (23.4%) higher than SOLO (12.7%), ADVOCATE (15.3%). Treatment difference (Δ=41.9) is the most reliable cross-trial metric."
        },

        # ─── Slide 6: Efficacy Over Time (press release figure) ───
        {
            "type": "image",
            "title": "EASI-75 Response Over Time — All Arms",
            "imagePath": os.path.join(FIGURES_DIR, "page-14.png"),
            "disclaimer": "Source: Apogee Therapeutics. Review is required before disclosure.",
            "speakerNotes": "EASI-75 TIME COURSE:\n- Significance achieved for all treatment arms by Week 2\n- Mid dose: 12.2% at Wk1, 35.6% at Wk4, 52.6% at Wk8, 59.7% at Wk12, 65.9% at Wk16\n- High dose tracks similarly to mid dose throughout\n- Continuous improvement suggests potential for further gains beyond Wk16\n- Part A 52-week data showed continued improvement"
        },

        # ─── Slide 7: Competitive Landscape (press release figure) ───
        {
            "type": "image",
            "title": "Competitive EASI-75 & IGA 0/1 at Week 16",
            "imagePath": os.path.join(FIGURES_DIR, "page-08.png"),
            "disclaimer": "Cross-trial comparison only. Different populations, imputation methods. Review is required before disclosure.",
            "speakerNotes": "COMPETITIVE PROFILE (from Apogee press release):\nZumilokibart Mid Dose (N=85) vs DUPIXENT (N=521):\n- EASI-75: 65.9 vs 49.5 (Δ from PBO: 41.9 vs 36.8)\n- IGA 0/1: 46.0 vs 34.6 (Δ: 34.8 vs 27.8)\n- EASI-90: 47.4 vs 31.8 (Δ: 37.8 vs 25.8)\n- I-NRS4: 50.5 vs 38.4 (Δ: 36.7 vs 27.5)\n\nCAVEATS: Cross-trial only. Zumilokibart PBO 23.4% vs DUPIXENT PBO 12.7% (SOLO). Small N (85) inflates variability."
        },

        # ─── Slide 8: Safety ───
        {
            "type": "content",
            "title": "Safety Summary — Through Week 16",
            "sections": [
                {
                    "header": "Overall Safety (Mid Dose vs Placebo)",
                    "bullets": [
                        "≥1 TEAE: 60.0% vs 67.0% PBO — lower than placebo",
                        "Serious TEAE: 1.2% vs 2.3% PBO",
                        "Discontinued due to TEAE: 2.4% vs 2.3% PBO",
                        "Most common: nasopharyngitis (14.1%), headache (7.1%)",
                        "No effect of ADAs on PK, efficacy, or safety"
                    ],
                    "x": 0.5, "y": 1.15, "w": 12.3, "h": 2.0
                },
                {
                    "header": "Conjunctivitis (Key Class Signal)",
                    "bullets": [
                        "Noninfective conjunctivitis: Low 4.7%, Mid 5.9%, High 11.5%, PBO 0.0%",
                        "Pooled conjunctivitis (all preferred terms): Mid 10.6%, Low 15.1%, High 20.7%",
                        "Dose-dependent pattern (higher at higher doses)",
                        "Mid dose (10.6%) slightly above lebrikizumab Ph3 (~7–8%)",
                        "Low dose paradox (15.1%) — likely small-N noise"
                    ],
                    "x": 0.5, "y": 3.3, "w": 12.3, "h": 2.2
                }
            ],
            "disclaimer": "Review is required before disclosure.",
            "speakerNotes": "SAFETY DETAILS:\n- ≥1 TEAE: Low 75.6%, Mid 60.0%, High 67.8%, PBO 67.0%\n- ≥1 Serious TEAE: Low 2.3%, Mid 1.2%, High 3.4%, PBO 2.3%\n- D/C due to TEAE: Low 1.2%, Mid 2.4%, High 3.4%, PBO 2.3%\n\nCOMPARATIVE CONJUNCTIVITIS:\n- Lebrikizumab Ph3: ~7-8% (ADVOCATE)\n- Dupilumab: ~8-10% (SOLO/CAFÉ)\n- Tralokinumab: ~7-10% (ECZTRA)\n\nOverall well-tolerated, consistent with IL-13 class."
        },

        # ─── Slide 9: Broader Competitor Table ───
        {
            "type": "table",
            "title": "Competitive Landscape — AD Biologics at Week 16",
            "table": {
                "headers": ["Drug", "Sponsor", "MOA", "EASI-75", "IGA 0/1", "Dosing (Maint.)", "Phase"],
                "rows": [
                    ["Zumilokibart (APG777)", "Apogee", "Anti-IL-13", "65.9%", "46.0%", "Q12W–Q24W SC", "Phase 2b"],
                    ["Lebrikizumab (Ebglyss)", "Lilly", "Anti-IL-13", "53.0%", "37.0%", "Q2W/Q4W SC", "Approved"],
                    ["Dupilumab (Dupixent)", "Sanofi/Regen.", "Anti-IL-4Rα", "49.5%", "34.6%", "Q2W SC", "Approved"],
                    ["Nemolizumab (Nemluvio)", "Galderma", "Anti-IL-31Rα", "42.8%*", "36.7%*", "Q4W SC", "Approved"],
                    ["Tralokinumab (Adbry)", "LEO Pharma", "Anti-IL-13", "29.1%", "19.0%", "Q2W SC", "Approved"],
                    ["Amlitelimab", "Sanofi", "Anti-OX40L", "~44%†", "—", "Q4W SC", "Phase 2"],
                    ["Rocatinlimab", "Lilly (acq.)", "Anti-OX40", "—", "—", "Q4W SC", "Phase 3"]
                ]
            },
            "disclaimer": "Cross-trial comparisons are indirect. *+TCS combination. †24-week endpoint. Review is required before disclosure.",
            "speakerNotes": "SOURCES: Dupixent (SOLO 1&2 average, NRI); Ebglyss (ADVOCATE 1&2, NRI); Nemluvio (ARCADIA 1&2, NRI, +TCS); Adbry (ECZTRA 1&2, NRI); Amlitelimab (COAST, NRI). Note Nemluvio +TCS inflates vs monotherapy.\n\nZumilokibart's placebo rate (23.4%) is notably higher than historical AD trials (typically 10-15%), which may inflate absolute rates. Δ vs placebo is more reliable."
        },

        # ─── Slide 10: Head-to-Head vs Lebrikizumab ───
        {
            "type": "twoColumn",
            "title": "Zumilokibart vs Lebrikizumab (Ebglyss) — Lilly Positioning",
            "leftColumn": {
                "header": "Similarities",
                "bullets": [
                    "Same target: IL-13 neutralization",
                    "Same indication: moderate-to-severe AD adults",
                    "Similar endpoint magnitudes (EASI-75 ~50–66%)",
                    "SC injection route",
                    "Class-associated conjunctivitis risk",
                    "Both claim improving efficacy over time"
                ]
            },
            "rightColumn": {
                "header": "Differences",
                "bullets": [
                    "Dosing: Zumilokibart Q12–24W vs Lebrikizumab Q2–4W",
                    "Annual injections: 2–4 vs 13–26",
                    "Maturity: Ph2b vs Approved (Ebglyss launched)",
                    "Conjunctivitis: 10.6% (mid) vs ~8% (lebrikizumab Ph3)",
                    "Phase 3 data: 2H 2026 start; readout ~2028",
                    "Commercial: Apogee pre-revenue vs Lilly established"
                ]
            },
            "disclaimer": "Cross-trial comparison only; no head-to-head data available. Review is required before disclosure.",
            "speakerNotes": "The critical question for Lilly: Does zumilokibart threaten lebrikizumab's market position?\n\nThe dosing advantage is real and substantial (2-4 vs 13-26 injections/year).\nHowever:\n1. Lebrikizumab is already approved and launching\n2. Zumilokibart won't reach market until ~2029\n3. Phase 2 efficacy often doesn't fully translate to Phase 3\n4. Higher placebo rate may inflate absolute numbers\n\nKEY RISK: If Phase 3 confirms AND convenience drives switching → could cap lebrikizumab's peak share."
        },

        # ─── Slide 11: BNMA — EASI-75 ───
        {
            "type": "bnma",
            "title": "BNMA: EASI-75 at Induction Period (Week 16)",
            "imagePath": os.path.join(FIGURES_DIR, "APG777_EASI75_Wk16_2026-07-20.png"),
            "interpretation": [
                "Zumilokibart high dose peaks ~0.45 — highest",
                "Mid dose (Part A+B) peaks ~0.40, overlaps upadacitinib 15mg",
                "Lebrikizumab 250mg Q2W peaks ~0.35",
                "Wide CrI reflects small Phase 2 sample (N=85)",
                "Ranking: Mid ≈ #2–3 (overlaps upa, dupilumab)",
                "Lebrikizumab ranks ~#4–5 for EASI-75"
            ],
            "speakerNotes": "BNMA INTERPRETATION — EASI-75:\nRidge plot shows posterior distributions of PBO-adjusted treatment effects.\n\n1. Zumilokibart high dose (blue): rightmost peak (~0.45) but very wide distribution.\n2. Mid dose (red/pink, Part A+B): peaks ~0.38-0.40, overlapping with upadacitinib 15mg (teal) and dupilumab (green).\n3. Lebrikizumab 250mg Q2W (yellow/gold): peaks ~0.33-0.35.\n4. Abrocitinib 100mg (gray) and amlitelimab (purple) are lower.\n\nLIMITATIONS: Small sample inflates uncertainty. Phase 2 vs Phase 3 data. Different imputation methods.\n\nSOURCE: Lilly internal BNMA (Batman model), random-effects, monotherapy studies."
        },

        # ─── Slide 12: BNMA — IGA 0/1 ───
        {
            "type": "bnma",
            "title": "BNMA: IGA 0/1 at Induction Period (Week 16)",
            "imagePath": os.path.join(FIGURES_DIR, "APG777_IGA01_Wk16_2026-07-20.jpg"),
            "interpretation": [
                "Upadacitinib 15mg peaks highest (~0.35) overall",
                "Zumilokibart mid dose (Part A+B) peaks ~0.32",
                "Dupilumab 600/300mg peaks ~0.28",
                "Lebrikizumab 250mg Q2W peaks ~0.28",
                "Substantial overlap across all biologics for IGA 0/1",
                "Zumilokibart high dose has very wide CrI"
            ],
            "speakerNotes": "BNMA INTERPRETATION — IGA 0/1:\nIGA 0/1 posterior densities show a more compressed landscape than EASI-75.\n\n1. Upadacitinib 15mg oral (teal) peaks highest at ~0.35 (JAK class advantage for IGA).\n2. Zumilokibart Part A+B mid dose (red) peaks ~0.30-0.32.\n3. Dupilumab (green) and Lebrikizumab (yellow) both peak ~0.27-0.29.\n4. Abrocitinib 100mg lower (~0.22).\n\nFor IGA 0/1, separation between agents is less clear. Biologics cluster together, CIs overlap substantially. Dosing convenience may be more important than efficacy differentiation.\n\nSOURCE: Lilly internal BNMA (Batman model), random-effects, monotherapy studies."
        },

        # ─── Slide 13: Implications for Lilly Strategy ───
        {
            "type": "content",
            "title": "Implications for Lilly Strategy",
            "sections": [
                {
                    "header": "Competitive Threat Assessment",
                    "bullets": [
                        "EASI-75 Δ of 41.9 suggests potentially best-in-class efficacy among IL-13s",
                        "Dosing convenience (Q12–24W) is a major differentiator",
                        "Could set new standard of care upon approval (~2029)",
                        "Patient preference likely to favor fewer injections",
                        "Apogee's Blackstone deal funds full commercialization"
                    ],
                    "x": 0.5, "y": 1.15, "w": 12.3, "h": 2.2
                },
                {
                    "header": "Mitigating Factors for Lilly",
                    "bullets": [
                        "Lebrikizumab approved NOW; 3+ years of commercial build before zumilokibart arrives",
                        "Phase 2→3 attrition: efficacy commonly drops ~30% in larger trials",
                        "Higher placebo rate (23.4%) may inflate absolute numbers",
                        "Conjunctivitis (10.6%) slightly above lebrikizumab (~8%)",
                        "Small N (85/arm) — wide CIs, less certainty",
                        "Lilly's label breadth (adolescents, multiple indications) + rocatinlimab (anti-OX40) pipeline"
                    ],
                    "x": 0.5, "y": 3.5, "w": 12.3, "h": 2.5
                }
            ],
            "disclaimer": "Review is required before disclosure.",
            "speakerNotes": "THREAT LEVEL: MODERATE-HIGH.\n\nBULL CASE for Apogee: Phase 3 confirms efficacy, Q24W maintenance works, 2029 launch captures convenience seekers.\nBEAR CASE for Apogee: Phase 3 efficacy drops to ~50-55%, Q24W underperforms, conjunctivitis worsens with longer exposure.\n\nLILLY RESPONSE OPTIONS:\n1. Accelerate lebrikizumab lifecycle (Q4W data emphasis, pen device)\n2. Emphasize real-world evidence and safety track record\n3. Advance rocatinlimab (different MOA) as complementary pipeline\n4. Monitor ADventure Phase 3 enrollment and interim data\n5. Consider label expansion (pediatric, asthma) to differentiate"
        },

        # ─── Slide 14: Key Takeaways ───
        {
            "type": "summary",
            "title": "Key Takeaways & Recommended Actions",
            "takeaways": [
                "Zumilokibart mid dose achieved EASI-75 Δ=41.9 vs PBO (p<0.001) — potentially best-in-class for AD biologics",
                "Q12W–Q24W dosing (2–4 annual injections) is a transformational convenience advantage over all current biologics",
                "BNMA places zumilokibart mid dose in the top tier alongside upadacitinib and dupilumab, with overlapping CrIs vs lebrikizumab",
                "Phase 3 (ADventure) planned 2H 2026; if confirmed, represents a meaningful competitive threat to lebrikizumab by ~2029",
                "Safety is manageable (conjunctivitis 10.6%); key limitation is small sample size (N=85) with wide confidence intervals"
            ],
            "actions": [
                "Monitor ADventure Phase 3 enrollment and design details closely (2H 2026 initiation)",
                "Update BNMA with Phase 3 data when available; reassess ranking",
                "Evaluate lebrikizumab lifecycle strategy emphasizing established safety, label breadth, and real-world evidence"
            ],
            "speakerNotes": "SUMMARY: Zumilokibart is a credible, differentiated competitor to lebrikizumab in AD. The dosing convenience is its primary advantage. Lilly has time — lebrikizumab is approved and building market share now, while zumilokibart is 3+ years from potential approval.\n\nOPEN QUESTIONS:\n1. Should Lilly accelerate Q4W maintenance messaging for lebrikizumab?\n2. What is rocatinlimab timeline relative to zumilokibart?\n3. Will Q24W maintenance maintain efficacy long-term?\n\nReview is required before disclosure."
        }
    ]
}


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
    prs = Presentation()
    prs.slide_width = SLIDE_WIDTH
    prs.slide_height = SLIDE_HEIGHT

    for slide_data in DATA["slides"]:
        builder = BUILDERS.get(slide_data["type"])
        if builder:
            builder(prs, slide_data)
        else:
            print(f"Warning: Unknown slide type '{slide_data['type']}'", file=sys.stderr)

    output_file = os.path.join(BASE_DIR, DATA["outputFile"])
    prs.save(output_file)

    print(f"✓ Saved: {output_file}")
    print(f"  Mode: {DATA['mode']}")
    print(f"  Slides: {len(DATA['slides'])}")
    bnma_count = sum(1 for s in DATA["slides"] if s["type"] == "bnma")
    image_count = sum(1 for s in DATA["slides"] if s["type"] == "image")
    if image_count > 0:
        print(f"  Press release figures embedded: {image_count}")
    if bnma_count > 0:
        print(f"  BNMA plots embedded: {bnma_count}")


if __name__ == "__main__":
    main()

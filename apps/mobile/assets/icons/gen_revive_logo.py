"""Revive brand mark -> launcher icon layers + store icon.

Mark: an ink geometric "R" on a lime disc, with a butter sun-dot and a salmon
dot — the same four pastels as the app UI. Replaces the old lightning-bolt logo.

Outputs (this folder):
  revive_icon.png          1024  full-bleed icon (iOS + legacy Android)
  adaptive_background.png  1024  flat sky layer
  adaptive_foreground.png  1024  mark only, scaled for Android's 1.5x viewport
  play_store_icon_512.png   512  Google Play listing icon
Run:  python gen_revive_logo.py
"""
import io
import os

import cairosvg
from PIL import Image

DIR = os.path.dirname(os.path.abspath(__file__))
SKY, LIME, BUTTER, SALMON, INK = "#B8E3EE", "#CFE8B8", "#FBE28C", "#E1A38A", "#111111"


def mark(scale: float, with_bg: bool, bg_color: str = SKY) -> str:
    """SVG of the mark on a 1024 canvas. `scale` shrinks the artwork about the centre."""
    bg = f'<rect width="1024" height="1024" fill="{bg_color}"/>' if with_bg else ""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  {bg}
  <g transform="translate(512 512) scale({scale}) translate(-512 -512)">
    <circle cx="512" cy="522" r="360" fill="{LIME}"/>
    <circle cx="790" cy="236" r="104" fill="{BUTTER}"/>
    <circle cx="214" cy="826" r="64" fill="{SALMON}"/>
    <g fill="none" stroke="{INK}" stroke-width="112" stroke-linecap="round" stroke-linejoin="round">
      <path d="M418 340 V716"/>
      <path d="M418 340 H540 A126 126 0 0 1 540 592 H418"/>
      <path d="M548 592 L664 716"/>
    </g>
  </g>
</svg>"""


def render(svg: str, size: int, path: str) -> None:
    png = cairosvg.svg2png(bytestring=svg.encode(), output_width=size, output_height=size)
    Image.open(io.BytesIO(png)).save(os.path.join(DIR, path), optimize=True)
    print("wrote", path, size)


# Full icon: artwork fills ~86% so it reads well at small sizes.
render(mark(0.86, True), 1024, "revive_icon.png")
render(mark(0.86, True), 512, "play_store_icon_512.png")

# Adaptive layers. Android shows the central 72dp of a 108dp canvas (1.5x zoom),
# so the artwork is scaled to ~0.56 to land at ~60% of the visible icon.
render(f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024"><rect width="1024" height="1024" fill="{SKY}"/></svg>',
       1024, "adaptive_background.png")
render(mark(0.56, False), 1024, "adaptive_foreground.png")

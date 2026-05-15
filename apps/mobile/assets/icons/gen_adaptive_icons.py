"""
Generate Android adaptive icon layers from the Zenfit Z icon SVG.

Android adaptive icon rules:
  - Full canvas: 108dp x 108dp
  - Safe zone (never clipped): center 72dp x 72dp = 66.67% of canvas
  - Android magnifies the foreground by 108/72 = 1.5x in the visible viewport

  So: content_visible_pct = (content_size / canvas) * 1.5
  To show the Z at ~55% of the visible icon:
    target_canvas_pct = 0.55 / 1.5 = 0.367 → 376px of 1024px
    Z stroke-inclusive width ≈ 556px → scale = 376/556 ≈ 0.676

  Accent dot at (820,240) after scale 0.68 around (512,512):
    x = 512 + (820-512)*0.68 = 721  (safe zone: 171-853 ✓)
    y = 512 + (240-512)*0.68 = 327  (✓)

We produce:
  adaptive_background.png  — full-bleed gradient (no Z, no rounded clip)
  adaptive_foreground.png  — Z letterform on transparent, properly scaled for viewport
"""

import os
import cairosvg
from PIL import Image
import io

DIR = os.path.dirname(os.path.abspath(__file__))
SIZE = 1024

# Android shows 72dp of a 108dp canvas → magnification = 1.5x
# Scale Z down so it appears at ~55% of visible icon area after 1.5x zoom
SCALE = 0.68   # 556px * 0.68 = 378px on canvas → 378 * 1.5 / 1024 = 55% visible
TX = SIZE / 2
TY = SIZE / 2

# ── Background SVG (gradient only, no clip, no Z) ─────────────────────────────
BG_SVG = f"""<svg width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%"   stop-color="#FF5E7E"/>
      <stop offset="30%"  stop-color="#FF8A4C"/>
      <stop offset="62%"  stop-color="#A66BFF"/>
      <stop offset="100%" stop-color="#3B6BFF"/>
    </linearGradient>
    <radialGradient id="highlight" cx="25%" cy="20%" r="70%">
      <stop offset="0%"  stop-color="#FFFFFF" stop-opacity="0.35"/>
      <stop offset="70%" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
    <filter id="orbBlur" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="55"/>
    </filter>
  </defs>
  <rect width="{SIZE}" height="{SIZE}" fill="url(#bg)"/>
  <circle cx="880" cy="160" r="190" fill="#FFD93D" opacity="0.55" filter="url(#orbBlur)"/>
  <circle cx="140" cy="880" r="240" fill="#FF4D8F" opacity="0.55" filter="url(#orbBlur)"/>
  <circle cx="920" cy="920" r="180" fill="#3B6BFF" opacity="0.65" filter="url(#orbBlur)"/>
  <circle cx="100" cy="200" r="140" fill="#FF8A4C" opacity="0.45" filter="url(#orbBlur)"/>
  <rect width="{SIZE}" height="{SIZE}" fill="url(#highlight)"/>
</svg>"""

# ── Foreground SVG ─────────────────────────────────────────────────────────────
FG_SVG = f"""<svg width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="zFill" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%"   stop-color="#FFFFFF"/>
      <stop offset="100%" stop-color="#FFF0DC"/>
    </linearGradient>
    <filter id="softShadow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="10"/>
      <feOffset dx="0" dy="8"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.35"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <!-- Scale everything down around centre so Z fits at ~55% of visible viewport -->
  <g transform="translate({TX},{TY}) scale({SCALE}) translate(-{TX},-{TY})">
    <!-- Z letterform -->
    <path d="M 760 412 L 760 296 L 264 296 L 264 412 L 541.54 412 L 301.04 612 L 264 612 L 264 728 L 760 728 L 760 612 L 482.46 612 L 722.96 412 Z"
          fill="url(#zFill)"
          stroke="url(#zFill)"
          stroke-width="40"
          stroke-linejoin="round"
          stroke-linecap="round"
          filter="url(#softShadow)"/>
    <!-- Accent dot — at (821,240) scaled → approx (721,327), well within safe zone -->
    <circle cx="820" cy="240" r="52" fill="none" stroke="#FFE066" stroke-width="2" opacity="0.35"/>
    <circle cx="820" cy="240" r="34" fill="none" stroke="#FFFFFF" stroke-width="2" opacity="0.5"/>
    <circle cx="820" cy="240" r="22" fill="#FFE066"/>
    <circle cx="813" cy="232" r="7" fill="#FFFFFF" opacity="0.7"/>
  </g>
</svg>"""

def render(svg_str, out_path):
    data = cairosvg.svg2png(bytestring=svg_str.encode(), output_width=SIZE, output_height=SIZE)
    img = Image.open(io.BytesIO(data))
    img.save(out_path, "PNG")
    print(f"Saved {os.path.basename(out_path)}  {img.size}  {img.mode}")

render(BG_SVG,  os.path.join(DIR, "adaptive_background.png"))
render(FG_SVG,  os.path.join(DIR, "adaptive_foreground.png"))
print("Done.")

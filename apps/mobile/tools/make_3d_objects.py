"""Generate soft 'clay' 3D-style objects as transparent PNGs (CairoSVG)."""
from pathlib import Path
import cairosvg

OUT = Path(r"C:\Users\easwa\fitness_app\apps\mobile\assets\images")
HEAD = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">'

SHADOW = """
<defs><radialGradient id="sh" cx="50%" cy="50%" r="50%">
<stop offset="0" stop-color="#000" stop-opacity="0.28"/><stop offset="1" stop-color="#000" stop-opacity="0"/>
</radialGradient></defs>
<ellipse cx="256" cy="452" rx="170" ry="26" fill="url(#sh)"/>
"""


def grad(id_, c1, c2, cx=0.35, cy=0.3, r=0.9):
    return (f'<radialGradient id="{id_}" cx="{cx}" cy="{cy}" r="{r}">'
            f'<stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></radialGradient>')


def lin(id_, c1, c2, x2=0, y2=1):
    return (f'<linearGradient id="{id_}" x1="0" y1="0" x2="{x2}" y2="{y2}">'
            f'<stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient>')


def gloss(cx, cy, rx, ry, op=0.45, rot=-25):
    return (f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#fff" opacity="{op}" '
            f'transform="rotate({rot} {cx} {cy})"/>')


objects = {}

# ── dumbbell ─────────────────────────────────────────────────────────────────
objects["obj_dumbbell"] = f"""{HEAD}{SHADOW}
<defs>{grad('plate', '#5a5a5a', '#111')}{lin('bar', '#f4f4f4', '#9a9a9a')}{grad('cap', '#8a8a8a', '#2a2a2a')}</defs>
<g transform="rotate(-24 256 250)">
  <rect x="150" y="236" width="212" height="30" rx="15" fill="url(#bar)"/>
  <rect x="96"  y="150" width="64" height="200" rx="26" fill="url(#plate)"/>
  <rect x="352" y="150" width="64" height="200" rx="26" fill="url(#plate)"/>
  <rect x="60"  y="186" width="44" height="128" rx="20" fill="url(#cap)"/>
  <rect x="408" y="186" width="44" height="128" rx="20" fill="url(#cap)"/>
  {gloss(118, 200, 8, 40, 0.35, 0)}{gloss(374, 200, 8, 40, 0.35, 0)}
  {gloss(256, 244, 70, 5, 0.6, 0)}
</g></svg>"""

# ── apple ────────────────────────────────────────────────────────────────────
objects["obj_apple"] = f"""{HEAD}{SHADOW}
<defs>{grad('ap', '#ff8f7a', '#c4281c', 0.35, 0.3, 0.85)}{grad('lf', '#d8f2a6', '#6fae3a')}{lin('st', '#8b5a2b', '#4a2c0f')}</defs>
<path d="M256 150 C 190 110 90 150 96 262 C 100 360 170 450 232 446 C 246 445 250 440 256 440
         C 262 440 266 445 280 446 C 342 450 412 360 416 262 C 422 150 322 110 256 150 Z" fill="url(#ap)"/>
<path d="M256 152 C 258 120 262 96 282 70" stroke="url(#st)" stroke-width="16" stroke-linecap="round" fill="none"/>
<path d="M286 96 C 330 40 400 52 410 70 C 380 110 330 118 286 96 Z" fill="url(#lf)"/>
{gloss(165, 230, 22, 52, 0.5, 18)}
</svg>"""

# ── chat bubble ──────────────────────────────────────────────────────────────
objects["obj_chat"] = f"""{HEAD}{SHADOW}
<defs>{grad('bb', '#ffffff', '#9fd3e3', 0.3, 0.25, 0.95)}</defs>
<path d="M120 120 H392 A60 60 0 0 1 452 180 V292 A60 60 0 0 1 392 352 H258 L168 428 V352 H120
         A60 60 0 0 1 60 292 V180 A60 60 0 0 1 120 120 Z" fill="url(#bb)"/>
<circle cx="182" cy="236" r="22" fill="#111"/><circle cx="256" cy="236" r="22" fill="#111"/><circle cx="330" cy="236" r="22" fill="#111"/>
{gloss(150, 160, 56, 10, 0.7, -8)}
</svg>"""

# ── target with arrow ────────────────────────────────────────────────────────
objects["obj_target"] = f"""{HEAD}{SHADOW}
<defs>{grad('r1', '#ffd0bf', '#e1a38a')}{grad('r2', '#ffffff', '#e8e8e8')}{grad('r3', '#ff9a86', '#e26a5e')}{lin('shaft', '#444', '#111')}</defs>
<circle cx="236" cy="268" r="170" fill="url(#r1)"/>
<circle cx="236" cy="268" r="126" fill="url(#r2)"/>
<circle cx="236" cy="268" r="82" fill="url(#r1)"/>
<circle cx="236" cy="268" r="40" fill="url(#r3)"/>
<line x1="236" y1="268" x2="420" y2="84" stroke="url(#shaft)" stroke-width="14" stroke-linecap="round"/>
<path d="M400 60 L452 52 L444 104 L420 84 Z" fill="#fbe28c"/>
<path d="M420 84 L444 104 L404 112 Z" fill="#e5b82a"/>
{gloss(160, 180, 40, 10, 0.5, -35)}
</svg>"""

# ── bathroom scale ───────────────────────────────────────────────────────────
objects["obj_scale"] = f"""{HEAD}{SHADOW}
<defs>{grad('sc', '#e6f6cf', '#a9d487', 0.3, 0.2, 1)}{grad('face', '#ffffff', '#eaeaea')}</defs>
<rect x="76" y="108" width="360" height="330" rx="64" fill="url(#sc)"/>
<rect x="116" y="146" width="280" height="150" rx="40" fill="url(#face)"/>
<path d="M176 262 A80 80 0 0 1 336 262" stroke="#d9d9d9" stroke-width="16" stroke-linecap="round" fill="none"/>
<path d="M176 262 A80 80 0 0 1 270 188" stroke="#e26a5e" stroke-width="16" stroke-linecap="round" fill="none"/>
<line x1="256" y1="262" x2="300" y2="214" stroke="#111" stroke-width="10" stroke-linecap="round"/>
<circle cx="256" cy="262" r="12" fill="#111"/>
<rect x="196" y="332" width="120" height="14" rx="7" fill="#fff" opacity="0.7"/>
{gloss(130, 130, 40, 8, 0.6, -10)}
</svg>"""

# ── water drop ───────────────────────────────────────────────────────────────
objects["obj_drop"] = f"""{HEAD}{SHADOW}
<defs>{grad('dr', '#d9f3fb', '#4aa6c4', 0.35, 0.3, 0.9)}</defs>
<path d="M256 56 C 256 56 112 214 112 318 C 112 398 176 456 256 456 C 336 456 400 398 400 318 C 400 214 256 56 256 56 Z" fill="url(#dr)"/>
{gloss(200, 300, 20, 56, 0.6, 12)}
</svg>"""

# ── trophy cup ───────────────────────────────────────────────────────────────
objects["obj_trophy"] = f"""{HEAD}{SHADOW}
<defs>{grad('gd', '#fff1b0', '#e2a91a', 0.3, 0.2, 1)}{lin('base', '#6b4a1c', '#3a2508')}</defs>
<path d="M170 96 H342 V212 C342 270 304 306 256 306 C208 306 170 270 170 212 Z" fill="url(#gd)"/>
<path d="M170 128 C100 128 92 214 176 236" stroke="url(#gd)" stroke-width="22" fill="none" stroke-linecap="round"/>
<path d="M342 128 C412 128 420 214 336 236" stroke="url(#gd)" stroke-width="22" fill="none" stroke-linecap="round"/>
<rect x="236" y="300" width="40" height="70" rx="12" fill="url(#gd)"/>
<rect x="176" y="366" width="160" height="40" rx="14" fill="url(#base)"/>
<rect x="150" y="402" width="212" height="34" rx="14" fill="url(#base)"/>
<path d="M256 140 l14 30 l32 4 l-24 22 l7 32 l-29 -16 l-29 16 l7 -32 l-24 -22 l32 -4 Z" fill="#fff" opacity="0.65"/>
{gloss(212, 150, 12, 44, 0.55, 8)}
</svg>"""

for name, svg in objects.items():
    cairosvg.svg2png(bytestring=svg.encode("utf-8"), write_to=str(OUT / f"{name}.png"),
                     output_width=512, output_height=512)
    print(name, round((OUT / f"{name}.png").stat().st_size / 1024), "KB")

# contact sheet
from PIL import Image
sheet = Image.new("RGB", (512 * 4, 512 * 2), (184, 227, 238))
for i, name in enumerate(objects):
    t = Image.open(OUT / f"{name}.png").convert("RGBA")
    sheet.paste(t, ((i % 4) * 512, (i // 4) * 512), t)
sheet.thumbnail((1600, 800))
sheet.save(Path(__file__).with_name("preview_objects.png"))

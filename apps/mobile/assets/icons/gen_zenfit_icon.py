"""
Generate zenfit_icon.png — 1024×1024 ZenFit flame launcher icon.
Visual spec mirrors zenfit_icon.svg exactly:
  • Dark diagonal background gradient
  • Organic flame (bezier-approximated) with vertical green→mint gradient
  • Inner shadow path for hollow-core depth
  • Teardrop highlight + glowing core circle
  • Elliptical base glow + arc reflection line
Run with:  py -3 gen_zenfit_icon.py
"""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024


# ─── Bezier helpers ──────────────────────────────────────────────────────────

def cubic_bezier(p0, p1, p2, p3, n=400):
    pts = []
    for i in range(n + 1):
        t = i / n
        m = 1 - t
        x = m**3*p0[0] + 3*m**2*t*p1[0] + 3*m*t**2*p2[0] + t**3*p3[0]
        y = m**3*p0[1] + 3*m**2*t*p1[1] + 3*m*t**2*p2[1] + t**3*p3[1]
        pts.append((x, y))
    return pts


def quad_bezier(p0, p1, p2, n=150):
    pts = []
    for i in range(n + 1):
        t = i / n
        m = 1 - t
        x = m**2*p0[0] + 2*m*t*p1[0] + t**2*p2[0]
        y = m**2*p0[1] + 2*m*t*p1[1] + t**2*p2[1]
        pts.append((x, y))
    return pts


def flatten(pts):
    return [(int(round(x)), int(round(y))) for x, y in pts]


# ─── Flame polygon (matches SVG path control points) ─────────────────────────
#   M 342,748
#   C 285,560 410,340 522,178   ← left side cubic
#   C 635,340 740,550 682,748   ← right side cubic
#   Q 512,715 342,748           ← base quad arc

BL   = (342, 748)
TOP  = (522, 178)
BR   = (682, 748)

left_pts  = cubic_bezier(BL,  (285, 560), (410, 340), TOP,      400)
right_pts = cubic_bezier(TOP, (635, 340), (740, 550), BR,       400)
base_pts  = quad_bezier(BR,   (512, 715), BL,                   150)

flame_poly = flatten(left_pts + right_pts[1:] + base_pts[1:])

# ─── Inner shadow polygon (narrower, same family) ────────────────────────────
#   M 400,748  C 355,580 445,370 518,230  C 590,370 660,570 624,748  Q 512,728 400,748

IBL  = (400, 748)
ITOP = (518, 230)
IBR  = (624, 748)

i_left  = cubic_bezier(IBL,  (355, 580), (445, 370), ITOP, 300)
i_right = cubic_bezier(ITOP, (590, 370), (660, 570), IBR,  300)
i_base  = quad_bezier(IBR,   (512, 728), IBL,               80)

inner_poly = flatten(i_left + i_right[1:] + i_base[1:])

# ─── Teardrop highlight polygon ───────────────────────────────────────────────
#   M 516,460  C 548,490 558,530 516,610  C 474,530 484,490 516,460

tear_right = cubic_bezier((516, 460), (548, 490), (558, 530), (516, 610), 200)
tear_left  = cubic_bezier((516, 610), (474, 530), (484, 490), (516, 460), 200)
tear_poly  = flatten(tear_right + tear_left[1:])


# ─── Step 1: Background (diagonal gradient) ──────────────────────────────────
# #0A2E22 (10,46,34) → #051A12 (5,26,18), top-left → bottom-right

def make_background():
    c1 = np.array([10, 46, 34], dtype=float)
    c2 = np.array([5,  26, 18], dtype=float)
    x_i, y_i = np.meshgrid(np.arange(SIZE), np.arange(SIZE))
    t = (x_i + y_i) / (2.0 * (SIZE - 1))          # 0 at TL, 1 at BR
    t = np.clip(t, 0.0, 1.0)[..., np.newaxis]
    rgb = (c1 + (c2 - c1) * t).astype(np.uint8)    # (H,W,3)
    alpha = np.full((SIZE, SIZE, 1), 255, dtype=np.uint8)
    return Image.fromarray(np.concatenate([rgb, alpha], axis=2), "RGBA")


# ─── Step 2: Flame gradient layer then mask ───────────────────────────────────
# Vertical gradient: bottom #1D9E75 → 60% #25C48A → top #7EEDC8

def make_flame_gradient():
    # Build 1×SIZE strip, then tile to SIZE×SIZE
    c_bot  = np.array([29, 158, 117], dtype=float)   # #1D9E75
    c_mid  = np.array([37, 196, 138], dtype=float)   # #25C48A
    c_top  = np.array([126, 237, 200], dtype=float)  # #7EEDC8
    strip  = np.zeros((SIZE, 1, 3), dtype=float)
    for y in range(SIZE):
        # y=0 is top → t_top=1; y=SIZE-1 is bottom → t_bot=1
        t = y / (SIZE - 1)           # 0 at top, 1 at bottom
        if t >= 0.4:                 # lower 60% → bot..mid
            s = (t - 0.4) / 0.6
            col = c_mid + (c_bot - c_mid) * s
        else:                        # upper 40% → mid..top
            s = t / 0.4
            col = c_top + (c_mid - c_top) * s
        strip[y, 0] = col
    grad = np.tile(strip.astype(np.uint8), (1, SIZE, 1))
    alpha = np.full((SIZE, SIZE, 1), 255, dtype=np.uint8)
    return Image.fromarray(np.concatenate([grad, alpha], axis=2), "RGBA")


# ─── Rounded-square mask ─────────────────────────────────────────────────────

def make_rounded_mask(radius=230):
    mask = Image.new("L", (SIZE, SIZE), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=radius, fill=255)
    return mask


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    canvas = make_background()
    draw   = ImageDraw.Draw(canvas, "RGBA")

    # ── Base elliptical glow (blurred, drawn before flame) ────────────────
    glow_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow_layer)
    gd.ellipse(
        [512 - 180, 780 - 38, 512 + 180, 780 + 38],
        fill=(29, 158, 117, int(255 * 0.18)),
    )
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=18))
    canvas.alpha_composite(glow_layer)

    # ── Flame (gradient fill via mask) ────────────────────────────────────
    flame_mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(flame_mask).polygon(flame_poly, fill=255)

    flame_grad = make_flame_gradient()
    flame_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    flame_layer.paste(flame_grad, mask=flame_mask)
    canvas.alpha_composite(flame_layer)

    # ── Inner shadow ───────────────────────────────────────────────────────
    draw.polygon(inner_poly, fill=(10, 46, 34, int(255 * 0.50)))

    # ── Teardrop highlight ─────────────────────────────────────────────────
    draw.polygon(tear_poly, fill=(126, 237, 200, int(255 * 0.60)))

    # ── Core glow circle (blurred then overlaid) ───────────────────────────
    cx, cy, r = 516, 560, 40
    glow2 = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd2   = ImageDraw.Draw(glow2)
    # Draw a larger softer halo first
    for ring_r, ring_a in [(80, 60), (60, 120), (40, 204)]:
        ring_a_scaled = int(ring_a)
        gd2.ellipse(
            [cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r],
            fill=(126, 237, 200, ring_a_scaled),
        )
    glow2 = glow2.filter(ImageFilter.GaussianBlur(radius=14))
    canvas.alpha_composite(glow2)
    # Solid bright circle on top
    draw.ellipse(
        [cx - r, cy - r, cx + r, cy + r],
        fill=(126, 237, 200, int(255 * 0.80)),
    )

    # ── Arc reflection line ────────────────────────────────────────────────
    # Q 512,820 path from (320,780) to (700,780) arcing downward
    arc_pts = flatten(quad_bezier((320, 780), (512, 820), (700, 780), 200))
    draw.line(arc_pts, fill=(29, 158, 117, int(255 * 0.40)), width=10)

    # ── Clip to rounded square ─────────────────────────────────────────────
    rounded_mask = make_rounded_mask(radius=230)
    canvas.putalpha(rounded_mask)

    # ── Save ───────────────────────────────────────────────────────────────
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    # Place on opaque bg so PNG has solid corners (required by launcher icons)
    bg_solid = Image.new("RGBA", (SIZE, SIZE), (10, 46, 34, 255))
    bg_solid.paste(canvas, mask=canvas.split()[3])
    bg_solid.save("zenfit_icon.png", "PNG")
    print("Saved zenfit_icon.png  (1024x1024)")


if __name__ == "__main__":
    main()

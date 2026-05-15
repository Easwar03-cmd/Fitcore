"""Generate the Revive lightning bolt app icon."""
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

SIZE = 1024


def apply_rounded_mask(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=radius, fill=255)
    result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    result.paste(img, mask=mask)
    return result


def bolt_polygon(size=SIZE):
    """
    6-vertex lightning bolt.
    Upper arm = proper parallelogram (constant 113 px width, tilted left).
    Notch bumps 85 px right. Lower arm narrows to a tip.
    Bolt spans y=270..760 (49% of canvas) — fits inside the Android
    safe-zone (center 66 dp / 108 dp ≈ 61% of canvas).
    """
    s = size / SIZE
    raw = [
        (462, 270),  # v1  top-left  of upper arm
        (575, 270),  # v2  top-right of upper arm
        (505, 540),  # v3  bottom-right of upper arm  (kink)
        (590, 540),  # v4  notch — bumps 85 px right
        (468, 760),  # v5  bottom tip
        (392, 540),  # v6  notch — left edge / bottom-left of upper arm
    ]
    return [(int(x * s), int(y * s)) for x, y in raw]


def make_icon(size=SIZE) -> Image.Image:
    s = size / SIZE

    # ── Background: deep navy ──────────────────────────────────────────────
    bg = Image.new("RGBA", (size, size), (6, 15, 35, 255))

    # Subtle radial centre glow
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = size // 2, size // 2
    for r in range(int(340 * s), 0, -4):
        a = int(60 * (1 - r / (340 * s)) ** 1.2)
        gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(18, 50, 105, a))
    glow = glow.filter(ImageFilter.GaussianBlur(int(25 * s)))
    bg = Image.alpha_composite(bg, glow)

    # ── Lightning bolt ─────────────────────────────────────────────────────
    bolt = bolt_polygon(size)

    # Base: rich electric blue
    bolt_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(bolt_layer).polygon(bolt, fill=(15, 105, 235, 255))

    # Gradient: bright cyan-white on left face → deeper blue on right
    grad = np.zeros((size, size, 4), dtype=np.uint8)
    # find bolt x extents
    xs = [p[0] for p in bolt]
    bx_min, bx_max = min(xs), max(xs)
    for x in range(size):
        t = max(0.0, min(1.0, (x - bx_min) / (bx_max - bx_min)))
        r = int(130 + 95 * (1 - t))   # 225 → 130
        g = int(175 + 55 * (1 - t))   # 230 → 175
        b = 255
        grad[:, x] = [r, g, b, 255]
    bolt_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(bolt_mask).polygon(bolt, fill=255)
    grad[np.array(bolt_mask) == 0] = [0, 0, 0, 0]
    bolt_layer = Image.alpha_composite(bolt_layer, Image.fromarray(grad, "RGBA"))

    # Soft halo glow around bolt
    halo = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(halo).polygon(bolt, fill=(30, 120, 255, 150))
    halo = halo.filter(ImageFilter.GaussianBlur(int(30 * s)))

    # Compose: background → halo → bolt
    icon = Image.alpha_composite(bg, halo)
    icon = Image.alpha_composite(icon, bolt_layer)

    # Rounded corners (Android-style squircle)
    return apply_rounded_mask(icon, int(200 * s))


def make_foreground(size=SIZE) -> Image.Image:
    """Adaptive icon foreground: bolt on transparent. No background, no rounded corners."""
    s = size / SIZE
    bolt = bolt_polygon(size)

    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(bolt, fill=(15, 105, 235, 255))

    grad = np.zeros((size, size, 4), dtype=np.uint8)
    xs = [p[0] for p in bolt]
    bx_min, bx_max = min(xs), max(xs)
    for x in range(size):
        t = max(0.0, min(1.0, (x - bx_min) / (bx_max - bx_min)))
        r = int(130 + 95 * (1 - t))
        g = int(175 + 55 * (1 - t))
        b = 255
        grad[:, x] = [r, g, b, 255]
    bolt_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(bolt_mask).polygon(bolt, fill=255)
    grad[np.array(bolt_mask) == 0] = [0, 0, 0, 0]
    layer = Image.alpha_composite(layer, Image.fromarray(grad, "RGBA"))

    halo = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(halo).polygon(bolt, fill=(30, 120, 255, 120))
    halo = halo.filter(ImageFilter.GaussianBlur(int(22 * s)))
    return Image.alpha_composite(halo, layer)


def make_background(size=SIZE) -> Image.Image:
    """Adaptive icon background: plain dark navy, no rounded corners."""
    s = size / SIZE
    bg = Image.new("RGBA", (size, size), (6, 15, 35, 255))
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = size // 2, size // 2
    for r in range(int(340 * s), 0, -4):
        a = int(60 * (1 - r / (340 * s)) ** 1.2)
        gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(18, 50, 105, a))
    glow = glow.filter(ImageFilter.GaussianBlur(int(25 * s)))
    return Image.alpha_composite(bg, glow)


if __name__ == "__main__":
    import os
    out = os.path.dirname(os.path.abspath(__file__))

    print("Generating zenfit_icon.png …")
    make_icon(1024).save(os.path.join(out, "zenfit_icon.png"))

    print("Generating adaptive_foreground.png …")
    make_foreground(1024).save(os.path.join(out, "adaptive_foreground.png"))

    print("Generating adaptive_background.png …")
    make_background(1024).save(os.path.join(out, "adaptive_background.png"))

    print("Done.")

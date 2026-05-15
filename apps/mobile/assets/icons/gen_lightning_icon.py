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


def make_icon(size=SIZE) -> Image.Image:
    s = size / SIZE  # scale factor

    # ── Background (dark navy) ─────────────────────────────────────────────
    bg = Image.new("RGBA", (size, size), (8, 18, 40, 255))

    # Subtle radial gradient overlay (slightly lighter in center)
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = size // 2, size // 2
    for r in range(int(380 * s), 0, -4):
        a = int(55 * (1 - r / (380 * s)) ** 1.5)
        gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(20, 55, 110, a))
    glow = glow.filter(ImageFilter.GaussianBlur(int(22 * s)))
    bg = Image.alpha_composite(bg, glow)

    # ── Lightning bolt (6-vertex polygon) ─────────────────────────────────
    # Coordinates for SIZE=1024 (scaled by s for other sizes)
    raw = [
        (450, 140),  # v1  top-left  of upper arm
        (590, 140),  # v2  top-right of upper arm
        (550, 510),  # v3  bottom-right of upper arm (kink)
        (650, 510),  # v4  notch — bumps right
        (460, 900),  # v5  bottom tip
        (360, 510),  # v6  notch — left edge
    ]
    bolt = [(int(x * s), int(y * s)) for x, y in raw]

    # Base bolt fill: deep electric blue
    bolt_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(bolt_layer).polygon(bolt, fill=(18, 110, 220, 255))

    # Gradient overlay: lighter on the left face, darker on the right
    grad = np.zeros((size, size, 4), dtype=np.uint8)
    for x in range(size):
        t = x / size  # 0=left bright, 1=right dark
        r = int(80 + 100 * (1 - t))
        g = int(155 + 55 * (1 - t))
        b = 255
        grad[:, x] = [r, g, b, 255]
    bolt_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(bolt_mask).polygon(bolt, fill=255)
    grad[np.array(bolt_mask) == 0] = [0, 0, 0, 0]
    bolt_layer = Image.alpha_composite(bolt_layer, Image.fromarray(grad, "RGBA"))

    # Soft glow halo around bolt
    halo = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(halo).polygon(bolt, fill=(40, 130, 255, 160))
    halo = halo.filter(ImageFilter.GaussianBlur(int(28 * s)))

    # Compose: background → halo → bolt
    icon = Image.alpha_composite(bg, halo)
    icon = Image.alpha_composite(icon, bolt_layer)

    # Rounded corners
    icon = apply_rounded_mask(icon, int(180 * s))
    return icon


def make_foreground(size=SIZE) -> Image.Image:
    """Adaptive icon foreground: bolt only on transparent background."""
    s = size / SIZE
    raw = [
        (450, 140), (590, 140), (550, 510),
        (650, 510), (460, 900), (360, 510),
    ]
    bolt = [(int(x * s), int(y * s)) for x, y in raw]

    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(bolt, fill=(18, 110, 220, 255))

    grad = np.zeros((size, size, 4), dtype=np.uint8)
    for x in range(size):
        t = x / size
        r = int(80 + 100 * (1 - t))
        g = int(155 + 55 * (1 - t))
        b = 255
        grad[:, x] = [r, g, b, 255]
    bolt_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(bolt_mask).polygon(bolt, fill=255)
    grad[np.array(bolt_mask) == 0] = [0, 0, 0, 0]
    layer = Image.alpha_composite(layer, Image.fromarray(grad, "RGBA"))

    halo = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(halo).polygon(bolt, fill=(40, 130, 255, 120))
    halo = halo.filter(ImageFilter.GaussianBlur(int(22 * s)))
    return Image.alpha_composite(halo, layer)


def make_background(size=SIZE) -> Image.Image:
    """Adaptive icon background: plain dark navy (no rounded corners)."""
    bg = Image.new("RGBA", (size, size), (8, 18, 40, 255))
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = size // 2, size // 2
    s = size / SIZE
    for r in range(int(380 * s), 0, -4):
        a = int(55 * (1 - r / (380 * s)) ** 1.5)
        gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(20, 55, 110, a))
    glow = glow.filter(ImageFilter.GaussianBlur(int(22 * s)))
    return Image.alpha_composite(bg, glow)


if __name__ == "__main__":
    import os

    out = os.path.dirname(os.path.abspath(__file__))

    print("Generating zenfit_icon.png (1024x1024)...")
    make_icon(1024).save(os.path.join(out, "zenfit_icon.png"))

    print("Generating adaptive_foreground.png (1024x1024)...")
    make_foreground(1024).save(os.path.join(out, "adaptive_foreground.png"))

    print("Generating adaptive_background.png (1024x1024)...")
    make_background(1024).save(os.path.join(out, "adaptive_background.png"))

    print("Done.")

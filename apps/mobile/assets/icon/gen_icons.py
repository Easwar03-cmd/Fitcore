"""Generate ZenFit launcher icons: full icon + adaptive foreground."""
from PIL import Image, ImageDraw

SIZE = 1024
BG_GREEN = (29, 158, 117)   # #1D9E75
WHITE    = (255, 255, 255, 255)
CLEAR    = (0, 0, 0, 0)

# Classic 7-vertex lightning bolt, centred in SIZE×SIZE canvas.
# Vertices listed clockwise from top-left.
BOLT = [
    (370, 170),  # A  top-left
    (630, 170),  # B  top-right
    (560, 520),  # C  inner notch – right
    (695, 520),  # D  outer notch – right  (the protruding right corner)
    (455, 860),  # E  bottom tip (left-of-centre for visual balance)
    (320, 520),  # F  outer notch – left   (the protruding left corner)
    (450, 520),  # G  inner notch – left
]


def draw_bolt(draw, fill):
    draw.polygon(BOLT, fill=fill)


# ── 1. Full icon (green bg + white bolt) ─────────────────────────────────────
full = Image.new("RGBA", (SIZE, SIZE), BG_GREEN + (255,))
draw_bolt(ImageDraw.Draw(full), WHITE)
full.save("icon.png")
print("Saved icon.png")

# ── 2. Adaptive foreground (white bolt on transparent bg) ────────────────────
fg = Image.new("RGBA", (SIZE, SIZE), CLEAR)
draw_bolt(ImageDraw.Draw(fg), WHITE)
fg.save("foreground.png")
print("Saved foreground.png")

print("Done.")

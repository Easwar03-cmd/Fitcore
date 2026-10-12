"""Crop / cut out / compress the user-supplied photos into app assets."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

SRC = Path(r"C:\Users\easwa\Downloads\Images")
OUT = Path(r"C:\Users\easwa\fitness_app\apps\mobile\assets\images")
OUT.mkdir(parents=True, exist_ok=True)


def photo(name, out, box_display, factor, max_side, q=80):
    im = Image.open(SRC / name).convert("RGB")
    box = tuple(int(v * factor) for v in box_display)
    im = im.crop(box)
    im.thumbnail((max_side, max_side), Image.LANCZOS)
    im.save(OUT / out, "JPEG", quality=q, optimize=True, progressive=True)
    print(out, im.size, round((OUT / out).stat().st_size / 1024), "KB")


def flood_bg(rgb, is_bg):
    """Background = bg-like pixels connected to the image border."""
    lab, n = ndi.label(is_bg)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])))
    border.discard(0)
    return np.isin(lab, list(border))


def save_cutout(rgb, bg, out, max_side, feather=1.2):
    alpha = (~bg).astype(np.float32)
    # remove 1px fringe, then soften the edge
    alpha = ndi.binary_erosion(alpha > 0.5, iterations=1).astype(np.float32)
    alpha = ndi.gaussian_filter(alpha, feather)
    img = Image.fromarray(rgb).convert("RGBA")
    img.putalpha(Image.fromarray((alpha * 255).astype(np.uint8)))
    bbox = img.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox()
    img = img.crop(bbox)
    img.thumbnail((max_side, max_side), Image.LANCZOS)
    img.save(OUT / out, "PNG", optimize=True)
    print(out, img.size, round((OUT / out).stat().st_size / 1024), "KB")


# ── photos used as inset tiles ────────────────────────────────────────────────
photo("Bowl.jpg", "hero_home_plate.jpg", (480, 160, 1480, 1160), 3.36, 800)
photo("Battle ropes.jpg", "hero_gym_athlete.jpg", (400, 620, 1200, 1760), 2.75, 1000)
photo("Push-up.jpg", "hero_home_workout.jpg", (340, 440, 1160, 1260), 2.88, 800)
photo("Athlete.jpg", "hero_progress.jpg", (330, 0, 1660, 1333), 1.51, 800)
photo("People.jpg", "hero_community.jpg", (0, 380, 1330, 1710), 3.01, 800)
photo("Fitband.jpg", "hero_fitband.jpg", (800, 650, 1950, 1800), 2.12, 800)

# ── heart: white studio background -> transparent ────────────────────────────
im = Image.open(SRC / "Heart.jpg").convert("RGB").crop((0, 0, 736, 603))
rgb = np.array(im)
is_bg = rgb.min(axis=2) >= 238
save_cutout(rgb, flood_bg(rgb, is_bg), "heart_3d.png", 600)

# ── medal: flat blue backdrop -> transparent ─────────────────────────────────
im = Image.open(SRC / "Meda;.jpg").convert("RGB").crop((0, 0, 2400, 2880))
rgb = np.array(im)
ref = np.array([194, 229, 249], dtype=np.float32)
dist = np.sqrt(((rgb.astype(np.float32) - ref) ** 2).sum(axis=2))
is_bg = dist < 22
save_cutout(rgb, flood_bg(rgb, is_bg), "challenge_medal.png", 700)

# ── runner: already RGBA — trim, de-halo, resize ─────────────────────────────
im = Image.open(SRC / "Runner.png").convert("RGBA")
a = np.array(im.getchannel("A")).astype(np.float32) / 255
a = ndi.binary_erosion(a > 0.5, iterations=2).astype(np.float32)
a = ndi.gaussian_filter(a, 1.0)
im.putalpha(Image.fromarray((a * 255).astype(np.uint8)))
im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox())
im.thumbnail((900, 900), Image.LANCZOS)
im.save(OUT / "workout_runner.png", "PNG", optimize=True)
print("workout_runner.png", im.size, round((OUT / "workout_runner.png").stat().st_size / 1024), "KB")

# ── preview sheet on the sky colour ──────────────────────────────────────────
sheet = Image.new("RGB", (1800, 620), (184, 227, 238))
x = 10
for n in ["heart_3d.png", "challenge_medal.png", "workout_runner.png"]:
    t = Image.open(OUT / n).convert("RGBA")
    t.thumbnail((560, 600))
    sheet.paste(t, (x, 10), t)
    x += 600
sheet.save(Path(__file__).with_name("preview_cutouts.png"))

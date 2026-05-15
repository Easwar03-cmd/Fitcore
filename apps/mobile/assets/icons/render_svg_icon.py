"""Render zenfit_icon.svg to zenfit_icon.png (1024x1024) using cairosvg."""
import subprocess
import sys
import os

svg_path = os.path.join(os.path.dirname(__file__), "zenfit_icon.svg")
png_path = os.path.join(os.path.dirname(__file__), "zenfit_icon.png")

try:
    import cairosvg
    cairosvg.svg2png(url=svg_path, write_to=png_path, output_width=1024, output_height=1024)
    print(f"Saved {png_path}")
except ImportError:
    print("cairosvg not found. Trying pip install cairosvg...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "cairosvg"])
    import cairosvg
    cairosvg.svg2png(url=svg_path, write_to=png_path, output_width=1024, output_height=1024)
    print(f"Saved {png_path}")

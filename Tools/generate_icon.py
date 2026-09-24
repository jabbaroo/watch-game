#!/usr/bin/env python3
"""Generates a 1024x1024 placeholder app icon. Replace with an Icon Composer icon before release."""
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "WatchGame" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

SVG = """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" fill="#101418"/>
  <circle cx="330" cy="330" r="150" fill="#D55E00"/>
  <rect x="544" y="180" width="300" height="300" rx="40" fill="#F0E442"/>
  <polygon points="330,544 480,844 180,844" fill="#009E73"/>
  <polygon points="694,544 738,660 860,660 762,732 800,850 694,780 588,850 626,732 528,660 650,660" fill="#0072B2"/>
</svg>"""

with tempfile.TemporaryDirectory() as tmp:
    svg = pathlib.Path(tmp) / "icon.svg"
    svg.write_text(SVG)
    subprocess.run(["qlmanage", "-t", "-s", "1024", "-o", tmp, str(svg)], check=True, capture_output=True)
    png = pathlib.Path(tmp) / "icon.svg.png"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    # App Store icons must have no alpha channel; a JPEG round trip flattens it.
    jpg = pathlib.Path(tmp) / "icon.jpg"
    subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "100", str(png), "--out", str(jpg)], check=True, capture_output=True)
    subprocess.run(["sips", "-s", "format", "png", str(jpg), "--out", str(OUT)], check=True, capture_output=True)
    print(f"wrote {OUT.relative_to(ROOT)}")

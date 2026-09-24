#!/usr/bin/env python3
"""Writes the go, no-go pack: the shapes and colours items with a quarter of them shown as holds."""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "WatchGame" / "Resources" / "Packs" / "gonogo.pack.json"
COLOURS = [("red", "#D55E00"), ("yellow", "#F0E442"), ("green", "#009E73"), ("blue", "#0072B2")]
SHAPES = ["circle", "square", "triangle", "star"]

pack = {
    "id": "gonogo",
    "nameKey": "pack.gonogo",
    "descriptionKey": "pack.gonogo.description",
    "holdProbability": 0.25,
    "dimensions": [
        {"id": "colour", "nameKey": "dimension.colour",
         "values": [{"id": c, "labelKey": f"colour.{c}", "hintKey": f"hint.colour.{c}"} for c, _ in COLOURS]},
        {"id": "shape", "nameKey": "dimension.shape",
         "values": [{"id": s, "labelKey": f"shape.{s}"} for s in SHAPES]},
    ],
    "items": [
        {"id": f"{c}-{s}", "attributes": {"colour": c, "shape": s},
         "visual": {"type": "shape", "kind": s, "colour": hex_}}
        for c, hex_ in COLOURS for s in SHAPES
    ],
}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(pack, indent=2) + "\n")
print(f"wrote {OUT.relative_to(ROOT)} ({len(pack['items'])} items, hold {pack['holdProbability']})")

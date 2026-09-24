#!/usr/bin/env python3
"""Writes the Stroop pack: four colour words in four ink colours, ids shared across dimensions
so the engine can tell congruent items (word in its own colour) from incongruent ones."""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "WatchGame" / "Resources" / "Packs" / "stroop.pack.json"
COLOURS = [("red", "#D55E00"), ("yellow", "#F0E442"), ("green", "#009E73"), ("blue", "#0072B2")]

pack = {
    "id": "stroop",
    "nameKey": "pack.stroop",
    "descriptionKey": "pack.stroop.description",
    "dimensions": [
        {"id": "ink", "nameKey": "dimension.ink",
         "values": [{"id": c, "labelKey": f"colour.{c}", "hintKey": f"hint.colour.{c}"} for c, _ in COLOURS]},
        {"id": "word", "nameKey": "dimension.word",
         "values": [{"id": c, "labelKey": f"colour.{c}"} for c, _ in COLOURS]},
    ],
    "items": [
        {"id": f"{word}-in-{ink}", "attributes": {"ink": ink, "word": word},
         "visual": {"type": "word", "textKey": f"colour.{word}", "colour": hex_}}
        for ink, hex_ in COLOURS for word, _ in COLOURS
    ],
}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(pack, indent=2) + "\n")
print(f"wrote {OUT.relative_to(ROOT)} ({len(pack['items'])} items)")

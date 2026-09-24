#!/usr/bin/env python3
"""Replaces the fenced code block that follows `path`: in the plan with the file's current content."""
import pathlib, re, sys
plan = pathlib.Path(sys.argv[1]); root = pathlib.Path(sys.argv[2])
lines = plan.read_text().splitlines()
PATH_LINE = re.compile(r"^(?:Replace\s+)?`([^`]+)`(?:\s+with)?(?:\s*\([^)]*\))?(?:\s+with)?:\s*$")
for path in sys.argv[3:]:
    content = (root / path).read_text().rstrip("\n").splitlines()
    hits = [i for i, l in enumerate(lines) if (m := PATH_LINE.match(l)) and m.group(1) == path]
    if not hits:
        print(f"no block for {path}"); continue
    i = hits[-1]  # last occurrence is the authoritative version
    j = i + 1
    while lines[j].strip() == "": j += 1
    assert lines[j].startswith("```"), f"no fence after {path}"
    k = j + 1
    while not lines[k].startswith("```"): k += 1
    lines[j+1:k] = content
    print(f"synced {path} ({len(content)} lines)")
plan.write_text("\n".join(lines) + "\n")

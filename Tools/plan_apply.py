#!/usr/bin/env python3
"""Applies file blocks from the implementation plan, task by task.

A file block is a line of the form `path/to/file`: (optionally prefixed with
"Replace ... with:" wording) immediately followed by a fenced code block.
Usage: plan_apply.py PLAN ROOT --tasks 1-9 [--apply] [--task-files N]
"""
import argparse, pathlib, re, subprocess, sys

FENCE = re.compile(r"^```[\w+-]*\s*$")
PATH_LINE = re.compile(r"^(?:Replace\s+)?`([^`]+)`(?:\s+with)?(?:\s*\([^)]*\))?(?:\s+with)?:\s*$")
COMMIT = re.compile(r'git commit -m "([^"]+)"')

def parse_tasks(text):
    lines = text.splitlines()
    tasks = []
    current = None
    in_fence = False
    for i, line in enumerate(lines):
        if line.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = re.match(r"^### Task (\d+): (.*)$", line)
        if m:
            if current:
                current["end"] = i
            current = {"number": int(m.group(1)), "title": m.group(2), "start": i, "end": len(lines)}
            tasks.append(current)
        elif current and line.startswith("## "):
            current["end"] = i
            current = None
    return lines, tasks

def file_blocks(lines, start, end):
    i = start
    blocks = []
    while i < end:
        m = PATH_LINE.match(lines[i])
        if m:
            j = i + 1
            while j < end and lines[j].strip() == "":
                j += 1
            if j < end and FENCE.match(lines[j]):
                k = j + 1
                body = []
                while k < end and not lines[k].startswith("```"):
                    body.append(lines[k]); k += 1
                blocks.append((m.group(1), "\n".join(body) + "\n"))
                i = k + 1
                continue
        i += 1
    return blocks

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("plan"); ap.add_argument("root")
    ap.add_argument("--tasks", required=True)
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    lo, hi = (int(x) for x in args.tasks.split("-")) if "-" in args.tasks else (int(args.tasks),) * 2
    lines, tasks = parse_tasks(pathlib.Path(args.plan).read_text())
    root = pathlib.Path(args.root)
    for task in tasks:
        if not (lo <= task["number"] <= hi):
            continue
        section = lines[task["start"]:task["end"]]
        blocks = file_blocks(lines, task["start"], task["end"])
        commit = next((COMMIT.search(l).group(1) for l in section if COMMIT.search(l)), None)
        print(f"== Task {task['number']}: {task['title']}")
        for path, body in blocks:
            print(f"   {'write' if args.apply else 'would write'} {path} ({len(body.splitlines())} lines)")
            if args.apply:
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(body)
                if path.endswith(".sh") or path.endswith(".py"):
                    target.chmod(0o755)
        print(f"   commit: {commit}")

if __name__ == "__main__":
    main()

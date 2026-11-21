"""Pair two string sheets (from extract_strings.py) by location and print a
Markdown before/after table of every changed string.

Usage: python -I tools/copy/diff_sheet.py before.tsv after.tsv > table.md
Relies on the copy pass editing strings in place (same file:line / json path).
"""
import sys
from collections import defaultdict


def load(path):
    rows = defaultdict(list)
    with open(path, encoding="utf-8") as fh:
        next(fh)
        for line in fh:
            kind, loc, text = line.rstrip("\n").split("\t", 2)
            rows[loc].append(text)
    return rows


def cell(s):
    return s.replace("|", "\\|")


def main():
    before, after = load(sys.argv[1]), load(sys.argv[2])
    print("| Location | Before | After |")
    print("|---|---|---|")
    n = 0
    for loc in before:
        a, b = before[loc], after.get(loc, [])
        if a == b:
            continue
        if len(a) == len(b):  # same literals on the line: pair by position
            pairs = [(o, w) for o, w in zip(a, b) if o != w]
            olds, news = [p[0] for p in pairs], [p[1] for p in pairs]
        else:
            olds = [x for x in a if x not in b] or a
            news = [x for x in b if x not in a] or b
        for i in range(max(len(olds), len(news))):
            o = olds[i] if i < len(olds) else ""
            w = news[i] if i < len(news) else ""
            print(f"| `{loc}` | {cell(o)} | {cell(w)} |")
            n += 1
    print(f"\n{n} changed strings.", file=sys.stderr)


if __name__ == "__main__":
    main()

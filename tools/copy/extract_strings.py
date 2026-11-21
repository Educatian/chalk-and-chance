"""Export every player-facing string in the English game to one TSV sheet.

Usage (from repo root):  python -I tools/copy/extract_strings.py [out.tsv]
Columns: kind  location  text
  kind = gd | json
  location = file:line for GDScript, file#json.path for data files.
Heuristic, not a parser: it errs toward including a string. Dev logs,
dictionary keys, ids, paths, LLM-prompt-only persona fields and the
classifier keyword lists (LLMClient._classify_stub_text) are skipped.
"""
import json, os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GD_DIRS = ["scenes", "scripts", "autoload"]
SKIP_GD_DIRS = [os.path.join("scenes", "dev")]
# Lines that are never shown to the player.
SKIP_LINE = re.compile(r"print\(|printerr\(|push_warning\(|push_error\(|preload\(|load\(|get_node|"
                       r"has_node|res://|user://|emit_signal|Telemetry\.|\.connect\(|has_method|"
                       r"add_to_group|is_in_group|Input\.|get_meta|set_meta|find_child|"
                       r"ProjectSettings|OS\.get|headers|\.find\(\"")
STR = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
IDENT = re.compile(r"^[A-Za-z0-9_./:#%+-]*$")
# JSON keys whose values are ids/config or LLM-prompt material, not text the player reads.
JSON_SKIP_KEYS = {"id", "persona_id", "badge", "format", "mode", "arrangement", "requires", "metric",
                  "backdrop", "backdrop_thumb", "grade_band", "subject_context", "emotion_baseline",
                  "speaker", "mood", "portrait", "color", "_doc", "win_moves", "steps", "seat",
                  "knowledge_state", "hidden_need", "escalation_triggers", "deescalation_moves",
                  "answer_flip_policy", "behavior_tendencies", "traits", "voice", "region_id",
                  "move", "tag", "tags", "skill", "construct", "kind", "type", "icon", "sprite"}
JSON_DIRS = ["data/scenarios", "data/persona_library", "data/narrative"]


def gd_rows():
    for d in GD_DIRS:
        for dp, _, fs in os.walk(os.path.join(ROOT, d)):
            rel_dir = os.path.relpath(dp, ROOT)
            if any(rel_dir.startswith(s) for s in SKIP_GD_DIRS):
                continue
            for f in sorted(fs):
                if not f.endswith(".gd"):
                    continue
                path = os.path.join(dp, f)
                rel = os.path.relpath(path, ROOT).replace("\\", "/")
                in_classifier = False
                for n, line in enumerate(open(path, encoding="utf-8"), 1):
                    s = line.strip()
                    if s.startswith("func ") or s.startswith("static func "):
                        in_classifier = "_classify_stub_text" in s
                    if in_classifier or s.startswith("#") or SKIP_LINE.search(s):
                        continue
                    for m in STR.finditer(line):
                        t = m.group(1)
                        tail = line[m.end():m.end() + 2].lstrip()
                        if tail.startswith(":") and IDENT.match(t):
                            continue  # dictionary key
                        if not re.search(r"[A-Za-z]{2}", t):
                            continue
                        if IDENT.match(t) and not re.match(r"^([A-Z][a-z]|[A-Z]{3,}$)", t):
                            continue  # snake_case id / tag (Capitalized words and HEADERS kept)
                        yield ("gd", f"{rel}:{n}", t)


def json_walk(node, path, skip=False):
    if isinstance(node, dict):
        for k, v in node.items():
            yield from json_walk(v, f"{path}.{k}", skip or k in JSON_SKIP_KEYS)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from json_walk(v, f"{path}[{i}]", skip)
    elif isinstance(node, str) and not skip and re.search(r"[A-Za-z]{2}", node) and not node.startswith("res://"):
        yield path, node


def json_rows():
    for d in JSON_DIRS:
        for f in sorted(os.listdir(os.path.join(ROOT, d))):
            if f.endswith(".json"):
                rel = f"{d}/{f}"
                with open(os.path.join(ROOT, rel), encoding="utf-8") as fh:
                    data = json.load(fh)
                for p, t in json_walk(data, ""):
                    yield ("json", f"{rel}#{p.lstrip('.')}", t)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "tools", "copy", "strings.tsv")
    rows = list(gd_rows()) + list(json_rows())
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("kind\tlocation\ttext\n")
        for r in rows:
            fh.write("\t".join(x.replace("\t", " ") for x in r) + "\n")
    print(f"{len(rows)} strings -> {out}")


if __name__ == "__main__":
    main()

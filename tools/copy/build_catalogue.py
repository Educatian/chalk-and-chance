"""Build i18n/ui_<lang>.json from translator TSVs (english<TAB>translated).

    python -I tools/copy/build_catalogue.py ko path/to/a.tsv path/to/b.tsv ...

Cells are GDScript source literals (as tools/copy/extract_strings.py exports them), so
escapes (\\" \\n \\t \\\\) are decoded to the runtime text before they become keys.
A later file overrides an earlier one for the same key (pass the hand-written
supplement last); overrides are reported.
"""
import json
import sys

BS = chr(92)
ESC = {'n': '\n', 't': '\t', '"': '"', BS: BS, "'": "'"}


def unesc(s):
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == BS and i + 1 < len(s):
            out.append(ESC.get(s[i + 1], c + s[i + 1]))
            i += 2
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def main():
    lang, paths = sys.argv[1], sys.argv[2:]
    cat, conflicts = {}, []
    for p in paths:
        with open(p, encoding='utf8') as f:
            next(f)
            for line in f:
                cells = line.rstrip('\n').split('\t')
                if len(cells) < 2 or not cells[1].strip():
                    continue
                en, tr = unesc(cells[0]), unesc(cells[1])
                if en in cat and cat[en] != tr:
                    conflicts.append(en)   # a later file overrides (the supplement goes last)
                cat[en] = tr
    with open('i18n/ui_%s.json' % lang, 'w', encoding='utf8', newline='\n') as f:
        json.dump(cat, f, ensure_ascii=False, indent=0, sort_keys=True)
    print('entries', len(cat), 'conflicts', len(conflicts))
    for c in conflicts[:10]:
        print('  overridden:', repr(c))


if __name__ == '__main__':
    main()

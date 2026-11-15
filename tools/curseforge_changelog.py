# Baut den Changelog für CurseForge: der Abschnitt einer Version aus allen CHANGELOG*.md, Sprachen untereinander.
# Aufruf: python3 tools/curseforge_changelog.py <Version> <Ausgabedatei>
# Bricht ab, wenn eine Sprache den Abschnitt nicht hat, damit kein Release mit unvollständigem Changelog entsteht.
import os, sys

VERSION, OUT = sys.argv[1], sys.argv[2]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = [('CHANGELOG.md', 'English'), ('CHANGELOG.de.md', 'Deutsch'), ('CHANGELOG.fr.md', 'Français'),
         ('CHANGELOG.es.md', 'Español'), ('CHANGELOG.pt-BR.md', 'Português'), ('CHANGELOG.it.md', 'Italiano'),
         ('CHANGELOG.ru.md', 'Русский'), ('CHANGELOG.ko.md', '한국어'), ('CHANGELOG.zh-CN.md', '简体中文'),
         ('CHANGELOG.zh-TW.md', '繁體中文')]

def section(path):
    lines = open(os.path.join(ROOT, path), encoding='utf8').read().splitlines()
    out, inside = [], False
    for line in lines:
        if line.startswith('## '):
            head = line[3:].strip()
            if inside: break
            inside = head == VERSION or head.startswith(VERSION + ' ')
            continue
        if inside: out.append(line)
    return '\n'.join(out).strip() if inside else None

parts, missing = [], []
for path, name in LANGS:
    body = section(path) if os.path.exists(os.path.join(ROOT, path)) else None
    if not body: missing.append(path)
    else: parts.append(f'### {name}\n\n{body}')
if missing:
    sys.exit(f'Changelog für {VERSION} fehlt in: {", ".join(missing)}')
open(OUT, 'w', encoding='utf8', newline='\n').write(f'# BerufeTracker {VERSION}\n\n' + '\n\n'.join(parts) + '\n')
print(f'{OUT}: {len(parts)} Sprachen')

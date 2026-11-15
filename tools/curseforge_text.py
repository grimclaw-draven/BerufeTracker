# Texte für CurseForge im gleichen Format: Klartext, alle Sprachen untereinander, getrennt durch eine Strichlinie.
#   python3 tools/curseforge_text.py description <Ausgabedatei>          Projektbeschreibung aus README.md + readme/<Sprache>.md
#   python3 tools/curseforge_text.py changelog <Version> <Ausgabedatei>  Changelog einer Version aus CHANGELOG.md + changelog/<Sprache>.md
# Beim Changelog bricht das Skript ab, wenn eine Sprache den Abschnitt der Version nicht hat.
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Englisch liegt im Hauptordner, die anderen Sprachen in readme/ und changelog/
LANGS = [(None, 'English'), ('de', 'Deutsch'), ('fr', 'Français'), ('es', 'Español'), ('pt-BR', 'Português'),
         ('it', 'Italiano'), ('ru', 'Русский'), ('ko', '한국어'), ('zh-CN', '简体中文'), ('zh-TW', '繁體中文')]

def path_of(kind, code):
    return f'{kind.upper()}.md' if code is None else f'{kind}/{code}.md'
SEP = '\n\n\n--------------------------------------------------\n\n\n'
OTHERS = ' · '.join(name for _, name in LANGS[1:])

def plain(lines):
    """Markdown -> Klartext: Links zu Text, ohne Fett/Code/Überschriftenzeichen/Aufzählungsstriche."""
    out = []
    for l in lines:
        l = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', l)
        l = l.replace('**', '').replace('`', '')
        l = re.sub(r'^#+\s*', '', l)
        l = re.sub(r'^\*(.*)\*$', r'\1', l)
        l = re.sub(r'^- ', '', l)
        out.append(l)
    return re.sub(r'\n{3,}', '\n\n', '\n'.join(out)).strip()

def read(name):
    return open(os.path.join(ROOT, name), encoding='utf8').read().splitlines()

def join(sections):
    parts = []
    for index, (title, name, body) in enumerate(sections):
        note = f'\n\n(More languages below: {OTHERS})' if index == 0 else ''
        parts.append(f'{title}  ({name}){note}\n\n{body}')
    return SEP.join(parts) + '\n'

def description():
    sections = []
    for suffix, name in LANGS:
        lines = read(path_of('readme', suffix))
        body = plain(lines[3:])          # Zeile 1 Titel, Zeile 3 Sprachleiste mit Links zu den anderen Dateien
        sections.append(('BerufeTracker', name, body))
    return join(sections)

def changelog(version):
    sections, missing = [], []
    for suffix, name in LANGS:
        path = path_of('changelog', suffix)
        lines = read(path) if os.path.exists(os.path.join(ROOT, path)) else []
        body, inside = [], False
        for line in lines:
            if line.startswith('## '):
                head = line[3:].strip()
                if inside: break
                inside = head == version or head.startswith(version + ' ')
                continue
            if inside: body.append(line)
        text = plain(body)
        if not text: missing.append(path)
        else: sections.append((f'BerufeTracker {version}', name, text))
    if missing:
        sys.exit(f'Changelog für {version} fehlt in: {", ".join(missing)}')
    return join(sections)

if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == 'description': text, out = description(), sys.argv[2]
    elif mode == 'changelog': text, out = changelog(sys.argv[2]), sys.argv[3]
    else: sys.exit('description <Datei> | changelog <Version> <Datei>')
    open(out, 'w', encoding='utf8', newline='\n').write(text)
    print(f'{out}: {len(text)} Zeichen')

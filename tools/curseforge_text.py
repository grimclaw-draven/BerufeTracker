# Texte für Releases und CurseForge.
#   python3 tools/curseforge_text.py description <Ausgabedatei>
#       CurseForge-Projektbeschreibung: alle READMEs als Klartext untereinander, getrennt durch eine Strichlinie.
#   python3 tools/curseforge_text.py description-md <Ausgabedatei>
#       Dasselbe als Markdown (bei CurseForge Beschreibungsart "Markdown" wählen und einfügen).
#   python3 tools/curseforge_text.py changelog <Version> <Ausgabedatei>
#       CurseForge-Changelog: der komplette Changelog jeder Sprache untereinander (Klartext mit Aufzählungspunkten).
#       Bricht ab, wenn eine Sprache den Abschnitt der neuen Version noch nicht hat.
#   python3 tools/curseforge_text.py release-notes <Version> <Ausgabedatei>
#       GitHub-Release: nur Englisch, nur diese Version (Markdown), darunter Links zu den anderen Sprachen.
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.environ.get('GITHUB_REPOSITORY') or 'grimclaw-draven/BerufeTracker'
# Englisch liegt im Hauptordner, die anderen Sprachen in readme/ und changelog/
LANGS = [(None, 'English'), ('de', 'Deutsch'), ('fr', 'Français'), ('es', 'Español'), ('pt-BR', 'Português'),
         ('it', 'Italiano'), ('ru', 'Русский'), ('ko', '한국어'), ('zh-CN', '简体中文'), ('zh-TW', '繁體中文')]
SEP = '\n\n\n--------------------------------------------------\n\n\n'
OTHERS = ' · '.join(name for _, name in LANGS[1:])

def path_of(kind, code):
    return f'{kind.upper()}.md' if code is None else f'{kind}/{code}.md'

def read(name):
    path = os.path.join(ROOT, name)
    return open(path, encoding='utf8').read().splitlines() if os.path.exists(path) else []

def plain(lines, bullets=False):
    """Markdown -> Klartext: Links zu Text, ohne Fett/Code/Überschriftenzeichen; Aufzählungspunkte wahlweise behalten."""
    out = []
    for l in lines:
        l = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', l)
        l = l.replace('**', '').replace('`', '')
        l = re.sub(r'^#+\s*', '', l)
        l = re.sub(r'^\*(.*)\*$', r'\1', l)
        if not bullets: l = re.sub(r'^- ', '', l)
        out.append(l)
    return re.sub(r'\n{3,}', '\n\n', '\n'.join(out)).strip()

def join(sections):
    parts = []
    for index, (title, name, body) in enumerate(sections):
        note = f'\n\n(More languages below: {OTHERS})' if index == 0 else ''
        parts.append(f'{title}  ({name}){note}\n\n{body}')
    return SEP.join(parts) + '\n'

def version_section(lines, version):
    """Zeilen des Abschnitts '## <version> ...' ohne die Überschrift; None, wenn es ihn nicht gibt."""
    body, inside = [], False
    for line in lines:
        if line.startswith('## '):
            if inside: break
            head = line[3:].strip()
            inside = head == version or head.startswith(version + ' ')
            continue
        if inside: body.append(line)
    text = '\n'.join(body).strip()
    return text if inside and text else None

def description():
    sections = []
    for code, name in LANGS:
        lines = read(path_of('readme', code))
        sections.append(('BerufeTracker', name, plain(lines[3:])))  # Zeile 1 Titel, Zeile 3 Sprachleiste
    return join(sections)

def absolute_links(line):
    """Relative Links der READMEs (z. B. readme/de.md) zeigen bei CurseForge ins Leere: auf GitHub umbiegen."""
    return re.sub(r'\]\((?!https?://|#)([^)]+)\)', lambda m: f'](https://github.com/{REPO}/blob/main/{m.group(1)})', line)

def description_md():
    """CurseForge-Projektbeschreibung als Markdown (Beschreibungsart "Markdown"): alle READMEs untereinander."""
    parts = []
    for index, (code, name) in enumerate(LANGS):
        lines = [absolute_links(l) for l in read(path_of('readme', code))[3:]]  # Zeile 1 Titel, Zeile 3 Sprachleiste
        body = re.sub(r'\n{3,}', '\n\n', '\n'.join(lines)).strip()
        note = f'\n\n*More languages below: {OTHERS}*' if index == 0 else ''
        parts.append(f'# BerufeTracker ({name}){note}\n\n{body}')
    return '\n\n---\n\n'.join(parts) + '\n'

def changelog(version):
    sections, missing = [], []
    for code, name in LANGS:
        path = path_of('changelog', code)
        lines = read(path)
        if not version_section(lines, version):
            missing.append(path)
            continue
        body = [l for l in lines if not l.startswith('# ')]  # Titel "# Changelog" weglassen
        sections.append(('BerufeTracker', name, plain(body, bullets=True)))
    if missing:
        sys.exit(f'Changelog für {version} fehlt in: {", ".join(missing)}')
    return join(sections)

def release_notes(version):
    english = version_section(read('CHANGELOG.md'), version)
    if not english:
        sys.exit(f'Changelog für {version} fehlt in: CHANGELOG.md')
    links = ' · '.join(f'[{name}](https://github.com/{REPO}/blob/{version}/changelog/{code}.md)' for code, name in LANGS[1:])
    return f'{english}\n\nChangelog in other languages: {links}\n'

if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == 'description': text, out = description(), sys.argv[2]
    elif mode == 'description-md': text, out = description_md(), sys.argv[2]
    elif mode == 'changelog': text, out = changelog(sys.argv[2]), sys.argv[3]
    elif mode == 'release-notes': text, out = release_notes(sys.argv[2]), sys.argv[3]
    else: sys.exit('description <Datei> | changelog <Version> <Datei> | release-notes <Version> <Datei>')
    open(out, 'w', encoding='utf8', newline='\n').write(text)
    print(f'{out}: {len(text)} Zeichen')

"""Baut das Release-ZIP für CurseForge.

Aufruf: python -I tools/build_release.py "<Addon-Ordner>"
Ergebnis: <Addon-Ordner>/dev/dist/BerufeTracker-<Version>.zip mit dem Ordner BerufeTracker/.
Nimmt nur, was die .toc lädt, plus LICENSE.md, README.md und CHANGELOG.md.
Seed.lua wird durch eine leere Fassung ersetzt: die eigenen Charakterdaten bleiben lokal.
"""
import os, re, sys, zipfile

A = sys.argv[1]
NAME = 'BerufeTracker'
toc = open(os.path.join(A, NAME + '.toc'), encoding='utf8').read()
version = re.search(r'^## Version:\s*(\S+)', toc, re.M).group(1)
if version.startswith('@'):  # Platzhalter für den Packager: lokal die Version aus dem letzten Git-Tag nehmen
    import subprocess
    try:
        version = subprocess.run(['git', '-C', A, 'describe', '--tags', '--always'], capture_output=True, text=True, check=True).stdout.strip()
    except Exception:
        version = 'dev'
    toc = toc.replace('@project-version@', version)
files = [l.strip() for l in toc.splitlines() if l.strip() and not l.startswith('#')]
EMPTY_SEED = '''-- Startwerte für Skills, bis sich ein Charakter mit dem Addon einloggt. In der Veröffentlichung leer.
local _, BT = ...
BT.SEED_SKILLS = {}
BT.SEED_CAPS = {}
'''

# Schutz: keine eigenen Daten oder Entwicklungsdateien im Paket
# Eigene Namen und Pfade, die nie im Paket landen dürfen: eine pro Zeile in dev/private.txt (nicht im Repo).
words = ['AppData', 'scratchpad']
private_list = os.path.join(A, 'dev', 'private.txt')
if os.path.isfile(private_list):
    words += [w.strip() for w in open(private_list, encoding='utf8') if w.strip()]
private = re.compile('|'.join(re.escape(w) for w in words), re.I)
problems = []
for f in files:
    if f == 'Seed.lua': continue
    path = os.path.join(A, f)
    if not os.path.isfile(path): problems.append('fehlt: ' + f)
    elif private.search(open(path, encoding='utf8').read()): problems.append('private Daten in ' + f)
for f in ['LICENSE.md', 'README.md', 'CHANGELOG.md']:
    if not os.path.isfile(os.path.join(A, f)): problems.append('fehlt: ' + f)
if problems:
    sys.exit('Abbruch:\n  ' + '\n  '.join(problems))

out_dir = os.path.join(A, 'dev', 'dist')
os.makedirs(out_dir, exist_ok=True)
out = os.path.join(out_dir, f'{NAME}-{version}.zip')
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr(f'{NAME}/{NAME}.toc', toc)
    for f in files:
        if f == 'Seed.lua':
            z.writestr(f'{NAME}/Seed.lua', EMPTY_SEED)
        else:
            z.write(os.path.join(A, f), f'{NAME}/{f}')
    for f in ['LICENSE.md', 'README.md', 'CHANGELOG.md']:
        z.write(os.path.join(A, f), f'{NAME}/{f}')
with zipfile.ZipFile(out) as z:
    for i in z.infolist(): print(f'{i.file_size:>9}  {i.filename}')
print('\n' + out, os.path.getsize(out), 'Bytes')

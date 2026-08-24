#!/usr/bin/env python3
"""Welche Dart-Dateien sind von main.dart aus überhaupt erreichbar?

Hintergrund: am 2026-08-23 waren 40 von 97 Dateien (41 %) an kein Menü
gehängt — darunter ganze Module und, unbemerkt, die Impressumsleiste samt
der einzigen Stelle, die je `checkForUpdate()` aufrief. Toter Code sieht im
Editor aus wie lebender; nur dieser Lauf trennt beides.

Aufruf:  python3 tools/erreichbarkeit.py [projektwurzel]
Rückgabe: 0 wenn nichts Neues tot ist, 1 wenn die Liste gewachsen ist.
"""
import collections
import os
import re
import sys

# Stand nach dem Zuschnitt auf die Rolle. Wächst die Zahl, hängt etwas Neues
# in der Luft — dann entweder verdrahten, löschen oder in CLAUDE.md begründen.
#
# Verlauf, damit die Zahl nicht wie Nachlässigkeit aussieht:
#   40  Ausgangslage 2026-08-23 — niemand wusste, was davon Absicht war
#   19  nach dem Aufräumen: vier Module ans Menü, alter Login gelöscht
#   44  nach dem Zuschnitt 2026-08-24 — Vereinverwaltung, Archiv,
#       Routineaufgaben, Statistik und Dienste gehören in die Vorsitzer-App
#       und wurden hier abgehängt. Der Sprung ist gewollt: die Dateien
#       bleiben liegen, statt sie zu löschen, solange nicht entschieden ist,
#       ob sie drüben gebraucht werden.
ERWARTET_GEPARKT = 44


def main() -> int:
    wurzel = sys.argv[1] if len(sys.argv) > 1 else '.'
    lib = os.path.join(wurzel, 'lib')
    if not os.path.isdir(lib):
        print(f'kein lib/ unter {wurzel!r}', file=sys.stderr)
        return 2

    dateien = {}
    for ordner, _, namen in os.walk(lib):
        for n in namen:
            # `.bak`-Kopien sind Arbeitsstände, kein Programm.
            if n.endswith('.dart') and '.bak' not in n:
                # normpath, damit die Schlüssel zu den aufgelösten
                # Import-Pfaden passen: bei Aufruf mit '.' liefert walk
                # './lib/x.dart', normpath aber 'lib/x.dart'.
                p = os.path.normpath(os.path.join(ordner, n))
                with open(p, encoding='utf-8', errors='ignore') as f:
                    dateien[p] = f.read()

    graph = collections.defaultdict(set)
    for p, quelle in dateien.items():
        d = os.path.dirname(p)
        for m in re.finditer(r"import\s+'([^']+\.dart)'", quelle):
            ziel = m.group(1)
            if ziel.startswith(('package:', 'dart:')):
                continue
            q = os.path.normpath(os.path.join(d, ziel))
            if q in dateien:
                graph[p].add(q)

    start = os.path.normpath(os.path.join(lib, 'main.dart'))
    gesehen, rand = {start}, [start]
    while rand:
        for nachbar in graph[rand.pop()]:
            if nachbar not in gesehen:
                gesehen.add(nachbar)
                rand.append(nachbar)

    geparkt = sorted(set(dateien) - gesehen)
    anteil = round(100 * len(geparkt) / len(dateien)) if dateien else 0
    print(f'{len(dateien)} Dateien · {len(gesehen)} erreichbar · '
          f'{len(geparkt)} geparkt ({anteil} %)')
    for p in geparkt:
        print('   ', os.path.relpath(p, wurzel))

    if len(geparkt) > ERWARTET_GEPARKT:
        print(f'\nNEU GEPARKT: {len(geparkt) - ERWARTET_GEPARKT} Datei(en) mehr '
              f'als die dokumentierten {ERWARTET_GEPARKT}.')
        print('Verdrahten, löschen — oder in CLAUDE.md begründen '
              'und ERWARTET_GEPARKT anheben.')
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

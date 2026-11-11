# BerufeTracker

Wie viel Kupfererz, Leinenstoff und Friedensblume brauchst du noch, um deine Berufe auf 300 zu bringen? BerufeTracker rechnet es aus: für alle Berufe, bis hinunter zu den Grundmaterialien und über alle deine Charaktere und Banken hinweg.

Für **WoW Forever**, deutscher Client.

*English: Shows the remaining materials to level every profession to 300, broken down to base materials and counted across all your characters and banks. The interface is German only and node tooltips need a German client.*

## Funktionen

**Materialien**
- Gesamtbedarf aller Berufe, aufgelöst bis zu den Grundmaterialien. Ein Bronzebarren zählt zum Beispiel als Kupfer- und Zinnbarren und diese wiederum als Erz.
- Gegengerechnet wird, was du in Taschen, Bank und Post aller Charaktere hast. Wenn [BagBrother/Bagnon](https://www.curseforge.com/wow/addons/bagnon) installiert ist, kommen auch Charaktere dazu, die BerufeTracker noch nicht kennt.
- Du kannst nach allen Berufen, nach gelernten Berufen oder nach einem bestimmten Charakter filtern und Sammelberufe ausschließen.
- Beim Drüberfahren siehst du den Bedarf je Beruf, Preis und Kaufkosten, die Verteilung auf deine Charaktere und woher du das Material bekommst: Vorkommen mit Zonen, Gegner mit Stufen und die nächsten Händler deiner Fraktion.
- Mit dem Auktionshaus-Scan siehst du, was es kosten würde, alles zu kaufen statt selbst zu farmen.

**Route**
- Die Schritt-für-Schritt-Route jedes Berufs mit dem Stand, wie viel davon noch offen ist.
- Guides sind wählbar: Metabot, RankedBoost, Wowhead, wowtbc.gg, GoldGoblin und wow-professions, je Beruf oder für alle gemeinsam.
- Fehlende Rezepte sind mit Fundort markiert.
- Lehrer-Besuche erscheinen an der richtigen Stelle der Route, mit dem nächstgelegenen Lehrer, der dir die nächste Stufe beibringt.

**Wegpunkte**
- Strg+Linksklick auf einen Lehrer oder ein Material setzt einen Wegpunkt zum nächsten Lehrer oder Händler.
- Eine Leiste mit Richtungspfeil und Beschreibung zeigt das Ziel. Ein Klick darauf öffnet die Karte beim Ziel.
- Auch auf der Karte steht eine Beschriftung. Wenn du die Kartenmarkierung im Chat teilst, wird die Beschreibung mitgeschickt.
- Der Wegpunkt verschwindet, sobald du mit dem NPC sprichst.

**Im Spiel**
- Item-Tooltips (Taschen, Bank, Auktionshaus, Beute) zeigen, wie viel du nach deinem aktuellen Filter noch brauchst.
- Erzadern und Kräuter in der Welt zeigen, was du daraus noch brauchst.

## Bedienung

- `/berufe` oder der Minimap-Button öffnen das Fenster.
- Für die Preise öffnest du das Auktionshaus und klickst auf „Preise scannen“ (oder `/berufe scan`).
- `/berufe skill <Beruf> <Wert>` setzt einen Skill von Hand, falls er nicht erkannt wird. Ohne Wert gilt wieder die automatische Erkennung.
- Jeder Charakter muss sich einmal mit dem Addon einloggen, damit seine Berufe bekannt sind. Seine Bank wird erfasst, sobald du sie einmal öffnest.

## Grenzen

- Die Oberfläche ist nur auf Deutsch. Die Erkennung von Erzadern und Kräutern in der Welt funktioniert nur mit einem deutschen Client.
- Entfernungen sind Luftlinie und gelten nur auf demselben Kontinent.
- Nicht für jedes Rezept ist ein Fundort bekannt.
- Händler- und Fundortdaten stammen aus der QuestieDB. Sie können einzelne Fehler enthalten.

## Quellen und Dank

- **Routen:** [Metabot](https://metabot.gg/en/wow-forever/professions), [RankedBoost](https://rankedboost.com/world-of-warcraft/forever/), [Wowhead](https://www.wowhead.com/forever/profession-leveling-guides), [wowtbc.gg](https://wowtbc.gg/warcraftforever/), [GoldGoblin](https://classic.goldgoblin.net/berufe/) und [wow-professions](https://www.wow-professions.com/forever/). Die Routen wurden für das Addon zusammengefasst. Die vollständigen Guides mit allen Erklärungen findest du auf den jeweiligen Seiten, der Link steht im Addon bei der Guide-Auswahl.
- **Lehrer, Händler und Fundorte** wurden aus der QuestieDB (GPLv3) erzeugt. Danke an das Questie-Team und alle Mitwirkenden. BerufeTracker ist kein Projekt des Questie-Teams.

## Lizenz

GPLv3, siehe `LICENSE.md`.

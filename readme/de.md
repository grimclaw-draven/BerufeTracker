# BerufeTracker

[English](../README.md) · [Deutsch](de.md) · [Français](fr.md) · [Español](es.md) · [Português](pt-BR.md) · [Italiano](it.md) · [Русский](ru.md) · [한국어](ko.md) · [简体中文](zh-CN.md) · [繁體中文](zh-TW.md)

Wie viel Kupfererz, Leinenstoff und Friedensblume brauchst du noch, um deine Berufe auf 300 zu bringen? BerufeTracker rechnet es aus: für alle Berufe, bis hinunter zu den Grundmaterialien und über alle deine Charaktere und Banken hinweg.

Für **WoW Forever**, in der Sprache deines Spiel-Clients: Englisch, Deutsch, Französisch, Spanisch, Portugiesisch, Italienisch, Russisch, Koreanisch und Chinesisch (vereinfacht und traditionell).

## Funktionen

**Materialien**
- Gesamtbedarf aller Berufe, aufgelöst bis zu den Grundmaterialien. Ein Bronzebarren zählt zum Beispiel als Kupfer- und Zinnbarren und diese wiederum als Erz.
- Gegengerechnet wird, was du in Taschen, Bank und Post aller Charaktere deiner aktuellen Fraktion hast. Wenn [BagBrother/Bagnon](https://www.curseforge.com/wow/addons/bagnon) installiert ist, kommen auch Charaktere dazu, die BerufeTracker noch nicht kennt.
- Filter: „Aktueller Charakter“ (Standard) zeigt nur die Berufe des eingeloggten Charakters. „Alle Charaktere (gelernte Berufe)“ zählt jeden Charakter deiner Fraktion mit seinen eigenen Berufen und seinem Skill zusammen. „Gelernte Berufe (bester Charakter)“ zählt jeden gelernten Beruf einmal, „Alle Berufe (auch ungelernte)“ jeden Beruf einmal, ungelernte ab Skill 1, oder du wählst einen einzelnen Charakter. Die Route zeigt nur die Berufe der Auswahl; bei einem Charakter stehen noch nicht gelernte Berufe nur mit ihrem ersten Lehrer da. Sammelberufe lassen sich ausschließen.
- Beim Drüberfahren siehst du den Bedarf je Beruf, Preis und Kaufkosten, die Verteilung auf deine Charaktere und woher du das Material bekommst: Vorkommen mit Zonen, Gegner mit Stufen und die nächsten Händler deiner Fraktion.
- Mit dem Auktionshaus-Scan siehst du, was es kosten würde, alles zu kaufen statt selbst zu farmen. Materialien und Route zeigen dieselben Kaufkosten, inklusive Lehrer und Rezepte.

**Route**
- Die Schritt-für-Schritt-Route jedes Berufs mit dem Stand, wie viel davon noch offen ist.
- Guides sind wählbar: Metabot, RankedBoost, Wowhead, wowtbc.gg, GoldGoblin und wow-professions, je Beruf oder für alle gemeinsam.
- **Günstigster berechneter Weg:** eigener Guide, unabhängig von den anderen Guides. Er wählt für jeden Skillpunkt das billigste aller Rezepte des Berufs (Forever-Spieldaten), nach Rezeptfarbe und Chance auf einen Skillpunkt, mit Auktionshaus-, Händler-, Lehrer- und Rezeptpreisen. Gelernte Rezepte und vorhandene Materialien zählen gratis; Händlerware mit begrenztem Vorrat zählt nur, wenn sie im Auktionshaus zu haben ist; Rezepte mit Abklingzeit bleiben außen vor. **Günstigster Guide-Weg** macht dasselbe mit den Schritten der anderen Guides. **Schnellster berechneter Weg** wählt die Rezepte mit der kürzesten Herstellzeit und rechnet auch Abklingzeiten von Materialien wie Mondstoff ein. Die eigenen Wege sind nie teurer als einer der anderen Guides und werden beim Öffnen des Fensters neu berechnet.
- Jeder Guide zeigt Herstellzeit und Kosten ab deinem aktuellen Skill; die Guide-Menüs vergleichen die Kosten aller Guides.
- Fehlende Rezepte sind mit Fundort markiert.
- Lehrer-Besuche erscheinen an der richtigen Stelle der Route, mit dem nächstgelegenen Lehrer, der dir die nächste Stufe beibringt.

**Wegpunkte**
- Strg+Linksklick auf einen Lehrer oder ein Material setzt einen Wegpunkt zum nächsten Lehrer oder Händler.
- Eine Leiste mit Richtungspfeil und Beschreibung zeigt das Ziel. Ein Klick darauf öffnet die Karte beim Ziel.
- Auch auf der Karte steht eine Beschriftung. Wenn du die Kartenmarkierung im Chat teilst, wird die Beschreibung mitgeschickt.
- Der Wegpunkt verschwindet, sobald du mit dem NPC sprichst.

**Im Spiel**
- Item-Tooltips (Taschen, Bank, Auktionshaus, Beute) zeigen, wie viel du nach deinem aktuellen Filter noch brauchst.
- Erzadern und Kräuter in der Welt zeigen, was du daraus noch brauchst und wie oft du ungefähr noch sammeln solltest: bis sie grau werden und für deine Berufe.
- **Erze/Kräuter hervorheben** (Tab Materialien oder `/berufe glitzern`): Kräuter und Erzadern in der Nähe leuchten, hell, wenn du das Material brauchst oder Sammeln noch Skillpunkte bringt, sonst grau. Bleibt aus, solange PÄNIK Gildentools oder ein anderes Addon das schon macht.
- Gegner zeigen, welche deiner benötigten Materialien sie fallen lassen, dazu Stoff von Humanoiden und Leder von Wildtieren (Kürschnern) ihrer Stufe.
- Waffen und Rüstung zeigen, welches Verzauberungsmaterial Entzaubern ungefähr ergibt, wenn du es brauchst.
- Das Berufsfenster des Spiels umrahmt das Rezept, das deine Route als Nächstes empfiehlt; beim Drüberfahren siehst du, welcher Guide es empfiehlt, die benötigten Materialien und welche Charaktere sie haben.

**Fenster**
- Tab Charaktere: Stufe, Gilde, Gold, Berufe und Materialien jedes Charakters; Gildenbanken stehen in der Reihenfolge der Charaktere ihrer Gilde. Du wählst, wessen Bestand mitzählt.
- Das Fenster lässt sich in der Größe ändern; aufgeklappte Berufe merkt es sich je Charakter.

## Bedienung

- `/berufe` oder der Minimap-Button öffnen das Fenster.
- Für die Preise öffnest du das Auktionshaus und klickst auf „Preise scannen“ (oder `/berufe scan`).
- `/berufe skill <Beruf> <Wert>` setzt einen Skill von Hand, falls er nicht erkannt wird. Ohne Wert gilt wieder die automatische Erkennung.
- Jeder Charakter muss sich einmal mit dem Addon einloggen, damit seine Berufe bekannt sind. Seine Bank wird erfasst, sobald du sie einmal öffnest.

## Grenzen

- Namen von Items, Lehrern, Händlern und Vorkommen kommen aus dem Spiel und aus der QuestieDB. Bei Italienisch und bei den wenigen Rezepten ohne hergestelltes Item (etwa Verzauberungen) stehen sie auf Englisch. Fundorte von Rezepten gibt es nur auf Deutsch und Englisch.
- Entfernungen sind Luftlinie und gelten nur auf demselben Kontinent.
- Nicht für jedes Rezept ist ein Fundort bekannt.
- Händler- und Fundortdaten stammen aus der QuestieDB. Sie können einzelne Fehler enthalten.

## Quellen und Dank

- **Routen:** [Metabot](https://metabot.gg/en/wow-forever/professions), [RankedBoost](https://rankedboost.com/world-of-warcraft/forever/), [Wowhead](https://www.wowhead.com/forever/profession-leveling-guides), [wowtbc.gg](https://wowtbc.gg/warcraftforever/), [GoldGoblin](https://classic.goldgoblin.net/berufe/) und [wow-professions](https://www.wow-professions.com/forever/). Die Routen wurden für das Addon zusammengefasst. Die vollständigen Guides mit allen Erklärungen findest du auf den jeweiligen Seiten, der Link steht im Addon bei der Guide-Auswahl.
- **Lehrer, Händler und Fundorte** wurden aus der QuestieDB (GPLv3) erzeugt. Danke an das Questie-Team und alle Mitwirkenden. BerufeTracker ist kein Projekt des Questie-Teams.
- **Beutechancen und Mengen** der Gegner stammen aus der [cMaNGOS-Classic-Datenbank](https://github.com/cmangos/classic-db) (GPLv3). Es sind Werte aus Classic 1.12, in WoW Forever können sie abweichen.
- **Rezepte, Farbgrenzen und Reagenzien** für den „Günstigsten berechneten Weg“ stammen aus den Spieldaten von WoW Forever über [wago.tools](https://wago.tools); Lehrerkosten und Händlervorrat aus der cMaNGOS-Classic-Datenbank.

## Lizenz

GPLv3, siehe `LICENSE.md`.

# Changelog

## 1.5.0

- Sammelgebiete: Unter Kräuterkunde, Bergbau, Kürschnerei und Angeln zeigt die Route die besten Karten für deinen aktuellen Skill nach Dichte und Nähe, mit dem Skill-Bereich, in dem sie sich lohnen, und eingefärbt nach Schwierigkeit. Klick öffnet die Karte, Rechtsklick blendet alles wieder aus
- Weltkarte: Fundpunkte und Rundweg für deine Sammelberufe auf jeder Zonenkarte und auf der Minimap; Kräuter als Quadrate, Erze als Rauten
- Auswahlfeld auf der Weltkarte (Knopf unten links): Kräuterkunde und Bergbau ein/aus, gemeinsamer Rundweg für beide, einzelne Materialien mit Symbol und Skill-Farben (grau bis rot)
- Beim Überfahren einer Zone auf der Weltkarte steht der Skill-Bereich deiner Sammelberufe dort
- Fundstellen, die in den Daten fehlen, lernt BerufeTracker beim Sammeln dazu
- Angeln: Skill-Bereich je Gebiet und Empfehlung des anspruchsvollsten Gebiets, in dem du noch zuverlässig fängst
- Lehrer: viele fehlende Lehrer ergänzt (andere Titel, Lehrer von WoW Forever); Lehrer lehren einen Rang mehr als in Classic, wie im Spiel beobachtet
- Klick auf einen Lehrer oder ein Material: Wegpunkt und Karte beim nächsten, jeder weitere Klick springt zum nächsten („Lehrer 1 von 18“)
- BerufeTracker-Reiter am Berufsfenster (neben dem ATT-Reiter): dockt die Route des offenen Berufs daneben an
- Leuchten und Ton nur für Sammelberufe, die der Charakter gelernt hat; häutbare Leichen mit Beute werden erkannt; läuft zusammen mit der NPC-Pause von PÄNIK
- Gegner-Tooltip: „Kürschnern“ in der Skill-Farbe für dieses Tier; nicht häutbare Tiere zeigen kein Leder mehr
- Tooltip von Kräutern und Erz zeigt die aktuelle Chance auf einen Skillpunkt
- Wegpunkt-Leiste steht jetzt neben der Minimap
- Klick auf einen Routen-Schritt oder ein herstellbares Material: Das Berufsfenster öffnet sich mit ausgewähltem Rezept und eingetragener Menge (höchstens so viel, wie du gerade herstellen kannst); fehlt das Rezept: Wegpunkt zum Rezepthändler bzw. Lehrer
- Tooltips von Routen-Schritten und herstellbaren Materialien zeigen die aktuelle Chance auf einen Skillpunkt beim Herstellen
- Rechtsklick auf den Minimap-Button, den Kartenknopf oder ein Sammelgebiet blendet Fundpunkte und Rundwege ein oder aus; deine Auswahl bleibt erhalten

## 1.4.0

- „Sammelbares hervorheben“ (früher „Erze/Kräuter hervorheben“) ist automatisch an, wenn der Charakter Kräuterkunde, Bergbau oder Kürschnerei hat, mit deutlich größerem Glitzereffekt: pulsierender Schein, Lichtstrahl und funkelnde Sterne, die um das Objekt kreisen
- Kürschnerei: häutbare Tiere leuchten ebenfalls (hellbeige), grau, wenn dein Skill nicht reicht
- Neue Option „Ton“ daneben (oder /berufe glitzern ton): ein leiser Hinweiston, sobald etwas Sammelbares in der Nähe ist, einmal je Objekt; mit oder ohne Leuchten
- Läuft zusammen mit PÄNIK Gildentools, statt auszubleiben; dort Erz und Kräuter ausschalten, sonst leuchten beide
- Tooltip von Kräutern und Erz endet mit einer Leerzeile, damit die Zeilen anderer Addons darunter abgesetzt sind

## 1.3.2

- Minimap-Button: Tooltip mit kurzer Beschreibung und was Klicken und Ziehen bewirken
- Der Minimap-Button nutzt LibDBIcon, wenn ein anderes Addon die Bibliothek mitbringt; Minimap-Sammler (z. B. Leatrix Plus) zeigen ihn dann mit eigenem Tooltip
- Die Addon-Liste zeigt die Versionsnummer statt „@project-version@“

## 1.3.1

- Neue Option „Erze/Kräuter hervorheben“ (Tab Materialien oder /berufe glitzern): Kräuter und Erzadern in der Nähe leuchten, hell, wenn du das Material brauchst oder Sammeln noch Skillpunkte bringt; bleibt aus, solange PÄNIK Gildentools oder ein anderes Addon das schon macht
- Die berechneten Wege verbrauchen vorhandenes Material zuerst, solange es noch Skillpunkte bringt (z. B. Gegengift vor Wollverband, Matschschnapper vor Wels); der schnellste Weg nur, wenn es keine zusätzliche Zeit kostet
- Rezepte zählen nur beim Charakter der Route als gelernt, wenn er den Beruf hat; sonst zählen die Rezepte deiner anderen Charaktere
- Tooltip von Kräutern und Erz: wie oft du ungefähr noch sammeln solltest, bis grau und für deine Berufe
- Tooltip: „Fehlt noch“ ist rot

## 1.3.0

- Neuer eigener Guide „Schnellster berechneter Weg“: die Rezepte mit der kürzesten Herstellzeit, inklusive Abklingzeiten von Materialien wie Mondstoff
- Herstellzeit und Kosten ab jetzt unter jedem Beruf, für jeden Guide
- „Günstigster Guide-Weg“ wird jetzt wie „Günstigster berechneter Weg“ Skillpunkt für Skillpunkt berechnet; keiner der beiden ist je teurer als einer der anderen Guides
- Die eigenen Wege rechnen die Chance auf einen Skillpunkt für jeden Punkt ein und nutzen deine Materialien nur, solange sie reichen
- Kein Ruckeln mehr nach dem Herstellen: die eigenen Wege werden beim Öffnen des Fensters im Hintergrund berechnet
- Neuer Standardfilter „Aktueller Charakter“; Filter umbenannt in „Alle Charaktere (gelernte Berufe)“, „Gelernte Berufe (bester Charakter)“ und „Alle Berufe (auch ungelernte)“. Die Route zeigt nur die Berufe der Auswahl, ungelernte nur mit ihrem ersten Lehrer
- Materialien und Route zeigen dieselben Kaufkosten, inklusive Lehrer, Rezepte und einer Schätzung für Materialien ohne Preis
- Berufsfenster des Spiels: das Rezept, das deine Route als Nächstes empfiehlt, hat einen feinen Rahmen und einen getönten Hintergrund; beim Drüberfahren siehst du, welcher Guide es empfiehlt, die Materialien und welche Charaktere sie haben
- Kräuter und Erz: der Tooltip zeigt, ob Sammeln noch Skillpunkte bringt
- Tab Charaktere: Stufe, Gilde, Gold, Berufe und Materialien jedes Charakters; Gildenbanken stehen bei den Charakteren ihrer Gilde
- Goldbeträge mit Münzsymbolen
- Fenster: Mindestgröße, klarere Einrückung; aufgeklappte Berufe werden je Charakter gemerkt
- Behoben: Taschen, Skills und Rezepte eines Charakters konnten beim Ausloggen verloren gehen

## 1.2.0

- Zwei eigene Guides: „Günstigster berechneter Weg“ (aus allen Rezepten des Berufs in den Forever-Spieldaten: je Skillpunkt das billigste Rezept nach Farbe und Chance) und „Günstigster Guide-Weg“ (aus den Schritten der anderen Guides)
- Kosten ab jetzt für jeden Guide in den Guide-Menüs und neben „Guide für alle:“, mit Lehrer- und Rezeptkosten; vorhandene Materialien zählen gratis
- Händlerware mit begrenztem Vorrat zählt nur, wenn sie im Auktionshaus ist; der Preisscan erfasst jetzt auch Rezept-Items
- Zwischenprodukte (Ballen, Barren …) werden im Auktionshaus gekauft, wenn das billiger ist als Herstellen
- Die Route folgt dem im Filter gewählten Charakter; zuerst die Hauptberufe, dann Erste Hilfe und Kochkunst, Angeln zuletzt
- Schritte mit langer Abklingzeit oder nur über eine Quest werden markiert
- Das Fenster lässt sich in der Größe ziehen
- Gegner-Tooltips zeigen, welche benötigten Materialien sie droppen, mit Chance und Menge (Daten: cMaNGOS)
- Entzaubern: Der Item-Tooltip zeigt die möglichen Ergebnisse mit Chance und Menge
- Handwerksmaterial, das keine Route braucht, zeigt „Für keine Route gebraucht“

## 1.1.1

- Bedarf an Erzadern und Kräutern erscheint jetzt zuverlässig, auch beim direkten Wechsel von einem Vorkommen zum nächsten
- Portugiesisch: Knopf „Escanear preços“ statt „Varrer preços“
- READMEs in allen Spielsprachen

## 1.1.0

- Alle Spielsprachen: Englisch, Deutsch, Französisch, Spanisch, Portugiesisch, Italienisch, Russisch, Koreanisch und Chinesisch (vereinfacht und traditionell)
- Namen von Items, Rezepten, Lehrern, Händlern und Vorkommen in der Sprache des Spiels
- Berufe, Items und Rezepte werden unabhängig von der Spielsprache erkannt

## 1.0.1

- Lehrer-Rang Lehrling (1-75) in der Route ergänzt
- Alle Ränge zeigen ihren Bereich, z. B. „Geselle (75-150)“
- Abgeschlossene Ränge nennen weiterhin ihren Lehrer
- Der aktuelle Rang bleibt farbig und bei „Nur Offenes“ sichtbar

## 1.0.0 – erste Veröffentlichung

- Materialbedarf aller Berufe 1–300, aufgelöst bis zu den Grundmaterialien, über alle Charaktere und Banken hinweg
- Filter „Alle Berufe“ zählt jeden Charakter mit seinen eigenen Berufen und seinem Skill zusammen; außerdem „Gelernte Berufe“, „Jeder Beruf einmal“ (auch ungelernte) und einzelne Charaktere; Sammelberufe ausschließbar
- Bedarf und Bestand zählen nur für Charaktere der aktuellen Fraktion
- Routen aus sechs Guides wählbar, mit Rezeptstatus und Lehrer-Besuchen
- Auktionshaus-Scan mit Kostenanzeige
- Bezugsquellen je Material: Vorkommen, Gegner, nächste Händler
- Wegpunkte zu Lehrern und Händlern mit Richtungspfeil, Kartenbeschriftung und Beschreibung im Chat-Link
- Bedarf in Item-Tooltips und an Erzadern und Kräutern in der Welt
- Berufe, Kategorien und Materialien alphabetisch sortiert

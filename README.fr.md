# BerufeTracker

[English](README.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português](README.pt-BR.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [한국어](README.ko.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md)

Combien de Minerai de cuivre, d'Etoffe de lin et de Pacifique vous faut-il encore pour monter vos métiers à 300 ? BerufeTracker fait le calcul : pour chaque métier, jusqu'aux matériaux de base et sur tous vos personnages et toutes vos banques.

Pour **WoW Forever**, dans la langue de votre client de jeu : anglais, allemand, français, espagnol, portugais, italien, russe, coréen et chinois (simplifié et traditionnel).

## Fonctionnalités

**Matériaux**
- Besoin total de tous les métiers, décomposé jusqu'aux matériaux de base. Une Barre de bronze, par exemple, compte comme des Barres de cuivre et d'étain, et celles-ci à leur tour comme du minerai.
- Ce que vous avez dans les sacs, la banque et la boîte aux lettres de tous vos personnages de votre faction actuelle est déduit. Si [BagBrother/Bagnon](https://www.curseforge.com/wow/addons/bagnon) est installé, les personnages que BerufeTracker ne connaît pas encore sont aussi pris en compte.
- Filtres : « Tous les métiers » additionne tous les personnages de votre faction avec leurs propres métiers et compétences. « Métiers appris » compte chaque métier appris une fois, « Chaque métier une fois » chaque métier une fois, y compris ceux non appris, ou choisissez un seul personnage. Les métiers de récolte peuvent être exclus.
- Le survol affiche le besoin par métier, le prix et le coût d'achat, la répartition du stock entre vos personnages et où obtenir le matériau : gisements avec zones, monstres avec niveaux et marchands les plus proches de votre faction.
- Le scan de l'hôtel des ventes indique ce que coûterait l'achat de tout au lieu de le récolter vous-même.

**Parcours**
- Le parcours pas à pas de chaque métier, avec ce qu'il en reste à faire.
- Choisissez votre guide : Metabot, RankedBoost, Wowhead, wowtbc.gg, GoldGoblin ou wow-professions, par métier ou pour tous à la fois.
- Les recettes manquantes sont signalées avec l'endroit où les trouver.
- Les visites chez le maître apparaissent au bon moment du parcours, avec le maître le plus proche qui vous enseigne le rang suivant.

**Points de passage**
- Ctrl+clic gauche sur un maître ou un matériau place un point de passage vers le maître ou le marchand le plus proche.
- Une barre avec une flèche de direction et une description indique la cible. Un clic dessus ouvre la carte sur la cible.
- La carte affiche aussi une étiquette. Quand vous partagez le repère de la carte dans la discussion, la description est envoyée avec.
- Le point de passage disparaît dès que vous parlez au PNJ.

**Dans le jeu**
- Les infobulles d'objets (sacs, banque, hôtel des ventes, butin) indiquent combien il vous en faut encore avec votre filtre actuel.
- Les filons de minerai et les herbes dans le monde indiquent ce qu'il vous faut encore en tirer.

## Utilisation

- `/berufe` ou le bouton de la minicarte ouvre la fenêtre.
- Pour les prix, ouvrez l'hôtel des ventes et cliquez sur « Scanner les prix » (ou `/berufe scan`).
- `/berufe skill <métier> <valeur>` définit une compétence à la main si elle n'est pas détectée. Sans valeur, la détection automatique s'applique de nouveau.
- Chaque personnage doit se connecter une fois avec l'addon pour que ses métiers soient connus. Sa banque est enregistrée dès que vous l'ouvrez une fois.

## Limites

- Les noms d'objets, de maîtres, de marchands et de gisements proviennent du jeu et de QuestieDB. Pour l'italien, et pour les quelques recettes sans objet fabriqué (comme les enchantements), les noms s'affichent en anglais. Les emplacements des recettes ne sont disponibles qu'en allemand et en anglais.
- Les distances sont à vol d'oiseau et ne valent que sur le même continent.
- Toutes les recettes n'ont pas d'emplacement connu.
- Les données des marchands et des emplacements proviennent de QuestieDB et peuvent contenir quelques erreurs.

## Sources et remerciements

- **Parcours :** [Metabot](https://metabot.gg/en/wow-forever/professions), [RankedBoost](https://rankedboost.com/world-of-warcraft/forever/), [Wowhead](https://www.wowhead.com/forever/profession-leveling-guides), [wowtbc.gg](https://wowtbc.gg/warcraftforever/), [GoldGoblin](https://classic.goldgoblin.net/berufe/) et [wow-professions](https://www.wow-professions.com/forever/). Les parcours ont été condensés pour l'addon. Vous trouverez les guides complets avec toutes les explications sur les sites respectifs ; le lien est affiché dans la sélection de guide de l'addon.
- **Maîtres, marchands et emplacements** ont été générés à partir de QuestieDB (GPLv3). Merci à l'équipe de Questie et à tous les contributeurs. BerufeTracker n'est pas un projet de l'équipe de Questie.

## Licence

GPLv3, voir `LICENSE.md`.

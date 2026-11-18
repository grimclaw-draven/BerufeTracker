# BerufeTracker

[English](../README.md) · [Deutsch](de.md) · [Français](fr.md) · [Español](es.md) · [Português](pt-BR.md) · [Italiano](it.md) · [Русский](ru.md) · [한국어](ko.md) · [简体中文](zh-CN.md) · [繁體中文](zh-TW.md)

Combien de Minerai de cuivre, d'Etoffe de lin et de Pacifique vous faut-il encore pour monter vos métiers à 300 ? BerufeTracker fait le calcul : pour chaque métier, jusqu'aux matériaux de base et sur tous vos personnages et toutes vos banques.

Pour **WoW Forever**, dans la langue de votre client de jeu : anglais, allemand, français, espagnol, portugais, italien, russe, coréen et chinois (simplifié et traditionnel).

## Fonctionnalités

**Matériaux**
- Besoin total de tous les métiers, décomposé jusqu'aux matériaux de base. Une Barre de bronze, par exemple, compte comme des Barres de cuivre et d'étain, et celles-ci à leur tour comme du minerai.
- Ce que vous avez dans les sacs, la banque et la boîte aux lettres de tous vos personnages de votre faction actuelle est déduit. Si [BagBrother/Bagnon](https://www.curseforge.com/wow/addons/bagnon) est installé, les personnages que BerufeTracker ne connaît pas encore sont aussi pris en compte.
- Filtres : « Personnage actuel » (par défaut) n'affiche que les métiers du personnage connecté. « Tous les personnages (métiers appris) » additionne tous les personnages de votre faction avec leurs propres métiers et compétences. « Métiers appris (meilleur personnage) » compte chaque métier appris une fois, « Tous les métiers (même non appris) » chaque métier une fois, les non appris à partir de 1, ou choisissez un seul personnage. Le parcours n'affiche que les métiers de la sélection ; pour un personnage, les métiers pas encore appris n'affichent que leur premier maître. Les métiers de récolte peuvent être exclus.
- Le survol affiche le besoin par métier, le prix et le coût d'achat, la répartition du stock entre vos personnages et où obtenir le matériau : gisements avec zones, monstres avec niveaux et marchands les plus proches de votre faction.
- Le scan de l'hôtel des ventes indique ce que coûterait l'achat de tout au lieu de le récolter vous-même. Composants et Parcours affichent le même coût d'achat, maîtres et recettes compris.

**Parcours**
- Le parcours pas à pas de chaque métier, avec ce qu'il en reste à faire.
- Choisissez votre guide : Metabot, RankedBoost, Wowhead, wowtbc.gg, GoldGoblin ou wow-professions, par métier ou pour tous à la fois.
- **Chemin calculé le moins cher :** un guide propre, indépendant des autres guides. Pour chaque point de compétence, il choisit la moins chère de toutes les recettes du métier (données de jeu de Forever), selon la couleur de la recette et la chance de gagner un point, avec les prix de l'hôtel des ventes, des marchands, des maîtres et des recettes. Les recettes connues et les composants déjà possédés sont gratuits ; les articles de marchand en stock limité ne comptent que s'ils sont à l'hôtel des ventes ; les recettes avec temps de recharge sont exclues. **Chemin le moins cher des guides** fait de même avec les étapes des autres guides. **Chemin calculé le plus rapide** choisit les recettes au temps de fabrication le plus court et tient aussi compte des temps de recharge de matériaux comme l'étoffe lunaire. Vos propres chemins ne coûtent jamais plus cher qu'un des autres guides et sont recalculés à l'ouverture de la fenêtre.
- Chaque guide affiche le temps de fabrication et le coût à partir de votre compétence actuelle ; les menus des guides comparent le coût de tous les guides.
- Les recettes manquantes sont signalées avec l'endroit où les trouver.
- Les visites chez le maître apparaissent au bon moment du parcours, avec le maître le plus proche qui vous enseigne le rang suivant.

**Points de passage**
- Ctrl+clic gauche sur un maître ou un matériau place un point de passage vers le maître ou le marchand le plus proche.
- Une barre avec une flèche de direction et une description indique la cible. Un clic dessus ouvre la carte sur la cible.
- La carte affiche aussi une étiquette. Quand vous partagez le repère de la carte dans la discussion, la description est envoyée avec.
- Le point de passage disparaît dès que vous parlez au PNJ.

**Dans le jeu**
- Les infobulles d'objets (sacs, banque, hôtel des ventes, butin) indiquent combien il vous en faut encore avec votre filtre actuel.
- Les filons de minerai et les herbes dans le monde indiquent ce qu'il vous faut encore en tirer et si la récolte vous rapporte encore des points de compétence.
- Les ennemis indiquent quels matériaux dont vous avez besoin ils laissent tomber, ainsi que le tissu des humanoïdes et le cuir des bêtes (dépeçage) de leur niveau.
- Les armes et armures indiquent quels matériaux d’enchantement le désenchantement donne environ, si vous en avez besoin.
- La fenêtre de métier du jeu met en évidence la recette que votre parcours recommande ensuite ; son infobulle indique les matériaux nécessaires et quels personnages les possèdent.

**Fenêtre**
- Onglet Personnages : niveau, guilde, or, métiers et matériaux de chaque personnage ; les banques de guilde suivent les personnages de leur guilde. Vous choisissez quels stocks comptent.
- La fenêtre est redimensionnable ; les métiers dépliés sont mémorisés par personnage.

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
- Les **chances et quantités de butin** des ennemis proviennent de la [base de données cMaNGOS Classic](https://github.com/cmangos/classic-db) (GPLv3). Ce sont des valeurs de Classic 1.12, elles peuvent différer dans WoW Forever.
- **Recettes, couleurs de compétence et composants** du « Chemin calculé le moins cher » proviennent des données de jeu de WoW Forever via [wago.tools](https://wago.tools) ; coûts des maîtres et stock des marchands de la base de données cMaNGOS Classic.

## Licence

GPLv3, voir `LICENSE.md`.

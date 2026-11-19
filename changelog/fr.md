# Changelog

## 1.4.0

- « Mettre en évidence la récolte » (anciennement « Mettre en évidence minerai/herbes ») est activé automatiquement si le personnage connaît l'herboristerie, le minage ou le dépeçage, avec un effet scintillant bien plus grand : lueur pulsante, rayon de lumière et étoiles qui tournent autour de l'objet
- Dépeçage : les bêtes dépeçables brillent aussi (beige clair), en gris si votre compétence est trop basse
- Nouvelle option « Son » à côté (ou /berufe glitzern ton) : un son discret dès qu'une ressource récoltable est proche, une fois par objet ; avec ou sans lueur
- Fonctionne avec PÄNIK Gildentools au lieu de rester désactivé ; désactivez-y le minerai et les herbes, sinon les deux brillent
- L'infobulle des herbes et du minerai se termine par une ligne vide, pour séparer les lignes des autres addons

## 1.3.2

- Bouton de la minicarte : infobulle avec une courte description et l'effet du clic et du glisser
- Le bouton de la minicarte utilise LibDBIcon si un autre addon fournit la bibliothèque ; les collecteurs de boutons (p. ex. Leatrix Plus) l'affichent alors avec sa propre infobulle
- La liste des addons affiche le numéro de version au lieu de « @project-version@ »

## 1.3.1

- Nouvelle option « Mettre en évidence minerai/herbes » (onglet Composants ou /berufe glitzern) : les herbes et filons proches brillent, vif si vous avez besoin du matériau ou si la récolte rapporte encore des points ; reste désactivée tant que PÄNIK Gildentools ou un autre addon le fait déjà
- Les chemins calculés utilisent d'abord les matériaux que vous avez, tant qu'ils rapportent des points (p. ex. Anti-venin avant Bandage en laine, Vivaneau avant Poisson-chat) ; le chemin le plus rapide seulement sans temps supplémentaire
- Les recettes ne comptent comme apprises que pour le personnage du parcours s'il a le métier ; sinon celles de vos autres personnages comptent
- Infobulle des herbes et du minerai : combien de fois environ récolter encore, jusqu'au gris et pour vos métiers
- Infobulle : « Manquant » est en rouge

## 1.3.0

- Nouveau guide propre « Chemin calculé le plus rapide » : les recettes au temps de fabrication le plus court, temps de recharge de matériaux comme l'étoffe lunaire compris
- Temps de fabrication et coût à partir de maintenant sous chaque métier, pour chaque guide
- « Chemin le moins cher des guides » est désormais calculé point par point comme « Chemin calculé le moins cher » ; aucun des deux ne coûte jamais plus cher qu'un des autres guides
- Les chemins propres tiennent compte de la chance de gagner un point à chaque point et n'utilisent vos matériaux que tant qu'ils suffisent
- Plus de ralentissement après une fabrication : les chemins propres sont calculés en arrière-plan à l'ouverture de la fenêtre
- Nouveau filtre par défaut « Personnage actuel » ; filtres renommés « Tous les personnages (métiers appris) », « Métiers appris (meilleur personnage) » et « Tous les métiers (même non appris) ». Le parcours n'affiche que les métiers de la sélection, les non appris seulement avec leur premier maître
- Composants et Parcours affichent le même coût d'achat, maîtres, recettes et une estimation pour les matériaux sans prix compris
- Fenêtre de métier du jeu : la recette que votre parcours recommande ensuite a un fin cadre et un fond teinté ; au survol, vous voyez quel guide la recommande, les matériaux et quels personnages les possèdent
- Herbes et minerai : l'infobulle indique si la récolte rapporte encore des points de compétence
- Onglet Personnages : niveau, guilde, or, métiers et matériaux de chaque personnage ; les banques de guilde suivent les personnages de leur guilde
- Montants en or avec icônes de pièces
- Fenêtre : taille minimale, indentation plus claire ; les métiers dépliés sont mémorisés par personnage
- Corrigé : les sacs, compétences et recettes d'un personnage pouvaient être perdus à la déconnexion

## 1.2.0

- Deux guides propres : « Chemin calculé le moins cher » (à partir de toutes les recettes du métier dans les données de jeu de Forever : pour chaque point de compétence la recette la moins chère selon la couleur et la chance) et « Chemin le moins cher des guides » (à partir des étapes des autres guides)
- Coût à partir de maintenant pour chaque guide dans les menus de guide et à côté de « Guide pour tous : », avec les coûts des maîtres et des recettes ; les composants déjà possédés sont gratuits
- Les articles de marchand en stock limité ne comptent que s'ils sont à l'hôtel des ventes ; l'analyse des prix couvre aussi les recettes
- Les produits intermédiaires (rouleaux, barres …) sont achetés à l'hôtel des ventes quand c'est moins cher que de les fabriquer
- Le parcours suit le personnage choisi dans le filtre ; d'abord les métiers principaux, puis Secourisme et Cuisine, Pêche en dernier
- Les étapes avec un long temps de recharge ou disponibles uniquement par une quête sont signalées
- La fenêtre peut être redimensionnée
- Les infobulles des ennemis indiquent les composants nécessaires qu'ils lâchent, avec chance et quantité (données : cMaNGOS)
- Désenchantement : l'infobulle de l'objet indique les résultats possibles avec chance et quantité
- Les composants d'artisanat dont aucun parcours n'a besoin indiquent « Requis par aucun parcours »

## 1.1.1

- Le besoin s’affiche désormais de façon fiable sur les filons de minerai et les herbes, même en passant directement d’un point de récolte au suivant
- Portugais : bouton « Escanear preços » au lieu de « Varrer preços »
- README dans toutes les langues du jeu

## 1.1.0

- Toutes les langues du jeu : anglais, allemand, français, espagnol, portugais, italien, russe, coréen et chinois (simplifié et traditionnel)
- Noms des objets, recettes, maîtres, marchands et points de récolte dans la langue du jeu
- Les métiers, objets et recettes sont reconnus quelle que soit la langue du jeu

## 1.0.1

- Rang de maître Apprenti (1-75) ajouté à l’itinéraire
- Tous les rangs affichent leur plage, p. ex. « Compagnon (75-150) »
- Les rangs terminés indiquent toujours leur maître
- Le rang actuel reste coloré et visible avec « Restant seulement »

## 1.0.0 – première version

- Besoin en matériaux de tous les métiers 1–300, décomposé jusqu’aux matériaux de base, sur tous les personnages et banques
- Le filtre « Tous les métiers » additionne chaque personnage avec ses propres métiers et son niveau ; en plus « Métiers appris », « Chaque métier une fois » (y compris ceux non appris) et les personnages individuels ; les métiers de récolte peuvent être exclus
- Le besoin et le stock ne comptent que pour les personnages de la faction actuelle
- Itinéraires de six guides au choix, avec état des recettes et visites aux maîtres
- Scan de l’hôtel des ventes avec affichage des coûts
- Provenance par matériau : points de récolte, monstres, marchands les plus proches
- Points de passage vers les maîtres et marchands avec flèche de direction, étiquette sur la carte et description dans le lien de discussion
- Besoin dans les infobulles des objets et sur les filons de minerai et les herbes dans le monde
- Métiers, catégories et matériaux triés par ordre alphabétique

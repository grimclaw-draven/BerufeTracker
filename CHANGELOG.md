# Changelog

## 1.3.1

- New option "Highlight ore/herbs" (Materials tab or /berufe glitzern): herbs and ore veins nearby glow, bright when you need the material or gathering still gives skill points; stays off while PÄNIK Gildentools or another addon already does this
- Calculated routes use materials you already have first while they still give skill points (e.g. Anti-Venom before Wool Bandage, Mud Snapper before Catfish); the fastest route only if it costs no extra time
- Recipes count as learned only for the character of the route if that character has the profession; otherwise recipes of your other characters count
- Herb and ore tooltip: about how often you still need to gather, until gray and for your professions
- Tooltip: "Still missing" is red

## 1.3.0

- New own guide "Fastest calculated route": the recipes with the shortest crafting time, including cooldowns of materials such as Mooncloth
- Crafting time and cost from now under every profession, for every guide
- "Cheapest guide route" is now calculated skill point by skill point like "Cheapest calculated route"; neither of them is ever more expensive than one of the other guides
- Own routes count the skill-up chance of every point and use your materials only as long as they last
- No more lag after crafting: own routes are calculated in the background when the window opens
- New default filter "Current character"; filters renamed to "All characters (learned professions)", "Learned professions (best character)" and "All professions (also unlearned)". The route shows only the professions of the selection, unlearned ones only with their first trainer
- Materials and route show the same purchase cost, including trainers, recipes and an estimate for materials without a price
- Profession window of the game: the recipe your route recommends next has a fine frame and a tinted background; hovering it shows which guide recommends it, the materials and which characters hold them
- Herbs and ore: the tooltip shows whether gathering still gives skill points
- Characters tab: level, guild, gold, professions and materials of every character; guild banks follow the characters of their guild
- Gold amounts with coin icons
- Window: minimum size, clearer indentation; expanded professions are remembered per character
- Fixed: bags, skills and recipes of a character could be lost on logout

## 1.2.0

- Two own guides: "Cheapest calculated route" (from all recipes of the profession in the Forever game data: for every skill point the cheapest recipe by color and skill-up chance) and "Cheapest guide route" (from the steps of the other guides)
- Cost from now on for every guide in the guide menus and next to "Guide for all:", including trainer and recipe costs; materials you already have count as free
- Vendor goods with limited stock only count if they are on the auction house; the price scan now also covers recipe items
- Intermediate products (bolts, bars …) are bought on the auction house when that is cheaper than crafting them
- Route follows the character chosen in the filter; main professions first, then First Aid and Cooking, Fishing last
- Steps with a long cooldown or only available through a quest are marked
- The window can be resized
- Enemy tooltips show which needed materials they drop, with chance and amount (data: cMaNGOS)
- Disenchanting: the item tooltip shows the possible results with chance and amount
- Trade goods that no route needs say "Not needed by any route"

## 1.1.1

- The need at ore veins and herbs now shows reliably, also when moving straight from one node to the next
- Portuguese: button "Escanear preços" instead of "Varrer preços"
- READMEs in all game languages

## 1.1.0

- All game languages: English, German, French, Spanish, Portuguese, Italian, Russian, Korean and Chinese (simplified and traditional)
- Names of items, recipes, trainers, vendors and nodes in the language of the game
- Professions, items and recipes are recognized regardless of the game language

## 1.0.1

- Trainer rank Apprentice (1-75) added to the route
- All ranks show their range, e.g. "Journeyman (75-150)"
- Completed ranks still name their trainer
- The current rank stays colored and visible with "Open only"

## 1.0.0 – first release

- Material need of all professions 1–300, broken down to base materials, across all characters and banks
- Filter "All professions" adds up every character with their own professions and skill; also "Learned professions", "Each profession once" (including unlearned ones) and single characters; gathering professions can be left out
- Need and stock only count for characters of the current faction
- Routes from six guides to choose from, with recipe status and trainer visits
- Auction House scan with cost display
- Sources per material: nodes, mobs, nearest vendors
- Waypoints to trainers and vendors with direction arrow, map label and description in the chat link
- Need in item tooltips and at ore veins and herbs in the world
- Professions, categories and materials sorted alphabetically

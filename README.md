# BerufeTracker

[English](README.md) · [Deutsch](readme/de.md) · [Français](readme/fr.md) · [Español](readme/es.md) · [Português](readme/pt-BR.md) · [Italiano](readme/it.md) · [Русский](readme/ru.md) · [한국어](readme/ko.md) · [简体中文](readme/zh-CN.md) · [繁體中文](readme/zh-TW.md)

How much Copper Ore, Linen Cloth and Peacebloom do you still need to bring your professions to 300? BerufeTracker works it out: for every profession, down to the base materials and across all your characters and banks.

For **WoW Forever**, in the language of your game client: English, German, French, Spanish, Portuguese, Italian, Russian, Korean and Chinese (simplified and traditional).

## Features

**Materials**
- Total need of all professions, broken down to base materials. A Bronze Bar, for example, counts as Copper and Tin Bars, and those in turn as ore.
- What you hold in the bags, bank and mailbox of all your characters of your current faction is deducted. If [BagBrother/Bagnon](https://www.curseforge.com/wow/addons/bagnon) is installed, characters that BerufeTracker does not know yet are included as well.
- Filters: "Current character" (default) shows only the professions of the logged-in character. "All characters (learned professions)" adds up every character of your faction with their own professions and skill. "Learned professions (best character)" counts each learned profession once, "All professions (also unlearned)" every profession once, unlearned ones from skill 1, or pick a single character. The route shows only the professions of the selection; for a single character, professions not learned yet show only their first trainer. Gathering professions can be left out.
- Hovering shows the need per profession, price and purchase cost, how the stock is spread across your characters, and where to get the material: nodes with zones, mobs with levels and the nearest vendors of your faction.
- The auction house scan shows what it would cost to buy everything instead of farming it yourself. Materials and route show the same purchase cost, including trainers and recipes.

**Route**
- The step-by-step route of each profession, with how much of it is still open.
- Choose your guide: Metabot, RankedBoost, Wowhead, wowtbc.gg, GoldGoblin or wow-professions, per profession or for all at once.
- **Cheapest calculated route:** your own guide, independent of the other guides. For every skill point it picks the cheapest of all the profession's recipes (Forever game data), by recipe color and skill-up chance, with auction house, vendor, trainer and recipe prices. Recipes you know and materials you already have count as free; vendor goods with limited stock only count if they are on the auction house; recipes with a cooldown are left out. **Cheapest guide route** does the same with the steps of the other guides. **Fastest calculated route** picks the recipes with the shortest crafting time and also counts cooldowns of materials such as Mooncloth. Your own routes are never more expensive than any of the other guides and are recalculated when you open the window.
- Every guide shows the crafting time and the cost from your current skill on; the guide menus compare the cost of all guides.
- Missing recipes are marked together with where to find them.
- Trainer visits appear at the right point of the route, with the nearest trainer who teaches you the next rank.

**Waypoints**
- Left-click on a trainer or a material sets a waypoint to the nearest trainer or vendor; each further click goes to the next one in the list. Clicking a route step or craftable material opens the profession window with the recipe and amount; if the recipe is missing, it leads you to the recipe vendor or trainer.
- A bar with a direction arrow and a description shows the target. Clicking it opens the map at the target.
- The map shows a label as well. When you share the map pin in chat, the description is sent along.
- The waypoint disappears as soon as you talk to the NPC.

**In the game**
- Item tooltips (bags, bank, auction house, loot) show how much you still need under your current filter.
- Ore veins and herbs in the world show what you still need from them and about how often you still need to gather them: until they turn gray and for your professions.
- **Highlight gatherables** (Materials tab or `/berufe glitzern`): herbs, ore veins and skinnable beasts nearby glow, bright when you need the material or gathering still gives skill points, otherwise gray. On automatically when the character has Herbalism, Mining or Skinning (the game only reveals the nearest object, up to about 15 m). Separately, **Sound** (next to it or `/berufe glitzern ton`) plays a quiet ping as soon as something you can gather is nearby. Works together with PÄNIK Gildentools; turn off ore and herbs there, otherwise both glow.
- **Gathering areas** (Route tab, under Herbalism, Mining, Skinning and Fishing): the best maps for your current skill, by density and distance, each with the skill range in which it pays off, so you see when to move on. Click: opens the map with matching spawn points and a loop route (also on the minimap); right-click shows or hides spawn points and routes (your selection is kept). Herbs, ore and beasts from the WoW Forever data of QuestieDB; fishing uses Classic minimum skills per zone. On the world map, hovering a zone shows the skill range of the gathering professions your character has learned below its name. A panel at the bottom left of the world map switches professions (herbs as squares, ore as diamonds, each with its own route color), single materials and skill colors on or off. Herb and ore spots missing from the data are learned when you gather there.
- Enemies show which of your needed materials they drop, plus cloth from humanoids and leather from beasts (skinning) of their level.
- Weapons and armor show which enchanting materials disenchanting gives about, if you need them.
- The game's profession window frames the recipe your route recommends next; hovering it shows which guide recommends it, the materials you need and which characters hold them. A BerufeTracker tab at the side of the profession window (next to the profession icons and the ATT tab) docks the BerufeTracker window right beside it with the route of that profession; click again to undock.

**Window**
- Characters tab: level, guild, gold, professions and materials of every character; guild banks follow the characters of their guild. Choose whose stock counts.
- The window can be resized; expanded professions are remembered per character.

## Usage

- `/berufe` or the minimap button opens the window.
- For prices, open the auction house and click "Scan prices" (or `/berufe scan`).
- `/berufe skill <profession> <value>` sets a skill by hand if it is not detected. Without a value, automatic detection applies again.
- Each character has to log in with the addon once so its professions are known. Its bank is recorded as soon as you open it once.

## Limitations

- Item, trainer, vendor and node names come from the game and from QuestieDB. For Italian, and for the few recipes without a crafted item (such as enchantments), names fall back to English. Recipe locations are only available in German and English.
- Distances are straight-line and only apply on the same continent.
- Not every recipe has a known location.
- Vendor and location data come from QuestieDB and may contain individual errors.

## Sources and thanks

- **Routes:** [Metabot](https://metabot.gg/en/wow-forever/professions), [RankedBoost](https://rankedboost.com/world-of-warcraft/forever/), [Wowhead](https://www.wowhead.com/forever/profession-leveling-guides), [wowtbc.gg](https://wowtbc.gg/warcraftforever/), [GoldGoblin](https://classic.goldgoblin.net/berufe/) and [wow-professions](https://www.wow-professions.com/forever/). The routes were condensed for the addon. You will find the full guides with all explanations on the respective sites; the link is shown in the addon's guide selection.
- **Trainers, vendors and locations** were generated from QuestieDB (GPLv3). Thanks to the Questie team and all contributors. BerufeTracker is not a project of the Questie team.
- **Drop chances and amounts** of enemies come from the [cMaNGOS Classic database](https://github.com/cmangos/classic-db) (GPLv3). They are Classic 1.12 values and can differ in WoW Forever.
- **Recipes, skill colors and reagents** for the "Cheapest calculated route" come from the WoW Forever game data via [wago.tools](https://wago.tools); trainer costs and vendor stock from the cMaNGOS Classic database.

## License

GPLv3, see `LICENSE.md`.

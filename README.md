# BerufeTracker

*[Deutsche Version](README.de.md)*

How much Copper Ore, Linen Cloth and Peacebloom do you still need to bring your professions to 300? BerufeTracker works it out: for every profession, down to the base materials and across all your characters and banks.

For **WoW Forever**, in the language of your game client: English, German, French, Spanish, Portuguese, Italian, Russian, Korean and Chinese (simplified and traditional).

## Features

**Materials**
- Total need of all professions, broken down to base materials. A Bronze Bar, for example, counts as Copper and Tin Bars, and those in turn as ore.
- What you hold in the bags, bank and mailbox of all your characters of your current faction is deducted. If [BagBrother/Bagnon](https://www.curseforge.com/wow/addons/bagnon) is installed, characters that BerufeTracker does not know yet are included as well.
- Filters: "All professions" adds up every character of your faction with their own professions and skill. "Learned professions" counts each learned profession once, "Each profession once" every profession once including unlearned ones, or pick a single character. Gathering professions can be left out.
- Hovering shows the need per profession, price and purchase cost, how the stock is spread across your characters, and where to get the material: nodes with zones, mobs with levels and the nearest vendors of your faction.
- The auction house scan shows what it would cost to buy everything instead of farming it yourself.

**Route**
- The step-by-step route of each profession, with how much of it is still open.
- Choose your guide: Metabot, RankedBoost, Wowhead, wowtbc.gg, GoldGoblin or wow-professions, per profession or for all at once.
- Missing recipes are marked together with where to find them.
- Trainer visits appear at the right point of the route, with the nearest trainer who teaches you the next rank.

**Waypoints**
- Ctrl+left-click on a trainer or a material sets a waypoint to the nearest trainer or vendor.
- A bar with a direction arrow and a description shows the target. Clicking it opens the map at the target.
- The map shows a label as well. When you share the map pin in chat, the description is sent along.
- The waypoint disappears as soon as you talk to the NPC.

**In the game**
- Item tooltips (bags, bank, auction house, loot) show how much you still need under your current filter.
- Ore veins and herbs in the world show what you still need from them.

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

## License

GPLv3, see `LICENSE.md`.

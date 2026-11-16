# BerufeTracker

[English](../README.md) · [Deutsch](de.md) · [Français](fr.md) · [Español](es.md) · [Português](pt-BR.md) · [Italiano](it.md) · [Русский](ru.md) · [한국어](ko.md) · [简体中文](zh-CN.md) · [繁體中文](zh-TW.md)

要把专业练到 300，你还需要多少铜矿石、亚麻布和宁神花？BerufeTracker 帮你算出来：每个专业都会分解到基础材料，并涵盖你所有的角色和银行。

适用于 **WoW Forever**，使用你游戏客户端的语言：英语、德语、法语、西班牙语、葡萄牙语、意大利语、俄语、韩语和中文（简体和繁体）。

## 功能

**材料**
- 所有专业的总需求，分解到基础材料。例如，青铜锭会计为铜锭和锡锭，而它们又会计为矿石。
- 会扣除你当前阵营所有角色的背包、银行和邮箱中的物品。如果安装了 [BagBrother/Bagnon](https://www.curseforge.com/wow/addons/bagnon)，BerufeTracker 尚不认识的角色也会被计入。
- 筛选：“所有专业”将你阵营的所有角色按各自的专业和技能等级相加。“已学专业”将每个已学专业计算一次，“每个专业一次”将每个专业计算一次（包括未学的），也可以只选择单个角色。采集专业可以排除。
- 鼠标悬停时显示每个专业的需求、价格和购买花费、库存在各角色间的分布，以及材料的获取途径：采集点及所在区域、怪物及其等级，以及你阵营最近的商人。
- 拍卖行扫描会显示全部购买（而不是自己采集）需要花多少钱。

**路线**
- 每个专业的分步路线，以及还剩多少未完成。
- 选择指南：Metabot、RankedBoost、Wowhead、wowtbc.gg、GoldGoblin 或 wow-professions，可按专业单独选择，也可全部统一设置。
- **最便宜的计算路线：** 独立于其他指南的自有指南。每个技能点都会从该专业全部配方（Forever 游戏数据）中，按配方颜色和升级几率选出最便宜的一个，计入拍卖行、商人、训练师和配方价格。已学会的配方和已有材料按免费计算；商人限量出售的物品只有在拍卖行有货时才计入；有冷却时间的配方不使用。**最便宜的指南路线** 用其他指南的步骤做同样的计算。两者都会在背包变化时自动更新。
- 缺少的配方会被标出，并注明获取地点。
- 拜访训练师会出现在路线中合适的位置，并附上能教你下一等级的最近训练师。

**路径点**
- 按住 Ctrl 左键点击训练师或材料，可设置前往最近训练师或商人的路径点。
- 一个带方向箭头和说明的条会显示目标。点击它会打开地图并定位到目标。
- 地图上也会显示标签。在聊天中分享地图标记时，说明会一并发送。
- 一旦你与该 NPC 对话，路径点就会消失。

**游戏内**
- 物品鼠标提示（背包、银行、拍卖行、拾取）会显示在当前筛选下你还需要多少。
- 世界中的矿脉和草药会显示你还需要从中获得多少。
- 敌人会显示它们掉落哪些你需要的材料，以及同等级人型生物的布料和野兽的皮革（剥皮）。
- 武器和护甲会显示分解大约能得到哪些你需要的附魔材料。

## 用法

- `/berufe` 或小地图按钮可打开窗口。
- 要获取价格，请打开拍卖行并点击“扫描价格”（或输入 `/berufe scan`）。
- `/berufe skill <专业> <数值>` 可在技能未被识别时手动设置。不带数值时将重新使用自动识别。
- 每个角色都需要启用插件登录一次，才能识别其专业。银行只要打开一次就会被记录。

## 限制

- 物品、训练师、商人和采集点的名称来自游戏和 QuestieDB。意大利语以及少数没有制造物品的配方（例如附魔）的名称会以英文显示。配方获取地点仅有德语和英语版本，因此在中文下会以英文显示。
- 距离为直线距离，且仅在同一大陆上有效。
- 并非每个配方都有已知的获取地点。
- 商人和地点数据来自 QuestieDB，可能存在个别错误。

## 来源与致谢

- **路线：** [Metabot](https://metabot.gg/en/wow-forever/professions)、[RankedBoost](https://rankedboost.com/world-of-warcraft/forever/)、[Wowhead](https://www.wowhead.com/forever/profession-leveling-guides)、[wowtbc.gg](https://wowtbc.gg/warcraftforever/)、[GoldGoblin](https://classic.goldgoblin.net/berufe/) 和 [wow-professions](https://www.wow-professions.com/forever/)。这些路线已为插件做了精简。包含全部说明的完整指南请见各网站；链接显示在插件的指南选择中。
- **训练师、商人和地点**由 QuestieDB（GPLv3）生成。感谢 Questie 团队和所有贡献者。BerufeTracker 不是 Questie 团队的项目。
- 敌人的**掉落几率和数量**来自 [cMaNGOS Classic 数据库](https://github.com/cmangos/classic-db)（GPLv3）。这些是经典旧世 1.12 的数值，在 WoW Forever 中可能有所不同。
- “最便宜的计算路线”的**配方、技能颜色和材料**来自通过 [wago.tools](https://wago.tools) 获取的 WoW Forever 游戏数据；训练师费用和商人库存来自 cMaNGOS Classic 数据库。

## 许可证

GPLv3，见 `LICENSE.md`。

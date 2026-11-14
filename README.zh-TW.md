# BerufeTracker

[English](README.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português](README.pt-BR.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [한국어](README.ko.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md)

要把專業練到 300，你還需要多少銅礦石、亞麻布和寧神花？BerufeTracker 幫你算出來：每個專業都會拆解到基礎材料，並涵蓋你所有的角色和銀行。

適用於 **WoW Forever**，使用你遊戲用戶端的語言：英文、德文、法文、西班牙文、葡萄牙文、義大利文、俄文、韓文和中文（簡體和繁體）。

## 功能

**材料**
- 所有專業的總需求，拆解到基礎材料。例如青銅錠會計為銅錠和錫錠，而它們又會再計為礦石。
- 會扣除你目前陣營所有角色的背包、銀行和信箱中的物品。若有安裝 [BagBrother/Bagnon](https://www.curseforge.com/wow/addons/bagnon)，BerufeTracker 還不認識的角色也會一併計入。
- 篩選：「所有專業」會把你陣營的所有角色依各自的專業和技能等級加總。「已學專業」將每個已學的專業計算一次，「每個專業一次」將每個專業計算一次（包含未學的），也可以只選擇單一角色。採集專業可以排除。
- 滑鼠指向時會顯示各專業的需求、價格與購買花費、庫存在各角色間的分布，以及材料的取得方式：採集點與所在區域、怪物與其等級，以及你陣營最近的商人。
- 拍賣場掃描會顯示全部用買的（而不是自己採集）要花多少錢。

**路線**
- 每個專業的逐步路線，以及還剩多少未完成。
- 選擇指南：Metabot、RankedBoost、Wowhead、wowtbc.gg、GoldGoblin 或 wow-professions，可依專業個別選擇，也可全部一起設定。
- 缺少的配方會被標示出來，並註明取得地點。
- 拜訪訓練師會出現在路線中適當的位置，並附上能教你下一個等級的最近訓練師。

**導航點**
- 按住 Ctrl 左鍵點擊訓練師或材料，可設定前往最近訓練師或商人的導航點。
- 一條帶有方向箭頭和說明的列會顯示目標。點擊它會開啟地圖並定位到目標。
- 地圖上也會顯示標籤。在聊天中分享地圖標記時，說明會一起送出。
- 只要你和該 NPC 對話，導航點就會消失。

**遊戲中**
- 物品滑鼠提示（背包、銀行、拍賣場、拾取）會顯示在目前篩選下你還需要多少。
- 世界中的礦脈和草藥會顯示你還需要從中取得多少。

## 使用方式

- `/berufe` 或小地圖按鈕可開啟視窗。
- 若要取得價格，請開啟拍賣場並點擊「掃描價格」（或輸入 `/berufe scan`）。
- `/berufe skill <專業> <數值>` 可在技能無法偵測時手動設定。不加數值則會重新套用自動偵測。
- 每個角色都需要啟用插件登入一次，才能得知它的專業。銀行只要開啟一次就會被記錄。

## 限制

- 物品、訓練師、商人和採集點的名稱來自遊戲和 QuestieDB。義大利文以及少數沒有製造物品的配方（例如附魔）的名稱會以英文顯示。配方取得地點只有德文和英文版本，因此在中文下會以英文顯示。
- 距離為直線距離，且只在同一塊大陸上有效。
- 並非每個配方都有已知的取得地點。
- 商人和地點資料來自 QuestieDB，可能有個別錯誤。

## 來源與致謝

- **路線：** [Metabot](https://metabot.gg/en/wow-forever/professions)、[RankedBoost](https://rankedboost.com/world-of-warcraft/forever/)、[Wowhead](https://www.wowhead.com/forever/profession-leveling-guides)、[wowtbc.gg](https://wowtbc.gg/warcraftforever/)、[GoldGoblin](https://classic.goldgoblin.net/berufe/) 和 [wow-professions](https://www.wow-professions.com/forever/)。這些路線已為插件做了精簡。包含所有說明的完整指南請見各網站；連結會顯示在插件的指南選擇中。
- **訓練師、商人和地點**是由 QuestieDB（GPLv3）產生。感謝 Questie 團隊和所有貢獻者。BerufeTracker 不是 Questie 團隊的專案。

## 授權

GPLv3，請見 `LICENSE.md`。

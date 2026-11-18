-- BerufeTracker: Fenster mit den Tabs Route, Materialien und Charaktere.
local ADDON, BT = ...
local L = BT.L

local WIDTH, ROW_HEIGHT, MATERIALS, ROUTE, CHARS = 700, 22, 1, 2, 3
local MIN_WIDTH, MIN_HEIGHT, CONTENT_TOP, CONTENT_BOTTOM = 700, 360, 106, 12
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local tab, window = ROUTE, nil
local rows = {}
local INTERMEDIATES = "Zwischenprodukte (herstellen)"
-- Aufgeklappte Berufe je Charakter, gespeichert; ohne Eintrag gilt: offen = Beruf des aktiven Charakters.
local expanded = setmetatable({}, {
    __index = function(_, key)
        local all = BT.db and BT.db.opt.expanded
        local mine = all and BT.me and all[BT.me]
        if mine then return mine[key] end
    end,
    __newindex = function(_, key, value)
        if not (BT.db and BT.me) then return end
        BT.db.opt.expanded = BT.db.opt.expanded or {}
        BT.db.opt.expanded[BT.me] = BT.db.opt.expanded[BT.me] or {}
        BT.db.opt.expanded[BT.me][key] = value
    end,
})

local function IsExpanded(profKey)
    if expanded[profKey] ~= nil then return expanded[profKey] end
    return BT.IsCurrentProf(profKey)
end

local function ShowMenu(anchor, options, width, selected, onPick)
    local menu = window.filterMenu
    if menu:IsShown() and menu.anchor == anchor then
        menu:Hide()
        return
    end
    menu.anchor = anchor
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    menu:SetWidth(width)
    for index, option in ipairs(options) do
        local button = menu.buttons[index]
        if not button then
            button = CreateFrame("Button", nil, menu)
            button:SetHeight(20)
            button:SetPoint("TOPLEFT", 4, -4 - (index - 1) * 20)
            button:SetPoint("RIGHT", -4, 0)
            button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            button.label:SetPoint("LEFT", 4, 0)
            button.label:SetPoint("RIGHT", -4, 0)
            button.label:SetJustifyH("LEFT")
            button.label:SetWordWrap(false)
            menu.buttons[index] = button
        end
        button.label:SetText((option.value == selected and "|cffffd100" or "|cffffffff") .. option.text .. "|r")
        button:SetScript("OnClick", function()
            menu:Hide()
            onPick(option.value)
            BT.Update()
        end)
        button:Show()
    end
    for index = #options + 1, #menu.buttons do menu.buttons[index]:Hide() end
    -- so breit wie der längste Eintrag, damit nichts umbricht oder überlappt
    local widest = width
    for index = 1, #options do
        local w = menu.buttons[index].label:GetStringWidth()
        if type(w) == "number" then widest = math.max(widest, math.ceil(w) + 24) end
    end
    menu:SetWidth(math.min(widest, 760))
    menu:SetHeight(8 + #options * 20)
    menu:Show()
end

-- Knopftext bleibt im Knopf: links/rechts begrenzt, zu langer Text wird mit "..." gekürzt.
local function FitButtonText(button, font)
    local text = button:GetFontString()
    if not text then return end
    if font then text:SetFontObject(font) end
    text:ClearAllPoints()
    text:SetPoint("LEFT", 6, 0)
    text:SetPoint("RIGHT", -18, 0)
    text:SetWordWrap(false)
end

local function AddDropArrow(button)
    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(18, 18)
    arrow:SetPoint("RIGHT", 0, 0)
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
end

local function OpenGuideMenu(button, prof)
    local options = {}
    local costs = BT.GuideCosts and BT.GuideCosts() or {}
    for _, guide in ipairs(BT.GuideList(prof)) do
        local last = guide.steps[#guide.steps].t
        local notes = {}
        if guide.lump then notes[#notes + 1] = L["Einkaufsliste"] end
        if last < 300 then notes[#notes + 1] = L["bis %d"]:format(last) end
        local cost = costs[guide.key] and costs[guide.key].prof[prof.key]
        if cost then
            notes[#notes + 1] = L["ca. %s"]:format(BT.Money(cost.cost))
        end
        options[#options + 1] = { value = guide.key,
            text = guide.title .. (#notes > 0 and ("  |cff999999" .. table.concat(notes, ", ") .. "|r") or "") }
    end
    ShowMenu(button, options, 340, BT.ActiveGuide(prof).key, function(key) BT.SetGuide(prof, key) end)
end

local function OpenAllGuidesMenu(button)
    local options = {}
    local costs = BT.GuideCosts and BT.GuideCosts() or {}
    for _, guide in ipairs(BT.ALL_GUIDES) do
        local cost, notes = costs[guide.key], {}
        -- Wo endet der Guide? Über alle Herstellungsberufe, die ihn haben.
        local lowest, highest, lump = nil, nil, false
        for _, prof in ipairs(BT.PROFS) do
            if not prof.gather then
                for _, entry in ipairs(BT.GuideList(prof, true)) do
                    if entry.key == guide.key then
                        local last = entry.steps[#entry.steps].t
                        lowest, highest = math.min(lowest or last, last), math.max(highest or last, last)
                        lump = lump or entry.lump
                    end
                end
            end
        end
        if lump then notes[#notes + 1] = L["Einkaufsliste"] end
        if lowest and lowest < 300 then
            notes[#notes + 1] = (highest == lowest and L["bis %d"] or L["teils nur bis %d"]):format(lowest)
        end
        if cost then
            notes[#notes + 1] = L["ca. %s"]:format(BT.Money(cost.total))
        end
        options[#options + 1] = { value = guide.key, text = guide.title .. (#notes > 0 and ("  |cff999999" .. table.concat(notes, ", ") .. "|r") or "") }
    end
    local selected = not next(BT.db.opt.guide) and (BT.db.opt.guideAll or "metabot") or nil
    ShowMenu(button, options, 380, selected, BT.SetAllGuides)
end

-- Ganzzahlige Anteile je Beruf, die in der Summe genau den Bedarf ergeben.
local function ProfessionShares(res)
    local list, assigned = {}, 0
    for key, amount in pairs(res.byProf) do
        local whole = math.floor(amount + 0.000001)
        list[#list + 1] = { key = key, amount = whole, rest = amount - whole }
        assigned = assigned + whole
    end
    table.sort(list, function(a, b)
        if a.rest ~= b.rest then return a.rest > b.rest end
        return a.key < b.key
    end)
    for i = 1, math.min(#list, res.need - assigned) do list[i].amount = list[i].amount + 1 end
    table.sort(list, function(a, b)
        if a.amount ~= b.amount then return a.amount > b.amount end
        return a.key < b.key
    end)
    return list
end

local function ColorName(id, class)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return color and ("|c" .. color.colorStr .. id .. "|r") or id
end

local function Ago(ts)
    local sec = time() - ts
    if sec < 3600 then return L["vor %d Min"]:format(math.max(1, math.floor(sec / 60))) end
    if sec < 86400 then return L["vor %d Std"]:format(math.floor(sec / 3600)) end
    return L["vor %d Tagen"]:format(math.floor(sec / 86400))
end

local AddSourceLines -- weiter unten, braucht NpcLine
local AddNeedLines -- weiter unten, gleiche Darstellung wie im Item-Tooltip des Spiels

local function ItemTooltip(row)
    local key, res = row.entry.key, BT.result[row.entry.key]
    local item = BT.ITEMS[key]
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(BT.ItemName(key), 1, 1, 1)
    AddNeedLines(GameTooltip, key, true)
    GameTooltip:AddLine(" ")
    local price, source, stamp = BT.Price(key)
    if price then
        GameTooltip:AddDoubleLine(L["Preis je Stück"], BT.Money(price), 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(L["Quelle"], source .. (stamp and (", " .. Ago(stamp)) or ""), 1, 0.82, 0, 0.7, 0.7, 0.7)
        if res.missing > 0 then
            GameTooltip:AddDoubleLine(L["Kaufkosten"], BT.Money(price * res.missing), 1, 0.82, 0, 1, 1, 1)
        end
        if BT.RECIPES[key] and res.buy then
            GameTooltip:AddLine(L["Im AH günstiger als selbst herstellen"], 0.2, 0.8, 0.2)
        elseif BT.RECIPES[key] then
            GameTooltip:AddLine(L["Fertig kaufen, zählt nicht zur Summe"], 0.7, 0.7, 0.7)
        end
    else
        GameTooltip:AddLine(L["Noch kein Preis: im Auktionshaus scannen"], 0.7, 0.7, 0.7)
    end
    local recipe = BT.RECIPES[key]
    if recipe then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Noch %s× herstellen (ergibt je %s):"]:format(BT.Format(res.crafts), recipe.makes), 1, 0.82, 0)
        for reagent, amount in pairs(recipe.reag) do
            GameTooltip:AddLine("  " .. amount .. "× " .. BT.ItemName(reagent), 1, 1, 1)
        end
    end
    AddSourceLines(key)
    local owners = {}
    for id, count in pairs(BT.byChar[key] or {}) do owners[#owners + 1] = { id = id, count = count } end
    if #owners > 0 then
        table.sort(owners, function(a, b) return a.count > b.count end)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Verteilung:"], 1, 0.82, 0)
        for _, owner in ipairs(owners) do
            GameTooltip:AddDoubleLine(owner.id, BT.Format(owner.count), 1, 1, 1, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function StepTooltip(row)
    local step, prof = row.entry.step, row.entry.prof
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(BT.StepName(step), 1, 1, 1)
    GameTooltip:AddLine(({ R = L["Benötigt ein Rezept-Item"], T = L["Beim Lehrer"], A = L["Automatisch gelernt"] })[step.src] or " ", 0.7, 0.7, 0.7)
    if step.src == "R" then
        local state, who = BT.RecipeStatus(step)
        GameTooltip:AddLine(" ")
        if step.rc then GameTooltip:AddLine(BT.RecipeItemName(step.rc), 1, 0.82, 0) end
        if state == "known" then
            GameTooltip:AddLine(L["Gelernt: %s"]:format(who), 0.2, 0.8, 0.2)
        elseif state == "owned" then
            GameTooltip:AddLine(L["Rezept-Item bei: %s"]:format(who), 1, 0.8, 0.2)
        else
            GameTooltip:AddLine(L["Noch nicht gesammelt"], 1, 0.4, 0.4)
            GameTooltip:AddLine((step.rc and BT.RecipeWhere(step.rc)) or L["Fundort unbekannt"], 1, 1, 1, true)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(step.lump and L["Menge für diesen Bereich:"] or L["Je Herstellung:"], 1, 0.82, 0)
    for _, reagent in ipairs(step.r) do
        GameTooltip:AddLine("  " .. reagent[2] .. "× " .. BT.ItemName(reagent[1]), 1, 1, 1)
    end
    if not step.lump then
        local total = BT.RemainingCrafts(step, step.f)
        GameTooltip:AddDoubleLine(L["Noch offen"], L["%s von %s"]:format(BT.Format(BT.StepRemaining(step, prof)), BT.Format(total)), 1, 0.82, 0, 1, 1, 1)
        -- nur eigene Rezept-Schritte rechnen nach Chance; fremde Guides haben ihre Mengen selbst eingerechnet
        if step.y then GameTooltip:AddLine(L["Voraussichtlich nach Chance auf einen Skillpunkt"], 0.7, 0.7, 0.7) end
    end
    if step.costMat then
        -- Guide "Günstigster Weg": Kosten ab dem aktuellen Skill
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(L["Materialkosten offen"], BT.Money(step.costMat) .. (step.estimated and (" " .. L["(geschätzt)"]) or ""), 1, 0.82, 0, 1, 1, 1)
        local how = ({ trainer = L["Lehrer"], ["trainer?"] = L["Lehrer, Preis unbekannt"], ah = L["Auktionshaus"], vendor = L["Händler"],
            known = L["schon gelernt oder im Besitz"], auto = L["Automatisch gelernt"], limited = L["nur begrenzt beim Händler, nicht im AH"],
            unavailable = L["nicht im AH gefunden"] })[step.learnHow] or ""
        GameTooltip:AddDoubleLine(L["Rezept"], (step.costLearn > 0 and (BT.Money(step.costLearn) .. ", ") or "") .. how, 1, 0.82, 0, 1, 1, 1)
        if step.fromGuide then GameTooltip:AddDoubleLine(L["Aus Guide"], step.fromGuide, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7) end
        if step.seconds and step.seconds > 0 then
            GameTooltip:AddDoubleLine(L["Herstellzeit"], BT.Duration(step.seconds), 1, 0.82, 0, 1, 1, 1)
        end
        if step.y then
            GameTooltip:AddLine(L["Lernbar ab %d, gelb ab %d, grün ab %d, grau ab %d"]:format(step.l, step.y, math.floor((step.y + step.g) / 2), step.g), 0.7, 0.7, 0.7)
        end
    end
    GameTooltip:Show()
end

local function NpcLine(entry)
    local place = BT.NpcPlace(entry)
    local npc = entry.npc
    local coords = npc.x and (" " .. string.format("%.1f, %.1f", npc.x, npc.y)) or ""
    local distance = entry.distance and (BT.Format(entry.distance) .. " m") or (entry.located and npc.m and L["anderer Kontinent"]) or nil
    return BT.NpcName(npc), place .. coords, distance
end

local function ZoneName(mapID)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and info.name or L["Karte %d"]:format(mapID)
end

-- Händler eines Materials, nächster zuerst, nur die eigene Fraktion.
local function ItemVendors(key)
    local source = BT.SOURCES and BT.SOURCES[key]
    if not source or not source.v then return {} end
    local npcs = {}
    for _, id in ipairs(source.v) do npcs[#npcs + 1] = BT.VENDORS[id] end
    return BT.NearestNpcs({ npcs = npcs })
end

-- Wo es das Material gibt: Hinweis, Vorkommen, Beute, nächste Händler.
AddSourceLines = function(key)
    if BT.RECIPES[key] then return end -- Zwischenprodukte: steht schon unter "herstellen"
    local source = BT.SOURCES and BT.SOURCES[key] or {}
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Bezug:"], 1, 0.82, 0)
    if source.h then GameTooltip:AddLine(source.ha and L[source.h]:format(source.ha) or L[source.h], 1, 1, 1, true) end
    for _, node in ipairs(source.o or {}) do
        local zones = {}
        for index, mapID in ipairs(node.z) do zones[index] = ZoneName(mapID) end
        GameTooltip:AddLine(BT.NodeName(node) .. ": " .. table.concat(zones, ", "), 0.8, 0.8, 0.8, true)
    end
    local drops = source.d
    if drops and drops.n then
        local names = {}
        for index, name in ipairs(drops.n) do names[index] = BT.MobName(drops.ids and drops.ids[index], name) end
        GameTooltip:AddLine(L["Beute von: %s"]:format(table.concat(names, ", ")), 0.8, 0.8, 0.8, true)
    elseif drops then
        GameTooltip:AddLine(L["Beute von %d Gegnern, meiste in:"]:format(drops.c), 0.8, 0.8, 0.8)
        for _, zone in ipairs(drops.z) do
            local level = zone.lo and (" (" .. L["Stufe %s"]:format(zone.lo .. (zone.hi and zone.hi ~= zone.lo and ("–" .. zone.hi) or "")) .. ")") or ""
            GameTooltip:AddLine("   " .. ZoneName(zone.m) .. level, 0.8, 0.8, 0.8)
        end
    end
    local vendors = ItemVendors(key)
    if #vendors > 0 then
        GameTooltip:AddLine((#vendors > 3 and L["Händler (die nächsten 3 von %d):"]:format(#vendors)) or L["Händler:"], 0.8, 0.8, 0.8)
        for index = 1, math.min(#vendors, 3) do
            local name, place, distance = NpcLine(vendors[index])
            GameTooltip:AddDoubleLine("   " .. name, distance or "", 1, 1, 1, 0.7, 0.7, 0.7)
            GameTooltip:AddLine("      " .. place, 0.7, 0.7, 0.7)
        end
        GameTooltip:AddLine(L["Strg+Linksklick: Wegpunkt zum nächsten Händler"], 0.4, 0.8, 1)
    end
    if not source.h and not source.o and not drops and #vendors == 0 then
        GameTooltip:AddLine(L["Keine Bezugsquelle bekannt"], 0.7, 0.7, 0.7)
    end
end

local function TrainerTooltip(row)
    local rank, list = row.entry.rank, row.entry.nearest
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(BT.RankLabel(rank), 1, 1, 1)
    GameTooltip:AddLine(rank.skill > 0 and L["Ab Skill %d und Charakterstufe %d"]:format(rank.skill, rank.level) or L["Ohne Voraussetzung"], 0.7, 0.7, 0.7)
    if rank.how then GameTooltip:AddLine(L[rank.how], 1, 0.82, 0) end
    GameTooltip:AddLine(" ")
    if #list == 0 then GameTooltip:AddLine(L["Kein Lehrer für deine Fraktion bekannt"], 1, 0.4, 0.4) end
    for index = 1, math.min(#list, 8) do
        local name, place, distance = NpcLine(list[index])
        GameTooltip:AddDoubleLine(name, distance or "", 1, 1, 1, 0.7, 0.7, 0.7)
        GameTooltip:AddLine("   " .. place, 0.7, 0.7, 0.7)
    end
    if list[1] then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Strg+Linksklick: Wegpunkt zu %s"]:format(BT.NpcName(list[1].npc)), 0.4, 0.8, 1)
    end
    GameTooltip:Show()
end

local function CreateRow()
    local row = CreateFrame("Button", nil, window.content)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(20, 20)
    row.check:SetPoint("LEFT", 2, 0)
    row.check:SetScript("OnClick", function(self)
        row.entry.onToggle(self:GetChecked())
        BT.Update()
    end)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 4, 0)

    row.guide = row:CreateTexture(nil, "BACKGROUND")
    row.guide:SetWidth(2)
    row.guide:SetPoint("TOPLEFT", 10, 0)
    row.guide:SetPoint("BOTTOMLEFT", 10, 0)
    row.guide:SetColorTexture(0.5, 0.42, 0.2, 0.8)

    row.line = row:CreateTexture(nil, "BACKGROUND")
    row.line:SetHeight(2)
    row.line:SetPoint("LEFT", 4, 0)
    row.line:SetPoint("RIGHT", -4, 0)
    row.line:SetColorTexture(0.8, 0.65, 0.2, 0.8)

    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.right:SetPoint("RIGHT", -4, 0)
    row.right:SetJustifyH("RIGHT")
    row.right:SetWordWrap(false)

    row.barBg = row:CreateTexture(nil, "BACKGROUND")
    row.barBg:SetSize(130, 12)
    row.barBg:SetPoint("RIGHT", -140, 0)
    row.barBg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
    row.barFill = row:CreateTexture(nil, "BORDER")
    row.barFill:SetHeight(12)
    row.barFill:SetPoint("LEFT", row.barBg, "LEFT", 0, 0)

    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.count:SetPoint("CENTER", row.barBg, "CENTER", 0, 0)

    row.cost = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.cost:SetPoint("RIGHT", -64, 0)
    row.cost:SetJustifyH("RIGHT")

    row.actionButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.actionButton:SetSize(112, 22)
    row.actionButton:SetPoint("LEFT", 2, 0)
    row.actionButton:SetScript("OnClick", function()
        row.entry.onAction()
        BT.RefreshUI()
    end)

    row.guideButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.guideButton:SetSize(128, 18)
    row.guideButton:SetPoint("RIGHT", -158, 0)
    FitButtonText(row.guideButton, "GameFontHighlightSmall")
    row.guideButton:SetScript("OnClick", function(self) row.entry.onGuide(self) end)
    AddDropArrow(row.guideButton)
    row.guideButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L["Guide wechseln"], 1, 1, 1)
        if row.entry.guideFull then GameTooltip:AddLine(row.entry.guideFull, 1, 0.82, 0) end
        GameTooltip:AddLine(row.entry.guideUrl, 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    row.guideButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    row:SetScript("OnClick", function(self)
        if self.entry.kind == "trainer" and IsControlKeyDown() then
            if self.entry.nearest[1] then BT.SetWaypoint(self.entry.nearest[1], self.entry.note) end
            return
        end
        if self.entry.kind == "item" and IsControlKeyDown() then
            local vendor = ItemVendors(self.entry.key)[1]
            if vendor then BT.SetWaypoint(vendor, L["Händler für %s"]:format(BT.ItemName(self.entry.key))) end
            return
        end
        if self.entry.onClick then
            self.entry.onClick()
            BT.RefreshUI()
        end
    end)
    row:SetScript("OnEnter", function(self)
        if self.entry.kind == "item" then ItemTooltip(self)
        elseif self.entry.kind == "step" then StepTooltip(self)
        elseif self.entry.kind == "trainer" then TrainerTooltip(self) end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function ConfigureRow(row, entry)
    row.entry = entry
    local isItem = entry.kind == "item"
    row.check:SetShown(entry.onToggle ~= nil)
    row.check:SetChecked(entry.checked)
    row:EnableMouse(entry.kind ~= "gap" and entry.kind ~= "divider" and entry.kind ~= "info" and entry.kind ~= "action")
    row.actionButton:SetShown(entry.kind == "action")
    if entry.actionText then row.actionButton:SetText(entry.actionText) end
    row.guide:SetShown(entry.kind == "step" or entry.kind == "trainer")
    row.line:SetShown(entry.kind == "divider")
    row.icon:SetShown(isItem)
    row.barBg:SetShown(isItem)
    row.barFill:SetShown(isItem)
    row.count:SetShown(isItem)
    row.cost:SetShown(isItem)
    row.guideButton:SetShown(entry.guideTitle ~= nil)
    if entry.guideTitle then row.guideButton:SetText(entry.guideTitle) end
    row.right:SetText(entry.right or "")
    local rightInset = isItem and -280 or ((entry.kind == "step" or entry.kind == "trainer") and -60) or (entry.kind == "info" and -6) or (entry.kind == "prof" and -292) or -190

    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", (isItem and 28) or ((entry.onToggle or entry.kind == "info") and 26) or ((entry.kind == "step" or entry.kind == "trainer") and 26) or 6, 0) -- Schritte wie die Infozeilen eingerückt
    row.text:SetPoint("RIGHT", row, "RIGHT", rightInset, 0)
    row.text:SetFontObject((entry.kind == "head") and "GameFontNormal" or (entry.kind == "info" and "GameFontHighlightSmall") or "GameFontHighlight")
    row.text:SetText(entry.text or "")

    if isItem then
        local res = BT.result[entry.key]
        local item = BT.ITEMS[entry.key]
        local fallback = item.id and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(item.id)
        row.icon:SetTexture(item.icon and ("Interface\\Icons\\" .. item.icon) or fallback or QUESTION)
        local done = res.missing == 0
        local share = res.need > 0 and math.min(1, res.have / res.need) or 1
        row.barFill:SetWidth(math.max(1, 130 * share))
        row.barFill:SetColorTexture(done and 0.2 or 0.75, done and 0.7 or 0.55, 0.15, 0.9)
        row.count:SetText(BT.Format(res.have) .. " / " .. BT.Format(res.need))
        local price = BT.Price(entry.key)
        if price and res.missing > 0 then
            local money = BT.Money(price * res.missing)
            row.cost:SetText(BT.RECIPES[entry.key] and ("|cff777777" .. money .. "|r") or ("|cffffd100" .. money .. "|r"))
        else
            row.cost:SetText("")
        end
    end
end

local function MaterialTitles()
    local titles = { INTERMEDIATES }
    for _, title in ipairs(BT.CATS) do titles[#titles + 1] = title end
    return titles
end

local function AnyOpen()
    if tab == MATERIALS then
        for _, title in ipairs(MaterialTitles()) do
            if not BT.db.opt.matCollapsed[title] then return true end
        end
        return false
    end
    for _, prof in ipairs(BT.PROFS) do
        if IsExpanded(prof.key) then return true end
    end
    return false
end

local function ToggleAll()
    local anyOpen = AnyOpen()
    if tab == MATERIALS then
        for _, title in ipairs(MaterialTitles()) do BT.db.opt.matCollapsed[title] = anyOpen or nil end
    else
        for _, prof in ipairs(BT.PROFS) do expanded[prof.key] = not anyOpen end
    end
end

local function AddCollapseAll(list)
    local anyOpen = AnyOpen()
    list[#list + 1] = { kind = "action", height = 28, onAction = ToggleAll,
        actionText = anyOpen and L["Alle einklappen"] or L["Alle ausklappen"] }
end

local function MatchesSearch(key, item, search)
    return search == "" or item.de:lower():find(search, 1, true) or item.en:lower():find(search, 1, true)
        or BT.ItemName(key):lower():find(search, 1, true)
end

local function AddItems(list, category, title, onlyMissing, search)
    local keys = {}
    for key, item in pairs(BT.ITEMS) do
        local res = BT.result[key]
        if item.cat == category and res.need > 0 and (not onlyMissing or res.missing > 0) and MatchesSearch(key, item, search) then
            keys[#keys + 1] = key
        end
    end
    if #keys == 0 then return end
    local collapsed = BT.db.opt.matCollapsed
    local open = search ~= "" or not collapsed[title]
    local names = {}
    for _, key in ipairs(keys) do names[key] = BT.ItemName(key) end
    table.sort(keys, function(a, b) return BT.Before(names[a], names[b]) end)
    local openItems = 0
    for _, key in ipairs(keys) do
        if BT.result[key].missing > 0 then openItems = openItems + 1 end
    end
    list[#list + 1] = {
        kind = "head",
        text = (open and "|cff999999[-]|r " or "|cff999999[+]|r ") .. L[title],
        right = openItems > 0 and L["%d offen"]:format(openItems) or ("|cff33cc33" .. L["fertig"] .. "|r"),
        onClick = function() collapsed[title] = (not collapsed[title]) or nil end,
    }
    if not open then return end
    for _, key in ipairs(keys) do
        local res = BT.result[key]
        local right
        if res.missing == 0 then
            right = "|cff33cc33" .. L["fertig"] .. "|r"
        elseif BT.RECIPES[key] then
            right = "|cffffcc33" .. L["%s× bauen"]:format(BT.Format(res.crafts)) .. "|r"
        else
            right = "|cffff6666-" .. BT.Format(res.missing) .. "|r"
        end
        list[#list + 1] = { kind = "item", key = key, text = names[key], right = right }
    end
end

local function BuildMaterials(list)
    local search = (window.search:GetText() or ""):lower()
    local onlyMissing = BT.db.opt.onlyMissing
    AddCollapseAll(list)
    -- Kategorien alphabetisch, die Zwischenprodukte reihen sich mit ein
    local categories = { { index = 0, title = INTERMEDIATES } }
    for index, title in ipairs(BT.CATS) do categories[#categories + 1] = { index = index, title = title } end
    table.sort(categories, function(a, b) return BT.Before(L[a.title], L[b.title]) end)
    for _, category in ipairs(categories) do AddItems(list, category.index, category.title, onlyMissing, search) end
end

local function RecipeTag(step)
    local excluded = BT.CRAFT_EXCLUDE and BT.CRAFT_EXCLUDE[step.en]
    if excluded == "cooldown" then return "  |cffff9933[" .. L["lange Abklingzeit"] .. "]|r" end
    if excluded == "quest" then return "  |cffff9933[" .. L["nur über Quest"] .. "]|r" end
    if step.src ~= "R" then return "" end
    local state, who = BT.RecipeStatus(step)
    if state == "known" then return "  |cff33cc33[" .. L["gelernt"] .. "]|r" end
    if state == "owned" then return "  |cffffcc33[" .. L["im Besitz: %s"]:format(who) .. "]|r" end
    return "  |cffff6666[" .. L["Rezept fehlt"] .. "]|r"
end

local function RecipeCounts(prof)
    local total, found = 0, 0
    for _, step in ipairs(BT.GuideSteps(prof)) do
        if step.src == "R" and BT.StepRemaining(step, prof.key) > 0 then
            total = total + 1
            if BT.RecipeStatus(step) ~= "missing" then found = found + 1 end
        end
    end
    return total, found
end

local function TrainerEntry(prof, rank, current)
    local nearest = BT.NearestNpcs(rank)
    local learned = BT.RankLearned(prof.key, rank)
    local head = "> " .. BT.RankLabel(rank)
    local how = rank.how and (L[rank.how] .. ": ") or ""
    local text
    if learned and not current then
        -- abgeschlossen: Lehrer trotzdem nennen, die ganze Zeile grau
        local target = L["kein Lehrer für deine Fraktion"]
        if nearest[1] then
            local name, place, distance = NpcLine(nearest[1])
            target = name .. ", " .. place .. (distance and (" (" .. distance .. ")") or "")
        end
        text = "|cff777777" .. head .. "  " .. how .. target .. "|r"
    else
        local target = "|cffff6666" .. L["kein Lehrer für deine Fraktion"] .. "|r"
        if nearest[1] then
            local name, place, distance = NpcLine(nearest[1])
            target = "|cffffffff" .. name .. "|r, " .. place .. (distance and (" |cff999999(" .. distance .. ")|r") or "")
        end
        text = "|cff66ccff" .. head .. "|r  " .. how .. target
    end
    local right = learned and ("|cff33cc33" .. L["gelernt"] .. "|r")
        or (BT.RankDue(prof.key, rank) and ("|cffffcc33" .. L["fällig"] .. "|r")) or L["ab %d"]:format(rank.skill)
    local note = BT.ProfTitle(prof) .. ": " .. BT.RankLabel(rank) .. " " .. (rank.how and ("- " .. L[rank.how]) or L["lernen"])
    return { kind = "trainer", rank = rank, nearest = nearest, text = text, right = right, learned = learned, note = note }
end

local function AddProfession(list, prof, onlyMissing, trainerOnly)
    if trainerOnly then
        -- noch nicht gelernt: nur sagen, wo man ihn lernt
        list[#list + 1] = { kind = "prof", text = "|cffffd100" .. BT.ProfTitle(prof) .. "|r  |cff999999" .. L["noch nicht gelernt"] .. "|r", right = "" }
        local first = BT.TRAINERS[prof.key] and BT.TRAINERS[prof.key][1]
        if first then list[#list + 1] = TrainerEntry(prof, first, false) end
        return
    end
    local skill, who = BT.Skill(prof.key)
    local off = BT.db.opt.off[prof.key]
    local key = prof.key
    local open = IsExpanded(key)
    local total, found = RecipeCounts(prof)
    local guide = BT.ActiveGuide(prof)
    local guides = BT.GuideList(prof)
    local right = off and ("|cff999999" .. L["aus"] .. "|r") or (guide.lump and L["Einkaufsliste"] or L["%s offen"]:format(BT.Format(prof.remaining)))
    if not off and total > 0 then right = right .. "  |cffffcc33" .. L["Rezepte %d/%d"]:format(found, total) .. "|r" end
    list[#list + 1] = {
        kind = "prof",
        text = (open and "|cff999999[-]|r " or "|cff999999[+]|r ") .. "|cffffd100" .. BT.ProfTitle(prof) .. "|r  " .. L["Skill %d/300"]:format(skill) .. (who == "manuell" and ("  |cff999999(" .. L["manuell"] .. ")|r") or ""),
        right = right,
        checked = not off,
        onToggle = function(on) BT.db.opt.off[key] = (not on) or nil end,
        onClick = function() expanded[key] = not open end,
        guideTitle = #guides > 1 and guide.title or nil,
        guideFull = guide.title,
        guideUrl = guide.url,
        onGuide = function(button) OpenGuideMenu(button, prof) end,
    }
    local learned = {}
    for _, entry in ipairs(BT.ProfChars(key)) do
        local label = entry.id:match("^%S+") .. " (" .. entry.rank .. ")"
        learned[#learned + 1] = entry.id == BT.me and ("|cffffd100" .. label .. "|r") or label
    end
    if #learned > 0 then
        list[#list + 1] = { kind = "info", height = 16, text = "|cff999999" .. L["Gelernt:"] .. "|r " .. table.concat(learned, ", ") }
    end
    if not open or off then return end
    list.detailFrom = #list + 1
 local activeSteps = guide.steps
    if guide.lump then
        list[#list + 1] = { kind = "info", height = 16, text = "|cff999999" .. L["Nur Einkaufsliste, keine einzelnen Rezepte"] .. "|r" }
    end
    -- Herstellzeit und Kosten ab jetzt bei jedem Guide (fremde Guides mit ihren eigenen Zahlen, nur angezeigt)
    local plan = guide.cheapest and guide.plan
    local seconds = BT.GuideSeconds and BT.GuideSeconds(guide, prof)
    if seconds and seconds > 0 then
        list[#list + 1] = { kind = "info", height = 16, text = "|cff999999" .. L["Herstellzeit ab jetzt ca. %s"]:format(BT.Duration(seconds)) .. "|r" }
    end
    local cost = plan and plan.total
    if not cost and BT.GuideCosts then
        local entry = BT.GuideCosts()[guide.key]
        cost = entry and entry.prof[prof.key] and entry.prof[prof.key].cost
    end
    if cost and (cost > 0 or (seconds or 0) > 0) then -- fertige Berufe ohne Zeile
        list[#list + 1] = { kind = "info", height = 16, text = "|cff999999" .. L["Kosten ab jetzt ca. %s (vorhandene Materialien gratis)"]:format(BT.Money(cost)) .. "|r" }
    end
    if plan and plan.estimated then
        list[#list + 1] = { kind = "info", height = 16, text = "|cff999999" .. L["Teils geschätzt: im Auktionshaus Preise scannen"] .. "|r" }
    end
    if not prof.gather and activeSteps[#activeSteps].t < 300 then
        list[#list + 1] = { kind = "info", height = 16, text = "|cffff9933" .. L["Guide endet bei Skill %d"]:format(activeSteps[#activeSteps].t) .. "|r" }
    end
    if prof.gather then
        list[#list + 1] = { kind = "info", height = 16, text = "|cff999999" .. L["Ab Skill %d nur noch durchs Sammeln, ohne Materialbedarf"]:format(prof.steps[#prof.steps].t) .. "|r" }
    end
    local ranks = BT.TRAINERS[prof.key]
    -- aktueller Rang = höchster gelernter; bleibt auch bei "Nur Offenes" sichtbar
    local currentRank
    for index, rank in ipairs(ranks or {}) do
        if BT.RankLearned(prof.key, rank) then currentRank = index end
    end
    local nextRank = 1
    local function AddRanksBefore(limit)
        -- ein Rang erscheint vor dem ersten Schritt, der über seine Untergrenze hinausgeht (Lehrling ganz oben)
        local function Bound(rank) return (rank.from or 1) <= 1 and 0 or rank.from end
        while ranks and ranks[nextRank] and (not limit or limit > Bound(ranks[nextRank])) do
            local entry = TrainerEntry(prof, ranks[nextRank], nextRank == currentRank)
            if not onlyMissing or not entry.learned or nextRank == currentRank then list[#list + 1] = entry end
            nextRank = nextRank + 1
        end
    end
    for _, step in ipairs(activeSteps) do
        AddRanksBefore(step.t)
        local remaining = BT.StepRemaining(step, prof.key)
        if not onlyMissing or remaining > 0 then
            local range = step.f .. "-" .. step.t .. "  " .. BT.StepName(step)
            local text = remaining == 0 and ("|cff777777" .. range .. "|r") or (range .. RecipeTag(step))
            list[#list + 1] = { kind = "step", prof = prof.key, step = step, text = text,
                right = remaining == 0 and ("|cff33cc33" .. L["fertig"] .. "|r") or (step.lump and L["offen"] or (remaining .. "×")) }
        end
    end
    AddRanksBefore(nil)
end

local function AddGroup(list, profs, onlyMissing, trainerOnly)
    for index, prof in ipairs(profs) do
        if index > 1 then list[#list + 1] = { kind = "gap", height = 10 } end
        list.detailFrom = nil
        AddProfession(list, prof, onlyMissing, trainerOnly)
        -- aufgeklappte Zeilen markieren: sie zählen nicht zur Mindesthöhe des Fensters
        if list.detailFrom then
            for row = list.detailFrom, #list do list[row].detail = true end
        end
    end
end

-- Klappt alle Berufe einer Sektion gemeinsam ein oder aus.
local function SectionHead(title, profs)
    local anyOpen = false
    for _, prof in ipairs(profs) do
        anyOpen = anyOpen or IsExpanded(prof.key)
    end
    return {
        kind = "head",
        text = (anyOpen and "|cff999999[-]|r " or "|cff999999[+]|r ") .. L[title],
        onClick = function()
            for _, prof in ipairs(profs) do expanded[prof.key] = not anyOpen end
        end,
    }
end

local SECONDARY = { ["first-aid"] = true, cooking = true, fishing = true } -- Nebenberufe

local function BuildRoute(list)
    local onlyMissing = BT.db.opt.onlyMissing
    AddCollapseAll(list)
    local current, others, gathering, learnable = {}, {}, {}, {}
    local focus = BT.FocusChar()
    local filter = BT.MatFilter()
    -- Charakter gewählt: dessen Hauptberufe zählen (zwei sind möglich)
    local mains = 0
    if focus then
        for _, prof in ipairs(BT.PROFS) do
            if not SECONDARY[prof.key] and BT.IsCurrentProf(prof.key) then mains = mains + 1 end
        end
    end
    for _, prof in ipairs(BT.PROFS) do
        local group
        if focus then
            -- nur die Berufe dieses Charakters; ungelernte Nebenberufe und (bei weniger als zwei Hauptberufen)
            -- ungelernte Hauptberufe nur mit dem ersten Lehrer
            if BT.IsCurrentProf(prof.key) then group = current
            elseif SECONDARY[prof.key] or mains < 2 then group = learnable end
        elseif filter == "once" or BT.LearnedByAnyone(prof.key) then
            -- gelernte Berufe des Charakters oben, auch Sammelberufe (sie sind Hauptberufe)
            group = (BT.IsCurrentProf(prof.key) and current) or (prof.gather and gathering) or others
        end
        if group then group[#group + 1] = prof end
    end
    -- Dieser Charakter: erst die Hauptberufe, dann Erste Hilfe und Kochkunst, Angeln zuletzt (sonst alphabetisch)
    local RANK = { ["first-aid"] = 1, cooking = 1, fishing = 2 }
    local order = {}
    for index, prof in ipairs(BT.PROFS) do order[prof.key] = index end
    local function ByKind(a, b)
        local ra, rb = RANK[a.key] or 0, RANK[b.key] or 0
        if ra ~= rb then return ra < rb end
        return order[a.key] < order[b.key]
    end
    table.sort(current, ByKind)
    table.sort(learnable, ByKind)
    if #current > 0 then
        local focus = BT.FocusChar()
        list[#list + 1] = SectionHead(focus and focus ~= BT.me and L["Charakter: %s"]:format(focus) or "Dieser Charakter", current)
        AddGroup(list, current, onlyMissing)
        list.firstSectionEnd = #list -- bis hierher muss das Fenster mindestens hoch sein
        list[#list + 1] = { kind = "gap", height = 12 }
        list[#list + 1] = { kind = "divider", height = 6 }
        list[#list + 1] = { kind = "gap", height = 12 }
    end
    local groups = { { "Weitere Berufe", others }, { "Sammelberufe", gathering }, { "Noch nicht gelernt", learnable, true } }
    local first = true
    for _, entry in ipairs(groups) do
        if #entry[2] > 0 then
            if not first then
                list[#list + 1] = { kind = "gap", height = 12 }
                list[#list + 1] = { kind = "divider", height = 6 }
                list[#list + 1] = { kind = "gap", height = 12 }
            end
            first = false
            list[#list + 1] = SectionHead(entry[1], entry[2])
            AddGroup(list, entry[2], onlyMissing, entry[3])
        end
    end
end

local function SectionState(id, section)
    local _, source, ts = BT.Source(id, section)
    if source == "own" then return "|cff33cc33" .. Ago(ts) .. "|r" end
    if source == "bagnon" then return "|cffcccc66Bagnon|r" end
    return "|cff999999-|r"
end

-- Materialien eines Charakters: Stück, verschiedene, davon für die Route gebraucht, Wert (nur mit Preis)
local function CharStock(id)
    local count, kinds, needed, value, seen = 0, 0, 0, 0, {}
    local result = BT.result or {}
    for _, section in ipairs({ "bags", "bank", "mail" }) do
        for key, n in pairs(BT.Source(id, section) or {}) do
            if type(n) == "number" and n > 0 then
                count = count + n
                if not seen[key] then seen[key], kinds = true, kinds + 1 end
                local res = result[key]
                if res and (res.need or 0) > 0 then needed = needed + n end
                local price = BT.Price and BT.Price(key)
                if price then value = value + price * n end
            end
        end
    end
    return count, kinds, needed, value
end

local function CharProfessions(id)
    local rec = BT.db.chars[id]
    local skills = rec and rec.skills
    if type(skills) ~= "table" or not next(skills) then return nil end
    local parts = {}
    for _, prof in ipairs(BT.PROFS) do
        local rank = skills[prof.key]
        if rank then parts[#parts + 1] = BT.ProfTitle(prof) .. " |cffffffff" .. rank .. "|r" end
    end
    return #parts > 0 and table.concat(parts, ", ") or nil
end

local function BuildChars(list)
    local ids = BT.CharOrder()
    local chars, banks, money = 0, 0, 0
    for _, id in ipairs(ids) do
        if BT.IsGuild(id) then banks = banks + 1 else chars = chars + 1 end
        if not BT.IsGuild(id) and BT.SameFaction(id) then money = money + (BT.CharInfo(id).money or 0) end
    end
    list[#list + 1] = { kind = "info", height = 18, text = "|cff999999" .. L["%d Charaktere, %d Gildenbanken"]:format(chars, banks)
        .. "  ·  " .. L["Gold (eigene Fraktion):"] .. "|r " .. BT.Money(money) }
    list[#list + 1] = { kind = "gap", height = 6 }
    list[#list + 1] = { kind = "head", text = L["Name  (Taschen / Bank / Post)"] }
    for index, id in ipairs(ids) do
        local info = BT.CharInfo(id)
        local guildBank = BT.IsGuild(id)
        local ignored = BT.IsIgnored(id)
        if index > 1 then list[#list + 1] = { kind = "gap", height = 6 } end
        list[#list + 1] = {
            kind = "char",
            text = ColorName(id, info.class) .. (id == BT.me and ("  |cffffd100(" .. L["aktiv"] .. ")|r") or "") .. (guildBank and ("  |cff999999(" .. L["Gildenbank"] .. ")|r") or ""),
            right = SectionState(id, "bags") .. " / " .. SectionState(id, "bank") .. " / " .. SectionState(id, "mail"),
            checked = not ignored,
            onToggle = function(on) BT.db.opt.ignored[id] = not on end,
        }
        -- Zeile 1: Stufe, Gilde, Gold (Gildenbank: welche Charaktere in der Gilde sind)
        local parts = {}
        if guildBank then
            local members = {}
            for _, other in ipairs(ids) do
                if not BT.IsGuild(other) and BT.CharInfo(other).guild == id:sub(1, -2) then members[#members + 1] = other:match("^%S+") end
            end
            parts[#parts + 1] = #members > 0 and (L["Gilde von:"] .. " " .. table.concat(members, ", ")) or L["kein eigener Charakter in dieser Gilde bekannt"]
        else
            if info.level then parts[#parts + 1] = L["Stufe %d"]:format(info.level) end
            if info.guild then parts[#parts + 1] = L["Gilde:"] .. " <" .. info.guild .. ">" end
            if info.money then parts[#parts + 1] = L["Gold:"] .. " " .. BT.Money(info.money) end
        end
        if not BT.SameFaction(id) then parts[#parts + 1] = "|cffff6666" .. L["andere Fraktion, zählt nicht mit"] .. "|r"
        elseif ignored then parts[#parts + 1] = "|cffff9933" .. L["zählt nicht mit"] .. "|r" end
        if #parts > 0 then list[#list + 1] = { kind = "info", height = 16, text = "|cff999999" .. table.concat(parts, "  ·  ") .. "|r" } end
        -- Zeile 2: Berufe mit Skill
        if not guildBank then
            local profs = CharProfessions(id)
            list[#list + 1] = { kind = "info", height = 16, text = profs and ("|cff999999" .. L["Berufe:"] .. "|r " .. profs)
                or ("|cff999999" .. L["Berufe unbekannt – einmal mit diesem Charakter einloggen"] .. "|r") }
        end
        -- Zeile 3: Materialien
        local count, kinds, needed, value = CharStock(id)
        local text = count > 0 and L["Materialien: %s Stück (%d verschiedene), davon %s gebraucht"]:format(BT.Format(count), kinds, BT.Format(needed))
            or L["Materialien: keine"]
        if value > 0 then text = text .. ", " .. L["Wert ca. %s"]:format(BT.Money(value)) end
        list[#list + 1] = { kind = "info", height = 16, text = "|cff999999" .. text .. "|r" }
    end
    list[#list + 1] = { kind = "gap", height = 12 }
    list[#list + 1] = { kind = "divider", height = 6 }
    list[#list + 1] = { kind = "info", height = 16, text = "|cff999999" .. L["Grün: eigener Scan (Taschen beim Einloggen, Bank und Post beim Öffnen)."]
        .. (next(BT.imported or {}) and (" " .. L["Gelb: aus Bagnon."]) or "") .. " " .. L["Haken: Bestand zählt mit."] .. "|r" }
end

local function FilterLabel()
    local filter = BT.db.opt.matFilter
    if filter == "me" then return L["Aktueller Charakter"] .. (BT.me and (": " .. BT.me:match("^%S+")) or "") end
    if filter == "learned" then return L["Gelernte Berufe (bester Charakter)"] end
    if filter == "once" then return L["Alle Berufe (auch ungelernte)"] end
    return filter or L["Alle Charaktere (gelernte Berufe)"]
end

BT.FilterLabel = function() return FilterLabel() end

local function OpenFilterMenu(button)
    local options = {
        { text = L["Aktueller Charakter"] .. "  |cff999999" .. L["immer der eingeloggte Charakter"] .. "|r", value = "me" },
        { text = L["Alle Charaktere (gelernte Berufe)"] .. "  |cff999999" .. L["jeder Charakter mit seinen Berufen"] .. "|r" },
        { text = L["Gelernte Berufe (bester Charakter)"] .. "  |cff999999" .. L["jeder gelernte Beruf einmal"] .. "|r", value = "learned" },
        { text = L["Alle Berufe (auch ungelernte)"] .. "  |cff999999" .. L["jeder Beruf einmal, ungelernte ab Skill 1"] .. "|r", value = "once" },
    }
    for _, id in ipairs(BT.FilterChars()) do
        local names = {}
        for _, prof in ipairs(BT.PROFS) do
            if BT.db.chars[id].skills[prof.key] then names[#names + 1] = BT.ProfTitle(prof) end
        end
        if #names > 0 then options[#options + 1] = { text = id .. "  |cff999999" .. table.concat(names, ", ") .. "|r", value = id } end
    end
    ShowMenu(button, options, 380, BT.db.opt.matFilter, function(value) BT.db.opt.matFilter = value end)
end

function BT.RefreshUI()
    if not window or not window:IsShown() then return end
    local list = {}
    if tab == MATERIALS then BuildMaterials(list)
    elseif tab == ROUTE then BuildRoute(list)
    else BuildChars(list) end

    local y = 0
    for index, entry in ipairs(list) do
        local row = rows[index] or CreateRow()
        rows[index] = row
        local height = entry.height or ROW_HEIGHT
        ConfigureRow(row, entry)
        row:SetHeight(height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", window.content, "RIGHT", 0, 0)
        row:Show()
        y = y + height
    end
    for index = #list + 1, #rows do rows[index]:Hide() end
    window.content:SetHeight(math.max(1, y))
    -- ohne Bedienelemente unter den Tabs (Charaktere) beginnt die Liste direkt darunter
    window.scroll:SetPoint("TOPLEFT", 12, tab == CHARS and -58 or -CONTENT_TOP)

    -- Mindesthöhe: auf dem Tab Route passt der Abschnitt "Dieser Charakter" ganz hinein (höchstens 90 % des Bildschirms)
    local minHeight = MIN_HEIGHT
    if tab == ROUTE and list.firstSectionEnd then
        local section = 0
        -- eingeklappte Größe: Aufklappen ändert die Fensterhöhe nicht
        for index = 1, list.firstSectionEnd do
            if not list[index].detail then section = section + (list[index].height or ROW_HEIGHT) end
        end
        local screen = UIParent and UIParent.GetHeight and UIParent:GetHeight()
        local cap = (type(screen) == "number" and screen > 0) and screen * 0.9 or 1400
        minHeight = math.max(MIN_HEIGHT, math.min(CONTENT_TOP + section + CONTENT_BOTTOM, cap))
    end
    if window.SetResizeBounds then window:SetResizeBounds(MIN_WIDTH, minHeight, 1600, 1400)
    elseif window.SetMinResize then window:SetMinResize(MIN_WIDTH, minHeight) end
    local h = window.GetHeight and window:GetHeight()
    if type(h) == "number" and h < minHeight then window:SetHeight(minHeight) end
    window.minHeight = minHeight

    local need, have = BT.needTotal or 0, BT.haveTotal or 0
    local percent = need > 0 and math.floor(have / need * 100) or 100
    window.summary:SetText(L["Grundmaterialien:"] .. " " .. BT.Format(have) .. " / " .. BT.Format(need) .. "  (" .. percent .. " %)")
    window.search:SetShown(tab == MATERIALS)
    window.searchLabel:SetShown(tab == MATERIALS)
    window.filter:SetShown(tab == MATERIALS)
    window.filter:SetText(FilterLabel())
    window.guideAll:SetShown(tab == ROUTE)
    window.guideAllLabel:SetShown(tab == ROUTE)
    window.guideAll:SetText(next(BT.db.opt.guide) and L["gemischt"] or BT.GlobalGuideTitle())
    window.guideAllCost:SetShown(tab == ROUTE)
    if tab == ROUTE and BT.GuideCosts then
        local active = BT.GuideCosts().active
        local text = L["ca. %s"]:format(BT.Money(active.total))
        if (active.learn or 0) > 0 then text = text .. " |cff999999(" .. L["davon Lehrer/Rezepte %s"]:format(BT.Money(active.learn)) .. ")|r" end
        window.guideAllCost:SetText(text)
    end
    window.scan:SetShown(tab == MATERIALS)
    window.scan:SetEnabled(BT.atAH or BT.scanText ~= nil)
    window.scan:SetText(BT.scanText or L["Preise scannen"])
    window.cost:SetShown(tab == MATERIALS)
    local learnText = ""
    if tab == MATERIALS and BT.GuideCosts then
        local learn = BT.GuideCosts().active.learn or 0
        if learn > 0 then learnText = "  |cff999999+ " .. L["Lehrer/Rezepte %s"]:format(BT.Money(learn)) .. "|r" end
    end
    window.cost:SetText(L["Kaufkosten"] .. ": |cffffd100" .. BT.Money(BT.cost or 0) .. "|r" .. learnText .. ((BT.unpriced or 0) > 0 and ("  |cff999999(" .. L["%d ohne Preis"]:format(BT.unpriced) .. ")|r") or ""))
    window.missing:SetShown(tab ~= CHARS)
    window.missing:ClearAllPoints()
    window.missing:SetPoint("TOPLEFT", tab == MATERIALS and 200 or 12, -80) -- ohne Suchfeld rückt es nach links
    window.missing:SetChecked(BT.db.opt.onlyMissing)
    window.noGather:SetShown(tab == MATERIALS)
    window.noGather:SetChecked(BT.db.opt.noGather)
    for index, button in ipairs(window.tabs) do
        if index == tab then button:LockHighlight() else button:UnlockHighlight() end
    end
end

local function CreateWindow()
    local f = CreateFrame("Frame", "BerufeTrackerFrame", UIParent, "BasicFrameTemplateWithInset")
    window = f
    f:SetSize(WIDTH, 600)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnShow", function()
        if BT.MarkPlansDirty then BT.MarkPlansDirty() end -- beim Öffnen mit den aktuellen Daten neu rechnen
        BT.Update()
    end)
    f:SetScript("OnHide", function() f.filterMenu:Hide() end)
    tinsert(UISpecialFrames, "BerufeTrackerFrame")
    local title = f.TitleText or (f.TitleContainer and f.TitleContainer.TitleText)
    if title then title:SetText("BerufeTracker") end

    f.tabs = {}
    local labels = { [MATERIALS] = L["Materialien"], [ROUTE] = L["Route"], [CHARS] = L["Charaktere"] }
    for position, index in ipairs({ ROUTE, MATERIALS, CHARS }) do -- Reihenfolge der Tabs von links
        local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        button:SetSize(110, 22)
        button:SetPoint("TOPLEFT", 12 + (position - 1) * 114, -28)
        button:SetText(labels[index])
        button:SetScript("OnClick", function()
            tab = index
            f.filterMenu:Hide()
            f.scroll:SetVerticalScroll(0)
            BT.RefreshUI()
        end)
        f.tabs[index] = button
    end

    f.summary = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.summary:SetPoint("LEFT", f.tabs[CHARS], "RIGHT", 10, 0) -- zwischen den Tabs und dem rechten Rand
    f.summary:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    f.summary:SetJustifyH("RIGHT")
    f.summary:SetWordWrap(false)

    f.searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.searchLabel:SetPoint("TOPLEFT", 16, -85)
    f.searchLabel:SetText(L["Suche:"])
    f.search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.search:SetSize(120, 20)
    f.search:SetPoint("LEFT", f.searchLabel, "RIGHT", 10, 0)
    f.search:SetAutoFocus(false)
    f.search:SetScript("OnTextChanged", function() BT.RefreshUI() end)
    f.search:SetScript("OnEscapePressed", f.search.ClearFocus)

    f.filter = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.filter:SetSize(240, 22)
    f.filter:SetPoint("TOPLEFT", 16, -55)
    f.filter:SetScript("OnClick", OpenFilterMenu)
    AddDropArrow(f.filter)
    FitButtonText(f.filter)

    f.guideAllLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.guideAllLabel:SetPoint("TOPLEFT", 18, -61)
    f.guideAllLabel:SetText(L["Guide für alle:"])
    f.guideAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.guideAll:SetSize(220, 22)
    f.guideAll:SetPoint("LEFT", f.guideAllLabel, "RIGHT", 8, 0)
    f.guideAll:SetScript("OnClick", OpenAllGuidesMenu)
    AddDropArrow(f.guideAll)
    FitButtonText(f.guideAll)
    f.guideAllCost = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.guideAllCost:SetPoint("LEFT", f.guideAll, "RIGHT", 8, 0)
    f.guideAllCost:SetPoint("RIGHT", f, "RIGHT", -16, 0) -- rechtsbündig wie "Grundmaterialien"
    f.guideAllCost:SetJustifyH("RIGHT")
    f.guideAllCost:SetWordWrap(false)

    f.scan = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.scan:SetSize(116, 22)
    f.scan:SetPoint("TOPLEFT", 264, -55)
    f.scan:SetScript("OnClick", function() BT.StartScan() end)

    f.cost = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.cost:SetPoint("LEFT", f.scan, "RIGHT", 10, 0) -- zwischen "Preise scannen" und dem rechten Rand
    f.cost:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    f.cost:SetJustifyH("RIGHT")
    f.cost:SetWordWrap(false)

    f.filterMenu = CreateFrame("Frame", nil, f)
    f.filterMenu:SetSize(380, 40)
    f.filterMenu:SetPoint("TOPLEFT", f.filter, "BOTTOMLEFT", 0, -2)
    f.filterMenu:SetFrameStrata("DIALOG")
    f.filterMenu:SetClampedToScreen(true)
    f.filterMenu:EnableMouse(true)
    local menuBackground = f.filterMenu:CreateTexture(nil, "BACKGROUND")
    menuBackground:SetAllPoints()
    menuBackground:SetColorTexture(0.05, 0.05, 0.07, 0.97)
    f.filterMenu.buttons = {}
    f.filterMenu:Hide()

    f.missing = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.missing:SetSize(22, 22)
    f.missing:SetPoint("TOPLEFT", 12, -80)
    f.missing:SetScript("OnClick", function(self)
        BT.db.opt.onlyMissing = self:GetChecked() or nil
        BT.RefreshUI()
    end)
    local label = f.missing:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", f.missing, "RIGHT", 2, 0)
    label:SetText(L["Nur Offenes"])

    f.noGather = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.noGather:SetSize(22, 22)
    f.noGather:SetPoint("TOPLEFT", 300, -80)
    f.noGather:SetScript("OnClick", function(self)
        BT.db.opt.noGather = self:GetChecked() or nil
        BT.Update()
    end)
    local noGatherLabel = f.noGather:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noGatherLabel:SetPoint("LEFT", f.noGather, "RIGHT", 2, 0)
    noGatherLabel:SetText(L["Sammelberufe ausschließen"])

    f.scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", 12, -106)
    f.scroll:SetPoint("BOTTOMRIGHT", -34, 12)
    f.content = CreateFrame("Frame", nil, f.scroll)
    f.content:SetSize(WIDTH - 46, 1)
    f.scroll:SetScrollChild(f.content)
    f.scroll:HookScript("OnVerticalScroll", function() f.filterMenu:Hide() end)

    -- Größe frei ziehbar (Griff unten rechts); die Größe bleibt gespeichert.
    if f.SetResizable then
        f:SetResizable(true)
        if f.SetResizeBounds then f:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, 1600, 1400)
        elseif f.SetMinResize then f:SetMinResize(MIN_WIDTH, MIN_HEIGHT) f:SetMaxResize(1600, 1400) end
    end
    local saved = BT.db and BT.db.opt.windowSize
    if type(saved) == "table" and saved[1] and saved[2] then f:SetSize(math.max(MIN_WIDTH, saved[1]), math.max(MIN_HEIGHT, saved[2])) end
    f:SetScript("OnSizeChanged", function(self, width)
        if type(width) == "number" then self.content:SetWidth(math.max(1, width - 46)) end
    end)
    f.content:SetWidth(math.max(1, (f:GetWidth() or WIDTH) - 46))
    f.grip = CreateFrame("Button", nil, f)
    f.grip:SetSize(16, 16)
    f.grip:SetPoint("BOTTOMRIGHT", -4, 4)
    f.grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    f.grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    f.grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    f.grip:SetScript("OnMouseDown", function() f.filterMenu:Hide() f:StartSizing("BOTTOMRIGHT") end)
    f.grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        BT.db.opt.windowSize = { math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5) }
        BT.RefreshUI()
    end)

    f:Hide()
end

local function CreateMinimapButton()
    local button = CreateFrame("Button", "BerufeTrackerMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\Icons\\Trade_BlackSmithing")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local function Place()
        local angle = math.rad(BT.db.opt.minimapAngle or 200)
        local radius = Minimap:GetWidth() / 2 + 5
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    end
    button:SetScript("OnClick", BT.Toggle)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            BT.db.opt.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            Place()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("BerufeTracker")
        GameTooltip:AddLine(L["Klicken: Fenster öffnen"], 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Place()
    C_Timer.After(1, Place) -- die Minimap-Größe steht beim Login evtl. noch nicht fest
    Minimap:HookScript("OnSizeChanged", Place)
end

function BT.Toggle()
    if window:IsShown() then window:Hide() else window:Show() end
end

local waypointLabel

local function RefreshWaypointLabel()
    local wp, distance, angle = BT.ActiveWaypoint()
    if not wp then
        waypointLabel:Hide()
        return
    end
    waypointLabel.arrow:SetShown(angle ~= nil)
    if angle then waypointLabel.arrow:SetRotation(angle) end
    waypointLabel.title:SetText(wp.name .. (distance and ("  |cffffffff" .. BT.Format(distance) .. " m|r") or ""))
    waypointLabel.note:SetText((wp.note and (wp.note .. "  ") or "") .. "|cff999999" .. wp.place .. "|r")
end

-- Öffnet die Karte beim Ziel. Über C_Map.OpenWorldMap, weil ein eigenes SetMapID die Karte für die Sitzung belasten würde.
local function OpenWaypointMap()
    local wp = BT.ActiveWaypoint()
    if not wp then return end
    if C_Map.OpenWorldMap then
        if InCombatLockdown() then
            print("|cffffcc00BerufeTracker:|r " .. L["Im Kampf lässt sich die Karte nicht öffnen."])
            return
        end
        C_Map.OpenWorldMap(wp.m)
    else
        if not WorldMapFrame:IsShown() then WorldMapFrame:Show() end
        WorldMapFrame:SetMapID(wp.m)
    end
    C_Timer.After(0.2, function() -- OpenMaps zusammenhängende Karte zusätzlich auf den Punkt zentrieren
        local api = _G.OpenMapAPI
        if api and api.IsStitched and api.IsStitched() then
            local u, v = api.WorldFromMap(wp.m, wp.x / 100, wp.y / 100)
            if u then api.ShowWorld(u, v) end
        end
    end)
end

local function CreateWaypointLabel()
    local f = CreateFrame("Frame", "BerufeTrackerWaypointLabel", UIParent)
    waypointLabel = f
    f:SetSize(390, 46)
    f:SetPoint("TOP", 0, -110)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    local dragged = false
    f:SetScript("OnMouseDown", function() dragged = false end)
    f:SetScript("OnDragStart", function(self)
        dragged = true
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and not dragged then OpenWaypointMap() end
    end)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L["Klicken: Karte beim Ziel öffnen"], 1, 1, 1)
        GameTooltip:AddLine(L["Ziehen: Leiste verschieben"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local background = f:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.65)
    f.arrow = f:CreateTexture(nil, "ARTWORK")
    f.arrow:SetSize(38, 38)
    f.arrow:SetPoint("LEFT", 6, 0)
    f.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 50, -8)
    f.title:SetPoint("RIGHT", -24, 0)
    f.title:SetJustifyH("LEFT")
    f.note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.note:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.note:SetPoint("RIGHT", -8, 0)
    f.note:SetJustifyH("LEFT")
    f.note:SetWordWrap(false)
    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetSize(22, 22)
    f.close:SetPoint("TOPRIGHT", 0, 0)
    f.close:SetScript("OnClick", function()
        BT.db.opt.waypoint = nil
        if C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
        f:Hide()
    end)
    local elapsed = 0
    f:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.05 then
            elapsed = 0
            RefreshWaypointLabel()
        end
    end)
    f:Hide()
end

local mapLabel

-- Wo die Beschriftung hin muss: bei OpenMap ein Punkt auf der Karte, sonst Blizzards Markierung.
local function MapLabelTarget(wp)
    local map = WorldMapFrame
    local api = _G.OpenMapAPI
    if api and api.IsStitched and api.IsStitched() then
        local u, v = api.WorldFromMap(wp.m, wp.x / 100, wp.y / 100)
        local x, y
        if u then x, y = api.MapFromWorld(map:GetMapID(), u, v) end
        if not x then return nil end
        local canvas = map:GetCanvas()
        mapLabel.anchor:ClearAllPoints()
        mapLabel.anchor:SetPoint("CENTER", canvas, "TOPLEFT", x * canvas:GetWidth(), -y * canvas:GetHeight())
        return mapLabel.anchor
    end
    if map.EnumeratePinsByTemplate then
        for pin in map:EnumeratePinsByTemplate("WaypointLocationPinTemplate") do
            if pin:IsShown() then return pin end
        end
    end
    return nil
end

local function RefreshMapLabel()
    local wp = BT.ActiveWaypoint()
    local target = wp and MapLabelTarget(wp)
    if not target then
        mapLabel:Hide()
        return
    end
    mapLabel.title:SetText(wp.name)
    mapLabel.note:SetText(wp.note or wp.place)
    mapLabel:SetSize(math.max(mapLabel.title:GetStringWidth(), mapLabel.note:GetStringWidth()) + 14, 34)
    local api = _G.OpenMapAPI
    local artTop = api and api.ArtTopLevel and api.ArtTopLevel() or 0
    mapLabel:SetFrameLevel(math.max(WorldMapFrame:GetCanvas():GetFrameLevel(), artTop) + 600)
    mapLabel:ClearAllPoints()
    mapLabel:SetPoint("LEFT", target, "RIGHT", 8, 0)
    mapLabel:Show()
end

local function EnsureMapLabel()
    if mapLabel or not (WorldMapFrame and WorldMapFrame.ScrollContainer) then return end
    local f = CreateFrame("Frame", "BerufeTrackerMapLabel", WorldMapFrame.ScrollContainer)
    mapLabel = f
    local background = f:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.7)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOPLEFT", 7, -4)
    f.note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.note:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)
    f.anchor = CreateFrame("Frame", nil, WorldMapFrame:GetCanvas())
    f.anchor:SetSize(1, 1)
    f:Hide()
    local driver = CreateFrame("Frame", "BerufeTrackerMapDriver", WorldMapFrame)
    local elapsed = 0
    driver:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            elapsed = 0
            RefreshMapLabel()
        end
    end)
end

function BT.ShowWaypointLabel()
    EnsureMapLabel()
    if not BT.ActiveWaypoint() then return end
    RefreshWaypointLabel()
    waypointLabel:Show()
end

-- Zusatzzeilen im Tooltip der Kartenmarkierung.
local function HookWaypointTooltip()
    GameTooltip:HookScript("OnShow", function(tip)
        local owner = tip:GetOwner()
        local wp = owner and owner.pinTemplate == "WaypointLocationPinTemplate" and BT.db.opt.waypoint
        if not wp then return end
        tip:AddLine(wp.name, 1, 0.82, 0)
        if wp.note then tip:AddLine(wp.note, 1, 1, 1, true) end
        tip:Show()
    end)
end

local function Plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local itemById, itemsByNode
local function ItemKeyById(id)
    if not itemById then
        itemById = {}
        for key, item in pairs(BT.ITEMS) do
            if item.id then itemById[item.id] = key end
        end
    end
    return itemById[id]
end

-- Vorkommen in der Welt -> Materialien daraus; das Hauptmaterial (dort an erster Stelle genannt) zuerst.
local function ItemsOfNode(name)
    if not itemsByNode then
        itemsByNode = {}
        for key, source in pairs(BT.SOURCES or {}) do
            for index, node in ipairs(source.o or {}) do
                local name = BT.NodeName(node) -- so heißt das Vorkommen im Tooltip der Spielsprache
                local list = itemsByNode[name] or {}
                itemsByNode[name] = list
                list[#list + 1] = { key = key, rank = index }
            end
        end
        for _, list in pairs(itemsByNode) do
            table.sort(list, function(a, b)
                if a.rank ~= b.rank then return a.rank < b.rank end
                return BT.Before(BT.ItemName(a.key), BT.ItemName(b.key))
            end)
        end
    end
    return itemsByNode[name]
end

-- Handwerksmaterial laut Spiel (Item-Klasse 7, "Handwerkswaren")?
local TRADE_GOODS = (Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods) or 7
local function IsTradeGood(id)
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not instant then return false end
    local ok, _, _, _, _, _, classID = pcall(instant, id)
    return ok and classID == TRADE_GOODS
end

local function TrackerHeader(tip)
    tip:AddLine(" ")
    tip:AddLine("BerufeTracker |cff999999(" .. FilterLabel() .. (BT.db.opt.noGather and (", " .. L["ohne Sammelberufe"]) or "") .. ")|r", 1, 0.82, 0)
end

-- Sammelberufe steigen durchs Sammeln: Ab welchem Skill ein Kraut bzw. Erz sammelbar ist (Classic-Werte).
-- Orange bis +25, gelb bis +50, grün bis +100, danach grau (keine Skillpunkte mehr).
local GATHER_REQ = {
    herbalism = { peacebloom = 1, silverleaf = 1, earthroot = 15, mageroyal = 50, briarthorn = 70, stranglekelp = 85,
        bruiseweed = 100, ["wild-steelbloom"] = 115, ["grave-moss"] = 120, kingsblood = 125, liferoot = 150, fadeleaf = 160,
        goldthorn = 170, ["khadgars-whisker"] = 185, wintersbite = 195, firebloom = 205, ["purple-lotus"] = 210,
        ["arthas-tears"] = 220, sungrass = 230, blindweed = 235, ["ghost-mushroom"] = 245, gromsblood = 250,
        ["golden-sansam"] = 260, dreamfoil = 270, ["mountain-silversage"] = 280, plaguebloom = 285, icecap = 290,
        ["black-lotus"] = 300, swiftthistle = 50 },
    mining = { ["copper-ore"] = 1, ["tin-ore"] = 65, ["silver-ore"] = 75, ["iron-ore"] = 125, ["gold-ore"] = 155,
        ["mithril-ore"] = 175, ["truesilver-ore"] = 230, ["dark-iron-ore-11370"] = 230, ["thorium-ore"] = 245,
        ["rough-stone"] = 1, ["coarse-stone"] = 65, ["heavy-stone"] = 125, ["solid-stone"] = 175, ["dense-stone"] = 245 },
}
BT.GATHER_REQ = GATHER_REQ

-- Zeile "Kräuterkunde (75): Sammeln bringt Skillpunkte" für den aktuellen (bzw. im Filter gewählten) Charakter.
-- Gibt true zurück, wenn eine Zeile hinzukam.
local function GatherLine(tip, key)
    local id = BT.FocusChar and BT.FocusChar() or BT.me
    local rec = id and BT.db.chars[id]
    local added = false
    for profKey, list in pairs(GATHER_REQ) do
        local need = list[key]
        local skill = rec and rec.skills and rec.skills[profKey]
        if need and skill then
            local name = BT.ProfTitle(BT.PROF_BY_KEY[profKey]) .. " (" .. skill .. ")"
            if skill < need then
                tip:AddLine(L["%s: sammelbar ab Skill %d"]:format(name, need), 1, 0.4, 0.4)
            elseif skill < need + 100 then
                local r, g, b = 1, 0.5, 0.25 -- orange
                if skill >= need + 50 then r, g, b = 0.25, 0.75, 0.25 elseif skill >= need + 25 then r, g, b = 1, 1, 0 end
                tip:AddLine(L["%s: Sammeln bringt Skillpunkte"]:format(name), r, g, b)
            else
                tip:AddLine(L["%s: grau, keine Skillpunkte mehr"]:format(name), 0.5, 0.5, 0.5)
            end
            added = true
        end
    end
    return added
end

-- Bedarf eines Materials nach den aktuellen Filtern; allProfs = alle Berufe statt der größten vier.
AddNeedLines = function(tip, key, allProfs)
    local res = BT.result and BT.result[key]
    if not res then return end
    TrackerHeader(tip)
    if res.need == 0 then
        -- Sammelberufe brauchen ihr Material trotzdem: zum Skillen
        if not GatherLine(tip, key) then tip:AddLine(L["Wird nicht mehr gebraucht"], 0.6, 0.6, 0.6) end
        return
    end
    GatherLine(tip, key)
    tip:AddDoubleLine(L["Benötigt"], BT.Format(res.need), 1, 1, 1, 1, 1, 1)
    tip:AddDoubleLine(L["Im Besitz"], BT.Format(res.have), 1, 1, 1, 1, 1, 1)
    if res.missing > 0 then
        tip:AddDoubleLine(L["Fehlt noch"], BT.Format(res.missing), 1, 1, 1, 1, 0.4, 0.4)
    else
        tip:AddLine(L["Genug vorhanden"], 0.2, 0.8, 0.2)
    end
    local shown = 0
    for _, part in ipairs(ProfessionShares(res)) do
        if part.amount > 0 and (allProfs or shown < 4) then
            shown = shown + 1
            tip:AddDoubleLine("   " .. BT.ProfTitle(BT.PROF_BY_KEY[part.key]), BT.Format(part.amount), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
        end
    end
end

-- Zusatzzeilen in Item-Tooltips (Taschen, Bank, Auktionshaus, Beute, Links)
-- und im Tooltip von Erzadern und Kräutern in der Welt.
-- Stufenbereiche aus den Bezugshinweisen (dieselben, die der Material-Tooltip zeigt):
-- Stoff von Humanoiden, Leder von Wildtieren (Kürschnern), Verzauberungsmaterial nach Gegenstandsstufe.
local CLOTH_HINT = "Beute von humanoiden Gegnern, Stufe %s"
local LEATHER_HINT = "Kürschnerei: Tiere häuten, Stufe %s"
local hintRanges = {}
local function KeysForLevel(hint, level)
    local ranges = hintRanges[hint]
    if not ranges then
        ranges = {}
        for key, source in pairs(BT.SOURCES or {}) do
            if source.h == hint and source.ha then
                local lo, hi = source.ha:match("(%d+)%D+(%d+)")
                if lo then ranges[#ranges + 1] = { key = key, lo = tonumber(lo), hi = tonumber(hi) } end
            end
        end
        table.sort(ranges, function(a, b) return a.lo < b.lo end)
        hintRanges[hint] = ranges
    end
    local keys = {}
    for _, range in ipairs(ranges) do
        if level >= range.lo and level <= range.hi then keys[#keys + 1] = range.key end
    end
    return keys
end

-- Eine Zeile "Material   fehlt X (Bestand/Bedarf)", nur wenn es laut Filter gebraucht wird.
local function NeedLine(tip, key, tag)
    local res = BT.result and BT.result[key]
    if not res or res.need == 0 then return false end
    local state = res.missing > 0 and ("|cffff6666" .. L["fehlt %s"]:format(BT.Format(res.missing)) .. "|r") or ("|cff33cc33" .. L["genug"] .. "|r")
    tip:AddDoubleLine(BT.ItemName(key) .. (tag and (" |cff999999(" .. tag .. ")|r") or ""),
        state .. " |cff999999(" .. BT.Format(res.have) .. "/" .. BT.Format(res.need) .. ")|r", 1, 1, 1, 1, 1, 1)
    return true
end

-- Mehrere Materialien: Kopfzeile nur, wenn mindestens eines gebraucht wird; jedes Material nur einmal.
local function NeedBlock(tip, entries, subtitle)
    local seen, shown = {}, false
    for _, entry in ipairs(entries) do
        local res = not seen[entry.key] and BT.result and BT.result[entry.key]
        seen[entry.key] = true
        if res and res.need > 0 then
            if not shown then
                TrackerHeader(tip)
                if subtitle then tip:AddLine(subtitle, 0.8, 0.8, 0.8) end
                shown = true
            end
            NeedLine(tip, entry.key, entry.tag)
        end
    end
    return shown
end

-- Kreaturtyp: über die Spiel-ID (1 Wildtier, 7 Humanoid), sonst über bekannte Namen in allen Sprachen.
local TYPE_NAMES = {
    [1] = { "Beast", "Wildtier", "Bête", "Bestia", "Fera", "Животное", "야수", "野兽", "野獸" },
    [7] = { "Humanoid", "Humanoide", "Humanoïde", "Umanoide", "Гуманоид", "인간형", "人型生物" },
}
local function IsCreatureType(unit, typeID)
    local name = UnitCreatureType and Plain(UnitCreatureType(unit))
    if not name then return false end
    if C_CreatureInfo and C_CreatureInfo.GetCreatureTypeInfo then
        local ok, info = pcall(C_CreatureInfo.GetCreatureTypeInfo, typeID)
        if ok and info and info.name == name then return true end
    end
    for _, known in ipairs(TYPE_NAMES[typeID]) do
        if known == name then return true end
    end
    return false
end

-- Beute-Eintrag {Material, Chance %, Menge von, bis, Kürschnern} -> "11 %, 1-2" bzw. "39 %, Kürschnern"
local function DropTag(drop)
    local chance = (drop[2] >= 10 or drop[2] == math.floor(drop[2])) and ("%.0f"):format(drop[2]) or ("%.1f"):format(drop[2])
    local count = drop[3] == drop[4] and tostring(drop[3]) or (drop[3] .. "-" .. drop[4])
    return chance .. " %, " .. count .. (drop[5] and (", " .. L["Kürschnern"]) or "")
end
BT.DropTag = DropTag

-- Stoff (Humanoide) und Leder zum Kürschnern (Wildtiere) nach Stufe; nur wenn Stufe und Typ lesbar sind.
local function LevelEntries(unit, entries)
    local level = UnitLevel and Plain(UnitLevel(unit))
    if type(level) ~= "number" or level <= 0 then return end
    if IsCreatureType(unit, 7) then
        for _, key in ipairs(KeysForLevel(CLOTH_HINT, level)) do entries[#entries + 1] = { key = key } end
    elseif IsCreatureType(unit, 1) then
        for _, key in ipairs(KeysForLevel(LEATHER_HINT, level)) do entries[#entries + 1] = { key = key, tag = L["Kürschnern"] } end
    end
end

-- Gegner mit lesbarer GUID: was er laut QuestieDB droppt, dazu Stoff/Leder nach Stufe.
local function AddMobLines(tip, unit, guid)
    if not BT.result or not unit then return end
    if Plain(UnitIsPlayer and UnitIsPlayer(unit)) == true then return end
    if Plain(UnitCanAttack and UnitCanAttack("player", unit)) == false then return end
    local npcID = type(guid) == "string" and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    local entries = {}
    for _, drop in ipairs(npcID and BT.MOB_DROPS and BT.MOB_DROPS[npcID] or {}) do entries[#entries + 1] = { key = drop[1], tag = DropTag(drop) } end
    LevelEntries(unit, entries)
    NeedBlock(tip, entries) -- kein tip:Show() hier: das stößt bei Gegnern die nächste Verarbeitung an (Endlosschleife)
end

-- Gegner mit geschützter GUID/Name (WoW Forever): Das Addon darf den Namen nicht lesen oder vergleichen.
-- Deshalb wird für jeden Beute-Gegner der aktuellen Karte der Textblock vorab gebaut; sichere Spielfunktionen
-- vergleichen den geschützten Namen mit jedem Kandidaten und lassen nur den passenden Block sichtbar.
-- Das Addon erfährt nie, welcher Gegner es ist. Die Zahl der Zeilen darf nicht vom Ergebnis abhängen: immer genau eine.
-- Aktuelle Karte: In WoW Forever ist GetBestMapForUnit zeitweise geschützt (z. B. im Kampf). Deshalb wird die Karte
-- bei Zonenwechseln und immer dann gemerkt, wenn sie lesbar ist; sonst gilt die zuletzt bekannte (wie bei ATT).
local lastMapID
local function CurrentMapID()
    local raw = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local mapID = Plain(raw)
    if type(mapID) == "number" and mapID > 0 then lastMapID = mapID end
    return lastMapID, raw
end
BT.CurrentMapID = CurrentMapID
do
    local frame = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED" }) do
        frame:RegisterEvent(event)
    end
    frame:SetScript("OnEvent", function() CurrentMapID() end)
end

local SecretMob = {}
do
    local function CanSelect()
        return Enum and Enum.CollationStrength and Enum.CollationStrength.Identical
            and Enum.NormalizationForm and Enum.NormalizationForm.Nfc
            and C_Intl and type(C_Intl.CompareStrings) == "function" and type(C_Intl.IsNormalized) == "function"
            and C_StringUtil and type(C_StringUtil.TruncateWhenZero) == "function" and type(C_StringUtil.WrapString) == "function"
            and C_CurveUtil and type(C_CurveUtil.EvaluateColorValueFromBoolean) == "function"
    end
    SecretMob.CanSelect = CanSelect
    -- Gleiche Texte ergeben 0 -> leerer Text -> der Marker ist normalisiert. Sonst bleibt ein "e" mit
    -- kombinierendem Akzent stehen, das nicht NFC-normalisiert ist. Ergebnis ggf. geschützt, nur weiterreichen.
    local function Matches(secretText, publicText)
        local comparison = C_Intl.CompareStrings(secretText, publicText, Enum.CollationStrength.Identical)
        local marker = C_StringUtil.WrapString(C_StringUtil.TruncateWhenZero(comparison), "e\204\129", "")
        return C_Intl.IsNormalized(marker, Enum.NormalizationForm.Nfc)
    end
    -- Tor 1: ein unsichtbarer Farbcode vor dem Text wird vollständig, der Text bleibt; Tor 0: alles entfällt.
    local function Fragment(gate, text)
        return C_StringUtil.WrapString(C_StringUtil.TruncateWhenZero(gate), "|c0000000", "|r" .. text)
    end

    -- Aktuelle Karte und die übergeordneten Karten bis zur Zone (Gebäude, Höhlen und Unterzonen haben eigene IDs).
    local function MapChain(mapID)
        local chain, guard = { [mapID] = true }, 0
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        while info and info.parentMapID and info.parentMapID > 0 and guard < 6 and (info.mapType or 3) > 3 do
            chain[info.parentMapID] = true
            info = C_Map.GetMapInfo(info.parentMapID)
            guard = guard + 1
        end
        return chain
    end
    SecretMob.MapChain = MapChain

    local cache = {}
    local function Candidates(mapID)
        if cache.result == BT.result and cache.map == mapID and cache.filter == BT.db.opt.matFilter then return cache.list end
        local maps = mapID and MapChain(mapID) -- ohne Karte: alle Beute-Gegner (gekappt, s. u.)
        local byName, order = {}, {}
        for id, info in pairs(BT.MOB_INFO or {}) do
            local here = not maps
            for _, m in ipairs(maps and info.m or {}) do if maps[m] then here = true break end end
            local drops = here and BT.MOB_DROPS and BT.MOB_DROPS[id]
            if drops then
                local name = BT.MobName(id, info.de)
                local entry = byName[name]
                if not entry then
                    entry = { name = name, drops = {}, seen = {} }
                    byName[name] = entry
                    order[#order + 1] = entry
                end
                for _, drop in ipairs(drops) do
                    if not entry.seen[drop[1]] then entry.seen[drop[1]] = true entry.drops[#entry.drops + 1] = drop end
                end
            end
        end
        local list = {}
        local header = "|cffffd100BerufeTracker|r |cff999999(" .. BT.FilterLabel() .. ")|r"
        for _, entry in ipairs(order) do
            local lefts, rights = { header }, { " " }
            for _, drop in ipairs(entry.drops) do
                local key = drop[1]
                local res = BT.result and BT.result[key]
                if res and res.need > 0 then
                    lefts[#lefts + 1] = BT.ItemName(key) .. " |cff999999(" .. DropTag(drop) .. ")|r"
                    rights[#rights + 1] = (res.missing > 0 and ("|cffff6666" .. L["fehlt %s"]:format(BT.Format(res.missing)) .. "|r") or ("|cff33cc33" .. L["genug"] .. "|r"))
                        .. " |cff999999(" .. BT.Format(res.have) .. "/" .. BT.Format(res.need) .. ")|r"
                end
            end
            if #lefts > 1 and (maps or #list < 150) then -- ohne Karte gekappt, damit das Hovern flüssig bleibt
                list[#list + 1] = { name = entry.name, left = table.concat(lefts, "\n"), right = table.concat(rights, "\n") }
            end
        end
        cache.result, cache.map, cache.filter, cache.list = BT.result, mapID, BT.db.opt.matFilter, list
        cache.mobsHere = #order
        return list
    end
    SecretMob.Candidates = Candidates
    SecretMob.cache = cache

    function SecretMob.Attach(tip, secretName)
        if not CanSelect() or not BT.result then return false end
        local list = Candidates(CurrentMapID())
        if #list == 0 then return false end
        local leftOut, rightOut = "", ""
        for _, candidate in ipairs(list) do
            local gate = C_CurveUtil.EvaluateColorValueFromBoolean(Matches(secretName, candidate.name), 1, 0)
            leftOut = leftOut .. Fragment(gate, candidate.left)
            rightOut = rightOut .. Fragment(gate, candidate.right)
        end
        tip:AddDoubleLine(leftOut, rightOut)
        return true
    end
end
BT.SecretMob = SecretMob

-- Entzaubern (Classic-Tabelle): Ergebnisse je Gegenstandsstufe mit Chance und Menge.
-- Grün: Staub/Essenz/Splitter (Rüstung 75 % Staub, Waffe 75 % Essenz), Blau: Splitter, Lila: Splitter bzw. Nexuskristall.
local DE_MATS = { -- Schlüssel -> Item-ID, Ersatzname deutsch, englisch (wenn das Spiel den Namen noch nicht kennt)
    ["strange-dust"] = { 10940, "Seltsamer Staub", "Strange Dust" },
    ["soul-dust"] = { 11083, "Seelenstaub", "Soul Dust" },
    ["vision-dust"] = { 11137, "Visionenstaub", "Vision Dust" },
    ["dream-dust"] = { 11176, "Traumstaub", "Dream Dust" },
    ["illusion-dust"] = { 16204, "Illusionsstaub", "Illusion Dust" },
    ["lesser-magic-essence"] = { 10938, "Geringe Magieessenz", "Lesser Magic Essence" },
    ["greater-magic-essence"] = { 10939, "Große Magieessenz", "Greater Magic Essence" },
    ["lesser-astral-essence"] = { 10998, "Geringe Astralessenz", "Lesser Astral Essence" },
    ["greater-astral-essence"] = { 11082, "Große Astralessenz", "Greater Astral Essence" },
    ["lesser-mystic-essence"] = { 11134, "Geringe Mystikeressenz", "Lesser Mystic Essence" },
    ["greater-mystic-essence"] = { 11135, "Große Mystikeressenz", "Greater Mystic Essence" },
    ["lesser-nether-essence"] = { 11174, "Geringe Netheressenz", "Lesser Nether Essence" },
    ["greater-nether-essence"] = { 11175, "Große Netheressenz", "Greater Nether Essence" },
    ["lesser-eternal-essence"] = { 16202, "Geringe ewige Essenz", "Lesser Eternal Essence" },
    ["greater-eternal-essence"] = { 16203, "Große ewige Essenz", "Greater Eternal Essence" },
    ["small-glimmering-shard"] = { 10978, "Kleiner gleißender Splitter", "Small Glimmering Shard" },
    ["large-glimmering-shard"] = { 11084, "Großer gleißender Splitter", "Large Glimmering Shard" },
    ["small-glowing-shard"] = { 11138, "Kleiner leuchtender Splitter", "Small Glowing Shard" },
    ["large-glowing-shard"] = { 11139, "Großer leuchtender Splitter", "Large Glowing Shard" },
    ["small-radiant-shard"] = { 11177, "Kleiner strahlender Splitter", "Small Radiant Shard" },
    ["large-radiant-shard"] = { 11178, "Großer strahlender Splitter", "Large Radiant Shard" },
    ["small-brilliant-shard"] = { 14343, "Kleiner glänzender Splitter", "Small Brilliant Shard" },
    ["large-brilliant-shard"] = { 14344, "Großer glänzender Splitter", "Large Brilliant Shard" },
    ["nexus-crystal"] = { 20725, "Nexuskristall", "Nexus Crystal" },
}
-- Grün: Stufe von, bis, Staub {von, bis}, Essenz {von, bis}, Splitter, Anteile Staub/Essenz/Splitter (Rüstung)
local DE_GREEN = {
    { 5, 15, "strange-dust", 1, 2, "lesser-magic-essence", 1, 2, nil, 80, 20, 0 },
    { 16, 20, "strange-dust", 2, 3, "greater-magic-essence", 1, 2, "small-glimmering-shard", 75, 20, 5 },
    { 21, 25, "strange-dust", 4, 6, "lesser-astral-essence", 1, 2, "small-glimmering-shard", 75, 15, 10 },
    { 26, 30, "soul-dust", 1, 2, "greater-astral-essence", 1, 2, "large-glimmering-shard", 75, 20, 5 },
    { 31, 35, "soul-dust", 2, 5, "lesser-mystic-essence", 1, 2, "small-glowing-shard", 75, 20, 5 },
    { 36, 40, "vision-dust", 1, 2, "greater-mystic-essence", 1, 2, "large-glowing-shard", 75, 20, 5 },
    { 41, 45, "vision-dust", 2, 5, "lesser-nether-essence", 1, 2, "small-radiant-shard", 75, 20, 5 },
    { 46, 50, "dream-dust", 1, 2, "greater-nether-essence", 1, 2, "large-radiant-shard", 75, 20, 5 },
    { 51, 55, "dream-dust", 2, 5, "lesser-eternal-essence", 1, 2, "small-brilliant-shard", 75, 20, 5 },
    { 56, 60, "illusion-dust", 1, 2, "greater-eternal-essence", 1, 2, "large-brilliant-shard", 75, 20, 5 },
    { 61, 65, "illusion-dust", 2, 5, "greater-eternal-essence", 2, 3, "large-brilliant-shard", 75, 20, 5 },
}
-- Blau: Stufe von, bis, Splitter (immer 1 Stück)
local DE_BLUE = {
    { 1, 25, "small-glimmering-shard" }, { 26, 30, "large-glimmering-shard" }, { 31, 35, "small-glowing-shard" },
    { 36, 40, "large-glowing-shard" }, { 41, 45, "small-radiant-shard" }, { 46, 50, "large-radiant-shard" },
    { 51, 55, "small-brilliant-shard" }, { 56, 65, "large-brilliant-shard" },
}
-- Lila: Stufe von, bis, Ergebnis, Menge von, bis
local DE_PURPLE = {
    { 40, 45, "small-radiant-shard", 2, 4 }, { 46, 50, "large-radiant-shard", 2, 4 },
    { 51, 55, "small-brilliant-shard", 2, 4 }, { 56, 60, "nexus-crystal", 1, 1 }, { 61, 94, "nexus-crystal", 1, 2 },
}

-- Gegenstände, die in WoW Forever anders entzaubert werden als in Classic (Item-ID -> Ergebnis, Chance, Menge von, bis).
-- Quelle: Wowhead-Entzauberstatistik für Forever.
local DE_ITEM = {
    [271204] = { -- Fleischhakenschlitzer (blau, entzaubert wie grün)
        { "greater-magic-essence", 70, 2, 3 }, { "strange-dust", 25, 3, 4 }, { "small-glimmering-shard", 5, 1, 1 },
    },
}
BT.DE_ITEM = DE_ITEM
local DE_CLASSIC_MAX_ID = 24283 -- höchste Item-ID aus Classic; darüber sind es neue Forever-Gegenstände

local function DisenchantResults(quality, itemLevel, isWeapon)
    local results = {}
    local function add(key, chance, lo, hi) if key and chance > 0 then results[#results + 1] = { key, chance, lo, hi } end end
    if quality == 2 then
        for _, row in ipairs(DE_GREEN) do
            if itemLevel >= row[1] and itemLevel <= row[2] then
                local dust, essence = row[10], row[11]
                if isWeapon then dust, essence = essence, dust end -- Waffen geben vor allem Essenz
                add(row[3], dust, row[4], row[5])
                add(row[6], essence, row[7], row[8])
                add(row[9], row[12], 1, 1)
            end
        end
    elseif quality == 3 then
        for _, row in ipairs(DE_BLUE) do
            if itemLevel >= row[1] and itemLevel <= row[2] then add(row[3], 100, 1, 1) end
        end
    elseif quality == 4 then
        for _, row in ipairs(DE_PURPLE) do
            if itemLevel >= row[1] and itemLevel <= row[2] then add(row[3], 100, row[4], row[5]) end
        end
    end
    table.sort(results, function(a, b) return a[2] > b[2] end)
    return results
end
BT.DisenchantResults = DisenchantResults

local function DisenchantName(key)
    if BT.ITEMS[key] then return BT.ItemName(key) end
    local mat = DE_MATS[key]
    local get = C_Item and C_Item.GetItemNameByID
    local ok, name = pcall(get or function() end, mat[1])
    if ok and type(name) == "string" and name ~= "" and not (issecretvalue and issecretvalue(name)) then return name end
    return BT.LOCALE == "deDE" and mat[2] or mat[3]
end

-- Waffen und Rüstung (grün und besser): alle Entzauber-Ergebnisse mit Chance und Menge, bei jedem
-- entzauberbaren Gegenstand. Benötigte Ergebnisse farbig mit Bedarf, die anderen grau.
local function AddDisenchantLines(tip, id)
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not (instant and get) then return end
    local ok, _, _, _, _, _, classID = pcall(instant, id)
    if not ok or (classID ~= 2 and classID ~= 4) then return end -- nur Waffen und Rüstung
    local ok2, _, _, quality, itemLevel = pcall(get, id)
    if not ok2 or type(quality) ~= "number" or quality < 2 or quality > 4 or type(itemLevel) ~= "number" then return end
    local results = DE_ITEM[id] or DisenchantResults(quality, itemLevel, classID == 2)
    if #results == 0 then return end
    TrackerHeader(tip)
    tip:AddLine(L["Entzaubern ergibt ca.:"], 0.8, 0.8, 0.8)
    if not DE_ITEM[id] and id > DE_CLASSIC_MAX_ID then
        tip:AddLine(L["(Classic-Werte, in Forever evtl. anders)"], 0.6, 0.6, 0.6)
    end
    for _, result in ipairs(results) do
        local tag = DropTag(result)
        local res = BT.result and BT.result[result[1]]
        if not (res and res.need > 0 and NeedLine(tip, result[1], tag)) then
            tip:AddLine(DisenchantName(result[1]) .. " (" .. tag .. ")", 0.6, 0.6, 0.6)
        end
    end
end

local function HookItemTooltips()
    local function OnItem(tip, data)
        if tip ~= GameTooltip and tip ~= ItemRefTooltip then return end
        local id = data and Plain(data.id)
        if not id and tip.GetItem then
            local _, link = tip:GetItem()
            link = Plain(link)
            id = link and tonumber(link:match("item:(%d+)"))
        end
        local key = id and ItemKeyById(id)
        if key then
            AddNeedLines(tip, key)
        elseif id and IsTradeGood(id) then
            -- Handwerksmaterial, das keine Route braucht: sagen, statt zu schweigen
            TrackerHeader(tip)
            tip:AddLine(L["Für keine Route gebraucht"], 0.6, 0.6, 0.6)
        elseif id then
            AddDisenchantLines(tip, id)
        end
    end
    -- Gegner-Tooltips: das Spiel baut sie laufend neu auf. Sperre gegen Wiedereintritt, Zeilen nur einmal je Inhalt.
    local mobBusy, mobDone = false, false
    local function MobTooltip(tip, data)
        local name, unit, guid
        if TooltipUtil and TooltipUtil.GetDisplayedUnit then
            local ok, n, u, g = pcall(TooltipUtil.GetDisplayedUnit, tip)
            if ok then name, unit, guid = n, u, g end
        end
        if unit == nil or (issecretvalue and issecretvalue(unit)) then
            local ok, _, u = pcall(tip.GetUnit, tip)
            unit = (ok and Plain(u)) or "mouseover"
        end
        if guid == nil then guid = data and data.guid end
        if guid == nil and UnitGUID then guid = UnitGUID(unit) end
        if issecretvalue and issecretvalue(guid) then
            -- geschützt: Name nur an sichere Spielfunktionen weitergeben, nie selbst lesen
            if name == nil and UnitName then name = UnitName(unit) end
            local attached = SecretMob.Attach(tip, name)
            local entries = {}
            LevelEntries(unit, entries)
            NeedBlock(tip, entries)
            return "geschützt", attached
        end
        AddMobLines(tip, unit, guid)
        return "lesbar"
    end
    local function OnUnit(tip, data)
        if tip ~= GameTooltip or mobBusy or mobDone then return end
        mobBusy, mobDone = true, true
        local ok, mode, attached = pcall(MobTooltip, tip, data)
        BT.mobDebug = { at = time(), mode = ok and mode or nil, attached = attached, error = not ok and tostring(mode) or nil }
        mobBusy = false
    end
    GameTooltip:HookScript("OnTooltipCleared", function() mobDone = false end)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnit)
    else
        GameTooltip:HookScript("OnTooltipSetUnit", OnUnit)
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItem)
    else
        for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
            if tip then tip:HookScript("OnTooltipSetItem", function(self) OnItem(self) end) end
        end
    end

    -- Vorkommen in der Welt: Bleibt der Tooltip beim Wechsel von einem Vorkommen zum nächsten offen, kommt kein
    -- OnShow mehr, nur neuer Inhalt. Deshalb zusätzlich nach jedem Setzen des Inhalts (TooltipDataProcessor) prüfen;
    -- nodeDone verhindert doppelte Zeilen und wird mit jedem neuen Inhalt zurückgesetzt.
    local nodeDone = false
    local function AddNodeLines(tip, name, fromShow)
        if nodeDone or not BT.result then return end
        if tip.GetItem and tip:GetItem() then return end
        if tip.GetUnit and tip:GetUnit() then return end
        local owner = tip.GetOwner and tip:GetOwner()
        if owner and window and owner.GetParent and owner:GetParent() == window.content then return end -- eigenes Fenster
        local line = _G.GameTooltipTextLeft1
        local text = Plain(name) or (line and Plain(line:GetText()))
        local list = text and ItemsOfNode(text)
        if not list then return end
        nodeDone = true
        local any = false
        for _, entry in ipairs(list) do
            local res = BT.result[entry.key]
            if res and res.need > 0 then
                if not any then TrackerHeader(tip) any = true end
                local state = res.missing > 0 and ("|cffff6666" .. L["fehlt %s"]:format(BT.Format(res.missing)) .. "|r") or ("|cff33cc33" .. L["genug"] .. "|r")
                tip:AddDoubleLine(BT.ItemName(entry.key), state .. " |cff999999(" .. BT.Format(res.have) .. "/" .. BT.Format(res.need) .. ")|r", 1, 1, 1, 1, 1, 1)
            end
        end
        if not any then TrackerHeader(tip) end
        local gathered = false
        for _, entry in ipairs(list) do
            if not gathered and GATHER_REQ and (GATHER_REQ.herbalism[entry.key] or GATHER_REQ.mining[entry.key]) then
                gathered = GatherLine(tip, entry.key)
            end
        end
        if not any and not gathered then tip:AddLine(L["Wird nicht mehr gebraucht"], 0.6, 0.6, 0.6) end
        -- Größe nur auf dem OnShow-Weg anpassen; während der Verarbeitung des Inhalts macht das Spiel es selbst
        if fromShow then tip:Show() end
    end
    GameTooltip:HookScript("OnTooltipCleared", function() nodeDone = false end)
    GameTooltip:HookScript("OnShow", function(tip) AddNodeLines(tip, nil, true) end)
    local kind = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and (TooltipDataProcessor.AllTypes or (Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object))
    if kind then
        TooltipDataProcessor.AddTooltipPostCall(kind, function(tip, data)
            if tip ~= GameTooltip then return end
            local first = data and data.lines and data.lines[1]
            AddNodeLines(tip, first and first.leftText)
        end)
    end
end

-- Fügt hinter dem Chat-Link des aktiven Wegpunkts dessen Beschreibung als normalen Text ein.
local function IsWaypointLink(text, wp)
    for mapID, x, y in text:gmatch("worldmap:(%d+):(%d+):(%d+)") do
        if tonumber(mapID) == wp.m and math.abs(tonumber(x) - wp.x * 100) <= 30 and math.abs(tonumber(y) - wp.y * 100) <= 30 then
            return true
        end
    end
    local ok, link = pcall(C_Map.GetUserWaypointHyperlink or function() end)
    return ok and link ~= nil and text:find(link, 1, true) ~= nil
end

local handledLink = setmetatable({}, { __mode = "k" }) -- je Chatzeile: dieser Link wurde schon ergänzt
local chatInfo = { boxes = 0 }

local function CheckChatBox(box, source)
    local text = box:GetText() or ""
    if not text:find("worldmap:", 1, true) then
        handledLink[box] = nil
        return
    end
    chatInfo.source, chatInfo.text = source, text
    local wp = BT.ActiveWaypoint()
    if not wp then
        chatInfo.result = "kein aktiver Wegpunkt"
    elseif not IsWaypointLink(text, wp) then
        chatInfo.result = "Link passt nicht zu " .. wp.m .. " " .. wp.x .. " " .. wp.y
    elseif handledLink[box] then
        chatInfo.result = "bereits ergänzt"
    else
        handledLink[box] = true -- bleibt gesetzt, solange der Link dasteht: von Hand Gelöschtes kommt nicht wieder
        local description = wp.name .. (wp.note and (" - " .. wp.note) or "")
        if text:find(description, 1, true) or #text + #description + 1 > 250 then
            chatInfo.result = "Text schon da oder zu lang"
            return
        end
        chatInfo.result = "ergänzt"
        C_Timer.After(0, function() -- erst wenn das Einfügen des Links ganz durch ist
            local now = box:GetText() or ""
            if now:find("worldmap:", 1, true) and not now:find(description, 1, true) then box:Insert(" " .. description) end
        end)
    end
end

local function ActiveChatBox()
    local get = (ChatFrameUtil and ChatFrameUtil.GetActiveWindow) or ChatEdit_GetActiveWindow
    return get and get() or nil
end

local function CheckActiveBox()
    local box = ActiveChatBox()
    if box then CheckChatBox(box, "Link-Funktion") end
end

local function HookChatBoxes()
    local seen = {}
    for index = 1, NUM_CHAT_WINDOWS or 10 do
        local frame = _G["ChatFrame" .. index]
        local box = _G["ChatFrame" .. index .. "EditBox"] or (frame and frame.editBox)
        if type(box) == "table" and box.HookScript and not seen[box] then
            seen[box] = true
            chatInfo.boxes = chatInfo.boxes + 1
            box:HookScript("OnTextChanged", function(self) CheckChatBox(self, "Chatzeile") end)
        end
    end
    if ChatFrameUtil then
        for _, name in ipairs({ "InsertLink", "OpenChat" }) do
            if ChatFrameUtil[name] then hooksecurefunc(ChatFrameUtil, name, CheckActiveBox) end
        end
    end
    for _, name in ipairs({ "ChatEdit_InsertLink", "ChatFrame_OpenChat" }) do
        if _G[name] then hooksecurefunc(name, CheckActiveBox) end
    end
end

-- /berufe mobdebug: zeigt, was der Gegner-Tooltip über den Gegner unter der Maus sieht.
local function DebugValue(value)
    if issecretvalue and issecretvalue(value) then return "|cffff6666geschützt|r" end
    return tostring(value)
end
function BT.PrintMobDebug()
    local tag = "|cffffcc00BerufeTracker:|r "
    local unit = "mouseover"
    print(tag .. "mouseover vorhanden: " .. DebugValue(UnitExists and UnitExists(unit)))
    if not (UnitExists and UnitExists(unit)) then
        print(tag .. "Maus über einen Gegner halten und /berufe mobdebug per Tastenkürzel oder Makro ausführen.")
    end
    print(tag .. "Spieler: " .. DebugValue(UnitIsPlayer and UnitIsPlayer(unit)) .. ", angreifbar: " .. DebugValue(UnitCanAttack and UnitCanAttack("player", unit)))
    local guid = UnitGUID and UnitGUID(unit)
    print(tag .. "GUID: " .. DebugValue(guid) .. ", Stufe: " .. DebugValue(UnitLevel and UnitLevel(unit)) .. ", Typ: " .. DebugValue(UnitCreatureType and UnitCreatureType(unit)))
    local plainGuid = Plain(guid)
    local npcID = type(plainGuid) == "string" and tonumber(plainGuid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    local drops = npcID and BT.MOB_DROPS and BT.MOB_DROPS[npcID]
    local names = {}
    for index, drop in ipairs(drops or {}) do names[index] = drop[1] .. " " .. DropTag(drop) end
    print(tag .. "NPC-ID: " .. tostring(npcID) .. ", Beute-Einträge: " .. (#names > 0 and table.concat(names, ", ") or "-"))
    print(tag .. "Wildtier: " .. tostring(IsCreatureType(unit, 1)) .. ", Humanoid: " .. tostring(IsCreatureType(unit, 7)))
    local info = BT.mobDebug
    print(tag .. "Sichere Namensauswahl verfügbar: " .. tostring(SecretMob.CanSelect() and true or false))
    local mapID, raw = CurrentMapID()
    print(tag .. "Karte gerade: " .. (raw == nil and "leer" or DebugValue(raw)) .. ", gemerkt: " .. tostring(mapID))
    local maps = {}
    for m in pairs(mapID and SecretMob.MapChain(mapID) or {}) do maps[#maps + 1] = m end
    local list = SecretMob.Candidates(mapID)
    print(tag .. "Karten: " .. (#maps > 0 and table.concat(maps, ", ") or "alle (keine bekannt)") .. ", Beute-Gegner: " .. tostring(SecretMob.cache.mobsHere) .. ", davon mit benötigter Beute: " .. #list)
    for index = 1, math.min(#list, 5) do print(tag .. "   " .. list[index].name) end
    print(tag .. "Letzter Gegner-Tooltip: " .. (info and ("vor " .. (time() - info.at) .. " s, GUID " .. tostring(info.mode) .. ", Block angehängt: " .. tostring(info.attached) .. ", Fehler: " .. tostring(info.error or "keiner")) or "noch keiner"))
end

function BT.PrintChatDebug()
    local wp = BT.ActiveWaypoint()
    local tag = "|cffffcc00BerufeTracker:|r "
    print(tag .. "Chatzeilen: " .. chatInfo.boxes .. ", Wegpunkt: " .. (wp and (wp.name .. " " .. wp.m .. " " .. wp.x .. " " .. wp.y) or "keiner"))
    local ok, link = pcall(C_Map.GetUserWaypointHyperlink or function() end)
    print(tag .. "Spiel-Link: " .. tostring(ok and link or "-"):gsub("|", "||"))
    print(tag .. "Zuletzt: " .. tostring(chatInfo.result or "noch kein Karten-Link gesehen") .. " (" .. tostring(chatInfo.source or "-") .. ")")
    print(tag .. "Text: " .. tostring(chatInfo.text or "-"):gsub("|", "||"))
end


-- ===== Berufsfenster des Spiels: Rezepte der aktiven Route markieren =====
-- Offene Schritte der aktiven Route aller Berufe, auffindbar über das hergestellte Item ("#ID") oder den Namen.
-- Der erste offene Schritt eines Berufs ist der aktuelle.
local routeIndex, routeIndexKey = {}, nil
local function NormalizeName(text) return (tostring(text):lower():gsub("[%p%s]", "")) end

function BT.RouteRecipeIndex()
    local key = tostring(BT.solveStamp) .. "|" .. tostring(BT.planVersion)
    if routeIndexKey == key then return routeIndex end
    local index = {}
    for _, prof in ipairs(BT.PROFS) do
        if not BT.db.opt.off[prof.key] then
            local current = true
            for _, step in ipairs(BT.GuideSteps(prof)) do
                local open = not step.lump and BT.StepRemaining(step, prof.key) or 0
                if open > 0 then
                    local entry = { step = step, prof = prof, open = open, current = current }
                    current = false
                    for _, alias in ipairs(step.aliases or {}) do
                        if not index[alias] then index[alias] = entry end
                    end
                end
            end
        end
    end
    routeIndex, routeIndexKey = index, key
    return index
end

-- Routen-Eintrag zu einem Rezept des Berufsfensters (über das hergestellte Item, sonst den Namen).
function BT.RouteRecipeInfo(name, outputID)
    local index = BT.RouteRecipeIndex()
    return (outputID and index["#" .. outputID]) or (name and index[NormalizeName(name)]) or nil
end

-- Tooltip-Zeilen: Routen-Abschnitt und je Material Bedarf, Bestand und wo es liegt.
function BT.AddRouteRecipeLines(tip, entry)
    local step = entry.step
    tip:AddLine(" ")
    tip:AddLine("BerufeTracker |cff999999(" .. BT.FilterLabel() .. ")|r", 1, 0.82, 0)
    tip:AddDoubleLine((entry.current and L["Aktueller Routen-Schritt"] or L["Späterer Routen-Schritt"]) .. " " .. step.f .. "-" .. step.t,
        L["%s× offen"]:format(BT.Format(entry.open)), 1, 1, 1, 1, 0.82, 0)
    for _, reagent in ipairs(step.r) do
        local key, per = reagent[1], reagent[2]
        local need = per * entry.open
        local have = (BT.totals and BT.totals[key]) or 0
        local color = have >= need and "|cff33cc33" or "|cffff6666"
        tip:AddDoubleLine("  " .. BT.ItemName(key), color .. BT.Format(have) .. "/" .. BT.Format(need) .. "|r", 1, 1, 1, 1, 1, 1)
        local owners = {}
        for id, count in pairs((BT.byChar or {})[key] or {}) do
            if count > 0 then owners[#owners + 1] = { id = id, count = count } end
        end
        table.sort(owners, function(a, b) return a.count > b.count end)
        for i = 1, math.min(3, #owners) do
            local who = owners[i].id == BT.me and ("|cffffd100" .. owners[i].id .. "|r") or owners[i].id
            tip:AddDoubleLine("     " .. who, BT.Format(owners[i].count), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
        end
    end
end

-- Hergestelltes Item eines Rezepts (zwischengespeichert, die Abfrage ist nicht ganz billig).
local outputCache = {}
local function RecipeOutput(recipeID)
    if not recipeID then return nil end
    if outputCache[recipeID] ~= nil then return outputCache[recipeID] or nil end
    local ui = C_TradeSkillUI
    local out = false
    if ui and ui.GetRecipeSchematic then
        local ok, schematic = pcall(ui.GetRecipeSchematic, recipeID, false)
        if ok and type(schematic) == "table" and schematic.outputItemID then out = schematic.outputItemID end
    end
    outputCache[recipeID] = out
    return out or nil
end

local profHook = { hooked = false, rows = 0, marked = 0 }

-- Eine Zeile der Rezeptliste: Balken links (hell = aktueller Schritt), rechts die offene Anzahl.
local function DecorateRecipeRow(frame, node)
    local data = node and node.GetData and node:GetData()
    local info = type(data) == "table" and data.recipeInfo
    if not rawget(frame, "btBar") then
        frame.btBar = frame:CreateTexture(nil, "OVERLAY")
        frame.btBar:SetPoint("TOPLEFT", 0, -1)
        frame.btBar:SetPoint("BOTTOMLEFT", 0, 1)
        frame.btBar:SetWidth(3)
        frame.btText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.btText:SetPoint("RIGHT", -4, 0)
        frame:HookScript("OnEnter", function(self)
            local entry = rawget(self, "btEntry")
            if not entry then return end
            if not GameTooltip:IsOwned(self) then GameTooltip:SetOwner(self, "ANCHOR_RIGHT") end
            BT.AddRouteRecipeLines(GameTooltip, entry)
            GameTooltip:Show()
        end)
        frame:HookScript("OnLeave", function(self) if rawget(self, "btEntry") and GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    end
    profHook.rows = profHook.rows + 1
    local entry = type(info) == "table" and BT.RouteRecipeInfo(info.name, RecipeOutput(info.recipeID)) or nil
    frame.btEntry = entry
    if entry then
        profHook.marked = profHook.marked + 1
        if entry.current then frame.btBar:SetColorTexture(1, 0.82, 0, 1) else frame.btBar:SetColorTexture(0.6, 0.5, 0.2, 0.6) end
        frame.btText:SetText((entry.current and "|cffffd100" or "|cff998844") .. BT.Format(entry.open) .. "×|r")
        frame.btBar:Show()
        frame.btText:Show()
    else
        frame.btBar:Hide()
        frame.btText:Hide()
    end
end

local function RecipeScrollBox()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local list = page and page.RecipeList
    return list and list.ScrollBox
end

-- Alle sichtbaren Zeilen neu markieren (z. B. nach einer neuen Route).
function BT.RefreshProfessionMarks()
    local box = RecipeScrollBox()
    if not (box and box.ForEachFrame and box.IsVisible and box:IsVisible()) then return end
    pcall(box.ForEachFrame, box, function(frame)
        local node = frame.GetElementData and frame:GetElementData()
        pcall(DecorateRecipeRow, frame, node)
    end)
end

local function HookProfessions()
    if profHook.hooked then return true end
    local box = RecipeScrollBox()
    if not (box and ScrollUtil and ScrollUtil.AddInitializedFrameCallback) then return false end
    local ok = pcall(ScrollUtil.AddInitializedFrameCallback, box, function(_, frame, node)
        local done, err = pcall(DecorateRecipeRow, frame, node)
        if not done then profHook.error = tostring(err) end
    end, profHook, true)
    profHook.hooked = ok
    return ok
end

function BT.InitProfessionsHook()
    if HookProfessions() then return end
    -- Das Berufsfenster wird erst bei Bedarf geladen
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:RegisterEvent("TRADE_SKILL_SHOW")
    loader:SetScript("OnEvent", function(self)
        if HookProfessions() then
            self:UnregisterAllEvents()
            BT.RefreshProfessionMarks()
        end
    end)
end

function BT.PrintProfessionDebug()
    local tag = "|cffffcc00BerufeTracker:|r "
    print(tag .. "Berufsfenster gefunden: " .. tostring(RecipeScrollBox() ~= nil) .. ", Haken gesetzt: " .. tostring(profHook.hooked))
    print(tag .. "Zeilen geprüft: " .. profHook.rows .. ", markiert: " .. profHook.marked .. (profHook.error and (", Fehler: " .. profHook.error) or ""))
    local count = 0
    for _ in pairs(BT.RouteRecipeIndex()) do count = count + 1 end
    print(tag .. "Offene Routen-Rezepte (Namen und Item-IDs): " .. count)
end

function BT.InitUI()
    CreateWindow()
    CreateMinimapButton()
    CreateWaypointLabel()
    HookWaypointTooltip()
    HookItemTooltips()
    HookChatBoxes()
    BT.InitProfessionsHook()
    EnsureMapLabel()
    if not mapLabel then -- die Weltkarte wird teils erst bei Bedarf geladen
        local loader = CreateFrame("Frame")
        loader:RegisterEvent("ADDON_LOADED")
        loader:SetScript("OnEvent", function(self, _, name)
            if name == "Blizzard_WorldMap" then
                EnsureMapLabel()
                self:UnregisterAllEvents()
            end
        end)
    end
    C_Timer.After(2, BT.ShowWaypointLabel) -- nach einem Reload ist der Wegpunkt erst etwas später bekannt
end

-- BerufeTracker: Fenster mit den Tabs Route, Materialien und Charaktere.
local ADDON, BT = ...

local WIDTH, ROW_HEIGHT, MATERIALS, ROUTE, CHARS = 640, 22, 1, 2, 3
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local tab, window = ROUTE, nil
local rows = {}
local INTERMEDIATES = "Zwischenprodukte (herstellen)"
local expanded = {} -- nur für diese Sitzung, sonst gilt: offen = Beruf des aktiven Charakters

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
    menu:SetHeight(8 + #options * 20)
    menu:Show()
end

local function AddDropArrow(button)
    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(18, 18)
    arrow:SetPoint("RIGHT", 0, 0)
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
end

local function OpenGuideMenu(button, prof)
    local options = {}
    for _, guide in ipairs(BT.GuideList(prof)) do
        local last = guide.steps[#guide.steps].t
        local notes = {}
        if guide.lump then notes[#notes + 1] = "Einkaufsliste" end
        if last < 300 then notes[#notes + 1] = "bis " .. last end
        options[#options + 1] = { value = guide.key,
            text = guide.title .. (#notes > 0 and ("  |cff999999" .. table.concat(notes, ", ") .. "|r") or "") }
    end
    ShowMenu(button, options, 210, BT.ActiveGuide(prof).key, function(key) BT.SetGuide(prof, key) end)
end

local function OpenAllGuidesMenu(button)
    local options = {}
    for _, guide in ipairs(BT.ALL_GUIDES) do options[#options + 1] = { value = guide.key, text = guide.title } end
    local selected = not next(BT.db.opt.guide) and (BT.db.opt.guideAll or "metabot") or nil
    ShowMenu(button, options, 230, selected, BT.SetAllGuides)
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
    if sec < 3600 then return "vor " .. math.max(1, math.floor(sec / 60)) .. " Min" end
    if sec < 86400 then return "vor " .. math.floor(sec / 3600) .. " Std" end
    return "vor " .. math.floor(sec / 86400) .. " Tagen"
end

local AddSourceLines -- weiter unten, braucht NpcLine
local AddNeedLines -- weiter unten, gleiche Darstellung wie im Item-Tooltip des Spiels

local function ItemTooltip(row)
    local key, res = row.entry.key, BT.result[row.entry.key]
    local item = BT.ITEMS[key]
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(item.de, 1, 1, 1)
    AddNeedLines(GameTooltip, key, true)
    GameTooltip:AddLine(" ")
    local price, source, stamp = BT.Price(key)
    if price then
        GameTooltip:AddDoubleLine("Preis je Stück", BT.Money(price), 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine("Quelle", source .. (stamp and (", " .. Ago(stamp)) or ""), 1, 0.82, 0, 0.7, 0.7, 0.7)
        if res.missing > 0 then
            GameTooltip:AddDoubleLine("Kaufkosten", BT.Money(price * res.missing), 1, 0.82, 0, 1, 1, 1)
        end
        if BT.RECIPES[key] then GameTooltip:AddLine("Fertig kaufen, zählt nicht zur Summe", 0.7, 0.7, 0.7) end
    else
        GameTooltip:AddLine("Noch kein Preis: im Auktionshaus scannen", 0.7, 0.7, 0.7)
    end
    local recipe = BT.RECIPES[key]
    if recipe then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Noch " .. BT.Format(res.crafts) .. "× herstellen (ergibt je " .. recipe.makes .. "):", 1, 0.82, 0)
        for reagent, amount in pairs(recipe.reag) do
            GameTooltip:AddLine("  " .. amount .. "× " .. BT.ITEMS[reagent].de, 1, 1, 1)
        end
    end
    AddSourceLines(key)
    local owners = {}
    for id, count in pairs(BT.byChar[key] or {}) do owners[#owners + 1] = { id = id, count = count } end
    if #owners > 0 then
        table.sort(owners, function(a, b) return a.count > b.count end)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Verteilung:", 1, 0.82, 0)
        for _, owner in ipairs(owners) do
            GameTooltip:AddDoubleLine(owner.id, BT.Format(owner.count), 1, 1, 1, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function StepTooltip(row)
    local step, prof = row.entry.step, row.entry.prof
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(step.n, 1, 1, 1)
    GameTooltip:AddLine(({ R = "Benötigt ein Rezept-Item", T = "Beim Lehrer", A = "Automatisch gelernt" })[step.src] or " ", 0.7, 0.7, 0.7)
    if step.src == "R" then
        local state, who = BT.RecipeStatus(step)
        GameTooltip:AddLine(" ")
        if step.rc then GameTooltip:AddLine(step.rc.de, 1, 0.82, 0) end
        if state == "known" then
            GameTooltip:AddLine("Gelernt: " .. who, 0.2, 0.8, 0.2)
        elseif state == "owned" then
            GameTooltip:AddLine("Rezept-Item bei: " .. who, 1, 0.8, 0.2)
        else
            GameTooltip:AddLine("Noch nicht gesammelt", 1, 0.4, 0.4)
            GameTooltip:AddLine((step.rc and step.rc.where) or "Fundort unbekannt", 1, 1, 1, true)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(step.lump and "Menge für diesen Bereich:" or "Je Herstellung:", 1, 0.82, 0)
    for _, reagent in ipairs(step.r) do
        GameTooltip:AddLine("  " .. reagent[2] .. "× " .. BT.ITEMS[reagent[1]].de, 1, 1, 1)
    end
    if not step.lump then
        GameTooltip:AddDoubleLine("Noch offen", BT.Format(BT.StepRemaining(step, prof)) .. " von " .. step.c, 1, 0.82, 0, 1, 1, 1)
    end
    GameTooltip:Show()
end

local function NpcLine(entry)
    local place = BT.NpcPlace(entry)
    local npc = entry.npc
    local coords = npc.x and (" " .. string.format("%.1f, %.1f", npc.x, npc.y)) or ""
    local distance = entry.distance and (BT.Format(entry.distance) .. " m") or (entry.located and npc.m and "anderer Kontinent") or nil
    return (npc.de or npc.n), place .. coords, distance
end

local function ZoneName(mapID)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and info.name or ("Karte " .. mapID)
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
    GameTooltip:AddLine("Bezug:", 1, 0.82, 0)
    if source.h then GameTooltip:AddLine(source.h, 1, 1, 1, true) end
    for _, node in ipairs(source.o or {}) do
        local zones = {}
        for index, mapID in ipairs(node.z) do zones[index] = ZoneName(mapID) end
        GameTooltip:AddLine(node.n .. ": " .. table.concat(zones, ", "), 0.8, 0.8, 0.8, true)
    end
    local drops = source.d
    if drops and drops.n then
        GameTooltip:AddLine("Beute von: " .. table.concat(drops.n, ", "), 0.8, 0.8, 0.8, true)
    elseif drops then
        GameTooltip:AddLine("Beute von " .. drops.c .. " Gegnern, meiste in:", 0.8, 0.8, 0.8)
        for _, zone in ipairs(drops.z) do
            local level = zone.lo and (" (Stufe " .. zone.lo .. (zone.hi and zone.hi ~= zone.lo and ("–" .. zone.hi) or "") .. ")") or ""
            GameTooltip:AddLine("   " .. ZoneName(zone.m) .. level, 0.8, 0.8, 0.8)
        end
    end
    local vendors = ItemVendors(key)
    if #vendors > 0 then
        GameTooltip:AddLine("Händler" .. (#vendors > 3 and (" (die nächsten 3 von " .. #vendors .. ")") or "") .. ":", 0.8, 0.8, 0.8)
        for index = 1, math.min(#vendors, 3) do
            local name, place, distance = NpcLine(vendors[index])
            GameTooltip:AddDoubleLine("   " .. name, distance or "", 1, 1, 1, 0.7, 0.7, 0.7)
            GameTooltip:AddLine("      " .. place, 0.7, 0.7, 0.7)
        end
        GameTooltip:AddLine("Strg+Linksklick: Wegpunkt zum nächsten Händler", 0.4, 0.8, 1)
    end
    if not source.h and not source.o and not drops and #vendors == 0 then
        GameTooltip:AddLine("Keine Bezugsquelle bekannt", 0.7, 0.7, 0.7)
    end
end

local function TrainerTooltip(row)
    local rank, list = row.entry.rank, row.entry.nearest
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(BT.RankLabel(rank), 1, 1, 1)
    GameTooltip:AddLine(rank.skill > 0 and ("Ab Skill " .. rank.skill .. " und Charakterstufe " .. rank.level) or "Ohne Voraussetzung", 0.7, 0.7, 0.7)
    if rank.how then GameTooltip:AddLine(rank.how, 1, 0.82, 0) end
    GameTooltip:AddLine(" ")
    if #list == 0 then GameTooltip:AddLine("Kein Lehrer für deine Fraktion bekannt", 1, 0.4, 0.4) end
    for index = 1, math.min(#list, 8) do
        local name, place, distance = NpcLine(list[index])
        GameTooltip:AddDoubleLine(name, distance or "", 1, 1, 1, 0.7, 0.7, 0.7)
        GameTooltip:AddLine("   " .. place, 0.7, 0.7, 0.7)
    end
    if list[1] then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Strg+Linksklick: Wegpunkt zu " .. (list[1].npc.de or list[1].npc.n), 0.4, 0.8, 1)
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
    row.guideButton:SetSize(116, 18)
    row.guideButton:SetPoint("RIGHT", -144, 0)
    row.guideButton:SetScript("OnClick", function(self) row.entry.onGuide(self) end)
    AddDropArrow(row.guideButton)
    row.guideButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Guide wechseln", 1, 1, 1)
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
            if vendor then BT.SetWaypoint(vendor, "Händler für " .. BT.ITEMS[self.entry.key].de) end
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
    local rightInset = isItem and -280 or ((entry.kind == "step" or entry.kind == "trainer") and -60) or (entry.kind == "info" and -6) or (entry.kind == "prof" and -266) or -190

    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", (isItem and 28) or ((entry.onToggle or entry.kind == "info") and 26) or ((entry.kind == "step" or entry.kind == "trainer") and 18) or 6, 0)
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
        actionText = anyOpen and "Alle einklappen" or "Alle ausklappen" }
end

local function MatchesSearch(item, search)
    return search == "" or item.de:lower():find(search, 1, true) or item.en:lower():find(search, 1, true)
end

local function AddItems(list, category, title, onlyMissing, search)
    local keys = {}
    for key, item in pairs(BT.ITEMS) do
        local res = BT.result[key]
        if item.cat == category and res.need > 0 and (not onlyMissing or res.missing > 0) and MatchesSearch(item, search) then
            keys[#keys + 1] = key
        end
    end
    if #keys == 0 then return end
    local collapsed = BT.db.opt.matCollapsed
    local open = search ~= "" or not collapsed[title]
    table.sort(keys, function(a, b) return BT.Before(BT.ITEMS[a].de, BT.ITEMS[b].de) end)
    local openItems = 0
    for _, key in ipairs(keys) do
        if BT.result[key].missing > 0 then openItems = openItems + 1 end
    end
    list[#list + 1] = {
        kind = "head",
        text = (open and "|cff999999[-]|r " or "|cff999999[+]|r ") .. title,
        right = openItems > 0 and (openItems .. " offen") or "|cff33cc33fertig|r",
        onClick = function() collapsed[title] = (not collapsed[title]) or nil end,
    }
    if not open then return end
    for _, key in ipairs(keys) do
        local res = BT.result[key]
        local right
        if res.missing == 0 then
            right = "|cff33cc33fertig|r"
        elseif BT.RECIPES[key] then
            right = "|cffffcc33" .. BT.Format(res.crafts) .. "× bauen|r"
        else
            right = "|cffff6666-" .. BT.Format(res.missing) .. "|r"
        end
        list[#list + 1] = { kind = "item", key = key, text = BT.ITEMS[key].de, right = right }
    end
end

local function BuildMaterials(list)
    local search = (window.search:GetText() or ""):lower()
    local onlyMissing = BT.db.opt.onlyMissing
    AddCollapseAll(list)
    -- Kategorien alphabetisch, die Zwischenprodukte reihen sich mit ein
    local categories = { { index = 0, title = INTERMEDIATES } }
    for index, title in ipairs(BT.CATS) do categories[#categories + 1] = { index = index, title = title } end
    table.sort(categories, function(a, b) return BT.Before(a.title, b.title) end)
    for _, category in ipairs(categories) do AddItems(list, category.index, category.title, onlyMissing, search) end
end

local function RecipeTag(step)
    if step.src ~= "R" then return "" end
    local state, who = BT.RecipeStatus(step)
    if state == "known" then return "  |cff33cc33[gelernt]|r" end
    if state == "owned" then return "  |cffffcc33[im Besitz: " .. who .. "]|r" end
    return "  |cffff6666[Rezept fehlt]|r"
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

local function TrainerEntry(prof, rank)
    local nearest = BT.NearestNpcs(rank)
    local learned = BT.RankLearned(prof.key, rank)
    local head = "> " .. BT.RankLabel(rank)
    local how = rank.how and (rank.how .. ": ") or ""
    local text
    if learned then
        -- abgeschlossen: Lehrer trotzdem nennen, die ganze Zeile grau
        local target = "kein Lehrer für deine Fraktion"
        if nearest[1] then
            local name, place, distance = NpcLine(nearest[1])
            target = name .. ", " .. place .. (distance and (" (" .. distance .. ")") or "")
        end
        text = "|cff777777" .. head .. "  " .. how .. target .. "|r"
    else
        local target = "|cffff6666kein Lehrer für deine Fraktion|r"
        if nearest[1] then
            local name, place, distance = NpcLine(nearest[1])
            target = "|cffffffff" .. name .. "|r, " .. place .. (distance and (" |cff999999(" .. distance .. ")|r") or "")
        end
        text = "|cff66ccff" .. head .. "|r  " .. how .. target
    end
    local right = learned and "|cff33cc33gelernt|r"
        or (BT.RankDue(prof.key, rank) and "|cffffcc33fällig|r") or ("ab " .. rank.skill)
    local note = prof.title .. ": " .. BT.RankLabel(rank) .. " " .. (rank.how and ("- " .. rank.how) or "lernen")
    return { kind = "trainer", rank = rank, nearest = nearest, text = text, right = right, learned = learned, note = note }
end

local function AddProfession(list, prof, onlyMissing)
    local skill, who = BT.Skill(prof.key)
    local off = BT.db.opt.off[prof.key]
    local key = prof.key
    local open = IsExpanded(key)
    local total, found = RecipeCounts(prof)
    local guide = BT.ActiveGuide(prof)
    local guides = BT.GuideList(prof)
    local right = off and "|cff999999aus|r" or (guide.lump and "Einkaufsliste" or (BT.Format(prof.remaining) .. " offen"))
    if not off and total > 0 then right = right .. "  |cffffcc33Rezepte " .. found .. "/" .. total .. "|r" end
    list[#list + 1] = {
        kind = "prof",
        text = (open and "|cff999999[-]|r " or "|cff999999[+]|r ") .. "|cffffd100" .. prof.title .. "|r  Skill " .. skill .. "/300" .. (who == "manuell" and "  |cff999999(manuell)|r" or ""),
        right = right,
        checked = not off,
        onToggle = function(on) BT.db.opt.off[key] = (not on) or nil end,
        onClick = function() expanded[key] = not open end,
        guideTitle = #guides > 1 and guide.title or nil,
        guideUrl = guide.url,
        onGuide = function(button) OpenGuideMenu(button, prof) end,
    }
    local learned = {}
    for _, entry in ipairs(BT.ProfChars(key)) do
        local label = entry.id:match("^%S+") .. " (" .. entry.rank .. ")"
        learned[#learned + 1] = entry.id == BT.me and ("|cffffd100" .. label .. "|r") or label
    end
    if #learned > 0 then
        list[#list + 1] = { kind = "info", height = 16, text = "|cff999999Gelernt:|r " .. table.concat(learned, ", ") }
    end
    if not open or off then return end
 local activeSteps = guide.steps
    if guide.lump then
        list[#list + 1] = { kind = "info", height = 16, text = "|cff999999Nur Einkaufsliste, keine einzelnen Rezepte|r" }
    end
    if not prof.gather and activeSteps[#activeSteps].t < 300 then
        list[#list + 1] = { kind = "info", height = 16, text = "|cffff9933Guide endet bei Skill " .. activeSteps[#activeSteps].t .. "|r" }
    end
    if prof.gather then
        list[#list + 1] = { kind = "info", height = 16, text = "|cff999999Ab Skill " .. prof.steps[#prof.steps].t .. " nur noch durchs Sammeln, ohne Materialbedarf|r" }
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
            local entry = TrainerEntry(prof, ranks[nextRank])
            if not onlyMissing or not entry.learned or nextRank == currentRank then list[#list + 1] = entry end
            nextRank = nextRank + 1
        end
    end
    for _, step in ipairs(activeSteps) do
        AddRanksBefore(step.t)
        local remaining = BT.StepRemaining(step, prof.key)
        if not onlyMissing or remaining > 0 then
            local range = step.f .. "-" .. step.t .. "  " .. step.n
            local text = remaining == 0 and ("|cff777777" .. range .. "|r") or (range .. RecipeTag(step))
            list[#list + 1] = { kind = "step", prof = prof.key, step = step, text = text,
                right = remaining == 0 and "|cff33cc33fertig|r" or (step.lump and "offen" or (remaining .. "×")) }
        end
    end
    AddRanksBefore(nil)
end

local function AddGroup(list, profs, onlyMissing)
    for index, prof in ipairs(profs) do
        if index > 1 then list[#list + 1] = { kind = "gap", height = 10 } end
        AddProfession(list, prof, onlyMissing)
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
        text = (anyOpen and "|cff999999[-]|r " or "|cff999999[+]|r ") .. title,
        onClick = function()
            for _, prof in ipairs(profs) do expanded[prof.key] = not anyOpen end
        end,
    }
end

local function BuildRoute(list)
    local onlyMissing = BT.db.opt.onlyMissing
    AddCollapseAll(list)
    local current, others, gathering = {}, {}, {}
    for _, prof in ipairs(BT.PROFS) do
        local group = (prof.gather and gathering) or (BT.IsCurrentProf(prof.key) and current) or others
        group[#group + 1] = prof
    end
    if #current > 0 then
        list[#list + 1] = SectionHead("Dieser Charakter", current)
        AddGroup(list, current, onlyMissing)
        list[#list + 1] = { kind = "gap", height = 12 }
        list[#list + 1] = { kind = "divider", height = 6 }
        list[#list + 1] = { kind = "gap", height = 12 }
    end
    list[#list + 1] = SectionHead("Weitere Berufe", others)
    AddGroup(list, others, onlyMissing)
    list[#list + 1] = { kind = "gap", height = 12 }
    list[#list + 1] = { kind = "divider", height = 6 }
    list[#list + 1] = { kind = "gap", height = 12 }
    list[#list + 1] = SectionHead("Sammelberufe", gathering)
    AddGroup(list, gathering, onlyMissing)
end

local function SectionState(id, section)
    local _, source, ts = BT.Source(id, section)
    if source == "own" then return "|cff33cc33" .. Ago(ts) .. "|r" end
    if source == "bagnon" then return "|cffcccc66Bagnon|r" end
    return "|cff999999-|r"
end

local function BuildChars(list)
    list[#list + 1] = { kind = "head", text = "Name  (Taschen / Bank / Post)" }
    for _, id in ipairs(BT.CharIds()) do
        local own, imported = BT.db.chars[id], BT.imported[id]
        local class = (own and own.class) or (imported and imported.class)
        local ignored = BT.IsIgnored(id)
        list[#list + 1] = {
            kind = "char",
            text = ColorName(id, class) .. (id == BT.me and "  |cffffd100(aktiv)|r" or "") .. (BT.IsGuild(id) and "  |cff999999(Gildenbank)|r" or ""),
            right = SectionState(id, "bags") .. " / " .. SectionState(id, "bank") .. " / " .. SectionState(id, "mail"),
            checked = not ignored,
            onToggle = function(on) BT.db.opt.ignored[id] = not on end,
        }
    end
end

local function FilterLabel()
    local filter = BT.db.opt.matFilter
    if filter == "learned" then return "Gelernte Berufe" end
    if filter == "once" then return "Jeder Beruf einmal" end
    return filter or "Alle Berufe"
end

local function OpenFilterMenu(button)
    local options = {
        { text = "Alle Berufe  |cff999999jeder Charakter mit seinen Berufen|r" },
        { text = "Gelernte Berufe  |cff999999jeder einmal, bester Charakter|r", value = "learned" },
        { text = "Jeder Beruf einmal  |cff999999auch ungelernte, bester Charakter|r", value = "once" },
    }
    for _, id in ipairs(BT.FilterChars()) do
        local names = {}
        for _, prof in ipairs(BT.PROFS) do
            if BT.db.chars[id].skills[prof.key] then names[#names + 1] = prof.title end
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

    local need, have = BT.needTotal or 0, BT.haveTotal or 0
    local percent = need > 0 and math.floor(have / need * 100) or 100
    window.summary:SetText("Grundmaterialien: " .. BT.Format(have) .. " / " .. BT.Format(need) .. "  (" .. percent .. " %)")
    window.search:SetShown(tab == MATERIALS)
    window.searchLabel:SetShown(tab == MATERIALS)
    window.filter:SetShown(tab == MATERIALS)
    window.filter:SetText(FilterLabel())
    window.guideAll:SetShown(tab == ROUTE)
    window.guideAll:SetText(next(BT.db.opt.guide) and "Guide für alle: gemischt" or ("Guide für alle: " .. BT.GlobalGuideTitle()))
    window.scan:SetShown(tab == MATERIALS)
    window.scan:SetEnabled(BT.atAH or BT.scanText ~= nil)
    window.scan:SetText(BT.scanText or "Preise scannen")
    window.cost:SetShown(tab == MATERIALS)
    window.cost:SetText("Kaufkosten: |cffffd100" .. BT.Money(BT.cost or 0) .. "|r" .. ((BT.unpriced or 0) > 0 and ("  |cff999999(" .. BT.unpriced .. " ohne Preis)|r") or ""))
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
    f:SetScript("OnShow", function() BT.Update() end)
    f:SetScript("OnHide", function() f.filterMenu:Hide() end)
    tinsert(UISpecialFrames, "BerufeTrackerFrame")
    local title = f.TitleText or (f.TitleContainer and f.TitleContainer.TitleText)
    if title then title:SetText("BerufeTracker") end

    f.tabs = {}
    local labels = { [MATERIALS] = "Materialien", [ROUTE] = "Route", [CHARS] = "Charaktere" }
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
    f.summary:SetPoint("TOPRIGHT", -16, -32)

    f.searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.searchLabel:SetPoint("TOPLEFT", 16, -85)
    f.searchLabel:SetText("Suche:")
    f.search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.search:SetSize(120, 20)
    f.search:SetPoint("LEFT", f.searchLabel, "RIGHT", 10, 0)
    f.search:SetAutoFocus(false)
    f.search:SetScript("OnTextChanged", function() BT.RefreshUI() end)
    f.search:SetScript("OnEscapePressed", f.search.ClearFocus)

    f.filter = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.filter:SetSize(170, 22)
    f.filter:SetPoint("TOPLEFT", 16, -55)
    f.filter:SetScript("OnClick", OpenFilterMenu)
    AddDropArrow(f.filter)

    f.guideAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.guideAll:SetSize(230, 22)
    f.guideAll:SetPoint("TOPLEFT", 16, -55)
    f.guideAll:SetScript("OnClick", OpenAllGuidesMenu)
    AddDropArrow(f.guideAll)

    f.scan = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.scan:SetSize(116, 22)
    f.scan:SetPoint("TOPLEFT", 194, -55)
    f.scan:SetScript("OnClick", function() BT.StartScan() end)

    f.cost = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.cost:SetPoint("TOPRIGHT", -14, -60)

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
    label:SetText("Nur Offenes")

    f.noGather = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.noGather:SetSize(22, 22)
    f.noGather:SetPoint("TOPLEFT", 300, -80)
    f.noGather:SetScript("OnClick", function(self)
        BT.db.opt.noGather = self:GetChecked() or nil
        BT.Update()
    end)
    local noGatherLabel = f.noGather:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noGatherLabel:SetPoint("LEFT", f.noGather, "RIGHT", 2, 0)
    noGatherLabel:SetText("Sammelberufe ausschließen")

    f.scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", 12, -106)
    f.scroll:SetPoint("BOTTOMRIGHT", -34, 12)
    f.content = CreateFrame("Frame", nil, f.scroll)
    f.content:SetSize(WIDTH - 46, 1)
    f.scroll:SetScrollChild(f.content)
    f.scroll:HookScript("OnVerticalScroll", function() f.filterMenu:Hide() end)

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
        GameTooltip:AddLine("Klicken: Fenster öffnen", 1, 1, 1)
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
            print("|cffffcc00BerufeTracker:|r Im Kampf lässt sich die Karte nicht öffnen.")
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
        GameTooltip:AddLine("Klicken: Karte beim Ziel öffnen", 1, 1, 1)
        GameTooltip:AddLine("Ziehen: Leiste verschieben", 0.7, 0.7, 0.7)
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
                local list = itemsByNode[node.n] or {}
                itemsByNode[node.n] = list
                list[#list + 1] = { key = key, rank = index }
            end
        end
        for _, list in pairs(itemsByNode) do
            table.sort(list, function(a, b)
                if a.rank ~= b.rank then return a.rank < b.rank end
                return BT.ITEMS[a.key].de < BT.ITEMS[b.key].de
            end)
        end
    end
    return itemsByNode[name]
end

local function TrackerHeader(tip)
    tip:AddLine(" ")
    tip:AddLine("BerufeTracker |cff999999(" .. FilterLabel() .. (BT.db.opt.noGather and ", ohne Sammelberufe" or "") .. ")|r", 1, 0.82, 0)
end

-- Bedarf eines Materials nach den aktuellen Filtern; allProfs = alle Berufe statt der größten vier.
AddNeedLines = function(tip, key, allProfs)
    local res = BT.result and BT.result[key]
    if not res then return end
    TrackerHeader(tip)
    if res.need == 0 then
        tip:AddLine("Wird nicht mehr gebraucht", 0.6, 0.6, 0.6)
        return
    end
    tip:AddDoubleLine("Benötigt", BT.Format(res.need), 1, 1, 1, 1, 1, 1)
    tip:AddDoubleLine("Im Besitz", BT.Format(res.have), 1, 1, 1, 1, 1, 1)
    if res.missing > 0 then
        tip:AddDoubleLine("Fehlt noch", BT.Format(res.missing), 1, 1, 1, 1, 0.4, 0.4)
    else
        tip:AddLine("Genug vorhanden", 0.2, 0.8, 0.2)
    end
    local shown = 0
    for _, part in ipairs(ProfessionShares(res)) do
        if part.amount > 0 and (allProfs or shown < 4) then
            shown = shown + 1
            tip:AddDoubleLine("   " .. BT.PROF_BY_KEY[part.key].title, BT.Format(part.amount), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
        end
    end
end

-- Zusatzzeilen in Item-Tooltips (Taschen, Bank, Auktionshaus, Beute, Links)
-- und im Tooltip von Erzadern und Kräutern in der Welt.
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
        if key then AddNeedLines(tip, key) end
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItem)
    else
        for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
            if tip then tip:HookScript("OnTooltipSetItem", function(self) OnItem(self) end) end
        end
    end

    local nodeDone = false
    GameTooltip:HookScript("OnTooltipCleared", function() nodeDone = false end)
    GameTooltip:HookScript("OnShow", function(tip)
        if nodeDone or not BT.result then return end
        if tip.GetItem and tip:GetItem() then return end
        if tip.GetUnit and tip:GetUnit() then return end
        local owner = tip.GetOwner and tip:GetOwner()
        if owner and window and owner.GetParent and owner:GetParent() == window.content then return end -- eigenes Fenster
        local line = _G.GameTooltipTextLeft1
        local text = line and Plain(line:GetText())
        local list = text and ItemsOfNode(text)
        if not list then return end
        nodeDone = true
        local any = false
        for _, entry in ipairs(list) do
            local res = BT.result[entry.key]
            if res and res.need > 0 then
                if not any then TrackerHeader(tip) any = true end
                local state = res.missing > 0 and ("|cffff6666fehlt " .. BT.Format(res.missing) .. "|r") or "|cff33cc33genug|r"
                tip:AddDoubleLine(BT.ITEMS[entry.key].de, state .. " |cff999999(" .. BT.Format(res.have) .. "/" .. BT.Format(res.need) .. ")|r", 1, 1, 1, 1, 1, 1)
            end
        end
        if not any then
            TrackerHeader(tip)
            tip:AddLine("Wird nicht mehr gebraucht", 0.6, 0.6, 0.6)
        end
        tip:Show()
    end)
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

function BT.PrintChatDebug()
    local wp = BT.ActiveWaypoint()
    local tag = "|cffffcc00BerufeTracker:|r "
    print(tag .. "Chatzeilen: " .. chatInfo.boxes .. ", Wegpunkt: " .. (wp and (wp.name .. " " .. wp.m .. " " .. wp.x .. " " .. wp.y) or "keiner"))
    local ok, link = pcall(C_Map.GetUserWaypointHyperlink or function() end)
    print(tag .. "Spiel-Link: " .. tostring(ok and link or "-"):gsub("|", "||"))
    print(tag .. "Zuletzt: " .. tostring(chatInfo.result or "noch kein Karten-Link gesehen") .. " (" .. tostring(chatInfo.source or "-") .. ")")
    print(tag .. "Text: " .. tostring(chatInfo.text or "-"):gsub("|", "||"))
end

function BT.InitUI()
    CreateWindow()
    CreateMinimapButton()
    CreateWaypointLabel()
    HookWaypointTooltip()
    HookItemTooltips()
    HookChatBoxes()
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

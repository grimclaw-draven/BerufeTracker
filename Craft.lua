-- BerufeTracker - Herstellen per Klick
--
-- Klick auf einen Routen-Schritt oder ein herstellbares Material:
--   * Rezept gelernt (eingeloggter Charakter): Berufsfenster öffnen, Rezept auswählen, Menge eintragen (höchstens so
--     viele, wie gerade herstellbar sind; mindestens 1)
--   * Rezept fehlt: Wegpunkt zum nächsten Händler des Rezept-Items (BT.RECIPE_VENDORS aus RecipeVendors.lua) bzw. zum
--     Lehrer des passenden Rangs; jeder weitere Klick zum nächsten
-- Alles abgesichert: Das Berufsfenster gehört zu einem bei Bedarf geladenen Blizzard-Addon und unterscheidet sich je
-- Spielversion; was fehlt, wird übersprungen.
local _, BT = ...
local L = BT.L

local function Plain(v)
    if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
    return v
end

local SKILL_LINE = {}
for id, key in pairs(BT.SKILL_LINES or {}) do SKILL_LINE[key] = id end

-- Vorlage (BT.RECIPE_TEMPLATES) zu einem Routen-Schritt oder einem Material finden
local function TemplateFor(profKey, step, itemKey)
    local itemID = itemKey and BT.ITEMS[itemKey] and BT.ITEMS[itemKey].id
    local stepItem
    for _, alias in ipairs(step and step.aliases or {}) do
        local id = type(alias) == "string" and tonumber(alias:match("^#(%d+)$"))
        if id then stepItem = id end
    end
    local function Search(prof)
        for _, tpl in ipairs((BT.RECIPE_TEMPLATES or {})[prof] or {}) do
            if step and (tpl.en == step.en or (stepItem and tpl.item == stepItem)) then return tpl end
            if itemID and tpl.item == itemID then return tpl end
        end
    end
    if profKey then
        local tpl = Search(profKey)
        if tpl then return tpl, profKey end
        return nil
    end
    for prof in pairs(BT.RECIPE_TEMPLATES or {}) do
        local tpl = Search(prof)
        if tpl then return tpl, prof end
    end
end
BT.CraftTemplateFor = TemplateFor

local function KnownByMe(tpl)
    local rec = BT.me and BT.db.chars[BT.me]
    local known = rec and rec.known
    if not known then return false end
    for _, alias in ipairs(tpl.aliases or {}) do
        if known[alias] then return true end
    end
    return false
end

-- Berufsfenster: Rezept auswählen und Menge eintragen. Ein frisch geöffnetes Fenster baut seine Rezeptliste erst
-- danach fertig auf und setzt die Auswahl dabei zurück (im Spiel: erst der zweite Klick wählte aus). Deshalb wird
-- nachgewählt, bis die Auswahl mehrmals hintereinander stimmt (oder ohne Prüfmöglichkeit 1,5 s lang).
local pending, ticker

-- welches Rezept ist im Berufsfenster gerade ausgewählt? (nil, wenn das Fenster es nicht verrät)
local function SelectedRecipeID(page)
    local form = type(page.SchematicForm) == "table" and page.SchematicForm
    if form and type(form.GetRecipeInfo) == "function" then
        local ok, info = pcall(form.GetRecipeInfo, form)
        if ok and type(info) == "table" and info.recipeID then return Plain(info.recipeID) end
    end
    local list = type(page.RecipeList) == "table" and page.RecipeList
    local behavior = list and type(list.selectionBehavior) == "table" and list.selectionBehavior
    if behavior and type(behavior.GetFirstSelectedElementData) == "function" then
        local ok, node = pcall(behavior.GetFirstSelectedElementData, behavior)
        if ok and type(node) == "table" and type(node.GetData) == "function" then
            local ok2, data = pcall(node.GetData, node)
            local info = ok2 and type(data) == "table" and data.recipeInfo
            if type(info) == "table" and info.recipeID then return Plain(info.recipeID) end
        end
    end
    return nil
end

local function SetAmount(page, info)
    local count = pending.count or 1
    local available = tonumber(Plain(info.numAvailable))
    if available and available < count then count = math.max(1, available) end
    local box = type(page.CreateMultipleInputBox) == "table" and page.CreateMultipleInputBox
    if box and type(box.SetValue) == "function" then pcall(box.SetValue, box, count) end
    return count
end

local function TrySelect()
    if not pending then return true end
    local now = GetTime and GetTime() or 0
    if now > pending.untilT then pending = nil return true end
    local frame = _G.ProfessionsFrame
    if type(frame) ~= "table" or not (frame.IsShown and frame:IsShown()) then return false end
    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo) then pending = nil return true end
    local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, pending.spell)
    if not ok or type(info) ~= "table" then return false end
    local page = type(frame.CraftingPage) == "table" and frame.CraftingPage
    if not page then return false end
    local current = SelectedRecipeID(page)
    if current ~= nil and current == pending.spell then
        -- Auswahl stimmt: Menge eintragen; fertig, wenn sie mehrmals hintereinander stimmt
        local count = SetAmount(page, info)
        pending.stable = (pending.stable or 0) + 1
        if pending.stable >= 3 then
            BT.craftDebug = { spell = pending.spell, count = count, verified = true }
            pending = nil
            return true
        end
        return false
    end
    pending.stable = 0
    local list = type(page.RecipeList) == "table" and page.RecipeList
    local selected = false
    if list and type(list.SelectRecipe) == "function" then selected = pcall(list.SelectRecipe, list, info, true) end
    if not selected and type(page.SelectRecipe) == "function" then selected = pcall(page.SelectRecipe, page, info) end
    if not selected then return false end
    local count = SetAmount(page, info)
    pending.firstAt = pending.firstAt or now
    -- verrät das Fenster die Auswahl nicht, einfach 1,5 s lang nachwählen
    if current == nil and now - pending.firstAt >= 1.5 then
        BT.craftDebug = { spell = pending.spell, count = count, verified = false }
        pending = nil
        return true
    end
    return false
end

BT.CraftTick = function() return TrySelect() end -- für Tests

local function OpenProfession(profKey)
    local line = SKILL_LINE[profKey]
    if not line then return end
    local current
    if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
        local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
        current = ok and type(info) == "table" and Plain(info.professionID)
    end
    local frame = _G.ProfessionsFrame
    local shown = type(frame) == "table" and frame.IsShown and frame:IsShown()
    if shown and current == line then return end
    if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then pcall(C_TradeSkillUI.OpenTradeSkill, line) end
end

function BT.OpenCraft(profKey, spell, count)
    if InCombatLockdown and InCombatLockdown() then
        print("|cffffcc00BerufeTracker:|r " .. L["Im Kampf lässt sich das Berufsfenster nicht öffnen."])
        return false
    end
    pending = { spell = spell, count = math.max(1, math.floor(count or 1)), untilT = (GetTime and GetTime() or 0) + 6 }
    OpenProfession(profKey)
    if TrySelect() then return true end
    if ticker then ticker:Cancel() end
    if C_Timer and C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(0.2, function(self)
            if TrySelect() then self:Cancel() ticker = nil end
        end, 30)
    end
    return true
end

-- Rang, dessen Lehrer ein Rezept ab Skill `skill` beibringt
local function RankFor(profKey, skill)
    local ranks = BT.TRAINERS and BT.TRAINERS[profKey]
    if not ranks then return nil end
    for _, rank in ipairs(ranks) do
        if (skill or 1) < rank.cap and not rank.how then return rank end
    end
    return ranks[1]
end

-- Chance auf einen Skillpunkt beim Herstellen (Classic): unter Lernbar nicht möglich (nil), bis gelb sicher,
-- von gelb bis grau fallend (grau - Skill) / (grau - gelb), ab grau 0. Felder der Vorlage: l lernbar, y gelb, g grau.
function BT.CraftChance(tpl, skill)
    if not (tpl and tpl.y and tpl.g and skill) then return nil end
    if tpl.l and skill < tpl.l then return nil end
    if skill < tpl.y then return 1 end
    if skill >= tpl.g then return 0 end
    return (tpl.g - skill) / (tpl.g - tpl.y)
end

-- Zeile für Tooltips: "Schneiderei (91): jetzt ca. 67 % Chance auf einen Skillpunkt" in Skill-Farbe
function BT.CraftChanceLine(tip, tpl, prof)
    local rec = BT.me and BT.db.chars[BT.me]
    local skill = rec and rec.skills and rec.skills[prof]
    if not (tpl and skill and skill > 0 and tpl.y and tpl.g) then return false end
    local title = BT.ProfTitle(BT.PROF_BY_KEY[prof]) .. " (" .. skill .. ")"
    local chance = BT.CraftChance(tpl, skill)
    if chance == nil then
        tip:AddLine(L["%s: herstellbar ab Skill %d"]:format(title, tpl.l or 1), 1, 0.25, 0.25)
    elseif chance <= 0 then
        tip:AddLine(L["%s: grau, keine Skillpunkte mehr"]:format(title), 0.5, 0.5, 0.5)
    else
        local green = math.floor((tpl.y + tpl.g) / 2)
        local r, gcol, b = 1, 0.5, 0.25 -- orange
        if skill >= green then r, gcol, b = 0.25, 0.75, 0.25 elseif skill >= tpl.y then r, gcol, b = 1, 1, 0 end
        tip:AddLine(title .. ": " .. L["jetzt ca. %d %% Chance auf einen Skillpunkt"]:format(math.floor(chance * 100 + 0.5)), r, gcol, b)
    end
    return true
end

-- Hauptfunktion für Klicks: herstellen oder zum Rezept führen. Gibt true zurück, wenn etwas passiert ist.
function BT.CraftOrFindRecipe(profKey, step, itemKey, count)
    local tpl, prof = TemplateFor(profKey, step, itemKey)
    if not tpl then return false end
    local tag = "|cffffcc00BerufeTracker:|r "
    local rec = BT.me and BT.db.chars[BT.me]
    local hasProf = rec and rec.skills and (rec.skills[prof] or 0) > 0
    if KnownByMe(tpl) and hasProf then
        return BT.OpenCraft(prof, tpl.spell, count)
    end
    local name = BT.StepName and step and BT.StepName(step) or (BT.ItemName and itemKey and BT.ItemName(itemKey)) or tpl.en
    if not hasProf then
        print(tag .. L["Dieser Charakter hat %s nicht gelernt."]:format(BT.ProfTitle(BT.PROF_BY_KEY[prof])))
        return true
    end
    if tpl.rc then
        local vendors = BT.RECIPE_VENDORS and BT.RECIPE_VENDORS[tpl.rc.id]
        local list = vendors and BT.NearestNpcs({ npcs = vendors }) or {}
        if #list > 0 then
            BT.CycleWaypoint("recipe:" .. tpl.rc.id, list, L["Rezept kaufen: %s"]:format(name), L["Händler %d von %d"])
            return true
        end
        local where = step and step.rc and BT.RecipeWhere and BT.RecipeWhere(step.rc)
        print(tag .. L["Rezept fehlt: %s"]:format(name) .. (where and (" - " .. where) or (" - " .. L["kein Händler bekannt"])))
        return true
    end
    local rank = RankFor(prof, tpl.l)
    local list = rank and BT.NearestNpcs(rank) or {}
    if #list > 0 then
        BT.CycleWaypoint("trainer:" .. prof .. ":" .. rank.name, list, L["Rezept lernen: %s"]:format(name), L["Lehrer %d von %d"])
        return true
    end
    print(tag .. L["Rezept fehlt: %s"]:format(name))
    return true
end

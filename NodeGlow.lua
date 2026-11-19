-- BerufeTracker - Erze und Kräuter in der Nähe hervorheben
--
-- Eigene Umsetzung über das "Soft Targeting" des Spiels: Das Spiel wählt laufend das nächste Objekt in der
-- Nähe als Interaktionsziel (Einheit "softinteract") und kann ihm eine Namensplakette geben. Ist dieses Objekt
-- ein Kraut oder eine Erzader aus unseren Daten, hängt an der Plakette ein Leuchten:
--   * hell in der Farbe der Art (Kraut grün, Erz orange), wenn du das Material noch brauchst oder das Sammeln
--     dir noch Skillpunkte bringt,
--   * schwach und grau, wenn nicht (oder wenn dein Skill dafür noch nicht reicht).
--
-- Geänderte Spieleinstellungen werden vorher gesichert und beim Abschalten wiederhergestellt.
-- Kollisionsschutz: Läuft ein Addon, das dieselben Einstellungen ändert (PÄNIK Gildentools, ForeverLootSparkles,
-- Lueur), bleibt dieses Modul ganz aus und fasst nichts an. In Instanzen und im Kampf ist es ebenfalls aus.
local _, BT = ...

local CONFLICTS = { "PaenikGildentools", "ForeverLootSparkles", "Lueur" }
local CVARS = {
    SoftTargetInteract = "3",            -- Interaktionsziel immer wählen
    SoftTargetInteractRange = "40",      -- das Spiel begrenzt selbst auf die Sichtweite der Plaketten
    SoftTargetInteractArc = "2",         -- rundherum, nicht nur vorne
    SoftTargetInteractOnlyInRange = "0", -- auch Objekte außerhalb der Reichweite
}
local PLATE = "SoftTargetNameplateInteract" -- Plakette nur, solange ein Kraut/Erz anvisiert ist
local UNIT = "softinteract"
local STAR = "Interface\\Cooldown\\star4"
local COLORS = { herbalism = { 0.45, 1, 0.45 }, mining = { 1, 0.62, 0.25 } }

local function Plain(v)
    if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
    return v
end
local function Safe(fn, ...)
    if not fn then return nil end
    local ok, r = pcall(fn, ...)
    if ok then return Plain(r) end
end

local function GetCV(name)
    if C_CVar and C_CVar.GetCVar then return Safe(C_CVar.GetCVar, name) end
    return Safe(GetCVar, name)
end
local function SetCV(name, value)
    local current = GetCV(name)
    if current == nil or current == value then return end
    if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, name, value) elseif SetCVar then pcall(SetCVar, name, value) end
end

-- Läuft ein Addon, das dasselbe macht? Dann bleibt dieses Modul ganz aus.
function BT.NodeGlowConflict()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if not loaded then return nil end
    for _, name in ipairs(CONFLICTS) do
        local ok, yes = pcall(loaded, name)
        if ok and yes then return name end
    end
end

local function InInstance()
    if not IsInInstance then return false end
    local inside, kind = IsInInstance()
    return inside and kind ~= "none"
end
local function InCombat() return InCombatLockdown ~= nil and InCombatLockdown() end

local function Wanted()
    return BT.db and BT.db.opt.nodeGlow == true and not BT.NodeGlowConflict() and not InInstance()
end

-- Einstellungen sichern/setzen bzw. zurücknehmen (nur außerhalb des Kampfes möglich)
local function Apply()
    local saved = BT.db.opt.glowSaved or {}
    BT.db.opt.glowSaved = saved
    for name, value in pairs(CVARS) do
        if saved[name] == nil then saved[name] = GetCV(name) or false end
        SetCV(name, value)
    end
    if saved[PLATE] == nil then saved[PLATE] = GetCV(PLATE) or false end
end

local function Restore()
    local saved = BT.db and BT.db.opt.glowSaved
    if not saved then return end
    for name, value in pairs(saved) do
        if value ~= false then SetCV(name, value) end
    end
    BT.db.opt.glowSaved = nil
end

-- Leuchten: Schein und zwei gegenläufig drehende Sterne, pulsierend
local fx, anchor
local function CreateEffect()
    fx = CreateFrame("Frame")
    fx:SetSize(1, 1)
    fx:Hide()
    local function Layer(size, alpha)
        local t = fx:CreateTexture(nil, "OVERLAY")
        t:SetTexture(STAR)
        t:SetBlendMode("ADD")
        t:SetSize(size, size)
        t:SetPoint("CENTER")
        t.base = alpha
        return t
    end
    fx.glow, fx.outer, fx.inner = Layer(84, 0.35), Layer(50, 0.85), Layer(34, 0.75)
    fx.t = 0
    fx:SetScript("OnUpdate", function(self, elapsed)
        self.t = self.t + math.min(elapsed or 0, 0.1)
        local c, level = self.color, self.level or 1
        local pulse = 0.75 + 0.25 * math.sin(self.t * 3)
        self.glow:SetVertexColor(c[1], c[2], c[3], self.glow.base * level * pulse)
        self.outer:SetVertexColor(c[1], c[2], c[3], self.outer.base * level)
        self.outer:SetRotation(self.t * 0.8)
        self.inner:SetVertexColor(1, 1, 1, self.inner.base * level * pulse)
        self.inner:SetRotation(-self.t * 1.3)
    end)
end

local function HideEffect()
    if not anchor then return end
    fx:Hide()
    fx:ClearAllPoints()
    fx:SetParent(nil)
    anchor = nil
end

local function ShowEffect(plate, color, level)
    if not fx then CreateEffect() end
    if anchor ~= plate then
        fx:SetParent(plate)
        fx:ClearAllPoints()
        fx:SetPoint("CENTER", plate, "CENTER", 0, -42)
        if fx.SetIgnoreParentAlpha then fx:SetIgnoreParentAlpha(true) end
        anchor = plate
    end
    fx.color, fx.level = color, level
    fx:Show()
end

local plateOpen
local function SetPlate(open)
    if plateOpen == open or InCombat() then return end
    plateOpen = open
    SetCV(PLATE, open and "1" or "0")
end

-- Was ist das Objekt aus Sicht von BerufeTracker? Art (herbalism/mining) und ob es sich lohnt.
local function Judge(name)
    local list = BT.ItemsOfNode and BT.ItemsOfNode(name)
    if not list then return nil end
    local req, kind
    for _, entry in ipairs(list) do
        for profKey, map in pairs(BT.GATHER_REQ or {}) do
            if map[entry.key] and (not req or map[entry.key] > req) then req, kind = map[entry.key], profKey end
        end
    end
    if not kind then return nil end
    local useful = false
    for _, entry in ipairs(list) do
        local res = BT.result and BT.result[entry.key]
        if res and (res.missing or 0) > 0 then useful = true end
    end
    local rec = BT.db.chars[(BT.FocusChar and BT.FocusChar()) or BT.me]
    local skill = rec and rec.skills and rec.skills[kind]
    if skill and skill >= req and skill < req + 100 then useful = true end -- bringt noch Skillpunkte
    if skill and skill < req then useful = false end                     -- noch nicht sammelbar
    return kind, useful
end

BT.glowDebug = { checks = 0, shown = 0 }
local function Evaluate()
    if not Wanted() or InCombat() then HideEffect() return end
    BT.glowDebug.checks = BT.glowDebug.checks + 1
    if Safe(UnitIsGameObject, UNIT) ~= true then SetPlate(false) HideEffect() return end
    local name = Safe(UnitName, UNIT)
    local kind, useful
    if type(name) == "string" then kind, useful = Judge(name) end
    BT.glowDebug.last = name
    SetPlate(kind ~= nil)
    local plate = kind and C_NamePlate and Safe(C_NamePlate.GetNamePlateForUnit, UNIT)
    if not plate then HideEffect() return end
    ShowEffect(plate, useful and COLORS[kind] or { 0.6, 0.6, 0.6 }, useful and 1 or 0.35)
    BT.glowDebug.shown = BT.glowDebug.shown + 1
end

local ticker, pending
local function Update()
    if InCombat() then pending = true return end
    pending = false
    if Wanted() then
        Apply()
        plateOpen = nil
        if not ticker and C_Timer and C_Timer.NewTicker then ticker = C_Timer.NewTicker(0.15, Evaluate) end
    else
        if ticker then ticker:Cancel() ticker = nil end
        HideEffect()
        -- bei einem anderen Glitzer-Addon gar nichts anfassen (es verwaltet dieselben Einstellungen);
        -- sonst die eigenen gesicherten Werte zurückgeben
        if not BT.NodeGlowConflict() then Restore() end
        plateOpen = nil
    end
end
BT.UpdateNodeGlow = Update

function BT.SetNodeGlow(on)
    BT.db.opt.nodeGlow = on and true or nil
    Update()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "PLAYER_SOFT_INTERACT_CHANGED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if not BT.db then return end
    if event == "PLAYER_REGEN_DISABLED" then
        SetPlate(false)
        HideEffect()
    elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then
        if ticker then Evaluate() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        plateOpen = nil
        if pending then Update() end
    elseif event == "PLAYER_LOGIN" then
        -- Kontoeinstellungen können nach dem Login nachgeladen werden: kurz danach erneut setzen
        if C_Timer and C_Timer.After then
            C_Timer.After(2, Update)
            C_Timer.After(8, Update)
        end
    else
        Update()
    end
end)

-- Diagnose: /berufe glitzern debug
function BT.PrintNodeGlowDebug()
    local tag = "|cffffcc00BerufeTracker:|r "
    print(tag .. "Erze/Kräuter hervorheben: " .. tostring(BT.db.opt.nodeGlow == true) .. ", anderes Addon: "
        .. tostring(BT.NodeGlowConflict()) .. ", aktiv: " .. tostring(ticker ~= nil))
    print(tag .. "Prüfungen: " .. BT.glowDebug.checks .. ", Leuchten gezeigt: " .. BT.glowDebug.shown
        .. ", zuletzt: " .. tostring(BT.glowDebug.last))
end

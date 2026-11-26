-- BerufeTracker - Erze und Kräuter in der Nähe hervorheben
--
-- Eigene Umsetzung über das "Soft Targeting" des Spiels: Das Spiel wählt laufend das nächste Objekt in der
-- Nähe als Interaktionsziel (Einheit "softinteract") und kann ihm eine Namensplakette geben. Ist dieses Objekt
-- ein Kraut oder eine Erzader aus unseren Daten, hängt an der Plakette ein Leuchten:
--   * hell in der Farbe der Art (Kraut grün, Erz orange), wenn du das Material noch brauchst oder das Sammeln
--     dir noch Skillpunkte bringt,
--   * schwach und grau, wenn nicht (oder wenn dein Skill dafür noch nicht reicht).
--
-- Kürschnern: Leichen sind Einheiten mit geschütztem Namen/GUID. Erkannt wird über das Mauszeiger-Symbol, das das
-- Spiel für das Ziel zeigen würde (SetUnitCursorTexture: "Skin" bzw. "UnableSkin" = Skill reicht nicht).
-- Ton (opt.nodeSound, Standard aus, unabhängig vom Leuchten): leiser Hinweis, sobald ein Objekt in der Nähe ist,
-- das du sammeln kannst (Skill reicht), einmal je Objekt.
-- Standardmäßig an, sobald der eingeloggte Charakter Kräuterkunde, Bergbau oder Kürschnerei hat (opt.nodeGlow nil = automatisch,
-- true/false = vom Spieler gewählt). Weiter weg sieht kein Addon Objekte: das Spiel gibt nur das eine Soft-Target
-- im Nahbereich (ca. 15 m) preis.
-- Geänderte Spieleinstellungen werden vorher gesichert und beim Abschalten wiederhergestellt.
-- Zusammenspiel: Läuft ein Addon, das dieselben Einstellungen ändert (PÄNIK Gildentools, ForeverLootSparkles,
-- Lueur), setzt dieses Modul dieselben Werte mit, sichert und stellt aber nichts zurück (das macht das andere
-- Addon). Die Plakette wird dann am tatsächlichen Wert geprüft, weil das andere Addon sie bei Kräutern/Erzen
-- schließen kann, wenn es dort selbst nichts anzeigt. In Instanzen und im Kampf ist es aus.
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
local COLORS = { herbalism = { 0.45, 1, 0.45 }, mining = { 1, 0.62, 0.25 }, skinning = { 1, 0.85, 0.6 } }
local SOUND = 3175 -- SOUNDKIT.MAP_PING: kurzes, leises Pling

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

local function HasGatherProf()
    local rec = BT.db and BT.me and BT.db.chars[BT.me]
    local skills = rec and rec.skills
    return skills ~= nil and ((skills.herbalism or 0) > 0 or (skills.mining or 0) > 0 or (skills.skinning or 0) > 0)
end

function BT.NodeSoundOn()
    return BT.db ~= nil and BT.db.opt.nodeSound == true
end

-- An? Vom Spieler gewählt, sonst automatisch mit Kräuterkunde/Bergbau.
function BT.NodeGlowOn()
    local opt = BT.db and BT.db.opt
    if not opt then return false end
    if opt.nodeGlow ~= nil then return opt.nodeGlow == true end
    return HasGatherProf()
end

local function Wanted()
    return (BT.NodeGlowOn() or BT.NodeSoundOn()) and not InInstance()
end
local function Coop() return BT.NodeGlowConflict() ~= nil end

-- Einstellungen sichern/setzen bzw. zurücknehmen (nur außerhalb des Kampfes möglich)
local function Apply()
    if Coop() then -- das andere Addon sichert und stellt zurück
        for name, value in pairs(CVARS) do SetCV(name, value) end
        return
    end
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

-- Leuchten: großer pulsierender Schein, zwei gegenläufig drehende Sterne, ein senkrechter Lichtstrahl, ein
-- waagerechter Blitz und funkelnde kleine Sterne, die um das Objekt kreisen
local SPARKS = 8
local fx, anchor
local function CreateEffect()
    fx = CreateFrame("Frame")
    fx:SetSize(1, 1)
    fx:Hide()
    local function Layer(w, h, alpha)
        local tex = fx:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(STAR)
        tex:SetBlendMode("ADD")
        tex:SetSize(w, h)
        tex:SetPoint("CENTER")
        tex.base = alpha
        return tex
    end
    fx.glow, fx.outer, fx.inner = Layer(170, 170, 0.45), Layer(110, 110, 0.9), Layer(64, 64, 0.85)
    fx.beam = Layer(26, 220, 0.55)
    fx.flare = Layer(150, 18, 0.5)
    fx.sparks = {}
    for i = 1, SPARKS do
        local spark = Layer(22, 22, 1)
        spark.phase = (i - 1) / SPARKS * 2 * math.pi
        spark.speed = 0.6 + (i % 3) * 0.25
        spark.radius = 38 + (i % 4) * 12
        fx.sparks[i] = spark
    end
    fx.t = 0
    fx:SetScript("OnUpdate", function(self, elapsed)
        self.t = self.t + math.min(elapsed or 0, 0.1)
        local t, c, level = self.t, self.color, self.level or 1
        local pulse = 0.7 + 0.3 * math.sin(t * 3)
        local grow = 1 + 0.12 * math.sin(t * 3)
        self.glow:SetSize(170 * grow, 170 * grow)
        self.glow:SetVertexColor(c[1], c[2], c[3], self.glow.base * level * pulse)
        self.outer:SetVertexColor(c[1], c[2], c[3], self.outer.base * level)
        self.outer:SetRotation(t * 0.8)
        self.inner:SetVertexColor(1, 1, 1, self.inner.base * level * pulse)
        self.inner:SetRotation(-t * 1.3)
        self.beam:SetVertexColor(c[1], c[2], c[3], self.beam.base * level * (0.6 + 0.4 * math.sin(t * 2)))
        self.flare:SetVertexColor(1, 1, 1, self.flare.base * level * pulse)
        for _, spark in ipairs(self.sparks) do
            local a = spark.phase + t * spark.speed
            spark:ClearAllPoints()
            spark:SetPoint("CENTER", self, "CENTER", math.cos(a) * spark.radius,
                math.sin(a) * spark.radius * 0.6 + 10 * math.sin(t * 2 + spark.phase))
            local twinkle = math.max(0, math.sin(t * 4 + spark.phase * 3))
            spark:SetVertexColor(1, 1, 0.9, level * twinkle)
            spark:SetRotation(a * 2)
        end
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
    if InCombat() then return end
    if Coop() then
        -- nur öffnen, nie schließen (das andere Addon braucht sie evtl. für seine Objekte); tatsächlichen Wert prüfen
        if open and GetCV(PLATE) ~= "1" then SetCV(PLATE, "1") end
        return
    end
    if plateOpen == open then return end
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
    -- nur, wenn der eingeloggte Charakter (er sammelt ja) diesen Sammelberuf gelernt hat
    local rec = BT.me and BT.db.chars[BT.me]
    local skill = rec and rec.skills and rec.skills[kind]
    if not skill or skill <= 0 then return nil end
    local useful = false
    for _, entry in ipairs(list) do
        local res = BT.result and BT.result[entry.key]
        if res and (res.missing or 0) > 0 then useful = true end
    end
    if skill >= req and skill < req + 100 then useful = true end -- bringt noch Skillpunkte
    if skill < req then useful = false end                     -- noch nicht sammelbar
    return kind, useful, skill >= req
end

-- Häutbare Leiche? Über das Mauszeiger-Symbol des Ziels (Name/GUID von Gegnern sind in WoW Forever geschützt).
local probe, skinIDs
local function SkinCursor(unit)
    if not SetUnitCursorTexture then return nil end
    if not probe then
        probe = UIParent:CreateTexture(nil, "BACKGROUND")
        probe:Hide()
        skinIDs = {}
        if GetFileIDFromPath then
            for _, file in ipairs({ "Skin", "UnableSkin" }) do
                local id = Safe(GetFileIDFromPath, "Interface\\Cursor\\" .. file)
                if id then skinIDs[id] = file end
            end
        end
    end
    local ok, set = pcall(SetUnitCursorTexture, probe, unit, nil, true)
    if not ok or Plain(set) == false then return nil end
    local tex = Plain(probe:GetTexture())
    local name = type(tex) == "number" and skinIDs[tex] or (type(tex) == "string" and tex)
    if type(name) ~= "string" and probe.GetAtlas then name = Plain(probe:GetAtlas()) end
    if type(name) ~= "string" then return nil end
    name = name:lower()
    if not name:find("skin", 1, true) then return nil end
    return name:find("unable", 1, true) and "unable" or "able"
end
BT.SkinCursor = SkinCursor

-- Häutbare Leiche: Mauszeiger "Häuten"; hat die Leiche noch Beute, zeigt das Spiel aber den Plündern-Zeiger -
-- dann über die Gegner-ID und die Beutedaten (Kürschner-Beute) und die Stufe (reicht der Skill?)
local function NpcOf(unit)
    local guid = Safe(UnitGUID, unit)
    return type(guid) == "string" and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")) or nil
end
local function CorpseSkin(unit, skill)
    local cursor = SkinCursor(unit)
    if cursor then return cursor end
    local npc = NpcOf(unit)
    local drops = npc and BT.MOB_DROPS and BT.MOB_DROPS[npc]
    local skinnable = false
    for _, d in ipairs(drops or {}) do if d[5] then skinnable = true end end
    if not skinnable then return nil end
    local level = Safe(UnitLevel, unit)
    if type(level) == "number" and level > 0 and BT.SkinReq and skill and skill < BT.SkinReq(level) then return "unable" end
    return "able"
end
BT.CorpseSkin = CorpseSkin

-- Ein anderes Addon (PÄNIK: "Draußen NPCs als Interaktionsziel überspringen") pausiert die Zielsuche, sobald draußen
-- eine Einheit gewählt ist - auch eine Leiche. Ist es eine häutbare Leiche und hat der Charakter Kürschnerei, wird die
-- Suche im selben Moment wieder eingeschaltet; lebende NPCs bleiben unberührt. PÄNIK pausiert während seiner Pause
-- kein zweites Mal, es gibt also kein Hin und Her.
local restoring = false
local function KeepCorpseTarget(name, value)
    if restoring or name ~= "SoftTargetInteract" or tostring(value) ~= "0" then return end
    if not (BT.db and BT.NodeGlowConflict() and BT.NodeGlowOn() and not InCombat() and not InInstance()) then return end
    local rec = BT.me and BT.db.chars[BT.me]
    if not (rec and rec.skills and (rec.skills.skinning or 0) > 0) then return end
    if Safe(UnitIsDead, UNIT) ~= true or not CorpseSkin(UNIT, rec.skills.skinning) then return end
    restoring = true
    SetCV("SoftTargetInteract", CVARS.SoftTargetInteract)
    restoring = false
    BT.glowDebug.kept = (BT.glowDebug.kept or 0) + 1
end
local hookedCVar, hookedGlobal
local function EnsureCVarHook()
    if not hooksecurefunc then return end
    if hookedCVar ~= C_CVar and C_CVar and C_CVar.SetCVar then hooksecurefunc(C_CVar, "SetCVar", KeepCorpseTarget) hookedCVar = C_CVar end
    if not hookedGlobal and SetCVar then hooksecurefunc("SetCVar", KeepCorpseTarget) hookedGlobal = true end
end

local function JudgeCorpse()
    local rec = BT.me and BT.db.chars[BT.me]
    local skill = rec and rec.skills and rec.skills.skinning
    if not skill or skill <= 0 then return nil end -- ohne Kürschnerei keine Leichen hervorheben
    if Safe(UnitIsDead, UNIT) ~= true then return nil end
    local cursor = CorpseSkin(UNIT, skill)
    if not cursor then return nil end
    return "skinning", cursor == "able", cursor == "able"
end

-- Ton: einmal je Objekt, wenn es sammelbar ist; Objekt = Art + Name (GUID ist bei Leichen geschützt)
local lastSoundKey, lastSoundAt = nil, 0
local function MaybeSound(key)
    if not key then lastSoundKey = nil return end
    if not BT.NodeSoundOn() or key == lastSoundKey then return end
    local now = GetTime and GetTime() or 0
    lastSoundKey = key
    if now - lastSoundAt < 1.5 then return end -- nicht mehrmals kurz hintereinander
    lastSoundAt = now
    if PlaySound then pcall(PlaySound, SOUND, "SFX") end
    BT.glowDebug.sounds = (BT.glowDebug.sounds or 0) + 1
end

BT.glowDebug = { checks = 0, shown = 0 }
local function Evaluate()
    if not Wanted() or InCombat() then HideEffect() return end
    BT.glowDebug.checks = BT.glowDebug.checks + 1
    -- das andere Addon kann seine Werte zurückgestellt haben (dort alles abgeschaltet)
    -- "0" = das andere Addon pausiert die Zielsuche gerade (PÄNIK: "Draußen NPCs als Interaktionsziel
    -- überspringen", trifft auch Leichen): nicht dagegen ankämpfen, sonst schalten beide ständig hin und her
    local interact = GetCV("SoftTargetInteract")
    if Coop() and interact ~= CVARS.SoftTargetInteract and interact ~= "0" then Apply() end
    local kind, useful, gatherable, name
    if Safe(UnitIsGameObject, UNIT) == true then
        name = Safe(UnitName, UNIT)
        if type(name) == "string" then kind, useful, gatherable = Judge(name) end
    elseif Safe(UnitExists, UNIT) == true then
        kind, useful, gatherable = JudgeCorpse()
        name = kind and "corpse"
    end
    BT.glowDebug.last = name
    if kind and kind ~= "skinning" and BT.NoteNodeSeen then BT.NoteNodeSeen(name) end
    MaybeSound(gatherable and (kind .. ":" .. tostring(name)) or nil)
    local glow = BT.NodeGlowOn()
    SetPlate(glow and kind ~= nil)
    local plate = glow and kind and C_NamePlate and Safe(C_NamePlate.GetNamePlateForUnit, UNIT)
    if not plate then HideEffect() return end
    ShowEffect(plate, useful and COLORS[kind] or { 0.6, 0.6, 0.6 }, useful and 1 or 0.35)
    BT.glowDebug.shown = BT.glowDebug.shown + 1
end

BT.EvaluateNodeGlow = Evaluate

local ticker, pending
local function Update()
    if InCombat() then pending = true return end
    pending = false
    if Wanted() then
        EnsureCVarHook()
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
    BT.db.opt.nodeGlow = on and true or false
    Update()
end

function BT.SetNodeSound(on)
    BT.db.opt.nodeSound = on and true or nil
    Update()
    if on and PlaySound then pcall(PlaySound, SOUND, "SFX") end -- zum Probehören
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "PLAYER_SOFT_INTERACT_CHANGED", "SKILL_LINES_CHANGED" }) do
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
    elseif event == "SKILL_LINES_CHANGED" then
        -- neu gelernter Sammelberuf schaltet das Leuchten automatisch an (Skills liest Core.lua zuerst ein)
        if C_Timer and C_Timer.After then C_Timer.After(1, function() if (ticker ~= nil) ~= Wanted() then Update() end end) end
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
    print(tag .. "Erze/Kräuter hervorheben: " .. tostring(BT.NodeGlowOn()) .. " (Einstellung " .. tostring(BT.db.opt.nodeGlow)
        .. "), zusammen mit: " .. tostring(BT.NodeGlowConflict()) .. ", aktiv: " .. tostring(ticker ~= nil)
        .. ", Plakette: " .. tostring(GetCV(PLATE)))
    print(tag .. "Ton: " .. tostring(BT.NodeSoundOn()) .. ", gespielt: " .. (BT.glowDebug.sounds or 0)
        .. ", Leichen-Pause aufgehoben: " .. (BT.glowDebug.kept or 0)
        .. ", Häuten-Symbol am Ziel: " .. tostring(SkinCursor(UNIT)))
    -- was das Spiel über das aktuelle Ziel verrät (für Leichen, die nicht erkannt werden)
    local raw = "-"
    if probe then
        local tex = probe:GetTexture()
        raw = tostring(Plain(tex)) .. (probe.GetAtlas and (" / " .. tostring(Plain(probe:GetAtlas()))) or "")
    end
    print(tag .. "Ziel: tot " .. tostring(Safe(UnitIsDead, UNIT)) .. ", Objekt " .. tostring(Safe(UnitIsGameObject, UNIT))
        .. ", Gegner-ID " .. tostring(NpcOf(UNIT)) .. ", Stufe " .. tostring(Safe(UnitLevel, UNIT)) .. ", Zeiger " .. raw
        .. ", häutbar " .. tostring(CorpseSkin(UNIT, 300)))
    print(tag .. "Prüfungen: " .. BT.glowDebug.checks .. ", Leuchten gezeigt: " .. BT.glowDebug.shown
        .. ", zuletzt: " .. tostring(BT.glowDebug.last))
end

-- BerufeTracker - Sammelgebiete: wo lohnt sich Kräuterkunde, Bergbau, Kürschnerei und Angeln für den aktuellen Skill?
--
-- Daten aus GatherData.lua (Fundpunkte je Karte, häutbare Gegner, Angel-Mindestskill). Bewertung je Karte:
--   Kräuter/Erze: Summe über alle Vorkommen (Anzahl Fundpunkte x Chance auf einen Skillpunkt) je Fläche
--   Kürschnerei:  dasselbe mit den häutbaren Gegnern (Mindestskill aus der Gegnerstufe)
--   Angeln:       Chance, überhaupt etwas zu fangen (Skillpunkte hängen beim Angeln nicht vom Gebiet ab)
-- Der Skill-Bereich "von-bis" einer Karte ist der Bereich, in dem sie mindestens halb so gut ist wie an ihrem besten
-- Punkt: so sieht man, wann sich ein Wechsel lohnt. Gereiht wird nach Wert beim aktuellen Skill und Nähe.
-- Ein Klick auf ein Gebiet setzt einen Wegpunkt in die dichteste Stelle, zeigt die passenden Fundpunkte auf Welt-
-- und Minimap und einen Rundweg durch sie (BT.db.opt.gatherMap); ein zweiter Klick blendet das wieder aus.
local _, BT = ...
local L = BT.L

local function Plain(v)
    if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
    return v
end

-- Chance auf einen Skillpunkt beim Sammeln (wie im Sammel-Tooltip): orange/gelb sicher, grün fallend, grau nichts
local function Chance(skill, req)
    local green, gray = req + 50, req + 100
    if skill < req or skill >= gray then return 0 end
    if skill < green then return 1 end
    return math.max(0.2, (gray - skill) / (gray - green))
end
BT.GatherSkillChance = Chance

-- Kürschnerei (Classic): bis Stufe 10 ab Skill 1, bis 20 (Stufe-10)x10, darüber Stufe x 5
local function SkinReq(level)
    if level <= 10 then return 1 end
    if level <= 20 then return (level - 10) * 10 end
    return level * 5
end
BT.SkinReq = SkinReq

-- Angeln: ab dem Mindestskill fängt man etwas, ab etwa +95 jedes Mal
local function FishChance(skill, base)
    if skill < base then return 0 end
    return math.min(1, (skill - base + 5) / 100)
end

local function Decode(s)
    local pts = {}
    for i = 1, #s - 5, 6 do
        pts[#pts + 1] = { tonumber(s:sub(i, i + 2)) / 1000, tonumber(s:sub(i + 3, i + 5)) / 1000 }
    end
    return pts
end

-- Je Beruf und Karte: Liste der Vorkommen-Arten { req, count, node, points (erst bei Bedarf) }
local byMap = {}
local function MapNodes(prof)
    if byMap[prof] then return byMap[prof] end
    local out = {}
    if prof == "skinning" then
        for m, list in pairs(BT.SKIN_ZONES or {}) do
            local kinds = {}
            for _, e in ipairs(list) do
                local lo, hi, count, x, y, npc = e[1], e[2], e[3], e[4], e[5], e[6]
                kinds[#kinds + 1] = { req = SkinReq(math.floor((lo + hi) / 2)), count = count, lo = lo, hi = hi, npc = npc,
                    points = { { x / 100, y / 100 } } }
            end
            out[m] = kinds
        end
    elseif prof == "fishing" then
        for m, base in pairs(BT.FISH_ZONES or {}) do out[m] = { { req = base, count = 1, fish = true } } end
    else
        local learned = BT.db and BT.db.learnedNodes or {}
        for _, node in ipairs((BT.GATHER_NODES or {})[prof] or {}) do
            local seenMaps = {}
            for m, s in pairs(node.maps) do
                local kinds = out[m] or {}
                out[m] = kinds
                local extra = learned[m] and learned[m][node.n] or {}
                kinds[#kinds + 1] = { req = node.req, count = #s / 6 + #extra, node = node, raw = s, m = m }
                seenMaps[m] = true
            end
            -- selbst gesammelte Stellen auf Karten, für die die Daten dieses Vorkommen nicht kennen
            for m, byName in pairs(learned) do
                local extra = byName[node.n]
                if extra and #extra > 0 and not seenMaps[m] then
                    local kinds = out[m] or {}
                    out[m] = kinds
                    kinds[#kinds + 1] = { req = node.req, count = #extra, node = node, raw = "", m = m }
                end
            end
        end
    end
    byMap[prof] = out
    return out
end

local function Points(kind)
    if not kind.points and kind.raw then
        kind.points = Decode(kind.raw)
        -- dazu die selbst gesammelten Stellen (BT.db.learnedNodes[Karte][Vorkommen] = { {x, y}, ... })
        local learned = kind.m and kind.node and BT.db and BT.db.learnedNodes
        local extra = learned and learned[kind.m] and learned[kind.m][kind.node.n]
        for _, p in ipairs(extra or {}) do kind.points[#kind.points + 1] = { p[1], p[2] } end
    end
    return kind.points or {}
end

-- Selbst dazulernen: Beim Sammeln (Beute-Fenster eines Vorkommens) die Stelle merken, an der man steht. Welches
-- Vorkommen es ist, kommt vom zuletzt angesehenen/anvisierten Objekt (Tooltip oder Soft Target, höchstens 10 s alt).
local lastNode
function BT.NoteNodeSeen(name)
    if type(name) ~= "string" or name == "" then return end
    lastNode = { name = name, at = GetTime and GetTime() or 0 }
end
local nodeByName
local function NodeFromName(name)
    if not nodeByName then
        nodeByName = {}
        for prof, list in pairs(BT.GATHER_NODES or {}) do
            for _, node in ipairs(list) do
                nodeByName[node.n] = { node = node, prof = prof }
                for _, id in ipairs(node.ids or {}) do
                    local localized = BT.NodeName and BT.NodeName({ n = node.n, id = id })
                    if localized then nodeByName[localized] = { node = node, prof = prof } end
                end
            end
        end
    end
    return nodeByName[name]
end
function BT.LearnNodeHere()
    if not lastNode or ((GetTime and GetTime() or 0) - lastNode.at) > 10 then return false end
    local found = NodeFromName(lastNode.name)
    if not found then return false end
    local m, x, y = BT.GatherPlayerMap()
    if not (m and x and y) or x <= 0 or y <= 0 or x >= 1 or y >= 1 then return false end
    lastNode = nil
    -- schon bekannt (Daten oder gelernt, im Umkreis von 1 % der Karte)? Dann nichts tun
    for _, kind in ipairs(MapNodes(found.prof)[m] or {}) do
        if kind.node == found.node then
            for _, p in ipairs(Points(kind)) do
                local dx, dy = p[1] - x, p[2] - y
                if dx * dx + dy * dy < 0.0001 then return false end
            end
        end
    end
    BT.db.learnedNodes = BT.db.learnedNodes or {}
    local byMapLearned = BT.db.learnedNodes[m] or {}
    BT.db.learnedNodes[m] = byMapLearned
    local list = byMapLearned[found.node.n] or {}
    byMapLearned[found.node.n] = list
    list[#list + 1] = { math.floor(x * 1000 + 0.5) / 1000, math.floor(y * 1000 + 0.5) / 1000 }
    byMap[found.prof] = nil -- Vorkommen neu zusammenstellen
    if BT.GatherRebuild then BT.GatherRebuild() end
    return true
end

local function KindChance(prof, kind, skill)
    if kind.fish then return FishChance(skill, kind.req) end
    return Chance(skill, kind.req)
end

-- Weltkoordinaten (Yards) und Fläche einer Karte; ohne Kartenfunktionen (Tests) nichts
local rectCache = {}
local function ToWorld(m, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, continent, pos = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x, y))
    if ok and continent and pos then return continent, pos.x, pos.y end
end
local function MapRect(m)
    local r = rectCache[m]
    if r == nil then
        local c, x1, y1 = ToWorld(m, 0, 0)
        local _, x2, y2 = ToWorld(m, 1, 1)
        r = c and x2 and { continent = c, w = math.abs(y2 - y1), h = math.abs(x2 - x1) } or nil
        if r and (r.w < 1 or r.h < 1) then r = nil end
        rectCache[m] = r -- Fehlschläge nicht merken: später (Kartendaten geladen) erneut versuchen
    end
    return r
end
local function PlayerMap()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local m = Plain(C_Map.GetBestMapForUnit("player"))
    local pos = m and C_Map.GetPlayerMapPosition(m, "player")
    if not pos then return m end
    local x, y = Plain(pos.x), Plain(pos.y)
    if not (x and y) then return m end
    return m, x, y
end
BT.GatherPlayerMap = PlayerMap
local function PlayerWorld()
    local m, x, y = PlayerMap()
    if not x then return nil end
    return ToWorld(m, x, y)
end

local function Value(prof, kinds, skill)
    local v = 0
    for _, kind in ipairs(kinds) do v = v + kind.count * KindChance(prof, kind, skill) end
    return v
end

-- Skill-Bereich, in dem die Karte mindestens halb so gut ist wie an ihrem besten Punkt
local rangeCache = {}
local function Range(prof, m, kinds)
    local key = prof .. ":" .. m
    local r = rangeCache[key]
    if r then return r[1], r[2] end
    local best, values = 0, {}
    for s = 1, 300 do
        values[s] = Value(prof, kinds, s)
        if values[s] > best then best = values[s] end
    end
    local lo, hi
    for s = 1, 300 do
        if best > 0 and values[s] >= best * 0.5 then
            lo = lo or s
            hi = s
        end
    end
    rangeCache[key] = { lo or 1, hi or 300 }
    return lo or 1, hi or 300
end

-- Hauptstädte: dort steht kaum etwas zum Sammeln, die kleine Fläche ergäbe aber eine hohe Dichte
local CITIES = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }
local MIN_COUNT = 15 -- weniger passende Fundpunkte/Tiere: kein Sammelgebiet
local NEAR_SCALE, OTHER_CONTINENT = 3000, 30000 -- Yards (anderer Kontinent: Schiff/Zeppelin und Wege)
local GATHER_PROFS = { "herbalism", "mining", "skinning", "fishing" }

function BT.MapName(m)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(m)
    local name = info and Plain(info.name)
    return name or L["Karte %d"]:format(m)
end

-- Die besten Gebiete für einen Beruf beim Skill skill (höchstens limit), mit Bereich, Anzahl, Entfernung.
function BT.GatherZones(prof, skill, limit)
    skill = math.max(1, skill or 1)
    local continent, px, py = PlayerWorld()
    local here = PlayerMap()
    local list, areas = {}, {}
    for m, kinds in pairs(MapNodes(prof)) do
        local value = Value(prof, kinds, skill)
        -- nur Zonen (keine Dungeons/Städte-Unterkarten), wenn das Spiel den Kartentyp nennt
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(m)
        local mapType = info and Plain(info.mapType)
        if (mapType and mapType ~= 3) or CITIES[m] then value = 0 end
        local entry
        if value > 0 then
            entry = { m = m, value = value, kinds = kinds }
            entry.lo, entry.hi = Range(prof, m, kinds)
            local count = 0
            for _, kind in ipairs(kinds) do
                if KindChance(prof, kind, skill) > 0 then count = count + kind.count end
            end
            entry.count = count
            if prof ~= "fishing" and count < MIN_COUNT then entry = nil end
        end
        if entry then
            local rect = MapRect(m)
            entry.rect = rect
            if rect then areas[#areas + 1] = rect.w * rect.h / 1e6 end
            if continent and rect and rect.continent == continent then
                local _, cx, cy = ToWorld(m, 0.5, 0.5)
                if cx then entry.distance = math.sqrt((cx - px) ^ 2 + (cy - py) ^ 2) end
            end
            list[#list + 1] = entry
        end
    end
    -- Dichte je Quadratkilometer (Yards grob als Meter). Fehlt die Größe einer Karte (z. B. auf einem anderen
    -- Kontinent), zählt die mittlere Größe der bekannten Karten - nie die rohe Anzahl (sonst wären solche Karten
    -- um ein Vielfaches besser bewertet)
    table.sort(areas)
    local typical = areas[math.max(1, math.floor((#areas + 1) / 2))] or 1
    for _, entry in ipairs(list) do
        local value = entry.value
        entry.area = entry.rect and entry.rect.w * entry.rect.h / 1e6 or typical
        entry.density = value / entry.area
        do
            -- Nähe: sanft fallend (Nachbargebiet ~4,5 km = 0,4); anderer Kontinent wie 30 km Weg (≈ 0,09)
            local near = (entry.m == here and 1) or 1 / (1 + (entry.distance or OTHER_CONTINENT) / NEAR_SCALE)
            entry.near = near
            if prof == "fishing" then
                -- Angeln: Skillpunkte hängen nicht vom Gebiet ab. Gesucht ist das anspruchsvollste Gebiet, in dem man
                -- noch zuverlässig fängt (bessere Fische, Fehlwürfe kosten Zeit: Chance hoch 3), dazu die Nähe;
                -- sonst stünden immer die Startgebiete (Mindestskill -70) vorn
                local base = entry.kinds[1].req
                entry.score = value ^ 3 * (1 + (base + 70) / 100) * near
            else
                entry.score = entry.density * near
                -- liegt der Skill außerhalb des guten Bereichs der Karte, gibt es bessere: nach hinten;
                -- im Bereich zählt, wie lange sie noch lohnt (am Ende des Bereichs bald wechseln)
                if skill < entry.lo or skill > entry.hi then
                    entry.score = entry.score * 0.3
                else
                    -- nur leicht: die sinkende Chance steckt schon im Wert (sonst doppelt gezählt)
                    entry.score = entry.score * (0.7 + 0.3 * (entry.hi - skill) / math.max(1, entry.hi - entry.lo))
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.m < b.m
    end)
    while limit and #list > limit do list[#list] = nil end
    return list
end

-- Diagnose: /berufe sammeldebug [Beruf]
function BT.PrintGatherDebug(arg)
    local tag = "|cffffcc00BerufeTracker:|r "
    local m, x, y = PlayerMap()
    print(tag .. "Karte " .. tostring(m) .. " (" .. tostring(m and BT.MapName(m)) .. "), Position " .. tostring(x and string.format("%.3f, %.3f", x, y)))
    local rect = m and MapRect(m)
    print(tag .. "Kartengröße: " .. (rect and string.format("%.0f x %.0f, Kontinent %s", rect.w, rect.h, tostring(rect.continent)) or "unbekannt"))
    local learnedCount, learnedHere = 0, 0
    for lm, byName in pairs(BT.db.learnedNodes or {}) do
        for _, list in pairs(byName) do
            learnedCount = learnedCount + #list
            if lm == m then learnedHere = learnedHere + #list end
        end
    end
    print(tag .. "Selbst gelernte Fundstellen: " .. learnedCount .. " (hier " .. learnedHere .. ")")
    local profs = arg and BT.PROF_BY_KEY[arg] and { arg } or GATHER_PROFS
    local rec = BT.me and BT.db.chars[BT.me]
    for _, prof in ipairs(profs) do
        local skill = rec and rec.skills and rec.skills[prof]
        if skill and skill > 0 then
            print(tag .. BT.ProfTitle(BT.PROF_BY_KEY[prof]) .. " " .. skill .. ":")
            for i, e in ipairs(BT.GatherZones(prof, skill, 6)) do
                print(string.format("  %d. %s (%d) Wert %.0f, Anzahl %d, Fläche %s, Dichte %.1f, Entfernung %s, Nähe %.2f, Bereich %d-%d, Punkte %.1f",
                    i, BT.MapName(e.m), e.m, e.value, e.count, e.rect and string.format("%.1f", e.area) or ("~" .. string.format("%.1f", e.area)),
                    e.density, e.distance and string.format("%.0f", e.distance) or "-", e.near or 0, e.lo, e.hi, e.score))
            end
        end
    end
end

-- Skill-Farbe eines Vorkommens/Tiers: rot (noch nicht), orange, gelb, grün, grau (bringt nichts mehr);
-- Angeln nach Fangchance. Farbcodes wie im Berufsfenster.
local COLOR_CODE = { red = "|cffff2020", orange = "|cffff8040", yellow = "|cffffff00", green = "|cff40bf40", gray = "|cff808080" }
BT.SKILL_COLOR = COLOR_CODE
local function KindColor(prof, kind, skill)
    if kind.fish then
        local c = FishChance(skill, kind.req)
        return (c <= 0 and "red") or (c < 0.5 and "orange") or (c < 0.95 and "yellow") or "green"
    end
    if skill < kind.req then return "red" end
    if skill < kind.req + 25 then return "orange" end
    if skill < kind.req + 50 then return "yellow" end
    if skill < kind.req + 100 then return "green" end
    return "gray"
end
BT.GatherKindColor = KindColor

-- Farbe eines Gebiets: Durchschnitt der sammelbaren Vorkommen/Tiere (orange 3, gelb 2, grün 1, nach Anzahl
-- gewichtet; z. B. Dunkelküste bei Kürschnerei 72: 176 orange, 203 gelb, 264 grün -> gelb); rot nur, wenn noch
-- nichts geht, grau, wenn nichts mehr etwas bringt
local COLOR_VALUE = { orange = 3, yellow = 2, green = 1 }
function BT.ZoneColor(prof, m, skill)
    local sum, count, red = 0, 0, 0
    for _, kind in ipairs(MapNodes(prof)[m] or {}) do
        local c = KindColor(prof, kind, skill)
        if COLOR_VALUE[c] then
            sum, count = sum + COLOR_VALUE[c] * kind.count, count + kind.count
        elseif c == "red" then
            red = red + kind.count
        end
    end
    if count == 0 then return red > 0 and "red" or "gray" end
    local avg = sum / count
    return (avg >= 2.5 and "orange") or (avg >= 1.5 and "yellow") or "green"
end

-- Alle Sammelberufe einer Karte mit Skill-Bereich (Angeln: von = fängt etwas, bis = fängt jedes Mal)
function BT.ZoneGatherRanges(m)
    local out = {}
    for _, prof in ipairs(GATHER_PROFS) do
        local kinds = MapNodes(prof)[m]
        if kinds then
            local lo, hi
            if prof == "fishing" then
                lo, hi = math.max(1, kinds[1].req), math.max(1, kinds[1].req + 95)
            else
                lo, hi = Range(prof, m, kinds)
            end
            out[#out + 1] = { prof = prof, lo = lo, hi = hi }
        end
    end
    return out
end

-- Zeile unter dem Zonennamen der Weltkarte (beim Überfahren einer Zone, auch zusammen mit Leatrix Maps)
local function ZoneLine(m)
    local rec = BT.me and BT.db and BT.db.chars[BT.me]
    local skills = rec and rec.skills or {}
    local parts = {}
    for _, r in ipairs(BT.ZoneGatherRanges(m)) do
        local skill = skills[r.prof]
        -- nur Berufe, die der eingeloggte Charakter gelernt hat
        if skill and skill > 0 then
            local color = COLOR_CODE[BT.ZoneColor(r.prof, m, skill)]
            parts[#parts + 1] = color .. BT.ProfTitle(BT.PROF_BY_KEY[r.prof]) .. " " .. r.lo .. "-" .. r.hi .. "|r"
        end
    end
    return table.concat(parts, "  ")
end
BT.ZoneGatherLine = ZoneLine

local zoneLabel
local function AreaLabel()
    for provider in pairs(WorldMapFrame.dataProviders or {}) do
        if type(provider) == "table" and provider.Label then return provider.Label end
    end
end
local function UpdateZoneLabel()
    local map = WorldMapFrame
    local label = AreaLabel()
    local m
    if label and label:IsShown() and map.IsCanvasMouseFocus and map:IsCanvasMouseFocus() then
        local shown = map:GetMapID()
        local x, y = map:GetNormalizedCursorPosition()
        local info = x and C_Map.GetMapInfoAtPosition and C_Map.GetMapInfoAtPosition(shown, x, y)
        if info and info.mapID and info.mapID ~= shown then
            m = info.mapID
        else
            local own = C_Map.GetMapInfo and C_Map.GetMapInfo(shown)
            if own and own.mapType == 3 then m = shown end
        end
    end
    local text = m and ZoneLine(m) or ""
    if text == "" then zoneLabel:Hide() return end
    zoneLabel.text:SetText(text)
    zoneLabel:ClearAllPoints()
    local desc = label.Description
    local below = (desc and desc:IsShown() and (desc:GetText() or "") ~= "" and desc) or label.Name or label
    zoneLabel:SetPoint("TOP", below, "BOTTOM", 0, -2)
    zoneLabel:SetSize(zoneLabel.text:GetStringWidth() + 4, zoneLabel.text:GetStringHeight() + 2)
    zoneLabel:Show()
end
local function EnsureZoneLabel()
    if zoneLabel or not (WorldMapFrame and WorldMapFrame.ScrollContainer and C_Map) then return end
    zoneLabel = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)
    zoneLabel:SetFrameStrata("HIGH")
    zoneLabel.text = zoneLabel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    zoneLabel.text:SetPoint("CENTER")
    zoneLabel.text:SetShadowOffset(1, -1)
    zoneLabel:Hide()
    local watch = CreateFrame("Frame", nil, WorldMapFrame)
    local wait = 0
    watch:SetScript("OnUpdate", function(_, delta)
        wait = wait + (delta or 0)
        if wait < 0.05 then return end
        wait = 0
        local ok = pcall(UpdateZoneLabel)
        if not ok then zoneLabel:Hide() end
    end)
end
BT.EnsureZoneLabel = EnsureZoneLabel

-- Farbauswahl für Fundpunkte und Rundweg (Häkchen auf der Weltkarte): "Alle" oder einzelne Skill-Farben
local COLOR_KEYS = { "gray", "green", "yellow", "orange", "red" }
local function ColorFilter()
    local opt = BT.db and BT.db.opt.gatherColors
    if not opt or opt.all ~= false then return nil end -- alle
    return opt
end

-- Fundpunkte eines Gebiets mit Skill-Farbe, nach der Farbauswahl gefiltert (ohne Auswahl: alle Farben)
local function GatherPointsOf(prof, m, skill, filter)
    local out = {}
    local off = BT.db and BT.db.opt.gatherNodeOff
    for _, kind in ipairs(MapNodes(prof)[m] or {}) do
        if not kind.fish and not (off and kind.node and off[kind.node.n]) then
            local color = KindColor(prof, kind, skill)
            if not filter or filter[color] then
                local chance = KindChance(prof, kind, skill)
                for _, p in ipairs(Points(kind)) do out[#out + 1] = { p[1], p[2], color = color, chance = chance, kind = kind } end
            end
        end
    end
    return out
end
-- für die Empfehlung: nur, was beim Skill noch etwas bringt
local function UsefulPoints(prof, m, skill)
    return GatherPointsOf(prof, m, skill, { orange = true, yellow = true, green = true })
end
BT.GatherPoints = UsefulPoints
BT.GatherPointsOf = GatherPointsOf

-- Dichteste Stelle: der Punkt mit den meisten (nach Chance gewichteten) Nachbarn im Umkreis von 6 % der Karte;
-- graue/rote Punkte zählen nur wenig (sonst wären sie gleichwertig)
local function Weight(p) return p.chance > 0 and p.chance or 0.05 end
local function Densest(points)
    local best, bestScore = nil, -1
    for i = 1, #points do
        local a, score = points[i], 0
        for j = 1, #points do
            local b = points[j]
            local dx, dy = a[1] - b[1], a[2] - b[2]
            if dx * dx + dy * dy < 0.0036 then score = score + Weight(b) end
        end
        if score > bestScore then best, bestScore = a, score end
    end
    return best
end
BT.GatherDensest = Densest

-- Rundweg: nächster Nachbar ab der dichtesten Stelle, danach 2-opt (Kreuzungen auflösen) und Or-opt (einzelne
-- Punkte an eine bessere Stelle verschieben), jeweils bis sich nichts mehr verbessert. Abstände in echten
-- Verhältnissen der Karte (Breite/Höhe in Yards, sonst wäre der Weg verzerrt).
local function Tour(points, start, aspect)
    local n = #points
    if n < 3 then return points end
    local ax = aspect or 1 -- Breite/Höhe der Karte
    local X, Y = {}, {}
    local used, order = {}, {}
    local cur = 1
    for i = 1, n do
        X[i], Y[i] = points[i][1] * ax, points[i][2]
        if points[i] == start then cur = i end
    end
    used[cur] = true
    order[1] = cur
    for _ = 2, n do
        local bi, bd
        for i = 1, n do
            if not used[i] then
                local dx, dy = X[i] - X[cur], Y[i] - Y[cur]
                local d = dx * dx + dy * dy
                if not bd or d < bd then bi, bd = i, d end
            end
        end
        used[bi] = true
        cur = bi
        order[#order + 1] = cur
    end
    local sqrt = math.sqrt
    local function D(a, b) local dx, dy = X[a] - X[b], Y[a] - Y[b] return sqrt(dx * dx + dy * dy) end
    if n <= 900 then
        for _ = 1, 80 do
            local improved = false
            -- 2-opt: Kante (i,i+1) und (k,k+1) tauschen, wenn kürzer
            for i = 1, n - 2 do
                local a, b = order[i], order[i + 1]
                local dab = D(a, b)
                for k = i + 2, (i == 1) and (n - 1) or n do
                    local c, d = order[k], order[k % n + 1]
                    if D(a, c) + D(b, d) < dab + D(c, d) - 1e-12 then
                        local l, r = i + 1, k
                        while l < r do order[l], order[r] = order[r], order[l]; l, r = l + 1, r - 1 end
                        improved = true
                        b = order[i + 1]
                        dab = D(a, b)
                    end
                end
            end
            -- Or-opt: einen Punkt herausnehmen und zwischen zwei andere setzen, wenn kürzer
            for i = 1, n do
                local prev, p, nxt = order[(i - 2) % n + 1], order[i], order[i % n + 1]
                local gain = D(prev, p) + D(p, nxt) - D(prev, nxt)
                local bestJ, bestCost
                for j = 1, n do
                    local u, v = order[j], order[j % n + 1]
                    if u ~= p and v ~= p then
                        local cost = D(u, p) + D(p, v) - D(u, v)
                        if cost < gain - 1e-12 and (not bestCost or cost < bestCost) then bestJ, bestCost = j, cost end
                    end
                end
                if bestJ then
                    local target = order[bestJ]
                    table.remove(order, i)
                    for j = 1, #order do
                        if order[j] == target then table.insert(order, j + 1, p) break end
                    end
                    improved = true
                end
            end
            if not improved then break end
        end
    end
    local out = {}
    for i, idx in ipairs(order) do out[i] = points[idx] end
    return out
end
BT.GatherTour = Tour

-- Aktive Sammelberufe auf der Karte (mehrere gleichzeitig möglich: Kräuterkunde, Bergbau, Kürschnerei).
-- opt.gatherProfs = { [Beruf] = true } (nil = Anzeige aus); opt.gatherMap = zuletzt angeklicktes Gebiet (Wegpunkt).
local OVERLAY_PROFS = { "herbalism", "mining", "skinning" }
local function OverlayOn()
    local opt = BT.db and BT.db.opt
    return opt ~= nil and (opt.gatherProfs ~= nil or opt.gatherMap ~= nil)
end
local function ActiveProfs()
    local opt = BT.db and BT.db.opt
    local out = {}
    if not opt then return out end
    local set = opt.gatherProfs
    if not set and opt.gatherMap and opt.gatherMap.prof then set = { [opt.gatherMap.prof] = true } end
    for _, prof in ipairs(OVERLAY_PROFS) do if set and set[prof] then out[#out + 1] = prof end end
    return out
end
BT.GatherActiveProfs = ActiveProfs
-- für Stellen, die nur wissen wollen, ob überhaupt etwas angezeigt wird
local function Current()
    return OverlayOn() and (BT.db.opt.gatherMap or {}) or nil
end

-- Punkte für den Rundweg: nur, was Skillpunkte bringt (orange/gelb/grün), außer es ist nur Rot/Grau gewählt;
-- dazu ohne Ausreißer (nächster Nachbar mehr als dreimal so weit wie üblich und über 6 % der Karte) - sie bleiben
-- als Punkt sichtbar, erzwingen aber keinen langen Umweg (z. B. einzelne Inseln)
local function RoutePoints(points, aspect)
    local useful = {}
    for _, p in ipairs(points) do
        if p.color == "orange" or p.color == "yellow" or p.color == "green" then useful[#useful + 1] = p end
    end
    local base = #useful > 0 and useful or points
    -- jede Fundstelle nur einmal: mehrere Erzarten teilen sich oft dieselbe Stelle (das Spiel würfelt das Erz aus);
    -- doppelte Punkte machen den Weg unnötig lang und die Wegsuche langsam
    local seen, unique = {}, {}
    for _, p in ipairs(base) do
        local key = math.floor(p[1] * 1000 + 0.5) * 1000 + math.floor(p[2] * 1000 + 0.5)
        if not seen[key] then seen[key] = true unique[#unique + 1] = p end
    end
    base = unique
    local n = #base
    if n < 6 then return base end
    local ax = aspect or 1
    local nearest = {}
    for i = 1, n do
        local best
        for j = 1, n do
            if i ~= j then
                local dx, dy = (base[i][1] - base[j][1]) * ax, base[i][2] - base[j][2]
                local d = dx * dx + dy * dy
                if not best or d < best then best = d end
            end
        end
        nearest[i] = math.sqrt(best or 0)
    end
    local sorted = {}
    for i = 1, n do sorted[i] = nearest[i] end
    table.sort(sorted)
    local limit = math.max(sorted[math.floor(n / 2) + 1] * 3, 0.06 * ax)
    local out = {}
    for i = 1, n do if nearest[i] <= limit then out[#out + 1] = base[i] end end
    return #out >= 3 and out or base
end
BT.GatherRoutePoints = RoutePoints

-- Ein einziger Rundweg durch alle Punkte (auf Wunsch keine getrennten Wege je Gruppe); als Liste, damit Zeichnen
-- und Zwischenspeicher gleich bleiben
local function Tours(points, aspect)
    if #points < 3 then return {} end
    return { Tour(points, Densest(points), aspect) }
end
BT.GatherTours = Tours

-- Fundpunkte und Rundweg je Karte: Ist ein Sammelgebiet aktiv, zeigt jede Zonenkarte (und die Minimap der Zone, in
-- der man steht) die Punkte und den Rundweg für denselben Beruf beim aktuellen Skill, nicht nur das angeklickte Gebiet
local cache, cacheVersion = {}, 0
local function LiveSkill(prof)
    local rec = BT.me and BT.db.chars[BT.me]
    local skill = rec and rec.skills and rec.skills[prof]
    local sel = BT.db.opt.gatherMap
    return (skill and skill > 0) and skill or (sel and sel.prof == prof and sel.skill) or 1
end
local function BuildFor(m, prof)
    prof = prof or ActiveProfs()[1]
    if not (prof and m and MapNodes(prof)[m]) then return nil end
    local skill = LiveSkill(prof)
    local f = ColorFilter()
    local fkey = f and table.concat({ f.gray and "g" or "", f.green and "G" or "", f.yellow and "y" or "", f.orange and "o" or "", f.red and "r" or "" }) or "all"
    -- abgewählte Materialien gehören zum Schlüssel (auch wenn sie ohne Rebuild geändert wurden)
    local offNames = {}
    for name in pairs(BT.db.opt.gatherNodeOff or {}) do offNames[#offNames + 1] = name end
    table.sort(offNames)
    local key = prof .. ":" .. m .. ":" .. skill .. ":" .. fkey .. ":" .. cacheVersion .. ":" .. table.concat(offNames, ",")
    local c = cache[prof .. ":" .. m]
    if c and c.key == key then return c end
    local pts = GatherPointsOf(prof, m, skill, f)
    c = { points = pts, key = key, prof = prof }
    if prof ~= "skinning" then
        local rect = MapRect(m)
        local aspect = rect and rect.w / rect.h or 1.5
        local route = RoutePoints(pts, aspect)
        c.tours = Tours(route, aspect)
        c.tour = c.tours[1] -- größte Gruppe
    end
    cache[prof .. ":" .. m] = c
    return c
end
BT.GatherOverlayFor = BuildFor

-- Gemeinsamer Rundweg (Kräuterkunde + Bergbau zusammen, wenn beide aktiv und opt.gatherCombine nicht aus):
-- ein Weg durch die Rundweg-Punkte aller aktiven Berufe mit Weg
comboCache = {}
local function CombineOn()
    local opt = BT.db and BT.db.opt
    if not opt or opt.gatherCombine == false then return false end
    local n = 0
    for _, prof in ipairs(ActiveProfs()) do if prof ~= "skinning" then n = n + 1 end end
    return n >= 2
end
BT.GatherCombineOn = CombineOn
local function CombinedTour(m, builds)
    local keys = {}
    for _, b in ipairs(builds) do if b.prof ~= "skinning" then keys[#keys + 1] = b.key end end
    if #keys < 2 then return nil end
    local key = table.concat(keys, "|")
    local c = comboCache[m]
    if c and c.key == key then return c.tours end
    local rect = MapRect(m)
    local aspect = rect and rect.w / rect.h or 1.5
    local all = {}
    for _, b in ipairs(builds) do
        if b.prof ~= "skinning" then for _, p in ipairs(b.points) do all[#all + 1] = p end end
    end
    local route = RoutePoints(all, aspect)
    local tours = Tours(route, aspect)
    comboCache[m] = { key = key, tours = tours }
    return tours
end
BT.GatherCombinedTour = CombinedTour
local comboCache -- unten belegt (gemeinsamer Rundweg)
local function Rebuild()
    for k in pairs(cache) do cache[k] = nil end
    cacheVersion = cacheVersion + 1
end
BT.GatherRebuild = function()
    Rebuild()
    for k in pairs(comboCache or {}) do comboCache[k] = nil end
    if BT.RefreshGatherOverlay then BT.RefreshGatherOverlay() end
end

-- Dichte Stellen eines Gebiets: die dichteste, dann die dichteste außerhalb von 12 % um die vorigen (höchstens 5)
local function Spots(points, max)
    local rest, spots = {}, {}
    for i, p in ipairs(points) do rest[i] = p end
    while #rest > 0 and #spots < (max or 5) do
        local s = Densest(rest)
        spots[#spots + 1] = s
        local keep = {}
        for _, p in ipairs(rest) do
            local dx, dy = p[1] - s[1], p[2] - s[2]
            if dx * dx + dy * dy >= 0.0144 then keep[#keep + 1] = p end
        end
        rest = keep
    end
    return spots
end
BT.GatherSpots = Spots

-- Klick auf ein Gebiet: Beruf auf der Karte zuschalten und die Karte des Gebiets öffnen (dort sieht man alle
-- Fundpunkte und den Rundweg; ein Wegpunkt wäre überflüssig)
function BT.ShowGatherZone(prof, zone, skill)
    local opt = BT.db.opt
    opt.gatherProfs = opt.gatherProfs or {}
    if prof ~= "fishing" then opt.gatherProfs[prof] = true end
    opt.gatherMap = { prof = prof, m = zone.m, skill = skill }
    opt.gatherHidden, opt.gatherPanelHidden = nil, nil
    Rebuild()
    if C_Map and C_Map.OpenWorldMap and not (InCombatLockdown and InCombatLockdown()) then pcall(C_Map.OpenWorldMap, zone.m) end
    if BT.RefreshGatherOverlay then BT.RefreshGatherOverlay() end
end

-- Anzeige ein/aus (Rechtsklick auf Minimap-Button, Kartenknopf oder ein Sammelgebiet): die Auswahl (Berufe,
-- Materialien, Farben) bleibt erhalten, nur Punkte und Rundwege auf Welt- und Minimap werden aus- bzw. eingeblendet;
-- beim Ausblenden klappt auch das Auswahlfeld auf der Karte zu, beim Einblenden wieder auf
function BT.ToggleGatherDisplay()
    local opt = BT.db.opt
    if opt.gatherHidden then
        opt.gatherHidden, opt.gatherPanelHidden = nil, nil
        print("|cffffcc00BerufeTracker:|r " .. L["Fundpunkte und Rundwege eingeblendet"])
    else
        opt.gatherHidden, opt.gatherPanelHidden = true, true
        print("|cffffcc00BerufeTracker:|r " .. L["Fundpunkte und Rundwege ausgeblendet"])
    end
    if BT.RefreshGatherOverlay then BT.RefreshGatherOverlay() end
    if BT.RefreshUI then BT.RefreshUI() end
end

-- Rechtsklick auf ein Gebiet: diesen Beruf von der Karte nehmen (ohne Beruf: Anzeige ganz aus)
function BT.HideGatherZone(prof)
    local opt = BT.db.opt
    if not OverlayOn() then return end
    if prof and opt.gatherProfs then
        opt.gatherProfs[prof] = nil
        if opt.gatherMap and opt.gatherMap.prof == prof then opt.gatherMap = nil end
        if not next(opt.gatherProfs) then opt.gatherProfs, opt.gatherMap = nil, nil end
    else
        opt.gatherProfs, opt.gatherMap = nil, nil
    end
    Rebuild()
    if BT.RefreshGatherOverlay then BT.RefreshGatherOverlay() end
    print("|cffffcc00BerufeTracker:|r " .. L["Sammelgebiet ausgeblendet"])
end

-- Weltkarte: Punkte und Rundweg auf der Leinwand der Karte (auch mit OpenMap, dann über Weltkoordinaten)
local COLORS = { orange = { 1, 0.5, 0.25 }, yellow = { 1, 1, 0 }, green = { 0.25, 0.85, 0.25 }, gray = { 0.6, 0.6, 0.6 },
    red = { 1, 0.15, 0.15 } }

-- Auswahlfeld auf der Weltkarte (unten links, etwas höher: ganz unten liegen Koordinatenleisten anderer Addons):
-- Alle, Grau, Grün, Gelb, Orange, Rot; "Alle" graut die anderen aus
-- je Beruf eigene Linienfarbe und Form der Punkte (Kräuter Quadrat, Erz Raute, Tiere Quadrat ohne Weg)
local PROF_STYLE = {
    herbalism = { line = { 0.55, 1, 0.55, 0.7 }, rotate = 0 },
    mining = { line = { 0.55, 0.8, 1, 0.75 }, rotate = math.pi / 4 },
    skinning = { line = { 1, 0.85, 0.6, 0.7 }, rotate = 0 },
}
local colorPanel
local PANEL_ORDER = { "all", "gray", "green", "yellow", "orange", "red" }
local PANEL_LABEL = { all = L["Alle"], gray = L["Grau"], green = L["Grün"], yellow = L["Gelb"], orange = L["Orange"], red = L["Rot"] }
local function ColorOptions()
    local opt = BT.db.opt
    opt.gatherColors = opt.gatherColors or { all = true, green = true, yellow = true, orange = true }
    return opt.gatherColors
end
-- Symbole: Berufe und Materialien (Material aus den Daten; Kräuter ohne eigenen Datensatz fest, sonst Berufssymbol)
local PROF_ICON = { herbalism = "Trade_Herbalism", mining = "Trade_Mining", skinning = "INV_Misc_Pelt_Wolf_01" }
local NODE_ICON = { ["Grabmoos"] = "INV_Misc_Herb_07", ["Winterbiss"] = "INV_Misc_Flower_03", ["Geisterpilz"] = "INV_Mushroom_08",
    ["Bergsilbersalbei"] = "INV_Misc_Herb_MountainSilverSage", ["Eiskappe"] = "INV_Misc_Herb_IceCap",
    ["Schwarzer Lotus"] = "INV_Misc_Herb_BlackLotus" }
local function IconPath(name) return "Interface\\Icons\\" .. name end
local function NodeIcon(node, prof)
    local item = node.item and BT.ITEMS and BT.ITEMS[node.item]
    if item and item.icon then return IconPath(item.icon) end
    -- ohne Symbol in den Daten (z. B. Golderz, Echtsilbererz): beim Spiel über die Gegenstands-ID nachfragen
    if item and item.id then
        local get = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
        local ok, icon = pcall(get or function() end, item.id)
        icon = ok and Plain(icon)
        if icon then return icon end
    end
    return IconPath(NODE_ICON[node.n] or PROF_ICON[prof] or "INV_Misc_QuestionMark")
end
BT.GatherNodeIcon = NodeIcon
-- Kurzer Name für die Auswahl: "Goldvorkommen" -> "Gold", "Kleines Thoriumvorkommen" -> "Kleines Thorium"
local function ShortNodeName(node)
    local name = BT.NodeName({ n = node.n, id = node.ids[1] })
    for _, suffix in ipairs({ "vorkommen", "ablagerung", " Vein", " Deposit", " Lode" }) do
        if #name > #suffix + 2 and name:sub(-#suffix) == suffix then
            name = name:sub(1, -#suffix - 1)
            break
        end
    end
    return name
end
BT.GatherShortNodeName = ShortNodeName

-- Häkchen mit Symbol zwischen Kästchen und Name; der Name ist mitklickbar
local function AddIcon(box, size)
    box.icon = box:CreateTexture(nil, "ARTWORK")
    box.icon:SetSize(size, size)
    box.icon:SetPoint("LEFT", box, "RIGHT", 1, 0)
    box.label:ClearAllPoints()
    box.label:SetPoint("LEFT", box.icon, "RIGHT", 3, 0)
end

local function Learned(prof)
    local rec = BT.me and BT.db.chars[BT.me]
    return rec and rec.skills and (rec.skills[prof] or 0) > 0
end
local function NodeBox(i)
    local box = colorPanel.nodeBoxes[i]
    if box then return box end
    box = CreateFrame("CheckButton", nil, colorPanel, "UICheckButtonTemplate")
    box:SetSize(18, 18)
    box.label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    AddIcon(box, 16)
    -- feste Breite: zu lange Namen werden gekürzt statt in die Nachbarspalte zu laufen
    box.label:SetWidth(142)
    box.label:SetJustifyH("LEFT")
    if box.label.SetWordWrap then box.label:SetWordWrap(false) end
    if box.SetHitRectInsets then box:SetHitRectInsets(0, -160, 0, 0) end
    box:SetScript("OnClick", function(self)
        local opt = BT.db.opt
        opt.gatherNodeOff = opt.gatherNodeOff or {}
        opt.gatherNodeOff[self.nodeName] = (not self:GetChecked()) and true or nil
        if not next(opt.gatherNodeOff) then opt.gatherNodeOff = nil end
        Rebuild()
        if BT.RefreshGatherOverlay then BT.RefreshGatherOverlay() end
    end)
    colorPanel.nodeBoxes[i] = box
    return box
end

local COLUMN, PER_COLUMN = 182, 6
local PANEL_PROFS = { "herbalism", "mining" } -- im Auswahlfeld (Kürschnerei hat keine Fundpunkte-Liste/keinen Weg)
local PROF_Y, NODE_Y = -26, -52 -- Abstand: Überschrift -> Berufe -> Materialien
local function RefreshPanel()
    if not colorPanel then return end
    -- je Sammelberuf eine eigene Spalte: oben Häkchen mit Symbol und Name, darunter seine Materialien (nur wenn
    -- aktiv; mehr als 6 -> weitere Spalte). Berufe ohne Vorkommen auf der Karte und nicht gelernte: abgedunkelt
    local active = {}
    for _, prof in ipairs(ActiveProfs()) do active[prof] = true end
    local m = colorPanel.map
    local off = BT.db.opt.gatherNodeOff or {}
    local x, maxRows, used = 4, 0, 0
    local starts = {} -- x-Anfang jeder Berufsspalte (für die Trennstriche)
    for _, prof in ipairs(OVERLAY_PROFS) do
        if prof == "skinning" then colorPanel.profBoxes[prof]:Hide() end
    end
    for _, prof in ipairs(PANEL_PROFS) do
        local box = colorPanel.profBoxes[prof]
        local onMap = m and MapNodes(prof)[m] ~= nil
        local show = onMap or Learned(prof) or active[prof]
        box:SetShown(show and true or false)
        local c, k = PROF_STYLE[prof].line, Learned(prof) and 1 or 0.55
        box.label:SetTextColor(c[1] * k, c[2] * k, c[3] * k)
        if box.icon and box.icon.SetDesaturated then box.icon:SetDesaturated(not Learned(prof)) end
        if show then
            starts[#starts + 1] = x
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", colorPanel, "TOPLEFT", x, PROF_Y)
            box:SetChecked(active[prof] == true)
            local list, seen = {}, {}
            if active[prof] and prof ~= "skinning" then
                for _, kind in ipairs((m and MapNodes(prof)[m]) or {}) do
                    if kind.node and not seen[kind.node.n] then
                        seen[kind.node.n] = true
                        list[#list + 1] = kind
                    end
                end
                table.sort(list, function(a, b)
                    if a.req ~= b.req then return a.req < b.req end
                    return a.node.n < b.node.n
                end)
            end
            for i, kind in ipairs(list) do
                used = used + 1
                local nb = NodeBox(used)
                nb.nodeName = kind.node.n
                local color = KindColor(prof, kind, LiveSkill(prof))
                nb.label:SetText(BT.SKILL_COLOR[color] .. ShortNodeName(kind.node) .. "|r")
                nb.icon:SetTexture(NodeIcon(kind.node, prof))
                nb:SetChecked(not off[kind.node.n])
                nb:ClearAllPoints()
                nb:SetPoint("TOPLEFT", colorPanel, "TOPLEFT", x + math.floor((i - 1) / PER_COLUMN) * COLUMN,
                    NODE_Y - ((i - 1) % PER_COLUMN) * 19)
                nb:Show()
            end
            maxRows = math.max(maxRows, math.min(#list, PER_COLUMN))
            x = x + math.max(1, math.ceil(#list / PER_COLUMN)) * COLUMN
        end
    end
    for i = used + 1, #colorPanel.nodeBoxes do colorPanel.nodeBoxes[i]:Hide() end
    -- gemeinsamer Rundweg: nur, wenn mindestens zwei Berufe mit Weg aktiv sind (Kräuterkunde + Bergbau)
    local routeProfs = 0
    for _, prof in ipairs(ActiveProfs()) do if prof ~= "skinning" then routeProfs = routeProfs + 1 end end
    local combo = colorPanel.comboBox
    combo:SetShown(routeProfs >= 2)
    combo:ClearAllPoints()
    -- neben der Farbzeile unten (nach "Rot")
    combo:SetPoint("BOTTOMLEFT", colorPanel, "BOTTOMLEFT", 4 + #PANEL_ORDER * 72 + 12, 3)
    combo:SetChecked(BT.db.opt.gatherCombine ~= false)
    local bottomWidth = 4 + #PANEL_ORDER * 72 + (routeProfs >= 2 and 12 + 190 or 0)
    colorPanel:SetWidth(math.max(bottomWidth, x + 4))
    local height = -NODE_Y + 30 + maxRows * 19 + (maxRows > 0 and 4 or 0)
    colorPanel:SetHeight(height)
    -- senkrechte Trennstriche zwischen den Berufsspalten (vom Berufs-Häkchen bis über die Farbzeile)
    for i = 2, #starts do
        local line = colorPanel.separators[i - 1]
        if not line then
            line = colorPanel:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(0.6, 0.6, 0.6, 0.5)
            line:SetWidth(1)
            colorPanel.separators[i - 1] = line
        end
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", colorPanel, "TOPLEFT", starts[i] - 5, PROF_Y + 2)
        line:SetHeight(height + PROF_Y - 2 - 28)
        line:Show()
    end
    for i = #starts, #colorPanel.separators do colorPanel.separators[i]:Hide() end
    local o = ColorOptions()
    for _, key in ipairs(PANEL_ORDER) do
        local box = colorPanel.boxes[key]
        if key == "all" then
            box:SetChecked(o.all ~= false)
        else
            box:SetChecked(o[key] == true)
            local on = o.all == false
            if box.SetEnabled then box:SetEnabled(on) end
            local c = COLORS[key]
            local k = on and 1 or 0.55
            box.label:SetTextColor(c[1] * k, c[2] * k, c[3] * k)
        end
    end
end
local function EnsurePanel()
    if colorPanel or not (WorldMapFrame and WorldMapFrame.ScrollContainer) then return end
    -- Knopf zum Ein-/Ausblenden des Felds (wie bei Questie/ATT), unten links; das Feld steht rechts daneben
    local button = CreateFrame("Button", "BerufeTracker_MapButton", WorldMapFrame.ScrollContainer)
    button:SetSize(30, 30)
    button:SetPoint("BOTTOMLEFT", WorldMapFrame.ScrollContainer, "BOTTOMLEFT", 8, 34)
    button:SetFrameLevel((WorldMapFrame.ScrollContainer:GetFrameLevel() or 1) + 4001)
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(0, 0, 0, 0.7)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 2, -2)
    button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    button.icon:SetTexture("Interface\\Icons\\Trade_BlackSmithing")
    if button.SetHighlightTexture then button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD") end
    if button.RegisterForClicks then button:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            BT.ToggleGatherDisplay() -- Anzeige ein/aus, Auswahl bleibt
            return
        end
        BT.db.opt.gatherPanelHidden = not BT.db.opt.gatherPanelHidden or nil
        if BT.RefreshGatherOverlay then BT.RefreshGatherOverlay() end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("BerufeTracker")
        GameTooltip:AddLine(L["Klick: Auswahl für Fundpunkte und Rundweg ein-/ausblenden"], 1, 1, 1, true)
        GameTooltip:AddLine(L["Rechtsklick: Fundpunkte und Rundwege ein-/ausblenden"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:Hide()
    local f = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)
    f.button = button
    f:SetSize(440, 68)
    f:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT", 4, 0)
    f:SetFrameLevel((WorldMapFrame.ScrollContainer:GetFrameLevel() or 1) + 4000)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.7)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOPLEFT", 6, -6)
    f.title:SetText("BerufeTracker: " .. L["Fundpunkte und Rundweg"])
    -- Zeile "Berufe"
    f.profBoxes = {}
    f.nodeBoxes = {}
    f.separators = {}
    for _, prof in ipairs(OVERLAY_PROFS) do
        local box = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        box:SetSize(20, 20)
        box.label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        box.label:SetPoint("LEFT", box, "RIGHT", 1, 0)
        box.label:SetText(BT.ProfTitle(BT.PROF_BY_KEY[prof]))
        AddIcon(box, 18)
        box.icon:SetTexture(IconPath(PROF_ICON[prof]))
        local c = PROF_STYLE[prof].line
        box.label:SetTextColor(c[1], c[2], c[3])
        if box.SetHitRectInsets then box:SetHitRectInsets(0, -(COLUMN - 26), 0, 0) end -- ganze Spaltenbreite klickbar
        box:SetScript("OnClick", function(self)
            local opt = BT.db.opt
            if not opt.gatherProfs then
                opt.gatherProfs = {}
                for _, p in ipairs(ActiveProfs()) do opt.gatherProfs[p] = true end
            end
            opt.gatherProfs[prof] = self:GetChecked() and true or nil
            opt.gatherHidden = nil
            Rebuild()
            RefreshPanel()
            if BT.RefreshGatherOverlay then BT.RefreshGatherOverlay() end
            if BT.RefreshUI then BT.RefreshUI() end
        end)
        f.profBoxes[prof] = box
    end
    f.comboBox = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.comboBox:SetSize(20, 20)
    f.comboBox.label = f.comboBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.comboBox.label:SetPoint("LEFT", f.comboBox, "RIGHT", 1, 0)
    f.comboBox.label:SetText(L["Gemeinsamer Rundweg"])
    f.comboBox.label:SetTextColor(1, 0.82, 0)
    if f.comboBox.SetHitRectInsets then f.comboBox:SetHitRectInsets(0, -140, 0, 0) end
    f.comboBox:SetScript("OnClick", function(self)
        -- Achtung Lua: "x and false or nil" ergibt immer nil; deshalb ausdrücklich
        if self:GetChecked() then BT.db.opt.gatherCombine = nil else BT.db.opt.gatherCombine = false end
        if BT.RefreshGatherOverlay then BT.RefreshGatherOverlay() end
    end)
    f.boxes = {}
    local x = 4
    for _, key in ipairs(PANEL_ORDER) do
        local box = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        box:SetSize(20, 20)
        box:SetPoint("BOTTOMLEFT", x, 3)
        box.label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        box.label:SetPoint("LEFT", box, "RIGHT", 1, 0)
        box.label:SetText(PANEL_LABEL[key])
        -- auch der Name ist klickbar: Klickfläche des Häkchens über die Beschriftung verlängern
        if box.SetHitRectInsets then box:SetHitRectInsets(0, -48, 0, 0) end
        box:SetScript("OnClick", function(self)
            local o = ColorOptions()
            if key == "all" then o.all = self:GetChecked() and true or false
            else o[key] = self:GetChecked() and true or false end
            RefreshPanel()
            Rebuild()
            if BT.RefreshGatherOverlay then BT.RefreshGatherOverlay() end
        end)
        f.boxes[key] = box
        -- feste Breite je Eintrag (die Textbreite ist beim Aufbau der Karte oft noch nicht bekannt)
        x = x + 72
    end
    f:SetWidth(math.max(x + 4, 484))
    f.comboBox:Hide()
    colorPanel = f
    f:Hide()
    RefreshPanel()
end
BT.GatherColorPanel = function() EnsurePanel() return colorPanel end
BT.GatherMapButton = function() EnsurePanel() return colorPanel and colorPanel.button end
BT.GatherRefreshPanel = function() RefreshPanel() end
local mapLayer, pinPool, linePool = nil, {}, {}
local drawn
local function CanvasPos(canvas, m, x, y, shownMap)
    local api = _G.OpenMapAPI
    if api and api.IsStitched and api.IsStitched() then
        local u, v = api.WorldFromMap(m, x, y)
        if not u then return nil end
        local cx, cy = api.MapFromWorld(shownMap, u, v)
        if not cx then return nil end
        return cx * canvas:GetWidth(), -cy * canvas:GetHeight()
    end
    if shownMap ~= m then return nil end
    return x * canvas:GetWidth(), -y * canvas:GetHeight()
end

local function HideWorld()
    for _, t in ipairs(pinPool) do t:Hide() end
    for _, l in ipairs(linePool) do l:Hide() end
    drawn = nil
end

local function DrawWorldMap()
    if not (WorldMapFrame and WorldMapFrame.GetCanvas and WorldMapFrame:IsShown()) then return end
    local canvas = WorldMapFrame:GetCanvas()
    local shown = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    EnsurePanel()
    if colorPanel then
        -- Knopf auf jeder Karte mit Kräutern, Erzen oder häutbaren Tieren (auch wenn noch nichts eingeschaltet ist),
        -- das Feld daneben, solange es nicht über den Knopf ausgeblendet wurde
        local here = false
        for _, prof in ipairs(OVERLAY_PROFS) do
            if MapNodes(prof)[shown] then here = true end
        end
        colorPanel.button:SetShown(here)
        local showPanel = here and not BT.db.opt.gatherPanelHidden
        if showPanel and (not colorPanel:IsShown() or colorPanel.map ~= shown) then
            colorPanel.map = shown
            RefreshPanel()
        end
        colorPanel:SetShown(showPanel and true or false)
    end
    if not OverlayOn() or BT.db.opt.gatherHidden then
        HideWorld()
        return
    end
    local builds, keys = {}, {}
    for _, prof in ipairs(ActiveProfs()) do
        local b = BuildFor(shown, prof)
        if b then builds[#builds + 1] = b keys[#keys + 1] = b.key end
    end
    local stamp = table.concat(keys, "|") .. ":" .. tostring(CombineOn()) .. ":" .. tostring(shown) .. ":" .. canvas:GetWidth() .. ":" .. canvas:GetHeight()
    if stamp == drawn then return end
    drawn = stamp
    if not mapLayer then
        mapLayer = CreateFrame("Frame", nil, canvas)
        mapLayer:SetAllPoints(canvas)
    end
    -- über den Kartensymbolen anderer Addons (Questie, ATT …), die oft dieselben Kräuter/Erze zeigen
    mapLayer:SetFrameLevel(math.min(9000, canvas:GetFrameLevel() + 3000))
    for _, tex in ipairs(pinPool) do tex:Hide() end
    for _, l in ipairs(linePool) do l:Hide() end
    local scale = math.max(6, canvas:GetWidth() / 220)
    local used, lines = 0, 0
    local combined = CombineOn() and CombinedTour(shown, builds) or nil
    local tours = {}
    for _, tour in ipairs(combined or {}) do tours[#tours + 1] = { tour = tour, line = { 1, 0.82, 0, 0.75 } } end
    for _, built in ipairs(builds) do
        local style = PROF_STYLE[built.prof] or PROF_STYLE.herbalism
        for _, p in ipairs(built.points) do
            local x, y = CanvasPos(canvas, shown, p[1], p[2], shown)
            if x then
                used = used + 1
                local tex = pinPool[used]
                if not tex then
                    tex = mapLayer:CreateTexture(nil, "OVERLAY")
                    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
                    pinPool[used] = tex
                end
                local c = COLORS[p.color]
                tex:SetVertexColor(c[1], c[2], c[3], 0.9)
                tex:SetSize(scale, scale)
                if tex.SetRotation then tex:SetRotation(style.rotate) end
                tex:ClearAllPoints()
                tex:SetPoint("CENTER", canvas, "TOPLEFT", x, y)
                tex:Show()
            end
        end
        if not combined then
            for _, tour in ipairs(built.tours or {}) do tours[#tours + 1] = { tour = tour, line = style.line } end
        end
    end
    for _, entry in ipairs(tours) do
        local tour, style = entry.tour, { line = entry.line }
        if tour and #tour > 1 and mapLayer.CreateLine then
            local n = #tour
            for i = 1, n do
                local a, b = tour[i], tour[i % n + 1]
                local x1, y1 = CanvasPos(canvas, shown, a[1], a[2], shown)
                local x2, y2 = CanvasPos(canvas, shown, b[1], b[2], shown)
                if x1 and x2 then
                    lines = lines + 1
                    local l = linePool[lines]
                    if not l then
                        l = mapLayer:CreateLine(nil, "ARTWORK")
                        linePool[lines] = l
                    end
                    l:SetColorTexture(style.line[1], style.line[2], style.line[3], style.line[4])
                    l:SetThickness(math.max(1.5, scale / 4))
                    l:SetStartPoint("TOPLEFT", canvas, x1, y1)
                    l:SetEndPoint("TOPLEFT", canvas, x2, y2)
                    l:Show()
                end
            end
        end
    end
end

-- Minimap: Punkte im Umkreis (Durchmesser in Yards je Zoomstufe wie bei HereBeDragons-Pins)
local OUTDOOR = { [0] = 466 + 2 / 3, [1] = 400, [2] = 333 + 1 / 3, [3] = 266 + 2 / 3, [4] = 200, [5] = 133 + 1 / 3 }
local INDOOR = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 }
local miniPool = {}
local function DrawMinimap()
    local sel = Current()
    local used = 0
    local m, px, py
    if sel and BT.db.opt.gatherHidden then sel = nil end
    if sel and Minimap and Minimap.GetZoom then m, px, py = PlayerMap() end
    for _, prof in ipairs(sel and ActiveProfs() or {}) do
        local built = BuildFor(m, prof)
        local rect = m and MapRect(m)
        local style = PROF_STYLE[prof]
        if built and px and rect then
            local zoom = Minimap:GetZoom()
            local indoor = GetCVar and tonumber(GetCVar("minimapZoom") or "") ~= zoom
            local diameter = (indoor and INDOOR or OUTDOOR)[zoom] or 466
            local radius = Minimap:GetWidth() / 2
            local rotate = GetCVar and GetCVar("rotateMinimap") == "1"
            local facing = rotate and GetPlayerFacing and Plain(GetPlayerFacing()) or nil
            for _, p in ipairs(built.points) do
                local dx = (p[1] - px) * rect.w
                local dy = (p[2] - py) * rect.h
                if facing then
                    local s, c = math.sin(facing), math.cos(facing)
                    dx, dy = dx * c - dy * s, dx * s + dy * c
                end
                local ox, oy = dx / (diameter / 2) * radius, -dy / (diameter / 2) * radius
                if ox * ox + oy * oy < (radius - 4) ^ 2 then
                    used = used + 1
                    local t = miniPool[used]
                    if not t then
                        t = Minimap:CreateTexture(nil, "OVERLAY")
                        t:SetTexture("Interface\\Buttons\\WHITE8X8")
                        t:SetSize(5, 5)
                        miniPool[used] = t
                    end
                    local c = COLORS[p.color]
                    t:SetVertexColor(c[1], c[2], c[3], 0.95)
                    if t.SetRotation then t:SetRotation(style.rotate) end
                    t:ClearAllPoints()
                    t:SetPoint("CENTER", Minimap, "CENTER", ox, oy)
                    t:Show()
                end
            end
        end
    end
    for i = used + 1, #miniPool do miniPool[i]:Hide() end
end

function BT.RefreshGatherOverlay()
    drawn = nil
    pcall(DrawWorldMap)
    pcall(DrawMinimap)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
pcall(loader.RegisterEvent, loader, "LOOT_OPENED")
loader:SetScript("OnEvent", function(_, event)
    if event == "LOOT_OPENED" then
        pcall(BT.LearnNodeHere)
        return
    end
    pcall(EnsureZoneLabel)
end)

local driver = CreateFrame("Frame")
local elapsed = 0
driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + (delta or 0)
    if elapsed < 0.2 then return end
    elapsed = 0
    if not Current() then
        if #miniPool > 0 and miniPool[1]:IsShown() then pcall(DrawMinimap) end
        pcall(DrawWorldMap) -- blendet Punkte aus, pflegt Kartenknopf und Feld
        return
    end
    pcall(DrawWorldMap)
    pcall(DrawMinimap)
end)

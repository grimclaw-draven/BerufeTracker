-- BerufeTracker: Scannt Taschen/Bank/Post aller Charaktere und rechnet den offenen Materialbedarf aus.
local ADDON, BT = ...

BT.NAME = {}
for key, item in pairs(BT.ITEMS) do
    BT.NAME[item.de] = key
    BT.NAME[item.en] = key
end
BT.PROF_BY_NAME = {}
BT.PROF_BY_KEY = {}

local function Normalize(text) return (text:lower():gsub("[%p%s]", "")) end

-- Sortierschlüssel nach deutscher Gewohnheit: Umlaute wie Grundbuchstaben, ß wie ss, ohne Groß/Klein.
local FOLD = { ["ä"] = "a", ["ö"] = "o", ["ü"] = "u", ["Ä"] = "a", ["Ö"] = "o", ["Ü"] = "u", ["ß"] = "ss" }
function BT.SortKey(text)
    return (text:gsub("\195[\132\150\156\164\182\188\159]", FOLD)):lower()
end

-- Alphabetisch vergleichen; bei gleichem Schlüssel entscheidet der Originaltext.
function BT.Before(a, b)
    local ka, kb = BT.SortKey(a), BT.SortKey(b)
    if ka ~= kb then return ka < kb end
    return a < b
end

-- Berufe überall alphabetisch nach deutschem Namen.
table.sort(BT.PROFS, function(a, b) return BT.Before(a.title, b.title) end)

for _, prof in ipairs(BT.PROFS) do
    BT.PROF_BY_KEY[prof.key] = prof
    for _, name in ipairs(prof.names) do BT.PROF_BY_NAME[name:lower()] = prof.key end
    local allSteps = { prof.steps }
    for _, guide in ipairs(prof.alts or {}) do allSteps[#allSteps + 1] = guide.steps end
    for _, steps in ipairs(allSteps) do for _, step in ipairs(steps) do
        -- Namen, unter denen der Client dieses Rezept melden kann (Rezept-, Ergebnis- oder Rezept-Item-Name).
        step.aliases = { Normalize(step.n), Normalize(step.en) }
        if step.rc then
            BT.NAME[step.rc.de] = step.rc.slug
            BT.NAME[step.rc.en] = step.rc.slug
            for _, name in ipairs({ step.rc.de, step.rc.en }) do
                step.aliases[#step.aliases + 1] = Normalize((name:gsub("^[^:]+:%s*", "")))
            end
        end
    end end
end

-- Reihenfolge: jedes Item kommt erst, nachdem alle seine Verbraucher berechnet sind.
local ORDER = {}
do
    local seen, post = {}, {}
    local function visit(key)
        if seen[key] then return end
        seen[key] = true
        local recipe = BT.RECIPES[key]
        if recipe then for reagent in pairs(recipe.reag) do visit(reagent) end end
        post[#post + 1] = key
    end
    for key in pairs(BT.ITEMS) do visit(key) end
    for i = #post, 1, -1 do ORDER[#ORDER + 1] = post[i] end
end

local DB
local SECTIONS = { "bags", "bank", "mail" }
BT.totals, BT.byChar, BT.result, BT.imported = {}, {}, {}, {}

local function NumBags() return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 end
local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

function BT.Format(n)
    local s, out = tostring(math.floor(n + 0.5)), ""
    while #s > 3 do
        out = "." .. s:sub(-3) .. out
        s = s:sub(1, -4)
    end
    return s .. out
end

local function PlayerId()
    local name, surname = UnitFullName("player")
    if surname and surname ~= "" then return name .. " " .. surname end
    return name
end

local function Record()
    local rec = DB.chars[BT.me]
    if not rec then
        rec = { bags = {}, bank = {}, mail = {}, ts = {}, skills = {} }
        DB.chars[BT.me] = rec
    end
    local _, class = UnitClass("player")
    rec.class = class
    rec.faction = UnitFactionGroup("player")
    return rec
end

-- Item-Erkennung läuft über den Namen, die Zuordnung ID -> Item wird gemerkt.
local function KeyFromLink(id, link)
    if id and DB.idmap[id] ~= nil then return DB.idmap[id] or nil end
    local name = link and link:match("%[(.-)%]")
    if not name then return nil end
    local key = BT.NAME[name]
    if id then DB.idmap[id] = key or false end
    return key
end

local function KeyFromID(id)
    local known = DB.idmap[id]
    if known ~= nil then return known or nil end
    local name = GetInfo(id)
    if not name then
        BT.pendingNames = true
        return nil
    end
    local key = BT.NAME[name]
    DB.idmap[id] = key or false
    return key
end

local function ScanContainers(list)
    local out = {}
    for _, bag in ipairs(list) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                local key = KeyFromLink(info.itemID, info.hyperlink)
                if key then out[key] = (out[key] or 0) + (info.stackCount or 1) end
            end
        end
    end
    return out
end

local function BagList()
    local list = {}
    for bag = 0, NumBags() do list[#list + 1] = bag end
    return list
end

local function BankList()
    local list, seen = {}, {}
    local function add(bag)
        if bag and not seen[bag] then
            seen[bag] = true
            list[#list + 1] = bag
        end
    end
    add(BANK_CONTAINER)
    local slots = NUM_BANKBAGSLOTS
    if not slots and Constants and Constants.InventoryConstants then
        slots = Constants.InventoryConstants.NumCharacterBankSlots
    end
    for bag = NumBags() + 1, NumBags() + (slots or 0) do add(bag) end
    if REAGENTBANK_CONTAINER and IsReagentBankUnlocked and IsReagentBankUnlocked() then add(REAGENTBANK_CONTAINER) end
    if C_Bank and C_Bank.FetchPurchasedBankTabData then
        local ok, tabs = pcall(C_Bank.FetchPurchasedBankTabData, 0)
        if ok and type(tabs) == "table" then
            for _, tab in ipairs(tabs) do add(tab.ID) end
        end
    end
    return list
end

local function ScanBags()
    local rec = Record()
    rec.bags = ScanContainers(BagList())
    rec.ts.bags = time()
end

local function ScanBank()
    if not BT.bankOpen then return end
    local rec = Record()
    rec.bank = ScanContainers(BankList())
    rec.ts.bank = time()
end

local function ScanMail()
    if not (GetInboxNumItems and GetInboxItem) then return end
    local rec, out = Record(), {}
    for index = 1, GetInboxNumItems() do
        for attachment = 1, ATTACHMENTS_MAX_RECEIVE or 12 do
            local name, itemID, _, count = GetInboxItem(index, attachment)
            local key = name and (BT.NAME[name] or (itemID and KeyFromID(itemID)))
            if key then out[key] = (out[key] or 0) + (count or 1) end
        end
    end
    rec.mail = out
    rec.ts.mail = time()
end

local function ScanSkills()
    local found, caps = {}, {}
    local function note(name, rank, maxRank)
        local key = type(name) == "string" and BT.PROF_BY_NAME[name:lower()]
        if key and tonumber(rank) then found[key] = math.max(found[key] or 0, tonumber(rank)) end
        if key and tonumber(maxRank) then caps[key] = math.max(caps[key] or 0, tonumber(maxRank)) end
    end
    if GetProfessions and GetProfessionInfo then
        local ok, a, b, c, d, e, f = pcall(GetProfessions)
        if ok then
            for _, index in pairs({ a, b, c, d, e, f }) do
                local ok2, name, _, rank, maxRank = pcall(GetProfessionInfo, index)
                if ok2 then note(name, rank, maxRank) end
            end
        end
    end
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() or 0 do
            local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
            if not isHeader then note(name, rank, maxRank) end
        end
    end
    if next(found) then
        local rec = Record()
        rec.skills, rec.caps = found, caps
    end
end

local function NoteRecipe(rec, recipeID, name)
    rec.known = rec.known or {}
    if name then rec.known[Normalize(name)] = true end
    local ui = C_TradeSkillUI
    if ui.GetRecipeSchematic then
        local ok, schematic = pcall(ui.GetRecipeSchematic, recipeID, false)
        local output = ok and schematic and schematic.outputItemID and GetInfo(schematic.outputItemID)
        if output then rec.known[Normalize(output)] = true end
    end
end

-- Gelernte Rezepte stehen erst fest, wenn das Berufsfenster des Charakters offen war.
local function ScanRecipes()
    local ui = C_TradeSkillUI
    if not (ui and ui.IsTradeSkillReady and ui.GetAllRecipeIDs and ui.GetRecipeInfo and ui.IsTradeSkillReady()) then return end
    for _, foreign in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting" }) do
        if ui[foreign] and ui[foreign]() then return end
    end
    local rec = Record()
    for _, recipeID in ipairs(ui.GetAllRecipeIDs() or {}) do
        local info = ui.GetRecipeInfo(recipeID)
        if info and info.learned then NoteRecipe(rec, recipeID, info.name) end
    end
end

-- Bagnon (BagBrother) kennt oft schon alle Charaktere; das füllt Lücken, bis ein Char selbst gescannt wurde.
local function AddCacheItems(section, items)
    for _, entry in pairs(items) do
        if type(entry) == "string" then
            local id = tonumber(entry:match("^(%d+)"))
            local key = id and KeyFromID(id)
            if key then
                section[key] = (section[key] or 0) + (tonumber(entry:match(";(%d+)$")) or 1)
            end
        end
    end
end

function BT.ImportBagnon()
    BT.pendingNames = false
    local out, root = {}, type(BrotherBags) == "table" and BrotherBags.forever
    if type(root) == "table" then
        for id, cache in pairs(root) do
            if type(cache) == "table" then
                local faction = (cache.faction == true and "Alliance") or (cache.faction == false and "Horde") or nil
                local rec = { bags = {}, bank = {}, mail = {}, class = cache.class, faction = faction }
                for bag, data in pairs(cache) do
                    if type(bag) == "number" and bag ~= -2 and type(data) == "table" and type(data.items) == "table" then
                        AddCacheItems((bag >= 0 and bag <= NumBags()) and rec.bags or rec.bank, data.items)
                    end
                end
                if type(cache.mail) == "table" then AddCacheItems(rec.mail, cache.mail) end
                out[id] = rec
            end
        end
    end
    BT.imported = out
end

function BT.CharIds()
    local seen, list = {}, {}
    for _, tbl in ipairs({ DB.chars, BT.imported }) do
        for id in pairs(tbl) do
            if not seen[id] then
                seen[id] = true
                list[#list + 1] = id
            end
        end
    end
    table.sort(list)
    return list
end

-- Quelle eines Bereichs: eigener Scan hat Vorrang, sonst Bagnon-Cache.
function BT.Source(id, section)
    local own = DB.chars[id]
    if own and own.ts[section] then return own[section], "own", own.ts[section] end
    local imported = BT.imported[id]
    if imported then return imported[section], "bagnon" end
    return nil
end

-- Fraktion eines Charakters (eigener Login hat Vorrang, sonst Bagnon); nil = unbekannt.
function BT.CharFaction(id)
    local own = DB.chars[id]
    if own and own.faction then return own.faction end
    local imported = BT.imported and BT.imported[id]
    return imported and imported.faction or nil
end

-- Gehört der Charakter zur Fraktion des aktiven Charakters? Unbekannt zählt mit.
-- Materialien lassen sich nicht zur anderen Fraktion schicken, deshalb zählt nur die eigene.
function BT.SameFaction(id)
    local mine = UnitFactionGroup("player")
    if mine ~= "Alliance" and mine ~= "Horde" then return true end
    local theirs = BT.CharFaction(id)
    return theirs == nil or theirs == mine
end

-- Bagnon speichert Gildenbanken als "Name*"; die zählen nur, wenn man sie aktiv einschaltet.
function BT.IsGuild(id) return id:sub(-1) == "*" end

function BT.IsIgnored(id)
    local ignored = DB.opt.ignored[id]
    if ignored == nil then return BT.IsGuild(id) end
    return ignored
end

function BT.Skill(profKey)
    local override = DB.opt.skill[profKey]
    if override then return override, "manuell" end
    local best, who = 0, nil
    for id, rec in pairs(DB.chars) do
        local rank = not BT.IsIgnored(id) and rec.skills and rec.skills[profKey]
        if rank and rank > best then best, who = rank, id end
    end
    return best, who
end

function BT.IsCurrentProf(profKey)
    local rec = DB.chars[BT.me]
    return rec ~= nil and rec.skills ~= nil and rec.skills[profKey] ~= nil
end

-- Zustand eines Rezepts: "known" (gelernt), "owned" (Rezept-Item vorhanden) oder "missing".
function BT.RecipeStatus(step)
    for id, rec in pairs(DB.chars) do
        if rec.known and not BT.IsIgnored(id) then
            for _, alias in ipairs(step.aliases) do
                if rec.known[alias] then return "known", id end
            end
        end
    end
    local owners = step.rc and BT.byChar[step.rc.slug]
    if owners then
        local best, who = 0, nil
        for id, count in pairs(owners) do
            if count > best then best, who = count, id end
        end
        if who then return "owned", who end
    end
    return "missing"
end

-- Alle Charaktere, die einen Beruf gelernt haben, höchster Skill zuerst.
function BT.ProfChars(profKey)
    local list = {}
    for id, rec in pairs(DB.chars) do
        local rank = not BT.IsIgnored(id) and rec.skills and rec.skills[profKey]
        if rank then list[#list + 1] = { id = id, rank = rank } end
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.id < b.id
    end)
    return list
end

-- Lehrer: maßgeblich ist der aktive Charakter, wenn er den Beruf hat, sonst der mit dem höchsten Skill.
local function ProfessionOwner(profKey)
    local me = DB.chars[BT.me]
    if me and me.skills and me.skills[profKey] then return me end
    local _, who = BT.Skill(profKey)
    return who and DB.chars[who] or nil
end

function BT.RankLearned(profKey, rank)
    local rec = ProfessionOwner(profKey)
    return rec ~= nil and rec.caps ~= nil and (rec.caps[profKey] or 0) >= rank.cap
end

function BT.RankDue(profKey, rank)
    local rec = ProfessionOwner(profKey)
    return rec ~= nil and rec.skills ~= nil and (rec.skills[profKey] or 0) >= rank.skill
end

local worldCache = {}
local function ToWorld(mapID, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, continent, position = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
    if ok and continent and position then return continent, position.x, position.y end
    return nil
end

local function NpcWorld(npc)
    local key = npc.m .. ":" .. npc.x .. ":" .. npc.y
    local cached = worldCache[key]
    if cached == nil then
        local continent, wx, wy = ToWorld(npc.m, npc.x / 100, npc.y / 100)
        cached = continent and { continent, wx, wy } or false
        worldCache[key] = cached
    end
    if cached then return cached[1], cached[2], cached[3] end
    return nil
end

local function PlayerWorld()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then return nil end
    return ToWorld(mapID, position.x, position.y)
end

-- Lehrer der eigenen Fraktion, die nächsten zuerst; ohne Entfernung (anderer Kontinent) dahinter.
function BT.NearestNpcs(rank)
    local faction = UnitFactionGroup("player")
    local letter = (faction == "Alliance" and "A") or (faction == "Horde" and "H") or nil
    local continent, px, py = PlayerWorld()
    local list = {}
    for _, npc in ipairs(rank.npcs) do
        if not letter or npc.f:find(letter, 1, true) then
            local entry = { npc = npc, located = continent ~= nil }
            if continent and npc.m then
                local c, x, y = NpcWorld(npc)
                if c == continent then entry.distance = math.sqrt((x - px) ^ 2 + (y - py) ^ 2) end
            end
            list[#list + 1] = entry
        end
    end
    table.sort(list, function(a, b)
        if a.distance and b.distance then return a.distance < b.distance end
        if a.distance or b.distance then return a.distance ~= nil end
        return (a.npc.de or a.npc.n) < (b.npc.de or b.npc.n)
    end)
    return list
end

function BT.NpcPlace(entry)
    local npc = entry.npc
    local zone = npc.where
    if not zone and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(npc.m)
        zone = info and info.name
    end
    return zone or "?"
end

-- Der aktive Wegpunkt mit Beschreibung; nil, sobald er im Spiel entfernt oder ersetzt wurde.
function BT.ActiveWaypoint()
    local wp = DB.opt.waypoint
    if not wp then return nil end
    if C_Map and C_Map.HasUserWaypoint and C_Map.GetUserWaypoint then
        local point = C_Map.HasUserWaypoint() and C_Map.GetUserWaypoint()
        if not point then
            DB.opt.waypoint = nil
            return nil
        end
        local c1, x1, y1 = ToWorld(wp.m, wp.x / 100, wp.y / 100)
        local c2, x2, y2 = ToWorld(point.uiMapID, point.position.x, point.position.y)
        if c1 and c2 and (c1 ~= c2 or (x1 - x2) ^ 2 + (y1 - y2) ^ 2 > 25) then
            DB.opt.waypoint = nil
            return nil
        end
    end
    local continent, px, py = PlayerWorld()
    local c, x, y = ToWorld(wp.m, wp.x / 100, wp.y / 100)
    if not (continent and c == continent) then return wp, nil, nil end
    local distance = math.sqrt((x - px) ^ 2 + (y - py) ^ 2)
    -- Weltkoordinaten: x zeigt nach Norden, y nach Westen; Blickrichtung und Drehung laufen gegen den Uhrzeigersinn.
    local angle
    if GetPlayerFacing then
        local ok, facing = pcall(GetPlayerFacing)
        if ok and not (issecretvalue and issecretvalue(facing)) and type(facing) == "number" then
            angle = math.atan2(y - py, x - px) - facing
        end
    end
    return wp, distance, angle
end

local function Plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

-- Sprichst du mit dem Ziel des Wegpunkts, hat er seinen Zweck erfüllt.
local function ClearWaypointOnInteraction()
    local wp = DB and BT.ActiveWaypoint()
    if not wp then return end
    local guid = UnitGUID and Plain(UnitGUID("npc"))
    local npcID = type(guid) == "string" and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    local name = UnitName and Plain(UnitName("npc"))
    local same
    if npcID and wp.id then same = npcID == wp.id else same = name ~= nil and (name == wp.name or name == wp.en) end
    if not same then return end
    DB.opt.waypoint = nil
    if C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
end
BT.ClearWaypointOnInteraction = ClearWaypointOnInteraction

-- Setzt die Kartenmarkierung auf einen Lehrer; geht das nicht, stehen die Daten im Chat.
function BT.SetWaypoint(entry, note)
    local npc, place = entry.npc, BT.NpcPlace(entry)
    local name = npc.de or npc.n
    local tag = "|cffffcc00BerufeTracker:|r "
    local suffix = note and (" - " .. note) or ""
    if not npc.m then
        print(tag .. name .. ": " .. place .. " (keine Koordinaten für eine Markierung)" .. suffix)
        return false
    end
    if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        local allowed = true
        if C_Map.CanSetUserWaypointOnMap then
            local ok, result = pcall(C_Map.CanSetUserWaypointOnMap, npc.m)
            allowed = ok and result == true
        end
        local previous = DB.opt.waypoint
        DB.opt.waypoint = { id = npc.id, name = name, en = npc.n, note = note, place = place, m = npc.m, x = npc.x, y = npc.y }
        if allowed and pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(npc.m, npc.x / 100, npc.y / 100)) then
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
            end
            if PlaySound and SOUNDKIT and SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_ON then
                PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_ON)
            end
            print(tag .. "Wegpunkt gesetzt: " .. name .. ", " .. place .. suffix)
            if BT.ShowWaypointLabel then BT.ShowWaypointLabel() end
            return true
        end
        DB.opt.waypoint = previous
    end
    print(tag .. name .. ", " .. place .. string.format(": %.1f, %.1f", npc.x, npc.y) .. suffix)
    return false
end

function BT.GuideList(prof)
    local list = { { key = "metabot", title = "Metabot", url = "https://metabot.gg/en/wow-forever/professions", steps = prof.steps } }
    for _, guide in ipairs(prof.alts or {}) do list[#list + 1] = guide end
    return list
end

function BT.ActiveGuide(prof)
    local list, pick = BT.GuideList(prof), DB.opt.guide[prof.key] or DB.opt.guideAll
    for _, guide in ipairs(list) do
        if guide.key == pick then return guide end
    end
    return list[1]
end

function BT.GuideSteps(prof) return BT.ActiveGuide(prof).steps end

BT.ALL_GUIDES = {
    { key = "metabot", title = "Metabot" }, { key = "rankedboost", title = "RankedBoost" }, { key = "wowhead", title = "Wowhead" },
    { key = "wowtbc", title = "wowtbc.gg" }, { key = "goldgoblin", title = "GoldGoblin" }, { key = "wowprofessions", title = "wow-professions" },
}

function BT.GlobalGuideTitle()
    for _, guide in ipairs(BT.ALL_GUIDES) do
        if guide.key == DB.opt.guideAll then return guide.title end
    end
    return BT.ALL_GUIDES[1].title
end

function BT.SetGuide(prof, key) DB.opt.guide[prof.key] = key end

-- Setzt einen Guide für alle Berufe und hebt die Einzelauswahl auf.
function BT.SetAllGuides(key)
    DB.opt.guideAll = key
    wipe(DB.opt.guide)
end

function BT.FilterChars()
    local list = {}
    for id, rec in pairs(DB.chars) do
        if next(rec.skills or {}) and not BT.IsIgnored(id) and BT.SameFaction(id) then list[#list + 1] = id end
    end
    table.sort(list)
    return list
end

-- Höchster Skill eines Berufs unter den Charakteren der eigenen Fraktion (manueller Wert hat Vorrang).
local function BestSkill(profKey)
    local override = DB.opt.skill[profKey]
    if override then return override, "manuell" end
    local best, who = 0, nil
    for id, rec in pairs(DB.chars) do
        local rank = not BT.IsIgnored(id) and BT.SameFaction(id) and rec.skills and rec.skills[profKey]
        if rank and rank > best then best, who = rank, id end
    end
    return best, who
end

-- Skills, mit denen ein Beruf in die Materialliste eingeht (einer je Charakter); leer = vom Filter ausgeschlossen.
-- Filter: nil = alle Berufe aller Charaktere der eigenen Fraktion, jeder mit seinem eigenen Skill;
-- "once" = jeder Beruf einmal mit dem besten Charakter, auch ungelernte; "learned" = gelernte Berufe einmal;
-- sonst ein einzelner Charakter.
local function FilteredSkills(profKey)
    if DB.opt.noGather and BT.PROF_BY_KEY[profKey].gather then return {} end
    local filter = DB.opt.matFilter
    if filter == "once" then return { (BestSkill(profKey)) } end
    if filter == "learned" then
        local skill, who = BestSkill(profKey)
        return who and { skill } or {}
    end
    if filter then
        local rec = DB.chars[filter]
        local skill = rec and rec.skills and rec.skills[profKey]
        return skill and { skill } or {}
    end
    local list = {}
    for _, id in ipairs(BT.CharIds()) do
        local rec = DB.chars[id]
        local skill = rec and rec.skills and rec.skills[profKey]
        if skill and not BT.IsIgnored(id) and BT.SameFaction(id) then list[#list + 1] = skill end
    end
    return list
end

-- Anteil einer Einkaufsliste, der bei diesem Skill noch offen ist.
local function LumpShare(step, skill)
    if skill >= step.t then return 0 end
    if skill <= step.f then return 1 end
    return (step.t - skill) / (step.t - step.f)
end

local function RemainingCrafts(step, skill)
    if skill >= step.t then return 0 end
    if skill <= step.f then return step.c end
    return math.ceil(step.c * (step.t - skill) / (step.t - step.f))
end

function BT.StepRemaining(step, profKey)
    return RemainingCrafts(step, (BT.Skill(profKey)))
end

function BT.Solve()
    local totals, byChar = {}, {}
    for _, id in ipairs(BT.CharIds()) do
        if not BT.IsIgnored(id) and BT.SameFaction(id) then
            for _, section in ipairs(SECTIONS) do
                local src = BT.Source(id, section)
                for key, count in pairs(src or {}) do
                    totals[key] = (totals[key] or 0) + count
                    byChar[key] = byChar[key] or {}
                    byChar[key][id] = (byChar[key][id] or 0) + count
                end
            end
        end
    end

    local demand, supply, share = {}, {}, {}
    local function AddShare(key, profKey, amount)
        share[key] = share[key] or {}
        share[key][profKey] = (share[key][profKey] or 0) + amount
    end

    for _, prof in ipairs(BT.PROFS) do
        local crafts = 0
        if not DB.opt.off[prof.key] then
            local skill, skills = (BT.Skill(prof.key)), FilteredSkills(prof.key)
            for _, step in ipairs(BT.GuideSteps(prof)) do
                if not step.lump then crafts = crafts + RemainingCrafts(step, skill) end
                for _, filtered in ipairs(skills) do
                    if step.lump then
                        local part = LumpShare(step, filtered)
                        if part > 0 then
                            for _, reagent in ipairs(step.r) do
                                local amount = math.ceil(reagent[2] * part)
                                demand[reagent[1]] = (demand[reagent[1]] or 0) + amount
                                AddShare(reagent[1], prof.key, amount)
                            end
                        end
                    else
                        local c = RemainingCrafts(step, filtered)
                        if c > 0 then
                            for _, reagent in ipairs(step.r) do
                                demand[reagent[1]] = (demand[reagent[1]] or 0) + c * reagent[2]
                                AddShare(reagent[1], prof.key, c * reagent[2])
                            end
                            if step.out then supply[step.out] = (supply[step.out] or 0) + c * step.mk end
                        end
                    end
                end
            end
        end
        prof.remaining = crafts
    end

    local result, needTotal, haveTotal = {}, 0, 0
    for _, key in ipairs(ORDER) do
        local wanted = demand[key] or 0
        local need = math.max(0, wanted - (supply[key] or 0))
        local have = totals[key] or 0
        local missing = math.max(0, need - have)
        local recipe, crafts = BT.RECIPES[key], 0
        -- Bedarf anteilig auf die Berufe verteilen, auch durch Zwischenprodukte hindurch.
        local byProf = {}
        if need > 0 then
            for profKey, amount in pairs(share[key] or {}) do byProf[profKey] = amount * need / wanted end
        end
        if recipe and missing > 0 then
            crafts = math.ceil(missing / recipe.makes)
            for reagent, amount in pairs(recipe.reag) do
                local total = crafts * amount
                demand[reagent] = (demand[reagent] or 0) + total
                for profKey, part in pairs(byProf) do AddShare(reagent, profKey, total * part / need) end
            end
        end
        result[key] = { need = need, have = have, missing = missing, crafts = crafts, byProf = byProf }
        if not recipe then
            needTotal = needTotal + need
            haveTotal = haveTotal + math.min(have, need)
        end
    end
    BT.totals, BT.byChar, BT.result = totals, byChar, result
    BT.needTotal, BT.haveTotal = needTotal, haveTotal
    local cost, unpriced = 0, 0
    for key, res in pairs(result) do
        if not BT.RECIPES[key] and res.missing > 0 then
            local price = BT.Price(key)
            if price then cost = cost + price * res.missing else unpriced = unpriced + 1 end
        end
    end
    BT.cost, BT.unpriced = cost, unpriced
end

function BT.Update()
    BT.Solve()
    if BT.RefreshUI then BT.RefreshUI() end
end

local queued = {}
local function Queue(task)
    queued[task] = true
    if queued.running then return end
    queued.running = true
    C_Timer.After(0.4, function()
        queued.running = nil
        if queued.bags then ScanBags() end
        if queued.bank then ScanBank() end
        if queued.mail then ScanMail() end
        if queued.skills then ScanSkills() end
        if queued.recipes then ScanRecipes() end
        if queued.import then BT.ImportBagnon() end
        wipe(queued)
        BT.Update()
    end)
end

local frame = CreateFrame("Frame")
local handlers = {}

function handlers.PLAYER_LOGIN()
    BerufeTrackerDB = BerufeTrackerDB or {}
    DB = BerufeTrackerDB
    DB.chars = DB.chars or {}
    DB.opt = DB.opt or {}
    DB.opt.off = DB.opt.off or {}
    DB.opt.ignored = DB.opt.ignored or {}
    DB.opt.skill = DB.opt.skill or {}
    DB.opt.matCollapsed = DB.opt.matCollapsed or {}
    DB.opt.guide = DB.opt.guide or {}
    DB.prices = DB.prices or {}
    if DB.dataVersion ~= BT.DATA_VERSION then
        DB.idmap = {}
        DB.dataVersion = BT.DATA_VERSION
    end
    DB.idmap = DB.idmap or {}
    BT.db = DB
    BT.me = PlayerId()
    for id, skills in pairs(BT.SEED_SKILLS or {}) do
        local rec = DB.chars[id]
        if not rec then
            rec = { bags = {}, bank = {}, mail = {}, ts = {} }
            DB.chars[id] = rec
        end
        if not next(rec.skills or {}) then rec.skills = skills end
        rec.caps = rec.caps or (BT.SEED_CAPS and BT.SEED_CAPS[id])
    end
    Record()
    BT.ImportBagnon()
    if BT.InitUI then BT.InitUI() end
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED",
        "MAIL_SHOW", "MAIL_INBOX_UPDATE", "SKILL_LINES_CHANGED", "GET_ITEM_INFO_RECEIVED" }) do
        frame:RegisterEvent(event)
    end
    for _, event in ipairs({ "PLAYERREAGENTBANKSLOTS_CHANGED", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE",
        "TRADE_SKILL_DATA_SOURCE_CHANGED", "NEW_RECIPE_LEARNED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED",
        "GOSSIP_SHOW", "TRAINER_SHOW", "MERCHANT_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    Queue("bags")
    Queue("skills")
end

function handlers.BAG_UPDATE_DELAYED()
    Queue("bags")
    if BT.bankOpen then Queue("bank") end
end

function handlers.BANKFRAME_OPENED()
    BT.bankOpen = true
    Queue("bank")
end

function handlers.BANKFRAME_CLOSED() BT.bankOpen = false end
function handlers.PLAYERBANKSLOTS_CHANGED() Queue("bank") end
function handlers.PLAYERREAGENTBANKSLOTS_CHANGED() Queue("bank") end
function handlers.MAIL_SHOW() Queue("mail") end
function handlers.MAIL_INBOX_UPDATE() Queue("mail") end
function handlers.SKILL_LINES_CHANGED() Queue("skills") end
for _, event in ipairs({ "GOSSIP_SHOW", "TRAINER_SHOW", "MERCHANT_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE" }) do
    handlers[event] = function() BT.ClearWaypointOnInteraction() end
end
function handlers.ZONE_CHANGED_NEW_AREA() Queue("position") end
function handlers.ZONE_CHANGED() Queue("position") end
function handlers.TRADE_SKILL_SHOW() Queue("recipes") end
function handlers.TRADE_SKILL_LIST_UPDATE() Queue("recipes") end
function handlers.TRADE_SKILL_DATA_SOURCE_CHANGED() Queue("recipes") end
function handlers.NEW_RECIPE_LEARNED(recipeID)
    local ui = C_TradeSkillUI
    local ok, info = pcall(ui.GetRecipeInfo, recipeID)
    if ok and info then NoteRecipe(Record(), recipeID, info.name) end
    Queue("recipes")
end
function handlers.GET_ITEM_INFO_RECEIVED()
    if BT.pendingNames then Queue("import") end
end

frame:SetScript("OnEvent", function(_, event, ...) handlers[event](...) end)
frame:RegisterEvent("PLAYER_LOGIN")

SLASH_BERUFETRACKER1 = "/berufe"
SLASH_BERUFETRACKER2 = "/btrack"
SlashCmdList.BERUFETRACKER = function(input)
    local cmd, arg1, arg2 = strsplit(" ", strtrim(input or ""), 3)
    cmd = (cmd or ""):lower()
    if cmd == "chatdebug" then
        BT.PrintChatDebug()
    elseif cmd == "scan" then
        BT.StartScan()
    elseif cmd == "skill" and arg1 then
        local key = BT.PROF_BY_NAME[arg1:lower()] or (BT.PROF_BY_KEY[arg1:lower()] and arg1:lower())
        if not key then
            print("|cffffcc00BerufeTracker:|r Beruf unbekannt: " .. arg1)
            return
        end
        DB.opt.skill[key] = tonumber(arg2)
        print("|cffffcc00BerufeTracker:|r " .. BT.PROF_BY_KEY[key].title .. ": " .. (arg2 and tonumber(arg2) and ("Skill auf " .. arg2 .. " gesetzt") or "wieder automatisch"))
        BT.Update()
    else
        BT.Toggle()
    end
end

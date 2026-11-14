-- BerufeTracker: Sprachen. Schlüssel ist der deutsche Text; fehlt eine Übersetzung, gilt Englisch, sonst der Schlüssel.
local _, BT = ...

local locale = GetLocale and GetLocale() or "enUS"
if locale == "enGB" then locale = "enUS" end
BT.LOCALE = locale

BT.TRANSLATIONS = BT.TRANSLATIONS or {}
local T = BT.TRANSLATIONS

BT.L = setmetatable({}, {
    __index = function(_, key)
        if locale == "deDE" then return key end
        local own = T[locale] or (locale == "esMX" and T.esES)
        return (own and own[key]) or (T.enUS and T.enUS[key]) or key
    end,
})

-- Fertigkeits-IDs des Spiels -> Beruf (gleich in jeder Sprache)
BT.SKILL_LINES = {
    [171] = "alchemy", [164] = "blacksmithing", [333] = "enchanting", [202] = "engineering",
    [182] = "herbalism", [165] = "leatherworking", [186] = "mining", [393] = "skinning",
    [197] = "tailoring", [185] = "cooking", [129] = "first-aid", [356] = "fishing",
}

-- Berufsnamen je Sprache (Deutsch steht in den Daten)
BT.PROF_NAMES = {
    alchemy = { enUS = "Alchemy", frFR = "Alchimie", esES = "Alquimia", esMX = "Alquimia", ptBR = "Alquimia", ruRU = "Алхимия", koKR = "연금술", zhCN = "炼金术", zhTW = "鍊金術", itIT = "Alchimia" },
    blacksmithing = { enUS = "Blacksmithing", frFR = "Forge", esES = "Herrería", esMX = "Herrería", ptBR = "Ferraria", ruRU = "Кузнечное дело", koKR = "대장기술", zhCN = "锻造", zhTW = "鍛造", itIT = "Forgiatura" },
    enchanting = { enUS = "Enchanting", frFR = "Enchantement", esES = "Encantamiento", esMX = "Encantamiento", ptBR = "Encantamento", ruRU = "Наложение чар", koKR = "마법부여", zhCN = "附魔", zhTW = "附魔", itIT = "Incantamento" },
    engineering = { enUS = "Engineering", frFR = "Ingénierie", esES = "Ingeniería", esMX = "Ingeniería", ptBR = "Engenharia", ruRU = "Инженерное дело", koKR = "기계공학", zhCN = "工程学", zhTW = "工程學", itIT = "Ingegneria" },
    herbalism = { enUS = "Herbalism", frFR = "Herboristerie", esES = "Herboristería", esMX = "Herboristería", ptBR = "Herborismo", ruRU = "Травничество", koKR = "약초채집", zhCN = "草药学", zhTW = "草藥學", itIT = "Erbalismo" },
    leatherworking = { enUS = "Leatherworking", frFR = "Travail du cuir", esES = "Peletería", esMX = "Peletería", ptBR = "Couraria", ruRU = "Кожевничество", koKR = "가죽세공", zhCN = "制皮", zhTW = "製皮", itIT = "Conciatura" },
    mining = { enUS = "Mining", frFR = "Minage", esES = "Minería", esMX = "Minería", ptBR = "Mineração", ruRU = "Горное дело", koKR = "채광", zhCN = "采矿", zhTW = "採礦", itIT = "Estrazione" },
    skinning = { enUS = "Skinning", frFR = "Dépeçage", esES = "Desuello", esMX = "Desuello", ptBR = "Esfolamento", ruRU = "Снятие шкур", koKR = "무두질", zhCN = "剥皮", zhTW = "剝皮", itIT = "Scuoiatura" },
    tailoring = { enUS = "Tailoring", frFR = "Couture", esES = "Sastrería", esMX = "Sastrería", ptBR = "Alfaiataria", ruRU = "Портняжное дело", koKR = "재봉술", zhCN = "裁缝", zhTW = "裁縫", itIT = "Sartoria" },
    cooking = { enUS = "Cooking", frFR = "Cuisine", esES = "Cocina", esMX = "Cocina", ptBR = "Culinária", ruRU = "Кулинария", koKR = "요리", zhCN = "烹饪", zhTW = "烹飪", itIT = "Cucina" },
    ["first-aid"] = { enUS = "First Aid", frFR = "Secourisme", esES = "Primeros auxilios", esMX = "Primeros auxilios", ptBR = "Primeiros Socorros", ruRU = "Первая помощь", koKR = "응급치료", zhCN = "急救", zhTW = "急救", itIT = "Primo Soccorso" },
    fishing = { enUS = "Fishing", frFR = "Pêche", esES = "Pesca", esMX = "Pesca", ptBR = "Pesca", ruRU = "Рыбная ловля", koKR = "낚시", zhCN = "钓鱼", zhTW = "釣魚", itIT = "Pesca" },
}

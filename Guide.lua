-- BerufeTracker: eigener Guide "Günstigster Weg".
-- Bausteine sind alle Schritte aller Guides eines Berufs. Gewählt wird die billigste Kette bis zum Ende,
-- mit Materialkosten (AH oder Händler mit unbegrenztem Vorrat), Lehrer- und Rezeptkosten.
-- Vorhandene Materialien (alle Charaktere der eigenen Fraktion) zählen gratis, bis sie aufgebraucht sind.
-- Händlerware mit begrenztem Vorrat (Rezepte wie Materialien) zählt nur, wenn sie im AH zu haben ist.
local _, BT = ...
local L = BT.L
local COSTS = BT.COSTS or { train = {}, recipe = {}, vendor = {}, sell = {} }

local UNAVAILABLE = 10000000 -- 1000g: Rezept nicht zu bekommen (nur Drop, nicht im AH) -> nur ohne Alternative
local UNKNOWN_PRICE = 1000   -- 10s je Stück, wenn es gar keinen Anhaltspunkt gibt
local ESTIMATE_FACTOR = 4    -- ohne AH-Preis: Verkaufspreis beim Händler × 4 als grobe Schätzung
local BELOW = 0.001          -- Schritte unter dem aktuellen Skill zählen kaum (nur damit die Route vollständig bleibt)
local TIME_WEIGHT = 1000000  -- schnellster Weg: 100g je Sekunde, damit Zeit immer vor Gold geht
local TIE_WEIGHT = 0.01      -- günstigster Weg: Zeit nur als winziger Ausgleich bei Gleichstand im Gold

local dirty = { cost = true, time = true, cheapest = true }
BT.planVersion = 0

-- Beim Öffnen des Fensters: mit den aktuellen Daten neu rechnen. Sonst bleibt das Ergebnis stehen, auch wenn sich
-- Bestand, Preise oder Skills ändern (z. B. beim Herstellen); nur geänderte Einstellungen (Filter, Charakter,
-- Fraktion, abgewählte Berufe) rechnen sofort neu.
function BT.MarkPlansDirty()
    dirty.cost, dirty.time, dirty.cheapest = true, true, true
    BT.openStamp = (BT.openStamp or 0) + 1
end

-- Muss neu gerechnet werden? (Tests rechnen immer mit den aktuellen Daten)
local function Stale(cache, kind)
    if cache.sig == nil then return true end
    if cache.sig == BT.inputSig then return false end
    return BT.syncCompute or cache.ctx ~= BT.inputCtx or dirty[kind]
end



local StepCrafts -- Herstellungen je Skillpunkt für jeden Schritt (unten gesetzt, sobald die Rezeptvorlagen da sind)

local function Prices(key) return (BT.db and BT.db.prices and BT.db.prices[key]) or {} end

-- Marktpreis je Stück ohne Bestand: AH oder Händler mit unbegrenztem Vorrat. Gibt Preis und Quelle.
local function Market(key)
    local entry, data = Prices(key), COSTS.vendor[key]
    local best, how
    if entry.ah then best, how = entry.ah, "ah" end
    local vendor
    if entry.vendor and not entry.vendorLim then vendor = entry.vendor
    elseif data and not data.lim and not entry.vendorLim then vendor = data.p end
    if vendor and (not best or vendor < best) then best, how = vendor, "vendor" end
    return best, how
end
BT.MarketPrice = Market

-- Kosten, ein Rezept zu lernen: 0, wenn bekannt oder das Rezept-Item schon da ist.
local function LearnCost(step)
    if step.src == "A" then return 0, "auto" end
    if BT.RecipeStatus(step) ~= "missing" then return 0, "known" end
    if step.src == "R" then
        local slug = step.rc and step.rc.slug
        if not slug then return UNAVAILABLE, "unavailable" end
        local entry, data = Prices(slug), (step.rc.id and step.rc) or COSTS.recipe[slug]
        local best, how
        if entry.ah then best, how = entry.ah, "ah" end
        local vendor
        if entry.vendor and not entry.vendorLim then vendor = entry.vendor
        elseif data and data.p and not data.lim and not entry.vendorLim then vendor = data.p end
        if vendor and (not best or vendor < best) then best, how = vendor, "vendor" end
        if not best then return UNAVAILABLE, (data and data.lim) and "limited" or "unavailable" end
        return best, how
    end
    local cost = step.tc or COSTS.train[step.en]
    return cost or 0, cost and "trainer" or "trainer?"
end
BT.LearnCost = LearnCost

-- Stückpreis mit Bestandsrabatt; Zwischenprodukte (Barren, Ballen ...) alternativ selbst hergestellt.
local function MakePricer(factor)
    local memo = {}
    local function Price(key, depth)
        if memo[key] then return memo[key][1], memo[key][2] end
        local price, how = Market(key)
        local recipe = BT.RECIPES[key]
        if recipe and (depth or 0) < 5 then
            local sum, est = 0, false
            for reagent, amount in pairs(recipe.reag) do
                local p, h = Price(reagent, (depth or 0) + 1)
                sum = sum + p * amount
                est = est or h == "est" or h == "none"
            end
            sum = sum / recipe.makes
            if not price or sum < price then price, how = sum, est and "est" or "craft" end
        end
        if not price then
            local sell = COSTS.sell[key]
            if sell then price, how = sell * ESTIMATE_FACTOR, "est" else price, how = UNKNOWN_PRICE, "none" end
        end
        price = price * (factor[key] or 1)
        memo[key] = { price, how }
        return price, how
    end
    return Price
end


-- Marktpreis mit Schätzung, wenn es keinen gibt (ohne Bestand, ohne Herstellen).
local function BaseMarket(key)
    local price, how = Market(key)
    if price then return price, how end
    local sell = COSTS.sell[key]
    if sell then return sell * ESTIMATE_FACTOR, "est" end
    return UNKNOWN_PRICE, "none"
end

-- Zeit je Stück, ein Zwischenprodukt selbst herzustellen: Zauberzeit plus Abklingzeit als Wartezeit (Sekunden).
-- Mondstoff, Arkanitbarren, Transmutationen: Stunden bis Tage je Herstellung. Gekauftes kostet keine Zeit.
local function MakeTime(key)
    local entry = BT.CRAFT_TIME and BT.CRAFT_TIME[key]
    if not entry then return 0 end
    return (entry[1] + entry[2]) / math.max(1, entry[3] or 1)
end
BT.MakeTime = MakeTime

local function TimeWeight(mode) return mode == "time" and TIME_WEIGHT or TIE_WEIGHT end

-- Spielt den Materialverbrauch nach: zuerst aus dem Bestand, was fehlt, wird gekauft oder - wenn günstiger -
-- aus Rohstoffen hergestellt (auch aus eigenen, z. B. Leinenstoffballen aus vorhandenem Leinenstoff).
-- Modus "time": Herstellen kostet zusätzlich seine Zeit (inkl. Abklingzeit), Kaufen im AH keine.
-- ranOut[key] = Skill, bei dem der Bestand eines Materials aufgebraucht war; seconds = Zeit für Zwischenprodukte.
local function NewConsumer(stock, mode)
    local self = { stock = stock, bought = 0, estimated = false, ranOut = {}, at = 0, seconds = 0 }
    local weight = TimeWeight(mode)
    local function Unit(key, depth) -- Wert je Stück im Moment (Gold, im Zeitmodus plus Zeit)
        if (stock[key] or 0) > 1e-9 then return 0 end
        local price = Market(key) -- ohne echten Preis: Zwischenprodukte herstellen statt Schätzpreis
        local recipe = BT.RECIPES[key]
        if recipe and depth < 5 then
            local sum = 0
            for reagent, amount in pairs(recipe.reag) do sum = sum + Unit(reagent, depth + 1) * amount end
            sum = sum / recipe.makes + MakeTime(key) * weight
            if not price or sum < price then return sum end
        end
        if price then return price end
        return (BaseMarket(key)) + MakeTime(key) * weight -- nur selbst herstellbar: Zeit zählt mit
    end
    function self.Take(key, amount, depth)
        depth = depth or 0
        local have = stock[key] or 0
        local used = math.min(have, amount)
        if used > 0 then
            stock[key] = have - used
            if stock[key] <= 1e-9 and not self.ranOut[key] then self.ranOut[key] = self.at end
        end
        local rest = amount - used
        if rest <= 1e-9 then return end
        local price, how = Market(key)
        local recipe = BT.RECIPES[key]
        if recipe and depth < 5 then
            local sum = 0
            for reagent, n in pairs(recipe.reag) do sum = sum + Unit(reagent, depth + 1) * n end
            if not price or sum / recipe.makes + MakeTime(key) * weight < price then
                self.seconds = self.seconds + rest * MakeTime(key)
                for reagent, n in pairs(recipe.reag) do self.Take(reagent, rest * n / recipe.makes, depth + 1) end
                return
            end
        end
        if not price then
            price, how = BaseMarket(key)
            self.seconds = self.seconds + rest * MakeTime(key) -- ohne Marktpreis bleibt nur selbst herstellen
        end
        if self.log then self.log[key] = (self.log[key] or 0) + rest end
        self.bought = self.bought + rest * price
        if how == "est" or how == "none" then self.estimated = true end
    end
    return self
end
BT.NewConsumer = NewConsumer

-- Stückpreis je Skill: gratis, solange der Bestand laut letzter Simulation reicht (freeUntil[key] = ab diesem
-- Skill aufgebraucht), sonst Markt oder Herstellen. Zwischenergebnisse je Skill zwischengespeichert.
local function MakeTimedPricer(freeUntil, mode)
    local weight = TimeWeight(mode)
    local memoS, memo = nil, {}
    local function Price(key, s, depth)
        if memoS ~= s then memoS, memo = s, {} end
        local hit = memo[key]
        if hit then return hit[1], hit[2] end
        local price, how
        local free = freeUntil[key]
        if free and s < free then
            price, how = 0, "stock"
        else
            price, how = Market(key)
            local recipe = BT.RECIPES[key]
            if recipe and (depth or 0) < 5 then
                local sum, est = 0, false
                for reagent, amount in pairs(recipe.reag) do
                    local p, h = Price(reagent, s, (depth or 0) + 1)
                    sum = sum + p * amount
                    est = est or h == "est" or h == "none"
                end
                sum = sum / recipe.makes + MakeTime(key) * weight
                if not price or sum < price then price, how = sum, est and "est" or "craft" end
            end
            if not price then
                price, how = BaseMarket(key)
                price = price + MakeTime(key) * weight
            end
        end
        memo[key] = { price, how }
        return price, how
    end
    return Price
end

-- Verbrauch einer geplanten Route nachspielen. Abschnitte: { cand = {step}, from, to } (Rezept, Chance je Punkt)
-- oder { block = {step, perPoint}, from, to } (Guide-Abschnitt). Setzt seg.cost und seg.est.
local function Simulate(segments, skill, stock, crafts, mode)
    local consumer = NewConsumer(stock, mode)
    for _, seg in ipairs(segments) do
        local step = (seg.block or seg.cand).step
        local before, est, beforeSeconds = consumer.bought, consumer.estimated, consumer.seconds
        consumer.estimated = false
        for s = math.max(seg.from, skill), seg.to - 1 do
            consumer.at = s
            local c = StepCrafts(step, s)
            for _, reagent in ipairs(step.r) do consumer.Take(reagent[1], c * reagent[2]) end
            -- hergestellte Zwischenprodukte (z. B. Seidenstoffballen) stehen später wieder zur Verfügung
            if step.out then consumer.stock[step.out] = (consumer.stock[step.out] or 0) + c * (step.mk or 1) end
        end
        seg.cost, seg.est = consumer.bought - before, consumer.estimated
        seg.extraSeconds = consumer.seconds - beforeSeconds -- Zeit für selbst hergestellte Zwischenprodukte
        consumer.estimated = est or consumer.estimated
    end
    return consumer
end

-- Bestand, der bis zu welchem Skill gratis ist (nach einer Simulation).
local function FreeUntil(stock, consumer, maxSkill)
    local out = {}
    for key, count in pairs(stock) do
        if count > 0 then out[key] = consumer and consumer.ranOut[key] or (maxSkill + 1) end
    end
    return out
end

-- Alle Schritte aller Guides eines Berufs, doppelte zusammengefasst.
local function Candidates(prof)
    local list, seen = {}, {}
    for _, guide in ipairs(BT.GuideList(prof, true)) do
        if not guide.lump then
            for _, step in ipairs(guide.steps) do
                local id = step.en .. "|" .. step.f .. "|" .. step.t .. "|" .. step.c
                -- Abklingzeit- und Quest-Rezepte gelten für beide eigenen Guides nicht (BT.CRAFT_EXCLUDE)
                if step.t > step.f and not seen[id] and not (BT.CRAFT_EXCLUDE and BT.CRAFT_EXCLUDE[step.en]) then
                    seen[id] = true
                    list[#list + 1] = { step = step, guide = guide.title }
                end
            end
        end
    end
    return list
end

-- Billigste Kette über die Skill-Grenzen der Bausteine. Gibt Blöcke {cand, s, e} zurück.
local function Plan(cands, skill, Price)
    local pointSet = {}
    for _, cand in ipairs(cands) do
        local step = cand.step
        pointSet[step.f], pointSet[step.t] = true, true
        local craft, est = 0, false
        for _, reagent in ipairs(step.r) do
            local p, how = Price(reagent[1])
            craft = craft + p * reagent[2]
            est = est or how == "est" or how == "none"
        end
        cand.craft, cand.est = craft, est
        cand.learn, cand.learnHow = LearnCost(step)
        cand.perPoint = step.c / (step.t - step.f)
        -- gewichtete Herstellungen bis zu jedem Skill im Abschnitt (nach Chance; unter dem aktuellen Skill kaum gewichtet)
        local pre, acc = { [step.f] = 0 }, 0
        for q = step.f, step.t - 1 do
            acc = acc + StepCrafts(step, q) * (q >= skill and 1 or BELOW)
            pre[q + 1] = acc
        end
        cand.pre = pre
    end
    if skill > 0 then pointSet[skill] = true end
    local points = {}
    for p in pairs(pointSet) do points[#points + 1] = p end
    table.sort(points)
    local first, last = points[1], points[#points]
    local index = {}
    for i, p in ipairs(points) do index[p] = i end
    local best, from = { [1] = 0 }, {}
    for i = 1, #points do
        local base = best[i]
        if base then
            local s = points[i]
            for _, cand in ipairs(cands) do
                local step = cand.step
                if step.f <= s and s < step.t then
                    for j = i + 1, index[step.t] do
                        local e = points[j]
                        local above = math.max(0, e - math.max(s, skill))
                        local cost = cand.craft * (cand.pre[e] - cand.pre[s])
                            + (above > 0 and cand.learn or BELOW * cand.learn)
                        local total = base + cost
                        if not best[j] or total < best[j] then best[j], from[j] = total, { i, cand } end
                    end
                end
            end
        end
    end
    -- weiteste erreichbare Stelle (normalerweise 300)
    local endIndex = #points
    while endIndex > 1 and not best[endIndex] do endIndex = endIndex - 1 end
    local blocks, j = {}, endIndex
    while from[j] do
        local i, cand = from[j][1], from[j][2]
        table.insert(blocks, 1, { cand = cand, s = points[i], e = points[j] })
        j = i
    end
    -- gleiche Bausteine hintereinander zusammenfassen
    local merged = {}
    for _, block in ipairs(blocks) do
        local prev = merged[#merged]
        if prev and prev.cand == block.cand and prev.e == block.s then prev.e = block.e else merged[#merged + 1] = block end
    end
    return merged, first, last
end

local function Usage(blocks, skill)
    local usage = {}
    for _, block in ipairs(blocks) do
        local cand = block.cand
        local above = math.max(0, block.e - math.max(block.s, skill))
        local crafts = cand.perPoint * above
        for _, reagent in ipairs(cand.step.r) do
            usage[reagent[1]] = (usage[reagent[1]] or 0) + crafts * reagent[2]
        end
    end
    return usage
end


-- Gleiche Rezepte direkt hintereinander zu einem Schritt zusammenfassen; Summen neu bilden
-- (Lernkosten und nicht erhältliche Rezepte je Rezept nur einmal).
local function Finish(steps)
    local merged = {}
    for _, step in ipairs(steps) do
        local prev = merged[#merged]
        if prev and prev.en == step.en and prev.t == step.f then
            prev.t, prev.c = step.t, prev.c + step.c
            if (prev.src or "") == "" then prev.src = step.src end -- Quelle aus den Rezeptdaten statt "unbekannt"
            prev.costMat = (prev.costMat or 0) + (step.costMat or 0)
            prev.costLearn = math.max(prev.costLearn or 0, step.costLearn or 0)
            prev.unavailable = prev.unavailable or step.unavailable
            prev.estimated = prev.estimated or step.estimated
            if prev.fromGuide ~= step.fromGuide then prev.fromGuide = prev.fromGuide or step.fromGuide end
        else
            merged[#merged + 1] = step
        end
    end
    local total, missing, estimated, learned = 0, 0, false, {}
    for _, step in ipairs(merged) do
        total = total + (step.costMat or 0)
        if not learned[step.en] then
            learned[step.en] = true
            total = total + (step.costLearn or 0)
            if step.unavailable then missing = missing + 1 end
        else
            step.costLearn = 0
        end
        estimated = estimated or (step.estimated and (step.costMat or 0) > 0)
    end
    return { steps = merged, total = total, estimated = estimated, missing = missing }
end

local cache = {}

-- Rechnet alle Berufe nacheinander; der Bestand wird dabei aufgeteilt (nicht doppelt verplant).
function BT.ComputeCheapest()
    if not Stale(cache, "cheapest") then return cache end
    dirty.cheapest = false
    local stock = {}
    for key, count in pairs(BT.totals or {}) do stock[key] = count end
    local out = { sig = BT.inputSig, ctx = BT.inputCtx }
    for _, prof in ipairs(BT.PROFS) do
        if not prof.gather then
            local cands = Candidates(prof)
            local skill = BT.Skill(prof.key) or 0
            local factor = {}
            for key, count in pairs(stock) do if count > 0 then factor[key] = 0 end end
            local blocks, usage
            for _ = 1, 3 do
                blocks = Plan(cands, skill, MakePricer(factor))
                usage = Usage(blocks, skill)
                local changed = false
                for key, used in pairs(usage) do
                    local have = stock[key] or 0
                    local f = (used <= have) and 0 or ((used - have) / used)
                    if have == 0 then f = 1 end
                    if math.abs((factor[key] or 1) - f) > 0.01 then changed = true end
                    factor[key] = f
                end
                if not changed then break end
            end
            local segments = {}
            for _, block in ipairs(blocks) do
                segments[#segments + 1] = { block = { step = block.cand.step }, from = block.s, to = block.e }
            end
            local copy = {}
            for key, count in pairs(stock) do copy[key] = count end
            local consumer = Simulate(segments, skill, copy, nil)
            local steps, total, estimated, missing = {}, 0, false, 0
            for index, block in ipairs(blocks) do
                local cand, orig = block.cand, block.cand.step
                local step = {}
                for k, v in pairs(orig) do step[k] = v end
                step.f, step.t = block.s, block.e
                local expected = 0
                for q = block.s, block.e - 1 do expected = expected + StepCrafts(orig, q) end
                step.c = math.max(1, math.ceil(expected - 1e-9)) -- voraussichtlich nach Chance
                local above = math.max(0, block.e - math.max(block.s, skill))
                step.costMat = segments[index].cost or 0
                step.costLearn = above > 0 and cand.learn or 0
                step.learnHow = cand.learnHow
                step.fromGuide = cand.guide
                step.estimated = segments[index].est
                if step.costLearn >= UNAVAILABLE then step.unavailable = true step.costLearn = 0 end
                total = total + step.costMat + step.costLearn
                estimated = estimated or (cand.est and above > 0)
                steps[#steps + 1] = step
            end
            stock = consumer.stock
            out[prof.key] = Finish(steps)
        end
    end
    cache = out
    return out
end

-- Guide-Eintrag für die Auswahl; die Schritte werden erst bei Bedarf berechnet.
function BT.CheapestGuide(prof)
    if prof.gather then return nil end
    local guide = { key = "cheapest", title = L["Günstigster Guide-Weg"], cheapest = true,
        url = L["Eigener Guide aus allen Guides: billigste Rezepte nach AH-, Händler-, Lehrer- und Rezeptpreisen; vorhandene Materialien zählen gratis."] }
    return setmetatable(guide, { __index = function(_, k)
        local plan = BT.ComputeCheapest()[prof.key]
        if k == "steps" then return plan and plan.steps or prof.steps end
        if k == "plan" then return plan end
    end })
end

-- ===== Guide "Günstigster berechneter Weg": unabhängig von den anderen Guides =====
-- Bausteine sind alle Rezepte des Berufs aus den Forever-Spieldaten (BT.ALLREC). Für jeden Skillpunkt zählt die
-- erwartete Zahl an Herstellungen nach Farbe: orange sicher, ab gelb Chance (grau - Skill) / (grau - gelb).
-- Lernkosten zählen, sobald ein Rezept zum ersten Mal benutzt wird.

local function NormalizeName(text) return (tostring(text):lower():gsub("[%p%s]", "")) end

-- Schritt-Vorlagen einmal beim Laden bauen (Namen, Aliasse für "schon gelernt", Rezept-Items fürs Inventar).
local TEMPLATES = {}
do
    local getSpell = C_Spell and C_Spell.GetSpellName
    for profKey, recs in pairs(BT.ALLREC or {}) do
        local list = {}
        for _, rec in ipairs(recs) do
            local step = { n = rec.de, en = rec.en, src = rec.src, spell = rec.s, r = rec.r, tc = rec.tc,
                l = rec.l, y = rec.y, g = rec.g, su = rec.su or 1, item = rec.item, ct = rec.ct }
            step.aliases = { NormalizeName(rec.de), NormalizeName(rec.en) }
            if rec.item then
                step.aliases[#step.aliases + 1] = "#" .. rec.item
                local out = BT.ITEM_BY_ID[rec.item]
                if out then step.out, step.mk = out, rec.mk or 1 end
            end
            if getSpell then
                local ok, own = pcall(getSpell, rec.s)
                if ok and type(own) == "string" and own ~= "" and not (issecretvalue and issecretvalue(own)) then
                    step.aliases[#step.aliases + 1] = NormalizeName(own)
                end
            end
            if rec.rc then
                local rc = rec.rc
                local slug = BT.ITEM_BY_ID[rc.id] or ("recipe-item-" .. rc.id)
                step.rc = { slug = slug, de = rc.de, en = rc.en, id = rc.id, p = rc.p, lim = rc.lim }
                BT.ITEM_BY_ID[rc.id] = slug
                BT.NAME[rc.de], BT.NAME[rc.en] = slug, slug
                if BT.RC_ITEM and not BT.RC_ITEM[rc.en] then BT.RC_ITEM[rc.en] = rc.id end
                for _, name in ipairs({ rc.de, rc.en }) do
                    step.aliases[#step.aliases + 1] = NormalizeName((name:gsub("^[^:]+:%s*", "")))
                end
            end
            list[#list + 1] = step
        end
        TEMPLATES[profKey] = list
    end
end
BT.RECIPE_TEMPLATES = TEMPLATES

-- Erwartete Herstellungen für einen Skillpunkt bei Skill s; nil, wenn das Rezept dort nicht (mehr) zählt.
local function CraftsPerPoint(step, s)
    if s < step.l or s >= step.g then return nil end
    local chance = 1
    if s >= step.y and step.g > step.y then chance = (step.g - s) / (step.g - step.y) end
    return 1 / (chance * step.su)
end
BT.CraftsPerPoint = CraftsPerPoint

-- Rezept-Vorlage (mit Farbgrenzen) zu einem beliebigen Schritt, auch aus den fremden Guides
local TEMPLATE_BY_EN = {}
for _, list in pairs(TEMPLATES) do
    for _, tpl in ipairs(list) do TEMPLATE_BY_EN[tpl.en] = TEMPLATE_BY_EN[tpl.en] or tpl end
end
function BT.StepTemplate(step)
    if step.l and step.y and step.g then return step end
    return TEMPLATE_BY_EN[step.en]
end

-- Herstellungen für einen Skillpunkt bei Skill s, wie gerechnet wird: eigene Rezept-Schritte nach Rezeptfarbe und
-- Chance; Schritte der fremden Guides (und von dort übernommene Abschnitte) mit der Zahl des Guides - die fremden
-- Guides bleiben so, wie sie sind, und der eigene Weg ist nie teurer als ein Guide.
StepCrafts = function(step, s)
    local c = step.l and step.y and step.g and CraftsPerPoint(step, s)
    if c then return c end
    return step.c / math.max(1, step.t - step.f)
end
BT.StepCrafts = StepCrafts

-- Nur zur Anzeige: voraussichtliche Herstellungen nach Chance ab Skill "from" (auch für Schritte fremder Guides);
-- nil, wenn das Rezept unbekannt ist.
function BT.ExpectedCrafts(step, from)
    local tpl = BT.StepTemplate(step)
    if not tpl then return nil end
    local sum = 0
    for s = math.max(from or step.f, step.f), step.t - 1 do
        sum = sum + (CraftsPerPoint(tpl, s) or step.c / math.max(1, step.t - step.f))
    end
    return math.ceil(sum - 1e-9)
end

local MAX_SKILL = 300

-- Zauberzeit je Herstellung in Sekunden: aus den Rezeptdaten, für Guide-Schritte über den Rezeptnamen.
local CAST_BY_NAME = {}
for _, list in pairs(TEMPLATES) do
    for _, step in ipairs(list) do CAST_BY_NAME[step.en] = CAST_BY_NAME[step.en] or step.ct end
end
local function CastTime(step) return step.ct or CAST_BY_NAME[step.en] or 5 end
BT.CastTime = CastTime

-- Modus "time" (schnellster Weg): eine Sekunde Herstellzeit wiegt mehr als jedes Gold, Gold entscheidet nur bei
-- Gleichstand. Nicht erhältliche Rezepte bleiben in beiden Modi das Letzte, was gewählt wird.
local function LearnValue(learn, mode)
    if mode == "time" and learn >= UNAVAILABLE then return learn * 100000 end
    return learn
end

-- Billigster (oder schnellster) Weg Punkt für Punkt. Zwei Arten von Bausteinen:
--  * Rezepte (Zustand = zuletzt benutztes Rezept, Herstellungen je Punkt nach Farbe und Chance)
--  * Abschnitte der anderen Guides (mit deren Herstellungszahlen), Start bei jedem Skill, Ende an einer Abschnittsgrenze.
-- Materialkosten werden für jeden Skillpunkt einzeln bewertet: Bestand ist nur gratis, bis er laut Simulation
-- aufgebraucht ist (auch innerhalb eines langen Guide-Abschnitts).
local function PlanAll(steps, blocks, skill, Price, withUnavailable, breaks, mode, yield)
    -- Kosten einer Herstellung bei Skill s; ändern sich nur an den Stellen, an denen ein Material aufgebraucht ist
    local segOf, seg = {}, 0
    for s = 1, MAX_SKILL do
        if breaks and breaks[s] then seg = seg + 1 end
        segOf[s] = seg
    end
    local craftCache, cacheSeg = {}, nil
    local function Craft(step, s)
        if segOf[s] ~= cacheSeg then craftCache, cacheSeg = {}, segOf[s] end
        local hit = craftCache[step]
        if hit then return hit end
        local sum = 0
        for _, reagent in ipairs(step.r) do sum = sum + Price(reagent[1], s) * reagent[2] end
        -- schnellster Weg: Zeit vor Gold; günstigster Weg: Zeit nur als winziger Ausgleich bei Gleichstand
        -- (z. B. zwei Rezepte aus gratis Bestand: das mit weniger Herstellungen gewinnt)
        sum = sum + CastTime(step) * TimeWeight(mode)
        craftCache[step] = sum
        return sum
    end
    local usable = {}
    for _, step in ipairs(steps) do
        local learn, how = LearnCost(step)
        if withUnavailable or learn < UNAVAILABLE then
            usable[#usable + 1] = { step = step, learn = learn, how = how, value = LearnValue(learn, mode) }
        end
    end
    local guideBlocks, ends = {}, {}
    for _, cand in ipairs(blocks) do
        local learn, how = LearnCost(cand.step)
        if withUnavailable or learn < UNAVAILABLE then
            local step = cand.step
            local block = { step = step, guide = cand.guide, learn = learn, how = how, value = LearnValue(learn, mode) }
            -- Kosten bis zu jedem Skill im Abschnitt, Punkt für Punkt: Herstellungen nach Chance, Bestand nur,
            -- solange er reicht
            local pre, acc = { [step.f] = 0 }, 0
            for q = step.f, step.t - 1 do
                acc = acc + Craft(step, q) * StepCrafts(step, q) * (q >= skill and 1 or BELOW)
                pre[q + 1] = acc
            end
            block.pre = pre
            guideBlocks[#guideBlocks + 1] = block
            ends[step.f], ends[step.t] = true, true
        end
    end
    if yield then yield() end
    local endList = {}
    for p in pairs(ends) do endList[#endList + 1] = p end
    table.sort(endList)

    local arrive = { [1] = 0 } -- billigste Kosten, Skill s zu erreichen
    local viaBlock = {}        -- [s] = {von, Baustein}, wenn s am billigsten über einen Guide-Abschnitt erreicht wird
    local pend = {}
    local cur, bestArg, switched = {}, {}, {}
    local reached = 1
    for s = 1, MAX_SKILL - 1 do
        local base = arrive[s]
        if not base then break end
        if yield and s % 50 == 0 then yield() end -- im Hintergrund in kleinen Stücken rechnen
        local weight = s >= skill and 1 or BELOW
        -- Guide-Abschnitte, die bei s beginnen können
        for _, block in ipairs(guideBlocks) do
            local step = block.step
            if step.f <= s and s < step.t then
                for _, e in ipairs(endList) do
                    if e > s and e <= step.t then
                        local total = base + (block.pre[e] - block.pre[s]) + block.value * weight
                        if not pend[e] or total < pend[e][1] then pend[e] = { total, s, block } end
                    end
                end
            end
        end
        -- Rezepte Punkt für Punkt
        local new, best, arg, sw = {}, nil, nil, {}
        for index, cand in ipairs(usable) do
            local crafts = CraftsPerPoint(cand.step, s)
            if crafts then
                local cont = cur[index]
                local switch = base + cand.value * weight
                local start
                if cont and cont <= switch then start = cont else start, sw[index] = switch, true end
                local total = start + Craft(cand.step, s) * crafts * weight
                new[index] = total
                if not best or total < best then best, arg = total, index end
            end
        end
        cur, bestArg[s], switched[s] = new, arg, sw
        local nextS = s + 1
        local p = pend[nextS]
        if best and (not p or best <= p[1]) then
            arrive[nextS] = best
        elseif p then
            arrive[nextS], viaBlock[nextS] = p[1], { p[2], p[3] }
        end
        if arrive[nextS] then reached = nextS end
    end
    -- Rückweg: Abschnitte {cand oder block, from, to}
    local segments, pos = {}, reached
    while pos > 1 do
        if viaBlock[pos] then
            local from, block = viaBlock[pos][1], viaBlock[pos][2]
            table.insert(segments, 1, { block = block, from = from, to = pos })
            pos = from
        else
            local s, index = pos - 1, bestArg[pos - 1]
            local to = pos
            while true do
                if switched[s][index] or s == 1 then break end
                s = s - 1
            end
            table.insert(segments, 1, { cand = usable[index], from = s, to = to })
            pos = s
        end
    end
    return segments, reached
end

-- Material und Herstellungen eines Abschnitts (offen = ab dem aktuellen Skill).
local function SegmentCrafts(seg, skill)
    local all, open = 0, 0
    local step = (seg.block or seg.cand).step
    for s = seg.from, seg.to - 1 do
        local c = StepCrafts(step, s)
        all = all + c
        if s >= skill then open = open + c end
    end
    return all, open
end

-- Rechnet alle Berufe nacheinander (Bestand wird über die Berufe verteilt). yield: Pause zwischen den Teilen,
-- damit die Rechnung im Hintergrund über mehrere Bildschirmbilder laufen kann.
local function ComputePlans(mode, yield)
    local stock = {}
    for key, count in pairs(BT.totals or {}) do stock[key] = count end
    local out = {}
    for _, prof in ipairs(BT.PROFS) do
        local templates = TEMPLATES[prof.key]
        if templates and not prof.gather then
            local skill = BT.Skill(prof.key) or 0
            local blocks = Candidates(prof)
            local freeUntil = FreeUntil(stock, nil, MAX_SKILL)
            -- Mehrere Runden: jede plant mit dem Verbrauch der vorigen. Gewählt wird die Runde, die laut
            -- Verbrauchssimulation wirklich am wenigsten kostet (Gold bzw. Zeit), nicht einfach die letzte.
            local segments, reached, consumer, bestScore
            for _ = 1, 6 do
                local Price = MakeTimedPricer(freeUntil, mode)
                local breaks = {}
                for _, at in pairs(freeUntil) do breaks[at] = true end
                local segs, reach = PlanAll(templates, blocks, skill, Price, false, breaks, mode, yield)
                if reach < MAX_SKILL then segs, reach = PlanAll(templates, blocks, skill, Price, true, breaks, mode, yield) end
                local copy = {}
                for key, count in pairs(stock) do copy[key] = count end
                local cons = Simulate(segs, skill, copy, nil, mode)
                local score = cons.bought + cons.seconds * TimeWeight(mode)
                for _, seg in ipairs(segs) do
                    local src = seg.block or seg.cand
                    local _, open = SegmentCrafts(seg, skill)
                    if seg.to > skill then score = score + LearnValue(src.learn, mode) end
                    score = score + open * CastTime(src.step) * TimeWeight(mode)
                end
                if not bestScore or score < bestScore then
                    bestScore, segments, reached, consumer = score, segs, reach, cons
                end
                -- einmal als knapp erkannt, bleibt ein Material knapp (sonst pendelt die Planung zwischen zwei Wegen)
                local nextFree, changed = FreeUntil(stock, cons, MAX_SKILL), false
                for key, value in pairs(nextFree) do
                    value = math.min(value, freeUntil[key] or value)
                    nextFree[key] = value
                    if freeUntil[key] ~= value then changed = true end
                end
                freeUntil = nextFree
                if yield then yield() end
                if not changed then break end
            end
            local steps, seconds = {}, 0
            for _, seg in ipairs(segments) do
                local src = seg.block or seg.cand
                local all, open = SegmentCrafts(seg, skill)
                local step = {}
                for k, v in pairs(src.step) do step[k] = v end
                step.f, step.t, step.c = seg.from, seg.to, math.max(1, math.ceil(all - 1e-9))
                step.costMat = seg.cost or 0
                step.costLearn = seg.to > skill and src.learn or 0
                step.learnHow, step.estimated = src.how, seg.est
                step.seconds = open * CastTime(src.step) + (seg.extraSeconds or 0)
                seconds = seconds + step.seconds
                step.fromGuide = nil -- bei den berechneten Wegen spielt die Herkunft keine Rolle
                if seg.block then step.y, step.l, step.g = nil, nil, nil end
                if step.costLearn >= UNAVAILABLE then step.unavailable = true step.costLearn = 0 end
                steps[#steps + 1] = step
            end
            stock = consumer.stock -- Rest geht an den nächsten Beruf
            out[prof.key] = Finish(steps)
            out[prof.key].seconds = seconds
        end
    end
    return out
end

-- Ergebnis je Modus zwischenspeichern; neu gerechnet wird nur, wenn sich die Eingaben (BT.inputSig: Bestand,
-- Preise, Skills, gelernte Rezepte, Filter) geändert haben. Danach läuft die Rechnung im Hintergrund, bis dahin
-- gilt das alte Ergebnis. So ruckelt das Spiel beim Herstellen nicht.
local plans = { cost = {}, time = {} }
local jobs = {}
local function GetPlans(mode)
    local cache, sig = plans[mode], BT.inputSig
    if not Stale(cache, mode) then return cache end
    dirty[mode] = false
    if BT.syncCompute or cache.sig == nil or not (C_Timer and C_Timer.After and coroutine) then
        local out = ComputePlans(mode)
        out.sig, out.ctx = sig, BT.inputCtx
        plans[mode] = out
        BT.planVersion = BT.planVersion + 1
        return out
    end
    local job = jobs[mode]
    if not job or job.sig ~= sig then
        local co = coroutine.create(function() return ComputePlans(mode, coroutine.yield) end)
        job = { co = co, sig = sig, ctx = BT.inputCtx }
        jobs[mode] = job
        local function Step()
            if jobs[mode] ~= job then return end -- durch eine neuere Rechnung ersetzt
            local ok, result = coroutine.resume(co)
            if not ok then
                jobs[mode] = nil
                if geterrorhandler then geterrorhandler()(result) end
                return
            end
            if coroutine.status(co) == "dead" then
                jobs[mode] = nil
                result.sig, result.ctx = job.sig, job.ctx
                plans[mode] = result
                BT.planVersion = BT.planVersion + 1
                if BT.Update then BT.Update() end
            else
                C_Timer.After(0, Step)
            end
        end
        C_Timer.After(0, Step)
    end
    return cache
end

function BT.ComputeAllRecipes() return GetPlans("cost") end
function BT.ComputeFastest() return GetPlans("time") end

local function OwnGuide(prof, key, title, url, compute)
    if prof.gather or not TEMPLATES[prof.key] then return nil end
    local guide = { key = key, title = title, cheapest = true, url = url }
    return setmetatable(guide, { __index = function(_, k)
        local plan = compute()[prof.key]
        if k == "steps" then return plan and #plan.steps > 0 and plan.steps or prof.steps end
        if k == "plan" then return plan end
    end })
end

function BT.AllRecipesGuide(prof)
    return OwnGuide(prof, "allrecipes", L["Günstigster berechneter Weg"],
        L["Eigener Guide aus allen Rezepten des Berufs (Forever-Spieldaten): je Skillpunkt das billigste Rezept nach Farbe und Chance, mit AH-, Händler-, Lehrer- und Rezeptpreisen; gelernte Rezepte und vorhandene Materialien zählen gratis."],
        BT.ComputeAllRecipes)
end

function BT.FastestGuide(prof)
    return OwnGuide(prof, "fastest", L["Schnellster berechneter Weg"],
        L["Eigener Guide aus allen Rezepten des Berufs: je Skillpunkt das Rezept mit der kürzesten Herstellzeit (Zauberzeit und Chance auf einen Punkt); bei Gleichstand das billigere."],
        BT.ComputeFastest)
end

-- ===== Kosten jedes Guides ab dem aktuellen Skill (für Auswahlmenüs und "Guide für alle") =====
-- Gleiche Rechnung für alle Guides: Material zum Marktpreis, vorhandene Materialien zuerst (über die Berufe
-- nacheinander verteilt), Lernkosten je Rezept einmal, nicht erhältliche Rezepte gezählt statt bezahlt.
local function EvalSteps(steps, profKey, stock, skill)
    local missing, learned, learnCost = 0, {}, 0
    local consumer = NewConsumer(stock)
    consumer.log = BT.costLog -- nur zur Diagnose
    skill = skill or BT.Skill(profKey) or 0
    for _, step in ipairs(steps) do
        local amounts = {}
        if step.lump then
            local part = skill >= step.t and 0 or (skill <= step.f and 1 or (step.t - skill) / (step.t - step.f))
            if part > 0 then for _, r in ipairs(step.r) do amounts[#amounts + 1] = { r[1], math.ceil(r[2] * part) } end end
        else
            local c = 0
            for s = math.max(skill, step.f), step.t - 1 do c = c + StepCrafts(step, s) end
            c = math.ceil(c - 1e-9)
            if c > 0 then
                for _, r in ipairs(step.r) do amounts[#amounts + 1] = { r[1], c * r[2] } end
                if step.out then amounts.out = c * (step.mk or 1) end
            end
        end
        if #amounts > 0 then
            consumer.at = step.f
            for _, a in ipairs(amounts) do consumer.Take(a[1], a[2]) end
            if amounts.out then stock[step.out] = (stock[step.out] or 0) + amounts.out end
            if not step.lump and not learned[step.en] then
                learned[step.en] = true
                local learn = LearnCost(step)
                -- lange Abklingzeit oder nur über Quest: so nicht machbar, wie ein fehlendes Rezept zählen
                if learn >= UNAVAILABLE or (BT.CRAFT_EXCLUDE and BT.CRAFT_EXCLUDE[step.en]) then missing = missing + 1 else learnCost = learnCost + learn end
            end
        end
    end
    return consumer.bought + learnCost, missing, consumer.estimated, learnCost
end

local costCache = {}

-- Ergebnis: [Guide-Schlüssel] = { total, missing, estimated, prof = { [Beruf] = {cost, missing} } },
-- dazu .active = Summe der gerade gewählten Guides.
function BT.GuideCosts()
    -- neu nur, wenn sich Eingaben, eigene Pläne oder die Guide-Auswahl geändert haben
    local key = (BT.syncCompute and tostring(BT.inputSig) or (tostring(BT.inputCtx) .. "|" .. (BT.openStamp or 0)))
        .. "|" .. BT.planVersion .. "|" .. tostring(BT.db.opt.guideAll)
    for profKey, guideKey in pairs(BT.db.opt.guide) do key = key .. "|" .. profKey .. "=" .. guideKey end
    if costCache.key == key then return costCache end
    local out = { key = key }
    local function Run(pickGuide)
        local stock = {}
        for key, count in pairs(BT.totals or {}) do stock[key] = count end
        local res = { total = 0, missing = 0, estimated = false, prof = {} }
        -- zuerst die Berufe, die beim Filter mitzählen (sie bilden die Summe und teilen sich den Bestand),
        -- danach die übrigen nur für das Auswahlmenü des einzelnen Berufs
        local log = BT.costLog
        for pass = 1, 2 do
            BT.costLog = pass == 1 and log or nil
            for _, prof in ipairs(BT.PROFS) do
                local counted = BT.ProfCounted(prof.key)
                -- Sammelberufe zählen nicht (ihr Material sammelt man selbst), wie in der Materialliste
                if not prof.gather and not BT.db.opt.off[prof.key] and counted == (pass == 1) then
                    local guide = pickGuide(prof)
                    local own = pass == 1 and stock or {}
                    if pass == 2 then for key, count in pairs(stock) do own[key] = count end end
                    -- wie die Materialliste: bei mehreren Charakteren jeder mit seinem eigenen Skill
                    local skills = counted and BT.FilteredSkills(prof.key) or { BT.Skill(prof.key) or 0 }
                    local cost, missing, est, learn = 0, 0, false, 0
                    for _, skill in ipairs(skills) do
                        local c, m, e, l = EvalSteps(guide.steps, prof.key, own, skill)
                        cost, missing, est, learn = cost + c, math.max(missing, m), est or e, learn + l
                    end
                    res.prof[prof.key] = { cost = cost, missing = missing, counted = counted, learn = learn }
                    if counted then
                        res.total, res.missing = res.total + cost, res.missing + missing
                        res.learn = (res.learn or 0) + learn
                        res.estimated = res.estimated or est
                    end
                end
            end
        end
        return res
    end
    for _, entry in ipairs(BT.ALL_GUIDES) do
        out[entry.key] = Run(function(prof)
            local list = BT.GuideList(prof)
            for _, guide in ipairs(list) do if guide.key == entry.key then return guide end end
            return list[1]
        end)
    end
    BT.costLog = BT.diagLog -- Diagnose: Einkäufe der aktiven Auswahl je Material
    out.active = Run(BT.ActiveGuide)
    BT.costLog = nil
    costCache = out
    return out
end

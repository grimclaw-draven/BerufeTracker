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

-- Spielt den Materialverbrauch nach: zuerst aus dem Bestand, was fehlt, wird gekauft oder - wenn billiger -
-- aus Rohstoffen hergestellt (auch aus eigenen, z. B. Leinenstoffballen aus vorhandenem Leinenstoff).
-- ranOut[key] = Skill, bei dem der Bestand eines Materials aufgebraucht war.
local function NewConsumer(stock)
    local self = { stock = stock, bought = 0, estimated = false, ranOut = {}, at = 0 }
    local function Unit(key, depth) -- Kosten je Stück im Moment
        if (stock[key] or 0) > 1e-9 then return 0 end
        local price = Market(key) -- ohne echten Preis: Zwischenprodukte herstellen statt Schätzpreis
        local recipe = BT.RECIPES[key]
        if recipe and depth < 5 then
            local sum = 0
            for reagent, amount in pairs(recipe.reag) do sum = sum + Unit(reagent, depth + 1) * amount end
            sum = sum / recipe.makes
            if not price or sum < price then return sum end
        end
        return price or (BaseMarket(key))
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
            if not price or sum / recipe.makes < price then
                for reagent, n in pairs(recipe.reag) do self.Take(reagent, rest * n / recipe.makes, depth + 1) end
                return
            end
        end
        if not price then price, how = BaseMarket(key) end
        if self.log then self.log[key] = (self.log[key] or 0) + rest end
        self.bought = self.bought + rest * price
        if how == "est" or how == "none" then self.estimated = true end
    end
    return self
end
BT.NewConsumer = NewConsumer

-- Stückpreis je Skill: gratis, solange der Bestand laut letzter Simulation reicht (freeUntil[key] = ab diesem
-- Skill aufgebraucht), sonst Markt oder Herstellen. Zwischenergebnisse je Skill zwischengespeichert.
local function MakeTimedPricer(freeUntil)
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
                sum = sum / recipe.makes
                if not price or sum < price then price, how = sum, est and "est" or "craft" end
            end
            if not price then price, how = BaseMarket(key) end
        end
        memo[key] = { price, how }
        return price, how
    end
    return Price
end

-- Verbrauch einer geplanten Route nachspielen. Abschnitte: { cand = {step}, from, to } (Rezept, Chance je Punkt)
-- oder { block = {step, perPoint}, from, to } (Guide-Abschnitt). Setzt seg.cost und seg.est.
local function Simulate(segments, skill, stock, crafts)
    local consumer = NewConsumer(stock)
    for _, seg in ipairs(segments) do
        local step = (seg.block or seg.cand).step
        local before, est = consumer.bought, consumer.estimated
        consumer.estimated = false
        for s = math.max(seg.from, skill), seg.to - 1 do
            consumer.at = s
            local c = seg.block and seg.block.perPoint or crafts(step, s)
            for _, reagent in ipairs(step.r) do consumer.Take(reagent[1], c * reagent[2]) end
            -- hergestellte Zwischenprodukte (z. B. Seidenstoffballen) stehen später wieder zur Verfügung
            if step.out then consumer.stock[step.out] = (consumer.stock[step.out] or 0) + c * (step.mk or 1) end
        end
        seg.cost, seg.est = consumer.bought - before, consumer.estimated
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
                        local below = (e - s) - above
                        local cost = cand.craft * cand.perPoint * (above + BELOW * below)
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
    if cache.stamp == BT.solveStamp then return cache end
    local stock = {}
    for key, count in pairs(BT.totals or {}) do stock[key] = count end
    local out = { stamp = BT.solveStamp }
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
                segments[#segments + 1] = { block = { step = block.cand.step, perPoint = block.cand.perPoint }, from = block.s, to = block.e }
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
                step.c = math.max(1, math.ceil(orig.c * (block.e - block.s) / (orig.t - orig.f)))
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
    local guide = { key = "cheapest", title = L["Günstigster Weg (aus Guides)"], cheapest = true,
        url = L["Eigener Guide aus allen Guides: billigste Rezepte nach AH-, Händler-, Lehrer- und Rezeptpreisen; vorhandene Materialien zählen gratis."] }
    return setmetatable(guide, { __index = function(_, k)
        local plan = BT.ComputeCheapest()[prof.key]
        if k == "steps" then return plan and plan.steps or prof.steps end
        if k == "plan" then return plan end
    end })
end

-- ===== Guide "Günstigster Weg (alle Rezepte)": unabhängig von den anderen Guides =====
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
                l = rec.l, y = rec.y, g = rec.g, su = rec.su or 1, item = rec.item }
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

local MAX_SKILL = 300

-- Billigster Weg Punkt für Punkt. Zwei Arten von Bausteinen:
--  * Rezepte (Zustand = zuletzt benutztes Rezept, Herstellungen je Punkt nach Farbe und Chance)
--  * Abschnitte der anderen Guides (mit deren Herstellungszahlen), Start bei jedem Skill, Ende an einer Abschnittsgrenze.
-- So ist das Ergebnis nie teurer als die beste Zusammensetzung aus den Guides.
local function PlanAll(steps, blocks, skill, Price, withUnavailable, breaks)
    -- Kosten einer Herstellung bei Skill s; ändern sich nur dort, wo ein Material aufgebraucht ist (breaks)
    local craftCache, cacheFrom = {}, nil
    local function Craft(step, s)
        if cacheFrom == nil or s < cacheFrom or (breaks and breaks[s]) then
            if cacheFrom ~= s then craftCache, cacheFrom = {}, s end
        end
        local hit = craftCache[step]
        if hit then return hit end
        local sum = 0
        for _, reagent in ipairs(step.r) do sum = sum + Price(reagent[1], s) * reagent[2] end
        craftCache[step] = sum
        return sum
    end
    local usable = {}
    for _, step in ipairs(steps) do
        local learn, how = LearnCost(step)
        if withUnavailable or learn < UNAVAILABLE then
            usable[#usable + 1] = { step = step, learn = learn, how = how }
        end
    end
    local guideBlocks, ends = {}, {}
    for _, cand in ipairs(blocks) do
        local learn, how = LearnCost(cand.step)
        if withUnavailable or learn < UNAVAILABLE then
            guideBlocks[#guideBlocks + 1] = { step = cand.step, guide = cand.guide, learn = learn, how = how,
                perPoint = cand.step.c / (cand.step.t - cand.step.f) }
            ends[cand.step.f], ends[cand.step.t] = true, true
        end
    end
    local endList = {}
    for p in pairs(ends) do endList[#endList + 1] = p end
    table.sort(endList)

    local function W(a, b) -- gewichtete Zahl an Punkten von a bis b (unter dem Skill zählt kaum)
        local above = math.max(0, b - math.max(a, skill))
        return above + BELOW * ((b - a) - above)
    end

    local arrive = { [1] = 0 } -- billigste Kosten, Skill s zu erreichen
    local viaBlock = {}        -- [s] = {von, Baustein}, wenn s am billigsten über einen Guide-Abschnitt erreicht wird
    local pend = {}
    local cur, stateBest, bestArg, switched = {}, {}, {}, {}
    local reached = 1
    for s = 1, MAX_SKILL - 1 do
        local base = arrive[s]
        if not base then break end
        local weight = s >= skill and 1 or BELOW
        -- Guide-Abschnitte, die bei s beginnen können
        for _, block in ipairs(guideBlocks) do
            local step = block.step
            if step.f <= s and s < step.t then
                for _, e in ipairs(endList) do
                    if e > s and e <= step.t then
                        local total = base + Craft(step, s) * block.perPoint * W(s, e) + block.learn * weight
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
                local switch = base + cand.learn * weight
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
            arrive[nextS], stateBest[nextS] = best, true
        elseif p then
            arrive[nextS], viaBlock[nextS] = p[1], { p[2], p[3] }
        end
        if arrive[nextS] then reached = nextS end
    end
    -- Rückweg: Abschnitte {kind, cand, from, to}
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

local allCache = {}

-- Material und Herstellungen eines Abschnitts (offen = ab dem aktuellen Skill).
local function SegmentCrafts(seg, skill)
    if seg.block then
        local per = seg.block.perPoint
        local above = math.max(0, seg.to - math.max(seg.from, skill))
        return per * (seg.to - seg.from), per * above
    end
    local all, open = 0, 0
    for s = seg.from, seg.to - 1 do
        local c = CraftsPerPoint(seg.cand.step, s)
        all = all + c
        if s >= skill then open = open + c end
    end
    return all, open
end

function BT.ComputeAllRecipes()
    if allCache.stamp == BT.solveStamp then return allCache end
    local stock = {}
    for key, count in pairs(BT.totals or {}) do stock[key] = count end
    local out = { stamp = BT.solveStamp }
    for _, prof in ipairs(BT.PROFS) do
        local templates = TEMPLATES[prof.key]
        if templates and not prof.gather then
            local skill = BT.Skill(prof.key) or 0
            local blocks = Candidates(prof)
            local freeUntil = FreeUntil(stock, nil, MAX_SKILL)
            local segments, reached, consumer
            for _ = 1, 4 do
                local Price = MakeTimedPricer(freeUntil)
                local breaks = {}
                for _, at in pairs(freeUntil) do breaks[at] = true end
                segments, reached = PlanAll(templates, blocks, skill, Price, false, breaks)
                if reached < MAX_SKILL then segments, reached = PlanAll(templates, blocks, skill, Price, true, breaks) end
                local copy = {}
                for key, count in pairs(stock) do copy[key] = count end
                consumer = Simulate(segments, skill, copy, CraftsPerPoint)
                local nextFree, changed = FreeUntil(stock, consumer, MAX_SKILL), false
                for key, value in pairs(nextFree) do if freeUntil[key] ~= value then changed = true end end
                freeUntil = nextFree
                if not changed then break end
            end
            local steps = {}
            for _, seg in ipairs(segments) do
                local src = seg.block or seg.cand
                local all = SegmentCrafts(seg, skill)
                local step = {}
                for k, v in pairs(src.step) do step[k] = v end
                step.f, step.t, step.c = seg.from, seg.to, math.max(1, math.ceil(all - 1e-9))
                step.costMat = seg.cost or 0
                step.costLearn = seg.to > skill and src.learn or 0
                step.learnHow, step.estimated = src.how, seg.est
                step.fromGuide = nil -- bei "alle Rezepte" spielt die Herkunft keine Rolle
                if seg.block then step.y, step.l, step.g = nil, nil, nil end
                if step.costLearn >= UNAVAILABLE then step.unavailable = true step.costLearn = 0 end
                steps[#steps + 1] = step
            end
            stock = consumer.stock -- Rest geht an den nächsten Beruf
            out[prof.key] = Finish(steps)
        end
    end
    allCache = out
    return out
end

function BT.AllRecipesGuide(prof)
    if prof.gather or not TEMPLATES[prof.key] then return nil end
    local guide = { key = "allrecipes", title = L["Günstigster Weg (alle Rezepte)"], cheapest = true,
        url = L["Eigener Guide aus allen Rezepten des Berufs (Forever-Spieldaten): je Skillpunkt das billigste Rezept nach Farbe und Chance, mit AH-, Händler-, Lehrer- und Rezeptpreisen; gelernte Rezepte und vorhandene Materialien zählen gratis."] }
    return setmetatable(guide, { __index = function(_, k)
        local plan = BT.ComputeAllRecipes()[prof.key]
        if k == "steps" then return plan and #plan.steps > 0 and plan.steps or prof.steps end
        if k == "plan" then return plan end
    end })
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
            local c = skill >= step.t and 0 or (skill <= step.f and step.c or math.ceil(step.c * (step.t - skill) / (step.t - step.f)))
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
    if costCache.stamp == BT.solveStamp then return costCache end
    local out = { stamp = BT.solveStamp }
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

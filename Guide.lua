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
            local Price = MakePricer(factor)
            local steps, total, estimated, missing = {}, 0, false, 0
            for _, block in ipairs(blocks) do
                local cand, orig = block.cand, block.cand.step
                local step = {}
                for k, v in pairs(orig) do step[k] = v end
                step.f, step.t = block.s, block.e
                step.c = math.max(1, math.ceil(orig.c * (block.e - block.s) / (orig.t - orig.f)))
                local above = math.max(0, block.e - math.max(block.s, skill))
                local craftCost = 0
                for _, reagent in ipairs(orig.r) do craftCost = craftCost + Price(reagent[1]) * reagent[2] end
                step.costMat = craftCost * cand.perPoint * above
                step.costLearn = above > 0 and cand.learn or 0
                step.learnHow = cand.learnHow
                step.fromGuide = cand.guide
                step.estimated = cand.est
                if step.costLearn >= UNAVAILABLE then step.unavailable = true step.costLearn = 0 end
                total = total + step.costMat + step.costLearn
                estimated = estimated or (cand.est and above > 0)
                steps[#steps + 1] = step
            end
            for key, used in pairs(usage or {}) do
                if stock[key] then stock[key] = math.max(0, stock[key] - used) end
            end
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
local function PlanAll(steps, blocks, skill, Price, withUnavailable)
    local usable = {}
    for _, step in ipairs(steps) do
        local learn, how = LearnCost(step)
        if withUnavailable or learn < UNAVAILABLE then
            local craft, est = 0, false
            for _, reagent in ipairs(step.r) do
                local p, h = Price(reagent[1])
                craft = craft + p * reagent[2]
                est = est or h == "est" or h == "none"
            end
            usable[#usable + 1] = { step = step, learn = learn, how = how, craft = craft, est = est }
        end
    end
    local guideBlocks, ends = {}, {}
    for _, cand in ipairs(blocks) do
        local learn, how = LearnCost(cand.step)
        if withUnavailable or learn < UNAVAILABLE then
            local craft, est = 0, false
            for _, reagent in ipairs(cand.step.r) do
                local p, h = Price(reagent[1])
                craft = craft + p * reagent[2]
                est = est or h == "est" or h == "none"
            end
            guideBlocks[#guideBlocks + 1] = { step = cand.step, guide = cand.guide, learn = learn, how = how, craft = craft, est = est,
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
                        local total = base + block.craft * block.perPoint * W(s, e) + block.learn * weight
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
                local total = start + cand.craft * crafts * weight
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
            local factor = {}
            for key, count in pairs(stock) do if count > 0 then factor[key] = 0 end end
            local segments, reached, usage
            for _ = 1, 3 do
                local Price = MakePricer(factor)
                segments, reached = PlanAll(templates, blocks, skill, Price, false)
                if reached < MAX_SKILL then segments, reached = PlanAll(templates, blocks, skill, Price, true) end
                usage = {}
                for _, seg in ipairs(segments) do
                    local _, open = SegmentCrafts(seg, skill)
                    local step = (seg.block or seg.cand).step
                    for _, reagent in ipairs(step.r) do usage[reagent[1]] = (usage[reagent[1]] or 0) + open * reagent[2] end
                end
                local changed = false
                for key, used in pairs(usage) do
                    local have = stock[key] or 0
                    local f = have == 0 and 1 or (used <= have and 0 or (used - have) / used)
                    if math.abs((factor[key] or 1) - f) > 0.01 then changed = true end
                    factor[key] = f
                end
                if not changed then break end
            end
            local Price = MakePricer(factor)
            local steps, total, estimated, missing = {}, 0, false, 0
            for _, seg in ipairs(segments) do
                local src = seg.block or seg.cand
                local all, open = SegmentCrafts(seg, skill)
                local step = {}
                for k, v in pairs(src.step) do step[k] = v end
                step.f, step.t, step.c = seg.from, seg.to, math.max(1, math.ceil(all - 1e-9))
                local craftCost = 0
                for _, reagent in ipairs(step.r) do craftCost = craftCost + Price(reagent[1]) * reagent[2] end
                step.costMat = craftCost * open
                step.costLearn = seg.to > skill and src.learn or 0
                step.learnHow, step.estimated = src.how, src.est
                step.fromGuide = nil -- bei "alle Rezepte" spielt die Herkunft keine Rolle
                if seg.block then step.y, step.l, step.g = nil, nil, nil end
                if step.costLearn >= UNAVAILABLE then step.unavailable = true step.costLearn = 0 end
                total = total + step.costMat + step.costLearn
                estimated = estimated or (src.est and open > 0)
                steps[#steps + 1] = step
            end
            for key, used in pairs(usage or {}) do
                if stock[key] then stock[key] = math.max(0, stock[key] - used) end
            end
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
local function EvalSteps(steps, profKey, stock, Price)
    local cost, missing, learned, estimated = 0, 0, {}, false
    local skill = BT.Skill(profKey) or 0
    for _, step in ipairs(steps) do
        local amounts = {}
        if step.lump then
            local part = skill >= step.t and 0 or (skill <= step.f and 1 or (step.t - skill) / (step.t - step.f))
            if part > 0 then for _, r in ipairs(step.r) do amounts[#amounts + 1] = { r[1], math.ceil(r[2] * part) } end end
        else
            local c = BT.StepRemaining(step, profKey)
            if c > 0 then for _, r in ipairs(step.r) do amounts[#amounts + 1] = { r[1], c * r[2] } end end
        end
        if #amounts > 0 then
            for _, a in ipairs(amounts) do
                local have = stock[a[1]] or 0
                local free = math.min(have, a[2])
                stock[a[1]] = have - free
                local price, how = Price(a[1])
                cost = cost + (a[2] - free) * price
                estimated = estimated or ((a[2] - free) > 0 and (how == "est" or how == "none"))
            end
            if not step.lump and not learned[step.en] then
                learned[step.en] = true
                local learn = LearnCost(step)
                -- lange Abklingzeit oder nur über Quest: so nicht machbar, wie ein fehlendes Rezept zählen
                if learn >= UNAVAILABLE or (BT.CRAFT_EXCLUDE and BT.CRAFT_EXCLUDE[step.en]) then missing = missing + 1 else cost = cost + learn end
            end
        end
    end
    return cost, missing, estimated
end

local costCache = {}

-- Ergebnis: [Guide-Schlüssel] = { total, missing, estimated, prof = { [Beruf] = {cost, missing} } },
-- dazu .active = Summe der gerade gewählten Guides.
function BT.GuideCosts()
    if costCache.stamp == BT.solveStamp then return costCache end
    local out = { stamp = BT.solveStamp }
    local Price = MakePricer({})
    local function Run(pickGuide)
        local stock = {}
        for key, count in pairs(BT.totals or {}) do stock[key] = count end
        local res = { total = 0, missing = 0, estimated = false, prof = {} }
        -- zuerst die Berufe, die beim Filter mitzählen (sie bilden die Summe und teilen sich den Bestand),
        -- danach die übrigen nur für das Auswahlmenü des einzelnen Berufs
        for pass = 1, 2 do
            for _, prof in ipairs(BT.PROFS) do
                local counted = BT.ProfCounted(prof.key)
                if not prof.gather and not BT.db.opt.off[prof.key] and counted == (pass == 1) then
                    local guide = pickGuide(prof)
                    local own = pass == 1 and stock or {}
                    if pass == 2 then for key, count in pairs(stock) do own[key] = count end end
                    local cost, missing, est = EvalSteps(guide.steps, prof.key, own, Price)
                    res.prof[prof.key] = { cost = cost, missing = missing, counted = counted }
                    if counted then
                        res.total, res.missing = res.total + cost, res.missing + missing
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
    out.active = Run(BT.ActiveGuide)
    costCache = out
    return out
end

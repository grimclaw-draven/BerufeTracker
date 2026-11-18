-- BerufeTracker: Preise aus dem Auktionshaus-Scan und von Händlern.
local _, BT = ...

local BATCH_SIZE, ANSWER_WAIT, MAX_TRIES = 30, 4, 3
local scan
local frame = CreateFrame("Frame")

BT.ID_TO_KEY = {}
for key, item in pairs(BT.ITEMS) do
    if item.id then BT.ID_TO_KEY[item.id] = key end
end
-- Rezept-Items mitscannen (für den Guide "Günstigster Weg")
for slug, recipe in pairs(BT.COSTS and BT.COSTS.recipe or {}) do
    if recipe.id and not BT.ID_TO_KEY[recipe.id] then BT.ID_TO_KEY[recipe.id] = slug end
end
for _, steps in pairs(BT.RECIPE_TEMPLATES or {}) do
    for _, step in ipairs(steps) do
        if step.rc and not BT.ID_TO_KEY[step.rc.id] then BT.ID_TO_KEY[step.rc.id] = step.rc.slug end
    end
end

local function Entry(key)
    local entry = BT.db.prices[key]
    if not entry then
        entry = {}
        BT.db.prices[key] = entry
    end
    return entry
end

-- Günstigster bekannter Preis pro Stück: Kupfer, Quelle, Zeitpunkt.
-- Gleiche Preise wie die Guides: Händler nur mit unbegrenztem Vorrat (gescannt oder aus den Daten), sonst AH.
function BT.Price(key)
    local entry = (BT.db and BT.db.prices[key]) or {}
    local data = BT.COSTS and BT.COSTS.vendor and BT.COSTS.vendor[key]
    local vendor, vendorTs
    if entry.vendor and not entry.vendorLim then vendor, vendorTs = entry.vendor, entry.vendorTs
    elseif data and not data.lim and not entry.vendorLim then vendor = data.p end
    if vendor and (not entry.ah or vendor <= entry.ah) then return vendor, BT.L["Händler"], vendorTs end
    if entry.ah then return entry.ah, BT.L["Auktionshaus"], entry.ahTs end
    return nil
end

function BT.Money(copper)
    copper = math.floor(copper + 0.5)
    local gold, silver = math.floor(copper / 10000), math.floor(copper / 100) % 100
    if gold > 0 then return BT.Format(gold) .. "g " .. silver .. "s" end
    if silver > 0 then return silver .. "s " .. (copper % 100) .. "c" end
    return copper .. "c"
end

local function PriceSorts()
    local order = Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0
    return { { sortOrder = order, reverseSort = false } }
end

local function ItemKey(id)
    local ok, key = pcall(C_AuctionHouse.MakeItemKey, id)
    if ok and type(key) == "table" then return key end
    return { itemID = id, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
end

local function Progress()
    BT.scanText = scan and (BT.L["Scan"] .. " " .. scan.done .. "/" .. scan.total) or nil
    if BT.RefreshUI then BT.RefreshUI() end
end

local function EndScan(reason)
    local result = scan
    scan = nil
    BT.scanText = nil
    if result then
        print("|cffffcc00BerufeTracker:|r " .. BT.L[reason] .. " " .. BT.L["%d von %d Items mit Preis."]:format(result.priced, result.total))
    end
    BT.Update()
end

local Send

local function NextBatch(batch)
    scan.done = scan.done + #batch.ids
    scan.out = nil
    Progress()
    C_Timer.After(0, Send)
end

-- Ohne Antwort oder bei einer fremden Suche: die Anfrage nochmal stellen, nach MAX_TRIES überspringen.
local function Retry(batch)
    if batch.tries >= MAX_TRIES then
        NextBatch(batch)
        return
    end
    batch.tries = batch.tries + 1
    scan.out = nil
    table.insert(scan.batches, 1, batch)
    C_Timer.After(0.5, Send)
end

Send = function()
    if not scan or scan.out then return end
    local batch = scan.batches[1]
    if not batch then
        EndScan("Scan fertig.")
        return
    end
    local ready = C_AuctionHouse.IsThrottledMessageSystemReady
    if ready and not ready() then
        C_Timer.After(0.5, Send)
        return
    end
    table.remove(scan.batches, 1)
    local keys = {}
    for index, id in ipairs(batch.ids) do keys[index] = ItemKey(id) end
    scan.out = batch
    if not pcall(C_AuctionHouse.SearchForItemKeys, keys, PriceSorts()) then
        Retry(batch)
        return
    end
    local sentAt = batch.tries
    C_Timer.After(ANSWER_WAIT, function()
        if scan and scan.out == batch and batch.tries == sentAt then Retry(batch) end
    end)
end

local function ReadBrowse()
    local batch = scan and scan.out
    if not batch then return end
    local ok, list = pcall(C_AuctionHouse.GetBrowseResults)
    list = ok and type(list) == "table" and list or {}
    for _, result in ipairs(list) do
        local id = type(result.itemKey) == "table" and result.itemKey.itemID
        if not batch.set[id] then -- Antwort auf eine andere Suche, z. B. die Favoriten des AH-Fensters
            Retry(batch)
            return
        end
    end
    local now = time()
    for _, result in ipairs(list) do
        local itemID = type(result.itemKey) == "table" and BT.Plain(result.itemKey.itemID)
        local key = itemID and BT.ID_TO_KEY[itemID]
        local price = tonumber(BT.Plain(result.minPrice))
        if key and price and price > 0 then
            local entry = Entry(key)
            if entry.ahTs ~= now or not entry.ah or price < entry.ah then
                if entry.ahTs ~= now then scan.priced = scan.priced + 1 end
                entry.ah, entry.ahTs = price, now
            end
        end
    end
    if C_AuctionHouse.HasFullBrowseResults and not C_AuctionHouse.HasFullBrowseResults() then
        if pcall(C_AuctionHouse.RequestMoreBrowseResults) then return end
    end
    NextBatch(batch)
end

function BT.StartScan()
    if scan then
        EndScan("Scan abgebrochen.")
        return
    end
    if not BT.atAH then
        print("|cffffcc00BerufeTracker:|r " .. BT.L["Öffne zuerst das Auktionshaus."])
        return
    end
    local ids = {}
    for id in pairs(BT.ID_TO_KEY) do ids[#ids + 1] = id end
    table.sort(ids)
    scan = { total = #ids, done = 0, priced = 0, batches = {} }
    for first = 1, #ids, BATCH_SIZE do
        local batch = { ids = {}, set = {}, tries = 1 }
        for index = first, math.min(#ids, first + BATCH_SIZE - 1) do
            batch.ids[#batch.ids + 1] = ids[index]
            batch.set[ids[index]] = true
        end
        scan.batches[#scan.batches + 1] = batch
    end
    Progress()
    Send()
end

local function ScanMerchant()
    if not (GetMerchantNumItems and GetMerchantItemLink and BT.db) then return end
    local now = time()
    for index = 1, GetMerchantNumItems() or 0 do
        local link = BT.Plain(GetMerchantItemLink(index))
        local id = link and tonumber(link:match("item:(%d+)"))
        local key = (id and (BT.ITEM_BY_ID[id] or BT.ID_TO_KEY[id])) or (link and BT.NAME[link:match("%[(.-)%]") or ""])
        if key and (BT.ITEMS[key] or BT.ID_TO_KEY[id or 0] == key) then
            local price, stack, available
            if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
                local info = C_MerchantFrame.GetItemInfo(index)
                if info then price, stack, available = info.price, info.stackCount, info.numAvailable end
            elseif GetMerchantItemInfo then
                local _, _, itemPrice, quantity, numAvailable = GetMerchantItemInfo(index)
                price, stack, available = itemPrice, quantity, numAvailable
            end
            price, stack, available = BT.Plain(price), BT.Plain(stack), BT.Plain(available)
            if type(price) == "number" and price > 0 then
                local entry = Entry(key)
                entry.vendor, entry.vendorTs = price / math.max(1, stack or 1), now
                -- begrenzter Vorrat (z. B. 1×): zählt im Guide "Günstigster Weg" nicht als Händlerquelle
                entry.vendorLim = (type(available) == "number" and available >= 0) or nil
            end
        end
    end
    BT.Update()
end

frame:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_SHOW" then
        BT.atAH = true
        if BT.RefreshUI then BT.RefreshUI() end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        BT.atAH = false
        if scan then EndScan("Scan abgebrochen, Auktionshaus geschlossen.") else BT.RefreshUI() end
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if scan then Send() end
    elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" then
        if scan and scan.out then Retry(scan.out) end
    elseif event == "MERCHANT_SHOW" then
        ScanMerchant()
    else
        ReadBrowse()
    end
end)

for _, event in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_HOUSE_BROWSE_FAILURE", "MERCHANT_SHOW" }) do
    pcall(frame.RegisterEvent, frame, event)
end

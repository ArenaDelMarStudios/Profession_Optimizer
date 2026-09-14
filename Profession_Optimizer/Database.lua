local addonName = ...

--------------------------------------------------
-- Profession Optimizer Database
--------------------------------------------------

local DAY_SECONDS = 86400
local PRICE_HISTORY_LIMIT = 500


local function NormalizeItemName(name)
    if not name then
        return nil
    end

    return string.lower(strtrim(name))
end


local function Median(values)
    if not values or #values == 0 then
        return 0
    end

    table.sort(values)

    local count = #values
    local middle = math.floor(count / 2)

    if count % 2 == 1 then
        return values[middle + 1]
    end

    return math.floor(
        ((values[middle] + values[middle + 1]) / 2) + 0.5
    )
end


local function CalculateWindowStats(history, cutoffTime)
    local values = {}
    local low = nil
    local high = nil

    for _, sample in ipairs(history or {}) do
        local sampleTime = tonumber(sample.time) or 0
        local unitPrice = tonumber(sample.unitPrice) or 0

        if unitPrice > 0 and
           (not cutoffTime or sampleTime >= cutoffTime) then

            table.insert(values, unitPrice)

            if not low or unitPrice < low then
                low = unitPrice
            end

            if not high or unitPrice > high then
                high = unitPrice
            end
        end
    end

    return {
        samples = #values,
        median = Median(values),
        low = low or 0,
        high = high or 0,
    }
end


--------------------------------------------------
-- Main Database
--------------------------------------------------

local function GetDatabase()
    ProfessionOptimizerDB = ProfessionOptimizerDB or {}

    local DB = ProfessionOptimizerDB

    if (tonumber(DB.version) or 0) < 4 then
        DB.version = 4
    end

    DB.characters = DB.characters or {}

    -- Permanent sales history.
    DB.auctionSales = DB.auctionSales or {}
    DB.nextSaleID = DB.nextSaleID or 1

    -- Mail snapshot used to prevent duplicate sale imports.
    DB.mailSnapshots = DB.mailSnapshots or {}

    -- Lifetime gathered-item index.
    DB.itemIndex = DB.itemIndex or {}
    DB.itemNameIndex = DB.itemNameIndex or {}

    -- Persistent local Auction House market history.
    DB.auctionPrices = DB.auctionPrices or {}

    -- Retained for compatibility with earlier development builds.
    DB.ownedAuctions = DB.ownedAuctions or {}
    DB.auctionSalesByID = DB.auctionSalesByID or {}

    for _, sale in ipairs(DB.auctionSales) do
        if sale.saleID and sale.saleID >= DB.nextSaleID then
            DB.nextSaleID = sale.saleID + 1
        end

        if sale.auctionID then
            DB.auctionSalesByID[sale.auctionID] = true
        end
    end

    return DB
end


function PO_GetDatabase()
    return GetDatabase()
end


--------------------------------------------------
-- Character Database
--------------------------------------------------

function PO_GetCharacterDB()
    local DB = GetDatabase()
    local characterKey = UnitGUID("player")

    if not characterKey then
        return nil
    end

    if not DB.characters[characterKey] then
        DB.characters[characterKey] = {
            name = UnitName("player"),
            realm = GetRealmName(),
            professions = {},
            gatheringSessions = {},
            settings = {},
        }
    end

    local characterDB = DB.characters[characterKey]

    characterDB.professions = characterDB.professions or {}
    characterDB.gatheringSessions = characterDB.gatheringSessions or {}
    characterDB.settings = characterDB.settings or {}

    characterDB.name = UnitName("player")
    characterDB.realm = GetRealmName()

    return characterDB
end


--------------------------------------------------
-- Gathered Item Index
--------------------------------------------------

function PO_RegisterGatheredItem(itemData, quantity)
    if not itemData or not itemData.itemID then
        return
    end

    quantity = tonumber(quantity) or 0

    local DB = GetDatabase()
    local itemID = tonumber(itemData.itemID)

    local record = DB.itemIndex[itemID] or {
        itemID = itemID,
        totalGathered = 0,
    }

    record.name = itemData.name or record.name
    record.link = itemData.link or record.link
    record.quality = itemData.quality or record.quality
    record.itemType = itemData.itemType or record.itemType
    record.itemSubType = itemData.itemSubType or record.itemSubType
    record.classID = itemData.classID or record.classID
    record.subclassID = itemData.subclassID or record.subclassID

    if itemData.isCraftingReagent ~= nil then
        record.isCraftingReagent = itemData.isCraftingReagent
    end

    record.vendorPrice = itemData.vendorPrice or record.vendorPrice or 0
    record.totalGathered = (record.totalGathered or 0) + quantity

    DB.itemIndex[itemID] = record

    local normalizedName = NormalizeItemName(record.name)

    if normalizedName then
        DB.itemNameIndex[normalizedName] = itemID
    end
end


function PO_RebuildGatheredItemIndex()
    local DB = GetDatabase()

    DB.itemIndex = {}
    DB.itemNameIndex = {}

    for _, characterDB in pairs(DB.characters) do
        for _, session in ipairs(characterDB.gatheringSessions or {}) do
            for itemID, resource in pairs(session.resources or {}) do
                local id =
                    tonumber(resource.itemID) or
                    tonumber(itemID)

                if id then
                    PO_RegisterGatheredItem(
                        {
                            itemID = id,
                            name = resource.name,
                            link = resource.link,
                            quality = resource.quality,
                            itemType = resource.itemType,
                            itemSubType = resource.itemSubType,
                            classID = resource.classID,
                            subclassID = resource.subclassID,
                            isCraftingReagent = resource.isCraftingReagent,
                            vendorPrice = resource.vendorPrice,
                        },
                        resource.quantity or 0
                    )
                end
            end
        end
    end
end


function PO_ResolveGatheredItemID(itemName)
    local normalizedName = NormalizeItemName(itemName)

    if not normalizedName then
        return nil
    end

    local DB = GetDatabase()
    local itemID = DB.itemNameIndex[normalizedName]

    if itemID then
        return itemID
    end

    for id, item in pairs(DB.itemIndex) do
        if NormalizeItemName(item.name) == normalizedName then
            DB.itemNameIndex[normalizedName] = id
            return id
        end
    end

    return nil
end


function PO_GetGatheredItemRecord(itemID)
    if not itemID then
        return nil
    end

    return GetDatabase().itemIndex[tonumber(itemID)]
end


function PO_GetGatheredItemIndex()
    return GetDatabase().itemIndex
end


--------------------------------------------------
-- Auction House Market Price Storage
--------------------------------------------------

function PO_SaveAuctionMarketPrice(
    itemID,
    unitPrice,
    quantityAvailable,
    marketType
)
    itemID = tonumber(itemID)
    unitPrice = tonumber(unitPrice) or 0
    quantityAvailable = tonumber(quantityAvailable) or 0

    if not itemID or unitPrice <= 0 then
        return nil
    end

    local DB = GetDatabase()

    DB.auctionPrices[itemID] =
        DB.auctionPrices[itemID] or {
            itemID = itemID,
            priceHistory = {},
        }

    local market = DB.auctionPrices[itemID]
    market.priceHistory = market.priceHistory or {}

    local now = time()

    market.currentUnitPrice = unitPrice
    market.quantityAvailable = quantityAvailable
    market.marketType = marketType or "unknown"
    market.lastScan = now

    local lastSample = market.priceHistory[#market.priceHistory]

    -- One stored point represents one manual market observation.
    -- Suppress duplicate event callbacks from the same scan.
    if not lastSample or
       lastSample.unitPrice ~= unitPrice or
       lastSample.quantityAvailable ~= quantityAvailable or
       (now - (lastSample.time or 0)) >= 60 then

        table.insert(
            market.priceHistory,
            {
                time = now,
                unitPrice = unitPrice,
                quantityAvailable = quantityAvailable,
                marketType = market.marketType,
            }
        )
    end

    while #market.priceHistory > PRICE_HISTORY_LIMIT do
        table.remove(market.priceHistory, 1)
    end

    return market
end


function PO_GetAuctionMarketPrice(itemID)
    if not itemID then
        return nil
    end

    return GetDatabase().auctionPrices[tonumber(itemID)]
end


function PO_GetAuctionPriceHistory(itemID)
    local market = PO_GetAuctionMarketPrice(itemID)

    if not market then
        return {}
    end

    return market.priceHistory or {}
end


function PO_GetAuctionMarketStatistics(itemID)
    local market = PO_GetAuctionMarketPrice(itemID)

    local result = {
        itemID = tonumber(itemID),
        currentUnitPrice = 0,
        quantityAvailable = 0,
        marketType = nil,
        lastScan = nil,

        samples24h = 0,
        median24h = 0,
        low24h = 0,
        high24h = 0,

        samples7d = 0,
        median7d = 0,
        low7d = 0,
        high7d = 0,

        samplesAll = 0,
        medianAll = 0,
        lowAll = 0,
        highAll = 0,
    }

    if not market then
        return result
    end

    result.currentUnitPrice =
        tonumber(market.currentUnitPrice) or 0

    result.quantityAvailable =
        tonumber(market.quantityAvailable) or 0

    result.marketType = market.marketType
    result.lastScan = market.lastScan

    local now = time()
    local history = market.priceHistory or {}

    local stats24h =
        CalculateWindowStats(
            history,
            now - DAY_SECONDS
        )

    local stats7d =
        CalculateWindowStats(
            history,
            now - (7 * DAY_SECONDS)
        )

    local statsAll =
        CalculateWindowStats(
            history,
            nil
        )

    result.samples24h = stats24h.samples
    result.median24h = stats24h.median
    result.low24h = stats24h.low
    result.high24h = stats24h.high

    result.samples7d = stats7d.samples
    result.median7d = stats7d.median
    result.low7d = stats7d.low
    result.high7d = stats7d.high

    result.samplesAll = statsAll.samples
    result.medianAll = statsAll.median
    result.lowAll = statsAll.low
    result.highAll = statsAll.high

    return result
end


--------------------------------------------------
-- Sales Storage
--------------------------------------------------

function PO_CreateSaleID()
    local DB = GetDatabase()
    local saleID = DB.nextSaleID

    DB.nextSaleID = saleID + 1

    return saleID
end


function PO_AddAuctionSale(sale)
    if not sale then
        return nil
    end

    local DB = GetDatabase()

    sale.saleID =
        sale.saleID or
        PO_CreateSaleID()

    table.insert(DB.auctionSales, sale)

    return sale
end


function PO_GetAuctionSales()
    return GetDatabase().auctionSales
end


--------------------------------------------------
-- Database Statistics
--------------------------------------------------

function PO_GetDatabaseStats()
    local DB = GetDatabase()

    local characterCount = 0
    local gatheringSessionCount = 0

    for _, characterDB in pairs(DB.characters) do
        characterCount = characterCount + 1
        gatheringSessionCount =
            gatheringSessionCount +
            #(characterDB.gatheringSessions or {})
    end

    local pricedItems = 0
    local priceSamples = 0

    for _, market in pairs(DB.auctionPrices) do
        pricedItems = pricedItems + 1
        priceSamples =
            priceSamples +
            #(market.priceHistory or {})
    end

    return {
        characters = characterCount,
        gatheringSessions = gatheringSessionCount,
        auctionSales = #DB.auctionSales,
        pricedItems = pricedItems,
        priceSamples = priceSamples,
    }
end


--------------------------------------------------
-- Factory Reset API
--------------------------------------------------

function PO_ResetDatabase()
    ProfessionOptimizerDB = {
        version = 4,
        characters = {},
        auctionSales = {},
        nextSaleID = 1,
        mailSnapshots = {},
        itemIndex = {},
        itemNameIndex = {},
        auctionPrices = {},
        ownedAuctions = {},
        auctionSalesByID = {},
    }

    PO_GetCharacterDB()

    if PO_UpdateMainWindow then
        PO_UpdateMainWindow()
    end

    return ProfessionOptimizerDB
end

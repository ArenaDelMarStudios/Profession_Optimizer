local addonName = ...

--------------------------------------------------
-- Profession Optimizer Auction House Price Tracker
--
-- PURPOSE:
--   Track current Auction House market prices for
--   items already known to Profession Optimizer.
--
-- This file does NOT determine completed sales.
-- Completed sales are recorded by Sales.lua from
-- Auction House seller mail invoices.
--------------------------------------------------

local frame =
    CreateFrame("Frame")

local auctionHouseOpen = false
local scanActive = false
local pendingItemID = nil
local pendingItemKey = nil
local scanQueue = {}
local scanPosition = 0
local scanCount = 0
local scanStartedAt = 0

-- 0.80 sec ~= 75 queries/minute, below Blizzard's
-- documented 100-query/minute SendSearchQuery limit.
local QUERY_INTERVAL = 0.80

-- Safety ceiling for a single scan cycle.
local MAX_ITEMS_PER_SCAN = 90


--------------------------------------------------
-- Utility
--------------------------------------------------

local function IsQuerySystemReady()
    if not C_AuctionHouse then
        return false
    end

    if not C_AuctionHouse.IsThrottledMessageSystemReady then
        return true
    end

    return
        C_AuctionHouse.IsThrottledMessageSystemReady()
end


local function FormatMoney(copper)
    if PO_FormatMoney then
        return PO_FormatMoney(copper)
    end

    copper = tonumber(copper) or 0

    local gold =
        math.floor(copper / 10000)

    local silver =
        math.floor((copper % 10000) / 100)

    local remaining =
        math.floor(copper % 100)

    return string.format(
        "%dg %02ds %02dc",
        gold,
        silver,
        remaining
    )
end


--------------------------------------------------
-- Scan Queue
--------------------------------------------------

local function BuildScanQueue()
    wipe(scanQueue)

    local itemIndex =
        PO_GetGatheredItemIndex
        and PO_GetGatheredItemIndex()
        or {}

    for itemID, item in pairs(itemIndex) do
        if itemID and
           item and
           (item.totalGathered or 0) > 0 then

            table.insert(
                scanQueue,
                tonumber(itemID)
            )
        end
    end

    table.sort(scanQueue)

    while #scanQueue > MAX_ITEMS_PER_SCAN do
        table.remove(
            scanQueue
        )
    end
end


local function FinishScan()
    local scanned =
        scanCount

    scanActive = false
    pendingItemID = nil
    pendingItemKey = nil
    scanPosition = 0

    print(
        "Profession Optimizer: Auction House price scan complete. " ..
        scanned ..
        " item(s) processed."
    )

    if PO_UpdateMainWindow then
        PO_UpdateMainWindow()
    end
end


local function ScheduleNextQuery(delay)
    if not scanActive then
        return
    end

    C_Timer.After(
        delay or QUERY_INTERVAL,
        function()
            if PO_AuctionHouseQueryNext then
                PO_AuctionHouseQueryNext()
            end
        end
    )
end


--------------------------------------------------
-- Query Next Item
--------------------------------------------------

function PO_AuctionHouseQueryNext()
    if not scanActive then
        return
    end

    if not auctionHouseOpen then
        print(
            "Profession Optimizer: Auction House closed. Price scan stopped."
        )
        scanActive = false
        pendingItemID = nil
        pendingItemKey = nil
        return
    end

    if pendingItemID then
        return
    end

    if not IsQuerySystemReady() then
        ScheduleNextQuery(
            0.50
        )
        return
    end

    scanPosition =
        scanPosition + 1

    local itemID =
        scanQueue[scanPosition]

    if not itemID then
        FinishScan()
        return
    end

    local itemKey =
        C_AuctionHouse.MakeItemKey(
            itemID
        )

    if not itemKey then
        ScheduleNextQuery()
        return
    end

    pendingItemID =
        itemID

    pendingItemKey =
        itemKey

    local sorts = {
        {
            sortOrder =
                Enum.AuctionHouseSortOrder.Price,
            reverseSort =
                false,
        },
    }

    C_AuctionHouse.SendSearchQuery(
        itemKey,
        sorts,
        false
    )
end


--------------------------------------------------
-- Commodity Results
--------------------------------------------------

local function ProcessCommodityResults(itemID)
    itemID =
        tonumber(itemID)

    if not itemID then
        return
    end

    local resultCount =
        C_AuctionHouse.GetNumCommoditySearchResults(
            itemID
        )

    local lowestUnitPrice = nil

    local totalQuantity =
        C_AuctionHouse.GetCommoditySearchResultsQuantity
        and C_AuctionHouse.GetCommoditySearchResultsQuantity(itemID)
        or 0

    for index = 1, resultCount do
        local result =
            C_AuctionHouse.GetCommoditySearchResultInfo(
                itemID,
                index
            )

        if result then
            local unitPrice =
                tonumber(result.unitPrice) or 0

            if unitPrice > 0 and
               (
                   not lowestUnitPrice or
                   unitPrice < lowestUnitPrice
               ) then

                lowestUnitPrice =
                    unitPrice
            end
        end
    end

    if lowestUnitPrice then
        PO_SaveAuctionMarketPrice(
            itemID,
            lowestUnitPrice,
            totalQuantity,
            "commodity"
        )

        scanCount =
            scanCount + 1
    end
end


--------------------------------------------------
-- Non-Commodity Item Results
--------------------------------------------------

local function ProcessItemResults(itemKey)
    if not itemKey or
       not itemKey.itemID then
        return
    end

    local itemID =
        tonumber(itemKey.itemID)

    local resultCount =
        C_AuctionHouse.GetNumItemSearchResults(
            itemKey
        )

    local lowestUnitPrice = nil
    local totalQuantity = 0

    for index = 1, resultCount do
        local result =
            C_AuctionHouse.GetItemSearchResultInfo(
                itemKey,
                index
            )

        if result then
            local buyoutAmount =
                tonumber(result.buyoutAmount) or 0

            local quantity =
                tonumber(result.quantity) or 1

            if quantity <= 0 then
                quantity = 1
            end

            if buyoutAmount > 0 then
                local unitPrice =
                    math.floor(
                        (buyoutAmount / quantity) + 0.5
                    )

                if unitPrice > 0 and
                   (
                       not lowestUnitPrice or
                       unitPrice < lowestUnitPrice
                   ) then

                    lowestUnitPrice =
                        unitPrice
                end
            end
        end
    end

    if lowestUnitPrice then
        PO_SaveAuctionMarketPrice(
            itemID,
            lowestUnitPrice,
            totalQuantity,
            "item"
        )

        scanCount =
            scanCount + 1
    end
end


--------------------------------------------------
-- Complete Current Query
--------------------------------------------------

local function CompletePendingQuery(itemID)
    if pendingItemID and
       itemID and
       tonumber(itemID) ~= tonumber(pendingItemID) then
        return false
    end

    pendingItemID = nil
    pendingItemKey = nil

    if PO_UpdateMainWindow then
        PO_UpdateMainWindow()
    end

    ScheduleNextQuery()

    return true
end


--------------------------------------------------
-- Public Scan API
--------------------------------------------------

function PO_StartAuctionPriceScan(verbose)
    if not auctionHouseOpen then
        if verbose then
            print(
                "Profession Optimizer: Open the Auction House before scanning prices."
            )
        end
        return
    end

    if PO_GetSetting and
       not PO_GetSetting(
           "trackAuctionPrices"
       ) then

        if verbose then
            print(
                "Profession Optimizer: Auction House price tracking is disabled."
            )
        end

        return
    end

    if scanActive then
        if verbose then
            print(
                "Profession Optimizer: Auction House price scan already running."
            )
        end
        return
    end

    BuildScanQueue()

    if #scanQueue == 0 then
        if verbose then
            print(
                "Profession Optimizer: No gathered items are available to scan."
            )
        end
        return
    end

    scanActive = true
    scanPosition = 0
    scanCount = 0
    scanStartedAt = time()
    pendingItemID = nil
    pendingItemKey = nil

    print(
        "Profession Optimizer: Scanning Auction House prices for " ..
        #scanQueue ..
        " gathered item(s)."
    )

    PO_AuctionHouseQueryNext()
end


function PO_IsAuctionPriceScanActive()
    return scanActive
end


function PO_IsAuctionHouseOpen()
    return auctionHouseOpen
end


function PO_GetAuctionPriceScanProgress()
    return {
        active = scanActive,
        current =
            math.min(
                scanPosition,
                #scanQueue
            ),
        total =
            #scanQueue,
        processed =
            scanCount,
    }
end


--------------------------------------------------
-- Auction House Events
--------------------------------------------------

frame:RegisterEvent(
    "AUCTION_HOUSE_SHOW"
)

frame:RegisterEvent(
    "AUCTION_HOUSE_CLOSED"
)

frame:RegisterEvent(
    "COMMODITY_SEARCH_RESULTS_UPDATED"
)

frame:RegisterEvent(
    "ITEM_SEARCH_RESULTS_UPDATED"
)

frame:RegisterEvent(
    "AUCTION_HOUSE_THROTTLED_SYSTEM_READY"
)

frame:SetScript(
    "OnEvent",
    function(self, event, ...)
        if event == "AUCTION_HOUSE_SHOW" then
            -- Opening the Auction House never starts a scan.
            -- Scanning is triggered only by the Profession Optimizer UI.
            auctionHouseOpen = true

            if PO_UpdateMainWindow then
                PO_UpdateMainWindow()
            end

        elseif event == "AUCTION_HOUSE_CLOSED" then
            auctionHouseOpen = false
            scanActive = false
            pendingItemID = nil
            pendingItemKey = nil

        elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
            local itemID = ...

            if pendingItemID and
               tonumber(itemID) ==
               tonumber(pendingItemID) then

                ProcessCommodityResults(
                    itemID
                )

                CompletePendingQuery(
                    itemID
                )
            end

        elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
            local itemKey = ...

            if itemKey and
               pendingItemID and
               tonumber(itemKey.itemID) ==
               tonumber(pendingItemID) then

                ProcessItemResults(
                    itemKey
                )

                CompletePendingQuery(
                    itemKey.itemID
                )
            end

        elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
            if scanActive and
               not pendingItemID then
                PO_AuctionHouseQueryNext()
            end
        end
    end
)

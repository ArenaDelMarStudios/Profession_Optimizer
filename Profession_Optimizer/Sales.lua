local addonName = ...

--------------------------------------------------
-- Profession Optimizer Sales Tracker
--
-- Sales are recorded from Auction House seller
-- invoices in the mailbox. No auction-ID tracking
-- is used.
--------------------------------------------------

local frame = CreateFrame("Frame")

local mailboxOpen = false
local scanScheduled = false


--------------------------------------------------
-- Utility
--------------------------------------------------

local function NormalizeName(name)
    if not name then
        return ""
    end

    return string.lower(strtrim(name))
end


local function GetCharacterKey()
    return UnitGUID("player")
end


local function BuildInvoiceSignature(invoice)
    return table.concat(
        {
            NormalizeName(invoice.itemName),
            tostring(invoice.grossValue or 0),
            tostring(invoice.deposit or 0),
            tostring(invoice.consignment or 0),
            tostring(invoice.quantity or 0),
            invoice.commerceAuction and "1" or "0",
        },
        "|"
    )
end


--------------------------------------------------
-- Mailbox Invoice Collection
--------------------------------------------------

local function CollectSellerInvoices()
    local observations = {}

    if not GetInboxNumItems or
       not GetInboxInvoiceInfo or
       not GetInboxHeaderInfo then
        return observations
    end

    local numItems =
        GetInboxNumItems()

    for index = 1, numItems do
        local invoiceType,
            itemName,
            playerName,
            bid,
            buyout,
            deposit,
            consignment,
            moneyDelay,
            etaHour,
            etaMin,
            count,
            commerceAuction =
                GetInboxInvoiceInfo(index)

        if invoiceType == "seller" or
           invoiceType == "seller_temp_invoice" then

            local _, _, sender, subject, money, _, daysLeft =
                GetInboxHeaderInfo(index)

            local grossValue =
                tonumber(buyout) or 0

            if grossValue <= 0 then
                grossValue =
                    tonumber(bid) or 0
            end

            local quantity =
                tonumber(count) or 0

            local invoice = {
                mailboxIndex = index,
                invoiceType = invoiceType,
                itemName = itemName or "Unknown Item",
                playerName = playerName,
                sender = sender,
                subject = subject,
                attachedMoney = tonumber(money) or 0,
                bid = tonumber(bid) or 0,
                buyout = tonumber(buyout) or 0,
                grossValue = grossValue,
                deposit = tonumber(deposit) or 0,
                consignment = tonumber(consignment) or 0,
                moneyDelay = tonumber(moneyDelay) or 0,
                etaHour = etaHour,
                etaMin = etaMin,
                quantity = quantity,
                commerceAuction = commerceAuction and true or false,
                daysLeft = tonumber(daysLeft) or 0,
            }

            invoice.signature =
                BuildInvoiceSignature(invoice)

            table.insert(
                observations,
                invoice
            )
        end
    end

    return observations
end


--------------------------------------------------
-- Snapshot Matching
--
-- WoW mail has no persistent public mail ID.
-- We therefore persist the last seller-invoice
-- snapshot and predict how much daysLeft should
-- have decreased since the prior scan. This lets
-- identical sale invoices coexist without being
-- repeatedly imported every time the mailbox is
-- opened.
--------------------------------------------------

local function MatchPreviousSnapshot(
    current,
    previousEntries,
    previousTime,
    usedPrevious
)
    if not previousEntries or
       not previousTime then
        return nil
    end

    local now = time()
    local elapsedDays =
        math.max(
            0,
            (now - previousTime) / 86400
        )

    local bestIndex = nil
    local bestDifference = nil

    for index, previous in ipairs(previousEntries) do
        if not usedPrevious[index] and
           previous.signature == current.signature then

            local expectedDaysLeft =
                math.max(
                    0,
                    (previous.daysLeft or 0) -
                    elapsedDays
                )

            local difference =
                math.abs(
                    (current.daysLeft or 0) -
                    expectedDaysLeft
                )

            if bestDifference == nil or
               difference < bestDifference then
                bestDifference = difference
                bestIndex = index
            end
        end
    end

    -- 0.20 days = 4.8 hours. This is intentionally
    -- tolerant of server-side mailbox rounding.
    if bestIndex and
       bestDifference and
       bestDifference <= 0.20 then

        usedPrevious[bestIndex] = true

        return previousEntries[bestIndex]
    end

    return nil
end


--------------------------------------------------
-- Sale Creation
--------------------------------------------------

local function CreateSaleFromInvoice(invoice)
    if not invoice then
        return nil
    end

    local quantity =
        math.max(
            0,
            invoice.quantity or 0
        )

    local grossValue =
        math.max(
            0,
            invoice.grossValue or 0
        )

    local consignment =
        math.max(
            0,
            invoice.consignment or 0
        )

    local itemID =
        nil

    if PO_ResolveGatheredItemID then
        itemID =
            PO_ResolveGatheredItemID(
                invoice.itemName
            )
    end

    local itemLink =
        nil

    if itemID and PO_GetGatheredItemRecord then
        local gatheredItem =
            PO_GetGatheredItemRecord(
                itemID
            )

        if gatheredItem then
            itemLink =
                gatheredItem.link
        end
    end

    local unitPrice = 0

    if quantity > 0 then
        unitPrice =
            math.floor(
                (grossValue / quantity) + 0.5
            )
    end

    local sale = {
        source = "mail_invoice",
        invoiceType = invoice.invoiceType,

        itemID = itemID,
        itemName = invoice.itemName,
        itemLink = itemLink,

        quantity = quantity,
        unitPrice = unitPrice,

        grossValue = grossValue,
        deposit = invoice.deposit or 0,
        consignment = consignment,

        -- Successful-auction deposits are returned,
        -- so net sale revenue is sale value minus
        -- the AH consignment fee.
        netValue =
            math.max(
                0,
                grossValue - consignment
            ),

        commerceAuction =
            invoice.commerceAuction and true or false,

        buyer = invoice.playerName,

        characterGUID =
            UnitGUID("player"),
        character =
            UnitName("player"),
        realm =
            GetRealmName(),

        soldTime =
            time(),

        mailDaysLeft =
            invoice.daysLeft,

        matchedGathered =
            itemID ~= nil,
    }

    if PO_AddAuctionSale then
        return PO_AddAuctionSale(sale)
    end

    return nil
end


--------------------------------------------------
-- Scan Mailbox
--------------------------------------------------

local function ScanSalesInbox(verbose)
    scanScheduled = false

    if PO_GetSetting and
       not PO_GetSetting(
           "trackSalesHistory"
       ) then

        if verbose then
            print(
                "Profession Optimizer: Sales history tracking is disabled."
            )
        end

        return
    end

    local DB =
        PO_GetDatabase and
        PO_GetDatabase()

    if not DB then
        return
    end

    local characterKey =
        GetCharacterKey()

    if not characterKey then
        return
    end

    local current =
        CollectSellerInvoices()

    DB.mailSnapshots =
        DB.mailSnapshots or {}

    local previousSnapshot =
        DB.mailSnapshots[
            characterKey
        ]

    local previousEntries =
        previousSnapshot
        and previousSnapshot.entries
        or {}

    local previousTime =
        previousSnapshot
        and previousSnapshot.snapshotTime
        or nil

    local usedPrevious = {}
    local newSnapshotEntries = {}
    local newSales = 0

    for _, invoice in ipairs(current) do
        local matchedPrevious =
            MatchPreviousSnapshot(
                invoice,
                previousEntries,
                previousTime,
                usedPrevious
            )

        local saleID =
            matchedPrevious
            and matchedPrevious.saleID
            or nil

        if not matchedPrevious then
            local sale =
                CreateSaleFromInvoice(
                    invoice
                )

            if sale then
                saleID = sale.saleID
                newSales = newSales + 1
            end
        end

        table.insert(
            newSnapshotEntries,
            {
                signature =
                    invoice.signature,
                daysLeft =
                    invoice.daysLeft,
                saleID =
                    saleID,
            }
        )
    end

    DB.mailSnapshots[
        characterKey
    ] = {
        snapshotTime = time(),
        entries = newSnapshotEntries,
    }

    if newSales > 0 then
        print(
            "Profession Optimizer: " ..
            newSales ..
            " new Auction House sale(s) recorded from mail."
        )
    elseif verbose then
        print(
            "Profession Optimizer: Mail scan complete. No new AH sales."
        )
    end

    if PO_UpdateMainWindow then
        PO_UpdateMainWindow()
    end
end


function PO_ScanSalesInbox(verbose)
    if mailboxOpen and CheckInbox then
        CheckInbox()
    end

    C_Timer.After(
        0.25,
        function()
            ScanSalesInbox(verbose)
        end
    )
end


local function ScheduleScan()
    if scanScheduled then
        return
    end

    scanScheduled = true

    C_Timer.After(
        0.35,
        function()
            ScanSalesInbox(false)
        end
    )
end


--------------------------------------------------
-- Sales Query API
--------------------------------------------------

local function GetSaleItemName(sale)
    if sale.itemName then
        return sale.itemName
    end

    if sale.itemID and
       PO_GetGatheredItemRecord then

        local item =
            PO_GetGatheredItemRecord(
                sale.itemID
            )

        if item and item.name then
            return item.name
        end
    end

    if sale.itemLink and
       C_Item and
       C_Item.GetItemInfo then

        local name =
            C_Item.GetItemInfo(
                sale.itemLink
            )

        if name then
            return name
        end
    end

    return "Unknown Item"
end


local function GetNormalizedSaleValues(sale)
    local quantity =
        tonumber(sale.quantity) or 0

    local grossValue =
        tonumber(sale.grossValue)
        or tonumber(sale.totalBuyoutValue)
        or 0

    local consignment =
        tonumber(sale.consignment) or 0

    local netValue =
        tonumber(sale.netValue)

    if netValue == nil then
        netValue =
            math.max(
                0,
                grossValue - consignment
            )
    end

    local unitPrice =
        tonumber(sale.unitPrice)
        or tonumber(sale.unitBuyoutPrice)

    if not unitPrice then
        if quantity > 0 then
            unitPrice =
                math.floor(
                    (grossValue / quantity) + 0.5
                )
        else
            unitPrice = 0
        end
    end

    return
        quantity,
        grossValue,
        netValue,
        unitPrice
end


function PO_GetSalesItemSummary()
    local DB =
        PO_GetDatabase()

    local rowsByKey = {}

    -- Start with every gathered item so unsold gathered
    -- items remain visible in the itemized table.
    for itemID, item in pairs(
        DB.itemIndex or {}
    ) do
        local key =
            "id:" .. tostring(itemID)

        rowsByKey[key] = {
            key = key,
            itemID = itemID,
            itemName =
                item.name or
                ("Item " .. tostring(itemID)),
            itemLink = item.link,
            gathered =
                item.totalGathered or 0,
            sold = 0,
            grossValue = 0,
            netValue = 0,
            saleCount = 0,
        }
    end

    for _, sale in ipairs(
        DB.auctionSales or {}
    ) do
        local itemID =
            sale.itemID

        local itemName =
            GetSaleItemName(sale)

        if not itemID and
           PO_ResolveGatheredItemID then

            itemID =
                PO_ResolveGatheredItemID(
                    itemName
                )
        end

        local key

        if itemID then
            key =
                "id:" .. tostring(itemID)
        else
            key =
                "name:" ..
                NormalizeName(itemName)
        end

        local row =
            rowsByKey[key]

        if not row then
            local gathered = 0
            local itemLink =
                sale.itemLink

            if itemID and
               PO_GetGatheredItemRecord then

                local item =
                    PO_GetGatheredItemRecord(
                        itemID
                    )

                if item then
                    gathered =
                        item.totalGathered or 0
                    itemLink =
                        itemLink or item.link
                end
            end

            row = {
                key = key,
                itemID = itemID,
                itemName = itemName,
                itemLink = itemLink,
                gathered = gathered,
                sold = 0,
                grossValue = 0,
                netValue = 0,
                saleCount = 0,
            }

            rowsByKey[key] = row
        end

        local quantity,
            grossValue,
            netValue =
                GetNormalizedSaleValues(
                    sale
                )

        row.sold =
            row.sold + quantity
        row.grossValue =
            row.grossValue + grossValue
        row.netValue =
            row.netValue + netValue
        row.saleCount =
            row.saleCount + 1
    end

    local rows = {}

    for _, row in pairs(rowsByKey) do
        if row.sold > 0 then
            row.averageUnitPrice =
                math.floor(
                    (row.grossValue / row.sold) + 0.5
                )
        else
            row.averageUnitPrice = 0
        end

        table.insert(rows, row)
    end

    table.sort(
        rows,
        function(a, b)
            return
                string.lower(a.itemName or "") <
                string.lower(b.itemName or "")
        end
    )

    return rows
end


function PO_GetSalesSummaryForItemID(itemID)
    itemID = tonumber(itemID)

    local result = {
        itemID = itemID,
        gathered = 0,
        sold = 0,
        saleCount = 0,
        grossValue = 0,
        netValue = 0,
        averageUnitPrice = 0,
    }

    if not itemID then
        return result
    end

    if PO_GetGatheredItemRecord then
        local item =
            PO_GetGatheredItemRecord(itemID)

        if item then
            result.gathered =
                tonumber(item.totalGathered) or 0
        end
    end

    local DB = PO_GetDatabase()

    for _, sale in ipairs(DB.auctionSales or {}) do
        local saleItemID = tonumber(sale.itemID)

        if not saleItemID and
           sale.itemName and
           PO_ResolveGatheredItemID then

            saleItemID =
                PO_ResolveGatheredItemID(
                    GetSaleItemName(sale)
                )
        end

        if saleItemID == itemID then
            local quantity,
                grossValue,
                netValue =
                    GetNormalizedSaleValues(sale)

            result.sold =
                result.sold +
                (quantity or 0)

            result.saleCount =
                result.saleCount + 1

            result.grossValue =
                result.grossValue +
                (grossValue or 0)

            result.netValue =
                result.netValue +
                (netValue or 0)
        end
    end

    if result.sold > 0 then
        result.averageUnitPrice =
            math.floor(
                (result.grossValue / result.sold) + 0.5
            )
    end

    return result
end


function PO_GetSalesForItem(itemKey)
    local DB =
        PO_GetDatabase()

    local sales = {}

    for _, sale in ipairs(
        DB.auctionSales or {}
    ) do
        local itemName =
            GetSaleItemName(sale)

        local itemID =
            sale.itemID

        if not itemID and
           PO_ResolveGatheredItemID then
            itemID =
                PO_ResolveGatheredItemID(
                    itemName
                )
        end

        local saleKey

        if itemID then
            saleKey =
                "id:" .. tostring(itemID)
        else
            saleKey =
                "name:" ..
                NormalizeName(itemName)
        end

        if saleKey == itemKey then
            table.insert(sales, sale)
        end
    end

    table.sort(
        sales,
        function(a, b)
            return
                (a.soldTime or 0) >
                (b.soldTime or 0)
        end
    )

    return sales
end


function PO_GetSaleValues(sale)
    return GetNormalizedSaleValues(sale)
end


--------------------------------------------------
-- Realized Sales Performance
--
-- Realized Net Gold/Hour =
-- net AH sales matched to gathered items
-- divided by total completed gathering-session hours.
--------------------------------------------------

function PO_GetSalesPerformanceStats()
    local DB = PO_GetDatabase and PO_GetDatabase()

    local stats = {
        saleCount = 0,
        matchedSaleCount = 0,
        unitsSold = 0,
        grossValue = 0,
        netValue = 0,
        matchedNetValue = 0,
        gatheringSeconds = 0,
        realizedNetGoldPerHour = 0,
    }

    if not DB then
        return stats
    end

    for _, sale in ipairs(DB.auctionSales or {}) do
        local quantity, grossValue, netValue =
            GetNormalizedSaleValues(sale)

        stats.saleCount = stats.saleCount + 1
        stats.unitsSold = stats.unitsSold + (quantity or 0)
        stats.grossValue = stats.grossValue + (grossValue or 0)
        stats.netValue = stats.netValue + (netValue or 0)

        local itemID = sale.itemID

        if not itemID and sale.itemName and PO_ResolveGatheredItemID then
            itemID = PO_ResolveGatheredItemID(sale.itemName)
        end

        if itemID then
            stats.matchedSaleCount = stats.matchedSaleCount + 1
            stats.matchedNetValue =
                stats.matchedNetValue + (netValue or 0)
        end
    end

    if PO_GetTotalGatheringDuration then
        stats.gatheringSeconds = PO_GetTotalGatheringDuration()
    end

    if stats.gatheringSeconds > 0 then
        stats.realizedNetGoldPerHour =
            stats.matchedNetValue /
            (stats.gatheringSeconds / 3600)
    end

    return stats
end


--------------------------------------------------
-- Mail Events
--------------------------------------------------

frame:RegisterEvent(
    "MAIL_SHOW"
)

frame:RegisterEvent(
    "MAIL_INBOX_UPDATE"
)

frame:RegisterEvent(
    "MAIL_CLOSED"
)

frame:SetScript(
    "OnEvent",
    function(self, event)
        if event == "MAIL_SHOW" then
            mailboxOpen = true

            if CheckInbox then
                CheckInbox()
            end

            ScheduleScan()

        elseif event == "MAIL_INBOX_UPDATE" then
            ScheduleScan()

        elseif event == "MAIL_CLOSED" then
            mailboxOpen = false
        end
    end
)

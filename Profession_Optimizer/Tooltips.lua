--------------------------------------------------
-- Profession Optimizer Item Tooltips
--------------------------------------------------

local function FormatMoney(copper)
    if PO_FormatMoney then
        return PO_FormatMoney(copper)
    end

    copper = tonumber(copper) or 0

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local remaining = math.floor(copper % 100)

    return string.format(
        "%dg %02ds %02dc",
        gold,
        silver,
        remaining
    )
end


local function FormatAge(timestamp)
    timestamp = tonumber(timestamp)

    if not timestamp then
        return "never"
    end

    local seconds = math.max(0, time() - timestamp)

    if seconds < 60 then
        return "just now"
    end

    if seconds < 3600 then
        return string.format(
            "%dm ago",
            math.floor(seconds / 60)
        )
    end

    if seconds < 86400 then
        return string.format(
            "%dh ago",
            math.floor(seconds / 3600)
        )
    end

    return string.format(
        "%dd ago",
        math.floor(seconds / 86400)
    )
end


local function AddPriceLine(
    tooltip,
    label,
    amount
)
    amount = tonumber(amount) or 0

    if amount <= 0 then
        return
    end

    tooltip:AddDoubleLine(
        label,
        FormatMoney(amount),
        0.90, 0.82, 0.35,
        1.00, 1.00, 1.00
    )
end


local function AddProfessionOptimizerTooltip(
    tooltip,
    data
)
    if not tooltip or
       not data or
       not data.id then
        return
    end

    if PO_GetSetting and
       not PO_GetSetting("showTooltipData") then
        return
    end

    local itemID = tonumber(data.id)

    if not itemID then
        return
    end

    -- TooltipDataProcessor can update the same tooltip more than once.
    -- Prevent duplicate Profession Optimizer blocks for one data instance.
    if tooltip.__POItemID == itemID and
       tooltip.__PODataInstanceID == data.dataInstanceID then
        return
    end

    local market =
        PO_GetAuctionMarketStatistics
        and PO_GetAuctionMarketStatistics(itemID)
        or nil

    local sales =
        PO_GetSalesSummaryForItemID
        and PO_GetSalesSummaryForItemID(itemID)
        or nil

    local hasMarket =
        market and
        (
            (market.currentUnitPrice or 0) > 0 or
            (market.samplesAll or 0) > 0
        )

    local hasTracked =
        sales and
        (
            (sales.gathered or 0) > 0 or
            (sales.sold or 0) > 0
        )

    if not hasMarket and
       not hasTracked then
        return
    end

    tooltip.__POItemID = itemID
    tooltip.__PODataInstanceID = data.dataInstanceID

    tooltip:AddLine(" ")

    tooltip:AddLine(
        "Profession Optimizer",
        0.25, 0.85, 1.00
    )

    if hasMarket then
        AddPriceLine(
            tooltip,
            "Current AH / unit",
            market.currentUnitPrice
        )

        AddPriceLine(
            tooltip,
            "24h median",
            market.median24h
        )

        AddPriceLine(
            tooltip,
            "7d median",
            market.median7d
        )

        AddPriceLine(
            tooltip,
            "All-time median",
            market.medianAll
        )

        if (market.quantityAvailable or 0) > 0 then
            tooltip:AddDoubleLine(
                "Available",
                tostring(market.quantityAvailable),
                0.90, 0.82, 0.35,
                1.00, 1.00, 1.00
            )
        end

        if market.lastScan then
            tooltip:AddDoubleLine(
                "Last manual scan",
                FormatAge(market.lastScan),
                0.90, 0.82, 0.35,
                1.00, 1.00, 1.00
            )
        end
    end

    if hasTracked then
        tooltip:AddDoubleLine(
            "Gathered",
            tostring(sales.gathered or 0),
            0.45, 0.90, 0.55,
            1.00, 1.00, 1.00
        )

        tooltip:AddDoubleLine(
            "Sold",
            tostring(sales.sold or 0),
            0.45, 0.90, 0.55,
            1.00, 1.00, 1.00
        )

        AddPriceLine(
            tooltip,
            "Average sold / unit",
            sales.averageUnitPrice
        )
    end

    tooltip:Show()
end


if TooltipDataProcessor and
   TooltipDataProcessor.AddTooltipPostCall and
   Enum and
   Enum.TooltipDataType then

    TooltipDataProcessor.AddTooltipPostCall(
        Enum.TooltipDataType.Item,
        AddProfessionOptimizerTooltip
    )
end

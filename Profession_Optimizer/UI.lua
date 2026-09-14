--------------------------------------------------
-- Profession Optimizer UI
--------------------------------------------------

local minimapButton = nil
local mainWindow = nil
local minimapAngle = nil
local updateAccumulator = 0

local currentPanel = "session"

local sessionPanel = nil
local gatheringPanel = nil
local salesPanel = nil

local tabButtons = {}

local statusText = nil
local timeText = nil
local itemText = nil
local junkText = nil
local salesGPHText = nil

local junkCheckbox = nil
local salesCheckbox = nil
local auctionCheckbox = nil
local tooltipCheckbox = nil
local sessionButton = nil
local ahScanButton = nil

local gatheringSummaryText = nil
local gatheringRows = {}
local gatheringDetailText = nil
local selectedGatheringIndex = nil

local salesSummaryText = nil
local salesGPHSummaryText = nil
local salesRows = {}
local salesDetailText = nil
local selectedSalesKey = nil


--------------------------------------------------
-- Utility
--------------------------------------------------

local function NormalizeAngle(angle)
    angle = tonumber(angle) or 225

    while angle < 0 do
        angle = angle + 360
    end

    while angle >= 360 do
        angle = angle - 360
    end

    return angle
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


local function FormatDuration(seconds)
    seconds = tonumber(seconds) or 0

    local hours =
        math.floor(seconds / 3600)

    local minutes =
        math.floor(
            (seconds % 3600) / 60
        )

    local remaining =
        seconds % 60

    if hours > 0 then
        return string.format(
            "%02d:%02d:%02d",
            hours,
            minutes,
            remaining
        )
    end

    return string.format(
        "%02d:%02d",
        minutes,
        remaining
    )
end


local function FormatDate(timestamp)
    if not timestamp or
       timestamp <= 0 then
        return "--"
    end

    return date(
        "%b %d %Y %I:%M %p",
        timestamp
    )
end


--------------------------------------------------
-- Minimap Position
--------------------------------------------------

local function UpdateMinimapButtonPosition()
    if not minimapButton or
       not Minimap then
        return
    end

    minimapAngle =
        NormalizeAngle(
            minimapAngle
        )

    local radius =
        Minimap:GetWidth() / 2

    local radians =
        math.rad(
            minimapAngle
        )

    minimapButton:ClearAllPoints()

    minimapButton:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        math.cos(radians) * radius,
        math.sin(radians) * radius
    )
end


local function UpdateMinimapDragPosition()
    if not minimapButton or
       not Minimap then
        return
    end

    local mouseX, mouseY =
        GetCursorPosition()

    local scale =
        UIParent:GetEffectiveScale()

    mouseX = mouseX / scale
    mouseY = mouseY / scale

    local minimapX, minimapY =
        Minimap:GetCenter()

    if not minimapX or
       not minimapY then
        return
    end

    minimapAngle =
        math.deg(
            math.atan2(
                mouseY - minimapY,
                mouseX - minimapX
            )
        )

    minimapAngle =
        NormalizeAngle(
            minimapAngle
        )

    UpdateMinimapButtonPosition()
end


--------------------------------------------------
-- Common Controls
--------------------------------------------------

local function CreateCheckbox(
    parent,
    label,
    settingKey,
    x,
    y
)
    local checkbox =
        CreateFrame(
            "CheckButton",
            nil,
            parent,
            "UICheckButtonTemplate"
        )

    checkbox:SetPoint(
        "TOPLEFT",
        parent,
        "TOPLEFT",
        x,
        y
    )

    checkbox:SetSize(
        24,
        24
    )

    if checkbox.Text then
        checkbox.Text:SetText(
            label
        )
    end

    checkbox:SetChecked(
        PO_GetSetting(
            settingKey
        )
    )

    checkbox:SetScript(
        "OnClick",
        function(self)
            PO_SetSetting(
                settingKey,
                self:GetChecked()
            )

            if PO_UpdateMainWindow then
                PO_UpdateMainWindow()
            end
        end
    )

    return checkbox
end


local function CreatePanel()
    local panel =
        CreateFrame(
            "Frame",
            nil,
            mainWindow
        )

    panel:SetPoint(
        "TOPLEFT",
        mainWindow,
        "TOPLEFT",
        14,
        -88
    )

    panel:SetPoint(
        "BOTTOMRIGHT",
        mainWindow,
        "BOTTOMRIGHT",
        -14,
        14
    )

    return panel
end


--------------------------------------------------
-- Panel Switching
--------------------------------------------------

local function ShowPanel(panelName)
    currentPanel =
        panelName

    sessionPanel:Hide()
    gatheringPanel:Hide()
    salesPanel:Hide()

    if panelName == "session" then
        sessionPanel:Show()

    elseif panelName == "gathering" then
        gatheringPanel:Show()

    elseif panelName == "sales" then
        salesPanel:Show()
    end

    for key, button in pairs(
        tabButtons
    ) do
        button:SetEnabled(
            key ~= panelName
        )
    end

    if PO_UpdateMainWindow then
        PO_UpdateMainWindow()
    end
end


local function CreateTabButton(
    key,
    label,
    x
)
    local button =
        CreateFrame(
            "Button",
            nil,
            mainWindow,
            "UIPanelButtonTemplate"
        )

    button:SetSize(
        185,
        26
    )

    button:SetPoint(
        "TOPLEFT",
        mainWindow,
        "TOPLEFT",
        x,
        -52
    )

    button:SetText(
        label
    )

    button:SetScript(
        "OnClick",
        function()
            ShowPanel(
                key
            )
        end
    )

    tabButtons[key] =
        button
end


--------------------------------------------------
-- Session Panel
--------------------------------------------------

local function CreateSessionPanel()
    sessionPanel =
        CreatePanel()

    statusText =
        sessionPanel:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlight"
        )

    statusText:SetPoint(
        "TOPLEFT",
        sessionPanel,
        "TOPLEFT",
        12,
        -12
    )

    statusText:SetText(
        "Session: INACTIVE"
    )

    timeText =
        sessionPanel:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlightSmall"
        )

    timeText:SetPoint(
        "TOPLEFT",
        statusText,
        "BOTTOMLEFT",
        0,
        -10
    )

    itemText =
        sessionPanel:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlightSmall"
        )

    itemText:SetPoint(
        "TOPLEFT",
        timeText,
        "BOTTOMLEFT",
        0,
        -10
    )

    junkText =
        sessionPanel:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlightSmall"
        )

    junkText:SetPoint(
        "TOPLEFT",
        itemText,
        "BOTTOMLEFT",
        0,
        -10
    )

    salesGPHText =
        sessionPanel:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlightSmall"
        )

    salesGPHText:SetPoint(
        "TOPLEFT",
        junkText,
        "BOTTOMLEFT",
        0,
        -10
    )

    salesGPHText:SetText(
        "Realized Net Gold/Hour: --"
    )

    local optionsTitle =
        sessionPanel:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormal"
        )

    optionsTitle:SetPoint(
        "TOPLEFT",
        sessionPanel,
        "TOPLEFT",
        12,
        -125
    )

    optionsTitle:SetText(
        "Tracking Options"
    )

    junkCheckbox =
        CreateCheckbox(
            sessionPanel,
            "Track Junk Vendor Value",
            "trackJunkVendorValue",
            8,
            -145
        )

    salesCheckbox =
        CreateCheckbox(
            sessionPanel,
            "Track Completed AH Sales from Mail",
            "trackSalesHistory",
            8,
            -177
        )

    auctionCheckbox =
        CreateCheckbox(
            sessionPanel,
            "Track Auction House Market Prices",
            "trackAuctionPrices",
            8,
            -209
        )

    tooltipCheckbox =
        CreateCheckbox(
            sessionPanel,
            "Show Profession Optimizer Item Tooltips",
            "showTooltipData",
            8,
            -241
        )

    local note =
        sessionPanel:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlightSmall"
        )

    note:SetPoint(
        "TOPLEFT",
        sessionPanel,
        "TOPLEFT",
        18,
        -283
    )

    note:SetWidth(
        650
    )

    note:SetJustifyH(
        "LEFT"
    )

    note:SetText(
        "AH price scans are manual only. Open the Auction House, then press Scan AH Prices."
    )

    sessionButton =
        CreateFrame(
            "Button",
            nil,
            sessionPanel,
            "UIPanelButtonTemplate"
        )

    sessionButton:SetSize(
        170,
        30
    )

    sessionButton:SetPoint(
        "BOTTOMLEFT",
        sessionPanel,
        "BOTTOMLEFT",
        12,
        20
    )

    sessionButton:SetText(
        "Start Session"
    )

    sessionButton:SetScript(
        "OnClick",
        function()
            if PO_IsSessionActive and
               PO_IsSessionActive() then

                if PO_StopGatheringSession then
                    PO_StopGatheringSession()
                end
            else
                if PO_StartGatheringSession then
                    PO_StartGatheringSession()
                end
            end

            PO_UpdateMainWindow()
        end
    )

    local mailScanButton =
        CreateFrame(
            "Button",
            nil,
            sessionPanel,
            "UIPanelButtonTemplate"
        )

    mailScanButton:SetSize(
        170,
        30
    )

    mailScanButton:SetPoint(
        "LEFT",
        sessionButton,
        "RIGHT",
        12,
        0
    )

    mailScanButton:SetText(
        "Scan Mailbox Sales"
    )

    mailScanButton:SetScript(
        "OnClick",
        function()
            if PO_ScanSalesInbox then
                PO_ScanSalesInbox(
                    true
                )
            end
        end
    )

    ahScanButton =
        CreateFrame(
            "Button",
            nil,
            sessionPanel,
            "UIPanelButtonTemplate"
        )

    ahScanButton:SetSize(
        170,
        30
    )

    ahScanButton:SetPoint(
        "LEFT",
        mailScanButton,
        "RIGHT",
        12,
        0
    )

    ahScanButton:SetText(
        "Scan AH Prices"
    )

    ahScanButton:SetScript(
        "OnClick",
        function()
            if PO_StartAuctionPriceScan then
                PO_StartAuctionPriceScan(
                    true
                )
            end
        end
    )
end


--------------------------------------------------
-- Gathering History Panel
--------------------------------------------------

local function BuildResourceDetail(session)
    local resources = {}

    for _, resource in pairs(
        session.resources or {}
    ) do
        table.insert(
            resources,
            resource
        )
    end

    table.sort(
        resources,
        function(a, b)
            return
                string.lower(
                    a.name or ""
                ) <
                string.lower(
                    b.name or ""
                )
        end
    )

    local lines = {}

    for index, resource in ipairs(
        resources
    ) do
        if index > 12 then
            table.insert(
                lines,
                "..."
            )
            break
        end

        table.insert(
            lines,
            string.format(
                "%s x%d",
                resource.name or
                    "Unknown",
                resource.quantity or
                    0
            )
        )
    end

    if #lines == 0 then
        return
            "No resources recorded."
    end

    return table.concat(
        lines,
        "\n"
    )
end


local function UpdateGatheringDetail()
    if not selectedGatheringIndex then
        gatheringDetailText:SetText(
            "Select a gathering session."
        )
        return
    end

    local session =
        PO_GetGatheringSession and
        PO_GetGatheringSession(
            selectedGatheringIndex
        )

    if not session then
        gatheringDetailText:SetText(
            "Session unavailable."
        )
        return
    end

    local totalItems =
        session.totalItems or 0

    local junkItems =
        session.totalJunkItems or 0

    local junkValue =
        session.junkVendorValue or 0

    if session.totalItems == nil then
        totalItems = 0
        junkItems = 0
        junkValue = 0

        for _, resource in pairs(
            session.resources or {}
        ) do
            local quantity =
                resource.quantity or 0

            totalItems =
                totalItems + quantity

            if resource.isJunk then
                junkItems =
                    junkItems + quantity

                junkValue =
                    junkValue +
                    (
                        (resource.vendorPrice or 0) *
                        quantity
                    )
            end
        end
    end

    gatheringDetailText:SetText(
        "Date: " ..
        FormatDate(
            session.endTime or
            session.startTime
        ) ..
        "\nCharacter: " ..
        tostring(
            session.character or
            UnitName("player")
        ) ..
        "\nRealm: " ..
        tostring(
            session.realm or
            GetRealmName()
        ) ..
        "\nDuration: " ..
        FormatDuration(
            session.duration or 0
        ) ..
        "\nTotal Items: " ..
        tostring(totalItems) ..
        "\nJunk Items: " ..
        tostring(junkItems) ..
        "\nJunk Value: " ..
        FormatMoney(junkValue) ..
        "\n\nResources\n" ..
        BuildResourceDetail(session)
    )
end


local function CreateGatheringPanel()
    gatheringPanel =
        CreatePanel()

    gatheringSummaryText =
        gatheringPanel:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlight"
        )

    gatheringSummaryText:SetPoint(
        "TOPLEFT",
        gatheringPanel,
        "TOPLEFT",
        8,
        -8
    )

    gatheringSummaryText:SetText(
        "Gathering history"
    )

    for rowIndex = 1, 9 do
        local button =
            CreateFrame(
                "Button",
                nil,
                gatheringPanel,
                "UIPanelButtonTemplate"
            )

        button:SetSize(
            300,
            30
        )

        button:SetPoint(
            "TOPLEFT",
            gatheringPanel,
            "TOPLEFT",
            8,
            -45 -
            ((rowIndex - 1) * 34)
        )

        button:SetText("")

        button:SetScript(
            "OnClick",
            function(self)
                selectedGatheringIndex =
                    self.actualIndex

                UpdateGatheringDetail()
            end
        )

        gatheringRows[rowIndex] =
            button
    end

    gatheringDetailText =
        gatheringPanel:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlightSmall"
        )

    gatheringDetailText:SetPoint(
        "TOPLEFT",
        gatheringPanel,
        "TOPLEFT",
        335,
        -45
    )

    gatheringDetailText:SetWidth(
        380
    )

    gatheringDetailText:SetJustifyH(
        "LEFT"
    )

    gatheringDetailText:SetJustifyV(
        "TOP"
    )

    gatheringDetailText:SetText(
        "Select a gathering session."
    )
end


--------------------------------------------------
-- Sales / Market Panel
--------------------------------------------------

local function CreateSalesRow(rowIndex)
    local row =
        CreateFrame(
            "Button",
            nil,
            salesPanel
        )

    row:SetSize(
        720,
        25
    )

    row:SetPoint(
        "TOPLEFT",
        salesPanel,
        "TOPLEFT",
        8,
        -86 -
        ((rowIndex - 1) * 28)
    )

    row:SetHighlightTexture(
        "Interface\\QuestFrame\\UI-QuestTitleHighlight"
    )

    local widths = {
        170,
        65,
        90,
        55,
        85,
        100,
        100,
    }

    local anchors = {
        0,
        170,
        235,
        325,
        380,
        465,
        565,
    }

    row.columns = {}

    for columnIndex = 1, 7 do
        local text =
            row:CreateFontString(
                nil,
                "OVERLAY",
                "GameFontHighlightSmall"
            )

        text:SetPoint(
            "LEFT",
            row,
            "LEFT",
            anchors[columnIndex],
            0
        )

        text:SetWidth(
            widths[columnIndex]
        )

        text:SetJustifyH(
            columnIndex == 1
            and "LEFT"
            or "RIGHT"
        )

        row.columns[columnIndex] =
            text
    end

    row:SetScript(
        "OnClick",
        function(self)
            selectedSalesKey =
                self.itemKey

            PO_UpdateMainWindow()
        end
    )

    return row
end


local function CreateSalesPanel()
    salesPanel =
        CreatePanel()

    salesSummaryText =
        salesPanel:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlight"
        )

    salesSummaryText:SetPoint(
        "TOPLEFT",
        salesPanel,
        "TOPLEFT",
        8,
        -8
    )

    salesSummaryText:SetText(
        "Sales and market history"
    )

    salesGPHSummaryText =
        salesPanel:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormal"
        )

    salesGPHSummaryText:SetPoint(
        "TOPLEFT",
        salesSummaryText,
        "BOTTOMLEFT",
        0,
        -6
    )

    salesGPHSummaryText:SetText(
        "Realized Net Gold/Hour: --"
    )

    local headings = {
        "Item",
        "Gathered",
        "AH / Unit",
        "Sold",
        "Avg Sold",
        "7d Median",
        "Net",
    }

    local x = {
        8,
        178,
        243,
        333,
        388,
        473,
        573,
    }

    local widths = {
        170,
        65,
        90,
        55,
        85,
        100,
        100,
    }

    for index, heading in ipairs(
        headings
    ) do
        local text =
            salesPanel:CreateFontString(
                nil,
                "OVERLAY",
                "GameFontNormalSmall"
            )

        text:SetPoint(
            "TOPLEFT",
            salesPanel,
            "TOPLEFT",
            x[index],
            -63
        )

        text:SetWidth(
            widths[index]
        )

        text:SetJustifyH(
            index == 1
            and "LEFT"
            or "RIGHT"
        )

        text:SetText(
            heading
        )
    end

    for rowIndex = 1, 9 do
        salesRows[rowIndex] =
            CreateSalesRow(
                rowIndex
            )
    end

    salesDetailText =
        salesPanel:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlightSmall"
        )

    salesDetailText:SetPoint(
        "TOPLEFT",
        salesPanel,
        "TOPLEFT",
        8,
        -348
    )

    salesDetailText:SetWidth(
        710
    )

    salesDetailText:SetJustifyH(
        "LEFT"
    )

    salesDetailText:SetJustifyV(
        "TOP"
    )

    salesDetailText:SetText(
        "Select an item to view market and sale history."
    )
end


--------------------------------------------------
-- Main Window
--------------------------------------------------

local function CreateMainWindow()
    if mainWindow then
        return
    end

    mainWindow =
        CreateFrame(
            "Frame",
            "ProfessionOptimizerMainWindow",
            UIParent,
            "BackdropTemplate"
        )

    mainWindow:SetSize(
        760,
        560
    )

    mainWindow:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        0,
        0
    )

    mainWindow:SetFrameStrata(
        "DIALOG"
    )

    mainWindow:SetClampedToScreen(
        true
    )

    mainWindow:SetMovable(
        true
    )

    mainWindow:EnableMouse(
        true
    )

    mainWindow:RegisterForDrag(
        "LeftButton"
    )

    mainWindow:SetScript(
        "OnDragStart",
        function(self)
            self:StartMoving()
        end
    )

    mainWindow:SetScript(
        "OnDragStop",
        function(self)
            self:StopMovingOrSizing()
        end
    )

    mainWindow:SetBackdrop({
        bgFile =
            "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile =
            "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {
            left = 4,
            right = 4,
            top = 4,
            bottom = 4,
        },
    })

    local title =
        mainWindow:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormalLarge"
        )

    title:SetPoint(
        "TOPLEFT",
        mainWindow,
        "TOPLEFT",
        18,
        -18
    )

    title:SetText(
        "Profession Optimizer"
    )

    local closeButton =
        CreateFrame(
            "Button",
            nil,
            mainWindow,
            "UIPanelCloseButton"
        )

    closeButton:SetPoint(
        "TOPRIGHT",
        mainWindow,
        "TOPRIGHT",
        -4,
        -4
    )

    closeButton:SetScript(
        "OnClick",
        function()
            mainWindow:Hide()
        end
    )

    CreateTabButton(
        "session",
        "Session",
        18
    )

    CreateTabButton(
        "gathering",
        "Gathering History",
        211
    )

    CreateTabButton(
        "sales",
        "Sales / Market",
        404
    )

    CreateSessionPanel()
    CreateGatheringPanel()
    CreateSalesPanel()

    ShowPanel(
        "session"
    )

    mainWindow:Hide()
end


--------------------------------------------------
-- Update Session Panel
--------------------------------------------------

local function UpdateSessionPanel()
    if junkCheckbox then
        junkCheckbox:SetChecked(
            PO_GetSetting(
                "trackJunkVendorValue"
            )
        )
    end

    if salesCheckbox then
        salesCheckbox:SetChecked(
            PO_GetSetting(
                "trackSalesHistory"
            )
        )
    end

    if auctionCheckbox then
        auctionCheckbox:SetChecked(
            PO_GetSetting(
                "trackAuctionPrices"
            )
        )
    end

    if tooltipCheckbox then
        tooltipCheckbox:SetChecked(
            PO_GetSetting(
                "showTooltipData"
            )
        )
    end

    if ahScanButton then
        local progress =
            PO_GetAuctionPriceScanProgress
            and PO_GetAuctionPriceScanProgress()

        if progress and
           progress.active then

            ahScanButton:SetText(
                string.format(
                    "AH Scan %d/%d",
                    progress.current or 0,
                    progress.total or 0
                )
            )
        else
            ahScanButton:SetText(
                "Scan AH Prices"
            )
        end
    end

    local performance =
        PO_GetSalesPerformanceStats
        and PO_GetSalesPerformanceStats()
        or nil

    if salesGPHText then
        if performance and
           (performance.gatheringSeconds or 0) > 0 then

            salesGPHText:SetText(
                "Realized Net Gold/Hour: " ..
                FormatMoney(
                    performance.realizedNetGoldPerHour or 0
                )
            )
        else
            salesGPHText:SetText(
                "Realized Net Gold/Hour: --"
            )
        end
    end

    if not PO_GetSessionSnapshot then
        statusText:SetText(
            "Session: unavailable"
        )
        return
    end

    local snapshot =
        PO_GetSessionSnapshot()

    if snapshot.active then
        statusText:SetText(
            "Session: ACTIVE"
        )

        timeText:SetText(
            "Time: " ..
            FormatDuration(
                snapshot.elapsed
            )
        )

        itemText:SetText(
            "Items: " ..
            tostring(
                snapshot.totalItems or 0
            )
        )

        if PO_GetSetting(
            "trackJunkVendorValue"
        ) then
            junkText:SetText(
                "Junk Value: " ..
                (
                    snapshot.formattedJunkValue
                    or
                    "0g 00s 00c"
                )
            )

            junkText:Show()
        else
            junkText:Hide()
        end

        sessionButton:SetText(
            "Stop Session"
        )
    else
        statusText:SetText(
            "Session: INACTIVE"
        )

        timeText:SetText(
            "Time: --"
        )

        itemText:SetText(
            "Items: --"
        )

        if PO_GetSetting(
            "trackJunkVendorValue"
        ) then
            junkText:SetText(
                "Junk Value: --"
            )

            junkText:Show()
        else
            junkText:Hide()
        end

        sessionButton:SetText(
            "Start Session"
        )
    end
end


--------------------------------------------------
-- Update Gathering Panel
--------------------------------------------------

local function UpdateGatheringPanel()
    local sessions =
        PO_GetGatheringSessions
        and PO_GetGatheringSessions()
        or {}

    local stats =
        PO_GetGatheringHistoryStats
        and PO_GetGatheringHistoryStats()
        or {
            sessions = 0,
            totalItems = 0,
            junkVendorValue = 0,
        }

    gatheringSummaryText:SetText(
        string.format(
            "Sessions: %d    Items: %d    Junk Value: %s",
            stats.sessions or 0,
            stats.totalItems or 0,
            FormatMoney(
                stats.junkVendorValue or 0
            )
        )
    )

    local sessionCount =
        #sessions

    for rowIndex = 1, 9 do
        local actualIndex =
            sessionCount -
            rowIndex +
            1

        local button =
            gatheringRows[rowIndex]

        if actualIndex >= 1 then
            local session =
                sessions[actualIndex]

            button.actualIndex =
                actualIndex

            button:SetText(
                string.format(
                    "%s   |   %d items   |   %s",
                    FormatDate(
                        session.endTime or
                        session.startTime
                    ),
                    session.totalItems or 0,
                    FormatDuration(
                        session.duration or 0
                    )
                )
            )

            button:Show()
        else
            button.actualIndex = nil
            button:Hide()
        end
    end

    if selectedGatheringIndex and
       selectedGatheringIndex > sessionCount then
        selectedGatheringIndex = nil
    end

    UpdateGatheringDetail()
end


--------------------------------------------------
-- Update Sales / Market Detail
--------------------------------------------------

local function UpdateSalesDetail(
    rowsByKey
)
    if not selectedSalesKey then
        salesDetailText:SetText(
            "Select an item to view market and sale history."
        )
        return
    end

    local summary =
        rowsByKey[
            selectedSalesKey
        ]

    if not summary then
        selectedSalesKey = nil

        salesDetailText:SetText(
            "Select an item to view market and sale history."
        )
        return
    end

    local marketStats =
        nil

    if summary.itemID and
       PO_GetAuctionMarketStatistics then

        marketStats =
            PO_GetAuctionMarketStatistics(
                summary.itemID
            )
    end

    local marketPrice =
        marketStats
        and marketStats.currentUnitPrice
        or 0

    local available =
        marketStats
        and marketStats.quantityAvailable
        or 0

    local lastScan =
        marketStats
        and marketStats.lastScan
        or nil

    local marketType =
        marketStats
        and marketStats.marketType
        or "not scanned"

    local sales =
        PO_GetSalesForItem
        and PO_GetSalesForItem(
            selectedSalesKey
        )
        or {}

    local lines = {
        string.format(
            "%s   |   Gathered: %d   Sold: %d",
            summary.itemName or
                "Unknown Item",
            summary.gathered or 0,
            summary.sold or 0
        ),
        string.format(
            "Current AH / Unit: %s   Available: %d   Type: %s   Last Scan: %s",
            marketPrice > 0
            and FormatMoney(marketPrice)
            or "--",
            available,
            tostring(marketType),
            FormatDate(lastScan)
        ),
        string.format(
            "24h Median: %s   Low: %s   High: %s   Samples: %d",
            marketStats and (marketStats.median24h or 0) > 0
                and FormatMoney(marketStats.median24h)
                or "--",
            marketStats and (marketStats.low24h or 0) > 0
                and FormatMoney(marketStats.low24h)
                or "--",
            marketStats and (marketStats.high24h or 0) > 0
                and FormatMoney(marketStats.high24h)
                or "--",
            marketStats and (marketStats.samples24h or 0) or 0
        ),
        string.format(
            "7d Median: %s   Low: %s   High: %s   Samples: %d",
            marketStats and (marketStats.median7d or 0) > 0
                and FormatMoney(marketStats.median7d)
                or "--",
            marketStats and (marketStats.low7d or 0) > 0
                and FormatMoney(marketStats.low7d)
                or "--",
            marketStats and (marketStats.high7d or 0) > 0
                and FormatMoney(marketStats.high7d)
                or "--",
            marketStats and (marketStats.samples7d or 0) or 0
        ),
        string.format(
            "All-Time Median: %s   Low: %s   High: %s   Samples: %d",
            marketStats and (marketStats.medianAll or 0) > 0
                and FormatMoney(marketStats.medianAll)
                or "--",
            marketStats and (marketStats.lowAll or 0) > 0
                and FormatMoney(marketStats.lowAll)
                or "--",
            marketStats and (marketStats.highAll or 0) > 0
                and FormatMoney(marketStats.highAll)
                or "--",
            marketStats and (marketStats.samplesAll or 0) or 0
        ),
        string.format(
            "Average Sold / Unit: %s   Gross: %s   Net: %s",
            FormatMoney(
                summary.averageUnitPrice or 0
            ),
            FormatMoney(
                summary.grossValue or 0
            ),
            FormatMoney(
                summary.netValue or 0
            )
        ),
        "",
        "Recent Sales",
    }

    if #sales == 0 then
        table.insert(
            lines,
            "No sales recorded for this item."
        )
    else
        for index = 1, math.min(
            4,
            #sales
        ) do
            local sale =
                sales[index]

            local quantity,
                grossValue,
                netValue,
                unitPrice =
                    PO_GetSaleValues(
                        sale
                    )

            table.insert(
                lines,
                string.format(
                    "%s   Qty %d   Each %s   Gross %s   Fee %s   Net %s",
                    FormatDate(
                        sale.soldTime
                    ),
                    quantity or 0,
                    FormatMoney(
                        unitPrice or 0
                    ),
                    FormatMoney(
                        grossValue or 0
                    ),
                    FormatMoney(
                        sale.consignment or 0
                    ),
                    FormatMoney(
                        netValue or 0
                    )
                )
            )
        end
    end

    if summary.itemID and
       PO_GetAuctionPriceHistory then

        local history =
            PO_GetAuctionPriceHistory(
                summary.itemID
            )

        if #history > 0 then
            table.insert(
                lines,
                ""
            )

            table.insert(
                lines,
                "Recent AH Price Samples"
            )

            local shown = 0

            for index = #history, 1, -1 do
                local sample =
                    history[index]

                table.insert(
                    lines,
                    string.format(
                        "%s   %s / unit   %d available",
                        FormatDate(
                            sample.time
                        ),
                        FormatMoney(
                            sample.unitPrice or 0
                        ),
                        sample.quantityAvailable or 0
                    )
                )

                shown =
                    shown + 1

                if shown >= 3 then
                    break
                end
            end
        end
    end

    salesDetailText:SetText(
        table.concat(
            lines,
            "\n"
        )
    )
end


--------------------------------------------------
-- Update Sales / Market Table
--------------------------------------------------

local function UpdateSalesPanel()
    local summaries =
        PO_GetSalesItemSummary
        and PO_GetSalesItemSummary()
        or {}

    local totalSales = 0
    local totalUnits = 0
    local totalGross = 0
    local totalNet = 0
    local pricedItems = 0

    local rowsByKey = {}

    for _, summary in ipairs(
        summaries
    ) do
        totalSales =
            totalSales +
            (summary.saleCount or 0)

        totalUnits =
            totalUnits +
            (summary.sold or 0)

        totalGross =
            totalGross +
            (summary.grossValue or 0)

        totalNet =
            totalNet +
            (summary.netValue or 0)

        if summary.itemID and
           PO_GetAuctionMarketPrice and
           PO_GetAuctionMarketPrice(
               summary.itemID
           ) then

            pricedItems =
                pricedItems + 1
        end

        rowsByKey[
            summary.key
        ] =
            summary
    end

    salesSummaryText:SetText(
        string.format(
            "Sales: %d    Units: %d    Priced Items: %d    Gross: %s    Net: %s",
            totalSales,
            totalUnits,
            pricedItems,
            FormatMoney(totalGross),
            FormatMoney(totalNet)
        )
    )

    local performance =
        PO_GetSalesPerformanceStats
        and PO_GetSalesPerformanceStats()
        or nil

    if salesGPHSummaryText then
        if performance and
           (performance.gatheringSeconds or 0) > 0 then

            salesGPHSummaryText:SetText(
                "Realized Net Gold/Hour: " ..
                FormatMoney(
                    performance.realizedNetGoldPerHour or 0
                ) ..
                "   |   Gathering Time: " ..
                FormatDuration(
                    performance.gatheringSeconds or 0
                )
            )
        else
            salesGPHSummaryText:SetText(
                "Realized Net Gold/Hour: --"
            )
        end
    end

    for rowIndex = 1, 9 do
        local summary =
            summaries[rowIndex]

        local row =
            salesRows[rowIndex]

        if summary then
            row.itemKey =
                summary.key

            local market =
                nil

            if summary.itemID and
               PO_GetAuctionMarketPrice then

                market =
                    PO_GetAuctionMarketPrice(
                        summary.itemID
                    )
            end

            row.columns[1]:SetText(
                summary.itemName or
                "Unknown"
            )

            row.columns[2]:SetText(
                tostring(
                    summary.gathered or 0
                )
            )

            row.columns[3]:SetText(
                market and
                market.currentUnitPrice and
                FormatMoney(
                    market.currentUnitPrice
                )
                or "--"
            )

            row.columns[4]:SetText(
                tostring(
                    summary.sold or 0
                )
            )

            row.columns[5]:SetText(
                FormatMoney(
                    summary.averageUnitPrice or 0
                )
            )

            local marketStats =
                summary.itemID and
                PO_GetAuctionMarketStatistics and
                PO_GetAuctionMarketStatistics(
                    summary.itemID
                )
                or nil

            row.columns[6]:SetText(
                marketStats and
                (marketStats.median7d or 0) > 0 and
                FormatMoney(
                    marketStats.median7d
                )
                or "--"
            )

            row.columns[7]:SetText(
                FormatMoney(
                    summary.netValue or 0
                )
            )

            row:Show()
        else
            row.itemKey = nil
            row:Hide()
        end
    end

    UpdateSalesDetail(
        rowsByKey
    )
end


--------------------------------------------------
-- Public UI Update
--------------------------------------------------

function PO_UpdateMainWindow()
    if not mainWindow then
        return
    end

    UpdateSessionPanel()
    UpdateGatheringPanel()
    UpdateSalesPanel()
end


--------------------------------------------------
-- Toggle Window
--------------------------------------------------

local function ToggleMainWindow()
    if not mainWindow then
        CreateMainWindow()
    end

    if mainWindow:IsShown() then
        mainWindow:Hide()
    else
        PO_UpdateMainWindow()
        mainWindow:Show()
    end
end


--------------------------------------------------
-- Minimap Button
--------------------------------------------------

local function CreateMinimapButton()
    if minimapButton or
       not Minimap then
        return
    end

    minimapButton =
        CreateFrame(
            "Button",
            "ProfessionOptimizerMinimapButton",
            Minimap
        )

    minimapButton:SetSize(
        32,
        32
    )

    minimapButton:SetFrameStrata(
        "HIGH"
    )

    minimapButton:SetFrameLevel(
        Minimap:GetFrameLevel() + 10
    )

    minimapButton:EnableMouse(
        true
    )

    minimapButton:RegisterForClicks(
        "LeftButtonUp"
    )

    minimapButton:RegisterForDrag(
        "LeftButton"
    )

    local icon =
        minimapButton:CreateTexture(
            nil,
            "BACKGROUND"
        )

    icon:SetTexture(
        "Interface\\Icons\\INV_Misc_Coin_01"
    )

    icon:SetAllPoints(
        minimapButton
    )

    icon:SetTexCoord(
        0.07,
        0.93,
        0.07,
        0.93
    )

    local border =
        minimapButton:CreateTexture(
            nil,
            "OVERLAY"
        )

    border:SetTexture(
        "Interface\\Minimap\\MiniMap-TrackingBorder"
    )

    border:SetSize(
        54,
        54
    )

    border:SetPoint(
        "TOPLEFT",
        minimapButton,
        "TOPLEFT",
        0,
        0
    )

    local label =
        minimapButton:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormalSmall"
        )

    label:SetPoint(
        "CENTER",
        minimapButton,
        "CENTER",
        0,
        0
    )

    label:SetText(
        "PO"
    )

    minimapButton:SetScript(
        "OnEnter",
        function(self)
            GameTooltip:SetOwner(
                self,
                "ANCHOR_LEFT"
            )

            GameTooltip:SetText(
                "Profession Optimizer"
            )

            GameTooltip:AddLine(
                "Left-click: Open",
                1,
                1,
                1
            )

            GameTooltip:AddLine(
                "Left-drag: Move",
                1,
                1,
                1
            )

            GameTooltip:Show()
        end
    )

    minimapButton:SetScript(
        "OnLeave",
        function()
            GameTooltip:Hide()
        end
    )

    minimapButton:SetScript(
        "OnClick",
        function(self)
            if self.isDragging then
                return
            end

            ToggleMainWindow()
        end
    )

    minimapButton:SetScript(
        "OnDragStart",
        function(self)
            self.isDragging =
                true

            GameTooltip:Hide()

            self:SetScript(
                "OnUpdate",
                function()
                    UpdateMinimapDragPosition()
                end
            )
        end
    )

    minimapButton:SetScript(
        "OnDragStop",
        function(self)
            self:SetScript(
                "OnUpdate",
                nil
            )

            PO_SetSetting(
                "minimapAngle",
                minimapAngle
            )

            C_Timer.After(
                0.05,
                function()
                    if minimapButton then
                        minimapButton.isDragging =
                            false
                    end
                end
            )
        end
    )

    minimapAngle =
        PO_GetSetting(
            "minimapAngle"
        ) or 225

    UpdateMinimapButtonPosition()

    if PO_GetSetting(
        "showMinimapButton"
    ) then
        minimapButton:Show()
    else
        minimapButton:Hide()
    end
end


--------------------------------------------------
-- UI Timer / Loader
--------------------------------------------------

local function UIOnUpdate(
    self,
    elapsed
)
    updateAccumulator =
        updateAccumulator +
        elapsed

    if updateAccumulator < 1 then
        return
    end

    updateAccumulator = 0

    if mainWindow and
       mainWindow:IsShown() then
        PO_UpdateMainWindow()
    end
end


local loader =
    CreateFrame(
        "Frame"
    )

loader:RegisterEvent(
    "PLAYER_LOGIN"
)

loader:SetScript(
    "OnEvent",
    function(self, event)
        if event ~= "PLAYER_LOGIN" then
            return
        end

        CreateMainWindow()
        CreateMinimapButton()
        PO_UpdateMainWindow()

        loader:SetScript(
            "OnUpdate",
            UIOnUpdate
        )

        self:UnregisterEvent(
            "PLAYER_LOGIN"
        )
    end
)

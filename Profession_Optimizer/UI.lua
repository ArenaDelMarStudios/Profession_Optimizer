--------------------------------------------------
-- Profession Optimizer UI
--------------------------------------------------

local minimapButton = nil
local mainWindow = nil

local statusText = nil
local timeText = nil
local itemText = nil
local junkText = nil

local junkCheckbox = nil
local auctionCheckbox = nil
local sessionButton = nil

local updateAccumulator = 0
local minimapAngle = nil


--------------------------------------------------
-- Utility
--------------------------------------------------

local function NormalizeAngle(angle)

    while angle < 0 do
        angle = angle + 360
    end

    while angle >= 360 do
        angle = angle - 360
    end

    return angle
end


--------------------------------------------------
-- Minimap Button Position
--------------------------------------------------

local function UpdateMinimapButtonPosition()

    if not minimapButton or not Minimap then
        return
    end

    minimapAngle = NormalizeAngle(minimapAngle)

    local radius = Minimap:GetWidth() / 2
    local radians = math.rad(minimapAngle)

    local x = math.cos(radians) * radius
    local y = math.sin(radians) * radius

    minimapButton:ClearAllPoints()

    minimapButton:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        x,
        y
    )
end


--------------------------------------------------
-- Minimap Drag
--------------------------------------------------

local function UpdateMinimapDragPosition()

    if not minimapButton or not Minimap then
        return
    end

    local mouseX, mouseY = GetCursorPosition()

    local scale = UIParent:GetEffectiveScale()

    mouseX = mouseX / scale
    mouseY = mouseY / scale

    local minimapX, minimapY = Minimap:GetCenter()

    if not minimapX or not minimapY then
        return
    end

    local dx = mouseX - minimapX
    local dy = mouseY - minimapY

    minimapAngle = math.deg(
        math.atan2(dy, dx)
    )

    minimapAngle = NormalizeAngle(minimapAngle)

    UpdateMinimapButtonPosition()
end


--------------------------------------------------
-- Checkbox Helper
--------------------------------------------------

local function CreateCheckbox(
    parent,
    label,
    settingKey,
    x,
    y
)

    local checkbox = CreateFrame(
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

    checkbox:SetSize(24, 24)

    if checkbox.Text then
        checkbox.Text:SetText(label)
    end

    checkbox:SetChecked(
        PO_GetSetting(settingKey)
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


--------------------------------------------------
-- Create Main Window
--------------------------------------------------

local function CreateMainWindow()

    if mainWindow then
        return
    end

    mainWindow = CreateFrame(
        "Frame",
        "ProfessionOptimizerMainWindow",
        UIParent,
        "BackdropTemplate"
    )

    mainWindow:SetSize(300, 300)

    mainWindow:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        0,
        0
    )

    mainWindow:SetFrameStrata("DIALOG")

    mainWindow:SetClampedToScreen(true)

    mainWindow:SetMovable(true)
    mainWindow:EnableMouse(true)

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


    --------------------------------------------------
    -- Background
    --------------------------------------------------

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


    --------------------------------------------------
    -- Title
    --------------------------------------------------

    local title = mainWindow:CreateFontString(
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


    --------------------------------------------------
    -- Close Button
    --------------------------------------------------

    local closeButton = CreateFrame(
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


    --------------------------------------------------
    -- Separator
    --------------------------------------------------

    local separator = mainWindow:CreateTexture(
        nil,
        "ARTWORK"
    )

    separator:SetColorTexture(
        0.4,
        0.4,
        0.4,
        0.5
    )

    separator:SetPoint(
        "TOPLEFT",
        mainWindow,
        "TOPLEFT",
        18,
        -48
    )

    separator:SetSize(
        260,
        1
    )


    --------------------------------------------------
    -- Status
    --------------------------------------------------

    statusText = mainWindow:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )

    statusText:SetPoint(
        "TOPLEFT",
        separator,
        "BOTTOMLEFT",
        0,
        -15
    )

    statusText:SetText(
        "Session: INACTIVE"
    )


    --------------------------------------------------
    -- Time
    --------------------------------------------------

    timeText = mainWindow:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )

    timeText:SetPoint(
        "TOPLEFT",
        statusText,
        "BOTTOMLEFT",
        0,
        -8
    )

    timeText:SetText(
        "Time: --"
    )


    --------------------------------------------------
    -- Items
    --------------------------------------------------

    itemText = mainWindow:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )

    itemText:SetPoint(
        "TOPLEFT",
        timeText,
        "BOTTOMLEFT",
        0,
        -8
    )

    itemText:SetText(
        "Items: --"
    )


    --------------------------------------------------
    -- Junk Value
    --------------------------------------------------

    junkText = mainWindow:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )

    junkText:SetPoint(
        "TOPLEFT",
        itemText,
        "BOTTOMLEFT",
        0,
        -8
    )

    junkText:SetText(
        "Junk Value: --"
    )


    --------------------------------------------------
    -- Options
    --------------------------------------------------

    local optionsTitle = mainWindow:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )

    optionsTitle:SetPoint(
        "TOPLEFT",
        mainWindow,
        "TOPLEFT",
        18,
        -150
    )

    optionsTitle:SetText(
        "Options"
    )


    --------------------------------------------------
    -- Junk Checkbox
    --------------------------------------------------

    junkCheckbox = CreateCheckbox(
        mainWindow,
        "Track Junk Vendor Value",
        "trackJunkVendorValue",
        14,
        -170
    )


    --------------------------------------------------
    -- AH Checkbox
    --------------------------------------------------

    auctionCheckbox = CreateCheckbox(
        mainWindow,
        "Track Auction House Prices",
        "trackAuctionPrices",
        14,
        -200
    )


    --------------------------------------------------
    -- Session Button
    --------------------------------------------------

    sessionButton = CreateFrame(
        "Button",
        nil,
        mainWindow,
        "UIPanelButtonTemplate"
    )

    sessionButton:SetSize(
        150,
        28
    )

    sessionButton:SetPoint(
        "BOTTOM",
        mainWindow,
        "BOTTOM",
        0,
        25
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

            if PO_UpdateMainWindow then
                PO_UpdateMainWindow()
            end
        end
    )

    mainWindow:Hide()
end


--------------------------------------------------
-- Update Main Window
--------------------------------------------------

function PO_UpdateMainWindow()

    if not mainWindow then
        return
    end

    if junkCheckbox then

        junkCheckbox:SetChecked(
            PO_GetSetting(
                "trackJunkVendorValue"
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

    if not PO_GetSessionSnapshot then

        statusText:SetText(
            "Session: unavailable"
        )

        return
    end

    local snapshot = PO_GetSessionSnapshot()


    --------------------------------------------------
    -- Active
    --------------------------------------------------

    if snapshot.active then

        statusText:SetText(
            "Session: ACTIVE"
        )

        local minutes =
            math.floor(
                snapshot.elapsed / 60
            )

        local seconds =
            snapshot.elapsed % 60

        timeText:SetText(
            string.format(
                "Time: %02d:%02d",
                minutes,
                seconds
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


    --------------------------------------------------
    -- Inactive
    --------------------------------------------------

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
-- Create Minimap Button
--------------------------------------------------

local function CreateMinimapButton()

    if minimapButton then
        return
    end

    if not Minimap then

        print(
            "Profession Optimizer: Minimap unavailable."
        )

        return
    end

    minimapButton = CreateFrame(
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

    minimapButton:EnableMouse(true)

    minimapButton:RegisterForClicks(
        "LeftButtonUp"
    )

    minimapButton:RegisterForDrag(
        "LeftButton"
    )


    --------------------------------------------------
    -- Icon
    --------------------------------------------------

    local icon = minimapButton:CreateTexture(
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


    --------------------------------------------------
    -- Border
    --------------------------------------------------

    local border = minimapButton:CreateTexture(
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


    --------------------------------------------------
    -- PO Label
    --------------------------------------------------

    local label = minimapButton:CreateFontString(
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

    label:SetText("PO")


    --------------------------------------------------
    -- Tooltip
    --------------------------------------------------

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


    --------------------------------------------------
    -- Click
    --------------------------------------------------

    minimapButton:SetScript(
        "OnClick",
        function(self)

            if self.isDragging then
                return
            end

            ToggleMainWindow()
        end
    )


    --------------------------------------------------
    -- Drag Start
    --------------------------------------------------

    minimapButton:SetScript(
        "OnDragStart",
        function(self)

            self.isDragging = true

            GameTooltip:Hide()

            self:SetScript(
                "OnUpdate",
                function()
                    UpdateMinimapDragPosition()
                end
            )
        end
    )


    --------------------------------------------------
    -- Drag Stop
    --------------------------------------------------

    minimapButton:SetScript(
        "OnDragStop",
        function(self)

            self:SetScript(
                "OnUpdate",
                nil
            )

            --------------------------------------------------
            -- Save Minimap Position
            --------------------------------------------------

            PO_SetSetting(
                "minimapAngle",
                minimapAngle
            )

            C_Timer.After(
                0.05,
                function()

                    if minimapButton then
                        minimapButton.isDragging = false
                    end
                end
            )
        end
    )


    --------------------------------------------------
    -- Initial Position
    --------------------------------------------------

    minimapAngle =
        PO_GetSetting("minimapAngle")
        or 225

    UpdateMinimapButtonPosition()

    minimapButton:Show()

    print(
        "Profession Optimizer: Minimap button created."
    )
end


--------------------------------------------------
-- UI Timer
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


--------------------------------------------------
-- Loader
--------------------------------------------------

local loader = CreateFrame(
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

        print(
            "Profession Optimizer: Initializing UI..."
        )

        CreateMainWindow()

        CreateMinimapButton()

        PO_UpdateMainWindow()

        loader:SetScript(
            "OnUpdate",
            UIOnUpdate
        )

        print(
            "Profession Optimizer: UI loaded."
        )

        self:UnregisterEvent(
            "PLAYER_LOGIN"
        )
    end
)
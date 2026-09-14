--------------------------------------------------
-- Profession Optimizer Settings
--------------------------------------------------

local defaultSettings = {
    trackJunkVendorValue = true,
    trackSalesHistory = true,
    trackAuctionPrices = true,
    showTooltipData = true,
    showMinimapButton = true,
    minimapAngle = 225,
}

local function CopyDefaults(target)
    for key, value in pairs(defaultSettings) do
        if target[key] == nil then
            target[key] = value
        end
    end

    -- Obsolete from v0.1.3.
    -- Auction House scanning is manual UI-only.
    target.autoScanAuctionPrices = nil
end

function PO_GetSettings()
    local characterDB = PO_GetCharacterDB()

    if not characterDB then
        return defaultSettings
    end

    characterDB.settings = characterDB.settings or {}
    CopyDefaults(characterDB.settings)

    return characterDB.settings
end

function PO_GetSetting(key)
    local settings = PO_GetSettings()

    if settings[key] ~= nil then
        return settings[key]
    end

    return defaultSettings[key]
end

function PO_SetSetting(key, value)
    local settings = PO_GetSettings()
    settings[key] = value
    return value
end

function PO_ToggleSetting(key)
    local value = not PO_GetSetting(key)
    PO_SetSetting(key, value)
    return value
end

function PO_ResetSettings()
    local characterDB = PO_GetCharacterDB()

    if not characterDB then
        return
    end

    characterDB.settings = {}
    CopyDefaults(characterDB.settings)

    if PO_UpdateMainWindow then
        PO_UpdateMainWindow()
    end
end

function PO_ShowSettings()
    local settings = PO_GetSettings()

    print("Profession Optimizer Settings")
    print("-----------------------------")
    print("Track Junk Vendor Value: " .. tostring(settings.trackJunkVendorValue))
    print("Track Sales History: " .. tostring(settings.trackSalesHistory))
    print("Track Auction Prices: " .. tostring(settings.trackAuctionPrices))
    print("Show Tooltip Data: " .. tostring(settings.showTooltipData))
    print("Auction House Scanning: Manual UI only")
end

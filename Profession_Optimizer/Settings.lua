--------------------------------------------------
-- Profession Optimizer Settings
--------------------------------------------------

local defaultSettings = {
    trackJunkVendorValue = true,
    trackAuctionPrices = false,
    showMinimapButton = true,

    -- Minimap button position in degrees
    minimapAngle = 225,
}


--------------------------------------------------
-- Get Settings Table
--------------------------------------------------

function PO_GetSettings()

    local characterDB =
        PO_GetCharacterDB()

    if not characterDB then
        return nil
    end

    characterDB.settings =
        characterDB.settings or {}

    --------------------------------------------------
    -- Apply Defaults
    --------------------------------------------------

    for key, defaultValue in pairs(
        defaultSettings
    ) do

        if characterDB.settings[key] == nil then

            characterDB.settings[key] =
                defaultValue
        end
    end

    return characterDB.settings
end


--------------------------------------------------
-- Get Individual Setting
--------------------------------------------------

function PO_GetSetting(key)

    local settings =
        PO_GetSettings()

    if not settings then

        return defaultSettings[key]
    end

    if settings[key] == nil then

        return defaultSettings[key]
    end

    return settings[key]
end


--------------------------------------------------
-- Set Individual Setting
--------------------------------------------------

function PO_SetSetting(
    key,
    value
)

    local settings =
        PO_GetSettings()

    if not settings then
        return false
    end

    --------------------------------------------------
    -- Only Allow Known Settings
    --------------------------------------------------

    if defaultSettings[key] == nil then

        print(
            "Profession Optimizer: Unknown setting: " ..
            tostring(key)
        )

        return false
    end

    settings[key] = value

    return true
end


--------------------------------------------------
-- Toggle Setting
--------------------------------------------------

function PO_ToggleSetting(key)

    local currentValue =
        PO_GetSetting(key)

    if currentValue == nil then
        return nil
    end

    local newValue =
        not currentValue

    if PO_SetSetting(
        key,
        newValue
    ) then

        return newValue
    end

    return nil
end


--------------------------------------------------
-- Reset Settings
--------------------------------------------------

function PO_ResetSettings()

    local characterDB =
        PO_GetCharacterDB()

    if not characterDB then
        return false
    end

    characterDB.settings = {}

    for key, defaultValue in pairs(
        defaultSettings
    ) do

        characterDB.settings[key] =
            defaultValue
    end

    print(
        "Profession Optimizer: Settings reset to defaults."
    )

    --------------------------------------------------
    -- Refresh Current UI
    --------------------------------------------------

    if PO_UpdateMainWindow then

        PO_UpdateMainWindow()
    end

    return true
end


--------------------------------------------------
-- Settings Status
--------------------------------------------------

function PO_ShowSettings()

    local settings =
        PO_GetSettings()

    if not settings then

        print(
            "Profession Optimizer: Settings unavailable."
        )

        return
    end

    print(
        "Profession Optimizer Settings"
    )

    print(
        "-----------------------------"
    )

    --------------------------------------------------
    -- Junk Vendor Value
    --------------------------------------------------

    print(
        "Junk Vendor Value: " ..
        (
            settings.trackJunkVendorValue
            and "ON"
            or "OFF"
        )
    )

    --------------------------------------------------
    -- Auction House Prices
    --------------------------------------------------

    print(
        "Auction House Prices: " ..
        (
            settings.trackAuctionPrices
            and "ON"
            or "OFF"
        )
    )

    --------------------------------------------------
    -- Minimap Button
    --------------------------------------------------

    print(
        "Minimap Button: " ..
        (
            settings.showMinimapButton
            and "ON"
            or "OFF"
        )
    )

    --------------------------------------------------
    -- Minimap Position
    --------------------------------------------------

    print(
        "Minimap Angle: " ..
        tostring(
            settings.minimapAngle or 225
        )
    )
end
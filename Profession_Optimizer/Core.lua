local addonName = ...

local frame = CreateFrame("Frame")

local sessionActive = false
local sessionStartTime = nil


--------------------------------------------------
-- Utility
--------------------------------------------------

local function GetCharacterDB()
    return PO_GetCharacterDB()
end


local function GetElapsedTime()

    if not sessionStartTime then
        return 0
    end

    return math.floor(
        GetTime() - sessionStartTime
    )
end


--------------------------------------------------
-- Money Formatting
--------------------------------------------------

local function FormatMoney(copper)

    copper = tonumber(copper) or 0
    copper = math.floor(copper)

    local gold =
        math.floor(copper / 10000)

    local silver =
        math.floor((copper % 10000) / 100)

    local copperRemaining =
        copper % 100

    return string.format(
        "%dg %02ds %02dc",
        gold,
        silver,
        copperRemaining
    )
end


--------------------------------------------------
-- Settings Helper
--------------------------------------------------

local function GetSetting(key, fallback)

    if PO_GetSetting then

        local value =
            PO_GetSetting(key)

        if value ~= nil then
            return value
        end
    end

    return fallback
end


--------------------------------------------------
-- Session Value
--------------------------------------------------

local function CalculateSessionValue(session)

    local totalItems = 0
    local totalJunkItems = 0
    local totalJunkVendorValue = 0

    if not session or
       not session.resources then

        return
            totalItems,
            totalJunkItems,
            totalJunkVendorValue
    end

    for _, resource in pairs(
        session.resources
    ) do

        local quantity =
            resource.quantity or 0

        totalItems =
            totalItems + quantity

        if resource.isJunk then

            totalJunkItems =
                totalJunkItems +
                quantity

            totalJunkVendorValue =
                totalJunkVendorValue +
                (
                    (resource.vendorPrice or 0) *
                    quantity
                )
        end
    end

    return
        totalItems,
        totalJunkItems,
        totalJunkVendorValue
end


--------------------------------------------------
-- Chat Input Cleanup
--------------------------------------------------

local function ClearChatInput()

    C_Timer.After(
        0,
        function()

            local editBox =
                ChatEdit_ChooseBoxForSend()

            if editBox then

                editBox:SetText("")

                ChatEdit_DeactivateChat(
                    editBox
                )
            end
        end
    )
end


--------------------------------------------------
-- Item Classification
--------------------------------------------------

local function GetItemData(
    itemID,
    itemLink,
    itemName
)

    local itemQuality
    local itemType
    local itemSubType
    local classID
    local subclassID
    local isCraftingReagent
    local vendorPrice
    local isJunk

    local itemInfo = {
        C_Item.GetItemInfo(itemID)
    }

    if itemInfo then

        itemName =
            itemName or itemInfo[1]

        --------------------------------------------------
        -- ItemInfo return values
        --
        -- 3  = itemQuality
        -- 6  = itemType
        -- 7  = itemSubType
        -- 11 = vendor sell price
        -- 12 = classID
        -- 13 = subclassID
        -- 17 = isCraftingReagent
        --------------------------------------------------

        itemQuality =
            itemInfo[3]

        itemType =
            itemInfo[6]

        itemSubType =
            itemInfo[7]

        vendorPrice =
            itemInfo[11]

        classID =
            itemInfo[12]

        subclassID =
            itemInfo[13]

        isCraftingReagent =
            itemInfo[17]

        isJunk =
            itemQuality ==
            Enum.ItemQuality.Poor
    end

    return {
        itemID = itemID,

        name =
            itemName or
            "Unknown Item",

        link =
            itemLink,

        quality =
            itemQuality,

        isJunk =
            isJunk or false,

        itemType =
            itemType or
            "Unknown",

        itemSubType =
            itemSubType or
            "Unknown",

        classID =
            classID,

        subclassID =
            subclassID,

        isCraftingReagent =
            isCraftingReagent or false,

        vendorPrice =
            vendorPrice or 0,
    }
end


--------------------------------------------------
-- Start Session
--------------------------------------------------

local function StartGatheringSession()

    local characterDB =
        GetCharacterDB()

    if not characterDB then

        print(
            "Profession Optimizer: Character database unavailable."
        )

        return
    end

    if sessionActive then

        print(
            "Profession Optimizer: Gathering session already running."
        )

        return
    end

    characterDB.gatheringSessions =
        characterDB.gatheringSessions or {}

    sessionActive = true
    sessionStartTime = GetTime()

    characterDB.currentGatheringSession = {
        startTime = time(),
        resources = {},
    }

    print(
        "Profession Optimizer: Gathering session STARTED."
    )

    if PO_UpdateMainWindow then
        PO_UpdateMainWindow()
    end
end


--------------------------------------------------
-- Stop Session
--------------------------------------------------

local function StopGatheringSession()

    local characterDB =
        GetCharacterDB()

    if not sessionActive then

        print(
            "Profession Optimizer: No gathering session is running."
        )

        return
    end

    local elapsed =
        GetElapsedTime()

    sessionActive = false
    sessionStartTime = nil

    if characterDB and
       characterDB.currentGatheringSession then

        characterDB.currentGatheringSession.duration =
            elapsed

        characterDB.currentGatheringSession.endTime =
            time()

        characterDB.gatheringSessions =
            characterDB.gatheringSessions or {}

        table.insert(
            characterDB.gatheringSessions,
            characterDB.currentGatheringSession
        )

        characterDB.currentGatheringSession =
            nil
    end

    print(
        "Profession Optimizer: Gathering session STOPPED."
    )

    print(
        "Profession Optimizer: Duration: " ..
        string.format(
            "%02d:%02d",
            math.floor(elapsed / 60),
            elapsed % 60
        )
    )

    if PO_UpdateMainWindow then
        PO_UpdateMainWindow()
    end
end


--------------------------------------------------
-- Public Session API
--------------------------------------------------

function PO_IsSessionActive()
    return sessionActive
end


PO_StartGatheringSession =
    StartGatheringSession


PO_StopGatheringSession =
    StopGatheringSession


--------------------------------------------------
-- Session Snapshot
--------------------------------------------------

function PO_GetSessionSnapshot()

    local snapshot = {
        active = sessionActive,
        elapsed = 0,

        totalItems = 0,
        totalJunkItems = 0,

        junkVendorValue = 0,

        formattedJunkValue =
            FormatMoney(0),
    }

    if not sessionActive then
        return snapshot
    end

    local characterDB =
        GetCharacterDB()

    if not characterDB or
       not characterDB.currentGatheringSession then

        return snapshot
    end

    local totalItems
    local totalJunkItems
    local totalJunkVendorValue

    totalItems,
    totalJunkItems,
    totalJunkVendorValue =
        CalculateSessionValue(
            characterDB.currentGatheringSession
        )

    snapshot.elapsed =
        GetElapsedTime()

    snapshot.totalItems =
        totalItems

    snapshot.totalJunkItems =
        totalJunkItems

    snapshot.junkVendorValue =
        totalJunkVendorValue

    snapshot.formattedJunkValue =
        FormatMoney(
            totalJunkVendorValue
        )

    return snapshot
end


--------------------------------------------------
-- Loot Processing
--------------------------------------------------

local function RecordLoot()

    if not sessionActive then
        return
    end

    local characterDB =
        GetCharacterDB()

    if not characterDB then
        return
    end

    local session =
        characterDB.currentGatheringSession

    if not session then
        return
    end

    session.resources =
        session.resources or {}

    local numLootItems =
        GetNumLootItems()

    for slot = 1, numLootItems do

        local lootSlotType =
            GetLootSlotType(slot)

        if lootSlotType ==
           Enum.LootSlotType.Item then

            local itemLink =
                GetLootSlotLink(slot)

            local texture
            local itemName
            local quantity

            texture,
            itemName,
            quantity =
                GetLootSlotInfo(slot)

            if itemLink and
               itemName and
               quantity and
               quantity > 0 then

                local itemID =
                    C_Item.GetItemIDForItemInfo(
                        itemLink
                    )

                if itemID then

                    local itemData =
                        GetItemData(
                            itemID,
                            itemLink,
                            itemName
                        )

                    --------------------------------------------------
                    -- Create Item Record
                    --------------------------------------------------

                    if not session.resources[itemID] then

                        session.resources[itemID] =
                            itemData

                        session.resources[itemID].quantity =
                            0
                    end

                    --------------------------------------------------
                    -- Add Quantity
                    --------------------------------------------------

                    session.resources[itemID].quantity =
                        session.resources[itemID].quantity +
                        quantity

                    --------------------------------------------------
                    -- Display
                    --------------------------------------------------

                    print(
                        "Profession Optimizer: +" ..
                        quantity ..
                        " " ..
                        itemName
                    )

                    print(
                        "  Type: " ..
                        tostring(
                            itemData.itemType
                        ) ..
                        " / " ..
                        tostring(
                            itemData.itemSubType
                        )
                    )

                    --------------------------------------------------
                    -- Junk Vendor Value
                    --------------------------------------------------

                    if itemData.isJunk and
                       GetSetting(
                           "trackJunkVendorValue",
                           true
                       ) then

                        print(
                            "  Junk Vendor Value: " ..
                            FormatMoney(
                                itemData.vendorPrice
                            )
                        )
                    end

                    --------------------------------------------------
                    -- Crafting Reagent
                    --------------------------------------------------

                    if itemData.isCraftingReagent then

                        print(
                            "  Crafting Reagent: YES"
                        )
                    end
                end
            end
        end
    end

    if PO_UpdateMainWindow then
        PO_UpdateMainWindow()
    end
end


--------------------------------------------------
-- Session Status
--------------------------------------------------

local function ShowStatus()

    if not sessionActive then

        print(
            "Profession Optimizer: No gathering session running."
        )

        return
    end

    local characterDB =
        GetCharacterDB()

    if not characterDB then
        return
    end

    local session =
        characterDB.currentGatheringSession

    if not session then

        print(
            "Profession Optimizer: Session data unavailable."
        )

        return
    end

    local elapsed =
        GetElapsedTime()

    print(
        "Profession Optimizer Gathering Session: " ..
        string.format(
            "%02d:%02d",
            math.floor(elapsed / 60),
            elapsed % 60
        )
    )

    local resources =
        session.resources or {}

    local foundResources =
        false

    for _, resource in pairs(resources) do

        print(
            resource.name ..
            " x" ..
            resource.quantity ..
            " [" ..
            resource.itemType ..
            "]"
        )

        foundResources = true
    end

    if not foundResources then

        print(
            "Profession Optimizer: No items recorded yet."
        )

        return
    end

    --------------------------------------------------
    -- Session Statistics
    --------------------------------------------------

    local totalItems
    local totalJunkItems
    local totalJunkVendorValue

    totalItems,
    totalJunkItems,
    totalJunkVendorValue =
        CalculateSessionValue(
            session
        )

    print("")
    print("Session Statistics")
    print("------------------")

    print(
        "Total Items: " ..
        totalItems
    )

    --------------------------------------------------
    -- Junk Statistics
    --------------------------------------------------

    if GetSetting(
        "trackJunkVendorValue",
        true
    ) then

        print(
            "Junk Items: " ..
            totalJunkItems
        )

        print(
            "Junk Vendor Value: " ..
            FormatMoney(
                totalJunkVendorValue
            )
        )

        if elapsed > 0 then

            local junkValuePerHour =
                totalJunkVendorValue /
                (elapsed / 3600)

            print(
                "Junk Vendor Gold/Hour: " ..
                FormatMoney(
                    junkValuePerHour
                )
            )
        end
    end
end


--------------------------------------------------
-- Slash Commands
--------------------------------------------------

SLASH_PROFESSIONOPTIMIZER1 =
    "/po"


SlashCmdList["PROFESSIONOPTIMIZER"] =
    function(msg)

        msg =
            strtrim(
                string.lower(
                    msg or ""
                )
            )

        if msg == "prof" then

            if ShowProfessions then
                ShowProfessions()
            end

        elseif msg == "start" then

            StartGatheringSession()

        elseif msg == "stop" then

            StopGatheringSession()

        elseif msg == "status" then

            ShowStatus()

        else

            print(
                "Profession Optimizer commands:"
            )

            print(
                "/po prof - Show professions"
            )

            print(
                "/po start - Start gathering session"
            )

            print(
                "/po stop - Stop gathering session"
            )

            print(
                "/po status - Show session status"
            )
        end

        ClearChatInput()
    end


--------------------------------------------------
-- Events
--------------------------------------------------

frame:RegisterEvent(
    "PLAYER_LOGIN"
)

frame:RegisterEvent(
    "LOOT_OPENED"
)


frame:SetScript(
    "OnEvent",
    function(self, event, ...)

        if event == "PLAYER_LOGIN" then

            local characterDB =
                GetCharacterDB()

            if characterDB then

                characterDB.professions =
                    characterDB.professions or {}

                characterDB.gatheringSessions =
                    characterDB.gatheringSessions or {}

                --------------------------------------------------
                -- Do not automatically resume an interrupted
                -- gathering session yet.
                --------------------------------------------------

                characterDB.currentGatheringSession =
                    nil
            end

            print(
                "Profession Optimizer: Loaded. Version 0.1.0"
            )

        elseif event == "LOOT_OPENED" then

            RecordLoot()
        end
    end
)
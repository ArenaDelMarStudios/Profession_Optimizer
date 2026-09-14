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

    return math.floor(GetTime() - sessionStartTime)
end


function PO_FormatMoney(copper)
    copper = tonumber(copper) or 0
    copper = math.floor(copper)

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local remainingCopper = copper % 100

    return string.format(
        "%dg %02ds %02dc",
        gold,
        silver,
        remainingCopper
    )
end


local function GetSetting(key, fallback)
    if PO_GetSetting then
        local value = PO_GetSetting(key)

        if value ~= nil then
            return value
        end
    end

    return fallback
end


--------------------------------------------------
-- Session Calculations
--------------------------------------------------

local function CalculateSessionValue(session)
    local totalItems = 0
    local totalJunkItems = 0
    local totalJunkVendorValue = 0

    if not session or not session.resources then
        return totalItems, totalJunkItems, totalJunkVendorValue
    end

    for _, resource in pairs(session.resources) do
        local quantity = resource.quantity or 0

        totalItems = totalItems + quantity

        if resource.isJunk then
            totalJunkItems = totalJunkItems + quantity
            totalJunkVendorValue =
                totalJunkVendorValue +
                ((resource.vendorPrice or 0) * quantity)
        end
    end

    return totalItems, totalJunkItems, totalJunkVendorValue
end


local function FinalizeGatheringSession(session, elapsed)
    if not session then
        return
    end

    local totalItems, totalJunkItems, junkVendorValue =
        CalculateSessionValue(session)

    session.duration = elapsed or 0
    session.endTime = time()

    session.characterGUID =
        session.characterGUID or UnitGUID("player")
    session.character =
        session.character or UnitName("player")
    session.realm =
        session.realm or GetRealmName()

    session.totalItems = totalItems
    session.totalJunkItems = totalJunkItems
    session.junkVendorValue = junkVendorValue

    if session.duration > 0 then
        session.junkValuePerHour =
            junkVendorValue / (session.duration / 3600)
    else
        session.junkValuePerHour = 0
    end
end


--------------------------------------------------
-- Chat Input Cleanup
--------------------------------------------------

local function ClearChatInput()
    C_Timer.After(
        0,
        function()
            local editBox = ChatEdit_ChooseBoxForSend()

            if editBox then
                editBox:SetText("")
                ChatEdit_DeactivateChat(editBox)
            end
        end
    )
end


--------------------------------------------------
-- Item Classification
--------------------------------------------------

local function GetItemData(itemID, itemLink, itemName)
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
        itemName = itemName or itemInfo[1]
        itemQuality = itemInfo[3]
        itemType = itemInfo[6]
        itemSubType = itemInfo[7]
        vendorPrice = itemInfo[11]
        classID = itemInfo[12]
        subclassID = itemInfo[13]
        isCraftingReagent = itemInfo[17]

        if Enum and Enum.ItemQuality then
            isJunk =
                itemQuality == Enum.ItemQuality.Poor
        else
            isJunk = itemQuality == 0
        end
    end

    return {
        itemID = itemID,
        name = itemName or "Unknown Item",
        link = itemLink,
        quality = itemQuality,
        isJunk = isJunk or false,
        itemType = itemType or "Unknown",
        itemSubType = itemSubType or "Unknown",
        classID = classID,
        subclassID = subclassID,
        isCraftingReagent = isCraftingReagent or false,
        vendorPrice = vendorPrice or 0,
    }
end


--------------------------------------------------
-- Start / Stop Session
--------------------------------------------------

local function StartGatheringSession()
    local characterDB = GetCharacterDB()

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
        characterGUID = UnitGUID("player"),
        character = UnitName("player"),
        realm = GetRealmName(),
        resources = {},
    }

    print(
        "Profession Optimizer: Gathering session STARTED."
    )

    if PO_UpdateMainWindow then
        PO_UpdateMainWindow()
    end
end


local function StopGatheringSession()
    local characterDB = GetCharacterDB()

    if not sessionActive then
        print(
            "Profession Optimizer: No gathering session is running."
        )
        return
    end

    local elapsed = GetElapsedTime()

    sessionActive = false
    sessionStartTime = nil

    if characterDB and
       characterDB.currentGatheringSession then

        FinalizeGatheringSession(
            characterDB.currentGatheringSession,
            elapsed
        )

        characterDB.gatheringSessions =
            characterDB.gatheringSessions or {}

        table.insert(
            characterDB.gatheringSessions,
            characterDB.currentGatheringSession
        )

        characterDB.currentGatheringSession = nil
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


function PO_IsSessionActive()
    return sessionActive
end


PO_StartGatheringSession =
    StartGatheringSession

PO_StopGatheringSession =
    StopGatheringSession


--------------------------------------------------
-- Current Session Snapshot
--------------------------------------------------

function PO_GetSessionSnapshot()
    local snapshot = {
        active = sessionActive,
        elapsed = 0,
        totalItems = 0,
        totalJunkItems = 0,
        junkVendorValue = 0,
        formattedJunkValue = PO_FormatMoney(0),
    }

    if not sessionActive then
        return snapshot
    end

    local characterDB = GetCharacterDB()

    if not characterDB or
       not characterDB.currentGatheringSession then
        return snapshot
    end

    local totalItems, totalJunkItems, junkVendorValue =
        CalculateSessionValue(
            characterDB.currentGatheringSession
        )

    snapshot.elapsed = GetElapsedTime()
    snapshot.totalItems = totalItems
    snapshot.totalJunkItems = totalJunkItems
    snapshot.junkVendorValue = junkVendorValue
    snapshot.formattedJunkValue =
        PO_FormatMoney(junkVendorValue)

    return snapshot
end


--------------------------------------------------
-- Gathering History API
--------------------------------------------------

function PO_GetGatheringSessions()
    local characterDB = GetCharacterDB()

    if not characterDB then
        return {}
    end

    return characterDB.gatheringSessions or {}
end


function PO_GetGatheringSession(index)
    local sessions = PO_GetGatheringSessions()

    return sessions[index]
end


function PO_GetGatheringHistoryStats()
    local sessions = PO_GetGatheringSessions()

    local stats = {
        sessions = #sessions,
        totalItems = 0,
        totalJunkItems = 0,
        junkVendorValue = 0,
    }

    for _, session in ipairs(sessions) do
        local totalItems = session.totalItems
        local totalJunkItems = session.totalJunkItems
        local junkVendorValue = session.junkVendorValue

        if totalItems == nil or
           totalJunkItems == nil or
           junkVendorValue == nil then

            totalItems,
            totalJunkItems,
            junkVendorValue =
                CalculateSessionValue(session)
        end

        stats.totalItems =
            stats.totalItems + (totalItems or 0)
        stats.totalJunkItems =
            stats.totalJunkItems + (totalJunkItems or 0)
        stats.junkVendorValue =
            stats.junkVendorValue + (junkVendorValue or 0)
    end

    return stats
end


--------------------------------------------------
-- Account-Wide Completed Gathering Time
--------------------------------------------------

function PO_GetTotalGatheringDuration()
    local DB = PO_GetDatabase and PO_GetDatabase()

    if not DB then
        return 0
    end

    local totalDuration = 0

    for _, characterDB in pairs(DB.characters or {}) do
        for _, session in ipairs(characterDB.gatheringSessions or {}) do
            totalDuration =
                totalDuration +
                (tonumber(session.duration) or 0)
        end
    end

    return totalDuration
end


--------------------------------------------------
-- Loot Processing
--------------------------------------------------

local function RecordLoot()
    if not sessionActive then
        return
    end

    local characterDB = GetCharacterDB()

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

            local _, itemName, quantity =
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

                    if not session.resources[itemID] then
                        session.resources[itemID] =
                            itemData
                        session.resources[itemID].quantity =
                            0
                    end

                    session.resources[itemID].quantity =
                        session.resources[itemID].quantity +
                        quantity

                    if PO_RegisterGatheredItem then
                        PO_RegisterGatheredItem(
                            itemData,
                            quantity
                        )
                    end

                    print(
                        "Profession Optimizer: +" ..
                        quantity ..
                        " " ..
                        itemName
                    )

                    if itemData.isJunk and
                       GetSetting(
                           "trackJunkVendorValue",
                           true
                       ) then

                        print(
                            "  Junk Vendor Value: " ..
                            PO_FormatMoney(
                                itemData.vendorPrice
                            )
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
-- Status
--------------------------------------------------

local function ShowStatus()
    if not sessionActive then
        print(
            "Profession Optimizer: No gathering session running."
        )
        return
    end

    local characterDB = GetCharacterDB()

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

    local elapsed = GetElapsedTime()

    print(
        "Profession Optimizer Gathering Session: " ..
        string.format(
            "%02d:%02d",
            math.floor(elapsed / 60),
            elapsed % 60
        )
    )

    for _, resource in pairs(session.resources or {}) do
        print(
            resource.name ..
            " x" ..
            (resource.quantity or 0) ..
            " [" ..
            tostring(resource.itemType or "Unknown") ..
            "]"
        )
    end

    local totalItems, totalJunkItems, junkVendorValue =
        CalculateSessionValue(session)

    print("Session Statistics")
    print("------------------")
    print("Total Items: " .. totalItems)

    if GetSetting(
        "trackJunkVendorValue",
        true
    ) then
        print("Junk Items: " .. totalJunkItems)
        print(
            "Junk Vendor Value: " ..
            PO_FormatMoney(junkVendorValue)
        )

        if elapsed > 0 then
            print(
                "Junk Vendor Gold/Hour: " ..
                PO_FormatMoney(
                    junkVendorValue /
                    (elapsed / 3600)
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
            else
                print(
                    "Profession Optimizer: Profession display unavailable."
                )
            end

        elseif msg == "start" then
            StartGatheringSession()

        elseif msg == "stop" then
            StopGatheringSession()

        elseif msg == "status" then
            ShowStatus()

        elseif msg == "salescan" then
            if PO_ScanSalesInbox then
                PO_ScanSalesInbox(true)
            else
                print(
                    "Profession Optimizer: Sales scanner unavailable."
                )
            end

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
            print(
                "/po salescan - Scan current mailbox data for AH sales"
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

                -- Interrupted sessions are intentionally not resumed.
                characterDB.currentGatheringSession =
                    nil
            end

            if PO_RebuildGatheredItemIndex then
                PO_RebuildGatheredItemIndex()
            end

            print(
                "Profession Optimizer: Loaded. Version 0.1.5"
            )

        elseif event == "LOOT_OPENED" then
            RecordLoot()
        end
    end
)

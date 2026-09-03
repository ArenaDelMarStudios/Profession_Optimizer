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


--------------------------------------------------
-- Item Classification
--------------------------------------------------

local function GetItemData(itemID, itemLink, itemName)

    local itemType
    local itemSubType
    local classID
    local subclassID
    local isCraftingReagent
    local vendorPrice

    local itemInfo = { C_Item.GetItemInfo(itemID) }

    if itemInfo then

        itemName = itemName or itemInfo[1]

        -- ItemInfo return values
        -- 6  = itemType
        -- 7  = itemSubType
        -- 12 = classID
        -- 13 = subclassID
        -- 17 = isCraftingReagent
        -- 11 = vendor sell price

        itemType = itemInfo[6]
        itemSubType = itemInfo[7]
        vendorPrice = itemInfo[11]
        classID = itemInfo[12]
        subclassID = itemInfo[13]
        isCraftingReagent = itemInfo[17]
    end

    return {
        itemID = itemID,
        name = itemName or "Unknown Item",
        link = itemLink,

        itemType = itemType or "Unknown",
        itemSubType = itemSubType or "Unknown",

        classID = classID,
        subclassID = subclassID,

        isCraftingReagent = isCraftingReagent or false,

        vendorPrice = vendorPrice or 0,
    }
end


--------------------------------------------------
-- Start Session
--------------------------------------------------

local function StartGatheringSession()

    local characterDB = GetCharacterDB()

    if not characterDB then
        print("Profession Optimizer: Character database unavailable.")
        return
    end

    if sessionActive then
        print("Profession Optimizer: Gathering session already running.")
        return
    end

    sessionActive = true
    sessionStartTime = GetTime()

    characterDB.currentGatheringSession = {
        startTime = time(),
        resources = {},
    }

    print("Profession Optimizer: Gathering session STARTED.")
end


--------------------------------------------------
-- Stop Session
--------------------------------------------------

local function StopGatheringSession()

    local characterDB = GetCharacterDB()

    if not sessionActive then
        print("Profession Optimizer: No gathering session is running.")
        return
    end

    local elapsed = GetElapsedTime()

    sessionActive = false
    sessionStartTime = nil

    if characterDB and characterDB.currentGatheringSession then

        characterDB.currentGatheringSession.duration = elapsed
        characterDB.currentGatheringSession.endTime = time()

        table.insert(
            characterDB.gatheringSessions,
            characterDB.currentGatheringSession
        )

        characterDB.currentGatheringSession = nil
    end

    print("Profession Optimizer: Gathering session STOPPED.")

    print(
        "Profession Optimizer: Duration: " ..
        string.format(
            "%02d:%02d",
            math.floor(elapsed / 60),
            elapsed % 60
        )
    )
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

    local session = characterDB.currentGatheringSession

    if not session then
        return
    end

    local numLootItems = GetNumLootItems()

    for slot = 1, numLootItems do

        local lootSlotType = GetLootSlotType(slot)

        if lootSlotType == Enum.LootSlotType.Item then

            local itemLink = GetLootSlotLink(slot)

            local texture
            local itemName
            local quantity

            texture,
            itemName,
            quantity = GetLootSlotInfo(slot)

            if itemLink and itemName and quantity and quantity > 0 then

                local itemID =
                    C_Item.GetItemIDForItemInfo(itemLink)

                if itemID then

                    local itemData =
                        GetItemData(
                            itemID,
                            itemLink,
                            itemName
                        )

                    --------------------------------------------------
                    -- Create item record
                    --------------------------------------------------

                    if not session.resources[itemID] then

                        session.resources[itemID] = itemData
                        session.resources[itemID].quantity = 0

                    end

                    --------------------------------------------------
                    -- Add quantity
                    --------------------------------------------------

                    session.resources[itemID].quantity =
                        session.resources[itemID].quantity + quantity

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
                        tostring(itemData.itemType) ..
                        " / " ..
                        tostring(itemData.itemSubType)
                    )

                    if itemData.isCraftingReagent then

                        print(
                            "  Crafting Reagent: YES"
                        )

                    end
                end
            end
        end
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

    local characterDB = GetCharacterDB()

    if not characterDB then
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

    local resources =
        characterDB.currentGatheringSession.resources

    local foundResources = false

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
    end
end


--------------------------------------------------
-- Profession Information
--------------------------------------------------

local function ShowProfessions()

    local characterDB = GetCharacterDB()

    if not characterDB then
        return
    end

    print("Profession Optimizer: Professions")

    for _, profession in pairs(characterDB.professions) do

        print(
            profession.name ..
            ": " ..
            profession.skill ..
            "/" ..
            profession.maxSkill
        )

    end
end


--------------------------------------------------
-- Slash Commands
--------------------------------------------------

SLASH_PROFESSIONOPTIMIZER1 = "/po"

SlashCmdList["PROFESSIONOPTIMIZER"] = function(msg)

    msg = string.lower(msg or "")

    if msg == "prof" then

        ShowProfessions()

    elseif msg == "start" then

        StartGatheringSession()

    elseif msg == "stop" then

        StopGatheringSession()

    elseif msg == "status" then

        ShowStatus()

    else

        print("Profession Optimizer commands:")
        print("/po prof - Show professions")
        print("/po start - Start gathering session")
        print("/po stop - Stop gathering session")
        print("/po status - Show session status")

    end
end


--------------------------------------------------
-- Events
--------------------------------------------------

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("LOOT_OPENED")

frame:SetScript("OnEvent", function(self, event, ...)

    if event == "PLAYER_LOGIN" then

        local characterDB = GetCharacterDB()

        if characterDB then

            characterDB.professions =
                characterDB.professions or {}

            characterDB.gatheringSessions =
                characterDB.gatheringSessions or {}

        end

        print(
            "Profession Optimizer: Loaded. Version 0.1.0"
        )

    elseif event == "LOOT_OPENED" then

        RecordLoot()

    end
end)
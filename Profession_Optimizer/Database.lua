local addonName = ...

--------------------------------------------------
-- Profession Optimizer Database
--------------------------------------------------


--------------------------------------------------
-- Get Main Database
--------------------------------------------------

local function GetDatabase()

    --------------------------------------------------
    -- SavedVariables are loaded after addon files.
    -- Do not cache the database table at file load.
    --------------------------------------------------

    ProfessionOptimizerDB =
        ProfessionOptimizerDB or {}

    ProfessionOptimizerDB.version =
        ProfessionOptimizerDB.version or 1

    ProfessionOptimizerDB.characters =
        ProfessionOptimizerDB.characters or {}

    return ProfessionOptimizerDB
end


--------------------------------------------------
-- Character Database
--------------------------------------------------

function PO_GetCharacterDB()

    local DB =
        GetDatabase()

    local characterKey =
        UnitGUID("player")

    if not characterKey then
        return nil
    end


    --------------------------------------------------
    -- Create Character Record
    --------------------------------------------------

    if not DB.characters[characterKey] then

        DB.characters[characterKey] = {

            name =
                UnitName("player"),

            realm =
                GetRealmName(),

            professions = {},

            gatheringSessions = {},

            settings = {},
        }
    end


    --------------------------------------------------
    -- Existing Character Record
    --------------------------------------------------

    local characterDB =
        DB.characters[characterKey]


    --------------------------------------------------
    -- Ensure Required Tables Exist
    --------------------------------------------------

    characterDB.professions =
        characterDB.professions or {}

    characterDB.gatheringSessions =
        characterDB.gatheringSessions or {}

    characterDB.settings =
        characterDB.settings or {}


    --------------------------------------------------
    -- Update Character Information
    --------------------------------------------------

    characterDB.name =
        UnitName("player")

    characterDB.realm =
        GetRealmName()


    return characterDB
end
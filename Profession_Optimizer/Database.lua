local addonName = ...

Profession_OptimizerDB = Profession_OptimizerDB or {}

local DB = Profession_OptimizerDB

DB.version = DB.version or 1
DB.characters = DB.characters or {}

function PO_GetCharacterDB()
    local characterKey = UnitGUID("player")

    if not characterKey then
        return nil
    end

    if not DB.characters[characterKey] then
        DB.characters[characterKey] = {
            name = UnitName("player"),
            realm = GetRealmName(),
            professions = {},
            gatheringSessions = {},
        }
    end

    return DB.characters[characterKey]
end
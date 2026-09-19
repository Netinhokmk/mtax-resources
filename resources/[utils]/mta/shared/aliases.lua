_MTA_COMPAT = _MTA_COMPAT or {}

-- { alias, modern name, side MTA registers it on }
_MTA_COMPAT.aliases = {

    -- client
    { "canPlayerBeKnockedOffBike", "canPedBeKnockedOffBike", "client" },
    { "getCameraShakeLevel", "getCameraDrunkLevel", "client" },
    { "getPlayerSimplestTask", "getPedSimplestTask", "client" },
    { "getPlayerTargetCollision", "getPedTargetCollision", "client" },
    { "getPlayerTargetEnd", "getPedTargetEnd", "client" },
    { "getPlayerTargetStart", "getPedTargetStart", "client" },
    { "getPlayerTask", "getPedTask", "client" },
    { "isPlayerDoingTask", "isPedDoingTask", "client" },
    { "setCameraShakeLevel", "setCameraDrunkLevel", "client" },
    { "setPlayerCanBeKnockedOffBike", "setPedCanBeKnockedOffBike", "client" },

    -- server
    { "addPlayerClothes", "addPedClothes", "server" },
    { "getClientAccount", "getPlayerAccount", "server" },
    { "getClientIP", "getPlayerIP", "server" },
    { "getClientName", "getPlayerName", "server" },
    { "getPlayerClothes", "getPedClothes", "server" },
    { "getPlayerFightingStyle", "getPedFightingStyle", "server" },
    { "getPlayerGravity", "getPedGravity", "server" },
    { "getPlayerOccupiedVehicleSeat", "getPedOccupiedVehicleSeat", "server" },
    { "killPlayer", "killPed", "server" },
    { "removePlayerClothes", "removePedClothes", "server" },
    { "removePlayerFromVehicle", "removePedFromVehicle", "server" },
    { "setClientName", "setPlayerName", "server" },
    { "setPlayerArmor", "setPedArmor", "server" },
    { "setPlayerChoking", "setPedChoking", "server" },
    { "setPlayerFightingStyle", "setPedFightingStyle", "server" },
    { "setPlayerGravity", "setPedGravity", "server" },
    { "setPlayerStat", "setPedStat", "server" },
    { "warpPlayerIntoVehicle", "warpPedIntoVehicle", "server" },

    -- shared
    { "getVehicleIDFromName", "getVehicleModelFromName", "shared" },
    { "getVehicleNameFromID", "getVehicleNameFromModel", "shared" },
    { "getPedSkin", "getElementModel", "shared" },
    { "getPlayerWeapon", "getPedWeapon", "shared" },
    { "isPedInWater", "isElementInWater", "shared" },
    { "setPedSkin", "setElementModel", "shared" },
    { "attachElementToElement", "attachElements", "shared" },
    { "detachElementFromElement", "detachElements", "shared" },
    { "getPlayerAmmoInClip", "getPedAmmoInClip", "shared" },
    { "getPlayerArmor", "getPedArmor", "shared" },
    { "getPlayerContactElement", "getPedContactElement", "shared" },
    { "getPlayerOccupiedVehicle", "getPedOccupiedVehicle", "shared" },
    { "getPlayerRotation", "getPedRotation", "shared" },
    { "getPlayerSkin", "getElementModel", "shared" },
    { "getPlayerStat", "getPedStat", "shared" },
    { "getPlayerTarget", "getPedTarget", "shared" },
    { "getPlayerTotalAmmo", "getPedTotalAmmo", "shared" },
    { "getPlayerWeaponSlot", "getPedWeaponSlot", "shared" },
    { "getVehicleID", "getElementModel", "shared" },
    { "getVehicleModel", "getElementModel", "shared" },
    { "isPlayerChoking", "isPedChoking", "shared" },
    { "isPlayerDead", "isPedDead", "shared" },
    { "isPlayerDucked", "isPedDucked", "shared" },
    { "isPlayerInVehicle", "isPedInVehicle", "shared" },
    { "isPlayerInWater", "isElementInWater", "shared" },
    { "isPlayerOnGround", "isPedOnGround", "shared" },
    { "setPlayerRotation", "setPedRotation", "shared" },
    { "setPlayerSkin", "setElementModel", "shared" },
    { "setPlayerWeaponSlot", "setPedWeaponSlot", "shared" },
    { "setVehicleModel", "setElementModel", "shared" },
}

function _MTA_COMPAT.bindAliases(side)
    local bound, skipped = 0, 0

    for _, entry in ipairs(_MTA_COMPAT.aliases) do
        local alias, target, on = entry[1], entry[2], entry[3]

        if on == side or on == "shared" then
            if _G[alias] ~= nil then
                skipped = skipped + 1
            elseif type(_G[target]) == "function" then
                _G[alias] = _G[target]
                bound = bound + 1
            else
                skipped = skipped + 1
            end
        end
    end

    return bound, skipped
end

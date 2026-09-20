local KEY_TEAM = _MTA_TEAMS.KEY_TEAM
local KEY_COLOR = _MTA_TEAMS.KEY_COLOR

local isTeam = _MTA_TEAMS.isTeam

local restore = {}

local function applyNametag(thePlayer)
    if not isElement(thePlayer) or getElementType(thePlayer) ~= "player" then
        return
    end

    local theTeam = getPlayerTeam(thePlayer)
    if not theTeam then
        local saved = restore[thePlayer]
        if saved then
            restore[thePlayer] = nil
            setPlayerNametagColor(thePlayer, saved[1], saved[2], saved[3])
        end
        return
    end

    if not restore[thePlayer] then
        local r, g, b = getPlayerNametagColor(thePlayer)
        if r then
            restore[thePlayer] = { r, g, b }
        end
    end

    local r, g, b = getTeamColor(theTeam)
    if r then
        setPlayerNametagColor(thePlayer, r, g, b)
    end
end

local function applyAll()
    for _, thePlayer in ipairs(getElementsByType("player") or {}) do
        applyNametag(thePlayer)
    end
end

addEventHandler("onClientResourceStart", resourceRoot, applyAll)

addEventHandler("onClientElementCreated", root, function()
    if getElementType(source) == "player" then
        applyNametag(source)
    elseif isTeam(source) then
        applyAll()
    end
end)

addEventHandler("onClientElementDataChange", root, function(key)
    if key == KEY_TEAM and getElementType(source) == "player" then
        applyNametag(source)
    elseif key == KEY_COLOR and isTeam(source) then
        for _, thePlayer in ipairs(getPlayersInTeam(source) or {}) do
            applyNametag(thePlayer)
        end
    end
end)

addEventHandler("onClientPlayerQuit", root, function()
    restore[source] = nil
end)

addEventHandler("onClientPlayerDamage", root, function(attacker)
    if not isElement(attacker) or getElementType(attacker) ~= "player" or attacker == source then
        return
    end

    local theTeam = getPlayerTeam(source)
    if not theTeam or getPlayerTeam(attacker) ~= theTeam then
        return
    end
    if getTeamFriendlyFire(theTeam) then
        return
    end

    cancelEvent()
end)

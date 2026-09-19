_MTA_COMPAT = _MTA_COMPAT or {}

local function teams()
    if not getResourceFromName("teams") then
        _MTA_COMPAT.warnOnce("teams",
            "the [mtax]/teams resource is not running; team state, friendly fire and nametag colour are off")
        return nil
    end
    return exports["teams"]
end

---@param theName string
---@param red? number
---@param green? number
---@param blue? number
---@return Element|false
function createTeam(theName, red, green, blue)
    local owner = teams()
    return owner and owner:createTeam(theName, red, green, blue) or false
end

---@param thePlayer Element
---@param theTeam? Element
---@return boolean
function setPlayerTeam(thePlayer, theTeam)
    local owner = teams()
    return owner and owner:setPlayerTeam(thePlayer, theTeam) == true or false
end

---@param theTeam Element
---@param theName string
---@return boolean
function setTeamName(theTeam, theName)
    local owner = teams()
    return owner and owner:setTeamName(theTeam, theName) == true or false
end

---@param theTeam Element
---@param red number
---@param green number
---@param blue number
---@return boolean
function setTeamColor(theTeam, red, green, blue)
    local owner = teams()
    return owner and owner:setTeamColor(theTeam, red, green, blue) == true or false
end

---@param theTeam Element
---@param state boolean
---@return boolean
function setTeamFriendlyFire(theTeam, state)
    local owner = teams()
    return owner and owner:setTeamFriendlyFire(theTeam, state) == true or false
end

addEvent("onPlayerTeamChange", false)

_MTA_COMPAT = _MTA_COMPAT or {}

local function areas()
    if not getResourceFromName("radararea") then
        _MTA_COMPAT.warnOnce("radararea",
            "the [mtax]/radararea resource is not running; no radar area is created and none is drawn")
        return nil
    end
    return exports["radararea"]
end

---@param startX number|table
---@param startY number
---@param sizeX number
---@param sizeY number
---@param red? number
---@param green? number
---@param blue? number
---@param alpha? number
---@return Element|false
function createRadarArea(...)
    local owner = areas()
    return owner and owner:createRadarArea(...) or false
end

---@param theArea Element
---@param sizeX number|table
---@param sizeY? number
---@return boolean
function setRadarAreaSize(theArea, ...)
    local owner = areas()
    return owner and owner:setRadarAreaSize(theArea, ...) == true or false
end

---@param theArea Element
---@param red number
---@param green number
---@param blue number
---@param alpha number
---@return boolean
function setRadarAreaColor(theArea, red, green, blue, alpha)
    local owner = areas()
    return owner and owner:setRadarAreaColor(theArea, red, green, blue, alpha) == true or false
end

---@param theArea Element
---@param flashing boolean
---@return boolean
function setRadarAreaFlashing(theArea, flashing)
    local owner = areas()
    return owner and owner:setRadarAreaFlashing(theArea, flashing) == true or false
end

_MTA_COMPAT = _MTA_COMPAT or {}

do
    local warned = {}

    function _MTA_COMPAT.warnOnce(subject, message)
        if warned[subject] then
            return
        end
        warned[subject] = true
        outputDebugString("[mta-compat] " .. subject .. ": " .. message, 2)
    end
end


local function escapeForSet(set)
    return (set:gsub("[%%%]%^%-]", "%%%1"))
end

function gettok(text, index, separator)
    if type(text) ~= "string" then
        text = tostring(text or "")
    end

    index = tonumber(index)
    index = index and math.floor(index)
    if not index or index <= 0 or index >= 1024 then
        outputDebugString("Token parameter sent to split must be greater than 0 and smaller than 1024", 2)
        return false
    end

    local code = tonumber(separator)
    if code and type(separator) ~= "string" then
        separator = utf8.char(code)
    elseif type(separator) ~= "string" then
        return false
    end

    if separator == "" then
        return index == 1 and text or false
    end

    local pattern = "[^" .. escapeForSet(separator) .. "]+"
    local at = 0
    for token in text:gmatch(pattern) do
        at = at + 1
        if at == index then
            return token
        end
    end

    return false
end

local function isPed(element)
    local kind = getElementType(element)
    return kind == "ped" or kind == "player"
end

local function runChildren(element, apply)
    if not isElementCallPropagationEnabled(element) then
        return
    end
    for _, child in ipairs(getElementChildren(element) or {}) do
        if isElement(child) then
            apply(child)
        end
    end
end

function getPedRotation(ped)
    if not isElement(ped) or not isPed(ped) then
        return false
    end
    local _, _, rz = getElementRotation(ped)
    return type(rz) == "number" and rz or false
end

function setPedRotation(element, rotation)
    if not isElement(element) then
        return false
    end
    rotation = tonumber(rotation)
    if not rotation then
        return false
    end

    runChildren(element, function(child) setPedRotation(child, rotation) end)

    if not isPed(element) then
        return false
    end
    return setElementRotation(element, 0, 0, rotation) == true
end

function getVehicleRotation(vehicle)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then
        return false
    end
    return getElementRotation(vehicle)
end

function setVehicleRotation(element, rx, ry, rz)
    if not isElement(element) then
        return false
    end
    rx, ry, rz = tonumber(rx), tonumber(ry), tonumber(rz)
    if not rx or not ry or not rz then
        return false
    end

    runChildren(element, function(child) setVehicleRotation(child, rx, ry, rz) end)

    if getElementType(element) ~= "vehicle" then
        return false
    end
    return setElementRotation(element, rx, ry, rz) == true
end

function getObjectRotation(object)
    if not isElement(object) or getElementType(object) ~= "object" then
        return false
    end
    return getElementRotation(object)
end

function setObjectRotation(element, rx, ry, rz)
    if not isElement(element) then
        return false
    end
    rx, ry, rz = tonumber(rx), tonumber(ry), tonumber(rz)
    if not rx or not ry or not rz then
        return false
    end

    runChildren(element, function(child) setObjectRotation(child, rx, ry, rz) end)

    if getElementType(element) ~= "object" then
        return false
    end
    return setElementRotation(element, rx, ry, rz) == true
end

function isOOPEnabled()
    return true
end

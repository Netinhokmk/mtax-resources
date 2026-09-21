local _MTAX = {}

_MTAX.__index = _MTAX

function _MTAX:New()
    local Instance = setmetatable({}, self)
    return Instance
end

function _MTAX:Init()
    self.Resource = getResourceName(getThisResource())
    self.Binds = {}
    self.Commands = {}

    self.KeyHandler = function(Key, KeyState) self:KeyPressed(Key, KeyState) end
    self.CommandHandler = function(CommandName, ...) self:CommandCalled(CommandName, ...) end

    --- Register Events
    addEvent("registerBindKey:" .. self.Resource, true)
    addEvent("unregisterBindKey:" .. self.Resource, true)
    addEvent("registerCommandHandler:" .. self.Resource, true)
    addEvent("unregisterCommandHandler:" .. self.Resource, true)

    --- Add Events
    addEventHandler("registerBindKey:" .. self.Resource, root, function(...) self:RegisterBindKey(...) end)
    addEventHandler("unregisterBindKey:" .. self.Resource, root, function(...) self:UnregisterBindKey(...) end)
    addEventHandler("registerCommandHandler:" .. self.Resource, root, function(...) self:RegisterCommandHandler(...) end)
    addEventHandler("unregisterCommandHandler:" .. self.Resource, root, function(...) self:UnregisterCommandHandler(...) end)
    addEventHandler("onClientResourceStart", resourceRoot, function() self:ResourceStart() end)
end

function _MTAX:Chat()
    return exports["chat"]
end

function _MTAX:KeyPressed(Key, KeyState)
    Key = Key:lower()

    triggerServerEvent("callbackBindKey:" .. self.Resource, localPlayer, Key, KeyState)
end

function _MTAX:CommandCalled(CommandName, ...)
    triggerServerEvent("callbackCommandHandler:" .. self.Resource, localPlayer, CommandName, ...)
end

function _MTAX:RegisterBindKey(Key, KeyState)
    Key = Key:lower()

    local Id = Key .. ":" .. KeyState
    if self.Binds[Id] then
        return
    end

    if bindKey(Key, KeyState, self.KeyHandler) then
        self.Binds[Id] = true
    end
end

function _MTAX:UnregisterBindKey(Key, KeyState)
    Key = Key:lower()

    local Id = Key .. ":" .. KeyState
    if not self.Binds[Id] then
        return
    end

    unbindKey(Key, KeyState, self.KeyHandler)
    self.Binds[Id] = nil
end

function _MTAX:RegisterCommandHandler(CommandName, CaseSensitive)
    if self.Commands[CommandName] then
        return
    end

    if addCommandHandler(CommandName, self.CommandHandler, CaseSensitive) then
        self.Commands[CommandName] = true
    end
end

function _MTAX:UnregisterCommandHandler(CommandName)
    if not self.Commands[CommandName] then
        return
    end

    removeCommandHandler(CommandName, self.CommandHandler)
    self.Commands[CommandName] = nil
end

function _MTAX:ResourceStart()
    triggerServerEvent("requestCommandHandlers:" .. self.Resource, localPlayer)
end

local Main = _MTAX:New()

Main:Init()

--- Chat

---@param Text string
---@param R? number
---@param G? number
---@param B? number
---@param ColorCoded? boolean
---@return boolean
function outputChatBox(Text, R, G, B, ColorCoded)
    return Main:Chat():outputChatBox(Text, R, G, B, ColorCoded)
end

---@return boolean
function clearChatBox()
    return Main:Chat():clearChat()
end

---@param Show boolean
---@return boolean
function showChat(Show)
    return Main:Chat():setChatVisible(Show)
end

---@return boolean
function isChatVisible()
    return Main:Chat():isChatVisible()
end

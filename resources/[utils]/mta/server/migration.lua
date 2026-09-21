local NativeAddCommandHandler = addCommandHandler
local NativeRemoveCommandHandler = removeCommandHandler

_addCommandHandler = NativeAddCommandHandler
_removeCommandHandler = NativeRemoveCommandHandler

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
    self.GlobalCommands = {}

    --- Register Events
    addEvent("callbackBindKey:" .. self.Resource, true)
    addEvent("callbackCommandHandler:" .. self.Resource, true)
    addEvent("requestCommandHandlers:" .. self.Resource, true)

    --- Add Events
    addEventHandler("callbackBindKey:" .. self.Resource, root, function(...) self:CallbackBindKey(client, ...) end)
    addEventHandler("callbackCommandHandler:" .. self.Resource, root, function(...) self:CallbackCommandHandler(client, ...) end)
    addEventHandler("requestCommandHandlers:" .. self.Resource, root, function() self:RequestCommandHandlers(client) end)
    addEventHandler("onPlayerQuit", root, function() local Source = source; self:PlayerQuit(Source) end)
end

function _MTAX:IsPlayer(Player)
    return isElement(Player) and getElementType(Player) == "player"
end

function _MTAX:Chat()
    return exports["chat"]
end

function _MTAX:ClearBind(Player, Key, KeyState)
    local PlayerBinds = self.Binds[Player]
    if not PlayerBinds or not PlayerBinds[Key] then
        return
    end

    PlayerBinds[Key][KeyState] = nil

    if not next(PlayerBinds[Key]) then
        PlayerBinds[Key] = nil
    end

    if not next(PlayerBinds) then
        self.Binds[Player] = nil
    end
end

function _MTAX:BindKey(Player, Key, KeyState, Handler, ...)
    if not self:IsPlayer(Player) then
        return false
    end

    if type(Key) ~= "string" or type(KeyState) ~= "string" or type(Handler) ~= "function" then
        return false
    end

    Key = Key:lower()

    self.Binds[Player] = self.Binds[Player] or {}
    self.Binds[Player][Key] = self.Binds[Player][Key] or {}
    self.Binds[Player][Key][KeyState] = { Handler = Handler, Args = { ... } }

    triggerClientEvent(Player, "registerBindKey:" .. self.Resource, resourceRoot, Key, KeyState)
    return true
end

function _MTAX:UnbindKey(Player, Key, KeyState, Handler)
    if not isElement(Player) or type(Key) ~= "string" then
        return false
    end

    Key = Key:lower()

    if not self.Binds[Player] or not self.Binds[Player][Key] then
        return false
    end

    local States = {}

    if KeyState == nil then
        for State in pairs(self.Binds[Player][Key]) do
            States[#States + 1] = State
        end
    else
        States[1] = KeyState
    end

    local Removed = false

    for _, State in ipairs(States) do
        local Bind = self.Binds[Player] and self.Binds[Player][Key] and self.Binds[Player][Key][State]

        if Bind and (Handler == nil or Bind.Handler == Handler) then
            self:ClearBind(Player, Key, State)
            triggerClientEvent(Player, "unregisterBindKey:" .. self.Resource, resourceRoot, Key, State)
            Removed = true
        end
    end

    return Removed
end

function _MTAX:UnbindAllKeys(Player)
    if not isElement(Player) or not self.Binds[Player] then
        return false
    end

    for Key, States in pairs(self.Binds[Player]) do
        for State in pairs(States) do
            triggerClientEvent(Player, "unregisterBindKey:" .. self.Resource, resourceRoot, Key, State)
        end
    end

    self.Binds[Player] = nil
    return true
end

function _MTAX:CallbackBindKey(Player, Key, KeyState)
    if not Player or type(Key) ~= "string" or type(KeyState) ~= "string" then
        return
    end

    Key = Key:lower()

    local Bind = self.Binds[Player] and self.Binds[Player][Key] and self.Binds[Player][Key][KeyState]
    if not Bind then
        return
    end

    Bind.Handler(Player, Key, KeyState, table.unpack(Bind.Args))
end

function _MTAX:ClearCommand(Player, CommandName)
    local PlayerCommands = self.Commands[Player]
    if not PlayerCommands or not PlayerCommands[CommandName] then
        return
    end

    PlayerCommands[CommandName] = nil

    if not next(PlayerCommands) then
        self.Commands[Player] = nil
    end
end

function _MTAX:AddCommandHandler(Player, CommandName, Handler, CaseSensitive)
    if type(Player) == "string" then
        CommandName, Handler, CaseSensitive = Player, CommandName, Handler

        if type(Handler) ~= "function" then
            return false
        end

        self.GlobalCommands[CommandName] = { Handler = Handler, CaseSensitive = CaseSensitive }

        triggerClientEvent(root, "registerCommandHandler:" .. self.Resource, resourceRoot, CommandName, CaseSensitive)
        return true
    end

    if not self:IsPlayer(Player) then
        return false
    end

    if type(CommandName) ~= "string" or type(Handler) ~= "function" then
        return false
    end

    self.Commands[Player] = self.Commands[Player] or {}
    self.Commands[Player][CommandName] = { Handler = Handler, CaseSensitive = CaseSensitive }

    triggerClientEvent(Player, "registerCommandHandler:" .. self.Resource, resourceRoot, CommandName, CaseSensitive)
    return true
end

function _MTAX:RemoveCommandHandler(Player, CommandName, Handler)
    if type(Player) == "string" then
        CommandName, Handler = Player, CommandName

        local Bind = self.GlobalCommands[CommandName]
        if not Bind then
            return false
        end

        if Handler ~= nil and Bind.Handler ~= Handler then
            return false
        end

        self.GlobalCommands[CommandName] = nil
        triggerClientEvent(root, "unregisterCommandHandler:" .. self.Resource, resourceRoot, CommandName)
        return true
    end

    if not self:IsPlayer(Player) then
        return false
    end

    if type(CommandName) ~= "string" then
        return false
    end

    if not self.Commands[Player] or not self.Commands[Player][CommandName] then
        return false
    end

    local Bind = self.Commands[Player][CommandName]
    if Handler ~= nil and Bind.Handler ~= Handler then
        return false
    end

    self:ClearCommand(Player, CommandName)
    triggerClientEvent(Player, "unregisterCommandHandler:" .. self.Resource, resourceRoot, CommandName)
    return true
end

function _MTAX:RemoveAllCommandHandlers(Player)
    if not isElement(Player) or not self.Commands[Player] then
        return false
    end

    for CommandName in pairs(self.Commands[Player]) do
        triggerClientEvent(Player, "unregisterCommandHandler:" .. self.Resource, resourceRoot, CommandName)
    end

    self.Commands[Player] = nil
    return true
end

function _MTAX:CallbackCommandHandler(Player, CommandName, ...)
    if not Player or type(CommandName) ~= "string" then
        return
    end

    local Bind = (self.Commands[Player] and self.Commands[Player][CommandName]) or self.GlobalCommands[CommandName]
    if not Bind then
        return
    end

    Bind.Handler(Player, CommandName, ...)
end

function _MTAX:RequestCommandHandlers(Player)
    if not Player then
        return
    end

    for CommandName, Bind in pairs(self.GlobalCommands) do
        triggerClientEvent(Player, "registerCommandHandler:" .. self.Resource, resourceRoot, CommandName, Bind.CaseSensitive)
    end

    if self.Commands[Player] then
        for CommandName, Bind in pairs(self.Commands[Player]) do
            triggerClientEvent(Player, "registerCommandHandler:" .. self.Resource, resourceRoot, CommandName, Bind.CaseSensitive)
        end
    end
end

function _MTAX:PlayerQuit(Player)
    self.Binds[Player] = nil
    self.Commands[Player] = nil
end

local Main = _MTAX:New()

Main:Init()

---@param Player Element
---@param Key string
---@param KeyState string
---@param Handler function
---@param ... any
---@return boolean
function bindKey(Player, Key, KeyState, Handler, ...)
    return Main:BindKey(Player, Key, KeyState, Handler, ...)
end

---@param Player Element
---@param Key string
---@param KeyState? string
---@param Handler? function
---@return boolean
function unbindKey(Player, Key, KeyState, Handler)
    return Main:UnbindKey(Player, Key, KeyState, Handler)
end

---@param Player Element
---@return boolean
function unbindAllKeys(Player)
    return Main:UnbindAllKeys(Player)
end

---@param Player Element|string
---@param CommandName string|function
---@param Handler? function|boolean
---@param CaseSensitive? boolean
---@return boolean
function addCommandHandler(Player, CommandName, Handler, CaseSensitive)
    return Main:AddCommandHandler(Player, CommandName, Handler, CaseSensitive)
end

---@param Player Element|string
---@param CommandName? string|function
---@param Handler? function
---@return boolean
function removeCommandHandler(Player, CommandName, Handler)
    return Main:RemoveCommandHandler(Player, CommandName, Handler)
end

---@param Player Element
---@return boolean
function removeAllCommandHandlers(Player)
    return Main:RemoveAllCommandHandlers(Player)
end

---@param Text string
---@param VisibleTo? Element|Element[]
---@param R? number
---@param G? number
---@param B? number
---@param ColorCoded? boolean
---@return boolean
function outputChatBox(Text, VisibleTo, R, G, B, ColorCoded)
    return Main:Chat():outputChatBox(Text, VisibleTo, R, G, B, ColorCoded)
end

---@param VisibleTo? Element|Element[]
---@return boolean
function clearChatBox(VisibleTo)
    return Main:Chat():clearChat(VisibleTo)
end

---@param VisibleTo Element|Element[]
---@param Show boolean
---@return boolean
function showChat(VisibleTo, Show)
    return Main:Chat():setChatVisible(Show, VisibleTo)
end

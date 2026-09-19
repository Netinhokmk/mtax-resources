---@alias Element userdata
---@alias ChatMessage table

local _MTAX = {}

_MTAX.__index = _MTAX

function _MTAX:New()
    local Instance = setmetatable({}, self)
    return Instance
end

function _MTAX:Init()
    self.Enabled = true
    self.Sequence = 0
    self.Ids = {}
    self.ById = {}
    self.FreeIds = {}
    self.NextId = 1
    self.Flood = {}
    self.Stickers = {}

    for _, Id in ipairs(Config.Stickers) do
        self.Stickers[Id] = true
    end

    --- Add Events
    addEventHandler("onResourceStart", resourceRoot, function() self:ResourceStart() end)
    addEventHandler("onPlayerJoin", root, function() local Source = source; self:PlayerJoin(Source) end)
    addEventHandler("onPlayerQuit", root, function(Reason) local Source = source; self:PlayerQuit(Source, Reason) end)
    addEventHandler("onPlayerChangeNick", root, function() self:PushRoster() end)

    self:RegisterCommands()
end

--- Helpers

---@param Element any
---@return boolean
function _MTAX:IsPlayer(Element)
    return isElement(Element) and getElementType(Element) == "player"
end

---@param Player Element
---@return string
function _MTAX:PlayerName(Player)
    local Name = getPlayerName(Player)
    return type(Name) == "string" and Name ~= "" and Name or "Unknown"
end

---@param Player Element
---@return boolean
function _MTAX:IsAdmin(Player)
    if not self:IsPlayer(Player) then
        return false
    end

    local Ok, Result = pcall(function()
        local Acls = exports["acls"]
        local Accounts = exports["accounts"]
        local Account = Accounts:getPlayerAccount(Player)

        if not Account or Accounts:isGuestAccount(Account) then
            return false
        end

        local Name = Accounts:getAccountName(Account)
        if type(Name) ~= "string" or Name == "" then
            return false
        end

        for _, Group in ipairs(Config.AdminGroups) do
            if Acls:isObjectInACLGroup("user." .. Name, Acls:aclGetGroup(Group)) then
                return true
            end
        end

        return false
    end)

    return Ok and Result == true
end

--- Player ids

---@param Player Element
---@return number
function _MTAX:AssignID(Player)
    if self.Ids[Player] then
        return self.Ids[Player]
    end

    local Id
    if #self.FreeIds > 0 then
        table.sort(self.FreeIds)
        Id = table.remove(self.FreeIds, 1)
    else
        Id = self.NextId
        self.NextId = self.NextId + 1
    end

    self.Ids[Player] = Id
    self.ById[Id] = Player
    setElementData(Player, "chat:id", Id)
    return Id
end

---@param Player Element
function _MTAX:ReleaseID(Player)
    local Id = self.Ids[Player]
    if not Id then
        return
    end

    self.Ids[Player] = nil
    self.ById[Id] = nil
    self.Flood[Player] = nil
    table.insert(self.FreeIds, Id)
end

---@return table[]
function _MTAX:Roster()
    local Roster = {}

    for _, Player in ipairs(getElementsByType("player")) do
        local Id = self.Ids[Player]
        if Id then
            Roster[#Roster + 1] = { id = Id, name = self:PlayerName(Player) }
        end
    end

    table.sort(Roster, function(A, B) return A.id < B.id end)
    return Roster
end

function _MTAX:PushRoster()
    local Players = getElementsByType("player")
    if #Players == 0 then
        return
    end

    Client.roster(false, Players, self:Roster())
end

--- Delivery

---@param Targets Element[]
---@param Message ChatMessage
---@param Anchor? Element
function _MTAX:Deliver(Targets, Message, Anchor)
    if #Targets == 0 then
        return
    end

    self.Sequence = self.Sequence + 1
    Message.id = self.Sequence
    Message.time = ChatText:Timestamp()

    Client.receive(false, Targets, Message, Anchor)
end

---@param Speaker Element
---@param Range number
---@return Element[]
function _MTAX:InRange(Speaker, Range)
    local Targets = {}
    if not self:IsPlayer(Speaker) then
        return Targets
    end

    local X, Y, Z = getElementPosition(Speaker)
    local Dimension = getElementDimension(Speaker)
    local Interior = getElementInterior(Speaker)

    for _, Player in ipairs(getElementsByType("player")) do
        if getElementDimension(Player) == Dimension and getElementInterior(Player) == Interior then
            local PX, PY, PZ = getElementPosition(Player)
            if getDistanceBetweenPoints3D(X, Y, Z, PX, PY, PZ) <= Range then
                Targets[#Targets + 1] = Player
            end
        end
    end

    return Targets
end

---@param Player Element
---@param Text string
---@param Color? string
function _MTAX:Notice(Player, Text, Color)
    if not self:IsPlayer(Player) then
        return
    end

    self:Deliver({ Player }, { kind = "system", text = Text, color = Color })
end

--- Rate limiting

---@param Player Element
---@return boolean
function _MTAX:AllowFlood(Player)
    local Now = getTickCount()
    local State = self.Flood[Player]

    if not State then
        State = { Last = 0, Hits = 0, Since = Now, BlockedUntil = 0 }
        self.Flood[Player] = State
    end

    if Now < State.BlockedUntil then
        return false
    end

    if Now - State.Last < Config.Flood.Interval then
        return false
    end

    if Now - State.Since > Config.Flood.Window then
        State.Since = Now
        State.Hits = 0
    end

    State.Hits = State.Hits + 1
    State.Last = Now

    if State.Hits > Config.Flood.Burst then
        State.BlockedUntil = Now + Config.Flood.Cooldown
        State.Hits = 0
        State.Since = Now
        return false
    end

    return true
end

--- Sending

---@param Player Element
---@param TypeId string
---@param Text string
---@param Sticker? string
---@param Target? string|number
---@return boolean
function _MTAX:Say(Player, TypeId, Text, Sticker, Target)
    if not self:IsPlayer(Player) then
        return false
    end

    local Kind = Config.Types[TypeId]
    if not Kind or Kind.Scope == "none" then
        return false
    end

    if Kind.Admin and not self:IsAdmin(Player) then
        self:Notice(Player, Config.Text.NoPermission)
        return false
    end

    if not self.Enabled and not self:IsAdmin(Player) then
        self:Notice(Player, Config.Text.ChatOff)
        return false
    end

    if isPlayerMuted(Player) then
        self:Notice(Player, Config.Text.Muted)
        return false
    end

    if Sticker ~= nil and not self.Stickers[Sticker] then
        Sticker = nil
    end

    Text = ChatText:Line(Text)
    if Text == "" and not Sticker then
        self:Notice(Player, Config.Text.Empty)
        return false
    end

    if ChatText:Length(Text) > Config.MaxLength then
        Text = ChatText:Cut(Text, Config.MaxLength)
    end

    if not self:AllowFlood(Player) then
        self:Notice(Player, Config.Text.Flooding)
        return false
    end

    local Message = {
        kind    = TypeId,
        name    = self:PlayerName(Player),
        pid     = self.Ids[Player],
        text    = Text,
        sticker = Sticker,
        three   = Kind.ThreeD == true and Config.ThreeD.Enabled == true,
    }

    if Kind.Scope == "pm" then
        return self:SayPrivate(Player, Message, Target)
    end

    local Targets = Kind.Scope == "range"
        and self:InRange(Player, Kind.Range or 20)
        or getElementsByType("player")

    self:Deliver(Targets, Message, Message.three and Player or nil)
    return true
end

---@param Player Element
---@param Message ChatMessage
---@param Target? string|number
---@return boolean
function _MTAX:SayPrivate(Player, Message, Target)
    local Id = tonumber(Target)
    local Receiver = Id and self.ById[Id] or nil

    if not self:IsPlayer(Receiver) then
        self:Notice(Player, string.format(Config.Text.UnknownPlayer, tostring(Target)))
        return false
    end

    if Receiver == Player then
        self:Notice(Player, Config.Text.PmSelf)
        return false
    end

    local Outgoing = {}
    local Incoming = {}

    for Key, Value in pairs(Message) do
        Outgoing[Key] = Value
        Incoming[Key] = Value
    end

    Outgoing.name = self:PlayerName(Receiver)
    Outgoing.pid = self.Ids[Receiver]
    Outgoing.note = Config.Text.PmTo

    Incoming.name = self:PlayerName(Player)
    Incoming.pid = self.Ids[Player]
    Incoming.note = Config.Text.PmFrom

    self:Deliver({ Player }, Outgoing)
    self:Deliver({ Receiver }, Incoming)
    return true
end

---@param Player Element
---@param Sides? string
function _MTAX:Roll(Player, Sides)
    if not self:IsPlayer(Player) then
        return
    end

    local Max = math.floor(tonumber(Sides) or Config.Dice.Max)

    if Max < 2 or Max > Config.Dice.Max then
        self:Notice(Player, string.format(Config.Text.DiceRange, Config.Dice.Max))
        return
    end

    if not self:AllowFlood(Player) then
        self:Notice(Player, Config.Text.Flooding)
        return
    end

    local Roll = math.random(1, Max)

    self:Deliver(self:InRange(Player, Config.Dice.Range), {
        kind = "dice",
        name = self:PlayerName(Player),
        pid  = self.Ids[Player],
        text = string.format(Config.Text.Rolled, Roll, Max),
    })
end

--- Commands

function _MTAX:RegisterCommands()
    for TypeId, Kind in pairs(Config.Types) do
        for _, Command in ipairs(Kind.Commands or {}) do
            addCommandHandler(Command, function(Player, _, ...)
                self:RunTypeCommand(Player, TypeId, Kind, ...)
            end)
        end
    end

    if Config.Dice.Enabled then
        addCommandHandler("dice", function(Player, _, Sides) self:Roll(Player, Sides) end)
        addCommandHandler("roll", function(Player, _, Sides) self:Roll(Player, Sides) end)
    end

    addCommandHandler("clearchat", function(Player) self:ClearChatCommand(Player) end)
    addCommandHandler("togglechat", function(Player) self:ToggleChatCommand(Player) end)
end

---@param Player Element
---@param TypeId string
---@param Kind table
function _MTAX:RunTypeCommand(Player, TypeId, Kind, ...)
    local Words = { ... }

    if Kind.Scope == "pm" then
        local Target = table.remove(Words, 1)
        local Text = table.concat(Words, " ")

        if not Target or Text == "" then
            self:Notice(Player, Config.Text.UsagePm)
            return
        end

        self:Say(Player, TypeId, Text, nil, Target)
        return
    end

    self:Say(Player, TypeId, table.concat(Words, " "))
end

---@param Player Element
function _MTAX:ClearChatCommand(Player)
    if not self:IsAdmin(Player) then
        self:Notice(Player, Config.Text.NoPermission)
        return
    end

    local Players = getElementsByType("player")
    if #Players > 0 then
        Client.clear(false, Players)
    end

    self:Deliver(Players, { kind = "system", text = Config.Text.ChatCleared })
end

---@param Player Element
function _MTAX:ToggleChatCommand(Player)
    if not self:IsAdmin(Player) then
        self:Notice(Player, Config.Text.NoPermission)
        return
    end

    self:SetEnabled(not self.Enabled)

    self:Deliver(getElementsByType("player"), {
        kind = "system",
        text = string.format(Config.Text.ChatToggled, self.Enabled and "on" or "off"),
    })
end

--- Lifecycle

function _MTAX:ResourceStart()
    for _, Player in ipairs(getElementsByType("player")) do
        self:AssignID(Player)
    end

    self:PushRoster()
end

---@param Player Element
function _MTAX:PlayerJoin(Player)
    self:AssignID(Player)
    self:PushRoster()

    if not Config.JoinLeave then
        return
    end

    self:Deliver(getElementsByType("player"), {
        kind = "join",
        text = string.format(Config.Text.Joined, self:PlayerName(Player)),
    })
end

---@param Player Element
---@param Reason? string
function _MTAX:PlayerQuit(Player, Reason)
    local Name = self:PlayerName(Player)
    self:ReleaseID(Player)

    local Remaining = {}
    for _, Other in ipairs(getElementsByType("player")) do
        if Other ~= Player then
            Remaining[#Remaining + 1] = Other
        end
    end

    if #Remaining == 0 then
        return
    end

    if Config.JoinLeave then
        self:Deliver(Remaining, {
            kind = "leave",
            text = string.format(Config.Text.Left, Name, tostring(Reason or "Quit")),
        })
    end

    Client.roster(false, Remaining, self:Roster())
end

--- Public

---@param VisibleTo? Element|Element[]
---@return Element[]
function _MTAX:ResolveTargets(VisibleTo)
    if VisibleTo == nil or VisibleTo == root then
        return getElementsByType("player")
    end

    if type(VisibleTo) == "table" then
        local Targets = {}
        for _, Player in ipairs(VisibleTo) do
            if self:IsPlayer(Player) then
                Targets[#Targets + 1] = Player
            end
        end
        return Targets
    end

    if self:IsPlayer(VisibleTo) then
        return { VisibleTo }
    end

    return {}
end

---@param Text string
---@param VisibleTo? Element|Element[]
---@param R? number
---@param G? number
---@param B? number
---@param ColorCoded? boolean
---@return boolean
function _MTAX:OutputChatBox(Text, VisibleTo, R, G, B, ColorCoded)
    if type(Text) ~= "string" then
        return false
    end

    local Targets = self:ResolveTargets(VisibleTo)
    if #Targets == 0 then
        return false
    end

    local Color = ChatText:Rgb(R, G, B)
    local Message = { kind = "system", text = ChatText:Line(Text), color = Color }

    if ColorCoded then
        Message.text, Message.segments = ChatText:ColorCoded(Message.text, Color)
    end

    self:Deliver(Targets, Message)
    return true
end

---@param VisibleTo? Element|Element[]
---@return boolean
function _MTAX:ClearChat(VisibleTo)
    local Targets = self:ResolveTargets(VisibleTo)
    if #Targets == 0 then
        return false
    end

    Client.clear(false, Targets)
    return true
end

---@param Enabled boolean
---@return boolean
function _MTAX:SetEnabled(Enabled)
    self.Enabled = Enabled and true or false

    local Players = getElementsByType("player")
    if #Players > 0 then
        Client.enabled(false, Players, self.Enabled)
    end

    return true
end

local Main = _MTAX:New()

Main:Init()

--- Tunnel

Server.ready = function()
    local Player = client
    if not Main:IsPlayer(Player) then
        return false
    end

    return Main:AssignID(Player), Main:Roster(), Main.Enabled, Main:IsAdmin(Player)
end

Server.send = function(TypeId, Text, Sticker, Target)
    Main:Say(client, tostring(TypeId or ""), Text, Sticker, Target)
end

local CommandRate = { }

local function commandAllowed(Player)
    local Now = getTickCount()
    local State = CommandRate[Player]

    if not State or Now - State.Since >= Config.CommandFlood.Window then
        CommandRate[Player] = { Since = Now, Hits = 1 }
        return true
    end

    State.Hits = State.Hits + 1
    return State.Hits <= Config.CommandFlood.Burst
end

Server.command = function(Name, Args)
    local Player = client
    if not Main:IsPlayer(Player) or type(Name) ~= "string" or Name == "" then
        return false
    end

    Args = type(Args) == "string" and Args or ""
    if #Name + #Args + 1 > Config.CommandFlood.LineCap then
        return false
    end

    if not commandAllowed(Player) then
        Main:Notice(Player, Config.Text.Flooding)
        return true
    end

    return executeCommandHandler(Name, Player, Args) == true
end

addEventHandler("onPlayerQuit", root, function()
    CommandRate[source] = nil
end)

--- Exports

---@param Text string
---@param VisibleTo? Element|Element[]
---@param R? number
---@param G? number
---@param B? number
---@param ColorCoded? boolean
---@return boolean
function outputChatBox(Text, VisibleTo, R, G, B, ColorCoded)
    return Main:OutputChatBox(Text, VisibleTo, R, G, B, ColorCoded)
end

---@param VisibleTo? Element|Element[]
---@return boolean
function clearChat(VisibleTo)
    return Main:ClearChat(VisibleTo)
end

---@return boolean
function isChatEnabled()
    return Main.Enabled
end

---@param Enabled boolean
---@return boolean
function setChatEnabled(Enabled)
    return Main:SetEnabled(Enabled)
end

---@param Player Element
---@return number|false
function getPlayerChatID(Player)
    return Main.Ids[Player] or false
end

---@param Id number|string
---@return Element|false
function getPlayerFromChatID(Id)
    local Player = Main.ById[tonumber(Id) or -1]
    return Main:IsPlayer(Player) and Player or false
end

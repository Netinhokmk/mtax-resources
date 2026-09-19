Config = {}

--- Interface

Config.Key = "t"
Config.Cursor = true
Config.HistorySize = 100
Config.MaxLength = 200
Config.HideAfter = 12000
Config.Timestamps = true

--- Server

Config.JoinLeave = true
Config.AdminGroups = { "Admin", "Console" }

Config.Flood = {
    Interval = 600,
    Burst    = 5,
    Window   = 4000,
    Cooldown = 4000,
}

Config.CommandFlood = {
    Burst   = 8,
    Window  = 4000,
    LineCap = 255,
}

--- Labels

Config.ThreeD = {
    Enabled  = true,
    Distance = 25,
    Duration = 5000,
    Height   = 1.10,
    Stack    = 3,
}

--- Dice

Config.Dice = {
    Enabled = true,
    Max     = 12,
    Range   = 20,
}

--- Stickers

Config.Stickers = {
    "1f44b", "1f44d", "1f44e", "1f44f", "1f64f", "1f4aa",
    "1f600", "1f602", "1f605", "1f60e", "1f610", "1f614",
    "1f621", "1f622", "1f631", "1f634", "1f644", "1f92b",
    "2764",  "1f494", "1f525", "1f4a3", "1f3c1", "1f3af",
    "1f697", "1f6a8", "1f52b", "1f48a", "1f4b0", "1f37b",
    "1f355", "1f480",
}

--- Types

---@alias ChatScope "range"|"global"|"pm"|"none"
---@alias ChatForm "said"|"action"|"plain"

Config.Types = {
    ["local"] = {
        Label = "SAY", Color = "#e7e9ee", Commands = { "say", "s" },
        Scope = "range", Range = 20, ThreeD = false, Form = "said",
    },
    ["me"] = {
        Label = "ME", Color = "#4aa8ff", Commands = { "me" },
        Scope = "range", Range = 30, ThreeD = true, Form = "action",
    },
    ["do"] = {
        Label = "DO", Color = "#a978ff", Commands = { "do" },
        Scope = "range", Range = 15, ThreeD = true, Form = "action", Fade = 10000,
    },
    ["ooc"] = {
        Label = "OOC", Color = "#3ddc84", Commands = { "ooc", "b" },
        Scope = "global", Form = "said",
    },
    ["global"] = {
        Label = "GLOBAL", Color = "#ffb020", Commands = { "global", "g" },
        Scope = "global", Admin = true, Form = "said",
    },
    ["pm"] = {
        Label = "PM", Color = "#ff5fa2", Commands = { "pm", "w" },
        Scope = "pm", Form = "said",
    },
    ["dice"] = {
        Label = "DICE", Color = "#00d1c1",
        Scope = "range", Range = 20, Form = "action",
    },
    ["system"] = {
        Label = "SYSTEM", Color = "#8b93a7", Scope = "none", Form = "plain",
    },
    ["join"] = {
        Label = "JOIN", Color = "#3ddc84", Scope = "none", Form = "plain",
    },
    ["leave"] = {
        Label = "LEFT", Color = "#ff6b6b", Scope = "none", Form = "plain",
    },
}

Config.Tabs = { "local", "me", "do", "ooc", "global", "pm" }
Config.DefaultTab = "local"

--- Autocomplete

Config.Suggestions = {
    { Name = "say",        Params = "[message]",      Help = "Talk to players nearby" },
    { Name = "me",         Params = "[action]",       Help = "Describe what you are doing" },
    { Name = "do",         Params = "[description]",  Help = "Describe the scene around you" },
    { Name = "ooc",        Params = "[message]",      Help = "Out of character, whole server" },
    { Name = "global",     Params = "[message]",      Help = "Server announcement (admin)" },
    { Name = "pm",         Params = "[id] [message]", Help = "Private message a player" },
    { Name = "dice",       Params = "[max]",          Help = "Roll a die for players nearby" },
    { Name = "clearchat",  Params = "",               Help = "Wipe every chat (admin)" },
    { Name = "togglechat", Params = "",               Help = "Mute or unmute the chat (admin)" },
}

--- Text

Config.Text = {
    Joined        = "%s joined the server",
    Left          = "%s left the server (%s)",
    Rolled        = "rolled %d out of %d",
    PmTo          = "to",
    PmFrom        = "from",
    NoPermission  = "You are not allowed to use that.",
    Muted         = "You are muted.",
    Flooding      = "Slow down.",
    Empty         = "Say something first.",
    UsagePm       = "Usage: /pm [id] [message]",
    UnknownPlayer = "No player with id %s.",
    PmSelf        = "You cannot message yourself.",
    ChatOff       = "The chat is off.",
    ChatToggled   = "Chat %s by an admin.",
    ChatCleared   = "Chat cleared by an admin.",
    DiceRange     = "Pick a number between 2 and %d.",
    Unknown       = "Unknown command: %s",
}

Config = {}

--- Identifiers

Config.Identifiers = { "mtax", "mtax2", "ip", "discord" }

Config.Slot = {
    ip       = "ip",
    username = "mtax2",
    serial   = "mtax",
}

--- Limits

Config.ReasonMaxLength = 256
Config.NickMaxLength   = 64
Config.ValueMaxLength  = 128

Config.SweepInterval = 60000

--- Messages

Config.Text = {
    Refused  = "You are banned from this server.",
    WithTime = "You are banned from this server until %s.",
    Reason   = " (%s)",
}

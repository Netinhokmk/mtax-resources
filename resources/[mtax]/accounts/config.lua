Config = {}

--- Limits

Config.NameMaxLength     = 64
Config.PasswordMaxLength = 256

-- acl.xml ships user.Console in both the Admin and the Console groups, so an account
-- with that name is an instant administrator. Case-insensitive.
Config.ReservedNames = { "console" }

--- Rate limiting

Config.LoginRate    = { Interval = 1000, Window = 60000,  Burst = 5, Cooldown = 60000 }
Config.RegisterRate = { Interval = 5000, Window = 300000, Burst = 3, Cooldown = 300000 }

Config.AttemptTTL   = 600000
Config.AttemptSweep = 300000

--- Password migration

Config.MigrationInterval = 2000

--- Chat

Config.Chat = true
Config.WelcomeDelay = 4000

Config.Color = {
    Info = { 200, 200, 200 },
    Good = {  90, 200,  90 },
    Bad  = { 230,  90,  90 },
}

Config.Text = {
    WelcomeRegister = "Welcome. Use /register [user] [password] to create an account.",
    WelcomeLogin    = "Already registered? Use /login [user] [password].",
    UsageRegister   = "Usage: /register [user] [password]",
    UsageLogin      = "Usage: /login [user] [password]",
    Registered      = "Account created. Now use /login %s [password].",
    NameTaken       = "That name is already taken.",
    RegisterFailed  = "Could not create the account. Try again.",
    NameReserved    = "That name is reserved and cannot be registered.",
    NameTooLong     = "The user name is too long (max %d characters).",
    PasswordTooLong = "The password is too long (max %d characters).",
    LoggedIn        = "Logged in as %s.",
    LoginFailed     = "Wrong user or password.",
    AccountInUse    = "That account is already in use.",
    AlreadyLoggedIn = "You are already logged in. Use /logout first.",
    LoggedOut       = "Logged out.",
    NotLoggedIn     = "You are not logged in.",
    TooManyTries    = "Too many attempts. Wait a moment and try again.",
}

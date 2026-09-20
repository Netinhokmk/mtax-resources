resource_name    = "teams"
resource_version = "1.0.0"
resource_author  = "MTAX"

resource_info = {
    description = "MTAX - Teams",
    repository = "https://github.com/mtaxsa/mtax-resources",
}

shared_files = {
    ":mta/shared/warn.lua",
    ":mta/shared/teams.lua",
}

client_files = {
    "client/main.lua",
}

server_files = {
    "server/main.lua",
}

exports = {
    "createTeam",
    "setPlayerTeam",
    "setTeamName",
    "setTeamColor",
    "setTeamFriendlyFire",
}

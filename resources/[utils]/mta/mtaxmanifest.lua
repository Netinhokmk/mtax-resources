resource_name    = "mta"
resource_version = "1.4.0"
resource_author  = "MTAX:SA"

resource_info = {
    description = "MTAX - MTA:SA Compatibility Layer",
    repository = "https://github.com/mtaxsa/mtax-resources",
}

shared_files = {
    "shared/warn.lua",
    "shared/compat.lua",
    "shared/aliases.lua",
    "shared/teams.lua",
    "shared/radararea.lua",
}

client_files = {
    "client/compat.lua",
    "client/migration.lua",
    "client/core.lua",
    "client/widgets.lua",
    "client/radararea.lua",
    "client/bind_aliases.lua",
}

server_files = {
    "shared/migration.lua",
    "server/compat.lua",
    "server/migration.lua",
    "server/teams.lua",
    "shared/text.lua",
    "server/text.lua",
    "server/radararea.lua",
    "server/bind_aliases.lua",
}

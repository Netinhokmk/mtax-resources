resource_name    = "mta"
resource_version = "1.1.0"
resource_author  = "MTAX:SA"

resource_info = {
    description = "MTAX - MTA:SA Compatibility Layer",
    repository = "https://github.com/mtaxsa/mtax-resources",
}

shared_files = {
    "shared/compat.lua",
    "shared/aliases.lua",
}

client_files = {
    "client/compat.lua",
    "client/migration.lua",
    "client/core.lua",
    "client/widgets.lua",
    "client/bind_aliases.lua",
}

server_files = {
    "shared/migration.lua",
    "server/compat.lua",
    "server/migration.lua",
    "server/bind_aliases.lua",
}

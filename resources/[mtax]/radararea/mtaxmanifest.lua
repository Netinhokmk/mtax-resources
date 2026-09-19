resource_name    = "radararea"
resource_version = "1.0.0"
resource_author  = "MTAX"

resource_info = {
    description = "MTAX - Radar Areas",
    repository = "https://github.com/mtaxsa/mtax-resources",
}

shared_files = {
    ":mta/shared/warn.lua",
    ":mta/shared/radararea.lua",
}

client_files = {
    "client/main.lua",
}

server_files = {
    "server/main.lua",
}

exports = {
    "createRadarArea",
    "setRadarAreaSize",
    "setRadarAreaColor",
    "setRadarAreaFlashing",
}

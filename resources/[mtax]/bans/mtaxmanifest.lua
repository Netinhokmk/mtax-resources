resource_name    = "bans"
resource_version = "1.0.0"
resource_author  = "MTAX"

resource_info = {
    description = "MTAX - Server Bans",
    repository = "https://github.com/mtaxsa/mtax-resources",
}

shared_files = {
    "config.lua",
}

server_files = {
    "server/main.lua",
}

exports = {
    "addBan",
    "banPlayer",
    "removeBan",
    "getBans",
    "reloadBans",
    "isBan",
    "getBanIP",
    "getBanUsername",
    "getBanSerial",
    "getBanNick",
    "getBanReason",
    "getBanAdmin",
    "getBanTime",
    "getUnbanTime",
    "setUnbanTime",
    "setBanReason",
    "setBanAdmin",
    "setBanNick",
}

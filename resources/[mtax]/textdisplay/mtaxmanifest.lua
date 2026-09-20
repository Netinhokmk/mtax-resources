resource_name    = "textdisplay"
resource_version = "1.0.0"
resource_author  = "MTAX"

resource_info = {
    description = "MTAX - Text displays",
    repository = "https://github.com/mtaxsa/mtax-resources",
}

shared_files = {
    ":mta/shared/warn.lua",
    ":mta/shared/text.lua",
}

client_files = {
    "client/main.lua",
}

server_files = {
    "server/main.lua",
}

exports = {
    "textCreateDisplay",
    "textDestroyDisplay",
    "textCreateTextItem",
    "textDestroyTextItem",
    "textDisplayAddText",
    "textDisplayRemoveText",
    "textDisplayAddObserver",
    "textDisplayRemoveObserver",
    "textItemSetText",
    "textItemSetScale",
    "textItemSetPosition",
    "textItemSetColor",
    "textItemSetPriority",
}

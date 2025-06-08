fx_version 'cerulean'
game 'gta5'

author 'Muffin'
description 'QBCore Spike Strip System'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'qb-core',
    'qb-target'
}

lua54 'yes'

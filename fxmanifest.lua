fx_version 'cerulean'
game 'gta5'
lua54 'yes'


author 'Djonza'

version '1.0.0'

description 'Invoices'

server_script 'server.lua'

client_script 'client.lua'

shared_scripts {'@es_extended/imports.lua', '@ox_lib/init.lua', 'config.lua'}

files {
    'nui/index.html',
    'nui/style.css',
    'nui/script.js',
    'locales/*.json',
}

ui_page 'nui/index.html'

dependencies {
    'oxmysql',
    'es_extended',
    'ox_lib',
    'ox_target',
}

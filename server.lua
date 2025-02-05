local ox = exports['oxmysql']

lib.locale()

local function getPlayerIdentifier(playerId)
    for _, identifier in ipairs(GetPlayerIdentifiers(playerId)) do
        if string.match(identifier, "license:") then
            return identifier
        end
    end
    return nil
end

function getPlayerIdFromLicense(license)
    for _, playerId in ipairs(GetPlayers()) do 
        local identifiers = GetPlayerIdentifiers(playerId) 
        for _, id in ipairs(identifiers) do
            if id == license then
                return playerId 
            end
        end
    end
    return nil  
end



RegisterNetEvent('d-invoices:createBill')
AddEventHandler('d-invoices:createBill', function(playerId, amount, reason, comment)
    local src = source
    local playerName = GetPlayerName(src)
    local identifier = getPlayerIdentifier(playerId)
    local xPlayer = ESX.GetPlayerFromId(src)
    local playerJob = xPlayer.job.name 
    local receiverName = GetPlayerName(playerId)
    if identifier then
        exports.oxmysql:insert("INSERT INTO billing (sender, receiver, receiver_name, amount, reason, comment, status, organization, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())", {
            playerName, identifier, receiverName, amount, reason, comment, 'Unpaid', playerJob 
        }, function(id)
            if id then
                exports.oxmysql:execute("SELECT id, amount, status, created_at, organization FROM billing WHERE receiver = ? AND status = 'Unpaid'", {identifier}, function(bills)
                    TriggerClientEvent('d-invoices:client:receiveBills', src, bills)
                end)
                exports.oxmysql:execute("SELECT id, amount, status, created_at, organization FROM billing WHERE receiver = ?", {identifier}, function(history)
                    TriggerClientEvent('d-invoices:client:receiveHistory', src, history)
                end)
                TriggerClientEvent('ox_lib:notify', src, {
                    title = locale('title'),
                    description = locale('bill_created'),
                    type = "success"
                })
                TriggerClientEvent('ox_lib:notify', playerId, {
                    title = locale('title'),
                    description = locale("you_have_been_fined"),
                    type = "info"
                })
                local message = string.format("**Bill Created**\n**Sender:** %s\n**Receiver:** %s\n**Reason:** %s\n**Amount:** %s\n**Comment:** %s", playerName, receiverName, reason, amount, comment)
                SendToDiscord(Config.DiscordWebhook.Invoices, 'Bill created', message, 65280) 

            else
                TriggerClientEvent('ox_lib:notify', src, {
                    title = locale('title'),
                    description = locale('failed_to_create'),
                    type = "error"
                })
            end
        end)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('title'),
            description = locale('no_identifier'),
            type = "error"
        })
    end
end)

RegisterNetEvent('d-invoices:fetchDashboardInfo')
AddEventHandler('d-invoices:fetchDashboardInfo', function()
    local src = source
    local identifier = getPlayerIdentifier(src)  

    if identifier then
        ox:execute("SELECT COUNT(*) AS totalBills FROM billing WHERE receiver = ?", {identifier}, function(totalResult)
            local totalBills = totalResult[1].totalBills or 0

            ox:execute("SELECT COUNT(*) AS paidBills FROM billing WHERE receiver = ? AND status = 'Paid'", {identifier}, function(paidResult)
                local paidBills = paidResult[1].paidBills or 0

                ox:execute("SELECT COUNT(*) AS unpaidBills FROM billing WHERE receiver = ? AND status = 'Unpaid'", {identifier}, function(unpaidResult)
                    local unpaidBills = unpaidResult[1].unpaidBills or 0

                    TriggerClientEvent('d-invoices:client:receiveDashboardInfo', src, {
                        totalBills = totalBills,
                        paidBills = paidBills,
                        unpaidBills = unpaidBills
                    })
                end)
            end)
        end)
    end
end)

RegisterNetEvent('d-invoices:fetchBills')
AddEventHandler('d-invoices:fetchBills', function()
    local src = source
    local identifier = getPlayerIdentifier(src)

    if identifier then
        exports.oxmysql:execute("SELECT * FROM billing WHERE receiver = ? AND status = 'Unpaid'", {identifier}, function(bills)
            TriggerClientEvent('d-invoices:client:receiveBills', src, bills)
        end)
    end
end)

RegisterNetEvent('d-invoices:fetchHistory')
AddEventHandler('d-invoices:fetchHistory', function()
    local src = source
    local identifier = getPlayerIdentifier(src)

    if identifier then
        exports.oxmysql:execute("SELECT id, amount, status, created_at, reason, organization FROM billing WHERE receiver = ?", {identifier}, function(history)
            if history then
                TriggerClientEvent('d-invoices:client:receiveHistory', src, history) 
            end
        end)
    end
end)

RegisterNetEvent('d-invoices:payBill')
AddEventHandler('d-invoices:payBill', function(billId)
    local src = source
    local identifier = getPlayerIdentifier(src)

    ox:execute("SELECT amount, organization FROM billing WHERE id = ? AND receiver = ?", {billId, identifier}, function(result)
        if result and #result > 0 then
            local amount = result[1].amount
            local organization = result[1].organization
            local xPlayer = ESX.GetPlayerFromId(src)
            local money = Config.UseBank and xPlayer.getAccount('bank').money or xPlayer.getMoney()

            if money >= amount then
                if Config.UseBank then
                    xPlayer.removeAccountMoney('bank', amount)
                else
                    xPlayer.removeMoney(amount)
                end

                local societyAccount = nil
                for _, job in pairs(Config.AllowedJobs) do
                    if job.job == organization then
                        societyAccount = job.society
                        break
                    end
                end

                if societyAccount then
                    TriggerEvent('esx_addonaccount:getSharedAccount', societyAccount, function(account)
                        if account then
                            account.addMoney(amount) -- Add money to the society account
                        end
                    end)
                end

                ox:execute("UPDATE billing SET status = 'Paid' WHERE id = ?", {billId}, function(affectedRows)
                    if affectedRows then
                        ox:execute("SELECT id, amount, status, created_at FROM billing WHERE receiver = ? AND status = 'Unpaid'", {identifier}, function(bills)
                            TriggerClientEvent('d-invoices:client:receiveBills', src, bills)
                        end)

                        ox:execute("SELECT id, amount, status, created_at FROM billing WHERE receiver = ?", {identifier}, function(history)
                            TriggerClientEvent('d-invoices:client:receiveHistory', src, history)
                        end)

                        TriggerClientEvent('ox_lib:notify', src, {
                            title = locale('title'),
                            description = locale('paid'),
                            type = "success"
                        })
                        local playerName = GetPlayerName(src)
                        local message = string.format("\n**Paid by:** %s\n**Amount:** %s\n**Sent to:** %s", playerName, amount, societyAccount)
                        SendToDiscord(Config.DiscordWebhook.Invoices, 'Bill paid', message, 65280)
                    else
                        TriggerClientEvent('ox_lib:notify', src, {
                            title = locale('title'),
                            description = locale('failed_to_pay'),
                            type = "error"
                        })
                    end
                end)
            else
                TriggerClientEvent('ox_lib:notify', src, {
                    title = locale('title'),
                    description = locale('no_money'),
                    type = "error"
                })
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('title'),
                description = locale("bill_invalid"),
                type = "error"
            })
        end
    end)
end)

RegisterNetEvent('d-invoices:cancelInvoice')
AddEventHandler('d-invoices:cancelInvoice', function(invoiceId, amount, reason, comment)
    local src = source
    MySQL.update('UPDATE billing SET status = "Paid" WHERE id = ?', {invoiceId}, function(affectedRows)
        if affectedRows > 0 then
            local invoices = MySQL.query.await('SELECT * FROM billing WHERE id = ?', {invoiceId})

            if #invoices > 0 then
                local invoice = invoices[1]
                local receiverName = invoice.receiver_name
                local sender = invoice.sender
                local reason = invoice.reason
                local amount = invoice.amount
                local comment = invoice.comment
                local organization = invoice.organization

                local message = string.format("**Sender:** %s\n**Receiver:** %s\n**Reason:** %s\n**Amount:** %s\n**Comment:** %s\n**Organization:** %s", 
                    sender, receiverName, reason, amount, comment, organization)

                SendToDiscord(Config.DiscordWebhook.Invoices, 'Bill cancelled', message, 65280)
                TriggerClientEvent('ox_lib:notify', src, {
                    title = locale('title'),
                    description = locale("invoice_canceled"),
                    type = "info"
                })
            else
                TriggerClientEvent('ox_lib:notify', src, {
                    title = locale('title'),
                    description = locale("invoice_not_found"),
                    type = "info"
                })
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('title'),
                description = locale("failed_to_update"),
                type = "info"
            })
        end
    end)
end)


lib.callback.register('d-invoices:getAllPlayerData', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { error = 'Player not found' } end

    local playerJob = xPlayer.job.name
    local invoices = MySQL.query.await("SELECT * FROM billing WHERE status = 'Unpaid' AND organization = ?", {playerJob})

    for i = 1, #invoices do
        local receiverName = invoices[i].receiver_name 
        invoices[i].receiver = receiverName  
    end

    return invoices  
end)




function SendToDiscord(webhook, title, message, color)
    local embed = {
        {
            ["title"] = title,
            ["description"] = message,
            ["color"] = color, 
            ["footer"] = {
                ["text"] = os.date("%Y-%m-%d %H:%M:%S"), 
            },
        }
    }

    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({
        username = "Djonza Invoices", 
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

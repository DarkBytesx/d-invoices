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

RegisterNetEvent('billing:createBill')
AddEventHandler('billing:createBill', function(playerId, amount, reason, comment)
    local src = source
    local playerName = GetPlayerName(src)
    local identifier = getPlayerIdentifier(playerId)

    local xPlayer = ESX.GetPlayerFromId(src)
    local playerJob = xPlayer.job.name 

    if identifier then
        exports.oxmysql:insert("INSERT INTO billing (sender, receiver, amount, reason, comment, status, organization, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())", {
            playerName, identifier, amount, reason, comment, 'Unpaid', playerJob 
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

RegisterNetEvent('billing:fetchDashboardInfo')
AddEventHandler('billing:fetchDashboardInfo', function()
    local src = source
    local identifier = getPlayerIdentifier(src)  

    if identifier then
        ox:execute("SELECT COUNT(*) AS totalBills FROM billing WHERE receiver = ?", {identifier}, function(totalResult)
            local totalBills = totalResult[1].totalBills or 0

            ox:execute("SELECT COUNT(*) AS paidBills FROM billing WHERE receiver = ? AND status = 'Paid'", {identifier}, function(paidResult)
                local paidBills = paidResult[1].paidBills or 0

                ox:execute("SELECT COUNT(*) AS unpaidBills FROM billing WHERE receiver = ? AND status = 'Unpaid'", {identifier}, function(unpaidResult)
                    local unpaidBills = unpaidResult[1].unpaidBills or 0

                    TriggerClientEvent('billing:receiveDashboardInfo', src, {
                        totalBills = totalBills,
                        paidBills = paidBills,
                        unpaidBills = unpaidBills
                    })
                end)
            end)
        end)
    end
end)

RegisterNetEvent('billing:fetchBills')
AddEventHandler('billing:fetchBills', function()
    local src = source
    local identifier = getPlayerIdentifier(src)

    if identifier then
        exports.oxmysql:execute("SELECT * FROM billing WHERE receiver = ? AND status = 'Unpaid'", {identifier}, function(bills)
            TriggerClientEvent('d-invoices:client:receiveBills', src, bills)
        end)
    end
end)

RegisterNetEvent('billing:fetchHistory')
AddEventHandler('billing:fetchHistory', function()
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


RegisterNetEvent('billing:payBill')
AddEventHandler('billing:payBill', function(billId)
    local src = source
    local identifier = getPlayerIdentifier(src)
    
    ox:execute("SELECT amount, organization FROM billing WHERE id = ? AND receiver = ?", {billId, identifier}, function(result)
        if result and #result > 0 then
            local amount = result[1].amount
            local xPlayer = ESX.GetPlayerFromId(src)
            local money = xPlayer.getMoney() 

            if money >= amount then
                xPlayer.removeMoney(amount)
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

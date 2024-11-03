lib.locale()

local function hasRequiredJob()
    local xPlayer = ESX.GetPlayerData() 

    for _, job in ipairs(Config.AllowedJobs) do
        if xPlayer.job and xPlayer.job.name == job then
            return true 
        end
    end
    
    return false
end


exports.ox_target:addModel(Config.Banks, {
    {
        icon = "fas fa-credit-card",
        label = locale('access_invoices'),
        distance = 2,
        onSelect = function()
            TriggerServerEvent('billing:fetchBills')
            TriggerServerEvent('billing:fetchHistory')
            TriggerServerEvent('billing:fetchDashboardInfo')
            SetNuiFocus(true, true)
            SendNUIMessage({
                type = 'showInvoiceMenu'
            })
        end,
    },
})


RegisterCommand(Config.makeInvoicesCommand, function()
    if hasRequiredJob() then
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'showCreateBillMenu'
    })
else
    lib.notify({
        title = locale('title'),
        description = locale('no_permission'),
        type = 'error'
    })
end
end, false)

RegisterNUICallback('submitBill', function(data, cb)
    local playerId = tonumber(data.playerId)
    local reason = data.reason
    local amount = tonumber(data.amount)
    local comment = data.comment
    TriggerServerEvent('billing:createBill', playerId, amount, reason, comment)
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'hideInvoiceMenu'
    })
    cb('ok')
end)


RegisterNetEvent('billing:receiveDashboardInfo')
AddEventHandler('billing:receiveDashboardInfo', function(data)
    SendNUIMessage({
        type = 'updateDashboard',
        playerId = data.playerId,
        totalBills = data.totalBills,
        paidBills = data.paidBills,
        unpaidBills = data.unpaidBills
    })
end)

RegisterNetEvent('d-invoices:client:receiveBills')
AddEventHandler('d-invoices:client:receiveBills', function(bills)
    SendNUIMessage({
        type = 'updateYourBillings',
        bills = bills
    })
end)

RegisterNetEvent('d-invoices:client:receiveHistory')
AddEventHandler('d-invoices:client:receiveHistory', function(history)
    SendNUIMessage({
        type = 'updateHistory',
        history = history
    })
end)

RegisterNUICallback('payBill', function(data, cb)
    local billId = tonumber(data.billId)
    TriggerServerEvent('billing:payBill', billId)
    cb('ok')
end)

RegisterNUICallback('fetchBills', function(data, cb)
    TriggerServerEvent('billing:fetchBills')
    cb('ok')
end)

RegisterNUICallback('fetchHistory', function(data, cb)
    TriggerServerEvent('billing:fetchHistory')
    cb('ok')
end)

RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)


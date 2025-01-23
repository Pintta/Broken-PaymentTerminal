local QBCore = exports['qb-core']:GetCoreObject()

-- Maksutapa
RegisterServerEvent('Broken-PaymentTerminal:handlePayment')
AddEventHandler('Broken-PaymentTerminal:handlePayment', function(paymentMethod)
    local payerId = source
    local amount = invoiceAmount
    if paymentMethod == "cash" then
        -- Käteismaksu: Vähennetään käteisvarat
        local player = QBCore.Functions.GetPlayer(payerId)
        local cash = player.PlayerData.money['cash']
        if cash >= amount then
            -- Poistetaan rahaa maksajalta ja lisätään maksunluojalle
            player.Functions.RemoveMoney('cash', amount)
            local creator = QBCore.Functions.GetPlayer(invoiceCreator)
            creator.Functions.AddMoney('cash', amount)
            TriggerClientEvent('QBCore:Notify', payerId, "Maksu suoritettu käteisellä", "success")
            TriggerClientEvent('QBCore:Notify', invoiceCreator, GetPlayerName(payerId) .. " on maksanut laskun", "success")
        else
            TriggerClientEvent('QBCore:Notify', payerId, "Sinulla ei ole tarpeeksi käteistä", "error")
        end
    elseif paymentMethod == "bank" then
        -- Pankkimaksu: Vähennetään pelaajan pankkitililtä
        local player = QBCore.Functions.GetPlayer(payerId)
        local bank = player.PlayerData.money['bank']

        if bank >= amount then
            -- Poistetaan rahaa pankkitililtä maksajalta ja lisätään maksunluojalle
            player.Functions.RemoveMoney('bank', amount)
            local creator = QBCore.Functions.GetPlayer(invoiceCreator)
            creator.Functions.AddMoney('cash', amount)
            TriggerClientEvent('QBCore:Notify', payerId, "Maksu suoritettu pankkitililtä", "success")
            TriggerClientEvent('QBCore:Notify', invoiceCreator, GetPlayerName(payerId) .. " on maksanut laskun", "success")
        else
            TriggerClientEvent('QBCore:Notify', payerId, "Sinulla ei ole tarpeeksi rahaa pankkitilillä", "error")
        end
    end
end)
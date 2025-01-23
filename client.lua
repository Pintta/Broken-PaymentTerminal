local QBCore = exports['qb-core']:GetCoreObject()
-- Laskutustiedot
local invoiceAmount = 0
local invoiceCreator = ""
local invoiceReceiver = nil
-- Tablet animaatiot
local tabletAnimDict = "amb@prop_human_tablet@idle_a"
local tabletAnimName = "idle_a"
-- Käteismaksu animaatiot
local giveMoneyAnimDict = "mp_common"
local giveMoneyAnimName = "givetake2_a"
local takeMoneyAnimDict = "anim@mp_player_intcelebrationmale@money_wave"
local takeMoneyAnimName = "money_wave"
-- Pankkimaksu animaatio (puhelimen käyttö)
local phoneAnimDict = "cellphone@"
local phoneAnimName = "cellphone_text_read_base"

-- Näytetään laskutiedot laskuttajalle (ensimmäinen vaihe)
RegisterCommand('createinvoice', function(source, args, rawCommand)
    local creator = source -- Laskuttaja on se pelaaja, joka komennon laukaisee
    local amount = tonumber(args[1]) -- Maksun määrä tulee komennon argumentista
    if amount and amount > 0 then
        invoiceAmount = amount
        invoiceCreator = creator
        -- Hae kaikki pelaajat lähialueelta (10 metrin säteellä)
        local nearbyPlayers = {}
        local creatorCoords = GetEntityCoords(GetPlayerPed(creator))
        local players = QBCore.Functions.GetPlayers()
        for _, playerId in pairs(players) do
            if playerId ~= creator then
                local playerPed = GetPlayerPed(playerId)
                local playerCoords = GetEntityCoords(playerPed)
                local distance = #(creatorCoords - playerCoords)

                if distance <= 10.0 then -- 10 metrin säteellä
                    table.insert(nearbyPlayers, playerId)
                end
            end
        end
        if #nearbyPlayers > 0 then
            -- Näytetään valikko, jossa maksunluoja voi valita laskutettavan pelaajan
            TriggerClientEvent('Broken-PaymentTerminal:openInvoiceCreatorMenu', creator, invoiceAmount, nearbyPlayers)
            -- Animaatio: Tabletin käyttö maksunluojalle
            TriggerClientEvent('Broken-PaymentTerminal:startTabletAnimation', creator)
        else
            TriggerClientEvent('QBCore:Notify', creator, "Ei löytynyt lähistöllä olevia pelaajia", "error")
        end
    else
        TriggerClientEvent('QBCore:Notify', creator, "Syötä kelvollinen summa", "error")
    end
end)

-- Maksajan valikon näyttäminen (toinen vaihe)
RegisterServerEvent('Broken-PaymentTerminal:showInvoiceForPayer')
AddEventHandler('Broken-PaymentTerminal:showInvoiceForPayer', function(payerId)
    local creator = invoiceCreator
    local amount = invoiceAmount
    if creator and amount then
        TriggerClientEvent('Broken-PaymentTerminal:openInvoiceForPayerMenu', payerId, creator, amount)
        -- Animaatio: Tabletin käyttö maksajalle
        TriggerClientEvent('Broken-PaymentTerminal:startTabletAnimation', payerId)
    end
end)

-- Maksutavan käsittely
RegisterServerEvent('Broken-PaymentTerminal:handlePayment')
AddEventHandler('Broken-PaymentTerminal:handlePayment', function(paymentMethod)
    local payerId = source
    local amount = invoiceAmount
    if paymentMethod == "cash" then
        -- Käteismaksu: Vähennetään käteisvarat
        local player = QBCore.Functions.GetPlayer(payerId)
        local cash = player.PlayerData.money['cash']
        if cash >= amount then
            -- Animaatio: Maksaja antaa käteistä
            TriggerClientEvent('Broken-PaymentTerminal:startGiveMoneyAnimation', payerId)
            -- Animaatio: Maksunluoja vastaanottaa käteistä
            TriggerClientEvent('Broken-PaymentTerminal:startTakeMoneyAnimation', invoiceCreator)
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
            -- Animaatio: Maksunluoja saa puhelimen käteen (puhelin animaatio)
            TriggerClientEvent('Broken-PaymentTerminal:startPhoneAnimation', invoiceCreator)
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

-- QB-Menu näyttö maksajalle
RegisterNetEvent('Broken-PaymentTerminal:openInvoiceForPayerMenu')
AddEventHandler('Broken-PaymentTerminal:openInvoiceForPayerMenu', function(creator, amount)
    local menu = {
        {
            header = "Maksun tiedot",
            txt = "Laskuttaja: " .. creator .. "\nMäärä: " .. amount .. "$",
            icon = "fa-solid fa-file-invoice", -- Ikoni laskun tiedoille
            params = { event = "" }
        }, {
            header = "Valitse maksutapa",
            txt = "Valitse, maksatko käteisellä vai pankilla",
            icon = "fa-solid fa-credit-card", -- Ikoni maksutavoista
            params = {
                event = "Broken-PaymentTerminal:selectPaymentMethod"
            }
        }
    }
    TriggerEvent('qb-menu:openMenu', menu)
end)

-- Maksutavan valinta
RegisterNetEvent('Broken-PaymentTerminal:selectPaymentMethod')
AddEventHandler('Broken-PaymentTerminal:selectPaymentMethod', function()
    local menu = {
        {
            header = "Maksutapa",
            txt = "Valitse maksutapa",
            icon = "fa-solid fa-money-bill-wave", -- Maksutapa ikoni
            params = {
                event = "Broken-PaymentTerminal:confirmPaymentMethod"
            }
        }, {
            header = "Käteinen",
            txt = "Maksaa käteisellä",
            icon = "fa-solid fa-coins", -- Ikoni käteiselle
            params = {
                event = "Broken-PaymentTerminal:handlePayment",
                args = "cash"
            }
        }, {
            header = "Pankki",
            txt = "Maksaa pankkitililtä",
            icon = "fa-solid fa-university", -- Ikoni pankille
            params = {
                event = "Broken-PaymentTerminal:handlePayment",
                args = "bank"
            }
        }
    }
    TriggerEvent('qb-menu:openMenu', menu)
end)

-- Laskutiedot ja maksutapa valitaan pelaajalle
RegisterNetEvent('Broken-PaymentTerminal:handlePayment')
AddEventHandler('Broken-PaymentTerminal:handlePayment', function(method)
    TriggerServerEvent('Broken-PaymentTerminal:handlePayment', method)
end)

-- Maksunluojalle lähimpien pelaajien valinta
RegisterNetEvent('Broken-PaymentTerminal:openInvoiceCreatorMenu')
AddEventHandler('Broken-PaymentTerminal:openInvoiceCreatorMenu', function(creator, amount, nearbyPlayers)
    local playerNames = {}
    for _, playerId in pairs(nearbyPlayers) do
        local playerName = GetPlayerName(playerId)
        table.insert(playerNames, {header = playerName, txt = "Valitse " .. playerName, params = {event = 'Broken-PaymentTerminal:setInvoiceReceiver', args = playerId}})
    end
    local menu = {
        {
            header = "Lasku: " .. amount .. "$",
            txt = "Valitse pelaaja, jolle haluat lähettää laskun",
            icon = "fa-solid fa-user-plus", -- Ikoni pelaajalle
            params = {
                event = ""
            }
        },
        table.unpack(playerNames)
    }
    TriggerEvent('qb-menu:openMenu', menu)
end)

-- Maksun vastaanottajan valinta
RegisterNetEvent('Broken-PaymentTerminal:setInvoiceReceiver')
AddEventHandler('Broken-PaymentTerminal:setInvoiceReceiver', function(receiverId)
    invoiceReceiver = receiverId
    TriggerClientEvent('QBCore:Notify', invoiceCreator, "Lasku asetettu pelaajalle: " .. GetPlayerName(receiverId), "success")
end)

-- Tablet animaatio aloitus
RegisterNetEvent('Broken-PaymentTerminal:startTabletAnimation')
AddEventHandler('Broken-PaymentTerminal:startTabletAnimation', function(playerId)
    local playerPed = GetPlayerPed(playerId)
    RequestAnimDict(tabletAnimDict)
    while not HasAnimDictLoaded(tabletAnimDict) do
        Wait(100)
    end
    TaskPlayAnim(playerPed, tabletAnimDict, tabletAnimName, 8.0, -8.0, -1, 50, 0, false, false, false)
end)

-- Tablet animaation poistaminen
RegisterNetEvent('Broken-PaymentTerminal:stopTabletAnimation')
AddEventHandler('Broken-PaymentTerminal:stopTabletAnimation', function(playerId)
    local playerPed = GetPlayerPed(playerId)
    ClearPedTasksImmediately(playerPed)
end)

-- Animaatio käteismaksun antamiselle (maksaja)
RegisterNetEvent('Broken-PaymentTerminal:startGiveMoneyAnimation')
AddEventHandler('Broken-PaymentTerminal:startGiveMoneyAnimation', function(playerId)
    local playerPed = GetPlayerPed(playerId)
    RequestAnimDict(giveMoneyAnimDict)
    while not HasAnimDictLoaded(giveMoneyAnimDict) do
        Wait(100)
    end
    TaskPlayAnim(playerPed, giveMoneyAnimDict, giveMoneyAnimName, 8.0, -8.0, -1, 50, 0, false, false, false)
end)

-- Animaatio käteismaksun vastaanottamiselle (maksunluoja)
RegisterNetEvent('Broken-PaymentTerminal:startTakeMoneyAnimation')
AddEventHandler('Broken-PaymentTerminal:startTakeMoneyAnimation', function(playerId)
    local playerPed = GetPlayerPed(playerId)
    RequestAnimDict(takeMoneyAnimDict)
    while not HasAnimDictLoaded(takeMoneyAnimDict) do
        Wait(100)
    end
    TaskPlayAnim(playerPed, takeMoneyAnimDict, takeMoneyAnimName, 8.0, -8.0, -1, 50, 0, false, false, false)
end)

-- Pankkimaksun animaatio (puhelimen käyttö)
RegisterNetEvent('Broken-PaymentTerminal:startPhoneAnimation')
AddEventHandler('Broken-PaymentTerminal:startPhoneAnimation', function(playerId)
    local playerPed = GetPlayerPed(playerId)
    RequestAnimDict(phoneAnimDict)
    while not HasAnimDictLoaded(phoneAnimDict) do
        Wait(100)
    end
    TaskPlayAnim(playerPed, phoneAnimDict, phoneAnimName, 8.0, -8.0, -1, 50, 0, false, false, false)
end)
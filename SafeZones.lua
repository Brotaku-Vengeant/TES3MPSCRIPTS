--[[
    safeZones.lua - TES3MP 0.8.1
    Safe zone management module.
    Depends on: zoneCore.lua
--]]

if not ZoneCore then
    tes3mp.LogMessage(2, "[SafeZones] ERROR: ZoneCore must be loaded first!")
    return
end

local color = require("color")

----------------------------------------------
-- MODULE SETUP
----------------------------------------------

local SafeZones = {
    data = {},
    zones = {}
}

local DATA_FILE = "SafeData.json"

----------------------------------------------
-- CONFIGURATION
----------------------------------------------

SafeZones.config = {
    defaultMessages = {
        entering = "You have entered a safe zone. PvP is prohibited.",
        exiting = "You have left the safe zone."
    },
    defaultColors = {
        enter = color.Blue,
        exit = color.Red
    },
    defaultDropFlags = {
        pvp = false,
        pve = true,
        suicide = false
    }
}

----------------------------------------------
-- PERSISTENCE
----------------------------------------------

local function loadData()
    SafeZones.data = ZoneCore.LoadJSON(DATA_FILE)
    SafeZones.zones = {}
    
    for zoneName, zoneData in pairs(SafeZones.data) do
        if type(zoneData) == "table" and zoneData.custom then
            table.insert(SafeZones.zones, zoneData)
        end
    end
    
    ZoneCore.LogInfo("SafeZones: Loaded " .. #SafeZones.zones .. " zones")
end

local function saveData()
    ZoneCore.SaveJSON(DATA_FILE, SafeZones.data)
end

----------------------------------------------
-- ZONE LOOKUP
----------------------------------------------

function SafeZones.GetPlayerZone(pid)
    if not ZoneCore.IsValidPlayer(pid) then
        return nil
    end
    
    local cell = ZoneCore.GetPlayerCell(pid)
    if not cell then
        return nil
    end
    
    for _, zone in ipairs(SafeZones.zones) do
        if zone.exteriorCells then
            for _, ex in ipairs(zone.exteriorCells) do
                if cell == ex then
                    return zone
                end
            end
        end
        if zone.interiorCellHeaders then
            for _, header in ipairs(zone.interiorCellHeaders) do
                if cell:match(header) then
                    return zone
                end
            end
        end
    end
    
    return nil
end

function SafeZones.IsInSafeZone(pid)
    return SafeZones.GetPlayerZone(pid) ~= nil
end

function SafeZones.GetDropFlags(pid)
    local zone = SafeZones.GetPlayerZone(pid)
    if zone and zone.dropFlags then
        return zone.dropFlags
    end
    return nil
end

----------------------------------------------
-- ZONE MANAGEMENT
----------------------------------------------

function SafeZones.CreateZone(pid, zoneName)
    if not ZoneCore.IsAdmin(pid) then
        ZoneCore.SendMessage(pid, "You do not have permission to use this command.")
        return false
    end
    
    if not zoneName or zoneName == "" then
        ZoneCore.SendMessage(pid, "Usage: /createsafezone \"Zone Name\"")
        return false
    end
    
    local currentCell = ZoneCore.GetPlayerCell(pid)
    if not currentCell then
        ZoneCore.SendMessage(pid, "You are not in a valid cell.")
        return false
    end
    
    local isExterior = ZoneCore.IsExteriorCell(currentCell)
    
    if SafeZones.data[zoneName] then
        local existingZone = SafeZones.data[zoneName]
        
        if isExterior then
            if not existingZone.exteriorCells then
                existingZone.exteriorCells = {}
            end
            
            local cellExists = false
            for _, cell in ipairs(existingZone.exteriorCells) do
                if cell == currentCell then
                    cellExists = true
                    break
                end
            end
            
            if not cellExists then
                table.insert(existingZone.exteriorCells, currentCell)
            end
        else
            if not existingZone.interiorCellHeaders then
                existingZone.interiorCellHeaders = {}
            end
            
            local headerExists = false
            for _, header in ipairs(existingZone.interiorCellHeaders) do
                if currentCell:match(header) then
                    headerExists = true
                    break
                end
            end
            
            if not headerExists then
                table.insert(existingZone.interiorCellHeaders, currentCell)
            end
        end
        
        SafeZones.data[zoneName] = existingZone
        saveData()
        ZoneCore.SendMessage(pid, "Merged current cell (" .. currentCell .. ") with existing safe zone \"" .. zoneName .. "\".")
        return true
    end
    
    local newZone = {
        name = zoneName,
        exteriorCells = {},
        interiorCellHeaders = {},
        dropFlags = {
            pvp = SafeZones.config.defaultDropFlags.pvp,
            pve = SafeZones.config.defaultDropFlags.pve,
            suicide = SafeZones.config.defaultDropFlags.suicide
        },
        messages = {
            entering = SafeZones.config.defaultMessages.entering,
            exiting = SafeZones.config.defaultMessages.exiting
        },
        msgColors = {
            enter = SafeZones.config.defaultColors.enter,
            exit = SafeZones.config.defaultColors.exit
        },
        custom = true
    }
    
    if isExterior then
        newZone.exteriorCells[1] = currentCell
    else
        newZone.interiorCellHeaders[1] = currentCell
    end
    
    table.insert(SafeZones.zones, newZone)
    SafeZones.data[zoneName] = newZone
    saveData()
    
    ZoneCore.SendMessage(pid, "Safe zone \"" .. zoneName .. "\" created in cell: " .. currentCell)
    ZoneCore.LogInfo("SafeZones: Created zone '" .. zoneName .. "' by admin")
    return true
end

function SafeZones.RemoveZone(pid)
    if not ZoneCore.IsAdmin(pid) then
        ZoneCore.SendMessage(pid, "You do not have permission to use this command.")
        return false
    end
    
    local currentCell = ZoneCore.GetPlayerCell(pid)
    if not currentCell then
        ZoneCore.SendMessage(pid, "You are not in a valid cell.")
        return false
    end
    
    local isExterior = ZoneCore.IsExteriorCell(currentCell)
    local removed = false
    
    for i = #SafeZones.zones, 1, -1 do
        local zone = SafeZones.zones[i]
        local match = false
        
        if isExterior and zone.exteriorCells then
            for _, cell in ipairs(zone.exteriorCells) do
                if cell == currentCell then
                    match = true
                    break
                end
            end
        elseif not isExterior and zone.interiorCellHeaders then
            for _, header in ipairs(zone.interiorCellHeaders) do
                if currentCell:match(header) then
                    match = true
                    break
                end
            end
        end
        
        if match then
            SafeZones.data[zone.name] = nil
            table.remove(SafeZones.zones, i)
            removed = true
            ZoneCore.LogInfo("SafeZones: Removed zone '" .. zone.name .. "'")
            break
        end
    end
    
    if removed then
        saveData()
        ZoneCore.SendMessage(pid, "Safe zone for cell \"" .. currentCell .. "\" removed.")
        return true
    else
        ZoneCore.SendMessage(pid, "No safe zone found for cell \"" .. currentCell .. "\".")
        return false
    end
end

function SafeZones.ClearAllZones(pid)
    if not ZoneCore.IsAdmin(pid) then
        ZoneCore.SendMessage(pid, "You do not have permission to use this command.")
        return false
    end
    
    SafeZones.zones = {}
    SafeZones.data = {}
    saveData()
    
    ZoneCore.SendMessage(pid, "All safe zones have been removed from the server.")
    ZoneCore.LogInfo("SafeZones: All zones cleared by admin")
    return true
end

function SafeZones.ListZones(pid)
    if not ZoneCore.IsAdmin(pid) then
        ZoneCore.SendMessage(pid, "You do not have permission to use this command.")
        return
    end
    
    if #SafeZones.zones == 0 then
        ZoneCore.SendMessage(pid, "No safe zones found.")
        return
    end
    
    ZoneCore.SendMessage(pid, "=== Safe Zones ===")
    for _, zone in ipairs(SafeZones.zones) do
        local cellCount = 0
        if zone.exteriorCells then
            cellCount = cellCount + #zone.exteriorCells
        end
        if zone.interiorCellHeaders then
            cellCount = cellCount + #zone.interiorCellHeaders
        end
        ZoneCore.SendMessage(pid, "- " .. zone.name .. " (" .. cellCount .. " cells)")
    end
end

----------------------------------------------
-- CELL CHANGE NOTIFICATIONS
----------------------------------------------

local playerNotifications = {}

local function onCellChange(pid)
    if not ZoneCore.IsValidPlayer(pid) then
        return
    end
    
    local zone = SafeZones.GetPlayerZone(pid)
    local playerName = Players[pid].accountName or tostring(pid)
    
    if zone then
        if not playerNotifications[playerName] or playerNotifications[playerName] ~= zone.name then
            ZoneCore.SendMessage(pid, zone.msgColors.enter .. zone.messages.entering)
            playerNotifications[playerName] = zone.name
        end
    elseif playerNotifications[playerName] then
        ZoneCore.SendMessage(pid, color.White .. "You have left " .. playerNotifications[playerName] .. ".")
        playerNotifications[playerName] = nil
    end
end

----------------------------------------------
-- COMMAND REGISTRATION
----------------------------------------------

customCommandHooks.registerCommand("createsafezone", function(pid, cmd)
    local zoneName = table.concat(cmd, " ", 2)
    SafeZones.CreateZone(pid, zoneName)
end)

customCommandHooks.registerCommand("removesafezone", function(pid, cmd)
    SafeZones.RemoveZone(pid)
end)

customCommandHooks.registerCommand("clearsafezones", function(pid, cmd)
    SafeZones.ClearAllZones(pid)
end)

customCommandHooks.registerCommand("listsafezones", function(pid, cmd)
    SafeZones.ListZones(pid)
end)

----------------------------------------------
-- EVENT HANDLERS
----------------------------------------------

customEventHooks.registerHandler("OnPlayerCellChange", function(eventStatus, pid, previousCellDescription, currentCellDescription)
    onCellChange(pid)
end)

customEventHooks.registerHandler("OnServerPostInit", function(eventStatus)
    loadData()
end)

customEventHooks.registerHandler("OnServerExit", function(eventStatus)
    saveData()
end)

----------------------------------------------
-- REGISTER MODULE
----------------------------------------------

ZoneCore.RegisterModule("SafeZones", SafeZones)

ZoneCore.RegisterEventHandler("GetPlayerSafeZone", function(pid)
    return SafeZones.GetPlayerZone(pid)
end)

ZoneCore.RegisterEventHandler("GetSafeZoneDropFlags", function(pid)
    return SafeZones.GetDropFlags(pid)
end)

ZoneCore.LogInfo("SafeZones module loaded.")

return SafeZones
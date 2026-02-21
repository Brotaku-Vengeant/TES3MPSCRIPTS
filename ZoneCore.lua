--[[
    zoneCore.lua - TES3MP 0.8.1
    Core utilities and shared functionality for the zone system.
    This module MUST be loaded first before any other zone modules.
--]]

local json = require("dkjson")
local color = require("color")
local tableHelper = require("tableHelper")

-- Create global module table
ZoneCore = {}

----------------------------------------------
-- CONFIGURATION
----------------------------------------------

ZoneCore.config = {
    dataPath = "server/data/",
    chatPretextColor = color.GreenYellow,
    debugMode = false
}

----------------------------------------------
-- LOGGING UTILITIES
----------------------------------------------

function ZoneCore.LogInfo(message)
    tes3mp.LogMessage(1, "[ZoneCore] " .. tostring(message))
end

function ZoneCore.LogWarn(message)
    tes3mp.LogMessage(2, "[ZoneCore] " .. tostring(message))
end

function ZoneCore.LogDebug(message)
    if ZoneCore.config.debugMode then
        tes3mp.LogMessage(1, "[ZoneCore DEBUG] " .. tostring(message))
    end
end

----------------------------------------------
-- JSON PERSISTENCE HELPERS
----------------------------------------------

function ZoneCore.LoadJSON(filename)
    local filepath = ZoneCore.config.dataPath .. filename
    local file = io.open(filepath, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            local status, data = pcall(function() return json.decode(content) end)
            if status and type(data) == "table" then
                ZoneCore.LogInfo("Successfully loaded: " .. filename)
                return data
            else
                ZoneCore.LogWarn("Error decoding JSON from: " .. filename)
            end
        end
    else
        ZoneCore.LogDebug("File not found (will create on save): " .. filename)
    end
    return {}
end

function ZoneCore.SaveJSON(filename, data)
    local filepath = ZoneCore.config.dataPath .. filename
    local file = io.open(filepath, "w")
    if file then
        local encoded = json.encode(data, { indent = true })
        file:write(encoded)
        file:close()
        ZoneCore.LogInfo("Saved: " .. filename)
        return true
    else
        ZoneCore.LogWarn("Could not open for writing: " .. filename)
        return false
    end
end

----------------------------------------------
-- MESSAGING UTILITIES
----------------------------------------------

function ZoneCore.SendMessage(pid, message, asServerMessage)
    if Players[pid] and Players[pid]:IsLoggedIn() then
        tes3mp.SendMessage(pid, tostring(message) .. "\n" .. color.Default, asServerMessage or false)
    end
end

function ZoneCore.BroadcastMessage(message, asServerMessage)
    for pid, player in pairs(Players) do
        if type(pid) == "number" and pid < 65535 and player and player:IsLoggedIn() then
            tes3mp.SendMessage(pid, tostring(message) .. "\n" .. color.Default, asServerMessage or false)
        end
    end
end

----------------------------------------------
-- PLAYER UTILITIES
----------------------------------------------

function ZoneCore.IsValidPlayer(pid)
    return Players[pid] ~= nil and Players[pid]:IsLoggedIn()
end

function ZoneCore.IsAdmin(pid)
    if not ZoneCore.IsValidPlayer(pid) then
        return false
    end
    return Players[pid]:IsAdmin()
end

function ZoneCore.GetPlayerCell(pid)
    if not ZoneCore.IsValidPlayer(pid) then
        return nil
    end
    return Players[pid].data.location.cell
end

function ZoneCore.GetPlayerPosition(pid)
    if not ZoneCore.IsValidPlayer(pid) then
        return nil
    end
    return {
        posX = tes3mp.GetPosX(pid),
        posY = tes3mp.GetPosY(pid),
        posZ = tes3mp.GetPosZ(pid),
        rotX = tes3mp.GetRotX(pid),
        rotZ = tes3mp.GetRotZ(pid)
    }
end

function ZoneCore.TeleportPlayer(pid, cell, posX, posY, posZ, rotX, rotZ)
    if not ZoneCore.IsValidPlayer(pid) then
        return false
    end
    tes3mp.SetCell(pid, cell)
    tes3mp.SendCell(pid)
    tes3mp.SetPos(pid, posX or 0, posY or 0, posZ or 0)
    tes3mp.SetRot(pid, rotX or 0, rotZ or 0)
    tes3mp.SendPos(pid)
    return true
end

----------------------------------------------
-- CELL UTILITIES
----------------------------------------------

function ZoneCore.IsExteriorCell(cellName)
    if not cellName then
        return false
    end
    return string.find(cellName, ",") ~= nil
end

----------------------------------------------
-- CROSS-MODULE EVENT SYSTEM
----------------------------------------------

ZoneCore.eventHandlers = {}

function ZoneCore.RegisterEventHandler(eventName, handlerFunc)
    if not ZoneCore.eventHandlers[eventName] then
        ZoneCore.eventHandlers[eventName] = {}
    end
    table.insert(ZoneCore.eventHandlers[eventName], handlerFunc)
end

function ZoneCore.TriggerEvent(eventName, ...)
    if ZoneCore.eventHandlers[eventName] then
        for _, handler in ipairs(ZoneCore.eventHandlers[eventName]) do
            local result = handler(...)
            if result ~= nil then
                return result
            end
        end
    end
    return nil
end

----------------------------------------------
-- MODULE REGISTRATION
----------------------------------------------

ZoneCore.modules = {}

function ZoneCore.RegisterModule(moduleName, moduleTable)
    ZoneCore.modules[moduleName] = moduleTable
    ZoneCore.LogInfo("Module registered: " .. moduleName)
end

function ZoneCore.GetModule(moduleName)
    return ZoneCore.modules[moduleName]
end

----------------------------------------------
-- INITIALIZATION
----------------------------------------------

ZoneCore.LogInfo("ZoneCore loaded successfully.")

return ZoneCore
--[[

-- ========================================
-- JAIL SYSTEM TES3MP V 0.8.1
-- Sone System module for managing player penalties for killing players in a safe zone.
-- Brotaku Vengeant 2/21/2026 Ver 1.
-- ========================================

    Depends on: zoneCore.lua, safeZones.lua

--]]


if not ZoneCore then
    tes3mp.LogMessage(2, "[JailSystem] ERROR: ZoneCore must be loaded first!")
    return
end

local color = require("color")
local time = require("time")
local config = require("config")

----------------------------------------------
-- MODULE SETUP
----------------------------------------------

local JailSystem = {
    jailedPlayers = {},
    jailTimers = {}
}

----------------------------------------------
-- CONFIGURATION
----------------------------------------------

JailSystem.config = {
    jailTimeInMins = 30,
    broadcastOnJail = true
}

JailSystem.jailCells = {
    {
        cell = "Vivec, Hlaalu Prison Cells",
        posX = 245,
        posY = 504,
        posZ = -114.6,
        rotX = 0.117,
        rotZ = 3.126
    },
    {
        cell = "Vivec, Hlaalu Prison Cells",
        posX = 253,
        posY = -279,
        posZ = -116,
        rotX = 0.121,
        rotZ = 0.007
    }
}

JailSystem.messages = {
    jailed = "You were sent to jail for killing a player in a safe zone, you criminal scum! Your sentence is %d minutes.",
    released = "You were released from jail. Now taking bets on how long until you come back.",
    broadcast = "%s was sent to jail for killing another player in a safe zone. Everyone boo them! BOOOOOO"
}

JailSystem.msgColor = color.DarkSalmon

----------------------------------------------
-- JAIL FUNCTIONS
----------------------------------------------

function _G.JailSystem_ReleasePlayer(timerId, pid)
    if not ZoneCore.IsValidPlayer(pid) then
        JailSystem.jailedPlayers[pid] = nil
        JailSystem.jailTimers[pid] = nil
        return
    end
    
    JailSystem.jailedPlayers[pid] = nil
    JailSystem.jailTimers[pid] = nil
    
    ZoneCore.SendMessage(pid, JailSystem.msgColor .. JailSystem.messages.released)
    
    if config and config.defaultRespawnCell then
        local pos = config.defaultRespawnPos or {0, 0, 0}
        local rot = config.defaultRespawnRot or {0, 0}
        ZoneCore.TeleportPlayer(pid, config.defaultRespawnCell, pos[1], pos[2], pos[3], rot[1], rot[2])
    end
    
    ZoneCore.LogInfo("JailSystem: Released player " .. (Players[pid].accountName or tostring(pid)))
end

function JailSystem.JailPlayer(pid)
    if not ZoneCore.IsValidPlayer(pid) then
        return false
    end
    
    local roomIndex = math.random(#JailSystem.jailCells)
    local jailRoom = JailSystem.jailCells[roomIndex]
    
    JailSystem.jailedPlayers[pid] = roomIndex
    
    ZoneCore.TeleportPlayer(
        pid,
        jailRoom.cell,
        jailRoom.posX,
        jailRoom.posY,
        jailRoom.posZ,
        jailRoom.rotX,
        jailRoom.rotZ
    )
    
    tes3mp.SetHealthCurrent(pid, 100)
    tes3mp.SendStatsDynamic(pid)
    
    local jailMsg = string.format(JailSystem.messages.jailed, JailSystem.config.jailTimeInMins)
    ZoneCore.SendMessage(pid, JailSystem.msgColor .. jailMsg)
    
    if JailSystem.config.broadcastOnJail then
        local playerName = Players[pid].data.login.name or Players[pid].accountName or "Unknown"
        local broadcastMsg = string.format(JailSystem.messages.broadcast, playerName)
        ZoneCore.BroadcastMessage(JailSystem.msgColor .. broadcastMsg, true)
    end
    
    local releaseTimer = tes3mp.CreateTimerEx(
        "JailSystem_ReleasePlayer",
        time.seconds(JailSystem.config.jailTimeInMins * 60),
        "i",
        pid
    )
    tes3mp.StartTimer(releaseTimer)
    JailSystem.jailTimers[pid] = releaseTimer
    
    ZoneCore.LogInfo("JailSystem: Jailed player " .. (Players[pid].accountName or tostring(pid)))
    return true
end

function JailSystem.IsJailed(pid)
    return JailSystem.jailedPlayers[pid] ~= nil
end

function JailSystem.GetJailRoom(pid)
    local roomIndex = JailSystem.jailedPlayers[pid]
    if roomIndex then
        return JailSystem.jailCells[roomIndex]
    end
    return nil
end

function JailSystem.PreventEscape(pid)
    if not JailSystem.IsJailed(pid) then
        return
    end
    
    local jailRoom = JailSystem.GetJailRoom(pid)
    if not jailRoom then
        return
    end
    
    local currentCell = ZoneCore.GetPlayerCell(pid)
    if currentCell ~= jailRoom.cell then
        ZoneCore.TeleportPlayer(
            pid,
            jailRoom.cell,
            jailRoom.posX,
            jailRoom.posY,
            jailRoom.posZ,
            jailRoom.rotX,
            jailRoom.rotZ
        )
    end
end

function JailSystem.ReleaseEarly(pid, adminPid)
    if not ZoneCore.IsAdmin(adminPid) then
        ZoneCore.SendMessage(adminPid, "You do not have permission to use this command.")
        return false
    end
    
    if not JailSystem.IsJailed(pid) then
        ZoneCore.SendMessage(adminPid, "That player is not jailed.")
        return false
    end
    
    if JailSystem.jailTimers[pid] then
        tes3mp.StopTimer(JailSystem.jailTimers[pid])
    end
    
    JailSystem.jailedPlayers[pid] = nil
    JailSystem.jailTimers[pid] = nil
    
    ZoneCore.SendMessage(pid, JailSystem.msgColor .. "You have been released early by an admin.")
    ZoneCore.SendMessage(adminPid, "Player released from jail.")
    
    if config and config.defaultRespawnCell then
        local pos = config.defaultRespawnPos or {0, 0, 0}
        local rot = config.defaultRespawnRot or {0, 0}
        ZoneCore.TeleportPlayer(pid, config.defaultRespawnCell, pos[1], pos[2], pos[3], rot[1], rot[2])
    end
    
    return true
end

----------------------------------------------
-- COMMAND REGISTRATION
----------------------------------------------

customCommandHooks.registerCommand("releaseprisoner", function(pid, cmd)
    local targetPid = tonumber(cmd[2])
    if not targetPid then
        ZoneCore.SendMessage(pid, "Usage: /releaseprisoner <pid>")
        return
    end
    JailSystem.ReleaseEarly(targetPid, pid)
end)

customCommandHooks.registerCommand("listprisoners", function(pid, cmd)
    if not ZoneCore.IsAdmin(pid) then
        ZoneCore.SendMessage(pid, "You do not have permission to use this command.")
        return
    end
    
    local count = 0
    ZoneCore.SendMessage(pid, "=== Jailed Players ===")
    
    for jailedPid, roomIndex in pairs(JailSystem.jailedPlayers) do
        if ZoneCore.IsValidPlayer(jailedPid) then
            local name = Players[jailedPid].accountName or tostring(jailedPid)
            ZoneCore.SendMessage(pid, "- " .. name .. " (pid: " .. jailedPid .. ", room: " .. roomIndex .. ")")
            count = count + 1
        end
    end
    
    if count == 0 then
        ZoneCore.SendMessage(pid, "No players are currently jailed.")
    end
end)

----------------------------------------------
-- EVENT HANDLERS
----------------------------------------------

customEventHooks.registerHandler("OnPlayerCellChange", function(eventStatus, pid, previousCellDescription, currentCellDescription)
    JailSystem.PreventEscape(pid)
end)

customEventHooks.registerHandler("OnPlayerDisconnect", function(eventStatus, pid)
    if JailSystem.jailTimers[pid] then
        tes3mp.StopTimer(JailSystem.jailTimers[pid])
    end
    JailSystem.jailedPlayers[pid] = nil
    JailSystem.jailTimers[pid] = nil
end)

----------------------------------------------
-- REGISTER MODULE
----------------------------------------------

ZoneCore.RegisterModule("JailSystem", JailSystem)

ZoneCore.RegisterEventHandler("JailPlayer", function(pid)
    return JailSystem.JailPlayer(pid)
end)

ZoneCore.RegisterEventHandler("IsPlayerJailed", function(pid)
    return JailSystem.IsJailed(pid)
end)

ZoneCore.LogInfo("JailSystem module loaded.")


return JailSystem

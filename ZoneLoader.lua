lua
--[[
    zoneSystemLoader.lua - TES3MP 0.8.1
    Main loader for the modular zone system.
    
    INSTALLATION:
    1. Place all zone system files in server/scripts/custom/zones/
    2. Add this to your customScripts.lua:
       require("custom.zones.zoneSystemLoader")
    
    FILES REQUIRED:
    - zoneCore.lua
    - safeZones.lua
    - captureZones.lua
    - factionCapture.lua
    - jailSystem.lua
    - deathDrop.lua
--]]

local modulePath = "custom.zones."

-- Load order matters!
local modules = {
    "zoneCore",         -- Must be first - provides shared functionality
    "safeZones",        -- Safe zone management
    "captureZones",     -- Capture zone management
    "factionCapture",   -- Faction features (HQ, blocked factions, etc.)
    "jailSystem",       -- Jail system for safe zone violations
    "deathDrop",        -- Death drop handling
}

tes3mp.LogMessage(1, "[ZoneSystem] Loading modular zone system...")

local loadedCount = 0
local failedModules = {}

for _, moduleName in ipairs(modules) do
    local success, err = pcall(function()
        require(modulePath .. moduleName)
    end)
    
    if success then
        loadedCount = loadedCount + 1
        tes3mp.LogMessage(1, "[ZoneSystem] Loaded: " .. moduleName)
    else
        table.insert(failedModules, moduleName)
        tes3mp.LogMessage(2, "[ZoneSystem] FAILED to load: " .. moduleName)
        tes3mp.LogMessage(2, "[ZoneSystem] Error: " .. tostring(err))
    end
end

tes3mp.LogMessage(1, "[ZoneSystem] Loaded " .. loadedCount .. "/" .. #modules .. " modules.")

if #failedModules > 0 then
    tes3mp.LogMessage(2, "[ZoneSystem] WARNING: Some modules failed to load!")
    tes3mp.LogMessage(2, "[ZoneSystem] Failed: " .. table.concat(failedModules, ", "))
end

----------------------------------------------
-- GLOBAL HELPER FOR REFRESHING ZONES
----------------------------------------------

_G.RefreshCaptureZones = function()
    if ZoneCore then
        ZoneCore.TriggerEvent("RefreshCaptureZones")
        tes3mp.LogMessage(1, "[ZoneSystem] Capture zones refreshed.")
    end
end

return true
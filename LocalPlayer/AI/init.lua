-- AI Controller System - Main Entry Point
if not _G.CensuraG then
    error("CensuraG not initialized. Please load CensuraG.lua first.")
end

-- Initialize global AI system
_G.AiSystem = _G.AiSystem or {
    Config = {},
    State = {
        IsActive = false,
        CurrentAction = nil,
        CurrentTarget = nil,
        ActionStartTime = 0,
        MessageLog = {},
        IgnoredPlayers = {},
        CurrentDecision = nil,
        LastPositions = {}
    },
    Modules = {},
    Utils = {}
}

local System = _G.AiSystem
local baseUrl = "https://raw.githubusercontent.com/LxckStxp/Censura-Applications/main/LocalPlayer/AI/"

-- Helper function to load scripts
local function loadScript(path)
    local success, result = pcall(function()
        return loadstring(game:HttpGet(baseUrl .. path))()
    end)
    if not success then
        error("Failed to load " .. path .. ": " .. tostring(result))
    end
    return result
end

-- Load utilities
System.Utils.Logger = loadScript("Utils/Logger.lua")
local Logger = System.Utils.Logger
Logger:info("Initializing AI Controller System...")

System.Config = loadScript("Utils/Config.lua")

-- Load modules
local modules = {
    UIManager = "Modules/UIManager.lua",
    MovementManager = "Modules/MovementManager.lua",
    ChatManager = "Modules/ChatManager.lua",
    SpamDetection = "Modules/SpamDetection.lua",
    ContextBuilder = "Modules/ContextBuilder.lua",
    WebhookService = "Modules/WebhookService.lua"
}

for name, path in pairs(modules) do
    local success, result = pcall(function()
        System.Modules[name] = loadScript(path)
    end)
    if not success then
        Logger:error("Failed to load module " .. name .. ": " .. tostring(result))
    else
        Logger:info("Loaded module: " .. name)
    end
end

-- Load and initialize controller
local AiController = nil
local success, err = pcall(function()
    AiController = loadScript("AiController.lua")
end)

if not success then
    Logger:error("Failed to initialize AiController: " .. tostring(err))
    return nil
end

Logger:info("AI Controller System fully initialized")
return AiController

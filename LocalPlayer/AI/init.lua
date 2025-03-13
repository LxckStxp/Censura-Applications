-- AI Controller System - Main Entry Point
-- /LxckStxp/Censura-Applications/LocalPlayer/AI/init.lua

-- Ensure CensuraG is loaded
if not _G.CensuraG then
    error("CensuraG not initialized. Please load CensuraG.lua first.")
end

-- Create global table for AI system
if not _G.AiSystem then
    _G.AiSystem = {
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
end

local System = _G.AiSystem

-- Load utilities first
System.Utils.Logger = loadstring(game:HttpGet("https://raw.githubusercontent.com/LxckStxp/Censura-Applications/main/LocalPlayer/AI/Utils/Logger.lua"))()
System.Utils.Logger:info("Loading AI Controller System...")

-- Load configuration
System.Config = loadstring(game:HttpGet("https://raw.githubusercontent.com/LxckStxp/Censura-Applications/main/LocalPlayer/AI/Utils/Config.lua"))()

-- Load modules
System.Modules.UIManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/LxckStxp/Censura-Applications/main/LocalPlayer/AI/Modules/UIManager.lua"))()
System.Modules.MovementManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/LxckStxp/Censura-Applications/main/LocalPlayer/AI/Modules/MovementManager.lua"))()
System.Modules.ChatManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/LxckStxp/Censura-Applications/main/LocalPlayer/AI/Modules/ChatManager.lua"))()
System.Modules.SpamDetection = loadstring(game:HttpGet("https://raw.githubusercontent.com/LxckStxp/Censura-Applications/main/LocalPlayer/AI/Modules/SpamDetection.lua"))()
System.Modules.ContextBuilder = loadstring(game:HttpGet("https://raw.githubusercontent.com/LxckStxp/Censura-Applications/main/LocalPlayer/AI/Modules/ContextBuilder.lua"))()
System.Modules.WebhookService = loadstring(game:HttpGet("https://raw.githubusercontent.com/LxckStxp/Censura-Applications/main/LocalPlayer/AI/Modules/WebhookService.lua"))()

-- Load main controller
local AiController = loadstring(game:HttpGet("https://raw.githubusercontent.com/LxckStxp/Censura-Applications/main/LocalPlayer/AI/AiController.lua"))()

-- Return the initialized controller
return AiController

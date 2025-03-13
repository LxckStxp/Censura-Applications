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
            IgnoredPlayers = {}
        },
        Modules = {},
        Utils = {}
    }
end

local System = _G.AiSystem

-- Load utilities first
System.Utils.Logger = require(script.Utils.Logger)
System.Utils.Logger:info("Loading AI Controller System...")

-- Load configuration
System.Config = require(script.Utils.Config)

-- Load modules
System.Modules.UIManager = require(script.Modules.UIManager)
System.Modules.MovementManager = require(script.Modules.MovementManager)
System.Modules.ChatManager = require(script.Modules.ChatManager)
System.Modules.SpamDetection = require(script.Modules.SpamDetection)
System.Modules.ContextBuilder = require(script.Modules.ContextBuilder)
System.Modules.WebhookService = require(script.Modules.WebhookService)

-- Load main controller
local AiController = require(script.AiController)

-- Return the initialized controller
return AiController

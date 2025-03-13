-- AI Controller - Core Logic
-- /LxckStxp/Censura-Applications/LocalPlayer/AI/AiController.lua

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local System = _G.AiSystem
local Logger = System.Utils.Logger
local Config = System.Config

-- AI Controller Module
local AiController = {}
AiController.__index = AiController

-- Initialize the AI Controller
function AiController:Initialize()
    Logger:info("Initializing AiController")
    
    -- Initialize character references
    self.Character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    self.Humanoid = self.Character:WaitForChild("Humanoid")
    self.RootPart = self.Character:WaitForChild("HumanoidRootPart")
    
    -- Setup event handlers
    self:SetupCharacterHandler()
    
    -- Initialize all modules
    System.Modules.UIManager:Initialize(self)
    System.Modules.MovementManager:Initialize(self)
    System.Modules.ChatManager:Initialize(self)
    System.Modules.SpamDetection:Initialize()
    System.Modules.ContextBuilder:Initialize(self)
    System.Modules.WebhookService:Initialize()
    
    -- Start position tracking for stuck detection
    System.Modules.MovementManager:StartPositionTracking()
    
    Logger:info("AiController initialized successfully")
    return self
end

-- Toggle AI Control
function AiController:ToggleAIControl(state)
    System.State.IsActive = state
    
    if state then
        System.State.ActionStartTime = tick()
        spawn(function() self:RunAI() end)
        System.Modules.UIManager:UpdateStatusLabels("Starting", nil)
    else
        -- Stop any current movement
        if self.Humanoid then
            self.Humanoid:MoveTo(self.RootPart.Position)
        end
        System.Modules.UIManager:UpdateStatusLabels("Stopped", nil)
    end
    
    Logger:info("AI Control " .. (state and "enabled" or "disabled"))
end

-- Setup Character Handler
function AiController:SetupCharacterHandler()
    -- Handle character respawning
    localPlayer.CharacterAdded:Connect(function(character)
        self.Character = character
        self.Humanoid = character:WaitForChild("Humanoid")
        self.RootPart = character:WaitForChild("HumanoidRootPart")
        
        -- Reset state on respawn
        System.State.CurrentAction = nil
        System.State.CurrentTarget = nil
        System.State.LastPositions = {}
        
        -- Notify modules about character change
        System.Modules.MovementManager:OnCharacterChanged(self)
        
        Logger:info("Character respawned, AI controller updated")
    end)
end

-- Main AI Loop
function AiController:RunAI()
    while System.State.IsActive do
        -- Check if current action has timed out
        local actionTime = tick() - System.State.ActionStartTime
        local needsNewDecision = (not System.State.CurrentAction) or (actionTime > Config.ACTION_TIMEOUT)
        
        -- Check if current decision has a duration that's elapsed
        if System.State.CurrentDecision and System.State.CurrentDecision.duration then
            if actionTime > System.State.CurrentDecision.duration then
                needsNewDecision = true
            end
        end
        
        if needsNewDecision then
            local context = System.Modules.ContextBuilder:GetContext()
            local decision = System.Modules.WebhookService:CallGrok(context)
            
            if decision then
                System.State.CurrentDecision = decision
                System.State.ActionStartTime = tick()
                self:ExecuteDecision(decision)
            else
                -- Fallback behavior
                System.Modules.ChatManager:SendMessage("Just chilling here, anyone around?")
                System.State.ActionStartTime = tick()
            end
        end
        
        -- More natural wait time with slight randomization
        wait(Config.DECISION_INTERVAL * (0.8 + math.random() * 0.4))
    end
end

-- Execute Grok's Decision
function AiController:ExecuteDecision(decision)
    local action = decision.action
    local target = decision.target
    local message = decision.message
    local priority = decision.priority or 3
    local duration = decision.duration or 5
    
    -- Skip interacting with players marked as spammers
    if target and System.State.IgnoredPlayers[target] and System.State.IgnoredPlayers[target] > os.time() then
        Logger:info("Skipping interaction with spammer: " .. target)
        System.Modules.MovementManager:Wander(self) -- Default to wandering instead
        return
    end
    
    -- Update UI
    System.Modules.UIManager:UpdateStatusLabels(action, target, message)
    
    -- Update current state
    System.State.CurrentAction = action
    System.State.CurrentTarget = target
    
    -- Execute based on action type
    if action == "wander" then
        System.Modules.MovementManager:Wander(self)
    elseif action == "approach" and target then
        local player = Players:FindFirstChild(target)
        if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            System.Modules.MovementManager:ApproachPlayer(self, player)
        end
    elseif action == "interact" and target then
        local player = Players:FindFirstChild(target)
        if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            System.Modules.MovementManager:InteractWithPlayer(self, player, message)
        end
    elseif action == "say" and message then
        System.Modules.ChatManager:SendMessage(message)
    elseif action == "emote" and message then
        System.Modules.MovementManager:PerformEmote(self, message)
    elseif action == "explore" then
        System.Modules.MovementManager:Explore(self)
    elseif action == "follow" and target then
        local player = Players:FindFirstChild(target)
        if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            System.Modules.MovementManager:FollowPlayer(self, player, duration)
        end
    else
        Logger:warn("Unknown or invalid action: " .. tostring(action))
    end
end

-- Query Grok with Chat Input
function AiController:QueryGrokWithChat(message, sender)
    -- Skip if the player is marked as a spammer
    if System.State.IgnoredPlayers[sender] and System.State.IgnoredPlayers[sender] > os.time() then
        Logger:info("Ignoring chat from spammer: " .. sender)
        return
    end
    
    local context = System.Modules.ContextBuilder:GetContext() .. "\nNew message from " .. sender .. ": " .. message
    local decision = System.Modules.WebhookService:CallGrok(context)
    
    if decision then
        System.State.CurrentDecision = decision
        System.State.ActionStartTime = tick()
        self:ExecuteDecision(decision)
    else
        -- Fallback response
        System.Modules.ChatManager:SendMessage("Hey " .. sender .. ", what's that about?")
    end
end

-- Create and return the instance
local controller = setmetatable({}, AiController)
controller:Initialize()
return controller

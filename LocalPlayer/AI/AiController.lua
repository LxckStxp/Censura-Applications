-- AI Controller - Core Logic
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local System = _G.AiSystem
local Logger = System.Utils.Logger
local Config = System.Config

local AiController = {}
AiController.__index = AiController

function AiController.new()
    local self = setmetatable({}, AiController)
    return self:Initialize()
end

function AiController:Initialize()
    Logger:info("Initializing AiController")
    
    local success, err = pcall(function()
        self.Character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
        self.Humanoid = self.Character:WaitForChild("Humanoid", 5)
        self.RootPart = self.Character:WaitForChild("HumanoidRootPart", 5)
        
        if not self.Humanoid or not self.RootPart then
            error("Failed to find required character components")
        end
    end)
    
    if not success then
        Logger:error("Initialization failed: " .. tostring(err))
        return nil
    end
    
    self:SetupCharacterHandler()
    self:InitializeModules()
    
    Logger:info("AiController initialized successfully")
    return self
end

function AiController:InitializeModules()
    local modules = {
        "UIManager", "MovementManager", "ChatManager",
        "SpamDetection", "ContextBuilder", "WebhookService"
    }
    
    for _, moduleName in ipairs(modules) do
        local success, err = pcall(function()
            System.Modules[moduleName]:Initialize(self)
        end)
        if not success then
            Logger:warn("Failed to initialize " .. moduleName .. ": " .. tostring(err))
        end
    end
    
    System.Modules.MovementManager:StartPositionTracking()
end

function AiController:ToggleAIControl(state)
    System.State.IsActive = state
    
    if state then
        System.State.ActionStartTime = tick()
        task.spawn(function() self:RunAI() end)
        System.Modules.UIManager:UpdateStatusLabels("Starting", nil)
    else
        self:StopMovement()
        System.Modules.UIManager:UpdateStatusLabels("Stopped", nil)
    end
    
    Logger:info("AI Control " .. (state and "enabled" or "disabled"))
end

function AiController:StopMovement()
    if self.Humanoid and self.RootPart then
        self.Humanoid:MoveTo(self.RootPart.Position)
    end
end

function AiController:SetupCharacterHandler()
    localPlayer.CharacterAdded:Connect(function(character)
        local success, err = pcall(function()
            self.Character = character
            self.Humanoid = character:WaitForChild("Humanoid", 5)
            self.RootPart = character:WaitForChild("HumanoidRootPart", 5)
            
            System.State.CurrentAction = nil
            System.State.CurrentTarget = nil
            System.State.LastPositions = {}
            
            System.Modules.MovementManager:OnCharacterChanged(self)
        end)
        
        if success then
            Logger:info("Character respawned, AI controller updated")
        else
            Logger:error("Character handler error: " .. tostring(err))
        end
    end)
end

function AiController:RunAI()
    while System.State.IsActive do
        local actionTime = tick() - System.State.ActionStartTime
        local needsDecision = self:NeedsNewDecision(actionTime)
        
        if needsDecision then
            self:MakeDecision()
        end
        
        task.wait(Config.DECISION_INTERVAL * (0.8 + math.random() * 0.4))
    end
end

function AiController:NeedsNewDecision(actionTime)
    return (not System.State.CurrentAction) or 
           (actionTime > Config.ACTION_TIMEOUT) or
           (System.State.CurrentDecision and System.State.CurrentDecision.duration and 
            actionTime > System.State.CurrentDecision.duration)
end

function AiController:MakeDecision()
    local context = System.Modules.ContextBuilder:GetContext()
    local decision = System.Modules.WebhookService:CallGrok(context)
    
    if decision then
        System.State.CurrentDecision = decision
        System.State.ActionStartTime = tick()
        self:ExecuteDecision(decision)
    else
        System.Modules.ChatManager:SendMessage("Just chilling here, anyone around?")
        System.State.ActionStartTime = tick()
    end
end

function AiController:QueryGrokWithChat(message, sender)
    if System.State.IgnoredPlayers[sender] and System.State.IgnoredPlayers[sender] > os.time() then
        Logger:info("Ignoring chat from spammer: " .. sender)
        return
    end
    
    if not System.Modules.ChatManager:ShouldRespondToChat(message, sender) then
        Logger:info("Decided not to respond to: " .. sender)
        return
    end
    
    local queryId = sender .. ":" .. message .. ":" .. os.time()
    if self:IsRecentDuplicate(queryId) then
        Logger:info("Skipping similar recent message from " .. sender)
        return
    end
    
    local context = System.Modules.ContextBuilder:GetContext() .. "\nNew message from " .. sender .. ": " .. message
    local decision = System.Modules.WebhookService:CallGrok(context)
    
    if decision then
        System.Modules.ChatManager:StartConversation(sender)
        System.State.CurrentDecision = decision
        System.State.ActionStartTime = tick()
        self:ExecuteDecision(decision)
    else
        System.Modules.ChatManager:SendMessage("Hey " .. sender .. ", what's that about?")
    end
end

function AiController:IsRecentDuplicate(queryId)
    for id, _ in pairs(System.Modules.ChatManager.RespondedMessages) do
        if id:find(queryId:match("^[^:]+:[^:]+")) and 
           os.time() - tonumber(id:match(":(%d+)$") or 0) < 5 then
            return true
        end
    end
    return false
end

function AiController:ExecuteDecision(decision)
    local actions = {
        wander = function() System.Modules.MovementManager:Wander(self) end,
        approach = function() self:ExecuteApproach(decision.target) end,
        interact = function() self:ExecuteInteract(decision.target, decision.message) end,
        say = function() System.Modules.ChatManager:SendMessage(decision.message) end,
        emote = function() System.Modules.MovementManager:PerformEmote(self, decision.message) end,
        explore = function() System.Modules.MovementManager:Explore(self) end,
        follow = function() self:ExecuteFollow(decision.target, decision.duration) end
    }
    
    if decision.target and self:IsSpammer(decision.target) then
        Logger:info("Skipping interaction with spammer: " .. decision.target)
        System.Modules.MovementManager:Wander(self)
        return
    end
    
    System.Modules.UIManager:UpdateStatusLabels(decision.action, decision.target, decision.message)
    System.State.CurrentAction = decision.action
    System.State.CurrentTarget = decision.target
    
    local actionFunc = actions[decision.action]
    if actionFunc then
        actionFunc()
    else
        Logger:warn("Unknown action: " .. tostring(decision.action))
    end
end

function AiController:IsSpammer(target)
    return System.State.IgnoredPlayers[target] and System.State.IgnoredPlayers[target] > os.time()
end

function AiController:ExecuteApproach(target)
    local player = Players:FindFirstChild(target)
    if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        System.Modules.MovementManager:ApproachPlayer(self, player)
    end
end

function AiController:ExecuteInteract(target, message)
    local player = Players:FindFirstChild(target)
    if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        System.Modules.MovementManager:InteractWithPlayer(self, player, message)
    end
end

function AiController:ExecuteFollow(target, duration)
    local player = Players:FindFirstChild(target)
    if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        System.Modules.MovementManager:FollowPlayer(self, player, duration)
    end
end

-- Initialize and return
local controller = AiController.new()
if controller then
    return controller
end

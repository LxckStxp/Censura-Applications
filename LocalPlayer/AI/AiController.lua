local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local System = _G.AiSystem
local Logger = System.Utils.Logger
local Config = System.Config

local AiController = {}
AiController.__index = AiController

function AiController:Initialize()
    Logger:info("Initializing AI")
    self.Character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    self.Humanoid = self.Character:WaitForChild("Humanoid")
    self.RootPart = self.Character:WaitForChild("HumanoidRootPart")
    
    self:SetupCharacterHandler()
    
    System.Modules.UIManager:Initialize(self)
    System.Modules.MovementManager:Initialize(self)
    System.Modules.ChatManager:Initialize(self)
    System.Modules.SpamDetection:Initialize()
    System.Modules.ContextBuilder:Initialize(self)
    System.Modules.WebhookService:Initialize()
    
    Logger:info("AI initialized")
    return self
end

function AiController:ToggleAIControl(state)
    System.State.IsActive = state
    if state then
        spawn(function() self:RunAI() end)
        System.Modules.UIManager:UpdateStatusLabels("Active")
    else
        self.Humanoid:MoveTo(self.RootPart.Position)
        System.Modules.UIManager:UpdateStatusLabels("Stopped")
    end
    Logger:info("AI " .. (state and "enabled" or "disabled"))
end

function AiController:SetupCharacterHandler()
    localPlayer.CharacterAdded:Connect(function(character)
        self.Character = character
        self.Humanoid = character:WaitForChild("Humanoid")
        self.RootPart = character:WaitForChild("HumanoidRootPart")
        System.State.CurrentAction = nil
        System.Modules.MovementManager:OnCharacterChanged(self)
        Logger:info("Character respawned")
    end)
end

function AiController:RunAI()
    while System.State.IsActive do
        if not System.State.CurrentAction or (tick() - System.State.ActionStartTime > Config.ACTION_TIMEOUT) then
            local context = System.Modules.ContextBuilder:GetContext()
            local decision = System.Modules.WebhookService:CallGrok(context)
            
            if decision then
                System.State.ActionStartTime = tick()
                self:ExecuteDecision(decision)
            else
                System.Modules.ChatManager:SendMessage("Hey, what's up?")
            end
        end
        wait(Config.DECISION_INTERVAL)
    end
end

function AiController:QueryGrokWithChat(message, sender)
    if System.State.IgnoredPlayers[sender] then return end
    
    local context = System.Modules.ContextBuilder:GetContext() .. "\nMessage from " .. sender .. ": " .. message
    local decision = System.Modules.WebhookService:CallGrok(context)
    
    if decision then
        self:ExecuteDecision(decision)
    else
        System.Modules.ChatManager:SendMessage("Hey " .. sender .. ", cool message!")
    end
end

function AiController:ExecuteDecision(decision)
    local action = decision.action
    local target = decision.target
    local message = decision.message
    
    System.State.CurrentAction = action
    System.State.CurrentTarget = target
    System.Modules.UIManager:UpdateStatusLabels(action, target)
    
    if action == "wander" then
        System.Modules.MovementManager:Wander(self)
    elseif action == "approach" and target then
        System.Modules.MovementManager:ApproachPlayer(self, Players:FindFirstChild(target))
    elseif action == "say" and message then
        System.Modules.ChatManager:SendMessage(message)
    end
end

return setmetatable({}, AiController):Initialize()

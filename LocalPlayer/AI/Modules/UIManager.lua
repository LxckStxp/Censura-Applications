-- UI Manager Module
-- /LxckStxp/Censura-Applications/LocalPlayer/AI/Modules/UIManager.lua

local UIManager = {}

local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger
local Methods = _G.CensuraG.Methods

function UIManager:Initialize(controller)
    self.Controller = controller
    
    -- Create UI
    self:SetupUI()
    
    -- Start UI update loop
    spawn(function()
        while wait(1) do
            self:UpdateUIStats()
        end
    end)
    
    return self
end

function UIManager:SetupUI()
    self.Window = _G.CensuraG.CreateWindow("AI Controller")
    self.Window.Frame.Position = UDim2.new(0, 100, 0, 100)
    self.Window:SetSize(300, 450)
    
    -- Create tabs for organization
    self.Tabs = Methods:CreateTabSystem(self.Window.ContentFrame)
    
    -- Set up the main tab
    self:SetupMainTab()
    
    -- Set up the behavior tab
    self:SetupBehaviorTab()
    
    -- Set up the chat tab
    self:SetupChatTab()
    
    -- Set up the status tab
    self:SetupStatusTab()
    
    -- Set up the spam control tab
    self:SetupSpamTab()
    
    -- Keep the Cyberpunk theme as requested
    _G.CensuraG.SetTheme("Cyberpunk")
end

-- Main tab setup
function UIManager:SetupMainTab()
    self.MainTab = self.Tabs:AddTab("Main")
    self.MainGrid = Methods:CreateGrid(self.MainTab)
    
    -- Main toggle
    self.ToggleAI = Methods:CreateSwitch(self.MainGrid.Instance, "Enable AI", false, function(state)
        self.Controller:ToggleAIControl(state)
    end)
    self.MainGrid:AddComponent(self.ToggleAI)
    
    -- Manual actions section
    self.ActionsLabel = Methods:CreateLabel(self.MainGrid.Instance, "Manual Actions")
    self.MainGrid:AddComponent(self.ActionsLabel)
    
    -- Manual action buttons
    self.WanderButton = Methods:CreateButton(self.MainGrid.Instance, "Wander", function()
        if System.State.IsActive then
            System.Modules.MovementManager:Wander(self.Controller)
            self:UpdateStatusLabels("wander", nil)
        end
    end)
    self.MainGrid:AddComponent(self.WanderButton)
    
    self.SayButton = Methods:CreateButton(self.MainGrid.Instance, "Say Something", function()
        if System.State.IsActive then
            local phrases = {
                "Hey everyone, what's up?",
                "Anyone doing anything cool?",
                "I'm just exploring around.",
                "This place is pretty neat!",
                "How's everyone doing today?"
            }
            local message = phrases[math.random(1, #phrases)]
            System.Modules.ChatManager:SendMessage(message)
            self:UpdateStatusLabels("say", nil, message)
        end
    end)
    self.MainGrid:AddComponent(self.SayButton)
    
    self.EmoteButton = Methods:CreateButton(self.MainGrid.Instance, "Random Emote", function()
        if System.State.IsActive then
            local emotes = {"wave", "dance", "laugh", "point"}
            System.Modules.MovementManager:PerformEmote(self.Controller, emotes[math.random(1, #emotes)])
        end
    end)
    self.MainGrid:AddComponent(self.EmoteButton)
    
    -- Version and info
    self.VersionLabel = Methods:CreateLabel(self.MainGrid.Instance, "AI Controller v1.0")
    self.MainGrid:AddComponent(self.VersionLabel)
end

-- Behavior tab setup
function UIManager:SetupBehaviorTab()
    self.BehaviorTab = self.Tabs:AddTab("Behavior")
    self.BehaviorGrid = Methods:CreateGrid(self.BehaviorTab)
    
    -- Decision interval slider
    self.IntervalSlider = Methods:CreateSlider(self.BehaviorGrid.Instance, "Decision Interval", 2, 15, Config.DECISION_INTERVAL, function(value)
        Config.DECISION_INTERVAL = value
        Logger:info("Decision interval set to " .. value)
    end)
    self.BehaviorGrid:AddComponent(self.IntervalSlider)
    
    -- Detection radius slider
    self.RadiusSlider = Methods:CreateSlider(self.BehaviorGrid.Instance, "Detection Radius", 20, 100, Config.DETECTION_RADIUS, function(value)
        Config.DETECTION_RADIUS = value
        Logger:info("Detection radius set to " .. value)
    end)
    self.BehaviorGrid:AddComponent(self.RadiusSlider)
    
    -- Interaction distance slider
    self.InteractionSlider = Methods:CreateSlider(self.BehaviorGrid.Instance, "Interaction Distance", 3, 15, Config.INTERACTION_DISTANCE, function(value)
        Config.INTERACTION_DISTANCE = value
        Logger:info("Interaction distance set to " .. value)
    end)
    self.BehaviorGrid:AddComponent(self.InteractionSlider)
    
    -- Movement randomization slider
    self.MovementSlider = Methods:CreateSlider(self.BehaviorGrid.Instance, "Movement Randomization", 0, 100, Config.MOVEMENT_RANDOMIZATION * 100, function(value)
        Config.MOVEMENT_RANDOMIZATION = value / 100
        Logger:info("Movement randomization set to " .. value .. "%")
    end)
    self.BehaviorGrid:AddComponent(self.MovementSlider)
    
    -- Action timeout slider
    self.TimeoutSlider = Methods:CreateSlider(self.BehaviorGrid.Instance, "Action Timeout", 10, 60, Config.ACTION_TIMEOUT, function(value)
        Config.ACTION_TIMEOUT = value
        Logger:info("Action timeout set to " .. value)
    end)
    self.BehaviorGrid:AddComponent(self.TimeoutSlider)
end

-- Chat tab setup
function UIManager:SetupChatTab()
    self.ChatTab = self.Tabs:AddTab("Chat")
    self.ChatGrid = Methods:CreateGrid(self.ChatTab)
    
    -- Max message length slider
    self.MessageLengthSlider = Methods:CreateSlider(self.ChatGrid.Instance, "Max Message Length", 100, 500, Config.MAX_MESSAGE_LENGTH, function(value)
        Config.MAX_MESSAGE_LENGTH = value
        Logger:info("Max message length set to " .. value)
    end)
    self.ChatGrid:AddComponent(self.MessageLengthSlider)
    
    -- Message delay slider
    self.MessageDelaySlider = Methods:CreateSlider(self.ChatGrid.Instance, "Message Delay", 1, 20, Config.MESSAGE_DELAY * 10, function(value)
        Config.MESSAGE_DELAY = value / 10
        Logger:info("Message delay set to " .. Config.MESSAGE_DELAY)
    end)
    self.ChatGrid:AddComponent(self.MessageDelaySlider)
    
    -- Chat memory size slider
    self.MemorySizeSlider = Methods:CreateSlider(self.ChatGrid.Instance, "Chat Memory Size", 5, 30, Config.CHAT_MEMORY_SIZE, function(value)
        Config.CHAT_MEMORY_SIZE = value
        Logger:info("Chat memory size set to " .. value)
        
        -- Trim message log if needed
        while #System.State.MessageLog > Config.CHAT_MEMORY_SIZE do
            table.remove(System.State.MessageLog, 1)
        end
    end)
    self.ChatGrid:AddComponent(self.MemorySizeSlider)
    
    -- Typing speed sliders
    self.MinTypingSlider = Methods:CreateSlider(self.ChatGrid.Instance, "Min Typing Speed", 1, 20, Config.TYPING_SPEED.min * 100, function(value)
        Config.TYPING_SPEED.min = value / 100
        Logger:info("Min typing speed set to " .. Config.TYPING_SPEED.min)
    end)
    self.ChatGrid:AddComponent(self.MinTypingSlider)
    
    self.MaxTypingSlider = Methods:CreateSlider(self.ChatGrid.Instance, "Max Typing Speed", 1, 20, Config.TYPING_SPEED.max * 100, function(value)
        Config.TYPING_SPEED.max = value / 100
        Logger:info("Max typing speed set to " .. Config.TYPING_SPEED.max)
    end)
    self.ChatGrid:AddComponent(self.MaxTypingSlider)
    
    -- Clear chat history button
    self.ClearChatButton = Methods:CreateButton(self.ChatGrid.Instance, "Clear Chat History", function()
        System.State.MessageLog = {}
        Logger:info("Chat history cleared")
    end)
    self.ChatGrid:AddComponent(self.ClearChatButton)
end

-- Status tab setup
function UIManager:SetupStatusTab()
    self.StatusTab = self.Tabs:AddTab("Status")
    self.StatusGrid = Methods:CreateGrid(self.StatusTab)
    
    -- Status display
    self.StatusLabel = Methods:CreateLabel(self.StatusGrid.Instance, "Status: Idle")
    self.StatusGrid:AddComponent(self.StatusLabel)
    
    -- Current action display
    self.ActionLabel = Methods:CreateLabel(self.StatusGrid.Instance, "Action: None")
    self.StatusGrid:AddComponent(self.ActionLabel)
    
    -- Target display
    self.TargetLabel = Methods:CreateLabel(self.StatusGrid.Instance, "Target: None")
    self.StatusGrid:AddComponent(self.TargetLabel)
    
    -- Message count
    self.MessageCountLabel = Methods:CreateLabel(self.StatusGrid.Instance, "Messages Processed: 0")
    self.StatusGrid:AddComponent(self.MessageCountLabel)
    
    -- Pathfinding stats
    self.PathfindingLabel = Methods:CreateLabel(self.StatusGrid.Instance, "Failed Pathfinds: 0")
    self.StatusGrid:AddComponent(self.PathfindingLabel)
    
    -- Log viewer
    self.LogsLabel = Methods:CreateLabel(self.StatusGrid.Instance, "Recent Logs:")
    self.StatusGrid:AddComponent(self.LogsLabel)
    
    -- Log display (using a textbox as a makeshift log viewer)
    self.LogsBox = Methods:CreateTextBox(self.StatusGrid.Instance, "", function(text)
        -- Read-only, so we just reset it
        self:UpdateLogDisplay()
    end)
    self.LogsBox.Instance.Size = UDim2.new(1, 0, 0, 100)
    self.LogsBox.Instance.TextEditable = false
    self.LogsBox.Instance.TextWrapped = true
    self.LogsBox.Instance.ClearTextOnFocus = false
    self.StatusGrid:AddComponent(self.LogsBox)
end

-- Spam tab setup
function UIManager:SetupSpamTab()
    self.SpamTab = self.Tabs:AddTab("Spam Control")
    self.SpamGrid = Methods:CreateGrid(self.SpamTab)
    
    -- Enable spam detection
    self.SpamDetectionToggle = Methods:CreateSwitch(self.SpamGrid.Instance, "Enable Spam Detection", Config.SPAM_DETECTION.enabled, function(state)
        Config.SPAM_DETECTION.enabled = state
        Logger:info("Spam detection " .. (state and "enabled" or "disabled"))
    end)
    self.SpamGrid:AddComponent(self.SpamDetectionToggle)
    
    -- Message threshold slider
    self.ThresholdSlider = Methods:CreateSlider(self.SpamGrid.Instance, "Message Threshold", 2, 10, Config.SPAM_DETECTION.messageThreshold, function(value)
        Config.SPAM_DETECTION.messageThreshold = value
        Logger:info("Spam message threshold set to " .. value)
    end)
    self.SpamGrid:AddComponent(self.ThresholdSlider)
    
    -- Time window slider
    self.WindowSlider = Methods:CreateSlider(self.SpamGrid.Instance, "Time Window (sec)", 1, 15, Config.SPAM_DETECTION.timeWindow, function(value)
        Config.SPAM_DETECTION.timeWindow = value
        Logger:info("Spam time window set to " .. value .. " seconds")
    end)
    self.SpamGrid:AddComponent(self.WindowSlider)
    
    -- Similarity threshold slider
    self.SimilaritySlider = Methods:CreateSlider(self.SpamGrid.Instance, "Similarity Threshold", 1, 100, Config.SPAM_DETECTION.similarityThreshold * 100, function(value)
        Config.SPAM_DETECTION.similarityThreshold = value / 100
        Logger:info("Spam similarity threshold set to " .. value .. "%")
    end)
    self.SpamGrid:AddComponent(self.SimilaritySlider)
    
    -- Cooldown time slider
    self.CooldownSlider = Methods:CreateSlider(self.SpamGrid.Instance, "Cooldown Time (sec)", 5, 60, Config.SPAM_DETECTION.cooldownTime, function(value)
        Config.SPAM_DETECTION.cooldownTime = value
        Logger:info("Spam cooldown time set to " .. value .. " seconds")
    end)
    self.SpamGrid:AddComponent(self.CooldownSlider)
    
    -- Ignored players list
    self.IgnoredPlayersLabel = Methods:CreateLabel(self.SpamGrid.Instance, "Currently Ignored Players:")
    self.SpamGrid:AddComponent(self.IgnoredPlayersLabel)
    
    self.IgnoredPlayersDisplay = Methods:CreateLabel(self.SpamGrid.Instance, "None")
    self.SpamGrid:AddComponent(self.IgnoredPlayersDisplay)
    
    -- Clear ignored players button
    self.ClearIgnoredButton = Methods:CreateButton(self.SpamGrid.Instance, "Clear Ignored Players", function()
        System.State.IgnoredPlayers = {}
        self.IgnoredPlayersDisplay:SetText("None")
        Logger:info("Cleared all ignored players")
    end)
    self.SpamGrid:AddComponent(self.ClearIgnoredButton)
end

-- Update UI statistics periodically
function UIManager:UpdateUIStats()
    -- Count ignored players
    local ignoredCount = 0
    local ignoredNames = {}
    for name, time in pairs(System.State.IgnoredPlayers) do
        if time > os.time() then
            ignoredCount = ignoredCount + 1
            table.insert(ignoredNames, name)
        else
            -- Clean up expired entries
            System.State.IgnoredPlayers[name] = nil
        end
    end
    
    -- Update ignored players display
    if ignoredCount > 0 then
        self.IgnoredPlayersDisplay:SetText(table.concat(ignoredNames, ", "))
    else
        self.IgnoredPlayersDisplay:SetText("None")
    end
    
    -- Update pathfinding stats
    self.PathfindingLabel:SetText("Failed Pathfinds: " .. System.Modules.MovementManager.FailedPathfinds)
    
    -- Update message count
    self.MessageCountLabel:SetText("Messages Processed: " .. #System.State.MessageLog)
    
    -- Update status labels based on current state
    self.StatusLabel:SetText("Status: " .. (System.State.IsActive and "Active" or "Idle"))
    self.ActionLabel:SetText("Action: " .. (System.State.CurrentAction or "None"))
    self.TargetLabel:SetText("Target: " .. (System.State.CurrentTarget or "None"))
    
    -- Update log display
    self:UpdateLogDisplay()
end

-- Update the log display with recent logs
function UIManager:UpdateLogDisplay()
    local logs = Logger:GetRecentLogs(5) -- Get last 5 logs
    local logText = table.concat(logs, "\n")
    
    if self.LogsBox then
        self.LogsBox:SetText(logText)
    end
end

-- Update status labels in the UI
function UIManager:UpdateStatusLabels(action, target, message)
    -- Update current state
    if action then System.State.CurrentAction = action end
    if target then System.State.CurrentTarget = target end
    
    -- Update UI elements
    self.StatusLabel:SetText("Status: " .. (System.State.IsActive and "Active" or "Idle"))
    self.ActionLabel:SetText("Action: " .. (System.State.CurrentAction or "None"))
    self.TargetLabel:SetText("Target: " .. (System.State.CurrentTarget or "None"))
    
    -- Log the current state
    if action then
        local statusText = "AI Status: " .. action
        if target then statusText = statusText .. " → " .. target end
        if message then statusText = statusText .. " | " .. message end
        Logger:info(statusText)
    end
end

return UIManager

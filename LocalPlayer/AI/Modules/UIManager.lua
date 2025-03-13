-- UI Manager Module
-- /LxckStxp/Censura-Applications/LocalPlayer/AI/Modules/UIManager.lua

local UIManager = {}

local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

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
    -- Create main window using CensuraG's CreateWindow method
    self.Window = _G.CensuraG.CreateWindow("AI Controller")
    self.Window.Frame.Position = UDim2.new(0, 100, 0, 100)
    self.Window:SetSize(350, 500) -- Larger window for more controls
    
    -- Create main grid for content
    self.MainGrid = _G.CensuraG.Methods:CreateGrid(self.Window.ContentFrame)
    
    -- Add category headers and sections
    self:CreateMainControls()
    self:CreateBehaviorControls()
    self:CreateChatControls()
    self:CreateSpamControls()
    self:CreateStatusDisplay()
end

-- Main controls section
function UIManager:CreateMainControls()
    -- Section header
    local mainHeader = _G.CensuraG.Methods:CreateLabel(self.MainGrid.Instance, "🤖 Main Controls")
    mainHeader.Instance.Size = UDim2.new(1, -12, 0, 25)
    mainHeader.Label.TextSize = 16
    mainHeader.Label.Font = Enum.Font.Arcade -- Match Cyberpunk theme
    self.MainGrid:AddComponent(mainHeader)
    
    -- Main toggle
    self.ToggleAI = _G.CensuraG.Methods:CreateSwitch(self.MainGrid.Instance, "Enable AI Controller", false, function(state)
        self.Controller:ToggleAIControl(state)
    end)
    self.MainGrid:AddComponent(self.ToggleAI)
    
    -- Manual actions section
    local actionsHeader = _G.CensuraG.Methods:CreateLabel(self.MainGrid.Instance, "Manual Actions")
    self.MainGrid:AddComponent(actionsHeader)
    
    -- Create a horizontal button layout
    local actionButtonsFrame = Instance.new("Frame")
    actionButtonsFrame.Size = UDim2.new(1, -12, 0, 35)
    actionButtonsFrame.BackgroundTransparency = 1
    actionButtonsFrame.Parent = self.MainGrid.Instance
    
    -- Create horizontal layout
    local actionLayout = Instance.new("UIListLayout")
    actionLayout.FillDirection = Enum.FillDirection.Horizontal
    actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    actionLayout.Padding = UDim.new(0, 10)
    actionLayout.Parent = actionButtonsFrame
    
    -- Wander button
    self.WanderButton = _G.CensuraG.Methods:CreateButton(actionButtonsFrame, "Wander", function()
        if System.State.IsActive then
            System.Modules.MovementManager:Wander(self.Controller)
            self:UpdateStatusLabels("wander", nil)
        end
    end)
    
    -- Say button
    self.SayButton = _G.CensuraG.Methods:CreateButton(actionButtonsFrame, "Say", function()
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
    
    -- Emote button
    self.EmoteButton = _G.CensuraG.Methods:CreateButton(actionButtonsFrame, "Emote", function()
        if System.State.IsActive then
            local emotes = {"wave", "dance", "laugh", "point"}
            System.Modules.MovementManager:PerformEmote(self.Controller, emotes[math.random(1, #emotes)])
        end
    end)
    
    self.MainGrid:AddComponent({Instance = actionButtonsFrame})
    
    -- Add separator
    local separator = Instance.new("Frame")
    separator.Size = UDim2.new(1, -20, 0, 1)
    separator.Position = UDim2.new(0, 10, 0, 0)
    separator.BackgroundColor3 = _G.CensuraG.Config:GetTheme().AccentColor
    separator.BackgroundTransparency = 0.7
    separator.BorderSizePixel = 0
    separator.Parent = self.MainGrid.Instance
    self.MainGrid:AddComponent({Instance = separator})
end

-- Behavior controls section
function UIManager:CreateBehaviorControls()
    -- Section header
    local behaviorHeader = _G.CensuraG.Methods:CreateLabel(self.MainGrid.Instance, "🎮 Behavior Settings")
    behaviorHeader.Instance.Size = UDim2.new(1, -12, 0, 25)
    behaviorHeader.Label.TextSize = 16
    behaviorHeader.Label.Font = Enum.Font.Arcade -- Match Cyberpunk theme
    self.MainGrid:AddComponent(behaviorHeader)
    
    -- Decision interval slider
    self.IntervalSlider = _G.CensuraG.Methods:CreateSlider(self.MainGrid.Instance, "Decision Interval", 2, 15, Config.DECISION_INTERVAL, function(value)
        Config.DECISION_INTERVAL = value
        Logger:info("Decision interval set to " .. value)
    end)
    self.MainGrid:AddComponent(self.IntervalSlider)
    
    -- Detection radius slider
    self.RadiusSlider = _G.CensuraG.Methods:CreateSlider(self.MainGrid.Instance, "Detection Radius", 20, 100, Config.DETECTION_RADIUS, function(value)
        Config.DETECTION_RADIUS = value
        Logger:info("Detection radius set to " .. value)
    end)
    self.MainGrid:AddComponent(self.RadiusSlider)
    
    -- Interaction distance slider
    self.InteractionSlider = _G.CensuraG.Methods:CreateSlider(self.MainGrid.Instance, "Interaction Distance", 3, 15, Config.INTERACTION_DISTANCE, function(value)
        Config.INTERACTION_DISTANCE = value
        Logger:info("Interaction distance set to " .. value)
    end)
    self.MainGrid:AddComponent(self.InteractionSlider)
    
    -- Movement randomization slider
    self.MovementSlider = _G.CensuraG.Methods:CreateSlider(self.MainGrid.Instance, "Movement Randomization", 0, 100, Config.MOVEMENT_RANDOMIZATION * 100, function(value)
        Config.MOVEMENT_RANDOMIZATION = value / 100
        Logger:info("Movement randomization set to " .. value .. "%")
    end)
    self.MainGrid:AddComponent(self.MovementSlider)
    
    -- Add separator
    local separator = Instance.new("Frame")
    separator.Size = UDim2.new(1, -20, 0, 1)
    separator.Position = UDim2.new(0, 10, 0, 0)
    separator.BackgroundColor3 = _G.CensuraG.Config:GetTheme().AccentColor
    separator.BackgroundTransparency = 0.7
    separator.BorderSizePixel = 0
    separator.Parent = self.MainGrid.Instance
    self.MainGrid:AddComponent({Instance = separator})
end

-- Chat controls section
function UIManager:CreateChatControls()
    -- Section header
    local chatHeader = _G.CensuraG.Methods:CreateLabel(self.MainGrid.Instance, "💬 Chat Settings")
    chatHeader.Instance.Size = UDim2.new(1, -12, 0, 25)
    chatHeader.Label.TextSize = 16
    chatHeader.Label.Font = Enum.Font.Arcade -- Match Cyberpunk theme
    self.MainGrid:AddComponent(chatHeader)
    
    -- Max message length slider
    self.MessageLengthSlider = _G.CensuraG.Methods:CreateSlider(self.MainGrid.Instance, "Max Message Length", 100, 500, Config.MAX_MESSAGE_LENGTH, function(value)
        Config.MAX_MESSAGE_LENGTH = value
        Logger:info("Max message length set to " .. value)
    end)
    self.MainGrid:AddComponent(self.MessageLengthSlider)
    
    -- Message delay slider
    self.MessageDelaySlider = _G.CensuraG.Methods:CreateSlider(self.MainGrid.Instance, "Message Delay", 1, 20, Config.MESSAGE_DELAY * 10, function(value)
        Config.MESSAGE_DELAY = value / 10
        Logger:info("Message delay set to " .. Config.MESSAGE_DELAY)
    end)
    self.MainGrid:AddComponent(self.MessageDelaySlider)
    
    -- Chat memory size slider
    self.MemorySizeSlider = _G.CensuraG.Methods:CreateSlider(self.MainGrid.Instance, "Chat Memory Size", 5, 30, Config.CHAT_MEMORY_SIZE, function(value)
        Config.CHAT_MEMORY_SIZE = value
        Logger:info("Chat memory size set to " .. value)
        
        -- Trim message log if needed
        while #System.State.MessageLog > Config.CHAT_MEMORY_SIZE do
            table.remove(System.State.MessageLog, 1)
        end
    end)
    self.MainGrid:AddComponent(self.MemorySizeSlider)
    
    -- Add separator
    local separator = Instance.new("Frame")
    separator.Size = UDim2.new(1, -20, 0, 1)
    separator.Position = UDim2.new(0, 10, 0, 0)
    separator.BackgroundColor3 = _G.CensuraG.Config:GetTheme().AccentColor
    separator.BackgroundTransparency = 0.7
    separator.BorderSizePixel = 0
    separator.Parent = self.MainGrid.Instance
    self.MainGrid:AddComponent({Instance = separator})
end

-- Spam controls section
function UIManager:CreateSpamControls()
    -- Section header
    local spamHeader = _G.CensuraG.Methods:CreateLabel(self.MainGrid.Instance, "🛡️ Spam Protection")
    spamHeader.Instance.Size = UDim2.new(1, -12, 0, 25)
    spamHeader.Label.TextSize = 16
    spamHeader.Label.Font = Enum.Font.Arcade -- Match Cyberpunk theme
    self.MainGrid:AddComponent(spamHeader)
    
    -- Enable spam detection
    self.SpamDetectionToggle = _G.CensuraG.Methods:CreateSwitch(self.MainGrid.Instance, "Enable Spam Detection", Config.SPAM_DETECTION.enabled, function(state)
        Config.SPAM_DETECTION.enabled = state
        Logger:info("Spam detection " .. (state and "enabled" or "disabled"))
    end)
    self.MainGrid:AddComponent(self.SpamDetectionToggle)
    
    -- Message threshold slider
    self.ThresholdSlider = _G.CensuraG.Methods:CreateSlider(self.MainGrid.Instance, "Message Threshold", 2, 10, Config.SPAM_DETECTION.messageThreshold, function(value)
        Config.SPAM_DETECTION.messageThreshold = value
        Logger:info("Spam message threshold set to " .. value)
    end)
    self.MainGrid:AddComponent(self.ThresholdSlider)
    
    -- Time window slider
    self.WindowSlider = _G.CensuraG.Methods:CreateSlider(self.MainGrid.Instance, "Time Window (sec)", 1, 15, Config.SPAM_DETECTION.timeWindow, function(value)
        Config.SPAM_DETECTION.timeWindow = value
        Logger:info("Spam time window set to " .. value .. " seconds")
    end)
    self.MainGrid:AddComponent(self.WindowSlider)
    
    -- Cooldown time slider
    self.CooldownSlider = _G.CensuraG.Methods:CreateSlider(self.MainGrid.Instance, "Cooldown Time (sec)", 5, 60, Config.SPAM_DETECTION.cooldownTime, function(value)
        Config.SPAM_DETECTION.cooldownTime = value
        Logger:info("Spam cooldown time set to " .. value .. " seconds")
    end)
    self.MainGrid:AddComponent(self.CooldownSlider)
    
    -- Ignored players list
    self.IgnoredPlayersLabel = _G.CensuraG.Methods:CreateLabel(self.MainGrid.Instance, "Currently Ignored Players:")
    self.MainGrid:AddComponent(self.IgnoredPlayersLabel)
    
    self.IgnoredPlayersDisplay = _G.CensuraG.Methods:CreateLabel(self.MainGrid.Instance, "None")
    self.MainGrid:AddComponent(self.IgnoredPlayersDisplay)
    
    -- Clear ignored players button
    self.ClearIgnoredButton = _G.CensuraG.Methods:CreateButton(self.MainGrid.Instance, "Clear Ignored Players", function()
        System.State.IgnoredPlayers = {}
        self.IgnoredPlayersDisplay:SetText("None")
        Logger:info("Cleared all ignored players")
    end)
    self.MainGrid:AddComponent(self.ClearIgnoredButton)
    
    -- Add separator
    local separator = Instance.new("Frame")
    separator.Size = UDim2.new(1, -20, 0, 1)
    separator.Position = UDim2.new(0, 10, 0, 0)
    separator.BackgroundColor3 = _G.CensuraG.Config:GetTheme().AccentColor
    separator.BackgroundTransparency = 0.7
    separator.BorderSizePixel = 0
    separator.Parent = self.MainGrid.Instance
    self.MainGrid:AddComponent({Instance = separator})
end

-- Status display section
function UIManager:CreateStatusDisplay()
    -- Section header
    local statusHeader = _G.CensuraG.Methods:CreateLabel(self.MainGrid.Instance, "📊 Status")
    statusHeader.Instance.Size = UDim2.new(1, -12, 0, 25)
    statusHeader.Label.TextSize = 16
    statusHeader.Label.Font = Enum.Font.Arcade -- Match Cyberpunk theme
    self.MainGrid:AddComponent(statusHeader)
    
    -- Create a frame for status indicators
    local statusFrame = Instance.new("Frame")
    statusFrame.Size = UDim2.new(1, -12, 0, 75)
    statusFrame.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
    statusFrame.BackgroundTransparency = 0.8
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = self.MainGrid.Instance
    
    -- Add corner radius
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 4)
    statusCorner.Parent = statusFrame
    
    -- Add stroke for border
    local statusStroke = Instance.new("UIStroke")
    statusStroke.Color = _G.CensuraG.Config:GetTheme().AccentColor
    statusStroke.Transparency = 0.7
    statusStroke.Thickness = 1
    statusStroke.Parent = statusFrame
    
    -- Status indicators
    self.StatusLabel = Instance.new("TextLabel")
    self.StatusLabel.Size = UDim2.new(1, -20, 0, 20)
    self.StatusLabel.Position = UDim2.new(0, 10, 0, 5)
    self.StatusLabel.BackgroundTransparency = 1
    self.StatusLabel.Text = "Status: Idle"
    self.StatusLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    self.StatusLabel.Font = _G.CensuraG.Config:GetTheme().Font
    self.StatusLabel.TextSize = 14
    self.StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.StatusLabel.Parent = statusFrame
    
    self.ActionLabel = Instance.new("TextLabel")
    self.ActionLabel.Size = UDim2.new(1, -20, 0, 20)
    self.ActionLabel.Position = UDim2.new(0, 10, 0, 25)
    self.ActionLabel.BackgroundTransparency = 1
    self.ActionLabel.Text = "Action: None"
    self.ActionLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    self.ActionLabel.Font = _G.CensuraG.Config:GetTheme().Font
    self.ActionLabel.TextSize = 14
    self.ActionLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.ActionLabel.Parent = statusFrame
    
    self.TargetLabel = Instance.new("TextLabel")
    self.TargetLabel.Size = UDim2.new(1, -20, 0, 20)
    self.TargetLabel.Position = UDim2.new(0, 10, 0, 45)
    self.TargetLabel.BackgroundTransparency = 1
    self.TargetLabel.Text = "Target: None"
    self.TargetLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    self.TargetLabel.Font = _G.CensuraG.Config:GetTheme().Font
    self.TargetLabel.TextSize = 14
    self.TargetLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.TargetLabel.Parent = statusFrame
    
    self.MainGrid:AddComponent({Instance = statusFrame})
    
    -- Message count and pathfinding stats
    local statsFrame = Instance.new("Frame")
    statsFrame.Size = UDim2.new(1, -12, 0, 30)
    statsFrame.BackgroundTransparency = 1
    statsFrame.Parent = self.MainGrid.Instance
    
    -- Create layout for stats
    local statsLayout = Instance.new("UIListLayout")
    statsLayout.FillDirection = Enum.FillDirection.Horizontal
    statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    statsLayout.Padding = UDim.new(0, 10)
    statsLayout.Parent = statsFrame
    
    -- Message count
    self.MessageCountLabel = Instance.new("TextLabel")
    self.MessageCountLabel.Size = UDim2.new(0.5, -10, 1, 0)
    self.MessageCountLabel.BackgroundTransparency = 1
    self.MessageCountLabel.Text = "Messages: 0"
    self.MessageCountLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    self.MessageCountLabel.Font = _G.CensuraG.Config:GetTheme().Font
    self.MessageCountLabel.TextSize = 14
    self.MessageCountLabel.Parent = statsFrame
    
    -- Pathfinding stats
    self.PathfindingLabel = Instance.new("TextLabel")
    self.PathfindingLabel.Size = UDim2.new(0.5, -10, 1, 0)
    self.PathfindingLabel.BackgroundTransparency = 1
    self.PathfindingLabel.Text = "Failed Paths: 0"
    self.PathfindingLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    self.PathfindingLabel.Font = _G.CensuraG.Config:GetTheme().Font
    self.PathfindingLabel.TextSize = 14
    self.PathfindingLabel.Parent = statsFrame
    
    self.MainGrid:AddComponent({Instance = statsFrame})
    
    -- Version info at the bottom
    local versionLabel = _G.CensuraG.Methods:CreateLabel(self.MainGrid.Instance, "AI Controller v1.0")
    versionLabel.Label.TextSize = 12
    versionLabel.Label.TextColor3 = _G.CensuraG.Config:GetTheme().SecondaryTextColor
    self.MainGrid:AddComponent(versionLabel)
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
    self.PathfindingLabel.Text = "Failed Paths: " .. System.Modules.MovementManager.FailedPathfinds
    
    -- Update message count
    self.MessageCountLabel.Text = "Messages: " .. #System.State.MessageLog
    
    -- Update status labels based on current state
    self.StatusLabel.Text = "Status: " .. (System.State.IsActive and "Active" or "Idle")
    self.ActionLabel.Text = "Action: " .. (System.State.CurrentAction or "None")
    self.TargetLabel.Text = "Target: " .. (System.State.CurrentTarget or "None")
end

-- Update status labels in the UI
function UIManager:UpdateStatusLabels(action, target, message)
    -- Update current state
    if action then System.State.CurrentAction = action end
    if target then System.State.CurrentTarget = target end
    
    -- Update UI elements
    self.StatusLabel.Text = "Status: " .. (System.State.IsActive and "Active" or "Idle")
    self.ActionLabel.Text = "Action: " .. (System.State.CurrentAction or "None")
    self.TargetLabel.Text = "Target: " .. (System.State.CurrentTarget or "None")
    
    -- Log the current state
    if action then
        local statusText = "AI Status: " .. action
        if target then statusText = statusText .. " → " .. target end
        if message then statusText = statusText .. " | " .. message end
        Logger:info(statusText)
    end
end

return UIManager

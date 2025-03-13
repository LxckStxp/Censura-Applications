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
    self.Window:SetSize(350, 400) -- Set a reasonable window size
    
    -- Create a scrolling frame to contain all content
    self.ScrollFrame = Instance.new("ScrollingFrame")
    self.ScrollFrame.Size = UDim2.new(1, -16, 1, -10) -- Leave space for scrollbar
    self.ScrollFrame.Position = UDim2.new(0, 8, 0, 5)
    self.ScrollFrame.BackgroundTransparency = 1
    self.ScrollFrame.BorderSizePixel = 0
    self.ScrollFrame.ScrollBarThickness = 6
    self.ScrollFrame.ScrollBarImageColor3 = _G.CensuraG.Config:GetTheme().AccentColor
    self.ScrollFrame.ScrollBarImageTransparency = 0.3
    self.ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 1000) -- Will adjust this dynamically
    self.ScrollFrame.Parent = self.Window.ContentFrame
    
    -- Create a UIListLayout for automatic vertical arrangement
    self.ListLayout = Instance.new("UIListLayout")
    self.ListLayout.Padding = UDim.new(0, 8)
    self.ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    self.ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    self.ListLayout.Parent = self.ScrollFrame
    
    -- Add padding for better aesthetics
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = self.ScrollFrame
    
    -- Add category headers and sections
    self:CreateMainControls()
    self:CreateBehaviorControls()
    self:CreateChatControls()
    self:CreateSpamControls()
    self:CreateStatusDisplay()
    
    -- Update canvas size based on content
    self.ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        self.ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, self.ListLayout.AbsoluteContentSize.Y + 20)
    end)
    
    -- Initial canvas size update
    self.ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, self.ListLayout.AbsoluteContentSize.Y + 20)
end

-- Main controls section
function UIManager:CreateMainControls()
    -- Section header
    local mainHeader = self:CreateSectionHeader("🤖 Main Controls")
    
    -- Main toggle
    self.ToggleAI = _G.CensuraG.Methods:CreateSwitch(self.ScrollFrame, "Enable AI Controller", false, function(state)
        self.Controller:ToggleAIControl(state)
    end)
    
    -- Manual actions section
    local actionsHeader = self:CreateLabel("Manual Actions")
    
    -- Wander button
    self.WanderButton = _G.CensuraG.Methods:CreateButton(self.ScrollFrame, "Wander", function()
        if System.State.IsActive then
            System.Modules.MovementManager:Wander(self.Controller)
            self:UpdateStatusLabels("wander", nil)
        end
    end)
    
    -- Say button
    self.SayButton = _G.CensuraG.Methods:CreateButton(self.ScrollFrame, "Say Something", function()
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
    self.EmoteButton = _G.CensuraG.Methods:CreateButton(self.ScrollFrame, "Random Emote", function()
        if System.State.IsActive then
            local emotes = {"wave", "dance", "laugh", "point"}
            System.Modules.MovementManager:PerformEmote(self.Controller, emotes[math.random(1, #emotes)])
        end
    end)
    
    -- Add separator
    self:CreateSeparator()
end

-- Behavior controls section
function UIManager:CreateBehaviorControls()
    -- Section header
    local behaviorHeader = self:CreateSectionHeader("🎮 Behavior Settings")
    
    -- Decision interval slider
    self.IntervalSlider = _G.CensuraG.Methods:CreateSlider(self.ScrollFrame, "Decision Interval", 2, 15, Config.DECISION_INTERVAL, function(value)
        Config.DECISION_INTERVAL = value
        Logger:info("Decision interval set to " .. value)
    end)
    
    -- Detection radius slider
    self.RadiusSlider = _G.CensuraG.Methods:CreateSlider(self.ScrollFrame, "Detection Radius", 20, 100, Config.DETECTION_RADIUS, function(value)
        Config.DETECTION_RADIUS = value
        Logger:info("Detection radius set to " .. value)
    end)
    
    -- Interaction distance slider
    self.InteractionSlider = _G.CensuraG.Methods:CreateSlider(self.ScrollFrame, "Interaction Distance", 3, 15, Config.INTERACTION_DISTANCE, function(value)
        Config.INTERACTION_DISTANCE = value
        Logger:info("Interaction distance set to " .. value)
    end)
    
    -- Movement randomization slider
    self.MovementSlider = _G.CensuraG.Methods:CreateSlider(self.ScrollFrame, "Movement Randomization", 0, 100, Config.MOVEMENT_RANDOMIZATION * 100, function(value)
        Config.MOVEMENT_RANDOMIZATION = value / 100
        Logger:info("Movement randomization set to " .. value .. "%")
    end)
    
    -- Add separator
    self:CreateSeparator()
end

-- Chat controls section
function UIManager:CreateChatControls()
    -- Section header
    local chatHeader = self:CreateSectionHeader("💬 Chat Settings")
    
    -- Max message length slider
    self.MessageLengthSlider = _G.CensuraG.Methods:CreateSlider(self.ScrollFrame, "Max Message Length", 100, 500, Config.MAX_MESSAGE_LENGTH, function(value)
        Config.MAX_MESSAGE_LENGTH = value
        Logger:info("Max message length set to " .. value)
    end)
    
    -- Message delay slider
    self.MessageDelaySlider = _G.CensuraG.Methods:CreateSlider(self.ScrollFrame, "Message Delay", 1, 20, Config.MESSAGE_DELAY * 10, function(value)
        Config.MESSAGE_DELAY = value / 10
        Logger:info("Message delay set to " .. Config.MESSAGE_DELAY)
    end)
    
    -- Chat memory size slider
    self.MemorySizeSlider = _G.CensuraG.Methods:CreateSlider(self.ScrollFrame, "Chat Memory Size", 5, 30, Config.CHAT_MEMORY_SIZE, function(value)
        Config.CHAT_MEMORY_SIZE = value
        Logger:info("Chat memory size set to " .. value)
        
        -- Trim message log if needed
        while #System.State.MessageLog > Config.CHAT_MEMORY_SIZE do
            table.remove(System.State.MessageLog, 1)
        end
    end)
    
    -- Max concurrent conversations slider
    self.ConversationsSlider = _G.CensuraG.Methods:CreateSlider(self.ScrollFrame, "Max Conversations", 1, 5, System.Modules.ChatManager.MaxConcurrentConversations, function(value)
        System.Modules.ChatManager.MaxConcurrentConversations = value
        Logger:info("Max concurrent conversations set to " .. value)
    end)
    
    -- Conversation timeout slider
    self.TimeoutSlider = _G.CensuraG.Methods:CreateSlider(self.ScrollFrame, "Conversation Timeout", 10, 60, System.Modules.ChatManager.ConversationTimeout, function(value)
        System.Modules.ChatManager.ConversationTimeout = value
        Logger:info("Conversation timeout set to " .. value .. " seconds")
    end)
    
    -- Add separator
    self:CreateSeparator()
end

-- Spam controls section
function UIManager:CreateSpamControls()
    -- Section header
    local spamHeader = self:CreateSectionHeader("🛡️ Spam Protection")
    
    -- Enable spam detection
    self.SpamDetectionToggle = _G.CensuraG.Methods:CreateSwitch(self.ScrollFrame, "Enable Spam Detection", Config.SPAM_DETECTION.enabled, function(state)
        Config.SPAM_DETECTION.enabled = state
        Logger:info("Spam detection " .. (state and "enabled" or "disabled"))
    end)
    
    -- Message threshold slider
    self.ThresholdSlider = _G.CensuraG.Methods:CreateSlider(self.ScrollFrame, "Message Threshold", 2, 10, Config.SPAM_DETECTION.messageThreshold, function(value)
        Config.SPAM_DETECTION.messageThreshold = value
        Logger:info("Spam message threshold set to " .. value)
    end)
    
    -- Time window slider
    self.WindowSlider = _G.CensuraG.Methods:CreateSlider(self.ScrollFrame, "Time Window (sec)", 1, 15, Config.SPAM_DETECTION.timeWindow, function(value)
        Config.SPAM_DETECTION.timeWindow = value
        Logger:info("Spam time window set to " .. value .. " seconds")
    end)
    
    -- Cooldown time slider
    self.CooldownSlider = _G.CensuraG.Methods:CreateSlider(self.ScrollFrame, "Cooldown Time (sec)", 5, 60, Config.SPAM_DETECTION.cooldownTime, function(value)
        Config.SPAM_DETECTION.cooldownTime = value
        Logger:info("Spam cooldown time set to " .. value .. " seconds")
    end)
    
    -- Ignored players list
    local ignoredPlayersLabel = self:CreateLabel("Currently Ignored Players:")
    
    self.IgnoredPlayersDisplay = self:CreateLabel("None")
    
    -- Clear ignored players button
    self.ClearIgnoredButton = _G.CensuraG.Methods:CreateButton(self.ScrollFrame, "Clear Ignored Players", function()
        System.State.IgnoredPlayers = {}
        -- Directly update Text property instead of using SetText
        self.IgnoredPlayersDisplay.Text = "None"
        Logger:info("Cleared all ignored players")
    end)
    
    -- Add separator
    self:CreateSeparator()
end

-- Status display section
function UIManager:CreateStatusDisplay()
    -- Section header
    local statusHeader = self:CreateSectionHeader("📊 Status")
    
    -- Create a frame for status indicators
    local statusFrame = Instance.new("Frame")
    statusFrame.Size = UDim2.new(1, -20, 0, 75)
    statusFrame.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
    statusFrame.BackgroundTransparency = 0.8
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = self.ScrollFrame
    
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
    
    -- Active conversations display
    local conversationsLabel = self:CreateLabel("Active Conversations:")
    
    self.ConversationsDisplay = self:CreateLabel("None")
    
    -- Message count and pathfinding stats
    local statsFrame = Instance.new("Frame")
    statsFrame.Size = UDim2.new(1, -20, 0, 30)
    statsFrame.BackgroundTransparency = 1
    statsFrame.Parent = self.ScrollFrame
    
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
    
    -- Version info at the bottom
    local versionLabel = self:CreateLabel("AI Controller v1.0")
    versionLabel.TextSize = 12
    versionLabel.TextColor3 = _G.CensuraG.Config:GetTheme().SecondaryTextColor
end

-- Helper function to create section headers
function UIManager:CreateSectionHeader(text)
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -20, 0, 25)
    header.BackgroundTransparency = 1
    header.Text = text
    header.TextColor3 = _G.CensuraG.Config:GetTheme().AccentColor
    header.Font = Enum.Font.Arcade -- Match Cyberpunk theme
    header.TextSize = 16
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = self.ScrollFrame
    return header
end

-- Helper function to create labels
function UIManager:CreateLabel(text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    label.Font = _G.CensuraG.Config:GetTheme().Font
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = self.ScrollFrame
    return label
end

-- Helper function to create separators
function UIManager:CreateSeparator()
    local separator = Instance.new("Frame")
    separator.Size = UDim2.new(1, -20, 0, 1)
    separator.BackgroundColor3 = _G.CensuraG.Config:GetTheme().AccentColor
    separator.BackgroundTransparency = 0.7
    separator.BorderSizePixel = 0
    separator.Parent = self.ScrollFrame
    return separator
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
    
    -- Update ignored players display - directly set Text property
    if ignoredCount > 0 then
        self.IgnoredPlayersDisplay.Text = table.concat(ignoredNames, ", ")
    else
        self.IgnoredPlayersDisplay.Text = "None"
    end
    
    -- Count active conversations
    local conversationCount = 0
    local conversationNames = {}
    for name, time in pairs(System.Modules.ChatManager.ActiveConversations) do
        conversationCount = conversationCount + 1
        table.insert(conversationNames, name)
    end
    
    -- Update active conversations display - directly set Text property
    if conversationCount > 0 then
        self.ConversationsDisplay.Text = table.concat(conversationNames, ", ")
    else
        self.ConversationsDisplay.Text = "None"
    end
    
    -- Update pathfinding stats
    self.PathfindingLabel.Text = "Failed Paths: " .. System.Modules.MovementManager.FailedPathfinds
    
    -- Update message count
    self.MessageCountLabel.Text = "Messages: " .. #System.State.MessageLog
    
    -- Update status labels based on current state
    self.StatusLabel.Text = "Status: " .. (System.State.IsActive and "Active" or "Idle")
    self.ActionLabel.Text = "Action: " .. (System.State.CurrentAction or "None")
    self.TargetLabel.Text = "Target: " .. (System.State.CurrentTarget or "None")
    
    -- Update canvas size (in case content has changed)
    self.ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, self.ListLayout.AbsoluteContentSize.Y + 20)
end

-- Update status labels in the UI
function UIManager:UpdateStatusLabels(action, target, message)
    -- Update current state
    if action then System.State.CurrentAction = action end
    if target then System.State.CurrentTarget = target end
    
    -- Update UI elements - directly set Text properties
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

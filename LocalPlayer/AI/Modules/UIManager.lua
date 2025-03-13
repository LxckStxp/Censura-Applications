-- UI Manager Module
local UIManager = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

function UIManager:Initialize(controller)
    self.Controller = controller
    self:SetupUI()
    
    task.spawn(function()
        while task.wait(1) do
            self:UpdateUIStats()
        end
    end)
    
    return self
end

function UIManager:SetupUI()
    self.Window = _G.CensuraG.CreateWindow("AI Controller")
    self.Window.Frame.Position = UDim2.new(0, 100, 0, 100)
    self.Window:SetSize(350, 400)
    
    -- Scrolling frame setup
    self.ScrollFrame = Instance.new("ScrollingFrame")
    self.ScrollFrame.Size = UDim2.new(1, -16, 1, -10)
    self.ScrollFrame.Position = UDim2.new(0, 8, 0, 5)
    self.ScrollFrame.BackgroundTransparency = 1
    self.ScrollFrame.ScrollBarThickness = 6
    self.ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Auto-adjusted later
    self.ScrollFrame.Parent = self.Window.ContentFrame
    
    self.ListLayout = Instance.new("UIListLayout")
    self.ListLayout.Padding = UDim.new(0, 8)
    self.ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    self.ListLayout.Parent = self.ScrollFrame
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = self.ScrollFrame
    
    -- UI Sections
    self:CreateSections()
    
    -- Dynamic canvas size
    self.ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        self.ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, self.ListLayout.AbsoluteContentSize.Y + 20)
    end)
end

function UIManager:CreateSections()
    self:CreateMainControls()
    self:CreateBehaviorControls()
    self:CreateChatControls()
    self:CreateSpamControls()
    self:CreateStatusDisplay()
end

function UIManager:CreateMainControls()
    self:CreateSectionHeader("🤖 Main Controls")
    
    self.ToggleAI = _G.CensuraG.Methods:CreateSwitch(self.ScrollFrame, "Enable AI", false, function(state)
        self.Controller:ToggleAIControl(state)
    end)
    
    self.WanderButton = _G.CensuraG.Methods:CreateButton(self.ScrollFrame, "Wander", function()
        if System.State.IsActive then
            System.Modules.MovementManager:Wander(self.Controller)
            self:UpdateStatusLabels("wander", nil)
        end
    end)
    
    self.SayButton = _G.CensuraG.Methods:CreateButton(self.ScrollFrame, "Say", function()
        if System.State.IsActive then
            local phrases = {"Hey all!", "What’s up?", "Exploring here!", "Cool place!"}
            local message = phrases[math.random(1, #phrases)]
            System.Modules.ChatManager:SendMessage(message)
            self:UpdateStatusLabels("say", nil, message)
        end
    end)
    
    self.EmoteButton = _G.CensuraG.Methods:CreateButton(self.ScrollFrame, "Emote", function()
        if System.State.IsActive then
            local emotes = {"wave", "dance", "laugh"}
            System.Modules.MovementManager:PerformEmote(self.Controller, emotes[math.random(1, #emotes)])
        end
    end)
    
    self:CreateSeparator()
end

function UIManager:CreateBehaviorControls()
    self:CreateSectionHeader("🎮 Behavior")
    
    self.IntervalSlider = self:CreateSlider("Decision Interval", 2, 15, Config.DECISION_INTERVAL, function(value)
        Config.DECISION_INTERVAL = value
    end)
    
    self.RadiusSlider = self:CreateSlider("Detection Radius", 20, 100, Config.DETECTION_RADIUS, function(value)
        Config.DETECTION_RADIUS = value
    end)
    
    self.InteractionSlider = self:CreateSlider("Interaction Distance", 3, 15, Config.INTERACTION_DISTANCE, function(value)
        Config.INTERACTION_DISTANCE = value
    end)
    
    self:CreateSeparator()
end

function UIManager:CreateChatControls()
    self:CreateSectionHeader("💬 Chat")
    
    self.MessageLengthSlider = self:CreateSlider("Max Message Length", 100, 500, Config.MAX_MESSAGE_LENGTH, function(value)
        Config.MAX_MESSAGE_LENGTH = value
    end)
    
    self.MemorySizeSlider = self:CreateSlider("Chat Memory", 5, 30, Config.CHAT_MEMORY_SIZE, function(value)
        Config.CHAT_MEMORY_SIZE = value
        while #System.State.MessageLog > value do table.remove(System.State.MessageLog, 1) end
    end)
    
    self:CreateSeparator()
end

function UIManager:CreateSpamControls()
    self:CreateSectionHeader("🛡️ Spam")
    
    self.SpamToggle = _G.CensuraG.Methods:CreateSwitch(self.ScrollFrame, "Spam Detection", Config.SPAM_DETECTION.enabled, function(state)
        Config.SPAM_DETECTION.enabled = state
    end)
    
    self.ThresholdSlider = self:CreateSlider("Message Threshold", 2, 10, Config.SPAM_DETECTION.messageThreshold, function(value)
        Config.SPAM_DETECTION.messageThreshold = value
    end)
    
    self.IgnoredPlayersLabel = self:CreateLabel("Ignored Players: None")
    self.ClearIgnoredButton = _G.CensuraG.Methods:CreateButton(self.ScrollFrame, "Clear Ignored", function()
        System.State.IgnoredPlayers = {}
        self.IgnoredPlayersLabel.Text = "Ignored Players: None"
    end)
    
    self:CreateSeparator()
end

function UIManager:CreateStatusDisplay()
    self:CreateSectionHeader("📊 Status")
    
    self.StatusFrame = Instance.new("Frame")
    self.StatusFrame.Size = UDim2.new(1, -20, 0, 60)
    self.StatusFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    self.StatusFrame.BackgroundTransparency = 0.8
    self.StatusFrame.Parent = self.ScrollFrame
    
    local corner = Instance.new("UICorner", self.StatusFrame)
    corner.CornerRadius = UDim.new(0, 4)
    
    self.StatusLabel = self:CreateLabel("Status: Idle", self.StatusFrame, UDim2.new(0, 10, 0, 5))
    self.ActionLabel = self:CreateLabel("Action: None", self.StatusFrame, UDim2.new(0, 10, 0, 20))
    self.TargetLabel = self:CreateLabel("Target: None", self.StatusFrame, UDim2.new(0, 10, 0, 35))
    
    self.ConversationsLabel = self:CreateLabel("Conversations: None")
    self.StatsLabel = self:CreateLabel("Messages: 0 | Failed Paths: 0")
end

function UIManager:CreateSectionHeader(text)
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -20, 0, 25)
    header.BackgroundTransparency = 1
    header.Text = text
    header.TextColor3 = Color3.fromRGB(0, 170, 255)
    header.Font = Enum.Font.Arcade
    header.TextSize = 16
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = self.ScrollFrame
    return header
end

function UIManager:CreateLabel(text, parent, position)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = position or UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent or self.ScrollFrame
    return label
end

function UIManager:CreateSlider(name, min, max, default, callback)
    return _G.CensuraG.Methods:CreateSlider(self.ScrollFrame, name, min, max, default, function(value)
        callback(value)
        Logger:info(name .. " set to " .. value)
    end)
end

function UIManager:CreateSeparator()
    local separator = Instance.new("Frame")
    separator.Size = UDim2.new(1, -20, 0, 1)
    separator.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    separator.BackgroundTransparency = 0.7
    separator.BorderSizePixel = 0
    separator.Parent = self.ScrollFrame
end

function UIManager:UpdateUIStats()
    local ignored = {}
    for name, time in pairs(System.State.IgnoredPlayers) do
        if time > os.time() then table.insert(ignored, name) end
    end
    self.IgnoredPlayersLabel.Text = "Ignored Players: " .. (#ignored > 0 and table.concat(ignored, ", ") or "None")
    
    local conversations = {}
    for name in pairs(System.Modules.ChatManager.ActiveConversations) do
        table.insert(conversations, name)
    end
    self.ConversationsLabel.Text = "Conversations: " .. (#conversations > 0 and table.concat(conversations, ", ") or "None")
    
    self.StatsLabel.Text = string.format(
        "Messages: %d | Failed Paths: %d",
        #System.State.MessageLog,
        System.Modules.MovementManager.FailedPathfinds
    )
    
    self.StatusLabel.Text = "Status: " .. (System.State.IsActive and "Active" or "Idle")
    self.ActionLabel.Text = "Action: " .. (System.State.CurrentAction or "None")
    self.TargetLabel.Text = "Target: " .. (System.State.CurrentTarget or "None")
end

function UIManager:UpdateStatusLabels(action, target, message)
    if action then System.State.CurrentAction = action end
    if target then System.State.CurrentTarget = target end
    
    self:UpdateUIStats()
    if action then
        Logger:info("UI Updated: " .. action .. (target and " → " .. target or "") .. (message and " | " .. message or ""))
    end
end

return UIManager

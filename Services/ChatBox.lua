-- ChatService.lua
-- Custom chat interface application built with CensuraG UI API using TextChatService

-- Ensure CensuraG is loaded
if not _G.CensuraG then
    error("CensuraG UI API not found. Please ensure CensuraG is loaded before running ChatService.lua")
end

local ChatService = {
    Players = {},         -- Stores player data: {Messages, LastMessage, MessageCount, Name, DisplayName, Color, LastMessageFrame}
    ChatWindow = nil,     -- Reference to the CensuraG window
    MessageQueue = {},    -- Tracks message frames for display
    MAX_MESSAGES = 100,   -- Limits the number of displayed messages
    FilterText = "",      -- Current filter text
    LocalPlayerName = game.Players.LocalPlayer.Name,  -- Local player's name for mentions
    LastUpdateTime = 0,   -- For debouncing updates
    UPDATE_DELAY = 0.1    -- Debounce delay in seconds
}

-- Services
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- Helper Functions
local function getPlayerColor(userId)
    local hash = 0
    for i = 1, #tostring(userId) do
        hash = (hash * 31 + string.byte(tostring(userId), i)) % 16777216
    end
    return Color3.fromHSV(hash / 16777216, 0.7, 0.9)
end

local function shortenUsername(username)
    return #username > 10 and (username:sub(1, 10) .. "...") or username
end

-- Player Management
local function addPlayer(player)
    ChatService.Players[player.UserId] = {
        Messages = {},
        LastMessage = nil,
        MessageCount = 0,
        Name = player.Name,
        DisplayName = shortenUsername(player.DisplayName),
        Color = getPlayerColor(player.UserId),
        LastMessageFrame = nil
    }
    player.Chatted:Connect(function(message)
        ChatService:LogMessage(player, message)
    end)
end

local function removePlayer(player)
    ChatService.Players[player.UserId] = nil
end

-- Log and Stack Messages
function ChatService:LogMessage(player, message)
    local playerData = self.Players[player.UserId]
    if not playerData then return end
    local timestamp = os.date("%H:%M:%S")

    if playerData.LastMessage == message and playerData.LastMessageFrame then
        playerData.MessageCount = playerData.MessageCount + 1
        local messageLabel = playerData.LastMessageFrame:FindFirstChild("MessageLabel")
        if messageLabel then
            messageLabel.Text = message .. " (x" .. playerData.MessageCount .. ")"
        end
    else
        local messageData = {Text = message, Count = 1, Timestamp = timestamp}
        playerData.LastMessage = message
        playerData.MessageCount = 1
        playerData.LastMessageFrame = self:AddMessageToFeed(playerData, messageData)
        table.insert(playerData.Messages, {Text = message, Count = playerData.MessageCount, Timestamp = timestamp})
    end

    -- Debounced update
    local currentTime = tick()
    if currentTime - self.LastUpdateTime >= self.UPDATE_DELAY then
        self:UpdateChatFeed()
        self.LastUpdateTime = currentTime
    end
end

-- Add Message to Chat Feed
function ChatService:AddMessageToFeed(playerData, messageData)
    local theme = _G.CensuraG.Config:GetTheme()
    local messageFrame = Instance.new("Frame")
    messageFrame.Name = "MessageFrame"
    messageFrame.Size = UDim2.new(1, -10, 0, 30)
    messageFrame.BackgroundTransparency = 1
    messageFrame.Parent = self.ChatFeedFrame

    -- Player Name Label
    local nameLabel = Instance.new("TextLabel", messageFrame)
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(0, 100, 0, 20)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = playerData.DisplayName .. ":"
    nameLabel.TextColor3 = playerData.Color
    nameLabel.Font = theme.Font
    nameLabel.TextSize = 14
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Message Label with Mention Highlighting
    local messageLabel = Instance.new("TextLabel", messageFrame)
    messageLabel.Name = "MessageLabel"
    messageLabel.Size = UDim2.new(1, -160, 0, 20)
    messageLabel.Position = UDim2.new(0, 105, 0, 0)
    messageLabel.BackgroundTransparency = 1
    local messageText = messageData.Text
    if messageText:find("@" .. self.LocalPlayerName) then
        messageText = messageText:gsub("@" .. self.LocalPlayerName, "<font color=\"rgb(255,0,0)\">@" .. self.LocalPlayerName .. "</font>")
        messageLabel.RichText = true
    end
    messageLabel.Text = messageText .. (messageData.Count > 1 and " (x" .. messageData.Count .. ")" or "")
    messageLabel.TextColor3 = theme.TextColor
    messageLabel.Font = theme.Font
    messageLabel.TextSize = 14
    messageLabel.TextXAlignment = Enum.TextXAlignment.Left
    messageLabel.TextWrapped = true

    -- Timestamp Label
    local timestampLabel = Instance.new("TextLabel", messageFrame)
    timestampLabel.Name = "TimestampLabel"
    timestampLabel.Size = UDim2.new(0, 50, 0, 20)
    timestampLabel.Position = UDim2.new(1, -55, 0, 0)
    timestampLabel.BackgroundTransparency = 1
    timestampLabel.Text = messageData.Timestamp
    timestampLabel.TextColor3 = theme.SecondaryTextColor or Color3.fromRGB(150, 150, 150)
    timestampLabel.Font = theme.Font
    timestampLabel.TextSize = 12
    timestampLabel.TextXAlignment = Enum.TextXAlignment.Right

    -- Right-Click to Copy
    messageLabel.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            setclipboard(messageData.Text)
            _G.CensuraG.Logger:info("Copied message to clipboard")
        end
    end)

    -- Manage Message Queue
    table.insert(self.MessageQueue, messageFrame)
    if #self.MessageQueue > self.MAX_MESSAGES then
        local removedFrame = table.remove(self.MessageQueue, 1)
        if removedFrame then
            removedFrame:Destroy()
        end
    end

    -- Update CanvasSize and scroll to bottom
    local contentHeight = self.FeedLayout.AbsoluteContentSize.Y
    self.ChatFeedFrame.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
    self.ChatFeedFrame.CanvasPosition = Vector2.new(0, math.max(0, contentHeight - self.ChatFeedFrame.AbsoluteSize.Y))
    return messageFrame
end

-- Update Chat Feed with Filter
function ChatService:UpdateChatFeed()
    for _, frame in ipairs(self.MessageQueue) do
        local messageLabel = frame:FindFirstChild("MessageLabel")
        if messageLabel then
            local originalText = messageLabel.Text:match("^(.-)(%s*%(x%d+%)?)$") or messageLabel.Text
            frame.Visible = self.FilterText == "" or originalText:lower():find(self.FilterText:lower()) ~= nil
        end
    end
end

-- Command System
local commands = {
    tp = {
        description = "Teleport to a player",
        execute = function(args)
            if #args < 1 then
                _G.CensuraG.Logger:warn("Usage: /tp playername")
                return
            end
            local targetName = args[1]:lower()
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Name:lower():find(targetName) then
                    local localPlayer = Players.LocalPlayer
                    if localPlayer.Character and player.Character then
                        local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
                        local targetHrp = player.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and targetHrp then
                            hrp.CFrame = targetHrp.CFrame
                            _G.CensuraG.Logger:info("Teleported to " .. player.Name)
                            return
                        end
                    end
                    _G.CensuraG.Logger:warn("Character not found")
                    return
                end
            end
            _G.CensuraG.Logger:warn("Player '" .. targetName .. "' not found")
        end
    },
    exec = {
        description = "Execute a script",
        execute = function(args)
            if #args < 1 then
                _G.CensuraG.Logger:warn("Usage: /exec script")
                return
            end
            local script = table.concat(args, " ")
            local success, err = pcall(function()
                loadstring(script)()  -- Replace with exploit's script execution method if different
            end)
            if success then
                _G.CensuraG.Logger:info("Script executed successfully")
            else
                _G.CensuraG.Logger:error("Error executing script: " .. err)
            end
        end
    }
}

-- Initialize ChatService
function ChatService:Initialize()
    -- Connect Players
    for _, player in ipairs(Players:GetPlayers()) do
        addPlayer(player)
    end
    Players.PlayerAdded:Connect(addPlayer)
    Players.PlayerRemoving:Connect(removePlayer)

    -- Create Window
    self.ChatWindow = _G.CensuraG.CreateWindow("Chat Service")
    self.ChatWindow:SetSize(400, 300)
    self.ChatWindow.Frame.Position = UDim2.new(0.5, -200, 0.5, -150)

    -- Create a grid layout for organizing components
    local grid = _G.CensuraG.Components.grid(self.ChatWindow.ContentFrame)
    if not grid then
        _G.CensuraG.Logger:error("Failed to create grid layout for ChatService")
        return
    end

    -- Filter Input Area
    local filterFrame = Instance.new("Frame")
    filterFrame.Size = UDim2.new(1, -20, 0, 30)
    filterFrame.BackgroundTransparency = 1

    local filterInput = Instance.new("TextBox", filterFrame)
    filterInput.Size = UDim2.new(1, 0, 1, 0)
    filterInput.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
    filterInput.BackgroundTransparency = 0.8
    filterInput.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    filterInput.Font = _G.CensuraG.Config:GetTheme().Font
    filterInput.TextSize = 14
    filterInput.Text = ""
    filterInput.PlaceholderText = "Filter messages..."

    local filterCorner = Instance.new("UICorner", filterInput)
    filterCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)

    filterInput:GetPropertyChangedSignal("Text"):Connect(function()
        self.FilterText = filterInput.Text
        self:UpdateChatFeed()
    end)

    -- Chat Feed (ScrollingFrame)
    self.ChatFeedFrame = Instance.new("ScrollingFrame")
    self.ChatFeedFrame.Name = "ChatFeed"
    self.ChatFeedFrame.Size = UDim2.new(1, -20, 1, -100) -- Adjusted to fit between filter and input
    self.ChatFeedFrame.BackgroundTransparency = 0.8
    self.ChatFeedFrame.BackgroundColor3 = _G.CensuraG.Config:GetTheme().PrimaryColor
    self.ChatFeedFrame.ScrollBarThickness = 6
    self.ChatFeedFrame.ScrollBarImageColor3 = _G.CensuraG.Config:GetTheme().AccentColor
    self.ChatFeedFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    local feedCorner = Instance.new("UICorner", self.ChatFeedFrame)
    feedCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)

    self.FeedLayout = Instance.new("UIListLayout", self.ChatFeedFrame)
    self.FeedLayout.Padding = UDim.new(0, 5)
    self.FeedLayout.SortOrder = Enum.SortOrder.LayoutOrder
    self.FeedLayout.VerticalAlignment = Enum.VerticalAlignment.Top

    -- Chat Input Area
    local inputFrame = Instance.new("Frame")
    inputFrame.Size = UDim2.new(1, -20, 0, 40)
    inputFrame.BackgroundTransparency = 1

    local inputBox = Instance.new("TextBox", inputFrame)
    inputBox.Size = UDim2.new(1, -60, 1, 0)
    inputBox.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
    inputBox.BackgroundTransparency = 0.8
    inputBox.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    inputBox.Font = _G.CensuraG.Config:GetTheme().Font
    inputBox.TextSize = 14
    inputBox.Text = ""
    inputBox.PlaceholderText = "" -- Removed placeholder text
    inputBox.ClearTextOnFocus = false

    local inputCorner = Instance.new("UICorner", inputBox)
    inputCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)

    -- Custom Send Button
    local sendButtonFrame = Instance.new("Frame", inputFrame)
    sendButtonFrame.Size = UDim2.new(0, 50, 1, 0)
    sendButtonFrame.Position = UDim2.new(1, -50, 0, 0)
    sendButtonFrame.BackgroundColor3 = _G.CensuraG.Config:GetTheme().AccentColor
    sendButtonFrame.BackgroundTransparency = 0.7

    local sendButtonCorner = Instance.new("UICorner", sendButtonFrame)
    sendButtonCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)

    local sendButtonStroke = Instance.new("UIStroke", sendButtonFrame)
    sendButtonStroke.Color = _G.CensuraG.Config:GetTheme().BorderColor
    sendButtonStroke.Transparency = 0.6
    sendButtonStroke.Thickness = _G.CensuraG.Config.Math.BorderThickness

    local sendButtonLabel = Instance.new("TextLabel", sendButtonFrame)
    sendButtonLabel.Size = UDim2.new(1, 0, 1, 0)
    sendButtonLabel.BackgroundTransparency = 1
    sendButtonLabel.Text = "Send"
    sendButtonLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    sendButtonLabel.Font = _G.CensuraG.Config:GetTheme().Font
    sendButtonLabel.TextSize = 14

    local sendButton = Instance.new("TextButton", sendButtonFrame)
    sendButton.Size = UDim2.new(1, 0, 1, 0)
    sendButton.BackgroundTransparency = 1
    sendButton.Text = ""
    local function sendMessage()
        local message = inputBox.Text
        if message == "" then return end
        if message:sub(1, 1) == "/" then
            local args = message:sub(2):split(" ")
            local command = table.remove(args, 1)
            if commands[command] then
                commands[command].execute(args)
            else
                _G.CensuraG.Logger:warn("Unknown command: " .. command)
            end
        else
            local success, err = pcall(function()
                TextChatService.TextChannels.RBXGeneral:SendAsync(message)
            end)
            if success then
                _G.CensuraG.Logger:info("Message sent to Roblox chat: " .. message)
                -- Log the sent message to the chat feed manually (without triggering Chatted)
                self:AddMessageToFeed(self.Players[LocalPlayer.UserId], {Text = message, Count = 1, Timestamp = os.date("%H:%M:%S")})
            else
                _G.CensuraG.Logger:error("Error sending message: " .. err)
                self:AddMessageToFeed(self.Players[LocalPlayer.UserId], {Text = message, Count = 1, Timestamp = os.date("%H:%M:%S")}) -- Log locally if failed
            end
        end
        inputBox.Text = ""
    end
    sendButton.MouseButton1Click:Connect(sendMessage)
    inputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            sendMessage()
        end
    end)

    sendButton.MouseEnter:Connect(function()
        _G.CensuraG.AnimationManager:Tween(sendButtonFrame, {BackgroundTransparency = 0.5}, 0.2)
        _G.CensuraG.AnimationManager:Tween(sendButtonStroke, {Transparency = 0.2}, 0.2)
    end)

    sendButton.MouseLeave:Connect(function()
        _G.CensuraG.AnimationManager:Tween(sendButtonFrame, {BackgroundTransparency = 0.7}, 0.2)
        _G.CensuraG.AnimationManager:Tween(sendButtonStroke, {Transparency = 0.6}, 0.2)
    end)

    -- Add components to grid: filter, chat feed, input
    grid:AddComponent({Instance = filterFrame})
    grid:AddComponent({Instance = self.ChatFeedFrame})
    grid:AddComponent({Instance = inputFrame})

    -- Theme change handler
    local function onThemeChange()
        _G.CensuraG.Logger:info("Theme changed, refreshing ChatService UI")
        self.ChatWindow:Refresh()
        
        filterInput.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
        filterInput.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
        filterInput.Font = _G.CensuraG.Config:GetTheme().Font
        
        self.ChatFeedFrame.BackgroundColor3 = _G.CensuraG.Config:GetTheme().PrimaryColor
        self.ChatFeedFrame.ScrollBarImageColor3 = _G.CensuraG.Config:GetTheme().AccentColor
        
        inputBox.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
        inputBox.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
        inputBox.Font = _G.CensuraG.Config:GetTheme().Font
        
        sendButtonFrame.BackgroundColor3 = _G.CensuraG.Config:GetTheme().AccentColor
        sendButtonStroke.Color = _G.CensuraG.Config:GetTheme().BorderColor
        sendButtonLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
        sendButtonLabel.Font = _G.CensuraG.Config:GetTheme().Font

        -- Refresh message labels
        for _, frame in ipairs(self.MessageQueue) do
            local nameLabel = frame:FindFirstChild("NameLabel")
            local messageLabel = frame:FindFirstChild("MessageLabel")
            local timestampLabel = frame:FindFirstChild("TimestampLabel")
            if messageLabel then
                messageLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
                messageLabel.Font = _G.CensuraG.Config:GetTheme().Font
            end
            if nameLabel then
                nameLabel.Font = _G.CensuraG.Config:GetTheme().Font
            end
            if timestampLabel then
                timestampLabel.TextColor3 = _G.CensuraG.Config:GetTheme().SecondaryTextColor or Color3.fromRGB(150, 150, 150)
                timestampLabel.Font = _G.CensuraG.Config:GetTheme().Font
            end
        end
    end

    -- Connect theme change
    if _G.CensuraG.Config then
        _G.CensuraG.SetTheme = function(themeName)
            _G.CensuraG.Config.CurrentTheme = themeName
            _G.CensuraG.RefreshAll()
            onThemeChange()
        end
    end

    -- Initial message
    self:AddMessageToFeed(self.Players[LocalPlayer.UserId], {Text = "ChatService initialized!", Count = 1, Timestamp = os.date("%H:%M:%S")})
end

-- Start the Service
ChatService:Initialize()
return ChatService

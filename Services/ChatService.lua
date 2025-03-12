-- ChatService.lua
local ChatService = {
    Players = {},         -- Stores player data: {Messages, LastMessage, MessageCount, Name, DisplayName, Color, LastMessageFrame}
    ChatWindow = nil,     -- Reference to the CensuraG window
    MessageQueue = {},    -- Tracks message frames for display
    MAX_MESSAGES = 100,   -- Limits the number of displayed messages
    FilterText = "",      -- Current filter text
    LocalPlayerName = game.Players.LocalPlayer.Name  -- Local player's name for mentions
}

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
    end
    table.insert(playerData.Messages, {Text = message, Count = playerData.MessageCount, Timestamp = timestamp})
end

-- Add Message to Chat Feed
function ChatService:AddMessageToFeed(playerData, messageData)
    local theme = _G.CensuraG.Config:GetTheme()
    local messageFrame = Instance.new("Frame")
    messageFrame.Size = UDim2.new(1, -10, 0, 30)
    messageFrame.BackgroundTransparency = 1
    messageFrame.Parent = self.ChatWindow.ContentFrame

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
        table.remove(self.MessageQueue, 1):Destroy()
    end

    self:UpdateChatFeed()
    self.ChatWindow.ContentFrame.CanvasPosition = Vector2.new(0, self.ChatWindow.ContentFrame.CanvasSize.Y.Offset)
    return messageFrame
end

-- Update Chat Feed with Filter
function ChatService:UpdateChatFeed()
    for _, frame in ipairs(self.MessageQueue) do
        local messageLabel = frame:FindFirstChild("MessageLabel")
        if messageLabel then
            frame.Visible = self.FilterText == "" or messageLabel.Text:lower():find(self.FilterText:lower()) ~= nil
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
            for _, player in ipairs(game.Players:GetPlayers()) do
                if player.Name:lower():find(targetName) then
                    local localPlayer = game.Players.LocalPlayer
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
    for _, player in ipairs(game.Players:GetPlayers()) do
        addPlayer(player)
    end
    game.Players.PlayerAdded:Connect(addPlayer)
    game.Players.PlayerRemoving:Connect(removePlayer)

    -- Create Window
    self.ChatWindow = _G.CensuraG.CreateWindow("Chat Service")
    self.ChatWindow.Frame.Size = UDim2.new(0, 400, 0, 300)
    self.ChatWindow.Frame.Position = UDim2.new(0.5, -200, 0.5, -150)
    self.ChatWindow.ContentFrame.Size = UDim2.new(1, -12, 1, -116)

    -- Filter Input
    local filterFrame = Instance.new("Frame", self.ChatWindow.Frame)
    filterFrame.Size = UDim2.new(1, -12, 0, 30)
    filterFrame.Position = UDim2.new(0, 6, 0, 36)
    filterFrame.BackgroundTransparency = 1

    local filterInput = Instance.new("TextBox", filterFrame)
    filterInput.Size = UDim2.new(1, 0, 1, 0)
    filterInput.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
    filterInput.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    filterInput.Font = _G.CensuraG.Config:GetTheme().Font
    filterInput.TextSize = 14
    filterInput.PlaceholderText = "Filter messages..."
    filterInput:GetPropertyChangedSignal("Text"):Connect(function()
        self.FilterText = filterInput.Text
        self:UpdateChatFeed()
    end)

    -- Chat Input and Send Button
    local inputFrame = Instance.new("Frame", self.ChatWindow.Frame)
    inputFrame.Size = UDim2.new(1, -12, 0, 40)
    inputFrame.Position = UDim2.new(0, 6, 1, -50)
    inputFrame.BackgroundTransparency = 1

    local inputBox = Instance.new("TextBox", inputFrame)
    inputBox.Size = UDim2.new(1, -60, 1, 0)
    inputBox.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
    inputBox.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    inputBox.Font = _G.CensuraG.Config:GetTheme().Font
    inputBox.TextSize = 14
    inputBox.PlaceholderText = ">"

    local sendButton = Instance.new("TextButton", inputFrame)
    sendButton.Size = UDim2.new(0, 50, 1, 0)
    sendButton.Position = UDim2.new(1, -50, 0, 0)
    sendButton.Text = "Send"
    sendButton.BackgroundColor3 = _G.CensuraG.Config:GetTheme().AccentColor
    sendButton.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    sendButton.Font = _G.CensuraG.Config:GetTheme().Font
    sendButton.TextSize = 14

    -- Send Message Function
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
            chat(message)  -- Replace with your exploit's chat function
        end
        inputBox.Text = ""
    end

    sendButton.MouseButton1Click:Connect(sendMessage)
    inputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then sendMessage() end
    end)
end

-- Start the Service
ChatService:Initialize()
return ChatService

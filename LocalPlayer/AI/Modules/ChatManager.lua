-- Chat Manager Module
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local localPlayer = Players.LocalPlayer

local ChatManager = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

-- Configuration and state
ChatManager.Settings = {
    MaxConcurrentConversations = 2,
    ConversationTimeout = 60,
    MinResponseInterval = 1.5,
    MessageCacheDuration = 300 -- 5 minutes
}
ChatManager.RespondedMessages = {}
ChatManager.ActiveConversations = {}
ChatManager.LastMessageTime = 0

ChatManager.FallbackResponses = {
    "Hey, that's interesting!",
    "What’s up with that?",
    "I’ve been exploring too!",
    "Cool, tell me more!"
}

function ChatManager:Initialize(controller)
    self.Controller = controller
    self:SetupChatHandler()
    
    task.spawn(function()
        while task.wait(10) do
            self:CleanupState()
        end
    end)
    
    return self
end

function ChatManager:CleanupState()
    local currentTime = os.time()
    for player, time in pairs(self.ActiveConversations) do
        if currentTime - time > self.Settings.ConversationTimeout then
            self.ActiveConversations[player] = nil
            Logger:info("Conversation timeout with " .. player)
        end
    end
    
    for id, _ in pairs(self.RespondedMessages) do
        local timestamp = tonumber(id:match(":(%d+)$") or 0)
        if currentTime - timestamp > self.Settings.MessageCacheDuration then
            self.RespondedMessages[id] = nil
        end
    end
end

function ChatManager:SetupChatHandler()
    Players.PlayerAdded:Connect(function(player)
        if player ~= localPlayer then
            self:ConnectPlayerChat(player)
        end
    end)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            self:ConnectPlayerChat(player)
        end
    end
    
    if TextChatService.MessageReceived then
        TextChatService.MessageReceived:Connect(function(message)
            self:HandleMessage(message.TextSource, message.Text)
        end)
    end
end

function ChatManager:ConnectPlayerChat(player)
    player.Chatted:Connect(function(message)
        self:HandleMessage({ UserId = player.UserId, Name = player.Name }, message)
    end)
end

function ChatManager:HandleMessage(sender, message)
    if not sender or sender.UserId == localPlayer.UserId then return end
    
    local player = Players:GetPlayerByUserId(sender.UserId) or Players:FindFirstChild(sender.Name)
    if not player then return end
    
    local messageId = player.Name .. ":" .. message .. ":" .. os.time()
    if self.RespondedMessages[messageId] then return end
    
    local isSpam = System.Modules.SpamDetection:IsSpam(player.Name, message)
    self.RespondedMessages[messageId] = not isSpam
    
    if not isSpam then
        self:ReceiveMessage(player.Name, message)
        if System.State.IsActive and self:ShouldRespondToChat(message, player.Name) then
            self.Controller:QueryGrokWithChat(message, player.Name)
        end
    else
        Logger:warn("Spam detected from " .. player.Name .. ": " .. message)
    end
end

function ChatManager:ShouldRespondToChat(message, sender)
    local currentTime = os.time()
    if currentTime - self.LastMessageTime < self.Settings.MinResponseInterval then
        return false
    end
    
    local activeCount = 0
    for _ in pairs(self.ActiveConversations) do activeCount = activeCount + 1 end
    
    local lowerMessage = message:lower()
    if lowerMessage:find(localPlayer.Name:lower()) then
        self.ActiveConversations[sender] = currentTime
        self.LastMessageTime = currentTime
        return true
    end
    
    if self.ActiveConversations[sender] then
        self.ActiveConversations[sender] = currentTime
        self.LastMessageTime = currentTime
        return true
    end
    
    if activeCount >= self.Settings.MaxConcurrentConversations then
        return self:IsCriticalMessage(message, sender)
    end
    
    local player = Players:FindFirstChild(sender)
    if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local distance = (player.Character.HumanoidRootPart.Position - self.Controller.RootPart.Position).Magnitude
        local probability = distance <= Config.DETECTION_RADIUS * 0.5 and 0.6 or 0.3
        if distance <= Config.DETECTION_RADIUS and (self:IsEngagingMessage(lowerMessage) or math.random() < probability) then
            self.ActiveConversations[sender] = currentTime
            self.LastMessageTime = currentTime
            return true
        end
    end
    
    return false
end

function ChatManager:IsCriticalMessage(message, sender)
    local player = Players:FindFirstChild(sender)
    if not player or not player.Character then return false end
    
    local distance = (player.Character.HumanoidRootPart.Position - self.Controller.RootPart.Position).Magnitude
    return distance <= Config.DETECTION_RADIUS * 0.3 and self:IsEngagingMessage(message:lower())
end

function ChatManager:IsEngagingMessage(message)
    return message:find("?") or message:match("^(hi|hello|hey|sup|yo)")
end

function ChatManager:ReceiveMessage(sender, message)
    table.insert(System.State.MessageLog, {
        sender = sender,
        message = message,
        timestamp = os.time()
    })
    while #System.State.MessageLog > Config.CHAT_MEMORY_SIZE do
        table.remove(System.State.MessageLog, 1)
    end
end

function ChatManager:IsInConversationWith(playerName)
    return self.ActiveConversations[playerName] ~= nil
end

function ChatManager:StartConversation(playerName)
    self.ActiveConversations[playerName] = os.time()
    Logger:info("Conversation started with " .. playerName)
end

function ChatManager:SendMessage(message)
    if not message or #message == 0 then return end
    
    local channel = TextChatService.TextChannels and TextChatService.TextChannels.RBXGeneral
    if not channel then
        Logger:warn("No RBXGeneral channel available")
        return
    end
    
    local chunks = self:ChunkMessage(message)
    task.spawn(function()
        for i, chunk in ipairs(chunks) do
            local typingTime = math.min(#chunk * Config.TYPING_SPEED.min, 4)
            task.wait(typingTime)
            channel:SendAsync(chunk)
            if i < #chunks then task.wait(Config.MESSAGE_DELAY + math.random() * 0.5) end
        end
        self.LastMessageTime = os.time()
    end)
end

function ChatManager:ChunkMessage(message)
    if #message <= Config.MAX_MESSAGE_LENGTH then return {message} end
    
    local chunks = {}
    while #message > 0 do
        local chunk = message:sub(1, Config.MAX_MESSAGE_LENGTH)
        local breakPoint = chunk:find("%s[^%s]*$") or Config.MAX_MESSAGE_LENGTH + 1
        table.insert(chunks, chunk:sub(1, breakPoint - 1))
        message = message:sub(breakPoint):match("^%s*(.-)%s*$") or ""
    end
    return chunks
end

return ChatManager

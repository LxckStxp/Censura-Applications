local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local localPlayer = Players.LocalPlayer

local ChatManager = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

ChatManager.RespondedMessages = {}
ChatManager.ActiveConversations = {}
ChatManager.Settings = {
    MaxConcurrentConversations = 2,
    ConversationTimeout = 60,
    MinResponseInterval = 1.5
}
ChatManager.LastMessageTime = 0

ChatManager.FallbackResponses = {
    "Hey, that's cool!",
    "What do you think about that?",
    "I've been checking out this place too.",
    "Nice to chat with you!"
}

function ChatManager:Initialize(controller)
    self.Controller = controller
    self:SetupChatHandler()
    
    task.spawn(function()
        while task.wait(10) do
            self:CleanupConversations()
            self:CleanupMessages()
        end
    end)
    
    return self
end

function ChatManager:CleanupConversations()
    local currentTime = os.time()
    for player, lastTime in pairs(self.ActiveConversations) do
        if currentTime - lastTime > self.Settings.ConversationTimeout then
            self.ActiveConversations[player] = nil
            Logger:info("Conversation with " .. player .. " timed out")
        end
    end
end

function ChatManager:CleanupMessages()
    local currentTime = os.time()
    for id, _ in pairs(self.RespondedMessages) do
        if currentTime - tonumber(id:match(":(%d+)$") or 0) > 300 then
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
            self:HandleTextChat(message)
        end)
    end
end

function ChatManager:HandleTextChat(textChatMessage)
    local sender = textChatMessage.TextSource
    if not sender or sender.UserId == localPlayer.UserId then return end
    
    local player = Players:GetPlayerByUserId(sender.UserId)
    if not player then return end
    
    local message = textChatMessage.Text
    local messageId = player.Name .. ":" .. message .. ":" .. os.time()
    
    if self.RespondedMessages[messageId] then return end
    
    if not System.Modules.SpamDetection:IsSpam(player.Name, message) then
        self.RespondedMessages[messageId] = true
        self:ReceiveMessage(player.Name, message)
        
        if System.State.IsActive and self:ShouldRespondToChat(message, player.Name) then
            self.Controller:QueryGrokWithChat(message, player.Name)
        end
    else
        Logger:warn("Ignored spam from " .. player.Name)
    end
end

function ChatManager:ConnectPlayerChat(player)
    player.Chatted:Connect(function(message)
        local messageId = player.Name .. ":" .. message .. ":" .. os.time()
        if self.RespondedMessages[messageId] then return end
        
        if not System.Modules.SpamDetection:IsSpam(player.Name, message) then
            self.RespondedMessages[messageId] = true
            self:ReceiveMessage(player.Name, message)
            
            if System.State.IsActive and self:ShouldRespondToChat(message, player.Name) then
                self.Controller:QueryGrokWithChat(message, player.Name)
            end
        end
    end)
end

function ChatManager:ShouldRespondToChat(message, sender)
    local currentTime = os.time()
    if currentTime - self.LastMessageTime < self.Settings.MinResponseInterval then
        return false
    end
    
    local activeCount = table.getn(self.ActiveConversations)
    if message:lower():find(localPlayer.Name:lower()) then
        self:UpdateConversation(sender, currentTime)
        return true
    end
    
    if self.ActiveConversations[sender] then
        self:UpdateConversation(sender, currentTime)
        return true
    end
    
    if activeCount >= self.Settings.MaxConcurrentConversations then
        return self:ShouldRespondWhenBusy(message, sender)
    end
    
    local senderPlayer = Players:FindFirstChild(sender)
    if senderPlayer and senderPlayer.Character then
        local distance = (senderPlayer.Character.HumanoidRootPart.Position - self.Controller.RootPart.Position).Magnitude
        if distance <= Config.DETECTION_RADIUS then
            self:UpdateConversation(sender, currentTime)
            return math.random() < (self:IsQuestionOrGreeting(message) and 0.8 or 0.3)
        end
    end
    
    return false
end

function ChatManager:ShouldRespondWhenBusy(message, sender)
    local player = Players:FindFirstChild(sender)
    if player and player.Character then
        local distance = (player.Character.HumanoidRootPart.Position - self.Controller.RootPart.Position).Magnitude
        return distance <= Config.DETECTION_RADIUS * 0.3 and self:IsQuestionOrGreeting(message)
    end
    return false
end

function ChatManager:IsQuestionOrGreeting(message)
    return message:find("?") or message:lower():match("^(hi|hello|hey|sup|yo)")
end

function ChatManager:UpdateConversation(sender, time)
    self.ActiveConversations[sender] = time
    self.LastMessageTime = time
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

function ChatManager:StartConversation(playerName)
    self.ActiveConversations[playerName] = os.time()
end

function ChatManager:SendMessage(message)
    if not message or #message == 0 then return end
    
    local channel = TextChatService.TextChannels and TextChatService.TextChannels.RBXGeneral
    if not channel then return end
    
    task.spawn(function()
        for _, chunk in ipairs(self:ChunkMessage(message)) do
            local typingTime = math.min(#chunk * Config.TYPING_SPEED.min, 4)
            task.wait(typingTime)
            channel:SendAsync(chunk)
            task.wait(Config.MESSAGE_DELAY)
        end
        self.LastMessageTime = os.time()
    end)
end

function ChatManager:ChunkMessage(message)
    local chunks = {}
    while #message > 0 do
        if #message <= Config.MAX_MESSAGE_LENGTH then
            table.insert(chunks, message)
            break
        end
        
        local chunk = message:sub(1, Config.MAX_MESSAGE_LENGTH)
        local breakPoint = chunk:find("%s[^%s]*$") or Config.MAX_MESSAGE_LENGTH + 1
        table.insert(chunks, chunk:sub(1, breakPoint - 1))
        message = message:sub(breakPoint):match("^%s*(.-)%s*$") or ""
    end
    return chunks
end

return ChatManager

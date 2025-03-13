-- Chat Manager Module
-- /LxckStxp/Censura-Applications/LocalPlayer/AI/Modules/ChatManager.lua

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local localPlayer = Players.LocalPlayer

local ChatManager = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

-- Track which messages we've responded to and active conversations
ChatManager.RespondedMessages = {}
ChatManager.ActiveConversations = {}
ChatManager.MaxConcurrentConversations = 1 -- Only talk to one person at a time
ChatManager.ConversationTimeout = 30 -- Seconds before a conversation is considered inactive

function ChatManager:Initialize(controller)
    self.Controller = controller
    
    -- Set up chat event handlers
    self:SetupChatHandler()
    
    -- Start conversation cleanup timer
    spawn(function()
        while wait(10) do -- Check every 10 seconds
            self:CleanupOldConversations()
        end
    end)
    
    return self
end

-- Clean up old conversations to allow new ones
function ChatManager:CleanupOldConversations()
    local currentTime = os.time()
    local toRemove = {}
    
    for player, lastTime in pairs(self.ActiveConversations) do
        if currentTime - lastTime > self.ConversationTimeout then
            table.insert(toRemove, player)
        end
    end
    
    for _, player in ipairs(toRemove) do
        self.ActiveConversations[player] = nil
        Logger:info("Ended conversation with " .. player .. " due to inactivity")
    end
end

-- Setup Chat Handler
function ChatManager:SetupChatHandler()
    -- Handle existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            self:ConnectPlayerChat(player)
        end
    end
    
    -- Handle new players
    Players.PlayerAdded:Connect(function(player)
        self:ConnectPlayerChat(player)
    end)
    
    -- Setup TextChatService if available for newer chat system
    if TextChatService and TextChatService.MessageReceived then
        TextChatService.MessageReceived:Connect(function(textChatMessage)
            local sender = textChatMessage.TextSource
            if sender and sender.UserId ~= localPlayer.UserId then
                local playerObj = Players:GetPlayerByUserId(sender.UserId)
                if playerObj then
                    -- Process the message through spam filter
                    local isSpam = System.Modules.SpamDetection:IsSpam(playerObj.Name, textChatMessage.Text)
                    if not isSpam then
                        -- Check if we've already responded to this message
                        local messageId = playerObj.Name .. ":" .. textChatMessage.Text .. ":" .. os.time()
                        
                        if not self.RespondedMessages[messageId] then
                            self.RespondedMessages[messageId] = true
                            
                            self:ReceiveMessage(playerObj.Name, textChatMessage.Text)
                            
                            if System.State.IsActive and self:ShouldRespondToChat(textChatMessage.Text, playerObj.Name) then
                                self.Controller:QueryGrokWithChat(textChatMessage.Text, playerObj.Name)
                            end
                        else
                            Logger:info("Skipping duplicate message from " .. playerObj.Name)
                        end
                    else
                        Logger:warn("Ignored spam message from " .. playerObj.Name)
                    end
                end
            end
        end)
    end
end

-- Connect chat for a specific player
function ChatManager:ConnectPlayerChat(player)
    player.Chatted:Connect(function(message)
        -- Process the message through spam filter
        local isSpam = System.Modules.SpamDetection:IsSpam(player.Name, message)
        if not isSpam then
            -- Check if we've already responded to this message
            local messageId = player.Name .. ":" .. message .. ":" .. os.time()
            
            if not self.RespondedMessages[messageId] then
                self.RespondedMessages[messageId] = true
                
                self:ReceiveMessage(player.Name, message)
                
                if System.State.IsActive and self:ShouldRespondToChat(message, player.Name) then
                    self.Controller:QueryGrokWithChat(message, player.Name)
                end
            else
                Logger:info("Skipping duplicate message from " .. player.Name)
            end
        else
            Logger:warn("Ignored spam message from " .. player.Name)
        end
    end)
end

-- Improved logic for determining if AI should respond
function ChatManager:ShouldRespondToChat(message, sender)
    -- Check if we're already in too many conversations
    local activeCount = 0
    for _, lastTime in pairs(self.ActiveConversations) do
        activeCount = activeCount + 1
    end
    
    -- If we're at max conversations and this isn't an active conversation partner, don't respond
    if activeCount >= self.MaxConcurrentConversations and not self.ActiveConversations[sender] then
        local namesMentioned = false
        
        -- Exception: Always respond if directly addressed
        if message:lower():find(localPlayer.Name:lower()) then
            namesMentioned = true
        end
        
        if not namesMentioned then
            Logger:info("Not responding to " .. sender .. " - already in " .. activeCount .. " conversations")
            return false
        end
    end
    
    -- Always respond if our name is mentioned (already checked above for the exception case)
    if message:lower():find(localPlayer.Name:lower()) then
        -- Start or update conversation
        self.ActiveConversations[sender] = os.time()
        return true
    end
    
    -- Respond to active conversation partners
    if self.ActiveConversations[sender] then
        -- Update conversation timestamp
        self.ActiveConversations[sender] = os.time()
        return true
    end
    
    -- Check if player is nearby
    local senderPlayer = Players:FindFirstChild(sender)
    if senderPlayer and senderPlayer.Character and senderPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local distance = (senderPlayer.Character.HumanoidRootPart.Position - self.Controller.RootPart.Position).Magnitude
        if distance <= Config.DETECTION_RADIUS * 0.5 then -- Reduced from 0.7 to be more selective
            -- If player is close and we don't have too many conversations, start a new one
            if activeCount < self.MaxConcurrentConversations then
                self.ActiveConversations[sender] = os.time()
                return true
            else
                -- Otherwise only respond occasionally
                return math.random() < 0.15 -- Reduced chance (15% instead of 30%)
            end
        end
    end
    
    -- Respond rarely to other messages if not in too many conversations
    if activeCount < self.MaxConcurrentConversations then
        return math.random() < 0.1 -- Very low chance (10%)
    end
    
    return false -- Don't respond by default
end

-- Receive and Log Messages
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

-- Function to check if we're in a conversation with someone
function ChatManager:IsInConversationWith(playerName)
    return self.ActiveConversations[playerName] ~= nil
end

-- Function to start a conversation with someone
function ChatManager:StartConversation(playerName)
    self.ActiveConversations[playerName] = os.time()
    Logger:info("Started conversation with " .. playerName)
end

-- Function to end a conversation with someone
function ChatManager:EndConversation(playerName)
    self.ActiveConversations[playerName] = nil
    Logger:info("Ended conversation with " .. playerName)
end

-- Send Message with realistic typing simulation
function ChatManager:SendMessage(message)
    if not message or message == "" then return end
    
    local generalChannel = TextChatService.TextChannels and TextChatService.TextChannels.RBXGeneral
    if not generalChannel then
        Logger:warn("RBXGeneral channel not found. Cannot send message: " .. tostring(message))
        return
    end
    
    -- Split into chunks if needed
    local chunks = self:ChunkMessage(message)
    
    -- Send with realistic typing delays
    spawn(function()
        for i, chunk in ipairs(chunks) do
            if #chunk > 0 then
                -- Simulate typing time based on message length
                -- For longer messages, we'll use a slightly reduced per-character time
                local typingSpeed = math.max(Config.TYPING_SPEED.min * 0.8, Config.TYPING_SPEED.min - (#chunk / 1000))
                local typingTime = #chunk * (math.random(typingSpeed * 100, Config.TYPING_SPEED.max * 100) / 100)
                
                -- Cap typing time at a reasonable maximum
                typingTime = math.min(typingTime, 4)
                
                wait(typingTime)
                
                -- Send the message
                generalChannel:SendAsync(chunk)
                Logger:info("Sent message chunk (" .. #chunk .. " chars): " .. chunk)
                
                -- Wait between chunks
                if i < #chunks then
                    wait(Config.MESSAGE_DELAY + math.random() * 0.5)
                end
            end
        end
    end)
end

-- Chunk a message into larger pieces for realistic sending
function ChatManager:ChunkMessage(message)
    local chunks = {}
    
    -- If message is already short enough, return it as a single chunk
    if #message <= Config.MAX_MESSAGE_LENGTH then
        table.insert(chunks, message)
        return chunks
    end
    
    while #message > 0 do
        if #message <= Config.MAX_MESSAGE_LENGTH then
            -- If remaining message fits in one chunk, add it and break
            table.insert(chunks, message)
            break
        end
        
        -- Take a chunk of the maximum size
        local chunk = message:sub(1, Config.MAX_MESSAGE_LENGTH)
        
        -- Try to find a good breaking point (sentence end or space)
        local sentenceEnd = chunk:match(".*()%.%s")
        local lastSpace = chunk:find("%s[^%s]*$")
        
        local breakPoint
        if sentenceEnd and sentenceEnd > Config.MAX_MESSAGE_LENGTH * 0.7 then
            -- Prefer breaking at the end of sentences if it's at least 70% into the chunk
            breakPoint = sentenceEnd
        elseif lastSpace then
            -- Otherwise break at the last space
            breakPoint = lastSpace
        else
            -- If no good breaking point, just use the max length
            breakPoint = Config.MAX_MESSAGE_LENGTH + 1
        end
        
        -- Add the chunk and remove it from the message
        table.insert(chunks, message:sub(1, breakPoint - 1))
        message = message:sub(breakPoint):match("^%s*(.-)%s*$") or ""
    end
    
    return chunks
end

-- Cleanup old responded messages to prevent memory leak
function ChatManager:CleanupRespondedMessages()
    local currentTime = os.time()
    local toRemove = {}
    
    -- Find old message IDs (older than 5 minutes)
    for messageId, _ in pairs(self.RespondedMessages) do
        local timestamp = tonumber(messageId:match(":(%d+)$"))
        if timestamp and currentTime - timestamp > 300 then -- 5 minutes
            table.insert(toRemove, messageId)
        end
    end
    
    -- Remove old message IDs
    for _, messageId in ipairs(toRemove) do
        self.RespondedMessages[messageId] = nil
    end
    
    if #toRemove > 0 then
        Logger:info("Cleaned up " .. #toRemove .. " old responded messages")
    end
end

return ChatManager

-- Chat Manager Module
-- /LxckStxp/Censura-Applications/LocalPlayer/AI/Modules/ChatManager.lua

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local localPlayer = Players.LocalPlayer

local ChatManager = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

function ChatManager:Initialize(controller)
    self.Controller = controller
    
    -- Set up chat event handlers
    self:SetupChatHandler()
    
    return self
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
                        self:ReceiveMessage(playerObj.Name, textChatMessage.Text)
                        
                        if System.State.IsActive and self:ShouldRespondToChat(textChatMessage.Text, playerObj.Name) then
                            self.Controller:QueryGrokWithChat(textChatMessage.Text, playerObj.Name)
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
            self:ReceiveMessage(player.Name, message)
            
            if System.State.IsActive and self:ShouldRespondToChat(message, player.Name) then
                self.Controller:QueryGrokWithChat(message, player.Name)
            end
        else
            Logger:warn("Ignored spam message from " .. player.Name)
        end
    end)
end

-- Determine if AI should respond to a chat message
function ChatManager:ShouldRespondToChat(message, sender)
    -- Always respond if our name is mentioned
    if message:lower():find(localPlayer.Name:lower()) then
        return true
    end
    
    -- Check if player is nearby
    local senderPlayer = Players:FindFirstChild(sender)
    if senderPlayer and senderPlayer.Character and senderPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local distance = (senderPlayer.Character.HumanoidRootPart.Position - self.Controller.RootPart.Position).Magnitude
        if distance <= Config.DETECTION_RADIUS * 0.7 then -- Respond to closer players more often
            return true
        end
    end
    
    -- Respond randomly to other messages
    return math.random() < 0.3 -- 30% chance to respond to random messages
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

return ChatManager

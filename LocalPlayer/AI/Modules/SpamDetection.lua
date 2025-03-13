-- Spam Detection Module
-- /LxckStxp/Censura-Applications/LocalPlayer/AI/Modules/SpamDetection.lua

local SpamDetection = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

function SpamDetection:Initialize()
    return self
end

-- Spam detection function
function SpamDetection:IsSpam(playerName, message)
    -- If spam detection is disabled, nothing is spam
    if not Config.SPAM_DETECTION.enabled then
        return false
    end
    
    -- Check if player is in cooldown period
    if System.State.IgnoredPlayers[playerName] and System.State.IgnoredPlayers[playerName] > os.time() then
        return true
    end
    
    -- Count recent messages from this player
    local recentMessages = {}
    local currentTime = os.time()
    
    for _, entry in ipairs(System.State.MessageLog) do
        if entry.sender == playerName and (currentTime - entry.timestamp) <= Config.SPAM_DETECTION.timeWindow then
            table.insert(recentMessages, entry.message)
        end
    end
    
    -- Check message count threshold
    if #recentMessages >= Config.SPAM_DETECTION.messageThreshold - 1 then
        -- Check for message similarity
        local similarCount = 0
        for _, oldMessage in ipairs(recentMessages) do
            if self:GetMessageSimilarity(message, oldMessage) >= Config.SPAM_DETECTION.similarityThreshold then
                similarCount = similarCount + 1
            end
        end
        
        -- If enough similar messages found, mark as spam and add player to cooldown
        if similarCount >= Config.SPAM_DETECTION.messageThreshold - 1 then
            self:IgnorePlayer(playerName, Config.SPAM_DETECTION.cooldownTime)
            return true
        end
    end
    
    return false
end

-- Calculate similarity between two messages (0-1 scale)
function SpamDetection:GetMessageSimilarity(message1, message2)
    -- Convert to lowercase for case-insensitive comparison
    message1 = string.lower(message1)
    message2 = string.lower(message2)
    
    -- If messages are identical, return 1
    if message1 == message2 then
        return 1
    end
    
    -- If either message is very short, use a simple contains check
    if #message1 < 5 or #message2 < 5 then
        if string.find(message1, message2, 1, true) or string.find(message2, message1, 1, true) then
            return 0.9
        end
        return 0
    end
    
    -- Simple algorithm to measure similarity based on common characters
    local longerMsg, shorterMsg
    if #message1 > #message2 then
        longerMsg, shorterMsg = message1, message2
    else
        longerMsg, shorterMsg = message2, message1
    end
    
    local matchCount = 0
    for i = 1, #shorterMsg do
        local char = shorterMsg:sub(i, i)
        if longerMsg:find(char, 1, true) then
            matchCount = matchCount + 1
        end
    end
    
    return matchCount / #shorterMsg
end

-- Add player to ignored list
function SpamDetection:IgnorePlayer(playerName, duration)
    System.State.IgnoredPlayers[playerName] = os.time() + duration
    Logger:warn("Detected spam from " .. playerName .. ", ignoring for " .. duration .. " seconds")
end

-- Check if player is currently ignored
function SpamDetection:IsPlayerIgnored(playerName)
    return System.State.IgnoredPlayers[playerName] and System.State.IgnoredPlayers[playerName] > os.time()
end

-- Clear all ignored players
function SpamDetection:ClearIgnoredPlayers()
    System.State.IgnoredPlayers = {}
    Logger:info("Cleared all ignored players")
end

return SpamDetection

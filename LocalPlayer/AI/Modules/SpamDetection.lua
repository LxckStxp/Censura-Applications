-- Spam Detection Module
-- /LxckStxp/Censura-Applications/LocalPlayer/AI/Modules/SpamDetection.lua

local SpamDetection = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

-- Advanced spam detection configuration
SpamDetection.Settings = {
    -- Message pattern analysis
    PatternThreshold = 0.75,        -- Similarity threshold for pattern detection
    MinMessageLength = 3,           -- Minimum characters to qualify for pattern analysis
    
    -- Rate limiting
    GlobalRateLimit = {
        Count = 8,                  -- Maximum messages
        Window = 5                  -- Time window in seconds
    },
    BurstRateLimit = {
        Count = 4,                  -- Maximum burst messages
        Window = 2                  -- Burst window in seconds
    },
    
    -- Content analysis
    RepetitionThreshold = 0.8,      -- Threshold for repetitive content
    ContentSimilarityWindow = 5,    -- Number of previous messages to check for similarity
    
    -- Context awareness
    ConversationAllowance = 1.5,    -- Multiplier for rate limits in active conversations
    QuestionAllowance = 1.2,        -- Multiplier for questions (they may be sent quickly)
    
    -- Player reputation system
    PlayerReputation = {},          -- Store player reputation scores
    ReputationThreshold = -5,       -- Threshold for considering a player a spammer
    ReputationDecay = 0.1,          -- How quickly reputation recovers per minute
    ReputationPenalty = {
        PatternDetected = -2,       -- Penalty for detected patterns
        RateLimitExceeded = -1,     -- Penalty for exceeding rate limits
        RepetitiveContent = -2      -- Penalty for repetitive content
    },
    
    -- Dynamic adaptation
    AdaptiveThresholds = true,      -- Adjust thresholds based on server activity
    ServerActivityMultiplier = 1.0, -- Current server activity multiplier
    
    -- Spam types classification
    SpamTypes = {
        REPETITIVE = "repetitive",  -- Same message multiple times
        BURST = "burst",            -- Too many messages too quickly
        PATTERN = "pattern",        -- Following a spam pattern
        NONSENSE = "nonsense"       -- Random or gibberish text
    },
    
    -- Cooldown and tracking
    CooldownTime = 10,              -- Default cooldown time in seconds
    MaxCooldownTime = 60,           -- Maximum cooldown time for repeated offenders
    MessageHistory = {},            -- Track message history per player
    WarningIssued = {},             -- Track if warning was issued to a player
}

-- Initialize module
function SpamDetection:Initialize()
    -- Start the reputation decay process
    spawn(function()
        while wait(60) do -- Check every minute
            self:DecayReputationScores()
        end
    end)
    
    -- Start message history cleanup
    spawn(function()
        while wait(300) do -- Clean up every 5 minutes
            self:CleanupMessageHistory()
        end
    end)
    
    return self
end

-- Main spam detection function with enhanced logic
function SpamDetection:IsSpam(playerName, message)
    -- If spam detection is disabled, nothing is spam
    if not Config.SPAM_DETECTION.enabled then
        return false
    end
    
    -- Check if player is in cooldown period
    if System.State.IgnoredPlayers[playerName] and System.State.IgnoredPlayers[playerName] > os.time() then
        return true
    end
    
    -- Initialize message history for this player if it doesn't exist
    if not self.Settings.MessageHistory[playerName] then
        self.Settings.MessageHistory[playerName] = {}
    end
    
    -- Initialize reputation score if it doesn't exist
    if not self.Settings.PlayerReputation[playerName] then
        self.Settings.PlayerReputation[playerName] = 0
    end
    
    -- Record the message
    table.insert(self.Settings.MessageHistory[playerName], {
        message = message,
        timestamp = os.time()
    })
    
    -- Context-aware adjustments
    local contextMultiplier = 1.0
    
    -- Allow more messages in active conversations
    if System.Modules.ChatManager:IsInConversationWith(playerName) then
        contextMultiplier = self.Settings.ConversationAllowance
    end
    
    -- Allow more leniency for questions and responses
    if self:IsQuestionOrResponse(message) then
        contextMultiplier = contextMultiplier * self.Settings.QuestionAllowance
    end
    
    -- Step 1: Check for rate limiting violations
    local isRateLimited = self:CheckRateLimit(playerName, contextMultiplier)
    if isRateLimited then
        local spamType = self.Settings.SpamTypes.BURST
        self:HandleSpamDetection(playerName, message, spamType)
        return true
    end
    
    -- Step 2: Check for repetitive content
    local isRepetitive, repetitionScore = self:CheckRepetitiveContent(playerName, message)
    if isRepetitive then
        local spamType = self.Settings.SpamTypes.REPETITIVE
        self:HandleSpamDetection(playerName, message, spamType)
        return true
    end
    
    -- Step 3: Check for message patterns (more sophisticated than just similarity)
    local isPattern = self:CheckMessagePatterns(playerName, message)
    if isPattern then
        local spamType = self.Settings.SpamTypes.PATTERN
        self:HandleSpamDetection(playerName, message, spamType)
        return true
    end
    
    -- Step 4: Check for nonsense or gibberish (very short, random characters, etc.)
    local isNonsense = self:CheckNonsenseContent(message)
    if isNonsense then
        local spamType = self.Settings.SpamTypes.NONSENSE
        self:HandleSpamDetection(playerName, message, spamType)
        return true
    }
    
    -- Step 5: Check reputation score
    if self.Settings.PlayerReputation[playerName] <= self.Settings.ReputationThreshold then
        Logger:warn("Player " .. playerName .. " has a low reputation score (" .. 
                   self.Settings.PlayerReputation[playerName] .. "), treating as spam")
        self:HandleSpamDetection(playerName, message, "reputation")
        return true
    end
    
    -- If we got here, the message is not spam
    -- Slightly improve reputation for clean messages
    self.Settings.PlayerReputation[playerName] = 
        math.min(10, self.Settings.PlayerReputation[playerName] + 0.1)
    
    return false
end

-- Handle a spam detection event
function SpamDetection:HandleSpamDetection(playerName, message, spamType)
    -- Apply appropriate reputation penalty
    if spamType == self.Settings.SpamTypes.PATTERN then
        self.Settings.PlayerReputation[playerName] = 
            self.Settings.PlayerReputation[playerName] + self.Settings.ReputationPenalty.PatternDetected
    elseif spamType == self.Settings.SpamTypes.BURST then
        self.Settings.PlayerReputation[playerName] = 
            self.Settings.PlayerReputation[playerName] + self.Settings.ReputationPenalty.RateLimitExceeded
    elseif spamType == self.Settings.SpamTypes.REPETITIVE then
        self.Settings.PlayerReputation[playerName] = 
            self.Settings.PlayerReputation[playerName] + self.Settings.ReputationPenalty.RepetitiveContent
    end
    
    -- Clamp reputation to prevent extreme values
    self.Settings.PlayerReputation[playerName] = 
        math.max(-10, math.min(10, self.Settings.PlayerReputation[playerName]))
    
    -- Calculate cooldown time based on reputation (worse reputation = longer cooldown)
    local reputationFactor = math.abs(math.min(0, self.Settings.PlayerReputation[playerName])) / 10
    local cooldownTime = self.Settings.CooldownTime + 
                        (self.Settings.MaxCooldownTime - self.Settings.CooldownTime) * reputationFactor
    
    -- Apply cooldown
    self:IgnorePlayer(playerName, cooldownTime)
    
    -- Log the detection
    Logger:warn("Detected " .. spamType .. " spam from " .. playerName .. 
               ", ignoring for " .. cooldownTime .. " seconds (reputation: " .. 
               self.Settings.PlayerReputation[playerName] .. ")")
end

-- Check if message exceeds rate limits
function SpamDetection:CheckRateLimit(playerName, contextMultiplier)
    local messages = self.Settings.MessageHistory[playerName]
    local currentTime = os.time()
    local globalCount = 0
    local burstCount = 0
    
    -- Apply context multiplier to rate limits
    local adjustedGlobalCount = math.floor(self.Settings.GlobalRateLimit.Count * contextMultiplier)
    local adjustedBurstCount = math.floor(self.Settings.BurstRateLimit.Count * contextMultiplier)
    
    -- Count messages in the global and burst windows
    for i = #messages, 1, -1 do
        local timeDiff = currentTime - messages[i].timestamp
        
        if timeDiff <= self.Settings.GlobalRateLimit.Window then
            globalCount = globalCount + 1
        end
        
        if timeDiff <= self.Settings.BurstRateLimit.Window then
            burstCount = burstCount + 1
        end
    end
    
    -- Check if either limit is exceeded
    if globalCount > adjustedGlobalCount then
        Logger:info("Player " .. playerName .. " exceeded global rate limit: " .. 
                   globalCount .. "/" .. adjustedGlobalCount .. " messages in " .. 
                   self.Settings.GlobalRateLimit.Window .. " seconds")
        return true
    end
    
    if burstCount > adjustedBurstCount then
        Logger:info("Player " .. playerName .. " exceeded burst rate limit: " .. 
                   burstCount .. "/" .. adjustedBurstCount .. " messages in " .. 
                   self.Settings.BurstRateLimit.Window .. " seconds")
        return true
    end
    
    return false
end

-- Check for repetitive content
function SpamDetection:CheckRepetitiveContent(playerName, message)
    local messages = self.Settings.MessageHistory[playerName]
    local currentTime = os.time()
    local similarCount = 0
    local highestSimilarity = 0
    
    -- Check only a limited window of recent messages
    local startIdx = math.max(1, #messages - self.Settings.ContentSimilarityWindow)
    
    for i = startIdx, #messages - 1 do
        -- Skip messages that are too old (over 2 minutes)
        if currentTime - messages[i].timestamp > 120 then
            continue
        end
        
        local similarity = self:GetMessageSimilarity(message, messages[i].message)
        highestSimilarity = math.max(highestSimilarity, similarity)
        
        if similarity >= self.Settings.RepetitionThreshold then
            similarCount = similarCount + 1
            
            -- If we find multiple similar messages, it's repetitive
            if similarCount >= 2 then
                Logger:info("Repetitive content detected from " .. playerName .. 
                           " (similarity: " .. string.format("%.2f", similarity) .. ")")
                return true, similarity
            end
        end
    end
    
    return false, highestSimilarity
end

-- Check message patterns that indicate spam
function SpamDetection:CheckMessagePatterns(playerName, message)
    local messages = self.Settings.MessageHistory[playerName]
    
    -- Need at least 3 messages to detect patterns
    if #messages < 3 then
        return false
    end
    
    -- Skip if message is too short for pattern analysis
    if #message < self.Settings.MinMessageLength then
        return false
    end
    
    -- Check for character spam patterns (e.g., "aaaaaaa", "!!!!!!!")
    if self:HasCharacterSpamPattern(message) then
        Logger:info("Character spam pattern detected in message from " .. playerName)
        return true
    end
    
    -- Check for keyboard patterns (e.g., "asdfghjkl", "qwertyuiop")
    if self:HasKeyboardPattern(message) then
        Logger:info("Keyboard pattern detected in message from " .. playerName)
        return true
    end
    
    -- Check for alternating patterns in recent messages
    if self:HasAlternatingPattern(messages) then
        Logger:info("Alternating message pattern detected from " .. playerName)
        return true
    }
    
    -- Check for incremental spam (e.g., "a", "aa", "aaa")
    if self:HasIncrementalPattern(messages) then
        Logger:info("Incremental spam pattern detected from " .. playerName)
        return true
    end
    
    return false
end

-- Check if message contains character spam patterns
function SpamDetection:HasCharacterSpamPattern(message)
    -- Strip spaces for pattern detection
    local noSpaces = message:gsub("%s+", "")
    
    -- Check for repeated characters (e.g., "aaaaa", "!!!!!")
    for i = 1, #noSpaces - 3 do
        local char = noSpaces:sub(i, i)
        local repeatedCount = 1
        
        for j = i + 1, math.min(i + 5, #noSpaces) do
            if noSpaces:sub(j, j) == char then
                repeatedCount = repeatedCount + 1
            else
                break
            end
        end
        
        -- If we find 4 or more repeated characters, it's likely spam
        if repeatedCount >= 4 then
            return true
        end
    end
    
    return false
end

-- Check if message contains keyboard patterns
function SpamDetection:HasKeyboardPattern(message)
    -- Common keyboard patterns
    local keyboardPatterns = {
        "qwerty", "asdfgh", "zxcvbn", "123456", "qazwsx"
    }
    
    local lowerMessage = message:lower()
    
    for _, pattern in ipairs(keyboardPatterns) do
        if lowerMessage:find(pattern) then
            return true
        end
    end
    
    return false
end

-- Check for alternating patterns in recent messages
function SpamDetection:HasAlternatingPattern(messages)
    -- Need at least 4 messages to detect alternating patterns
    if #messages < 4 then
        return false
    end
    
    -- Get the most recent messages
    local recentMessages = {}
    for i = #messages - 3, #messages do
        table.insert(recentMessages, messages[i].message)
    end
    
    -- Check if messages alternate between 2 or 3 distinct values
    local uniqueMessages = {}
    for _, msg in ipairs(recentMessages) do
        if not table.find(uniqueMessages, msg) then
            table.insert(uniqueMessages, msg)
        end
        
        -- If we have more than 3 unique messages, it's not a simple alternating pattern
        if #uniqueMessages > 3 then
            return false
        end
    end
    
    -- If we have exactly 2 or 3 unique messages and they follow a pattern
    if #uniqueMessages >= 2 and #uniqueMessages <= 3 then
        -- Check for repeating pattern
        for i = 1, #recentMessages - 2 do
            if recentMessages[i] == recentMessages[i + 2] then
                return true
            end
        end
    end
    
    return false
end

-- Check for incremental spam patterns
function SpamDetection:HasIncrementalPattern(messages)
    -- Need at least 3 messages to detect incremental patterns
    if #messages < 3 then
        return false
    end
    
    -- Get the most recent 3 messages
    local msg1 = messages[#messages - 2].message
    local msg2 = messages[#messages - 1].message
    local msg3 = messages[#messages].message
    
    -- Check for character increments (e.g., "a", "aa", "aaa")
    if #msg1 < #msg2 and #msg2 < #msg3 then
        -- If each message contains the previous one as a substring
        if msg2:find(msg1, 1, true) and msg3:find(msg2, 1, true) then
            return true
        end
    end
    
    -- Check for number increments (e.g., "1", "2", "3")
    local num1 = tonumber(msg1)
    local num2 = tonumber(msg2)
    local num3 = tonumber(msg3)
    
    if num1 and num2 and num3 then
        local diff1 = num2 - num1
        local diff2 = num3 - num2
        
        -- If there's a consistent increment pattern
        if diff1 > 0 and diff2 > 0 and math.abs(diff1 - diff2) <= 1 then
            return true
        end
    end
    
    return false
end

-- Check for nonsense or gibberish content
function SpamDetection:CheckNonsenseContent(message)
    -- Skip short messages
    if #message < 5 then
        return false
    end
    
    local lowerMessage = message:lower()
    
    -- Check for random character distribution (entropy)
    local entropy = self:CalculateEntropy(lowerMessage)
    
    -- Very high entropy can indicate random keyboard mashing
    if entropy > 4.5 and #message > 8 then
        Logger:info("High entropy message detected (entropy: " .. string.format("%.2f", entropy) .. ")")
        return true
    end
    
    -- Check consonant-to-vowel ratio (very high ratio can indicate gibberish)
    local consonants, vowels = self:CountConsonantsAndVowels(lowerMessage)
    
    -- Avoid division by zero
    if vowels == 0 then
        vowels = 0.5
    end
    
    local ratio = consonants / vowels
    
    -- Typical English text has a ratio around 1.5-2.0
    -- Much higher values often indicate gibberish
    if ratio > 5 and consonants > 5 then
        Logger:info("Unusual consonant-to-vowel ratio detected (" .. string.format("%.2f", ratio) .. ")")
        return true
    end
    
    return false
end

-- Calculate entropy of a string (measure of randomness)
function SpamDetection:CalculateEntropy(str)
    local charCount = {}
    local total = #str
    
    -- Count character occurrences
    for i = 1, total do
        local char = str:sub(i, i)
        charCount[char] = (charCount[char] or 0) + 1
    end
    
    -- Calculate entropy
    local entropy = 0
    for _, count in pairs(charCount) do
        local probability = count / total
        entropy = entropy - probability * math.log(probability, 2)
    end
    
    return entropy
end

-- Count consonants and vowels in a string
function SpamDetection:CountConsonantsAndVowels(str)
    local consonants = 0
    local vowels = 0
    local vowelSet = {a = true, e = true, i = true, o = true, u = true}
    
    for i = 1, #str do
        local char = str:sub(i, i)
        if char:match("[a-z]") then
            if vowelSet[char] then
                vowels = vowels + 1
            else
                consonants = consonants + 1
            end
        end
    end
    
    return consonants, vowels
end

-- Check if a message is a question or response
function SpamDetection:IsQuestionOrResponse(message)
    -- Check for question marks
    if message:find("?") then
        return true
    end
    
    -- Check for common response indicators
    local responsePatterns = {
        "^yes", "^no", "^ok", "^sure", "^thanks", "^thank you", 
        "^lol", "^haha", "^wow", "^cool", "^nice", "^great", "^awesome"
    }
    
    local lowerMessage = message:lower()
    
    for _, pattern in ipairs(responsePatterns) do
        if lowerMessage:match(pattern) then
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
    
    -- Implementation of Levenshtein distance for similarity
    local len1, len2 = #message1, #message2
    local matrix = {}
    
    -- Initialize matrix
    for i = 0, len1 do
        matrix[i] = {[0] = i}
    end
    
    for j = 0, len2 do
        matrix[0][j] = j
    end
    
    -- Fill matrix
    for i = 1, len1 do
        for j = 1, len2 do
            local cost = (message1:sub(i, i) == message2:sub(j, j)) and 0 or 1
            matrix[i][j] = math.min(
                matrix[i-1][j] + 1,
                matrix[i][j-1] + 1,
                matrix[i-1][j-1] + cost
            )
        end
    end
    
    -- Calculate similarity from Levenshtein distance
    local maxLen = math.max(len1, len2)
    if maxLen == 0 then return 1 end
    
    local similarity = 1 - (matrix[len1][len2] / maxLen)
    return similarity
end

-- Add player to ignored list
function SpamDetection:IgnorePlayer(playerName, duration)
    System.State.IgnoredPlayers[playerName] = os.time() + duration
    
    -- If this is the first warning, issue a direct message
    if not self.Settings.WarningIssued[playerName] then
        -- We could send a message here if desired
        self.Settings.WarningIssued[playerName] = true
    end
}

-- Check if player is currently ignored
function SpamDetection:IsPlayerIgnored(playerName)
    return System.State.IgnoredPlayers[playerName] and System.State.IgnoredPlayers[playerName] > os.time()
end

-- Clear all ignored players
function SpamDetection:ClearIgnoredPlayers()
    System.State.IgnoredPlayers = {}
    Logger:info("Cleared all ignored players")
end

-- Decay reputation scores over time
function SpamDetection:DecayReputationScores()
    for player, score in pairs(self.Settings.PlayerReputation) do
        if score < 0 then
            -- Slowly improve negative reputation
            self.Settings.PlayerReputation[player] = 
                math.min(0, score + self.Settings.ReputationDecay)
        elseif score > 0 then
            -- Slowly decrease positive reputation to neutral
            self.Settings.PlayerReputation[player] = 
                math.max(0, score - self.Settings.ReputationDecay / 2)
        end
    end
end

-- Clean up old message history entries
function SpamDetection:CleanupMessageHistory()
    local currentTime = os.time()
    
    for player, messages in pairs(self.Settings.MessageHistory) do
        local toRemove = {}
        
        -- Find messages older than 10 minutes
        for i, msg in ipairs(messages) do
            if currentTime - msg.timestamp > 600 then
                table.insert(toRemove, i)
            end
        end
        
        -- Remove old messages
        for i = #toRemove, 1, -1 do
            table.remove(messages, toRemove[i])
        end
    end
}

return SpamDetection

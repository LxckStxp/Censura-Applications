-- Spam Detection Module
local SpamDetection = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

SpamDetection.Settings = {
    ReputationDecay = 0.05,
    HistoryCleanupInterval = 600, -- 10 minutes
    WarningIssued = {},
    PlayerReputation = {},
    MessageHistory = {}
}

function SpamDetection:Initialize()
    task.spawn(function()
        while task.wait(60) do
            self:DecayReputationScores()
            self:CleanupMessageHistory()
        end
    end)
    return self
end

function SpamDetection:IsSpam(playerName, message)
    if not Config.SPAM_DETECTION.enabled then return false end
    
    local currentTime = os.time()
    local messages = self.Settings.MessageHistory[playerName] or {}
    table.insert(messages, {message = message, timestamp = currentTime})
    self.Settings.MessageHistory[playerName] = messages
    
    local recentCount = 0
    for _, msg in ipairs(messages) do
        if currentTime - msg.timestamp <= Config.SPAM_DETECTION.timeWindow then
            recentCount = recentCount + 1
        end
    end
    
    if recentCount > Config.SPAM_DETECTION.messageThreshold then
        self:UpdateReputation(playerName, -2)
        self:IgnorePlayer(playerName, Config.SPAM_DETECTION.cooldownTime)
        return true
    end
    
    if self:IsRepetitive(messages) or self:IsGibberish(message) or self:IsPatterned(message) then
        self:UpdateReputation(playerName, -1)
        self:IgnorePlayer(playerName, Config.SPAM_DETECTION.cooldownTime)
        return true
    end
    
    if self:IsQuestionOrResponse(message) then
        self:UpdateReputation(playerName, 0.5)
    end
    return false
end

function SpamDetection:IsRepetitive(messages)
    if #messages < 2 then return false end
    
    local recent = {}
    for i = math.max(1, #messages - 3), #messages do
        table.insert(recent, messages[i].message)
    end
    
    for i = 1, #recent - 1 do
        if self:GetMessageSimilarity(recent[i], recent[i + 1]) > Config.SPAM_DETECTION.similarityThreshold then
            return true
        end
    end
    return false
end

function SpamDetection:IsGibberish(message)
    if #message < 5 then return false end
    
    local entropy = self:CalculateEntropy(message:lower())
    if entropy > 4.5 then return true end
    
    local consonants, vowels = self:CountConsonantsAndVowels(message:lower())
    return vowels > 0 and consonants / vowels > 5 and consonants > 5
end

function SpamDetection:IsPatterned(message)
    local noSpaces = message:gsub("%s", "")
    for i = 1, #noSpaces - 3 do
        if noSpaces:sub(i, i) == noSpaces:sub(i + 1, i + 1) and
           noSpaces:sub(i, i) == noSpaces:sub(i + 2, i + 2) and
           noSpaces:sub(i, i) == noSpaces:sub(i + 3, i + 3) then
            return true
        end
    end
    
    local patterns = {"qwerty", "asdf", "12345"}
    for _, pattern in ipairs(patterns) do
        if message:lower():find(pattern) then return true end
    end
    return false
end

function SpamDetection:CalculateEntropy(str)
    local charCount = {}
    for i = 1, #str do
        local char = str:sub(i, i)
        charCount[char] = (charCount[char] or 0) + 1
    end
    
    local entropy = 0
    for _, count in pairs(charCount) do
        local p = count / #str
        entropy = entropy - p * math.log(p, 2)
    end
    return entropy
end

function SpamDetection:CountConsonantsAndVowels(str)
    local consonants, vowels = 0, 0
    local vowelsSet = {["a"] = true, ["e"] = true, ["i"] = true, ["o"] = true, ["u"] = true}
    
    for char in str:gmatch("[a-z]") do
        if vowelsSet[char] then vowels = vowels + 1 else consonants = consonants + 1 end
    end
    return consonants, vowels
end

function SpamDetection:IsQuestionOrResponse(message)
    if message:find("?") then return true end
    
    local responses = {"yes", "no", "ok", "sure", "thanks", "lol", "haha"}
    for _, resp in ipairs(responses) do
        if message:lower():match("^" .. resp) then return true end
    end
    return false
end

function SpamDetection:GetMessageSimilarity(msg1, msg2)
    if msg1 == msg2 then return 1 end
    if #msg1 < 5 or #msg2 < 5 then return msg1:find(msg2, 1, true) and 0.9 or 0 end
    
    local len1, len2 = #msg1, #msg2
    local matrix = {{}}
    for i = 0, len1 do matrix[i] = {[0] = i} end
    for j = 0, len2 do matrix[0][j] = j end
    
    for i = 1, len1 do
        for j = 1, len2 do
            local cost = msg1:sub(i, i) == msg2:sub(j, j) and 0 or 1
            matrix[i][j] = math.min(
                matrix[i-1][j] + 1,
                matrix[i][j-1] + 1,
                matrix[i-1][j-1] + cost
            )
        end
    end
    return 1 - (matrix[len1][len2] / math.max(len1, len2))
end

function SpamDetection:UpdateReputation(playerName, change)
    local current = self.Settings.PlayerReputation[playerName] or 0
    self.Settings.PlayerReputation[playerName] = math.clamp(current + change, -10, 10)
end

function SpamDetection:IgnorePlayer(playerName, duration)
    System.State.IgnoredPlayers[playerName] = os.time() + duration
    if not self.Settings.WarningIssued[playerName] then
        self.Settings.WarningIssued[playerName] = true
        Logger:info("Player " .. playerName .. " ignored for " .. duration .. " seconds")
    end
end

function SpamDetection:IsPlayerIgnored(playerName)
    return System.State.IgnoredPlayers[playerName] and System.State.IgnoredPlayers[playerName] > os.time()
end

function SpamDetection:DecayReputationScores()
    for player, score in pairs(self.Settings.PlayerReputation) do
        if score > 0 then
            self.Settings.PlayerReputation[player] = math.max(0, score - self.Settings.ReputationDecay)
        elseif score < 0 then
            self.Settings.PlayerReputation[player] = math.min(0, score + self.Settings.ReputationDecay)
        end
    end
end

function SpamDetection:CleanupMessageHistory()
    local currentTime = os.time()
    for player, messages in pairs(self.Settings.MessageHistory) do
        local i = 1
        while i <= #messages do
            if currentTime - messages[i].timestamp > self.Settings.HistoryCleanupInterval then
                table.remove(messages, i)
            else
                i = i + 1
            end
        end
        if #messages == 0 then self.Settings.MessageHistory[player] = nil end
    end
end

return SpamDetection

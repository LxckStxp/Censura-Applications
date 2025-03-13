-- Webhook Service Module
-- /LxckStxp/Censura-Applications/LocalPlayer/AI/Modules/WebhookService.lua

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

local WebhookService = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

-- Advanced webhook configuration
WebhookService.Settings = {
    -- Request settings
    Timeout = 10,                  -- Timeout in seconds
    RetryCount = 2,                -- Number of retry attempts
    RetryDelay = 1,                -- Delay between retries in seconds
    
    -- Rate limiting
    RequestCooldown = 1.5,         -- Minimum time between requests
    LastRequestTime = 0,           -- Track last request time
    
    -- Response caching
    ResponseCache = {},            -- Cache recent responses
    CacheTimeout = 30,             -- How long to cache similar requests
    MaxCacheEntries = 10,          -- Maximum number of cached entries
    
    -- Error handling
    ErrorCount = 0,                -- Track consecutive errors
    MaxConsecutiveErrors = 3,      -- Max errors before fallback mode
    FallbackMode = false,          -- Whether we're in fallback mode
    FallbackDuration = 60,         -- How long to stay in fallback mode
    FallbackModeStartTime = 0,     -- When fallback mode started
    
    -- Request enhancement
    EnhanceContext = true,         -- Whether to enhance context before sending
    MaxContextLength = 4000,       -- Maximum context length to send
    ContextCompressionEnabled = true, -- Whether to compress long contexts
    
    -- Performance tracking
    RequestStats = {
        TotalRequests = 0,
        SuccessfulRequests = 0,
        FailedRequests = 0,
        AverageResponseTime = 0,
        TotalResponseTime = 0
    }
}

-- Fallback responses when API is unavailable
WebhookService.FallbackResponses = {
    -- Generic fallbacks
    generic = {
        {
            action = "say",
            message = "I'm just exploring around. This place is pretty interesting!",
            priority = 2,
            duration = 5
        },
        {
            action = "wander",
            message = nil,
            priority = 1,
            duration = 10
        },
        {
            action = "emote",
            message = "wave",
            priority = 1,
            duration = 3
        }
    },
    
    -- Responses to specific message types
    greeting = {
        {
            action = "say",
            message = "Hey there! How's it going?",
            priority = 3,
            duration = 3
        },
        {
            action = "emote",
            message = "wave",
            priority = 2,
            duration = 2
        }
    },
    
    question = {
        {
            action = "say",
            message = "That's an interesting question! I'm not entirely sure, but we could try to figure it out.",
            priority = 3,
            duration = 5
        }
    },
    
    conversation = {
        {
            action = "say",
            message = "Yeah, I was thinking the same thing. What else have you been up to?",
            priority = 3,
            duration = 5
        }
    }
}

function WebhookService:Initialize()
    -- Start cache cleanup timer
    spawn(function()
        while wait(60) do -- Clean up cache every minute
            self:CleanupCache()
            self:CheckFallbackMode()
        end
    end)
    
    Logger:info("WebhookService initialized with endpoint: " .. Config.WEBHOOK_URL)
    return self
}

-- Clean up expired cache entries
function WebhookService:CleanupCache()
    local currentTime = os.time()
    local keysToRemove = {}
    
    for key, entry in pairs(self.Settings.ResponseCache) do
        if currentTime - entry.timestamp > self.Settings.CacheTimeout then
            table.insert(keysToRemove, key)
        end
    end
    
    for _, key in ipairs(keysToRemove) do
        self.Settings.ResponseCache[key] = nil
    end
    
    -- If we still have too many entries, remove oldest ones
    if #self.Settings.ResponseCache > self.Settings.MaxCacheEntries then
        local entries = {}
        for key, entry in pairs(self.Settings.ResponseCache) do
            table.insert(entries, {key = key, timestamp = entry.timestamp})
        end
        
        -- Sort by timestamp (oldest first)
        table.sort(entries, function(a, b) 
            return a.timestamp < b.timestamp 
        end)
        
        -- Remove oldest entries
        for i = 1, #entries - self.Settings.MaxCacheEntries do
            self.Settings.ResponseCache[entries[i].key] = nil
        end
    end
    
    Logger:debug("Cleaned up " .. #keysToRemove .. " expired cache entries")
end

-- Check and update fallback mode status
function WebhookService:CheckFallbackMode()
    if self.Settings.FallbackMode then
        local currentTime = os.time()
        if currentTime - self.Settings.FallbackModeStartTime > self.Settings.FallbackDuration then
            self.Settings.FallbackMode = false
            self.Settings.ErrorCount = 0
            Logger:info("Exiting fallback mode after " .. self.Settings.FallbackDuration .. " seconds")
        end
    end
}

-- Generate a cache key for a request
function WebhookService:GenerateCacheKey(message)
    -- Extract key elements from the message
    local stateMatch = message:match("Current state: ([^\n]+)")
    local playerMatch = message:match("Nearby players: ([^\n]+)")
    
    -- Create a simplified representation for the cache key
    local keyParts = {
        state = stateMatch or "unknown",
        players = playerMatch or "none",
        -- Add a time component to ensure some variation
        timeframe = math.floor(os.time() / 30) -- Changes every 30 seconds
    }
    
    -- Create a string representation
    local keyString = HttpService:JSONEncode(keyParts)
    
    -- Return a hash of the string for shorter keys
    return HttpService:GenerateGUID(false)
end

-- Main function to call Grok API
function WebhookService:CallGrok(message)
    -- Check if we're in fallback mode
    if self.Settings.FallbackMode then
        Logger:info("In fallback mode, using local decision")
        return self:GenerateFallbackDecision(message)
    end
    
    -- Rate limiting check
    local currentTime = tick()
    if currentTime - self.Settings.LastRequestTime < self.Settings.RequestCooldown then
        Logger:info("Rate limiting webhook request, using cache or fallback")
        -- Try to use cached response
        local cacheKey = self:GenerateCacheKey(message)
        local cachedResponse = self.Settings.ResponseCache[cacheKey]
        
        if cachedResponse then
            Logger:info("Using cached response for similar context")
            return cachedResponse.response
        end
        
        -- If no cache, use fallback
        return self:GenerateFallbackDecision(message)
    end
    
    -- Update last request time
    self.Settings.LastRequestTime = currentTime
    
    -- Check cache first
    local cacheKey = self:GenerateCacheKey(message)
    local cachedResponse = self.Settings.ResponseCache[cacheKey]
    
    if cachedResponse then
        Logger:info("Using cached response for similar context")
        return cachedResponse.response
    end
    
    -- Prepare the message
    local processedMessage = message
    if self.Settings.EnhanceContext then
        processedMessage = self:EnhanceContext(message)
    end
    
    -- Check if message is too long
    if #processedMessage > self.Settings.MaxContextLength then
        if self.Settings.ContextCompressionEnabled then
            processedMessage = self:CompressContext(processedMessage)
        else
            -- Truncate to max length
            processedMessage = processedMessage:sub(1, self.Settings.MaxContextLength) .. 
                               "\n\n[Context truncated due to length]"
        end
    end
    
    -- Prepare request body
    local requestBody = { 
        message = processedMessage,
        player_name = localPlayer.Name,
        game_id = game.PlaceId,
        timestamp = os.time()
    }
    
    local body = HttpService:JSONEncode(requestBody)
    
    -- Track request stats
    local startTime = tick()
    self.Settings.RequestStats.TotalRequests = self.Settings.RequestStats.TotalRequests + 1
    
    -- Make the request with retry logic
    local response, success = self:MakeRequestWithRetry(Config.WEBHOOK_URL, body)
    
    -- Update response time stats
    local endTime = tick()
    local responseTime = endTime - startTime
    self.Settings.RequestStats.TotalResponseTime = self.Settings.RequestStats.TotalResponseTime + responseTime
    self.Settings.RequestStats.AverageResponseTime = 
        self.Settings.RequestStats.TotalResponseTime / self.Settings.RequestStats.TotalRequests
    
    if success and response and response.action then
        -- Reset error count on success
        self.Settings.ErrorCount = 0
        
        -- Update success stats
        self.Settings.RequestStats.SuccessfulRequests = self.Settings.RequestStats.SuccessfulRequests + 1
        
        -- Cache the response
        self.Settings.ResponseCache[cacheKey] = {
            response = response,
            timestamp = os.time()
        }
        
        Logger:info("Successful Grok decision: action=" .. tostring(response.action) .. 
                   ", target=" .. tostring(response.target) .. 
                   ", message=" .. tostring(response.message) ..
                   ", priority=" .. tostring(response.priority or "N/A") ..
                   ", duration=" .. tostring(response.duration or "N/A") ..
                   " (response time: " .. string.format("%.2f", responseTime) .. "s)")
        
        return response
    else
        -- Update failure stats
        self.Settings.RequestStats.FailedRequests = self.Settings.RequestStats.FailedRequests + 1
        
        -- Increment error count
        self.Settings.ErrorCount = self.Settings.ErrorCount + 1
        
        -- Check if we should enter fallback mode
        if self.Settings.ErrorCount >= self.Settings.MaxConsecutiveErrors and not self.Settings.FallbackMode then
            self.Settings.FallbackMode = true
            self.Settings.FallbackModeStartTime = os.time()
            Logger:warn("Entering fallback mode after " .. self.Settings.ErrorCount .. " consecutive errors")
        end
        
        Logger:error("Failed to call webhook: " .. tostring(response))
        
        -- Return a fallback decision
        return self:GenerateFallbackDecision(message)
    end
end

-- Make HTTP request with retry logic
function WebhookService:MakeRequestWithRetry(url, body)
    local attempts = 0
    local maxAttempts = self.Settings.RetryCount + 1
    
    while attempts < maxAttempts do
        attempts = attempts + 1
        
        local response, success, err
        
        -- Try to use the appropriate HTTP request method
        if typeof(request) == "function" then
            -- Using executor's request function
            success, response = pcall(function()
                local res = request({
                    Url = url,
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json",
                        ["User-Agent"] = "Roblox/AiController"
                    },
                    Body = body,
                    Timeout = self.Settings.Timeout
                })
                
                if res.StatusCode >= 200 and res.StatusCode < 300 then
                    local decoded = HttpService:JSONDecode(res.Body)
                    Logger:debug("Raw response: " .. tostring(res.Body))
                    return {
                        success = true,
                        data = decoded
                    }
                else
                    return {
                        success = false,
                        status = res.StatusCode,
                        message = "Request returned status: " .. res.StatusCode
                    }
                end
            end)
        else
            -- Using Roblox's HttpService
            success, response = pcall(function()
                local res = HttpService:RequestAsync({
                    Url = url,
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json",
                        ["User-Agent"] = "Roblox/AiController"
                    },
                    Body = body
                })
                
                if res.Success then
                    local decoded = HttpService:JSONDecode(res.Body)
                    Logger:debug("Raw response: " .. tostring(res.Body))
                    return {
                        success = true,
                        data = decoded
                    }
                else
                    return {
                        success = false,
                        status = res.StatusCode,
                        message = "HttpService failed: " .. res.StatusCode .. " - " .. res.StatusMessage
                    }
                end
            end)
        end
        
        -- Check for success
        if success and response and response.success and response.data then
            return response.data, true
        end
        
        -- If this wasn't the last attempt, wait before retrying
        if attempts < maxAttempts then
            Logger:warn("Request attempt " .. attempts .. " failed, retrying in " .. 
                       self.Settings.RetryDelay .. " seconds...")
            wait(self.Settings.RetryDelay)
        else
            Logger:error("All " .. maxAttempts .. " request attempts failed")
            return response and response.message or "Unknown error", false
        end
    end
    
    return "Maximum retry attempts exceeded", false
end

-- Enhance context before sending to Grok
function WebhookService:EnhanceContext(context)
    -- Add metadata about the current game session
    local gameSessionInfo = "\nSession Info: Playing in " .. game.Name .. 
                           " (Place ID: " .. game.PlaceId .. ") for " .. 
                           math.floor(workspace.DistributedGameTime / 60) .. " minutes\n"
    
    -- Add performance stats
    local statsInfo = "\nAI Stats: " .. 
                     self.Settings.RequestStats.SuccessfulRequests .. " successful requests, " ..
                     self.Settings.RequestStats.FailedRequests .. " failed requests, " ..
                     string.format("%.2f", self.Settings.RequestStats.AverageResponseTime) .. "s avg response time\n"
    
    -- Add a reminder about being a human-like player
    local reminder = "\nRemember: You are a human player in Roblox named " .. localPlayer.Name .. 
                    ". Respond naturally and conversationally as a real player would.\n"
    
    -- Add the enhancements to the context
    return context .. gameSessionInfo .. statsInfo .. reminder
end

-- Compress long contexts to fit within limits
function WebhookService:CompressContext(context)
    -- First, try removing less important sections
    local compressedContext = context
    
    -- Remove detailed environmental descriptions if too long
    if #compressedContext > self.Settings.MaxContextLength then
        compressedContext = compressedContext:gsub("Environment: [^\n]+\n\n", "Environment: [Simplified]\n\n")
    end
    
    -- Reduce detailed player information if still too long
    if #compressedContext > self.Settings.MaxContextLength then
        local detailedInfoStart = compressedContext:find("Detailed player information:")
        local detailedInfoEnd = nil
        
        if detailedInfoStart then
            detailedInfoEnd = compressedContext:find("\n\n", detailedInfoStart)
            
            if detailedInfoEnd then
                local beforeSection = compressedContext:sub(1, detailedInfoStart - 1)
                local afterSection = compressedContext:sub(detailedInfoEnd)
                compressedContext = beforeSection .. "Detailed player information: [Summarized]\n" .. afterSection
            end
        end
    end
    
    -- If still too long, limit the number of chat messages
    if #compressedContext > self.Settings.MaxContextLength then
        local chatStart = compressedContext:find("Recent chat:")
        if chatStart then
            local beforeChat = compressedContext:sub(1, chatStart - 1)
            local chatSection = compressedContext:sub(chatStart)
            
            -- Extract just the most recent 3-4 messages
            local messages = {}
            for message in chatSection:gmatch("%[.-]:%s.-\n") do
                table.insert(messages, message)
            end
            
            -- Keep only the most recent messages
            local recentMessages = {}
            local messagesToKeep = math.min(4, #messages)
            for i = math.max(1, #messages - messagesToKeep + 1), #messages do
                table.insert(recentMessages, messages[i])
            end
            
            local compressedChat = "Recent chat: [Only showing most recent messages]\n" .. 
                                  table.concat(recentMessages)
            
            compressedContext = beforeChat .. compressedChat
        end
    end
    
    -- If still too long after all optimizations, truncate with a note
    if #compressedContext > self.Settings.MaxContextLength then
        compressedContext = compressedContext:sub(1, self.Settings.MaxContextLength) .. 
                           "\n\n[Context truncated due to length]"
    end
    
    Logger:info("Compressed context from " .. #context .. " to " .. #compressedContext .. " characters")
    return compressedContext
end

-- Generate fallback decisions when API is unavailable
function WebhookService:GenerateFallbackDecision(context)
    -- Determine what type of fallback to use based on context
    local decisionType = "generic"
    
    -- Check if this is a response to a chat message
    if context:find("New message from") then
        local message = context:match("New message from [^:]+: ([^\n]+)")
        
        if message then
            if message:find("?") then
                decisionType = "question"
            elseif self:IsGreeting(message) then
                decisionType = "greeting"
            else
                decisionType = "conversation"
            end
        end
    end
    
    -- Get the appropriate fallback responses
    local responses = self.FallbackResponses[decisionType] or self.FallbackResponses.generic
    
    -- Select a random response
    local response = responses[math.random(1, #responses)]
    
    -- If this is a conversation response, make it more contextual
    if decisionType == "conversation" and response.action == "say" then
        -- Extract the player name
        local playerName = context:match("New message from ([^:]+):")
        if playerName then
            -- Personalize the response
            response.message = response.message:gsub("Yeah", "Hey " .. playerName .. ", yeah")
        end
    end
    
    Logger:info("Generated fallback decision of type '" .. decisionType .. "': " .. response.action)
    return response
end

-- Check if a message is a greeting
function WebhookService:IsGreeting(message)
    local lowerMessage = message:lower()
    local greetings = {"hi", "hello", "hey", "sup", "yo", "wassup", "what's up", "greetings", "howdy"}
    
    for _, greeting in ipairs(greetings) do
        if lowerMessage:find(greeting) then
            return true
        end
    end
    
    return false
end

-- Get stats about the webhook service
function WebhookService:GetStats()
    local stats = {
        totalRequests = self.Settings.RequestStats.TotalRequests,
        successRate = self.Settings.RequestStats.TotalRequests > 0 and 
                      (self.Settings.RequestStats.SuccessfulRequests / self.Settings.RequestStats.TotalRequests) * 100 or 0,
        averageResponseTime = self.Settings.RequestStats.AverageResponseTime,
        cacheSize = 0,
        fallbackMode = self.Settings.FallbackMode
    }
    
    -- Count cache entries
    for _ in pairs(self.Settings.ResponseCache) do
        stats.cacheSize = stats.cacheSize + 1
    end
    
    return stats
end

return WebhookService

-- Webhook Service Module
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local WebhookService = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

-- Configuration
WebhookService.Settings = {
    Timeout = 10,               -- Request timeout in seconds
    RetryCount = 2,             -- Number of retries on failure
    RetryDelay = 1,             -- Seconds between retries
    RequestCooldown = 1.5,      -- Minimum time between requests
    CacheTimeout = 30,          -- Seconds to keep cached responses
    MaxCacheEntries = 10,       -- Max cached responses
    MaxContextLength = 4000,    -- Max characters in context
    FallbackDuration = 60       -- Seconds in fallback mode after errors
}

WebhookService.State = {
    LastRequestTime = 0,
    ErrorCount = 0,
    MaxConsecutiveErrors = 3,
    FallbackMode = false,
    FallbackStartTime = 0,
    ResponseCache = {},
    Stats = {
        TotalRequests = 0,
        SuccessfulRequests = 0,
        FailedRequests = 0,
        AverageResponseTime = 0
    }
}

WebhookService.FallbackResponses = {
    generic = {
        {action = "say", message = "Just hanging out here!", priority = 2, duration = 5},
        {action = "wander", priority = 1, duration = 10},
        {action = "emote", message = "wave", priority = 1, duration = 3}
    },
    greeting = {
        {action = "say", message = "Hey there!", priority = 3, duration = 3},
        {action = "emote", message = "wave", priority = 2, duration = 2}
    },
    question = {
        {action = "say", message = "Good question! Let me think...", priority = 3, duration = 5}
    }
}

function WebhookService:Initialize()
    task.spawn(function()
        while task.wait(60) do
            self:CleanupCache()
            self:UpdateFallbackMode()
        end
    end)
    Logger:info("WebhookService initialized")
    return self
end

function WebhookService:CleanupCache()
    local currentTime = os.time()
    for key, entry in pairs(self.State.ResponseCache) do
        if currentTime - entry.timestamp > self.Settings.CacheTimeout then
            self.State.ResponseCache[key] = nil
        end
    end
    
    while table.getn(self.State.ResponseCache) > self.Settings.MaxCacheEntries do
        local oldestKey = next(self.State.ResponseCache)
        for key, entry in pairs(self.State.ResponseCache) do
            if entry.timestamp < self.State.ResponseCache[oldestKey].timestamp then
                oldestKey = key
            end
        end
        self.State.ResponseCache[oldestKey] = nil
    end
end

function WebhookService:UpdateFallbackMode()
    if self.State.FallbackMode and os.time() - self.State.FallbackStartTime > self.Settings.FallbackDuration then
        self.State.FallbackMode = false
        self.State.ErrorCount = 0
        Logger:info("Exited fallback mode")
    end
end

function WebhookService:GenerateCacheKey(message)
    local key = HttpService:GenerateGUID(false)
    return key .. ":" .. math.floor(os.time() / 30)
end

function WebhookService:CallGrok(message)
    if self.State.FallbackMode then
        return self:GetFallbackDecision(message, "generic")
    end
    
    local currentTime = tick()
    if currentTime - self.State.LastRequestTime < self.Settings.RequestCooldown then
        local cached = self:GetCachedResponse(message)
        return cached or self:GetFallbackDecision(message, "generic")
    end
    
    self.State.LastRequestTime = currentTime
    local cacheKey = self:GenerateCacheKey(message)
    local cachedResponse = self.State.ResponseCache[cacheKey]
    if cachedResponse then
        Logger:info("Using cached response")
        return cachedResponse.response
    end
    
    local context = self:PrepareContext(message)
    local requestBody = HttpService:JSONEncode({
        message = context,
        player_name = localPlayer.Name,
        game_id = game.PlaceId,
        timestamp = os.time()
    })
    
    local startTime = tick()
    self.State.Stats.TotalRequests = self.State.Stats.TotalRequests + 1
    
    local response, success = self:MakeRequest(Config.WEBHOOK_URL, requestBody)
    local responseTime = tick() - startTime
    self:UpdateStats(responseTime, success)
    
    if success and response and response.action then
        self.State.ResponseCache[cacheKey] = {response = response, timestamp = os.time()}
        Logger:info(string.format("Grok decision: %s (%.2fs)", response.action, responseTime))
        return response
    else
        self:HandleRequestFailure()
        return self:GetFallbackDecision(message, "generic")
    end
end

function WebhookService:PrepareContext(message)
    local context = message .. "\nSession: " .. game.Name .. " (ID: " .. game.PlaceId .. ")"
    if #context > self.Settings.MaxContextLength then
        local chatStart = context:find("Recent chat:")
        if chatStart then
            local recent = context:sub(chatStart)
            local lines = {}
            for line in recent:gmatch("[^\n]+") do table.insert(lines, line) end
            context = context:sub(1, chatStart - 1) .. "\nRecent chat:\n" .. 
                      table.concat({unpack(lines, math.max(1, #lines - 3), #lines)}, "\n") .. 
                      (#lines > 4 and "\n[Truncated]" or "")
        end
        if #context > self.Settings.MaxContextLength then
            context = context:sub(1, self.Settings.MaxContextLength - 20) .. "\n[Truncated]"
        end
    end
    return context
end

function WebhookService:MakeRequest(url, body)
    for attempt = 1, self.Settings.RetryCount + 1 do
        local success, result = pcall(function()
            local response = game:HttpPost(url, body, "application/json")
            local decoded = HttpService:JSONDecode(response)
            return decoded.StatusCode and decoded or {action = decoded.action, target = decoded.target, message = decoded.message}
        end)
        
        if success and result and result.action then
            return result, true
        end
        
        Logger:warn("Webhook attempt " .. attempt .. " failed: " .. tostring(result))
        if attempt < self.Settings.RetryCount + 1 then
            task.wait(self.Settings.RetryDelay)
        end
    end
    return "Request failed after retries", false
end

function WebhookService:UpdateStats(responseTime, success)
    self.State.Stats.AverageResponseTime = 
        (self.State.Stats.AverageResponseTime * (self.State.Stats.TotalRequests - 1) + responseTime) / 
        self.State.Stats.TotalRequests
    if success then
        self.State.Stats.SuccessfulRequests = self.State.Stats.SuccessfulRequests + 1
        self.State.ErrorCount = 0
    else
        self.State.Stats.FailedRequests = self.State.Stats.FailedRequests + 1
    end
end

function WebhookService:HandleRequestFailure()
    self.State.ErrorCount = self.State.ErrorCount + 1
    if self.State.ErrorCount >= self.State.MaxConsecutiveErrors and not self.State.FallbackMode then
        self.State.FallbackMode = true
        self.State.FallbackStartTime = os.time()
        Logger:warn("Entered fallback mode due to " .. self.State.ErrorCount .. " consecutive errors")
    end
end

function WebhookService:GetCachedResponse(message)
    local cacheKey = self:GenerateCacheKey(message)
    local entry = self.State.ResponseCache[cacheKey]
    if entry then
        Logger:info("Retrieved cached response")
        return entry.response
    end
    return nil
end

function WebhookService:GetFallbackDecision(message, defaultType)
    local decisionType = defaultType or "generic"
    if message:find("New message from") then
        local msg = message:match("New message from [^:]+: ([^\n]+)") or ""
        decisionType = msg:find("?") and "question" or self:IsGreeting(msg) and "greeting" or "generic"
    end
    
    local responses = self.FallbackResponses[decisionType] or self.FallbackResponses.generic
    local response = responses[math.random(1, #responses)]
    Logger:info("Fallback decision: " .. response.action)
    return response
end

function WebhookService:IsGreeting(message)
    return message:lower():match("^(hi|hello|hey|sup|yo)")
end

function WebhookService:GetStats()
    return {
        totalRequests = self.State.Stats.TotalRequests,
        successRate = self.State.Stats.TotalRequests > 0 and 
                      (self.State.Stats.SuccessfulRequests / self.State.Stats.TotalRequests) * 100 or 0,
        averageResponseTime = self.State.Stats.AverageResponseTime,
        cacheSize = table.getn(self.State.ResponseCache),
        fallbackMode = self.State.FallbackMode
    }
end

return WebhookService

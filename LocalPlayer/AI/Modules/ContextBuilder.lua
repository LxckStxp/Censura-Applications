-- Context Builder Module
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local localPlayer = Players.LocalPlayer

local ContextBuilder = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

-- Configuration settings
ContextBuilder.Settings = {
    MaxRecentMessages = 8,
    MinMessageRelevance = 0.5,
    MaxSimilarMessages = 2,
    RelevanceDecayRate = 0.2,
    IncludePlayerDistance = true,
    IncludePlayerActivity = true,
    IncludeEnvironment = true,
    CacheDuration = 300, -- 5 minutes
    MaxContextLength = 4000
}

-- Cache for expensive calculations
ContextBuilder.Cache = {
    Environment = { value = nil, timestamp = 0 },
    ProcessedMessages = {}
}

function ContextBuilder:Initialize(controller)
    self.Controller = controller
    
    -- Periodic cleanup
    task.spawn(function()
        while task.wait(60) do
            self:CleanupCache()
        end
    end)
    
    return self
end

function ContextBuilder:CleanupCache()
    local currentTime = os.time()
    for msgId, timestamp in pairs(self.Cache.ProcessedMessages) do
        if currentTime - timestamp > self.Settings.CacheDuration then
            self.Cache.ProcessedMessages[msgId] = nil
        end
    end
    
    if currentTime - self.Cache.Environment.timestamp > 30 then
        self.Cache.Environment.value = nil -- Refresh environment every 30 seconds
    end
end

function ContextBuilder:GetContext()
    local context = {
        "You are a human-like player in Roblox named " .. localPlayer.Name .. 
        ". Respond naturally as if you were a real player.",
        self:GetGameInfo(),
        self:GetStateInfo(),
    }
    
    if self.Settings.IncludeEnvironment then
        table.insert(context, "Environment: " .. self:GetEnvironmentContext())
    end
    
    table.insert(context, self:GetNearbyPlayersInfo())
    local ignoredInfo = self:GetIgnoredPlayersInfo()
    if ignoredInfo ~= "" then table.insert(context, ignoredInfo) end
    
    local conversationsInfo = self:GetActiveConversationsInfo()
    if conversationsInfo ~= "" then table.insert(context, conversationsInfo) end
    
    table.insert(context, self:GetOptimizedChatHistory())
    
    local fullContext = table.concat(context, "\n\n")
    if #fullContext > self.Settings.MaxContextLength then
        fullContext = self:CompressContext(fullContext)
    end
    
    return fullContext
end

function ContextBuilder:GetGameInfo()
    return string.format(
        "Game: %s (ID: %d), with %d players total.",
        game.Name,
        game.PlaceId,
        #Players:GetPlayers()
    )
end

function ContextBuilder:GetStateInfo()
    local action = System.State.CurrentAction or "idle"
    local target = System.State.CurrentTarget or "none"
    local time = math.floor(tick() - System.State.ActionStartTime)
    
    local state = "Current state: You are " .. action
    if target ~= "none" then state = state .. " with target " .. target end
    if time > 0 then state = state .. " for " .. time .. " seconds" end
    
    return state
end

function ContextBuilder:GetNearbyPlayersInfo()
    if not self.Controller or not self.Controller.RootPart then
        return "Nearby players: none (character not loaded)"
    end
    
    local nearby = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (player.Character.HumanoidRootPart.Position - self.Controller.RootPart.Position).Magnitude
            if distance <= Config.DETECTION_RADIUS then
                local info = self:GetPlayerDetails(player, distance)
                table.insert(nearby, info)
            end
        end
    end
    
    return "Nearby players: " .. (#nearby > 0 and table.concat(nearby, "\n- ") or "none")
end

function ContextBuilder:GetPlayerDetails(player, distance)
    local details = { player.Name .. " (" .. math.floor(distance) .. " studs away)" }
    
    if self.Settings.IncludePlayerActivity then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if humanoid.MoveDirection.Magnitude > 0.1 then
                table.insert(details, "moving")
                if humanoid.WalkSpeed > 17 then table.insert(details, "running") end
            end
            if humanoid.FloorMaterial == Enum.Material.Air and humanoid.JumpPower > 0 then
                table.insert(details, "jumping")
            end
        end
    end
    
    if System.Modules.ChatManager:IsInConversationWith(player.Name) then
        table.insert(details, "in conversation")
    end
    
    if System.State.IgnoredPlayers[player.Name] and System.State.IgnoredPlayers[player.Name] > os.time() then
        table.insert(details, "ignored (spam)")
    end
    
    return table.concat(details, ", ")
end

function ContextBuilder:GetIgnoredPlayersInfo()
    local ignored = {}
    for name, time in pairs(System.State.IgnoredPlayers) do
        if time > os.time() then
            table.insert(ignored, name .. " (" .. math.floor((time - os.time()) / 60) .. " min left)")
        end
    end
    return #ignored > 0 and "Ignoring " .. #ignored .. " spammers: " .. table.concat(ignored, ", ") or ""
end

function ContextBuilder:GetActiveConversationsInfo()
    local conversations = {}
    for name, time in pairs(System.Modules.ChatManager.ActiveConversations) do
        local duration = math.floor((os.time() - time) / 60)
        table.insert(conversations, name .. " (" .. (duration < 1 and "recent" or duration .. " min") .. ")")
    end
    return #conversations > 0 and "Active conversations: " .. table.concat(conversations, ", ") or ""
end

function ContextBuilder:GetOptimizedChatHistory()
    local messages = System.State.MessageLog
    if #messages == 0 then return "Recent chat: No recent messages" end
    
    local processed = {}
    local currentTime = os.time()
    
    for _, entry in ipairs(messages) do
        local timeAgo = currentTime - entry.timestamp
        local relevance = self:CalculateMessageRelevance(entry, timeAgo)
        
        if relevance >= self.Settings.MinMessageRelevance then
            local fingerprint = entry.sender .. ":" .. self:GetMessageFingerprint(entry.message)
            local count = (processed[fingerprint] or 0) + 1
            
            if count <= self.Settings.MaxSimilarMessages then
                processed[fingerprint] = count
                table.insert(processed, {
                    text = "[" .. entry.sender .. " - " .. self:FormatTime(timeAgo) .. "]: " .. entry.message,
                    relevance = relevance,
                    timestamp = entry.timestamp
                })
            end
        end
    end
    
    table.sort(processed, function(a, b) return a.timestamp < b.timestamp end)
    local limited = {}
    for i = 1, math.min(self.Settings.MaxRecentMessages, #processed) do
        table.insert(limited, processed[i].text)
    end
    
    return "Recent chat:\n" .. (#limited > 0 and table.concat(limited, "\n") or "No relevant messages")
end

function ContextBuilder:CalculateMessageRelevance(entry, timeAgo)
    local recency = math.max(0, 1 - (timeAgo / 900)) -- 15 min decay
    local mentionBonus = entry.message:lower():find(localPlayer.Name:lower()) and 0.3 or 0
    local questionBonus = entry.message:find("?") and 0.2 or 0
    return recency + mentionBonus + questionBonus
end

function ContextBuilder:GetMessageFingerprint(message)
    local simplified = message:lower():gsub("[^%w%s]", ""):match("^%s*(.-)%s*$")
    if #simplified < 10 then return simplified end
    
    local words = {}
    for word in simplified:gmatch("%S+") do
        table.insert(words, word)
        if #words >= 5 then break end
    end
    return table.concat(words, " ")
end

function ContextBuilder:FormatTime(seconds)
    return seconds < 60 and seconds .. "s ago" or math.floor(seconds / 60) .. "m ago"
end

function ContextBuilder:GetEnvironmentContext()
    if self.Cache.Environment.value and os.time() - self.Cache.Environment.timestamp < 30 then
        return self.Cache.Environment.value
    end
    
    if not self.Controller or not self.Controller.RootPart then
        return "Unknown (character not loaded)"
    end
    
    local position = self.Controller.RootPart.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {self.Controller.Character}
    
    local skyRay = workspace:Raycast(position, Vector3.new(0, 500, 0), params)
    local groundRay = workspace:Raycast(position, Vector3.new(0, -10, 0), params)
    
    local environment = skyRay and "Indoor" or "Outdoor"
    local ground = groundRay and groundRay.Instance.Name or "unknown"
    if groundRay and groundRay.Instance.Name == "Terrain" then
        ground = groundRay.Material.Name
    end
    
    local nearby = self:GetNearbyObjects(position, params)
    local result = environment .. " area on " .. ground
    if #nearby > 0 then
        result = result .. ", near " .. table.concat(nearby, ", ")
    end
    
    self.Cache.Environment = { value = result, timestamp = os.time() }
    return result
end

function ContextBuilder:GetNearbyObjects(position, params)
    local directions = {
        Vector3.new(50, 0, 0), Vector3.new(-50, 0, 0),
        Vector3.new(0, 0, 50), Vector3.new(0, 0, -50)
    }
    
    local objects = {}
    for _, dir in ipairs(directions) do
        local ray = workspace:Raycast(position, dir, params)
        if ray and ray.Instance.Name ~= "Terrain" then
            local name = ray.Instance.Name
            if ray.Instance.Parent:IsA("Model") then
                name = ray.Instance.Parent.Name
            end
            if not table.find(objects, name) then
                table.insert(objects, name .. " (" .. math.floor((ray.Position - position).Magnitude) .. " studs)")
            end
        end
    end
    return objects
end

function ContextBuilder:CompressContext(context)
    local lines = {}
    for line in context:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    
    -- Keep essential info, truncate less critical details
    local compressed = {}
    local chatStart = nil
    for i, line in ipairs(lines) do
        if line:find("Recent chat:") then
            chatStart = i
            break
        end
        table.insert(compressed, line)
    end
    
    if chatStart then
        local chatLines = {}
        for i = chatStart + 1, #lines do
            table.insert(chatLines, lines[i])
        end
        for i = 1, math.min(4, #chatLines) do
            table.insert(compressed, chatLines[#chatLines - i + 1])
        end
        if #chatLines > 4 then
            table.insert(compressed, "[Chat truncated]")
        end
        table.insert(compressed, "Recent chat:")
    end
    
    local result = table.concat(compressed, "\n")
    if #result > self.Settings.MaxContextLength then
        result = result:sub(1, self.Settings.MaxContextLength - 20) .. "\n[Truncated]"
    end
    return result
end

return ContextBuilder

-- Context Builder Module
-- /LxckStxp/Censura-Applications/LocalPlayer/AI/Modules/ContextBuilder.lua

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService") -- For JSON utilities
local localPlayer = Players.LocalPlayer

local ContextBuilder = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

-- Advanced settings for context building
ContextBuilder.Settings = {
    MaxRecentMessages = 8,          -- Maximum chat messages to include in context
    MinMessageRelevance = 0.5,      -- Minimum relevance score to include a message (0-1)
    MaxSimilarMessages = 2,         -- Maximum number of similar messages to include
    RelevanceDecayRate = 0.2,       -- How quickly older messages lose relevance
    IncludePlayerDistance = true,   -- Include distance to players in context
    IncludePlayerActivity = true,   -- Include what players are doing
    IncludeEnvironment = true,      -- Include environmental context
    MessageDeduplication = true,    -- Enable message deduplication
    ProcessedMessages = {},         -- Track processed message IDs
    ContextHistory = {},            -- Store recent contexts to avoid repetition
    MaxContextHistory = 5           -- Number of previous contexts to track
}

function ContextBuilder:Initialize(controller)
    self.Controller = controller
    
    -- Set up message processing cache cleanup
    spawn(function()
        while wait(60) do -- Clean up every minute
            self:CleanupProcessedMessages()
        end
    end)
    
    return self
end

-- Clean up old processed messages to prevent memory bloat
function ContextBuilder:CleanupProcessedMessages()
    local currentTime = os.time()
    local toRemove = {}
    
    for msgId, timestamp in pairs(self.Settings.ProcessedMessages) do
        if currentTime - timestamp > 300 then -- 5 minutes
            table.insert(toRemove, msgId)
        end
    end
    
    for _, msgId in ipairs(toRemove) do
        self.Settings.ProcessedMessages[msgId] = nil
    end
    
    -- Also trim context history
    while #self.Settings.ContextHistory > self.Settings.MaxContextHistory do
        table.remove(self.Settings.ContextHistory, 1)
    end
    
    Logger:debug("Cleaned up " .. #toRemove .. " old processed messages")
end

-- Get Game Context for Grok with enhanced environmental awareness
function ContextBuilder:GetContext()
    local context = {}
    
    -- Add introduction and role information
    table.insert(context, "You are a human-like player in Roblox named " .. localPlayer.Name .. ". Respond naturally as if you were a real player.")
    
    -- Game information
    local gameInfo = self:GetGameInfo()
    table.insert(context, gameInfo)
    
    -- Current state
    local stateInfo = self:GetStateInfo()
    table.insert(context, stateInfo)
    
    -- Environmental context
    if self.Settings.IncludeEnvironment then
        local environmentInfo = self:GetEnvironmentContext()
        table.insert(context, "Environment: " .. environmentInfo)
    end
    
    -- Nearby players with relevant details
    local playerInfo = self:GetNearbyPlayersInfo()
    table.insert(context, playerInfo)
    
    -- Add information about ignored players
    local ignoredInfo = self:GetIgnoredPlayersInfo()
    if ignoredInfo ~= "" then
        table.insert(context, ignoredInfo)
    end
    
    -- Active conversations
    local conversationsInfo = self:GetActiveConversationsInfo()
    if conversationsInfo ~= "" then
        table.insert(context, conversationsInfo)
    end
    
    -- Recent chat messages (processed to avoid duplication and ensure relevance)
    local chatHistory = self:GetOptimizedChatHistory()
    table.insert(context, chatHistory)
    
    -- Join all context sections with newlines
    local fullContext = table.concat(context, "\n\n")
    
    -- Store this context in history to avoid repetition
    table.insert(self.Settings.ContextHistory, self:GenerateContextFingerprint(fullContext))
    if #self.Settings.ContextHistory > self.Settings.MaxContextHistory then
        table.remove(self.Settings.ContextHistory, 1)
    end
    
    return fullContext
end

-- Generate a fingerprint of the context to detect similar contexts
function ContextBuilder:GenerateContextFingerprint(context)
    -- Extract key elements from the context to form a fingerprint
    local stateMatch = context:match("Current state: ([^\n]+)")
    local recentMessagesMatch = context:match("Recent chat:[^\n]*\n(.-)\n\n") or ""
    
    -- Create a simplified representation of the context
    local fingerprint = {
        state = stateMatch or "unknown",
        messages = {},
        timestamp = os.time()
    }
    
    -- Extract message senders
    for sender in recentMessagesMatch:gmatch("%[([^%]]+)") do
        if not fingerprint.messages[sender] then
            fingerprint.messages[sender] = 0
        end
        fingerprint.messages[sender] = fingerprint.messages[sender] + 1
    end
    
    return fingerprint
end

-- Get basic game information
function ContextBuilder:GetGameInfo()
    local gameInfo = {
        name = game.Name,
        placeId = game.PlaceId,
        playerCount = #Players:GetPlayers()
    }
    
    return string.format("Game: %s (ID: %d), with %d players total.", 
        gameInfo.name, gameInfo.placeId, gameInfo.playerCount)
end

-- Get current AI state information
function ContextBuilder:GetStateInfo()
    local currentAction = System.State.CurrentAction or "idle"
    local currentTarget = System.State.CurrentTarget or "none"
    
    local stateText = "Current state: You are " .. currentAction
    if currentTarget ~= "none" then
        stateText = stateText .. " with target " .. currentTarget
    end
    
    -- Add information about how long you've been in this state
    local actionTime = math.floor(tick() - System.State.ActionStartTime)
    if actionTime > 0 then
        stateText = stateText .. " for " .. actionTime .. " seconds"
    end
    
    return stateText
end

-- Get detailed information about nearby players
function ContextBuilder:GetNearbyPlayersInfo()
    if not self.Controller or not self.Controller.RootPart then
        return "Nearby players: none (character not loaded)"
    end
    
    local nearbyPlayers = {}
    local detailedInfo = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (player.Character.HumanoidRootPart.Position - self.Controller.RootPart.Position).Magnitude
            
            if distance <= Config.DETECTION_RADIUS then
                table.insert(nearbyPlayers, player.Name .. " (" .. math.floor(distance) .. " studs away)")
                
                -- Build detailed information
                local info = {
                    name = player.Name,
                    distance = math.floor(distance),
                    team = player.Team and player.Team.Name or "No Team"
                }
                
                -- Add activity information if enabled
                if self.Settings.IncludePlayerActivity then
                    info.moving = self:IsPlayerMoving(player) and "moving" or "stationary"
                    
                    -- Check what they're doing
                    if self:IsPlayerJumping(player) then
                        info.activity = "jumping"
                    elseif self:IsPlayerSprinting(player) then
                        info.activity = "running"
                    elseif self:IsPlayerCrouching(player) then
                        info.activity = "crouching"
                    end
                    
                    -- Check if they're looking at us
                    if self:IsPlayerLookingAt(player, localPlayer) then
                        info.lookingAtMe = true
                    end
                end
                
                -- Check if they're in an active conversation with us
                if System.Modules.ChatManager:IsInConversationWith(player.Name) then
                    info.inConversation = true
                end
                
                -- Check if they're being ignored due to spam
                if System.State.IgnoredPlayers[player.Name] and System.State.IgnoredPlayers[player.Name] > os.time() then
                    info.isIgnored = true
                end
                
                table.insert(detailedInfo, info)
            end
        end
    end
    
    -- Format the detailed information in a readable way
    local result = "Nearby players: " .. (next(nearbyPlayers) and table.concat(nearbyPlayers, ", ") or "none")
    
    if #detailedInfo > 0 then
        result = result .. "\n\nDetailed player information:"
        
        for _, info in ipairs(detailedInfo) do
            local details = "\n- " .. info.name .. ": " .. info.distance .. " studs away"
            
            if info.moving then
                details = details .. ", " .. info.moving
            end
            
            if info.activity then
                details = details .. ", " .. info.activity
            end
            
            if info.lookingAtMe then
                details = details .. ", looking at you"
            end
            
            if info.inConversation then
                details = details .. ", in active conversation with you"
            end
            
            if info.isIgnored then
                details = details .. ", currently ignoring due to spam"
            end
            
            result = result .. details
        end
    end
    
    return result
end

-- Get information about ignored players
function ContextBuilder:GetIgnoredPlayersInfo()
    local ignoredCount = 0
    local ignoredNames = {}
    
    for name, time in pairs(System.State.IgnoredPlayers) do
        if time > os.time() then
            ignoredCount = ignoredCount + 1
            local remainingTime = math.floor((time - os.time()) / 60)
            table.insert(ignoredNames, name .. " (" .. remainingTime .. " min remaining)")
        end
    end
    
    if ignoredCount > 0 then
        return "Currently ignoring " .. ignoredCount .. " player(s) for spam behavior: " .. table.concat(ignoredNames, ", ")
    else
        return ""
    end
end

-- Get information about active conversations
function ContextBuilder:GetActiveConversationsInfo()
    local conversationCount = 0
    local conversationDetails = {}
    
    for name, time in pairs(System.Modules.ChatManager.ActiveConversations) do
        conversationCount = conversationCount + 1
        local duration = math.floor((os.time() - time) / 60)
        if duration < 1 then
            duration = "less than a minute"
        else
            duration = duration .. " minutes"
        end
        
        table.insert(conversationDetails, name .. " (talking for " .. duration .. ")")
    end
    
    if conversationCount > 0 then
        return "Active conversations: " .. table.concat(conversationDetails, ", ")
    else
        return ""
    end
end

-- Get optimized chat history with deduplication and relevance filtering
function ContextBuilder:GetOptimizedChatHistory()
    local messageLog = System.State.MessageLog
    if #messageLog == 0 then
        return "Recent chat: No recent messages"
    end
    
    -- Create a list of processed messages with metadata
    local processedMessages = {}
    local currentTime = os.time()
    
    for i, entry in ipairs(messageLog) do
        local timeAgo = currentTime - entry.timestamp
        local timeString = ""
        
        if timeAgo < 60 then
            timeString = timeAgo .. "s ago"
        else
            timeString = math.floor(timeAgo/60) .. "m ago" 
        end
        
        -- Calculate message relevance (newer = more relevant)
        local recency = 1 - (timeAgo / (60 * 15)) -- 15 minutes is the maximum age we consider
        recency = math.max(0, math.min(1, recency)) -- Clamp between 0 and 1
        
        -- Calculate additional relevance factors
        local mentionBonus = entry.message:lower():find(localPlayer.Name:lower()) and 0.3 or 0
        local questionBonus = entry.message:find("?") and 0.2 or 0
        
        -- Calculate final relevance score
        local relevance = recency + mentionBonus + questionBonus
        
        -- Generate a message fingerprint for deduplication
        local msgFingerprint = entry.sender .. ":" .. self:GetMessageFingerprint(entry.message)
        
        -- Add to processed messages if it meets minimum relevance
        if relevance >= self.Settings.MinMessageRelevance then
            table.insert(processedMessages, {
                sender = entry.sender,
                message = entry.message,
                timestamp = entry.timestamp,
                timeString = timeString,
                relevance = relevance,
                fingerprint = msgFingerprint,
                index = i  -- Original index for stable sorting
            })
        end
    end
    
    -- Sort by relevance (most relevant first)
    table.sort(processedMessages, function(a, b)
        return a.relevance > b.relevance
    end)
    
    -- Deduplicate similar messages if enabled
    if self.Settings.MessageDeduplication then
        local uniqueFingerprints = {}
        local deduplicatedMessages = {}
        
        for _, msg in ipairs(processedMessages) do
            if not uniqueFingerprints[msg.fingerprint] then
                uniqueFingerprints[msg.fingerprint] = 1
                table.insert(deduplicatedMessages, msg)
            elseif uniqueFingerprints[msg.fingerprint] < self.Settings.MaxSimilarMessages then
                uniqueFingerprints[msg.fingerprint] = uniqueFingerprints[msg.fingerprint] + 1
                table.insert(deduplicatedMessages, msg)
            end
            -- Skip if we already have max similar messages
        end
        
        processedMessages = deduplicatedMessages
    end
    
    -- Limit to max recent messages
    if #processedMessages > self.Settings.MaxRecentMessages then
        local temp = {}
        for i = 1, self.Settings.MaxRecentMessages do
            table.insert(temp, processedMessages[i])
        end
        processedMessages = temp
    end
    
    -- Re-sort by original timestamp for chronological display
    table.sort(processedMessages, function(a, b)
        return a.timestamp < b.timestamp
    end)
    
    -- Format the chat history
    local result = "Recent chat:"
    
    for _, entry in ipairs(processedMessages) do
        -- Mark this message as processed to avoid duplicate responses
        self.Settings.ProcessedMessages[entry.sender .. ":" .. entry.message] = os.time()
        
        -- Format the message entry
        result = result .. "\n[" .. entry.sender .. " - " .. entry.timeString .. "]: " .. entry.message
    end
    
    return result
end

-- Generate a fingerprint for a message to detect similar messages
function ContextBuilder:GetMessageFingerprint(message)
    -- Simplify message for comparison (lowercase, no punctuation, trim spaces)
    local simplified = message:lower():gsub("[%p%c]", ""):gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
    
    -- For very short messages, use as is
    if #simplified < 10 then
        return simplified
    end
    
    -- For longer messages, use first few words as fingerprint
    local words = {}
    for word in simplified:gmatch("%S+") do
        table.insert(words, word)
        if #words >= 5 then break end
    end
    
    return table.concat(words, " ")
end

-- Check if a player is moving
function ContextBuilder:IsPlayerMoving(player)
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return humanoid.MoveDirection.Magnitude > 0.1
    end
    return false
end

-- Check if a player is jumping
function ContextBuilder:IsPlayerJumping(player)
    if not player or not player.Character then return false end
    
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        -- Check if they're in the air and moving upward
        return humanoid.FloorMaterial == Enum.Material.Air and 
               humanoid.JumpPower > 0 and 
               player.Character.HumanoidRootPart.Velocity.Y > 5
    end
    return false
end

-- Check if a player is sprinting
function ContextBuilder:IsPlayerSprinting(player)
    if not player or not player.Character then return false end
    
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        -- Check if they're moving faster than walking
        return humanoid.MoveDirection.Magnitude > 0.1 and humanoid.WalkSpeed > 17
    end
    return false
end

-- Check if a player is crouching
function ContextBuilder:IsPlayerCrouching(player)
    if not player or not player.Character then return false end
    
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        -- Some games set a lower walk speed or height when crouching
        return humanoid.WalkSpeed < 8 or humanoid.HipHeight < 1
    end
    return false
end

-- Check if a player is looking at another player
function ContextBuilder:IsPlayerLookingAt(player1, player2)
    if not player1 or not player2 or not player1.Character or not player2.Character then
        return false
    end
    
    local head1 = player1.Character:FindFirstChild("Head")
    local head2 = player2.Character:FindFirstChild("Head")
    
    if not head1 or not head2 then
        return false
    end
    
    local direction = (head2.Position - head1.Position).Unit
    local lookVector = head1.CFrame.LookVector
    
    -- Dot product to check if vectors are pointing in similar direction
    local dotProduct = direction:Dot(lookVector)
    
    -- If dot product > 0.7, the player is roughly looking at the other player
    return dotProduct > 0.7
end

-- Get environmental context by examining surroundings
function ContextBuilder:GetEnvironmentContext()
    if not self.Controller or not self.Controller.RootPart then
        return "Unknown (character not loaded)"
    end
    
    local position = self.Controller.RootPart.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {self.Controller.Character}
    
    -- Cast rays in different directions to identify surroundings
    local directions = {
        Vector3.new(1, 0, 0),
        Vector3.new(-1, 0, 0),
        Vector3.new(0, 0, 1),
        Vector3.new(0, 0, -1),
        Vector3.new(0, 1, 0),
        Vector3.new(0, -1, 0)
    }
    
    local nearbyObjects = {}
    local isIndoors = true
    local skyVisible = false
    
    -- Check if sky is visible (cast ray upward)
    local skyRay = workspace:Raycast(position, Vector3.new(0, 500, 0), rayParams)
    if not skyRay then
        skyVisible = true
    end
    
    for _, direction in ipairs(directions) do
        local result = workspace:Raycast(position, direction * 50, rayParams)
        if result then
            local hitPart = result.Instance
            local hitDistance = (result.Position - position).Magnitude
            
            -- Only add unique objects and include distance
            local objName = hitPart.Name
            if hitPart.Parent and hitPart.Parent:IsA("Model") then
                objName = hitPart.Parent.Name .. " (" .. hitPart.Name .. ")"
            end
            
            if not table.find(nearbyObjects, objName) and objName ~= "Terrain" then
                table.insert(nearbyObjects, objName .. " (" .. math.floor(hitDistance) .. " studs)")
            end
        else
            if direction.Y == 0 then -- If horizontal ray doesn't hit anything
                isIndoors = false
            end
        end
    end
    
    -- Determine environment type
    local environmentType = "Unknown"
    if skyVisible and not isIndoors then
        environmentType = "Open outdoor area"
    elseif not skyVisible and isIndoors then
        environmentType = "Indoor enclosed area"
    elseif skyVisible and isIndoors then
        environmentType = "Semi-enclosed area"
    elseif not skyVisible and not isIndoors then
        environmentType = "Underground or covered area"
    end
    
    -- Check what we're standing on
    local groundRay = workspace:Raycast(position, Vector3.new(0, -10, 0), rayParams)
    local groundType = "unknown surface"
    local groundMaterial = "unknown"
    
    if groundRay then
        if groundRay.Instance.Name == "Terrain" then
            groundType = "terrain"
            
            -- Try to determine terrain material
            local terrainMaterial = groundRay.Material
            if terrainMaterial then
                groundMaterial = terrainMaterial.Name
            end
        else
            groundType = groundRay.Instance.Name
            
            -- Try to get material
            if groundRay.Instance.Material then
                groundMaterial = groundRay.Instance.Material.Name
            end
        end
    end
    
    -- Combine information
    local environmentDesc = environmentType .. " on " .. groundType .. " (" .. groundMaterial .. ")"
    
    if #nearbyObjects > 0 then
        -- Limit to 5 most important objects to avoid clutter
        if #nearbyObjects > 5 then
            local trimmed = {}
            for i = 1, 5 do
                table.insert(trimmed, nearbyObjects[i])
            end
            environmentDesc = environmentDesc .. ", with " .. table.concat(trimmed, ", ") .. 
                              " and " .. (#nearbyObjects - 5) .. " other objects nearby"
        else
            environmentDesc = environmentDesc .. ", with " .. table.concat(nearbyObjects, ", ") .. " nearby"
        end
    end
    
    return environmentDesc
end

return ContextBuilder

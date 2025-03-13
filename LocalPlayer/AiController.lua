local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Ensure CensuraG is loaded
if not _G.CensuraG then
    error("CensuraG not initialized. Please load CensuraG.lua first.")
end

local Config = _G.CensuraG.Config
local Methods = _G.CensuraG.Methods
local Logger = _G.CensuraG.Logger
local localPlayer = Players.LocalPlayer

-- AI Controller Module
local AiController = {}
AiController.__index = AiController

-- Configuration
local WEBHOOK_URL = "http://127.0.0.1:5000/webhook"
local MAX_MESSAGE_LENGTH = 180
local MESSAGE_DELAY = 1
local DECISION_INTERVAL = 10

-- Advanced configuration
local TYPING_SPEED = { min = 0.05, max = 0.12 } -- Time per character for realistic typing
local MOVEMENT_RANDOMIZATION = 0.3 -- Randomness in movement patterns (0-1)
local INTERACTION_DISTANCE = 6 -- How close to get to players for interaction
local DETECTION_RADIUS = 60 -- How far to detect other players
local CHAT_MEMORY_SIZE = 15 -- Number of chat messages to remember
local ACTION_TIMEOUT = 30 -- Maximum time for any action before forcing a new decision

-- State Variables
AiController.IsAIControlled = false
AiController.MessageLog = {}
AiController.LastSentTime = 0
AiController.CurrentAction = nil
AiController.ActionStartTime = 0
AiController.CurrentTarget = nil
AiController.CurrentPath = nil
AiController.CurrentDecision = nil
AiController.FailedPathfinds = 0
AiController.LastPositions = {} -- Track positions to detect getting stuck
AiController.StuckDetectionInterval = 2 -- How often to check if stuck (seconds)
AiController.StuckThreshold = 3 -- Positions to check for being stuck
AiController.StuckDistance = 1 -- Maximum distance to consider as "not moving"
AiController.EmoteActions = {
    ["wave"] = function(self) self.Humanoid:PlayEmote("wave") end,
    ["dance"] = function(self) self.Humanoid:PlayEmote("dance") end,
    ["laugh"] = function(self) self.Humanoid:PlayEmote("laugh") end,
    ["point"] = function(self) self.Humanoid:PlayEmote("point") end,
    ["sit"] = function(self) self.Humanoid.Sit = true end,
    ["jump"] = function(self) self.Humanoid.Jump = true end
}

-- Initialize the AI Controller
function AiController:Initialize()
    Logger:info("Initializing AiController")
    
    self.Character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    self.Humanoid = self.Character:WaitForChild("Humanoid")
    self.RootPart = self.Character:WaitForChild("HumanoidRootPart")
    
    -- Create UI
    self:SetupUI()
    
    -- Setup event handlers
    self:SetupChatHandler()
    self:SetupCharacterHandler()
    
    -- Start position tracking for stuck detection
    self:StartPositionTracking()
    
    Logger:info("AiController initialized successfully")
    return self
end

-- Setup UI with more controls and information
function AiController:SetupUI()
    self.Window = _G.CensuraG.CreateWindow("AI Controller")
    self.Window.Frame.Position = UDim2.new(0, 100, 0, 100)
    self.Window:SetSize(300, 350) -- Larger window for more controls
    
    self.Grid = Methods:CreateGrid(self.Window.ContentFrame)
    
    -- Main toggle
    self.ToggleAI = Methods:CreateSwitch(self.Grid.Instance, "Enable AI", false, function(state)
        self:ToggleAIControl(state)
    end)
    self.Grid:AddComponent(self.ToggleAI)
    
    -- Behavior controls
    self.BehaviorLabel = Methods:CreateLabel(self.Grid.Instance, "Behavior Settings")
    self.Grid:AddComponent(self.BehaviorLabel)
    
    -- Decision interval slider
    self.IntervalSlider = Methods:CreateSlider(self.Grid.Instance, "Decision Interval", 2, 15, DECISION_INTERVAL, function(value)
        DECISION_INTERVAL = value
        Logger:info("Decision interval set to " .. value)
    end)
    self.Grid:AddComponent(self.IntervalSlider)
    
    -- Detection radius slider
    self.RadiusSlider = Methods:CreateSlider(self.Grid.Instance, "Detection Radius", 20, 100, DETECTION_RADIUS, function(value)
        DETECTION_RADIUS = value
        Logger:info("Detection radius set to " .. value)
    end)
    self.Grid:AddComponent(self.RadiusSlider)
    
    -- Status display
    self.StatusLabel = Methods:CreateLabel(self.Grid.Instance, "Status: Idle")
    self.Grid:AddComponent(self.StatusLabel)
    
    -- Current action display
    self.ActionLabel = Methods:CreateLabel(self.Grid.Instance, "Action: None")
    self.Grid:AddComponent(self.ActionLabel)
    
    -- Target display
    self.TargetLabel = Methods:CreateLabel(self.Grid.Instance, "Target: None")
    self.Grid:AddComponent(self.TargetLabel)
    
    -- Manual actions
    self.ManualLabel = Methods:CreateLabel(self.Grid.Instance, "Manual Controls")
    self.Grid:AddComponent(self.ManualLabel)
    
    -- Wander button
    self.WanderButton = Methods:CreateButton(self.Grid.Instance, "Wander", function()
        if self.IsAIControlled then
            self:Wander()
            self:UpdateStatusLabels("wander", nil)
        end
    end)
    self.Grid:AddComponent(self.WanderButton)
    
    -- Say something button
    self.SayButton = Methods:CreateButton(self.Grid.Instance, "Say Something", function()
        if self.IsAIControlled then
            local phrases = {
                "Hey everyone, what's up?",
                "Anyone doing anything cool?",
                "I'm just exploring around.",
                "This place is pretty neat!",
                "How's everyone doing today?"
            }
            local message = phrases[math.random(1, #phrases)]
            self:SendMessage(message)
            self:UpdateStatusLabels("say", nil, message)
        end
    end)
    self.Grid:AddComponent(self.SayButton)
    
    _G.CensuraG.SetTheme("Cyberpunk")
end

-- Update status labels in the UI
function AiController:UpdateStatusLabels(action, target, message)
    self.StatusLabel:SetText("Status: " .. (self.IsAIControlled and "Active" or "Idle"))
    self.ActionLabel:SetText("Action: " .. (action or "None"))
    self.TargetLabel:SetText("Target: " .. (target or "None"))
    
    -- Log the current state
    if action then
        local statusText = "AI Status: " .. action
        if target then statusText = statusText .. " → " .. target end
        if message then statusText = statusText .. " | " .. message end
        Logger:info(statusText)
    end
end

-- Toggle AI Control
function AiController:ToggleAIControl(state)
    self.IsAIControlled = state
    
    if state then
        self.ActionStartTime = tick()
        spawn(function() self:RunAI() end)
        self:UpdateStatusLabels("Starting", nil)
    else
        -- Stop any current movement
        if self.Humanoid then
            self.Humanoid:MoveTo(self.RootPart.Position)
        end
        self:UpdateStatusLabels("Stopped", nil)
    end
    
    Logger:info("AI Control " .. (state and "enabled" or "disabled"))
end

-- Setup Chat Handler with improved filtering
function AiController:SetupChatHandler()
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
                    self:ReceiveMessage(playerObj.Name, textChatMessage.Text)
                    
                    if self.IsAIControlled and self:ShouldRespondToChat(textChatMessage.Text, playerObj.Name) then
                        self:QueryGrokWithChat(textChatMessage.Text, playerObj.Name)
                    end
                end
            end
        end)
    end
end

-- Connect chat for a specific player
function AiController:ConnectPlayerChat(player)
    player.Chatted:Connect(function(message)
        self:ReceiveMessage(player.Name, message)
        
        if self.IsAIControlled and self:ShouldRespondToChat(message, player.Name) then
            self:QueryGrokWithChat(message, player.Name)
        end
    end)
end

-- Determine if AI should respond to a chat message
function AiController:ShouldRespondToChat(message, sender)
    -- Always respond if our name is mentioned
    if message:lower():find(localPlayer.Name:lower()) then
        return true
    end
    
    -- Check if player is nearby
    local senderPlayer = Players:FindFirstChild(sender)
    if senderPlayer and senderPlayer.Character and senderPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local distance = (senderPlayer.Character.HumanoidRootPart.Position - self.RootPart.Position).Magnitude
        if distance <= DETECTION_RADIUS * 0.7 then -- Respond to closer players more often
            return true
        end
    end
    
    -- Respond randomly to other messages
    return math.random() < 0.3 -- 30% chance to respond to random messages
end

-- Setup Character Handler
function AiController:SetupCharacterHandler()
    -- Handle character respawning
    localPlayer.CharacterAdded:Connect(function(character)
        self.Character = character
        self.Humanoid = character:WaitForChild("Humanoid")
        self.RootPart = character:WaitForChild("HumanoidRootPart")
        
        -- Reset state on respawn
        self.CurrentAction = nil
        self.CurrentTarget = nil
        self.CurrentPath = nil
        self.FailedPathfinds = 0
        self.LastPositions = {}
        
        Logger:info("Character respawned, AI controller updated")
        
        -- Restart position tracking
        self:StartPositionTracking()
    end)
end

-- Start tracking positions to detect getting stuck
function AiController:StartPositionTracking()
    spawn(function()
        while self.Character and self.Character.Parent do
            if self.RootPart then
                table.insert(self.LastPositions, self.RootPart.Position)
                if #self.LastPositions > self.StuckThreshold then
                    table.remove(self.LastPositions, 1)
                end
                
                -- Check if stuck
                if #self.LastPositions >= self.StuckThreshold and self.CurrentAction then
                    local isStuck = true
                    local referencePos = self.LastPositions[1]
                    
                    for i = 2, #self.LastPositions do
                        if (self.LastPositions[i] - referencePos).Magnitude > self.StuckDistance then
                            isStuck = false
                            break
                        end
                    end
                    
                    if isStuck and self.IsAIControlled then
                        Logger:warn("AI appears to be stuck, forcing new action")
                        self:ForceNewAction()
                    end
                end
            end
            
            wait(self.StuckDetectionInterval)
        end
    end)
end

-- Force a new action when stuck
function AiController:ForceNewAction()
    self.CurrentAction = nil
    self.CurrentTarget = nil
    self.CurrentPath = nil
    self.FailedPathfinds = 0
    
    -- Jump to try to unstuck
    self.Humanoid.Jump = true
    
    -- Move in a random direction
    local randomOffset = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
    self.Humanoid:MoveTo(self.RootPart.Position + randomOffset)
    
    -- Force a new decision sooner
    self.ActionStartTime = tick() - ACTION_TIMEOUT + 2
end

-- Receive and Log Messages
function AiController:ReceiveMessage(sender, message)
    table.insert(self.MessageLog, {
        sender = sender,
        message = message,
        timestamp = os.time()
    })
    
    while #self.MessageLog > CHAT_MEMORY_SIZE do
        table.remove(self.MessageLog, 1)
    end
end

function AiController:SendMessage(message)
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
                -- to prevent excessively long typing times
                local typingSpeed = math.max(TYPING_SPEED.min * 0.8, TYPING_SPEED.min - (#chunk / 1000))
                local typingTime = #chunk * (math.random(typingSpeed * 100, TYPING_SPEED.max * 100) / 100)
                
                -- Cap typing time at a reasonable maximum
                typingTime = math.min(typingTime, 4)
                
                wait(typingTime)
                
                -- Send the message
                generalChannel:SendAsync(chunk)
                Logger:info("Sent message chunk (" .. #chunk .. " chars): " .. chunk)
                
                -- Wait between chunks
                if i < #chunks then
                    wait(MESSAGE_DELAY + math.random() * 0.5)
                end
            end
        end
    end)
end

-- Chunk a message into larger pieces for realistic sending
function AiController:ChunkMessage(message)
    local chunks = {}
    
    -- If message is already short enough, return it as a single chunk
    if #message <= MAX_MESSAGE_LENGTH then
        table.insert(chunks, message)
        return chunks
    end
    
    while #message > 0 do
        if #message <= MAX_MESSAGE_LENGTH then
            -- If remaining message fits in one chunk, add it and break
            table.insert(chunks, message)
            break
        end
        
        -- Take a chunk of the maximum size
        local chunk = message:sub(1, MAX_MESSAGE_LENGTH)
        
        -- Try to find a good breaking point (sentence end or space)
        local sentenceEnd = chunk:match(".*()%.%s")
        local lastSpace = chunk:find("%s[^%s]*$")
        
        local breakPoint
        if sentenceEnd and sentenceEnd > MAX_MESSAGE_LENGTH * 0.7 then
            -- Prefer breaking at the end of sentences if it's at least 70% into the chunk
            breakPoint = sentenceEnd
        elseif lastSpace then
            -- Otherwise break at the last space
            breakPoint = lastSpace
        else
            -- If no good breaking point, just use the max length
            breakPoint = MAX_MESSAGE_LENGTH + 1
        end
        
        -- Add the chunk and remove it from the message
        table.insert(chunks, message:sub(1, breakPoint - 1))
        message = message:sub(breakPoint):match("^%s*(.-)%s*$") or ""
    end
    
    return chunks
end

-- Main AI Loop with improved decision-making and timing
function AiController:RunAI()
    while self.IsAIControlled do
        -- Check if current action has timed out
        local actionTime = tick() - self.ActionStartTime
        local needsNewDecision = (not self.CurrentAction) or (actionTime > ACTION_TIMEOUT)
        
        -- Check if current decision has a duration that's elapsed
        if self.CurrentDecision and self.CurrentDecision.duration then
            if actionTime > self.CurrentDecision.duration then
                needsNewDecision = true
            end
        end
        
        if needsNewDecision then
            local context = self:GetContext()
            local decision = self:CallGrok(context)
            
            if decision then
                self.CurrentDecision = decision
                self.ActionStartTime = tick()
                self:ExecuteDecision(decision)
            else
                -- Fallback behavior
                self:SendMessage("Just chilling here, anyone around?")
                self.ActionStartTime = tick()
            end
        end
        
        -- More natural wait time with slight randomization
        wait(DECISION_INTERVAL * (0.8 + math.random() * 0.4))
    end
end

-- Get Game Context for Grok with enhanced environmental awareness
function AiController:GetContext()
    -- Get nearby players with more details
    local nearbyPlayers = {}
    local playerDetails = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (player.Character.HumanoidRootPart.Position - self.RootPart.Position).Magnitude
            
            if distance <= DETECTION_RADIUS then
                table.insert(nearbyPlayers, player.Name .. " (" .. math.floor(distance) .. " studs away)")
                
                -- Add more detailed information
                local playerInfo = {
                    name = player.Name,
                    distance = math.floor(distance),
                    team = player.Team and player.Team.Name or "No Team",
                    moving = self:IsPlayerMoving(player)
                }
                
                -- Check if they're looking at us
                local isLookingAtMe = self:IsPlayerLookingAt(player, localPlayer)
                if isLookingAtMe then
                    playerInfo.lookingAtMe = true
                end
                
                table.insert(playerDetails, playerInfo)
            end
        end
    end
    
    -- Get game information
    local gameInfo = {
        name = game.Name,
        placeId = game.PlaceId,
        playerCount = #Players:GetPlayers()
    }
    
    -- Environmental context
    local environment = self:GetEnvironmentContext()
    
    -- Current state
    local currentState = "You are currently " .. (self.CurrentAction or "idle")
    if self.CurrentTarget then
        currentState = currentState .. " with target " .. self.CurrentTarget
    end
    
    -- Construct context
    local context = "You are a human-like player in Roblox named " .. localPlayer.Name .. ". Decide my next action based on this context:\n\n"
    context = context .. "Game: " .. gameInfo.name .. " (ID: " .. gameInfo.placeId .. "), with " .. gameInfo.playerCount .. " players total.\n"
    context = context .. "Environment: " .. environment .. "\n"
    context = context .. "Current state: " .. currentState .. "\n"
    context = context .. "Nearby players: " .. (next(nearbyPlayers) and table.concat(nearbyPlayers, ", ") or "none") .. "\n"
    context = context .. "Recent chat: "
    
    -- Add recent chat messages
    for _, entry in ipairs(self.MessageLog) do
        local timeAgo = os.time() - entry.timestamp
        local timeString = ""
        
        if timeAgo < 60 then
            timeString = timeAgo .. "s ago"
        else
            timeString = math.floor(timeAgo/60) .. "m ago" 
        end
        
        context = context .. "\n[" .. entry.sender .. " - " .. timeString .. "]: " .. entry.message
    end
    
    -- Add player info
    if #playerDetails > 0 then
        context = context .. "\n\nDetailed player information:"
        for _, info in ipairs(playerDetails) do
            local details = "\n- " .. info.name .. ": " .. info.distance .. " studs away, " 
                          .. (info.moving and "moving" or "stationary")
            
            if info.lookingAtMe then
                details = details .. ", looking at you"
            end
            
            context = context .. details
        end
    end
    
    return context
end

-- Check if a player is moving
function AiController:IsPlayerMoving(player)
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return humanoid.MoveDirection.Magnitude > 0.1
    end
    return false
end

-- Check if a player is looking at another player
function AiController:IsPlayerLookingAt(player1, player2)
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
function AiController:GetEnvironmentContext()
    local position = self.RootPart.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {self.Character}
    
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
    
    for _, direction in ipairs(directions) do
        local result = workspace:Raycast(position, direction * 50, rayParams)
        if result then
            local hitPart = result.Instance
            if hitPart.Name ~= "Terrain" and not table.find(nearbyObjects, hitPart.Name) then
                table.insert(nearbyObjects, hitPart.Name)
            end
        else
            if direction.Y == 0 then -- If horizontal ray doesn't hit anything
                isIndoors = false
            end
        end
    end
    
    -- Determine environment type
    local environmentType = isIndoors and "Indoor area" or "Open outdoor area"
    
    -- Check if we're on terrain or a structure
    local groundRay = workspace:Raycast(position, Vector3.new(0, -10, 0), rayParams)
    local groundType = "unknown surface"
    
    if groundRay then
        if groundRay.Instance.Name == "Terrain" then
            groundType = "terrain"
        else
            groundType = groundRay.Instance.Name
        end
    end
    
    -- Combine information
    local environmentDesc = environmentType .. " on " .. groundType
    if #nearbyObjects > 0 then
        environmentDesc = environmentDesc .. ", with " .. table.concat(nearbyObjects, ", ") .. " nearby"
    end
    
    return environmentDesc
end

-- Query Grok with Chat Input
function AiController:QueryGrokWithChat(message, sender)
    local context = self:GetContext() .. "\nNew message from " .. sender .. ": " .. message
    local decision = self:CallGrok(context)
    
    if decision then
        self.CurrentDecision = decision
        self.ActionStartTime = tick()
        self:ExecuteDecision(decision)
    else
        -- Fallback response
        self:SendMessage("Hey " .. sender .. ", what's that about?")
    end
end

-- Call Webhook Server with enhanced player information
function AiController:CallGrok(message)
    local requestBody = { 
        message = message,
        player_name = localPlayer.Name,
        game_id = game.PlaceId
    }
    
    local body = HttpService:JSONEncode(requestBody)
    
    local response, success, err
    if typeof(request) == "function" then
        Logger:info("Using executor 'request' function")
        success, response = pcall(function()
            local res = request({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = body
            })
            if res.StatusCode == 200 then
                local decoded = HttpService:JSONDecode(res.Body)
                Logger:info("Raw response: " .. tostring(res.Body))
                return decoded
            else
                error("Request returned status: " .. res.StatusCode)
            end
        end)
    else
        Logger:info("Falling back to HttpService")
        success, response = pcall(function()
            local res = HttpService:RequestAsync({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = body
            })
            if res.Success then
                local decoded = HttpService:JSONDecode(res.Body)
                Logger:info("Raw response: " .. tostring(res.Body))
                return decoded
            else
                error("HttpService failed: " .. res.StatusCode .. " - " .. res.StatusMessage)
            end
        end)
    end
    
    if success and response and response.action then
        Logger:info("Decision: action=" .. tostring(response.action) .. 
                   ", target=" .. tostring(response.target) .. 
                   ", message=" .. tostring(response.message) ..
                   ", priority=" .. tostring(response.priority or "N/A") ..
                   ", duration=" .. tostring(response.duration or "N/A"))
        return response
    else
        Logger:error("Failed to call webhook or invalid response: " .. tostring(err or response))
        return nil
    end
end

-- Execute Grok's Decision with new action types
function AiController:ExecuteDecision(decision)
    local action = decision.action
    local target = decision.target
    local message = decision.message
    local priority = decision.priority or 3
    local duration = decision.duration or 5
    
    -- Update UI
    self:UpdateStatusLabels(action, target, message)
    
    -- Update current state
    self.CurrentAction = action
    self.CurrentTarget = target
    
    -- Execute based on action type
    if action == "wander" then
        self:Wander()
    elseif action == "approach" and target then
        local player = Players:FindFirstChild(target)
        if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            self:ApproachPlayer(player)
        end
    elseif action == "interact" and target then
        local player = Players:FindFirstChild(target)
        if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            self:InteractWithPlayer(player, message)
        end
    elseif action == "say" and message then
        self:SendMessage(message)
    elseif action == "emote" and message then
        self:PerformEmote(message)
    elseif action == "explore" then
        self:Explore()
    elseif action == "follow" and target then
        local player = Players:FindFirstChild(target)
        if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            self:FollowPlayer(player, duration)
        end
    else
        Logger:warn("Unknown or invalid action: " .. tostring(action))
    end
end

-- Perform an emote
function AiController:PerformEmote(emoteName)
    if self.EmoteActions[emoteName:lower()] then
        self.EmoteActions[emoteName:lower()](self)
        Logger:info("Performed emote: " .. emoteName)
    else
        -- Try to play it directly
        local success, err = pcall(function()
            self.Humanoid:PlayEmote(emoteName)
        end)
        
        if not success then
            Logger:warn("Failed to play emote: " .. emoteName .. " - " .. tostring(err))
        end
    end
end

-- Wander with improved pathfinding and obstacle avoidance
function AiController:Wander()
    local targetPos = self:GetRandomPosition()
    
    -- Try to find a valid position
    local attempts = 0
    while attempts < 5 do
        local path = PathfindingService:CreatePath({
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true
        })
        
        path:ComputeAsync(self.RootPart.Position, targetPos)
        
        if path.Status == Enum.PathStatus.Success then
            -- Follow the path with human-like movement
            self:FollowPath(path)
            return
        else
            attempts = attempts + 1
            targetPos = self:GetRandomPosition()
            Logger:warn("Failed to compute path, trying a new position (attempt " .. attempts .. ")")
        end
    end
    
    -- If all pathfinding attempts fail, just move directly
    self.Humanoid:MoveTo(self:GetRandomPosition())
end

-- Get Random Position with terrain awareness
function AiController:GetRandomPosition()
    -- Try to find a position on walkable terrain
    local maxDistance = 50
    local minDistance = 10
    local position = self.RootPart.Position
    
    -- Create a random offset direction
    local angle = math.random() * math.pi * 2
    local distance = math.random(minDistance, maxDistance)
    local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
    
    -- Cast a ray down to find terrain height
    local rayStart = position + offset + Vector3.new(0, 50, 0)
    local rayDirection = Vector3.new(0, -100, 0)
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {self.Character}
    
    local rayResult = workspace:Raycast(rayStart, rayDirection, rayParams)
    
    if rayResult then
        -- Return the hit position with a small Y offset
        return rayResult.Position + Vector3.new(0, 3, 0)
    else
        -- Fallback to a simple offset if no terrain is found
        return position + offset
    end
end

-- Follow a computed path with human-like movement
function AiController:FollowPath(path)
    local waypoints = path:GetWaypoints()
    
    -- Skip the first waypoint as it's our current position
    for i = 2, #waypoints do
        if not self.IsAIControlled or self.CurrentAction ~= "wander" then
            break
        end
        
        local waypoint = waypoints[i]
        
        -- Handle waypoint actions
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            self.Humanoid.Jump = true
        end
        
        -- Move to the waypoint with some randomness for human-like movement
        local targetPos = waypoint.Position
        
        -- Add slight randomness to movement
        if math.random() < MOVEMENT_RANDOMIZATION then
            local randomOffset = Vector3.new(
                math.random(-2, 2) * 0.1,
                0,
                math.random(-2, 2) * 0.1
            )
            targetPos = targetPos + randomOffset
        end
        
        self.Humanoid:MoveTo(targetPos)
        
        -- Wait for movement to complete with timeout
        local startTime = tick()
        local reachedWaypoint = false
        
        while not reachedWaypoint and tick() - startTime < 5 and self.IsAIControlled do
            -- Check if we're close enough to the waypoint
            if (self.RootPart.Position - waypoint.Position).Magnitude < 3 then
                reachedWaypoint = true
            end
            
            -- If we're stuck, break out
            if tick() - startTime > 3 and (self.RootPart.Position - waypoint.Position).Magnitude > 10 then
                Logger:warn("Stuck while following path, skipping waypoint")
                break
            end
            
            wait(0.1)
        end
        
        -- Add random pauses for natural movement
        if i < #waypoints and math.random() < 0.3 then
            wait(math.random() * 0.5)
        end
    end
end

-- Approach Player (Smooth Movement)
function AiController:ApproachPlayer(player)
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        Logger:warn("Cannot approach player: invalid player or character")
        return
    end
    
    self.CurrentTarget = player.Name
    local approachStartTime = tick()
    
    while self.IsAIControlled and self.CurrentAction == "approach" and player.Character and 
          player.Character:FindFirstChild("HumanoidRootPart") and
          tick() - approachStartTime < 30 do
        
        local targetPos = player.Character.HumanoidRootPart.Position
        local currentDistance = (targetPos - self.RootPart.Position).Magnitude
        
        -- If we're close enough, stop approaching
        if currentDistance <= INTERACTION_DISTANCE then
            Logger:info("Reached player " .. player.Name)
            break
        end
        
        -- Create a path to the player
        local path = PathfindingService:CreatePath({
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true
        })
        
        -- Compute the path
        path:ComputeAsync(self.RootPart.Position, targetPos)
        
        if path.Status == Enum.PathStatus.Success then
            -- Reset failed pathfinds counter
            self.FailedPathfinds = 0
            
            -- Follow the path
            local waypoints = path:GetWaypoints()
            
            -- Skip the first waypoint
            for i = 2, #waypoints do
                if not self.IsAIControlled or self.CurrentAction ~= "approach" or
                   not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
                    break
                end
                
                -- Get the current distance to player (which may have moved)
                local updatedTargetPos = player.Character.HumanoidRootPart.Position
                local updatedDistance = (updatedTargetPos - self.RootPart.Position).Magnitude
                
                -- If we're close enough, stop approaching
                if updatedDistance <= INTERACTION_DISTANCE then
                    break
                end
                
                -- Handle waypoint actions
                if waypoints[i].Action == Enum.PathWaypointAction.Jump then
                    self.Humanoid.Jump = true
                end
                
                -- Move to the waypoint
                self.Humanoid:MoveTo(waypoints[i].Position)
                
                -- Wait for movement to complete or timeout
                local waypointStartTime = tick()
                local reachedWaypoint = false
                
                while not reachedWaypoint and tick() - waypointStartTime < 3 and 
                      self.IsAIControlled and self.CurrentAction == "approach" do
                    
                    -- Check if we're close enough to the waypoint
                    if (self.RootPart.Position - waypoints[i].Position).Magnitude < 3 then
                        reachedWaypoint = true
                    end
                    
                    -- Check if player moved significantly
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        local newTargetPos = player.Character.HumanoidRootPart.Position
                        if (newTargetPos - targetPos).Magnitude > 10 then
                            -- Player moved too much, recalculate path
                            break
                        end
                    else
                        -- Player character no longer exists
                        break
                    end
                    
                    wait(0.1)
                end
                
                -- If we're at the last waypoint, check if we need to recalculate
                if i == #waypoints and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local finalDistance = (player.Character.HumanoidRootPart.Position - self.RootPart.Position).Magnitude
                    if finalDistance > INTERACTION_DISTANCE + 2 then
                        -- Still too far, need to recalculate
                        break
                    end
                end
            end
        else
            -- Increment failed pathfinds counter
            self.FailedPathfinds = self.FailedPathfinds + 1
            
            if self.FailedPathfinds >= 3 then
                Logger:warn("Failed to pathfind to player " .. player.Name .. " multiple times, giving up")
                break
            end
            
            -- Simple direct movement as fallback
            self.Humanoid:MoveTo(targetPos)
            wait(1)
        end
        
        wait(0.5)
    end
end

-- Interact with Player with more dynamic behaviors
function AiController:InteractWithPlayer(player, message)
    if not player or not player.Character then
        Logger:warn("Cannot interact with player: invalid player or character")
        return
    end
    
    -- First approach the player
    self:ApproachPlayer(player)
    
    -- If we have a message, send it
    if message and message ~= "" then
        self:SendMessage(message)
    else
        -- Default messages if none provided
        local defaultMessages = {
            "Hey " .. player.Name .. ", what's up?",
            "Hi there " .. player.Name .. "! How's it going?",
            "Hello " .. player.Name .. "! Having fun?",
            "Hey, I was just exploring around. What are you up to, " .. player.Name .. "?"
        }
        self:SendMessage(defaultMessages[math.random(1, #defaultMessages)])
    end
    
    -- Perform a friendly emote
    local friendlyEmotes = {"wave", "point", "dance"}
    self:PerformEmote(friendlyEmotes[math.random(1, #friendlyEmotes)])
    
    -- Stay near the player for a while, responding to their movements
    local interactionStartTime = tick()
    local interactionDuration = 10 -- seconds
    
    while self.IsAIControlled and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and 
          tick() - interactionStartTime < interactionDuration do
        
        local distance = (player.Character.HumanoidRootPart.Position - self.RootPart.Position).Magnitude
        
        -- If player moves too far away, follow them
        if distance > INTERACTION_DISTANCE * 2 then
            self.Humanoid:MoveTo(player.Character.HumanoidRootPart.Position)
        end
        
        -- Randomly face the player for natural interaction
        if math.random() < 0.7 then
            local lookVector = (player.Character.HumanoidRootPart.Position - self.RootPart.Position).Unit
            local lookCFrame = CFrame.lookAt(self.RootPart.Position, self.RootPart.Position + Vector3.new(lookVector.X, 0, lookVector.Z))
            self.RootPart.CFrame = CFrame.new(self.RootPart.Position) * (lookCFrame - lookCFrame.Position)
        end
        
        wait(1 + math.random() * 0.5)
    end
end

-- Explore the environment more thoroughly
function AiController:Explore()
    -- Get points of interest in the game
    local pointsOfInterest = self:FindPointsOfInterest()
    
    if #pointsOfInterest > 0 then
        -- Choose a random point of interest
        local targetPoint = pointsOfInterest[math.random(1, #pointsOfInterest)]
        
        -- Create a path to the point
        local path = PathfindingService:CreatePath({
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true
        })
        
        path:ComputeAsync(self.RootPart.Position, targetPoint)
        
        if path.Status == Enum.PathStatus.Success then
            -- Follow the path
            self:FollowPath(path)
            
            -- Once we arrive, look around
            self:LookAround()
            
            -- Maybe comment on what we found
            if math.random() < 0.7 then
                local explorationComments = {
                    "This area is pretty interesting!",
                    "I like exploring this place.",
                    "Found something cool over here!",
                    "Nice spot to check out.",
                    "Anyone else been here before?"
                }
                self:SendMessage(explorationComments[math.random(1, #explorationComments)])
            end
        else
            -- Fallback to wander if pathfinding fails
            self:Wander()
        end
    else
        -- No points of interest, just wander
        self:Wander()
    end
end

-- Find points of interest in the game
function AiController:FindPointsOfInterest()
    local points = {}
    local position = self.RootPart.Position
    
    -- Look for interesting objects
    local interestingTypes = {
        "Part",
        "Model",
        "SpawnLocation",
        "Seat"
    }
    
    -- Search workspace for potential points of interest
    for _, child in pairs(workspace:GetDescendants()) do
        if table.find(interestingTypes, child.ClassName) and child:IsA("BasePart") then
            local distance = (child.Position - position).Magnitude
            
            -- Only consider points that are not too close or too far
            if distance > 20 and distance < 200 then
                table.insert(points, child.Position)
                
                -- Limit to a reasonable number of points
                if #points >= 10 then
                    break
                end
            end
        end
    end
    
    -- If we couldn't find interesting objects, create some random points
    if #points == 0 then
        for i = 1, 5 do
            local randomOffset = Vector3.new(
                math.random(-100, 100),
                0,
                math.random(-100, 100)
            )
            table.insert(points, position + randomOffset)
        end
    end
    
    return points
end

-- Look around in different directions
function AiController:LookAround()
    local startCFrame = self.RootPart.CFrame
    local lookDirections = {
        Vector3.new(1, 0, 0),
        Vector3.new(0, 0, 1),
        Vector3.new(-1, 0, 0),
        Vector3.new(0, 0, -1)
    }
    
    for _, direction in ipairs(lookDirections) do
        if not self.IsAIControlled then break end
        
        local lookCFrame = CFrame.lookAt(self.RootPart.Position, self.RootPart.Position + direction)
        self.RootPart.CFrame = CFrame.new(self.RootPart.Position) * (lookCFrame - lookCFrame.Position)
        
        wait(0.5 + math.random() * 0.5)
    end
    
    -- Return to original orientation
    self.RootPart.CFrame = startCFrame
end

-- Follow a player for a duration
function AiController:FollowPlayer(player, duration)
    if not player or not player.Character then
        Logger:warn("Cannot follow player: invalid player or character")
        return
    end
    
    local followStartTime = tick()
    local followDuration = duration or 15 -- Default to 15 seconds if not specified
    
    -- Let the player know we're following them
    if math.random() < 0.7 then
        local followMessages = {
            "I'll follow you for a bit, " .. player.Name .. "!",
            "Lead the way, " .. player.Name .. "!",
            "Where are we going, " .. player.Name .. "?",
            "I'll tag along with you!"
        }
        self:SendMessage(followMessages[math.random(1, #followMessages)])
    end
    
    while self.IsAIControlled and self.CurrentAction == "follow" and 
          player.Character and player.Character:FindFirstChild("HumanoidRootPart") and
          tick() - followStartTime < followDuration do
        
        local targetPos = player.Character.HumanoidRootPart.Position
        local currentDistance = (targetPos - self.RootPart.Position).Magnitude
        
        -- Stay at a reasonable following distance
        if currentDistance > INTERACTION_DISTANCE + 2 and currentDistance < 50 then
            -- Calculate a position slightly behind the player
            local playerLookVector = player.Character.HumanoidRootPart.CFrame.LookVector
            local followPos = targetPos - (playerLookVector * INTERACTION_DISTANCE * 0.8)
            
            -- Move to the follow position
            self.Humanoid:MoveTo(followPos)
            
            -- Wait for movement to complete or timeout
            local moveStartTime = tick()
            while tick() - moveStartTime < 2 and self.IsAIControlled and 
                  self.CurrentAction == "follow" and player.Character do
                
                -- Check if we're close enough to the follow position
                if (self.RootPart.Position - followPos).Magnitude < 5 then
                    break
                end
                
                wait(0.1)
            end
        elseif currentDistance >= 50 then
            -- Player moved too far away, stop following
            Logger:warn("Player moved too far away, stopping follow")
            break
        else
            -- We're already at a good distance, just wait
            wait(0.5)
        end
        
        -- Occasionally make a comment while following
        if math.random() < 0.1 then
            local followingComments = {
                "This is cool!",
                "Where are we going?",
                "Nice place!",
                "Anything interesting around here?",
                "Thanks for showing me around!"
            }
            self:SendMessage(followingComments[math.random(1, #followingComments)])
        end
        
        wait(0.5)
    end
    
    -- Let the player know we're done following them
    if math.random() < 0.5 and self.IsAIControlled then
        local endFollowMessages = {
            "I'll explore on my own now. Thanks!",
            "That was fun! I'll check out some other areas.",
            "Thanks for letting me follow you!",
            "I'll see what else is around here."
        }
        self:SendMessage(endFollowMessages[math.random(1, #endFollowMessages)])
    end
end

-- Create and return the instance
local controller = AiController:Initialize()
return controller 

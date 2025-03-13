-- Context Builder Module
-- /LxckStxp/Censura-Applications/LocalPlayer/AI/Modules/ContextBuilder.lua

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local ContextBuilder = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

function ContextBuilder:Initialize(controller)
    self.Controller = controller
    return self
end

-- Get Game Context for Grok with enhanced environmental awareness
function ContextBuilder:GetContext()
    -- Get nearby players with more details
    local nearbyPlayers = {}
    local playerDetails = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (player.Character.HumanoidRootPart.Position - self.Controller.RootPart.Position).Magnitude
            
            if distance <= Config.DETECTION_RADIUS then
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
                
                -- Check if they're spamming (don't interact with spammers)
                if System.State.IgnoredPlayers[player.Name] and System.State.IgnoredPlayers[player.Name] > os.time() then
                    playerInfo.isSpamming = true
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
    local currentState = "You are currently " .. (System.State.CurrentAction or "idle")
    if System.State.CurrentTarget then
        currentState = currentState .. " with target " .. System.State.CurrentTarget
    end
    
    -- Construct context
    local context = "You are a human-like player in Roblox named " .. localPlayer.Name .. ". Decide my next action based on this context:\n\n"
    context = context .. "Game: " .. gameInfo.name .. " (ID: " .. gameInfo.placeId .. "), with " .. gameInfo.playerCount .. " players total.\n"
    context = context .. "Environment: " .. environment .. "\n"
    context = context .. "Current state: " .. currentState .. "\n"
    context = context .. "Nearby players: " .. (next(nearbyPlayers) and table.concat(nearbyPlayers, ", ") or "none") .. "\n"
    
    -- Add note about spammers
    local spammerCount = 0
    for _ in pairs(System.State.IgnoredPlayers) do spammerCount = spammerCount + 1 end
    if spammerCount > 0 then
        context = context .. "Note: Currently ignoring " .. spammerCount .. " player(s) for spam behavior.\n"
    end
    
    context = context .. "Recent chat: "
    
    -- Add recent chat messages
    for _, entry in ipairs(System.State.MessageLog) do
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
            
            if info.isSpamming then
                details = details .. ", currently ignoring due to spam"
            end
            
            context = context .. details
        end
    end
    
    return context
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

return ContextBuilder

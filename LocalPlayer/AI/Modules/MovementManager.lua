-- Movement Manager Module
-- /LxckStxp/Censura-Applications/LocalPlayer/AI/Modules/MovementManager.lua

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

local MovementManager = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

function MovementManager:Initialize(controller)
    self.FailedPathfinds = 0
    self.Controller = controller
    self:StartPositionTracking()
    return self
end

function MovementManager:OnCharacterChanged(controller)
    self.Controller = controller
    self.FailedPathfinds = 0
    self:StartPositionTracking()
end

-- Start tracking positions to detect getting stuck
function MovementManager:StartPositionTracking()
    spawn(function()
        while self.Controller and self.Controller.Character and self.Controller.Character.Parent do
            if self.Controller.RootPart then
                table.insert(System.State.LastPositions, self.Controller.RootPart.Position)
                if #System.State.LastPositions > Config.STUCK_DETECTION.threshold then
                    table.remove(System.State.LastPositions, 1)
                end
                
                -- Check if stuck
                if #System.State.LastPositions >= Config.STUCK_DETECTION.threshold and System.State.CurrentAction then
                    local isStuck = true
                    local referencePos = System.State.LastPositions[1]
                    
                    for i = 2, #System.State.LastPositions do
                        if (System.State.LastPositions[i] - referencePos).Magnitude > Config.STUCK_DETECTION.distance then
                            isStuck = false
                            break
                        end
                    end
                    
                    if isStuck and System.State.IsActive then
                        Logger:warn("AI appears to be stuck, forcing new action")
                        self:ForceNewAction()
                    end
                end
            end
            
            wait(Config.STUCK_DETECTION.interval)
        end
    end)
end

-- Force a new action when stuck
function MovementManager:ForceNewAction()
    System.State.CurrentAction = nil
    System.State.CurrentTarget = nil
    self.FailedPathfinds = 0
    
    -- Jump to try to unstuck
    self.Controller.Humanoid.Jump = true
    
    -- Move in a random direction
    local randomOffset = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
    self.Controller.Humanoid:MoveTo(self.Controller.RootPart.Position + randomOffset)
    
    -- Force a new decision sooner
    System.State.ActionStartTime = tick() - Config.ACTION_TIMEOUT + 2
end

-- Wander with improved pathfinding and obstacle avoidance
function MovementManager:Wander(controller)
    local targetPos = self:GetRandomPosition()
    
    -- Try to find a valid position
    local attempts = 0
    while attempts < 5 do
        local path = PathfindingService:CreatePath({
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true
        })
        
        path:ComputeAsync(controller.RootPart.Position, targetPos)
        
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
    controller.Humanoid:MoveTo(self:GetRandomPosition())
end

-- Get Random Position with terrain awareness
function MovementManager:GetRandomPosition()
    -- Try to find a position on walkable terrain
    local maxDistance = 50
    local minDistance = 10
    local position = self.Controller.RootPart.Position
    
    -- Create a random offset direction
    local angle = math.random() * math.pi * 2
    local distance = math.random(minDistance, maxDistance)
    local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
    
    -- Cast a ray down to find terrain height
    local rayStart = position + offset + Vector3.new(0, 50, 0)
    local rayDirection = Vector3.new(0, -100, 0)
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {self.Controller.Character}
    
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
function MovementManager:FollowPath(path)
    local waypoints = path:GetWaypoints()
    
    -- Skip the first waypoint as it's our current position
    for i = 2, #waypoints do
        if not System.State.IsActive or System.State.CurrentAction ~= "wander" then
            break
        end
        
        local waypoint = waypoints[i]
        
        -- Handle waypoint actions
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            self.Controller.Humanoid.Jump = true
        end
        
        -- Move to the waypoint with some randomness for human-like movement
        local targetPos = waypoint.Position
        
        -- Add slight randomness to movement
        if math.random() < Config.MOVEMENT_RANDOMIZATION then
            local randomOffset = Vector3.new(
                math.random(-2, 2) * 0.1,
                0,
                math.random(-2, 2) * 0.1
            )
            targetPos = targetPos + randomOffset
        end
        
        self.Controller.Humanoid:MoveTo(targetPos)
        
        -- Wait for movement to complete with timeout
        local startTime = tick()
        local reachedWaypoint = false
        
        while not reachedWaypoint and tick() - startTime < 5 and System.State.IsActive do
            -- Check if we're close enough to the waypoint
            if (self.Controller.RootPart.Position - waypoint.Position).Magnitude < 3 then
                reachedWaypoint = true
            end
            
            -- If we're stuck, break out
            if tick() - startTime > 3 and (self.Controller.RootPart.Position - waypoint.Position).Magnitude > 10 then
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
function MovementManager:ApproachPlayer(controller, player)
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        Logger:warn("Cannot approach player: invalid player or character")
        return
    end
    
    System.State.CurrentTarget = player.Name
    local approachStartTime = tick()
    
    while System.State.IsActive and System.State.CurrentAction == "approach" and player.Character and 
          player.Character:FindFirstChild("HumanoidRootPart") and
          tick() - approachStartTime < 30 do
        
        local targetPos = player.Character.HumanoidRootPart.Position
        local currentDistance = (targetPos - controller.RootPart.Position).Magnitude
        
        -- If we're close enough, stop approaching
        if currentDistance <= Config.INTERACTION_DISTANCE then
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
        path:ComputeAsync(controller.RootPart.Position, targetPos)
        
        if path.Status == Enum.PathStatus.Success then
            -- Reset failed pathfinds counter
            self.FailedPathfinds = 0
            
            -- Follow the path
            local waypoints = path:GetWaypoints()
            
            -- Skip the first waypoint
            for i = 2, #waypoints do
                if not System.State.IsActive or System.State.CurrentAction ~= "approach" or
                   not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
                    break
                end
                
                -- Get the current distance to player (which may have moved)
                local updatedTargetPos = player.Character.HumanoidRootPart.Position
                local updatedDistance = (updatedTargetPos - controller.RootPart.Position).Magnitude
                
                -- If we're close enough, stop approaching
                if updatedDistance <= Config.INTERACTION_DISTANCE then
                    break
                end
                
                -- Handle waypoint actions
                if waypoints[i].Action == Enum.PathWaypointAction.Jump then
                    controller.Humanoid.Jump = true
                end
                
                -- Move to the waypoint
                controller.Humanoid:MoveTo(waypoints[i].Position)
                
                -- Wait for movement to complete or timeout
                local waypointStartTime = tick()
                local reachedWaypoint = false
                
                while not reachedWaypoint and tick() - waypointStartTime < 3 and 
                      System.State.IsActive and System.State.CurrentAction == "approach" do
                    
                    -- Check if we're close enough to the waypoint
                    if (controller.RootPart.Position - waypoints[i].Position).Magnitude < 3 then
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
                    local finalDistance = (player.Character.HumanoidRootPart.Position - controller.RootPart.Position).Magnitude
                    if finalDistance > Config.INTERACTION_DISTANCE + 2 then
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
            controller.Humanoid:MoveTo(targetPos)
            wait(1)
        end
        
        wait(0.5)
    end
end

-- Interact with Player with more dynamic behaviors
function MovementManager:InteractWithPlayer(controller, player, message)
    if not player or not player.Character then
        Logger:warn("Cannot interact with player: invalid player or character")
        return
    end
    
    -- First approach the player
    self:ApproachPlayer(controller, player)
    
    -- If we have a message, send it
    if message and message ~= "" then
        System.Modules.ChatManager:SendMessage(message)
    else
        -- Default messages if none provided
        local defaultMessages = {
            "Hey " .. player.Name .. ", what's up?",
            "Hi there " .. player.Name .. "! How's it going?",
            "Hello " .. player.Name .. "! Having fun?",
            "Hey, I was just exploring around. What are you up to, " .. player.Name .. "?"
        }
        System.Modules.ChatManager:SendMessage(defaultMessages[math.random(1, #defaultMessages)])
    end
    
    -- Perform a friendly emote
    local friendlyEmotes = {"wave", "point", "dance"}
    self:PerformEmote(controller, friendlyEmotes[math.random(1, #friendlyEmotes)])
    
    -- Stay near the player for a while, responding to their movements
    local interactionStartTime = tick()
    local interactionDuration = 10 -- seconds
    
    while System.State.IsActive and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and 
          tick() - interactionStartTime < interactionDuration do
        
        local distance = (player.Character.HumanoidRootPart.Position - controller.RootPart.Position).Magnitude
        
        -- If player moves too far away, follow them
        if distance > Config.INTERACTION_DISTANCE * 2 then
            controller.Humanoid:MoveTo(player.Character.HumanoidRootPart.Position)
        end
        
        -- Randomly face the player for natural interaction
        if math.random() < 0.7 then
            local lookVector = (player.Character.HumanoidRootPart.Position - controller.RootPart.Position).Unit
            local lookCFrame = CFrame.lookAt(controller.RootPart.Position, controller.RootPart.Position + Vector3.new(lookVector.X, 0, lookVector.Z))
            controller.RootPart.CFrame = CFrame.new(controller.RootPart.Position) * (lookCFrame - lookCFrame.Position)
        end
        
        wait(1 + math.random() * 0.5)
    end
end

-- Explore the environment more thoroughly
function MovementManager:Explore(controller)
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
        
        path:ComputeAsync(controller.RootPart.Position, targetPoint)
        
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
                System.Modules.ChatManager:SendMessage(explorationComments[math.random(1, #explorationComments)])
            end
        else
            -- Fallback to wander if pathfinding fails
            self:Wander(controller)
        end
    else
        -- No points of interest, just wander
        self:Wander(controller)
    end
end

-- Find points of interest in the game
function MovementManager:FindPointsOfInterest()
    local points = {}
    local position = self.Controller.RootPart.Position
    
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
function MovementManager:LookAround()
    local startCFrame = self.Controller.RootPart.CFrame
    local lookDirections = {
        Vector3.new(1, 0, 0),
        Vector3.new(0, 0, 1),
        Vector3.new(-1, 0, 0),
        Vector3.new(0, 0, -1)
    }
    
    for _, direction in ipairs(lookDirections) do
        if not System.State.IsActive then break end
        
        local lookCFrame = CFrame.lookAt(self.Controller.RootPart.Position, self.Controller.RootPart.Position + direction)
        self.Controller.RootPart.CFrame = CFrame.new(self.Controller.RootPart.Position) * (lookCFrame - lookCFrame.Position)
        
        wait(0.5 + math.random() * 0.5)
    end
    
    -- Return to original orientation
    self.Controller.RootPart.CFrame = startCFrame
end

-- Follow a player for a duration
function MovementManager:FollowPlayer(controller, player, duration)
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
        System.Modules.ChatManager:SendMessage(followMessages[math.random(1, #followMessages)])
    end
    
    while System.State.IsActive and System.State.CurrentAction == "follow" and 
          player.Character and player.Character:FindFirstChild("HumanoidRootPart") and
          tick() - followStartTime < followDuration do
        
        local targetPos = player.Character.HumanoidRootPart.Position
        local currentDistance = (targetPos - controller.RootPart.Position).Magnitude
        
        -- Stay at a reasonable following distance
        if currentDistance > Config.INTERACTION_DISTANCE + 2 and currentDistance < 50 then
            -- Calculate a position slightly behind the player
            local playerLookVector = player.Character.HumanoidRootPart.CFrame.LookVector
            local followPos = targetPos - (playerLookVector * Config.INTERACTION_DISTANCE * 0.8)
            
            -- Move to the follow position
            controller.Humanoid:MoveTo(followPos)
            
            -- Wait for movement to complete or timeout
            local moveStartTime = tick()
            while tick() - moveStartTime < 2 and System.State.IsActive and 
                  System.State.CurrentAction == "follow" and player.Character do
                
                -- Check if we're close enough to the follow position
                if (controller.RootPart.Position - followPos).Magnitude < 5 then
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
            System.Modules.ChatManager:SendMessage(followingComments[math.random(1, #followingComments)])
        end
        
        wait(0.5)
    end
    
    -- Let the player know we're done following them
    if math.random() < 0.5 and System.State.IsActive then
        local endFollowMessages = {
            "I'll explore on my own now. Thanks!",
            "That was fun! I'll check out some other areas.",
            "Thanks for letting me follow you!",
            "I'll see what else is around here."
        }
        System.Modules.ChatManager:SendMessage(endFollowMessages[math.random(1, #endFollowMessages)])
    end
end

-- Perform an emote
function MovementManager:PerformEmote(controller, emoteName)
    local emoteAction = Config.EMOTE_ACTIONS[emoteName:lower()]
    
    if emoteAction then
        if emoteAction == "sit" then
            controller.Humanoid.Sit = true
        elseif emoteAction == "jump" then
            controller.Humanoid.Jump = true
        else
            -- Try to play the emote
            local success, err = pcall(function()
                controller.Humanoid:PlayEmote(emoteAction)
            end)
            
            if not success then
                Logger:warn("Failed to play emote: " .. emoteName .. " - " .. tostring(err))
            end
        end
        
        Logger:info("Performed emote: " .. emoteName)
    else
        -- Try to play it directly
        local success, err = pcall(function()
            controller.Humanoid:PlayEmote(emoteName)
        end)
        
        if not success then
            Logger:warn("Failed to play emote: " .. emoteName .. " - " .. tostring(err))
        end
    end
end

return MovementManager

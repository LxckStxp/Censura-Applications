-- Movement Manager Module
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

local MovementManager = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

-- Configuration
MovementManager.Settings = {
    MaxPathAttempts = 5,
    PathTimeout = 5,
    WanderRadius = { Min = 10, Max = 50 },
    InteractionTimeout = 30,
    FollowUpdateInterval = 1
}

function MovementManager:Initialize(controller)
    self.Controller = controller
    self.FailedPathfinds = 0
    self:StartPositionTracking()
    return self
end

function MovementManager:OnCharacterChanged(controller)
    self.Controller = controller
    self.FailedPathfinds = 0
    self:StartPositionTracking()
end

function MovementManager:StartPositionTracking()
    task.spawn(function()
        while self.Controller and self.Controller.Character do
            if self.Controller.RootPart then
                table.insert(System.State.LastPositions, self.Controller.RootPart.Position)
                if #System.State.LastPositions > Config.STUCK_DETECTION.threshold then
                    table.remove(System.State.LastPositions, 1)
                end
                
                if self:IsStuck() and System.State.IsActive then
                    self:HandleStuckSituation()
                end
            end
            task.wait(Config.STUCK_DETECTION.interval)
        end
    end)
end

function MovementManager:IsStuck()
    if #System.State.LastPositions < Config.STUCK_DETECTION.threshold or not System.State.CurrentAction then
        return false
    end
    
    local reference = System.State.LastPositions[1]
    for _, pos in ipairs(System.State.LastPositions) do
        if (pos - reference).Magnitude > Config.STUCK_DETECTION.distance then
            return false
        end
    end
    return true
end

function MovementManager:HandleStuckSituation()
    Logger:warn("AI stuck detected, attempting recovery")
    self.FailedPathfinds = 0
    System.State.CurrentAction = nil
    System.State.CurrentTarget = nil
    
    self.Controller.Humanoid.Jump = true
    local randomOffset = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
    self.Controller.Humanoid:MoveTo(self.Controller.RootPart.Position + randomOffset)
    System.State.ActionStartTime = tick() - Config.ACTION_TIMEOUT + 2
end

function MovementManager:Wander(controller)
    local targetPos = self:GetRandomPosition()
    local path = self:ComputePath(controller.RootPart.Position, targetPos)
    
    if path then
        self:FollowPath(path)
    else
        Logger:warn("Pathfinding failed after attempts, using direct movement")
        controller.Humanoid:MoveTo(targetPos)
    end
end

function MovementManager:GetRandomPosition()
    local pos = self.Controller.RootPart.Position
    local angle = math.random() * 2 * math.pi
    local distance = math.random(self.Settings.WanderRadius.Min, self.Settings.WanderRadius.Max)
    local offset = Vector3.new(math.cos(angle) * distance, 50, math.sin(angle) * distance)
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {self.Controller.Character}
    
    local rayResult = workspace:Raycast(pos + offset, Vector3.new(0, -100, 0), params)
    return rayResult and rayResult.Position + Vector3.new(0, 3, 0) or pos + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

function MovementManager:ComputePath(startPos, endPos)
    for attempt = 1, self.Settings.MaxPathAttempts do
        local path = PathfindingService:CreatePath({
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true
        })
        
        local success, err = pcall(function()
            path:ComputeAsync(startPos, endPos)
        end)
        
        if success and path.Status == Enum.PathStatus.Success then
            self.FailedPathfinds = 0
            return path
        end
        
        self.FailedPathfinds = self.FailedPathfinds + 1
        Logger:warn("Path computation failed (attempt " .. attempt .. "): " .. (err or "Unknown error"))
        endPos = self:GetRandomPosition() -- Try a new position
    end
    return nil
end

function MovementManager:FollowPath(path)
    local waypoints = path:GetWaypoints()
    for i = 2, #waypoints do
        if not System.State.IsActive or System.State.CurrentAction ~= "wander" then break end
        
        local waypoint = waypoints[i]
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            self.Controller.Humanoid.Jump = true
        end
        
        local targetPos = waypoint.Position + Vector3.new(
            math.random(-2, 2) * Config.MOVEMENT_RANDOMIZATION,
            0,
            math.random(-2, 2) * Config.MOVEMENT_RANDOMIZATION
        )
        
        self.Controller.Humanoid:MoveTo(targetPos)
        if not self:WaitForWaypoint(targetPos) then break end
        
        if i < #waypoints and math.random() < 0.3 then
            task.wait(math.random() * 0.5)
        end
    end
end

function MovementManager:WaitForWaypoint(targetPos)
    local startTime = tick()
    while tick() - startTime < self.Settings.PathTimeout and System.State.IsActive do
        local distance = (self.Controller.RootPart.Position - targetPos).Magnitude
        if distance < 3 then return true end
        if distance > 10 and tick() - startTime > 3 then
            Logger:warn("Stuck while following path")
            return false
        end
        task.wait(0.1)
    end
    return false
end

function MovementManager:ApproachPlayer(controller, player)
    if not self:ValidatePlayer(player) then return end
    
    System.State.CurrentTarget = player.Name
    local startTime = tick()
    
    while System.State.IsActive and System.State.CurrentAction == "approach" and
          self:ValidatePlayer(player) and tick() - startTime < self.Settings.InteractionTimeout do
        local targetPos = player.Character.HumanoidRootPart.Position
        if (targetPos - controller.RootPart.Position).Magnitude <= Config.INTERACTION_DISTANCE then
            Logger:info("Reached player " .. player.Name)
            break
        end
        
        local path = self:ComputePath(controller.RootPart.Position, targetPos)
        if path then
            self:FollowPath(path)
        else
            controller.Humanoid:MoveTo(targetPos)
        end
        task.wait(0.5)
    end
end

function MovementManager:InteractWithPlayer(controller, player, message)
    if not self:ValidatePlayer(player) then return end
    
    self:ApproachPlayer(controller, player)
    if message then
        System.Modules.ChatManager:SendMessage(message)
    end
end

function MovementManager:Explore(controller)
    self:Wander(controller) -- Explore is similar to wander for now
end

function MovementManager:FollowPlayer(controller, player, duration)
    if not self:ValidatePlayer(player) then return end
    
    System.State.CurrentTarget = player.Name
    local startTime = tick()
    
    while System.State.IsActive and System.State.CurrentAction == "follow" and
          self:ValidatePlayer(player) and tick() - startTime < (duration or self.Settings.InteractionTimeout) do
        local targetPos = player.Character.HumanoidRootPart.Position
        local distance = (targetPos - controller.RootPart.Position).Magnitude
        
        if distance > Config.INTERACTION_DISTANCE * 2 then
            local path = self:ComputePath(controller.RootPart.Position, targetPos)
            if path then
                self:FollowPath(path)
            else
                controller.Humanoid:MoveTo(targetPos)
            end
        end
        task.wait(self.Settings.FollowUpdateInterval)
    end
end

function MovementManager:PerformEmote(controller, emoteName)
    local emote = Config.EMOTE_ACTIONS[emoteName:lower()]
    if emote and controller.Humanoid then
        local animation = Instance.new("Animation")
        animation.AnimationId = "rbxassetid://" .. (emote == "wave" and "507770239" or "507771019") -- Example IDs
        local track = controller.Humanoid:LoadAnimation(animation)
        track:Play()
        task.delay(track.Length, function() track:Stop() animation:Destroy() end)
    else
        Logger:warn("Invalid emote or humanoid: " .. tostring(emoteName))
    end
end

function MovementManager:ValidatePlayer(player)
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        Logger:warn("Invalid player or character for movement")
        return false
    end
    return true
end

return MovementManager

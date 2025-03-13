local PathfindingService = game:GetService("PathfindingService")

local MovementManager = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

function MovementManager:Initialize(controller)
    self.Controller = controller
    return self
end

function MovementManager:OnCharacterChanged(controller)
    self.Controller = controller
end

function MovementManager:Wander(controller)
    local pos = controller.RootPart.Position + Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))
    controller.Humanoid:MoveTo(pos)
end

function MovementManager:ApproachPlayer(controller, player)
    if player and player.Character then
        local path = PathfindingService:CreatePath()
        path:ComputeAsync(controller.RootPart.Position, player.Character.HumanoidRootPart.Position)
        if path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()
            for i = 2, #waypoints do
                controller.Humanoid:MoveTo(waypoints[i].Position)
                wait(0.5)
            end
        end
    end
end

return MovementManager

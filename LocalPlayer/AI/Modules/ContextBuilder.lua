local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local ContextBuilder = {}
local System = _G.AiSystem
local Logger = System.Utils.Logger

function ContextBuilder:Initialize(controller)
    self.Controller = controller
    return self
end

function ContextBuilder:GetContext()
    local context = {"You are a player named " .. localPlayer.Name .. " in Roblox."}
    table.insert(context, "Game: " .. game.Name .. " (ID: " .. game.PlaceId .. ")")
    table.insert(context, "State: " .. (System.State.CurrentAction or "idle"))
    
    local players = "Nearby: "
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            local dist = (player.Character.HumanoidRootPart.Position - self.Controller.RootPart.Position).Magnitude
            if dist <= 60 then
                players = players .. player.Name .. " (" .. math.floor(dist) .. " studs), "
            end
        end
    end
    table.insert(context, players:sub(1, -3))
    
    return table.concat(context, "\n")
end

return ContextBuilder

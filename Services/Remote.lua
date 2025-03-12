--[[
  Simple Remote Command Listener
  Allows control of one account via chat commands from another account
  
  Features:
  - Security check to prevent controlling player from running the script
  - Command system for remote player control
  - External script execution capability
]]

-- Services
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")

-- Config
local CONTROLLER_ID = 7886577295
local PREFIX = "!"

-- Security check - Don't run the script if this is the controlling player
local LocalPlayer = Players.LocalPlayer
if LocalPlayer.UserId == CONTROLLER_ID then
    warn("Remote Command Listener: Script terminated - You are the controlling player")
    return -- Exit the script immediately
end

-- Variables
local isFrozen = false
local freezeConnection = nil

-- Command handlers
local Commands = {
    say = function(args)
        local message = table.concat(args, " ")
        if message ~= "" then
            TextChatService.TextChannels.RBXGeneral:SendAsync(message)
        end
    end,
    
    bring = function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player.UserId == CONTROLLER_ID and player.Character and LocalPlayer.Character then
                if player.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame
                end
                break
            end
        end
    end,
    
    kick = function(args)
        local message = table.concat(args, " ")
        if message == "" then message = "Kicked by remote command" end
        pcall(function() LocalPlayer:Kick(message) end)
        pcall(function() game:Shutdown() end)
    end,
    
    freeze = function()
        if isFrozen then return end
        
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
            
            if freezeConnection then freezeConnection:Disconnect() end
            freezeConnection = RunService.Heartbeat:Connect(function()
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                    LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 0
                    LocalPlayer.Character:FindFirstChildOfClass("Humanoid").JumpPower = 0
                end
            end)
            
            isFrozen = true
        end
    end,
    
    unfreeze = function()
        if not isFrozen then return end
        
        if freezeConnection then
            freezeConnection:Disconnect()
            freezeConnection = nil
        end
        
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 16
            LocalPlayer.Character:FindFirstChildOfClass("Humanoid").JumpPower = 50
        end
        
        isFrozen = false
    end,
    
    fling = function()
        if not LocalPlayer.Character then return end
        
        local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
        
        -- Make character lightweight
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0, 0, 0)
            end
        end
        
        -- Apply extreme upward force
        local force = Instance.new("BodyVelocity")
        force.Velocity = Vector3.new(math.random(-100, 100), 2000, math.random(-100, 100))
        force.MaxForce = Vector3.new(999999, 999999, 999999)
        force.Parent = rootPart
        
        -- Add spin
        local spin = Instance.new("BodyAngularVelocity")
        spin.AngularVelocity = Vector3.new(math.random(-30, 30), math.random(-30, 30), math.random(-30, 30))
        spin.MaxTorque = Vector3.new(999999, 999999, 999999)
        spin.Parent = rootPart
        
        -- Clean up
        task.delay(1, function()
            if force and force.Parent then force:Destroy() end
            if spin and spin.Parent then spin:Destroy() end
            
            task.delay(4, function()
                if LocalPlayer.Character then
                    for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0.5, 1, 1)
                        end
                    end
                end
            end)
        end)
    end,
    
    runcode = function(args)
        if #args < 1 then return end
        
        local source = args[1]
        local url
        
        -- Check if GitHub URL or Pastebin ID
        if source:match("github%.com") then
            url = source:gsub("github%.com/(.+)/blob/", "raw.githubusercontent.com/%1/")
        else
            url = "https://pastebin.com/raw/" .. source
        end
        
        -- Get and run code
        pcall(function()
            local code = game:HttpGet(url)
            loadstring(code)()
        end)
    end
}

-- Process chat messages
local function onChatted(player, message)
    -- Only listen to authorized controller
    if player.UserId ~= CONTROLLER_ID then return end
    
    -- Check for command prefix
    if message:sub(1, #PREFIX) ~= PREFIX then return end
    
    -- Parse command
    local content = message:sub(#PREFIX + 1)
    local args = {}
    
    for word in content:gmatch("%S+") do
        table.insert(args, word)
    end
    
    if #args == 0 then return end
    
    -- Get command name and remove it from args
    local commandName = args[1]:lower()
    table.remove(args, 1)
    
    -- Run command if it exists
    if Commands[commandName] then
        pcall(function() Commands[commandName](args) end)
    end
end

-- Connect to players
for _, player in ipairs(Players:GetPlayers()) do
    player.Chatted:Connect(function(message)
        onChatted(player, message)
    end)
end

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        onChatted(player, message)
    end)
end)

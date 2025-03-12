--[[
    LocoManager - Character Movement Enhancement
    Part of CensuraG-Applications
    
    Provides advanced character movement controls including:
    - Walk speed, jump power, hip height adjustment
    - Sophisticated fly mode with smooth controls
    - Noclip functionality
    - Movement presets
    - Step size adjustment
]]

-- Ensure CensuraG is loaded
if not _G.CensuraG then
    warn("LocoManager requires CensuraG to be loaded. Please load CensuraG first.")
    return
end

-- Initialize LocoManager
local LocoManager = {
    Version = "1.0.0",
    FlyActive = false,
    NoclipActive = false,
    FlySpeed = 1.0,
    OriginalValues = {},
    Connections = {},
    Presets = {
        Default = { WalkSpeed = 16, JumpPower = 50, HipHeight = 0, Gravity = 196.2 },
        Sprint = { WalkSpeed = 32, JumpPower = 50, HipHeight = 0, Gravity = 196.2 },
        SuperJump = { WalkSpeed = 16, JumpPower = 120, HipHeight = 0, Gravity = 196.2 },
        Moon = { WalkSpeed = 16, JumpPower = 50, HipHeight = 0, Gravity = 45 },
        Stealth = { WalkSpeed = 8, JumpPower = 25, HipHeight = 0, Gravity = 196.2 },
        Athlete = { WalkSpeed = 24, JumpPower = 70, HipHeight = 0, Gravity = 196.2 }
    }
}

-- Get local player and character
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

-- Store original values
LocoManager.OriginalValues = {
    WalkSpeed = humanoid.WalkSpeed,
    JumpPower = humanoid.JumpPower,
    HipHeight = humanoid.HipHeight,
    Gravity = workspace.Gravity,
    AutoRotate = humanoid.AutoRotate,
    PlatformStand = humanoid.PlatformStand,
    StepHeight = humanoid.MaxSlopeAngle -- Using MaxSlopeAngle as a proxy for step height
}

-- Create the UI window
local window = _G.CensuraG.CreateWindow("LocoManager v" .. LocoManager.Version)
local grid = _G.CensuraG.Components.grid(window.ContentFrame)

-- Add header
grid:AddComponent(_G.CensuraG.Components.textlabel(grid.Instance, "Character Movement Controls"))

-- Basic movement sliders section
grid:AddComponent(_G.CensuraG.Components.textlabel(grid.Instance, "Basic Movement"))

-- Walk Speed Slider
local walkSpeedSlider = _G.CensuraG.Components.slider(
    grid.Instance, 
    "Walk Speed", 
    0, 
    100, 
    humanoid.WalkSpeed, 
    function(value)
        humanoid.WalkSpeed = value
    end
)
grid:AddComponent(walkSpeedSlider)

-- Jump Power Slider
local jumpPowerSlider = _G.CensuraG.Components.slider(
    grid.Instance, 
    "Jump Power", 
    0, 
    250, 
    humanoid.JumpPower, 
    function(value)
        humanoid.JumpPower = value
    end
)
grid:AddComponent(jumpPowerSlider)

-- Hip Height Slider
local hipHeightSlider = _G.CensuraG.Components.slider(
    grid.Instance, 
    "Hip Height", 
    0, 
    10, 
    humanoid.HipHeight, 
    function(value)
        humanoid.HipHeight = value
    end
)
grid:AddComponent(hipHeightSlider)

-- Gravity Slider
local gravitySlider = _G.CensuraG.Components.slider(
    grid.Instance, 
    "Gravity", 
    0, 
    300, 
    workspace.Gravity, 
    function(value)
        workspace.Gravity = value
    end
)
grid:AddComponent(gravitySlider)

-- Step Height/Max Slope Angle Slider
local stepHeightSlider = _G.CensuraG.Components.slider(
    grid.Instance, 
    "Step Height", 
    0, 
    89, 
    humanoid.MaxSlopeAngle, 
    function(value)
        humanoid.MaxSlopeAngle = value
    end
)
grid:AddComponent(stepHeightSlider)

-- Advanced movement section
grid:AddComponent(_G.CensuraG.Components.textlabel(grid.Instance, "Advanced Movement"))

-- Fly mode implementation
function LocoManager:StartFly()
    if self.FlyActive then return end
    
    self.FlyActive = true
    self.OriginalValues.PlatformStand = humanoid.PlatformStand
    self.OriginalValues.AutoRotate = humanoid.AutoRotate
    
    -- Set up for flying
    humanoid.PlatformStand = true
    humanoid.AutoRotate = false
    
    -- Create a BodyVelocity to control movement
    local bodyVelocity = Instance.new("BodyVelocity", hrp)
    bodyVelocity.Name = "LocoManagerFlyForce"
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    
    -- Create a BodyGyro to control rotation
    local bodyGyro = Instance.new("BodyGyro", hrp)
    bodyGyro.Name = "LocoManagerGyro"
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.D = 50
    bodyGyro.P = 5000
    
    -- Main fly control loop
    local camera = workspace.CurrentCamera
    local userInputService = game:GetService("UserInputService")
    local flyConnection
    
    flyConnection = game:GetService("RunService").RenderStepped:Connect(function()
        if not self.FlyActive then
            flyConnection:Disconnect()
            return
        end
        
        -- Update gyro orientation based on camera
        bodyGyro.CFrame = camera.CFrame
        
        -- Calculate movement direction
        local moveDirection = Vector3.new(0, 0, 0)
        
        -- Forward/backward movement (W/S)
        if userInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDirection = moveDirection + camera.CFrame.LookVector
        end
        if userInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDirection = moveDirection - camera.CFrame.LookVector
        end
        
        -- Left/right movement (A/D)
        if userInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDirection = moveDirection - camera.CFrame.RightVector
        end
        if userInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDirection = moveDirection + camera.CFrame.RightVector
        end
        
        -- Up/down movement (Space/LeftControl)
        if userInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDirection = moveDirection + Vector3.new(0, 1, 0)
        end
        if userInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            moveDirection = moveDirection - Vector3.new(0, 1, 0)
        end
        
        -- Normalize movement vector and apply speed
        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit * humanoid.WalkSpeed * self.FlySpeed
        end
        
        -- Apply movement
        bodyVelocity.Velocity = moveDirection
    end)
    
    -- Store the connection for cleanup
    table.insert(self.Connections, flyConnection)
    
    -- Store the body movers for cleanup
    self.FlyBodyVelocity = bodyVelocity
    self.FlyBodyGyro = bodyGyro
end

function LocoManager:StopFly()
    if not self.FlyActive then return end
    
    self.FlyActive = false
    
    -- Restore humanoid properties
    humanoid.PlatformStand = self.OriginalValues.PlatformStand
    humanoid.AutoRotate = self.OriginalValues.AutoRotate
    
    -- Remove body movers
    if self.FlyBodyVelocity then
        self.FlyBodyVelocity:Destroy()
        self.FlyBodyVelocity = nil
    end
    
    if self.FlyBodyGyro then
        self.FlyBodyGyro:Destroy()
        self.FlyBodyGyro = nil
    end
end

-- Noclip implementation
function LocoManager:StartNoclip()
    if self.NoclipActive then return end
    
    self.NoclipActive = true
    
    -- Set up noclip connection
    local noclipConnection = game:GetService("RunService").Stepped:Connect(function()
        if not self.NoclipActive then
            noclipConnection:Disconnect()
            return
        end
        
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)
    
    -- Store the connection for cleanup
    table.insert(self.Connections, noclipConnection)
end

function LocoManager:StopNoclip()
    if not self.NoclipActive then return end
    
    self.NoclipActive = false
    
    -- Restore collision
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if part.Name == "HumanoidRootPart" then
                part.CanCollide = false -- HRP should never collide
            else
                part.CanCollide = true
            end
        end
    end
end

-- Fly Switch
local flySwitch = _G.CensuraG.Components.switch(
    grid.Instance,
    "Fly Mode",
    false,
    function(enabled)
        if enabled then
            LocoManager:StartFly()
        else
            LocoManager:StopFly()
        end
    end
)
grid:AddComponent(flySwitch)

-- Fly Speed Slider
local flySpeedSlider = _G.CensuraG.Components.slider(
    grid.Instance, 
    "Fly Speed Multiplier", 
    0.1, 
    5, 
    LocoManager.FlySpeed, 
    function(value)
        LocoManager.FlySpeed = value
    end
)
grid:AddComponent(flySpeedSlider)

-- Noclip Switch
local noclipSwitch = _G.CensuraG.Components.switch(
    grid.Instance,
    "Noclip Mode",
    false,
    function(enabled)
        if enabled then
            LocoManager:StartNoclip()
        else
            LocoManager:StopNoclip()
        end
    end
)
grid:AddComponent(noclipSwitch)

-- Presets section
grid:AddComponent(_G.CensuraG.Components.textlabel(grid.Instance, "Movement Presets"))

-- Create array of preset names for dropdown
local presetNames = {}
for name, _ in pairs(LocoManager.Presets) do
    table.insert(presetNames, name)
end
table.sort(presetNames) -- Sort alphabetically

-- Preset Dropdown
local presetDropdown = _G.CensuraG.Components.dropdown(
    grid.Instance,
    "Presets",
    presetNames,
    function(option)
        local preset = LocoManager.Presets[option]
        if preset then
            -- Apply preset values
            humanoid.WalkSpeed = preset.WalkSpeed
            humanoid.JumpPower = preset.JumpPower
            humanoid.HipHeight = preset.HipHeight
            workspace.Gravity = preset.Gravity
            
            -- Update sliders
            walkSpeedSlider:SetValue(preset.WalkSpeed, true)
            jumpPowerSlider:SetValue(preset.JumpPower, true)
            hipHeightSlider:SetValue(preset.HipHeight, true)
            gravitySlider:SetValue(preset.Gravity, true)
        end
    end
)
grid:AddComponent(presetDropdown)

-- Reset button
local resetButton = _G.CensuraG.Components.textbutton(
    grid.Instance,
    "Reset All Movement Settings",
    function()
        -- Disable fly and noclip if active
        if LocoManager.FlyActive then
            LocoManager:StopFly()
            flySwitch:SetState(false, true)
        end
        
        if LocoManager.NoclipActive then
            LocoManager:StopNoclip()
            noclipSwitch:SetState(false, true)
        end
        
        -- Reset all values to original
        humanoid.WalkSpeed = LocoManager.OriginalValues.WalkSpeed
        humanoid.JumpPower = LocoManager.OriginalValues.JumpPower
        humanoid.HipHeight = LocoManager.OriginalValues.HipHeight
        workspace.Gravity = LocoManager.OriginalValues.Gravity
        humanoid.MaxSlopeAngle = LocoManager.OriginalValues.StepHeight
        
        -- Update sliders
        walkSpeedSlider:SetValue(LocoManager.OriginalValues.WalkSpeed, true)
        jumpPowerSlider:SetValue(LocoManager.OriginalValues.JumpPower, true)
        hipHeightSlider:SetValue(LocoManager.OriginalValues.HipHeight, true)
        gravitySlider:SetValue(LocoManager.OriginalValues.Gravity, true)
        stepHeightSlider:SetValue(LocoManager.OriginalValues.StepHeight, true)
        
        -- Reset fly speed
        LocoManager.FlySpeed = 1.0
        flySpeedSlider:SetValue(1.0, true)
    end
)
grid:AddComponent(resetButton)

-- Character changed handler
local function handleCharacterAdded(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    hrp = character:WaitForChild("HumanoidRootPart")
    
    -- Update original values for the new character
    LocoManager.OriginalValues = {
        WalkSpeed = humanoid.WalkSpeed,
        JumpPower = humanoid.JumpPower,
        HipHeight = humanoid.HipHeight,
        Gravity = workspace.Gravity,
        AutoRotate = humanoid.AutoRotate,
        PlatformStand = humanoid.PlatformStand,
        StepHeight = humanoid.MaxSlopeAngle
    }
    
    -- Reset fly and noclip states
    if LocoManager.FlyActive then
        LocoManager:StopFly()
        flySwitch:SetState(false, true)
    end
    
    if LocoManager.NoclipActive then
        LocoManager:StopNoclip()
        noclipSwitch:SetState(false, true)
    end
    
    -- Update slider values for the new character
    walkSpeedSlider:SetValue(humanoid.WalkSpeed, true)
    jumpPowerSlider:SetValue(humanoid.JumpPower, true)
    hipHeightSlider:SetValue(humanoid.HipHeight, true)
    gravitySlider:SetValue(workspace.Gravity, true)
    stepHeightSlider:SetValue(humanoid.MaxSlopeAngle, true)
}

-- Connect character added event
player.CharacterAdded:Connect(handleCharacterAdded)

-- Cleanup function
function LocoManager:Cleanup()
    -- Disconnect all connections
    for _, connection in ipairs(self.Connections) do
        if connection.Connected then
            connection:Disconnect()
        end
    end
    self.Connections = {}
    
    -- Stop fly and noclip
    self:StopFly()
    self:StopNoclip()
    
    -- Reset movement values
    if humanoid then
        humanoid.WalkSpeed = self.OriginalValues.WalkSpeed
        humanoid.JumpPower = self.OriginalValues.JumpPower
        humanoid.HipHeight = self.OriginalValues.HipHeight
        humanoid.MaxSlopeAngle = self.OriginalValues.StepHeight
    end
    
    workspace.Gravity = self.OriginalValues.Gravity
}

-- Add to _G for other scripts to access
_G.LocoManager = LocoManager

-- Print success message
print("LocoManager v" .. LocoManager.Version .. " loaded successfully!")

return LocoManager

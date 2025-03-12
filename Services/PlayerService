-- PlayerService.lua
local PlayerService = {}
PlayerService.__index = PlayerService

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CensuraG = _G.CensuraG
local Logger = CensuraG.Logger
local TweenService = game:GetService("TweenService")

-- Player data cache with UI references
PlayerService.Players = {}
PlayerService.PlayerCards = {}
PlayerService.FollowConnections = {}

-- Debounce for UI updates
local updateDebounce = false
local UPDATE_DELAY = 0.5

-- Custom PlayerCard Component
local function CreatePlayerCard(parent, playerData, onClick)
    local theme = CensuraG.Config:GetTheme()
    
    local cardFrame = Instance.new("TextButton")
    cardFrame.Size = UDim2.new(1, -12, 0, 40)
    cardFrame.BackgroundColor3 = theme.SecondaryColor
    cardFrame.BackgroundTransparency = 0.8
    cardFrame.BorderSizePixel = 0
    cardFrame.Text = ""
    cardFrame.Parent = parent
    
    local corner = Instance.new("UICorner", cardFrame)
    corner.CornerRadius = UDim.new(0, CensuraG.Config.Math.CornerRadius)
    
    local avatar = Instance.new("ImageLabel", cardFrame)
    avatar.Size = UDim2.new(0, 30, 0, 30)
    avatar.Position = UDim2.new(0, 5, 0.5, -15)
    avatar.BackgroundTransparency = 1
    avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. playerData.UserId .. "&w=48&h=48"
    
    local nameLabel = Instance.new("TextLabel", cardFrame)
    nameLabel.Size = UDim2.new(1, -50, 1, 0)
    nameLabel.Position = UDim2.new(0, 40, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = playerData.DisplayName
    nameLabel.TextColor3 = theme.TextColor
    nameLabel.Font = theme.Font
    nameLabel.TextSize = 14
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    
    local status = Instance.new("Frame", cardFrame)
    status.Size = UDim2.new(0, 8, 0, 8)
    status.Position = UDim2.new(1, -12, 0.5, -4)
    status.BackgroundColor3 = playerData.IsOnline and theme.EnabledColor or theme.DisabledColor
    local statusCorner = Instance.new("UICorner", status)
    statusCorner.CornerRadius = UDim.new(1, 0)
    
    cardFrame.MouseButton1Click:Connect(onClick)
    
    return {
        Instance = cardFrame,
        Update = function(self, data)
            nameLabel.Text = data.DisplayName
            avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. data.UserId .. "&w=48&h=48"
            status.BackgroundColor3 = data.IsOnline and theme.EnabledColor or theme.DisabledColor
        end,
        Destroy = function(self)
            cardFrame:Destroy()
        end
    }
end

-- Custom PlayerDetailLabel Component
local function CreatePlayerDetailLabel(parent, key, value)
    local theme = CensuraG.Config:GetTheme()
    
    local labelFrame = Instance.new("Frame")
    labelFrame.Size = UDim2.new(1, -12, 0, 20)
    labelFrame.BackgroundTransparency = 1
    labelFrame.Parent = parent
    
    local keyLabel = Instance.new("TextLabel", labelFrame)
    keyLabel.Size = UDim2.new(0.4, 0, 1, 0)
    keyLabel.Position = UDim2.new(0, 5, 0, 0)
    keyLabel.BackgroundTransparency = 1
    keyLabel.Text = key .. ":"
    keyLabel.TextColor3 = theme.TextColor
    keyLabel.Font = theme.Font
    keyLabel.TextSize = 12
    keyLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local valueLabel = Instance.new("TextLabel", labelFrame)
    valueLabel.Size = UDim2.new(0.6, -10, 1, 0)
    valueLabel.Position = UDim2.new(0.4, 5, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = value
    valueLabel.TextColor3 = theme.SecondaryTextColor
    valueLabel.Font = theme.Font
    valueLabel.TextSize = 12
    valueLabel.TextXAlignment = Enum.TextXAlignment.Left
    valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
    
    return {
        Instance = labelFrame,
        Update = function(self, newValue)
            valueLabel.Text = newValue
        end
    }
end

-- Custom Section Header
local function CreateSectionHeader(parent, text)
    local theme = CensuraG.Config:GetTheme()
    
    local headerFrame = Instance.new("Frame")
    headerFrame.Size = UDim2.new(1, -12, 0, 25)
    headerFrame.BackgroundColor3 = theme.PrimaryColor
    headerFrame.BackgroundTransparency = 0.5
    headerFrame.Parent = parent
    
    local corner = Instance.new("UICorner", headerFrame)
    corner.CornerRadius = UDim.new(0, CensuraG.Config.Math.CornerRadius)
    
    local headerLabel = Instance.new("TextLabel", headerFrame)
    headerLabel.Size = UDim2.new(1, -10, 1, 0)
    headerLabel.Position = UDim2.new(0, 5, 0, 0)
    headerLabel.BackgroundTransparency = 1
    headerLabel.Text = text
    headerLabel.TextColor3 = theme.TextColor
    headerLabel.Font = theme.Font
    headerLabel.TextSize = 14
    headerLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    return { Instance = headerFrame }
end

-- Custom Simple Button (No width expansion)
local function CreateSimpleButton(parent, text, callback)
    local theme = CensuraG.Config:GetTheme()
    
    local buttonFrame = Instance.new("TextButton")
    buttonFrame.Size = UDim2.new(0, 80, 0, 30)
    buttonFrame.BackgroundColor3 = theme.AccentColor
    buttonFrame.BackgroundTransparency = 0.6
    buttonFrame.BorderSizePixel = 0
    buttonFrame.Text = text
    buttonFrame.TextColor3 = theme.TextColor
    buttonFrame.Font = theme.Font
    buttonFrame.TextSize = 14
    buttonFrame.Parent = parent
    
    local corner = Instance.new("UICorner", buttonFrame)
    corner.CornerRadius = UDim.new(0, CensuraG.Config.Math.CornerRadius)
    
    local stroke = Instance.new("UIStroke", buttonFrame)
    stroke.Color = theme.TextColor
    stroke.Transparency = 0.8
    stroke.Thickness = 1
    
    -- Simple hover and click effects without width change
    buttonFrame.MouseEnter:Connect(function()
        TweenService:Create(buttonFrame, TweenInfo.new(0.2), {BackgroundTransparency = 0.4}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 0.6}):Play()
    end)
    
    buttonFrame.MouseLeave:Connect(function()
        TweenService:Create(buttonFrame, TweenInfo.new(0.2), {BackgroundTransparency = 0.6}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 0.8}):Play()
    end)
    
    buttonFrame.MouseButton1Down:Connect(function()
        TweenService:Create(buttonFrame, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play()
    end)
    
    buttonFrame.MouseButton1Up:Connect(function()
        TweenService:Create(buttonFrame, TweenInfo.new(0.2), {BackgroundTransparency = 0.4}):Play()
        if callback then callback() end
    end)
    
    return { Instance = buttonFrame }
end

-- Format value for readability
local function FormatValue(key, value)
    if value == nil then return "N/A" end
    if key == "AccountAge" then
        return tostring(value) .. " days"
    elseif key == "LastOnline" then
        return os.date("%Y-%m-%d %H:%M:%S", value)
    elseif key == "HeightScale" or key == "WidthScale" then
        return string.format("%.2f", value)
    elseif key == "HeadColor" then
        return "#" .. value
    elseif type(value) == "boolean" then
        return value and "Yes" or "No"
    else
        return tostring(value)
    end
end

-- Initialize the PlayerService
function PlayerService:Initialize()
    Logger:info("Initializing PlayerService")

    for _, player in ipairs(Players:GetPlayers()) do
        self:CachePlayer(player)
    end

    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerAdded(player)
    end)
    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerRemoving(player)
    end)

    self:CreateMainWindow()
end

-- Cache player data
function PlayerService:CachePlayer(player)
    local userId = player.UserId
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character and character:FindFirstChild("Humanoid")
    local description = humanoid and humanoid:GetAppliedDescription()

    self.Players[userId] = self.Players[userId] or {}
    local data = self.Players[userId]
    data.DisplayName = player.DisplayName
    data.UserName = player.Name
    data.UserId = userId
    data.AccountAge = player.AccountAge
    data.MembershipType = tostring(player.MembershipType)
    data.Team = player.Team and player.Team.Name or "None"
    data.CharacterAppearance = description and {
        HeightScale = description.HeightScale,
        WidthScale = description.WidthScale,
        HeadColor = description.HeadColor:ToHex()
    } or data.CharacterAppearance or nil
    data.IsOnline = true
    data.LastOnline = nil
    data.Character = character

    Logger:info("Updated player data for " .. player.DisplayName .. " (UserId: " .. userId .. ")")
end

-- Handle player joining
function PlayerService:OnPlayerAdded(player)
    self:CachePlayer(player)
    self:UpdatePlayerCard(player.UserId)
end

-- Handle player leaving
function PlayerService:OnPlayerRemoving(player)
    local userId = player.UserId
    if self.Players[userId] then
        self.Players[userId].IsOnline = false
        self.Players[userId].LastOnline = os.time()
        self.Players[userId].Character = nil
        if self.FollowConnections[userId] then
            self.FollowConnections[userId]:Disconnect()
            self.FollowConnections[userId] = nil
        end
        Logger:info(player.DisplayName .. " has left, data cached")
    end
    self:UpdatePlayerCard(userId)
end

-- Create the main window with ScrollingFrame
function PlayerService:CreateMainWindow()
    if self.MainWindow then
        self.MainWindow.Frame:Destroy()
    end

    self.MainWindow = CensuraG.CreateWindow("Player Service")
    self.MainWindow.Frame.Size = UDim2.new(0, 400, 0, 500)
    self.MainWindow.Frame.Position = UDim2.new(0.5, -200, 0.5, -250)

    self.PlayerList = Instance.new("ScrollingFrame")
    self.PlayerList.Size = UDim2.new(1, -12, 1, -36)
    self.PlayerList.Position = UDim2.new(0, 6, 0, 36)
    self.PlayerList.BackgroundTransparency = 1
    self.PlayerList.ScrollBarThickness = 6
    self.PlayerList.ScrollBarImageColor3 = CensuraG.Config:GetTheme().AccentColor
    self.PlayerList.CanvasSize = UDim2.new(0, 0, 0, 0)
    self.PlayerList.Parent = self.MainWindow.Frame

    local listLayout = Instance.new("UIListLayout", self.PlayerList)
    listLayout.Padding = UDim.new(0, 4)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local padding = Instance.new("UIPadding", self.PlayerList)
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 4)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        self.PlayerList.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
    end)

    for userId in pairs(self.Players) do
        self:UpdatePlayerCard(userId)
    end
end

-- Update or create a single player card
function PlayerService:UpdatePlayerCard(userId)
    if not self.PlayerList then return end

    local data = self.Players[userId]
    if not data then return end

    local card = self.PlayerCards[userId]
    if not card then
        card = CreatePlayerCard(self.PlayerList, data, function()
            self:ShowPlayerDetails(data)
        end)
        self.PlayerCards[userId] = card
        card.Instance.LayoutOrder = userId
    else
        card:Update(data)
    end

    if not updateDebounce then
        updateDebounce = true
        task.delay(UPDATE_DELAY, function()
            local listLayout = self.PlayerList:FindFirstChild("UIListLayout")
            if listLayout then
                self.PlayerList.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
            end
            updateDebounce = false
            Logger:info("Player list updated (batched)")
        end)
    end
end

-- Show detailed player info with organized layout
function PlayerService:ShowPlayerDetails(playerData)
    local detailsWindow = CensuraG.CreateWindow(playerData.DisplayName .. " - Details")
    detailsWindow.Frame.Size = UDim2.new(0, 350, 0, 450)
    detailsWindow.Frame.Position = UDim2.new(0.5, -175, 0.5, -225)

    local scrollFrame = Instance.new("ScrollingFrame", detailsWindow.Frame)
    scrollFrame.Size = UDim2.new(1, -12, 1, -96)
    scrollFrame.Position = UDim2.new(0, 6, 0, 36)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = CensuraG.Config:GetTheme().AccentColor
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    local listLayout = Instance.new("UIListLayout", scrollFrame)
    listLayout.Padding = UDim.new(0, 4)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local padding = Instance.new("UIPadding", scrollFrame)
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 4)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)

    -- Player Info Section
    local playerInfoHeader = CreateSectionHeader(scrollFrame, "Player Info")
    playerInfoHeader.Instance.LayoutOrder = 1

    local playerFields = {
        {"Display Name", playerData.DisplayName},
        {"Username", playerData.UserName},
        {"User ID", playerData.UserId},
        {"Account Age", playerData.AccountAge},
        {"Membership", playerData.MembershipType},
        {"Team", playerData.Team},
        {"Online", playerData.IsOnline},
        {"Last Online", playerData.LastOnline}
    }

    for i, field in ipairs(playerFields) do
        local label = CreatePlayerDetailLabel(scrollFrame, field[1], FormatValue(field[1], field[2]))
        label.Instance.LayoutOrder = i + 1
    end

    -- Character Info Section
    if playerData.CharacterAppearance then
        local charInfoHeader = CreateSectionHeader(scrollFrame, "Character Info")
        charInfoHeader.Instance.LayoutOrder = 10

        local charFields = {
            {"Height Scale", playerData.CharacterAppearance.HeightScale},
            {"Width Scale", playerData.CharacterAppearance.WidthScale},
            {"Head Color", playerData.CharacterAppearance.HeadColor}
        }

        for i, field in ipairs(charFields) do
            local label = CreatePlayerDetailLabel(scrollFrame, field[1], FormatValue(field[1], field[2]))
            label.Instance.LayoutOrder = i + 10
        end
    end

    -- Update CanvasSize
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
    end)
    task.delay(0.1, function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
    end)

    -- Button Container
    local buttonFrame = Instance.new("Frame", detailsWindow.Frame)
    buttonFrame.Size = UDim2.new(1, -12, 0, 50)
    buttonFrame.Position = UDim2.new(0, 6, 1, -56)
    buttonFrame.BackgroundTransparency = 1

    local buttonLayout = Instance.new("UIListLayout", buttonFrame)
    buttonLayout.FillDirection = Enum.FillDirection.Horizontal
    buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    buttonLayout.Padding = UDim.new(0, 10)

    -- Teleport Button
    local teleportBtn = CreateSimpleButton(buttonFrame, "Teleport", function()
        local localPlayer = Players.LocalPlayer
        if playerData.IsOnline and playerData.Character and localPlayer.Character then
            localPlayer.Character:MoveTo(playerData.Character.PrimaryPart.Position)
            Logger:info("Teleported to " .. playerData.DisplayName)
        else
            Logger:warn("Cannot teleport: Player offline or no character")
        end
    end)

    -- Copy UserID Button
    local copyBtn = CreateSimpleButton(buttonFrame, "Copy UserID", function()
        setclipboard(tostring(playerData.UserId))
        Logger:info("Copied UserId " .. playerData.UserId .. " to clipboard")
    end)

    -- Follow Switch
    local followSwitch = CensuraG.Components.switch(buttonFrame, "Follow", false, function(state)
        local userId = playerData.UserId
        local localPlayer = Players.LocalPlayer
        if state then
            if playerData.IsOnline and playerData.Character and localPlayer.Character then
                local humanoid = localPlayer.Character:FindFirstChild("Humanoid")
                local targetRoot = playerData.Character.PrimaryPart
                if humanoid and targetRoot then
                    humanoid:MoveTo(targetRoot.Position)
                    local followConnection = game:GetService("RunService").Heartbeat:Connect(function()
                        if playerData.Character and targetRoot and localPlayer.Character then
                            humanoid:MoveTo(targetRoot.Position)
                        else
                            if self.FollowConnections[userId] then
                                self.FollowConnections[userId]:Disconnect()
                                self.FollowConnections[userId] = nil
                            end
                            followSwitch:SetState(false, true)
                        end
                    end)
                    self.FollowConnections[userId] = followConnection
                    Logger:info("Started following " .. playerData.DisplayName)
                end
            else
                Logger:warn("Cannot follow: Player offline or no character")
                followSwitch:SetState(false, true)
            end
        else
            if self.FollowConnections[userId] then
                self.FollowConnections[userId]:Disconnect()
                self.FollowConnections[userId] = nil
                Logger:info("Stopped following " .. playerData.DisplayName)
            end
        end
    end)
    followSwitch.Instance.Size = UDim2.new(0, 100, 0, 30)

    detailsWindow:UpdateSize()
    Logger:info("Showing details for " .. playerData.DisplayName)
end

-- Start the service
PlayerService:Initialize()

return PlayerService

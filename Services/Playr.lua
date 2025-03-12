--[[
    Playr - Player Management UI
    Part of CensuraG-Applications
    
    Depends on:
    - CensuraG UI API
    - PlayrService backend
    
    Features:
    - Player listing with dynamic updates
    - Detailed player information windows
    - Player statistics dashboard
    - Team visualization
    - Player tracking and monitoring
]]

-- Ensure dependencies are loaded
if not _G.CensuraG then
    warn("Playr requires CensuraG to be loaded. Please load CensuraG first.")
    return
end

if not _G.PlayrService then
    --warn("Playr requires PlayrService to be loaded. Please load PlayrService first.")
    --return
  
    print("PlayrService not found. loading now..")
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/LxckStxp/CensuraG-Applications/main/Services/PlayrService.lua"))()
end

-- Initialize Playr UI
local Playr = {
    Version = "1.0.0",
    Windows = {},
    Components = {},
    PlayerDetailWindows = {},
    RefreshInterval = 1, -- Seconds between UI refreshes
    LastRefresh = 0,
    IsActive = true,
    CurrentFilter = "All Players",
    CurrentSort = "Name (A-Z)"
}

-- Create main info window
Playr.Windows.Info = _G.CensuraG.CreateWindow("Playr Info v" .. Playr.Version)
local infoGrid = _G.CensuraG.Components.grid(Playr.Windows.Info.ContentFrame)

-- Create player list window
Playr.Windows.PlayerList = _G.CensuraG.CreateWindow("Player List")
local playerListGrid = _G.CensuraG.Components.grid(Playr.Windows.PlayerList.ContentFrame)

-- Position windows side by side
Playr.Windows.Info.Frame.Position = UDim2.new(0, 50, 0, 50)
Playr.Windows.PlayerList.Frame.Position = UDim2.new(0, 400, 0, 50)

-- Info dashboard section
infoGrid:AddComponent(_G.CensuraG.Components.textlabel(infoGrid.Instance, "Player Dashboard"))

-- Create statistics panel
local statsFrame = Instance.new("Frame")
statsFrame.Size = UDim2.new(1, -12, 0, 120)
statsFrame.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
statsFrame.BackgroundTransparency = 0.8
statsFrame.BorderSizePixel = 0

local statsCorner = Instance.new("UICorner", statsFrame)
statsCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)

-- Player count label
Playr.Components.PlayerCountLabel = Instance.new("TextLabel", statsFrame)
Playr.Components.PlayerCountLabel.Size = UDim2.new(1, -20, 0, 20)
Playr.Components.PlayerCountLabel.Position = UDim2.new(0, 10, 0, 10)
Playr.Components.PlayerCountLabel.BackgroundTransparency = 1
Playr.Components.PlayerCountLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
Playr.Components.PlayerCountLabel.Font = _G.CensuraG.Config:GetTheme().Font
Playr.Components.PlayerCountLabel.TextSize = 14
Playr.Components.PlayerCountLabel.TextXAlignment = Enum.TextXAlignment.Left
Playr.Components.PlayerCountLabel.Text = "Players: 0"

-- Friends count label
Playr.Components.FriendsLabel = Instance.new("TextLabel", statsFrame)
Playr.Components.FriendsLabel.Size = UDim2.new(1, -20, 0, 20)
Playr.Components.FriendsLabel.Position = UDim2.new(0, 10, 0, 35)
Playr.Components.FriendsLabel.BackgroundTransparency = 1
Playr.Components.FriendsLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
Playr.Components.FriendsLabel.Font = _G.CensuraG.Config:GetTheme().Font
Playr.Components.FriendsLabel.TextSize = 14
Playr.Components.FriendsLabel.TextXAlignment = Enum.TextXAlignment.Left
Playr.Components.FriendsLabel.Text = "Friends: 0"

-- Session time label
Playr.Components.SessionLabel = Instance.new("TextLabel", statsFrame)
Playr.Components.SessionLabel.Size = UDim2.new(1, -20, 0, 20)
Playr.Components.SessionLabel.Position = UDim2.new(0, 10, 0, 60)
Playr.Components.SessionLabel.BackgroundTransparency = 1
Playr.Components.SessionLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
Playr.Components.SessionLabel.Font = _G.CensuraG.Config:GetTheme().Font
Playr.Components.SessionLabel.TextSize = 14
Playr.Components.SessionLabel.TextXAlignment = Enum.TextXAlignment.Left
Playr.Components.SessionLabel.Text = "Session Time: 00:00:00"

-- Account age label
Playr.Components.AccountAgeLabel = Instance.new("TextLabel", statsFrame)
Playr.Components.AccountAgeLabel.Size = UDim2.new(1, -20, 0, 20)
Playr.Components.AccountAgeLabel.Position = UDim2.new(0, 10, 0, 85)
Playr.Components.AccountAgeLabel.BackgroundTransparency = 1
Playr.Components.AccountAgeLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
Playr.Components.AccountAgeLabel.Font = _G.CensuraG.Config:GetTheme().Font
Playr.Components.AccountAgeLabel.TextSize = 14
Playr.Components.AccountAgeLabel.TextXAlignment = Enum.TextXAlignment.Left
Playr.Components.AccountAgeLabel.Text = "Avg. Account Age: 0 days"

infoGrid:AddComponent({Instance = statsFrame})

-- Team information section
infoGrid:AddComponent(_G.CensuraG.Components.textlabel(infoGrid.Instance, "Team Information"))

-- Create team panel
local teamFrame = Instance.new("Frame")
teamFrame.Size = UDim2.new(1, -12, 0, 120)
teamFrame.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
teamFrame.BackgroundTransparency = 0.8
teamFrame.BorderSizePixel = 0

local teamCorner = Instance.new("UICorner", teamFrame)
teamCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)

-- Team list container (ScrollingFrame)
Playr.Components.TeamList = Instance.new("ScrollingFrame", teamFrame)
Playr.Components.TeamList.Size = UDim2.new(1, -10, 1, -10)
Playr.Components.TeamList.Position = UDim2.new(0, 5, 0, 5)
Playr.Components.TeamList.BackgroundTransparency = 1
Playr.Components.TeamList.BorderSizePixel = 0
Playr.Components.TeamList.ScrollBarThickness = 6
Playr.Components.TeamList.ScrollBarImageColor3 = _G.CensuraG.Config:GetTheme().AccentColor
Playr.Components.TeamList.ScrollBarImageTransparency = 0.3
Playr.Components.TeamList.CanvasSize = UDim2.new(0, 0, 0, 200)
Playr.Components.TeamList.AutomaticCanvasSize = Enum.AutomaticSize.Y

local teamListLayout = Instance.new("UIListLayout", Playr.Components.TeamList)
teamListLayout.Padding = UDim.new(0, 5)
teamListLayout.SortOrder = Enum.SortOrder.LayoutOrder
teamListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
teamListLayout.VerticalAlignment = Enum.VerticalAlignment.Top

infoGrid:AddComponent({Instance = teamFrame})

-- Configuration section
infoGrid:AddComponent(_G.CensuraG.Components.textlabel(infoGrid.Instance, "Configuration"))

-- Refresh rate slider
local refreshRateSlider = _G.CensuraG.Components.slider(
    infoGrid.Instance,
    "UI Refresh Rate (seconds)",
    0.5,
    5,
    Playr.RefreshInterval,
    function(value)
        Playr.RefreshInterval = value
    end
)
infoGrid:AddComponent(refreshRateSlider)

-- Auto-track teams toggle
local teamTrackSwitch = _G.CensuraG.Components.switch(
    infoGrid.Instance,
    "Auto-Track Teams",
    _G.PlayrService.Config.AutoTrackTeams,
    function(enabled)
        _G.PlayrService.Config.AutoTrackTeams = enabled
        if enabled then
            _G.PlayrService:SetupTeamTracking()
        end
        Playr:RefreshUI()
    end
)
infoGrid:AddComponent(teamTrackSwitch)

-- Auto-track friends toggle
local friendTrackSwitch = _G.CensuraG.Components.switch(
    infoGrid.Instance,
    "Auto-Track Friends",
    _G.PlayrService.Config.AutoTrackFriends,
    function(enabled)
        _G.PlayrService.Config.AutoTrackFriends = enabled
        if enabled then
            for _, player in pairs(_G.PlayrService.Players) do
                player:UpdateFriendStatus()
            end
        end
        Playr:RefreshUI()
    end
)
infoGrid:AddComponent(friendTrackSwitch)

-- Refresh button
local refreshButton = _G.CensuraG.Components.textbutton(
    infoGrid.Instance,
    "Refresh All Data",
    function()
        _G.PlayrService:RefreshAllPlayers()
        Playr:RefreshUI()
    end
)
infoGrid:AddComponent(refreshButton)

-- Player List Window Components
playerListGrid:AddComponent(_G.CensuraG.Components.textlabel(playerListGrid.Instance, "All Players"))

-- Filter options
local filterOptions = {"All Players", "Friends Only", "Tracked Only", "Alive Only", "Dead Only"}
local filterDropdown = _G.CensuraG.Components.dropdown(
    playerListGrid.Instance,
    "Filter",
    filterOptions,
    function(option)
        Playr.CurrentFilter = option
        Playr:RefreshPlayerList()
    end
)
playerListGrid:AddComponent(filterDropdown)

-- Sort options
local sortOptions = {"Name (A-Z)", "Name (Z-A)", "Team", "Account Age", "Join Time", "Distance"}
local sortDropdown = _G.CensuraG.Components.dropdown(
    playerListGrid.Instance,
    "Sort By",
    sortOptions,
    function(option)
        Playr.CurrentSort = option
        Playr:RefreshPlayerList()
    end
)
playerListGrid:AddComponent(sortDropdown)

-- Player list container
local playerListContainer = Instance.new("Frame")
playerListContainer.Size = UDim2.new(1, -12, 0, 300)
playerListContainer.BackgroundTransparency = 1

-- Create scrolling frame for player list
Playr.Components.PlayerList = Instance.new("ScrollingFrame", playerListContainer)
Playr.Components.PlayerList.Size = UDim2.new(1, 0, 1, 0)
Playr.Components.PlayerList.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
Playr.Components.PlayerList.BackgroundTransparency = 0.8
Playr.Components.PlayerList.BorderSizePixel = 0
Playr.Components.PlayerList.ScrollBarThickness = 6
Playr.Components.PlayerList.ScrollBarImageColor3 = _G.CensuraG.Config:GetTheme().AccentColor
Playr.Components.PlayerList.ScrollBarImageTransparency = 0.3
Playr.Components.PlayerList.CanvasSize = UDim2.new(0, 0, 2, 0)
Playr.Components.PlayerList.AutomaticCanvasSize = Enum.AutomaticSize.Y

local listCorner = Instance.new("UICorner", Playr.Components.PlayerList)
listCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)

local listLayout = Instance.new("UIListLayout", Playr.Components.PlayerList)
listLayout.Padding = UDim.new(0, 5)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.VerticalAlignment = Enum.VerticalAlignment.Top

local listPadding = Instance.new("UIPadding", Playr.Components.PlayerList)
listPadding.PaddingTop = UDim.new(0, 5)
listPadding.PaddingBottom = UDim.new(0, 5)
listPadding.PaddingLeft = UDim.new(0, 5)
listPadding.PaddingRight = UDim.new(0, 5)

playerListGrid:AddComponent({Instance = playerListContainer})

-- Add stats row to player list
Playr.Components.PlayerListStats = Instance.new("TextLabel", playerListGrid.Instance)
Playr.Components.PlayerListStats.Size = UDim2.new(1, -12, 0, 20)
Playr.Components.PlayerListStats.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
Playr.Components.PlayerListStats.BackgroundTransparency = 0.8
Playr.Components.PlayerListStats.BorderSizePixel = 0
Playr.Components.PlayerListStats.Text = "Showing 0 players"
Playr.Components.PlayerListStats.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
Playr.Components.PlayerListStats.Font = _G.CensuraG.Config:GetTheme().Font
Playr.Components.PlayerListStats.TextSize = 14

local statsListCorner = Instance.new("UICorner", Playr.Components.PlayerListStats)
statsListCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)

playerListGrid:AddComponent({Instance = Playr.Components.PlayerListStats})

-- Create player entry for the list
function Playr:CreatePlayerEntry(player)
    local entry = Instance.new("Frame")
    entry.Size = UDim2.new(1, -10, 0, 60)
    entry.BackgroundColor3 = _G.CensuraG.Config:GetTheme().PrimaryColor
    entry.BackgroundTransparency = 0.7
    entry.BorderSizePixel = 0
    entry.Name = "PlayerEntry_" .. player.UserId
    
    local entryCorner = Instance.new("UICorner", entry)
    entryCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)
    
    -- Team color indicator
    local teamColor = Instance.new("Frame", entry)
    teamColor.Size = UDim2.new(0, 4, 1, 0)
    teamColor.Position = UDim2.new(0, 0, 0, 0)
    teamColor.BackgroundColor3 = player.TeamColor.Color
    teamColor.BorderSizePixel = 0
    
    -- Avatar image
    local avatar = Instance.new("ImageLabel", entry)
    avatar.Size = UDim2.new(0, 50, 0, 50)
    avatar.Position = UDim2.new(0, 10, 0, 5)
    avatar.BackgroundTransparency = 1
    
    -- Try to get avatar image
    pcall(function()
        avatar.Image = game.Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    end)
    
    -- Avatar circle mask
    local avatarCorner = Instance.new("UICorner", avatar)
    avatarCorner.CornerRadius = UDim.new(1, 0)
    
    -- Player name
    local nameLabel = Instance.new("TextLabel", entry)
    nameLabel.Size = UDim2.new(1, -150, 0, 20)
    nameLabel.Position = UDim2.new(0, 70, 0, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.DisplayName .. " (@" .. player.Name .. ")"
    nameLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Font = _G.CensuraG.Config:GetTheme().Font
    nameLabel.TextSize = 16
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    
    -- Player stats (team, account age)
    local statsLabel = Instance.new("TextLabel", entry)
    statsLabel.Size = UDim2.new(1, -150, 0, 20)
    statsLabel.Position = UDim2.new(0, 70, 0, 25)
    statsLabel.BackgroundTransparency = 1
    
    local teamName = player.Team and player.Team.Name or "No Team"
    local accountAge = player.AccountAge .. " days"
    
    statsLabel.Text = "Team: " .. teamName .. " • Age: " .. accountAge
    statsLabel.TextColor3 = _G.CensuraG.Config:GetTheme().SecondaryTextColor
    statsLabel.TextXAlignment = Enum.TextXAlignment.Left
    statsLabel.Font = _G.CensuraG.Config:GetTheme().Font
    statsLabel.TextSize = 12
    statsLabel.TextTruncate = Enum.TextTruncate.AtEnd
    
    -- Player status (alive/dead, friend status)
    local statusLabel = Instance.new("TextLabel", entry)
    statusLabel.Size = UDim2.new(1, -150, 0, 20)
    statusLabel.Position = UDim2.new(0, 70, 0, 40)
    statusLabel.BackgroundTransparency = 1
    
    local statusText = player.IsAlive and "Alive" or "Dead"
    if player.IsFriend then
        statusText = statusText .. " • Friend"
    end
    if player:HasTag("Tracked") then
        statusText = statusText .. " • Tracked"
    end
    
    statusLabel.Text = statusText
    statusLabel.TextColor3 = player.IsAlive and 
                            _G.CensuraG.Config:GetTheme().EnabledColor or 
                            _G.CensuraG.Config:GetTheme().DisabledColor
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Font = _G.CensuraG.Config:GetTheme().Font
    statusLabel.TextSize = 12
    
    -- Action buttons container
    local actionContainer = Instance.new("Frame", entry)
    actionContainer.Size = UDim2.new(0, 80, 0, 50)
    actionContainer.Position = UDim2.new(1, -85, 0, 5)
    actionContainer.BackgroundTransparency = 1
    
    -- Track button
    local trackButton = Instance.new("TextButton", actionContainer)
    trackButton.Size = UDim2.new(1, 0, 0, 20)
    trackButton.Position = UDim2.new(0, 0, 0, 0)
    trackButton.BackgroundColor3 = player:HasTag("Tracked") and 
                                 _G.CensuraG.Config:GetTheme().EnabledColor or
                                 _G.CensuraG.Config:GetTheme().AccentColor
    trackButton.BackgroundTransparency = 0.7
    trackButton.Text = player:HasTag("Tracked") and "Untrack" or "Track"
    trackButton.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    trackButton.Font = _G.CensuraG.Config:GetTheme().Font
    trackButton.TextSize = 12
    
    local trackCorner = Instance.new("UICorner", trackButton)
    trackCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)
    
    -- Details button
    local detailsButton = Instance.new("TextButton", actionContainer)
    detailsButton.Size = UDim2.new(1, 0, 0, 20)
    detailsButton.Position = UDim2.new(0, 0, 1, -20)
    detailsButton.BackgroundColor3 = _G.CensuraG.Config:GetTheme().AccentColor
    detailsButton.BackgroundTransparency = 0.7
    detailsButton.Text = "Details"
    detailsButton.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    detailsButton.Font = _G.CensuraG.Config:GetTheme().Font
    detailsButton.TextSize = 12
    
    local detailsCorner = Instance.new("UICorner", detailsButton)
    detailsCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)
    
    -- Button interactions
    trackButton.MouseEnter:Connect(function()
        _G.CensuraG.AnimationManager:Tween(trackButton, {BackgroundTransparency = 0.5}, 0.2)
    end)
    
    trackButton.MouseLeave:Connect(function()
        _G.CensuraG.AnimationManager:Tween(trackButton, {BackgroundTransparency = 0.7}, 0.2)
    end)
    
    detailsButton.MouseEnter:Connect(function()
        _G.CensuraG.AnimationManager:Tween(detailsButton, {BackgroundTransparency = 0.5}, 0.2)
    end)
    
    detailsButton.MouseLeave:Connect(function()
        _G.CensuraG.AnimationManager:Tween(detailsButton, {BackgroundTransparency = 0.7}, 0.2)
    end)
    
    -- Track button functionality
    trackButton.MouseButton1Click:Connect(function()
        local isTracked = player:HasTag("Tracked")
        
        if isTracked then
            player:RemoveTag("Tracked")
            trackButton.Text = "Track"
            _G.CensuraG.AnimationManager:Tween(trackButton, {
                BackgroundColor3 = _G.CensuraG.Config:GetTheme().AccentColor
            }, 0.2)
        else
            player:AddTag("Tracked")
            trackButton.Text = "Untrack"
            _G.CensuraG.AnimationManager:Tween(trackButton, {
                BackgroundColor3 = _G.CensuraG.Config:GetTheme().EnabledColor
            }, 0.2)
        end
        
        -- Update status label
        local statusText = player.IsAlive and "Alive" or "Dead"
        if player.IsFriend then
            statusText = statusText .. " • Friend"
        end
        if player:HasTag("Tracked") then
            statusText = statusText .. " • Tracked"
        end
        statusLabel.Text = statusText
    end)
    
    -- Details button functionality
    detailsButton.MouseButton1Click:Connect(function()
        self:OpenPlayerDetails(player)
    end)
    
    -- Hover effect for entry
    entry.MouseEnter:Connect(function()
        _G.CensuraG.AnimationManager:Tween(entry, {BackgroundTransparency = 0.5}, 0.2)
    end)
    
    entry.MouseLeave:Connect(function()
        _G.CensuraG.AnimationManager:Tween(entry, {BackgroundTransparency = 0.7}, 0.2)
    end)
    
    -- Click on entry to open details
    entry.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:OpenPlayerDetails(player)
        end
    end)
    
    return entry
end

-- Create team entry for team list
function Playr:CreateTeamEntry(teamName, teamData)
    local entry = Instance.new("Frame")
    entry.Size = UDim2.new(1, -10, 0, 30)
    entry.BackgroundColor3 = teamData.Color.Color
    entry.BackgroundTransparency = 0.7
    entry.BorderSizePixel = 0
    
    local entryCorner = Instance.new("UICorner", entry)
    entryCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)
    
    -- Team name
    local nameLabel = Instance.new("TextLabel", entry)
    nameLabel.Size = UDim2.new(0.7, -10, 1, 0)
    nameLabel.Position = UDim2.new(0, 10, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = teamName
    nameLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Font = _G.CensuraG.Config:GetTheme().Font
    nameLabel.TextSize = 14
    
    -- Player count
    local countLabel = Instance.new("TextLabel", entry)
    countLabel.Size = UDim2.new(0.3, -10, 1, 0)
    countLabel.Position = UDim2.new(0.7, 0, 0, 0)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = #teamData.Players .. " players"
    countLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    countLabel.TextXAlignment = Enum.TextXAlignment.Right
    countLabel.Font = _G.CensuraG.Config:GetTheme().Font
    countLabel.TextSize = 14
    
    return entry
end

-- Open player details window
function Playr:OpenPlayerDetails(player)
    -- Check if window already exists
    if self.PlayerDetailWindows[player.UserId] then
        -- Window exists, just bring it to front
        -- This would require z-index management which CensuraG may not directly support
        return
    end
    
    -- Create new window
    local detailWindow = _G.CensuraG.CreateWindow(player.DisplayName .. " Details")
    self.PlayerDetailWindows[player.UserId] = detailWindow
    
    -- Position the window
    detailWindow.Frame.Position = UDim2.new(0, 600, 0, 100)
    
    -- Create grid for content
    local detailGrid = _G.CensuraG.Components.grid(detailWindow.ContentFrame)
    
    -- Player header with avatar
    local headerFrame = Instance.new("Frame")
    headerFrame.Size = UDim2.new(1, -12, 0, 80)
    headerFrame.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
    headerFrame.BackgroundTransparency = 0.8
    headerFrame.BorderSizePixel = 0
    
    local headerCorner = Instance.new("UICorner", headerFrame)
    headerCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)
    
    -- Avatar image
    local avatar = Instance.new("ImageLabel", headerFrame)
    avatar.Size = UDim2.new(0, 70, 0, 70)
    avatar.Position = UDim2.new(0, 5, 0, 5)
    avatar.BackgroundTransparency = 1
    
    -- Try to get avatar image
    pcall(function()
        avatar.Image = game.Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    end)
    
    -- Avatar circle mask
    local avatarCorner = Instance.new("UICorner", avatar)
    avatarCorner.CornerRadius = UDim.new(1, 0)
    
    -- Player name (display name + username)
    local nameLabel = Instance.new("TextLabel", headerFrame)
    nameLabel.Size = UDim2.new(1, -85, 0, 25)
    nameLabel.Position = UDim2.new(0, 80, 0, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.DisplayName
    nameLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Font = _G.CensuraG.Config:GetTheme().Font
    nameLabel.TextSize = 18
    
    -- Username
    local usernameLabel = Instance.new("TextLabel", headerFrame)
    usernameLabel.Size = UDim2.new(1, -85, 0, 20)
    usernameLabel.Position = UDim2.new(0, 80, 0, 30)
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Text = "@" .. player.Name
    usernameLabel.TextColor3 = _G.CensuraG.Config:GetTheme().SecondaryTextColor
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Left
    usernameLabel.Font = _G.CensuraG.Config:GetTheme().Font
    usernameLabel.TextSize = 14
    
    -- Status
    local statusLabel = Instance.new("TextLabel", headerFrame)
    statusLabel.Size = UDim2.new(1, -85, 0, 20)
    statusLabel.Position = UDim2.new(0, 80, 0, 55)
    statusLabel.BackgroundTransparency = 1
    
    local statusText = player.IsAlive and "Alive" or "Dead"
    if player.IsFriend then
        statusText = statusText .. " • Friend"
    end
    if player:HasTag("Tracked") then
        statusText = statusText .. " • Tracked"
    end
    
    statusLabel.Text = statusText
    statusLabel.TextColor3 = player.IsAlive and 
                          _G.CensuraG.Config:GetTheme().EnabledColor or 
                          _G.CensuraG.Config:GetTheme().DisabledColor
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Font = _G.CensuraG.Config:GetTheme().Font
    statusLabel.TextSize = 14
    
    detailGrid:AddComponent({Instance = headerFrame})
    
    -- Player details section
    detailGrid:AddComponent(_G.CensuraG.Components.textlabel(detailGrid.Instance, "Player Information"))
    
    -- User ID
    local userIdLabel = _G.CensuraG.Components.textlabel(detailGrid.Instance, "User ID: " .. player.UserId)
    detailGrid:AddComponent(userIdLabel)
    
    -- Account Age
    local accountAgeLabel = _G.CensuraG.Components.textlabel(detailGrid.Instance, "Account Age: " .. player.AccountAge .. " days")
    detailGrid:AddComponent(accountAgeLabel)
    
    -- Team
    local teamLabel = _G.CensuraG.Components.textlabel(detailGrid.Instance, "Team: " .. (player.Team and player.Team.Name or "None"))
    detailGrid:AddComponent(teamLabel)
    
    -- Join Time
    local joinTimeText = os.date("%Y-%m-%d %H:%M:%S", player.JoinTime)
    local joinTimeLabel = _G.CensuraG.Components.textlabel(detailGrid.Instance, "Joined Server: " .. joinTimeText)
    detailGrid:AddComponent(joinTimeLabel)
    
    -- In-game location section
    detailGrid:AddComponent(_G.CensuraG.Components.textlabel(detailGrid.Instance, "In-Game Location"))
    
    -- Position display
    local positionDisplay = Instance.new("TextLabel")
    positionDisplay.Size = UDim2.new(1, -12, 0, 20)
    positionDisplay.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
    positionDisplay.BackgroundTransparency = 0.8
    positionDisplay.BorderSizePixel = 0
    positionDisplay.Text = "Position: N/A (Character not loaded)"
    positionDisplay.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    positionDisplay.Font = _G.CensuraG.Config:GetTheme().Font
    positionDisplay.TextSize = 14
    
    local positionCorner = Instance.new("UICorner", positionDisplay)
    positionCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)
    
    detailGrid:AddComponent({Instance = positionDisplay})
    
    -- Distance from you
    local distanceDisplay = Instance.new("TextLabel")
    distanceDisplay.Size = UDim2.new(1, -12, 0, 20)
    distanceDisplay.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
    distanceDisplay.BackgroundTransparency = 0.8
    distanceDisplay.BorderSizePixel = 0
    distanceDisplay.Text = "Distance from you: N/A"
    distanceDisplay.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
    distanceDisplay.Font = _G.CensuraG.Config:GetTheme().Font
    distanceDisplay.TextSize = 14
    
    local distanceCorner = Instance.new("UICorner", distanceDisplay)
    distanceCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)
    
    detailGrid:AddComponent({Instance = distanceDisplay})
    
    -- Actions section
    detailGrid:AddComponent(_G.CensuraG.Components.textlabel(detailGrid.Instance, "Actions"))
    
    -- Track/Untrack button
    local trackButton = _G.CensuraG.Components.textbutton(
        detailGrid.Instance,
        player:HasTag("Tracked") and "Untrack Player" or "Track Player",
        function()
            local isTracked = player:HasTag("Tracked")
            
            if isTracked then
                player:RemoveTag("Tracked")
                trackButton.Button.Text = "Track Player"
            else
                player:AddTag("Tracked")
                trackButton.Button.Text = "Untrack Player"
            end
            
            -- Update status in header
            local statusText = player.IsAlive and "Alive" or "Dead"
            if player.IsFriend then
                statusText = statusText .. " • Friend"
            end
            if player:HasTag("Tracked") then
                statusText = statusText .. " • Tracked"
            end
            statusLabel.Text = statusText
            
            -- Refresh player list
            self:RefreshPlayerList()
        end
    )
    detailGrid:AddComponent(trackButton)
    
    -- Teleport to player button (if enabled/available)
    local teleportButton = _G.CensuraG.Components.textbutton(
        detailGrid.Instance,
        "Teleport to Player",
        function()
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and 
               game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
            else
                -- Show error message
                local errorLabel = statusLabel:Clone()
                errorLabel.Text = "Cannot teleport - Character not available"
                errorLabel.TextColor3 = _G.CensuraG.Config:GetTheme().DisabledColor
                errorLabel.Parent = detailGrid.Instance
                
                -- Remove after a few seconds
                task.delay(3, function()
                    errorLabel:Destroy()
                end)
            end
        end
    )
    detailGrid:AddComponent(teleportButton)
    
    -- Spectate player button (if enabled/available)
    local spectateButton = _G.CensuraG.Components.textbutton(
        detailGrid.Instance,
        "Spectate Player",
        function()
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local camera = workspace.CurrentCamera
                camera.CameraSubject = player.Character
                camera.CameraType = Enum.CameraType.Custom
                
                -- Add a button to stop spectating
                local stopSpectateButton = _G.CensuraG.Components.textbutton(
                    detailGrid.Instance,
                    "Stop Spectating",
                    function()
                        local localPlayer = game.Players.LocalPlayer
                        if localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid") then
                            camera.CameraSubject = localPlayer.Character.Humanoid
                        end
                        camera.CameraType = Enum.CameraType.Custom
                        stopSpectateButton.Instance:Destroy()
                    end
                )
                detailGrid:AddComponent(stopSpectateButton)
            else
                -- Show error message
                local errorLabel = statusLabel:Clone()
                errorLabel.Text = "Cannot spectate - Character not available"
                errorLabel.TextColor3 = _G.CensuraG.Config:GetTheme().DisabledColor
                errorLabel.Parent = detailGrid.Instance
                
                -- Remove after a few seconds
                task.delay(3, function()
                    errorLabel:Destroy()
                end)
            end
        end
    )
    detailGrid:AddComponent(spectateButton)
    
    -- Add note button
    local addNoteButton = _G.CensuraG.Components.textbutton(
        detailGrid.Instance,
        "Add Note",
        function()
            -- Create note input
            local noteFrame = Instance.new("Frame")
            noteFrame.Size = UDim2.new(1, -12, 0, 80)
            noteFrame.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
            noteFrame.BackgroundTransparency = 0.8
            noteFrame.BorderSizePixel = 0
            
            local noteCorner = Instance.new("UICorner", noteFrame)
            noteCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)
            
            local noteInput = Instance.new("TextBox", noteFrame)
            noteInput.Size = UDim2.new(1, -10, 1, -40)
            noteInput.Position = UDim2.new(0, 5, 0, 5)
            noteInput.BackgroundColor3 = _G.CensuraG.Config:GetTheme().PrimaryColor
            noteInput.BackgroundTransparency = 0.7
            noteInput.BorderSizePixel = 0
            noteInput.Text = player.Notes or ""
            noteInput.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
            noteInput.Font = _G.CensuraG.Config:GetTheme().Font
            noteInput.TextSize = 14
            noteInput.PlaceholderText = "Enter note about player..."
            noteInput.ClearTextOnFocus = false
            noteInput.TextXAlignment = Enum.TextXAlignment.Left
            noteInput.TextYAlignment = Enum.TextYAlignment.Top
            noteInput.TextWrapped = true
            
            local inputCorner = Instance.new("UICorner", noteInput)
            inputCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)
            
            -- Save button
            local saveButton = Instance.new("TextButton", noteFrame)
            saveButton.Size = UDim2.new(0.5, -7.5, 0, 25)
            saveButton.Position = UDim2.new(0, 5, 1, -30)
            saveButton.BackgroundColor3 = _G.CensuraG.Config:GetTheme().EnabledColor
            saveButton.BackgroundTransparency = 0.7
            saveButton.Text = "Save Note"
            saveButton.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
            saveButton.Font = _G.CensuraG.Config:GetTheme().Font
            saveButton.TextSize = 14
            
            local saveCorner = Instance.new("UICorner", saveButton)
            saveCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)
            
            -- Cancel button
            local cancelButton = Instance.new("TextButton", noteFrame)
            cancelButton.Size = UDim2.new(0.5, -7.5, 0, 25)
            cancelButton.Position = UDim2.new(0.5, 2.5, 1, -30)
            cancelButton.BackgroundColor3 = _G.CensuraG.Config:GetTheme().DisabledColor
            cancelButton.BackgroundTransparency = 0.7
            cancelButton.Text = "Cancel"
            cancelButton.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
            cancelButton.Font = _G.CensuraG.Config:GetTheme().Font
            cancelButton.TextSize = 14
            
            local cancelCorner = Instance.new("UICorner", cancelButton)
            cancelCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)
            
            -- Button interactions
            saveButton.MouseEnter:Connect(function()
                _G.CensuraG.AnimationManager:Tween(saveButton, {BackgroundTransparency = 0.5}, 0.2)
            end)
            
            saveButton.MouseLeave:Connect(function()
                _G.CensuraG.AnimationManager:Tween(saveButton, {BackgroundTransparency = 0.7}, 0.2)
            end)
            
            cancelButton.MouseEnter:Connect(function()
                _G.CensuraG.AnimationManager:Tween(cancelButton, {BackgroundTransparency = 0.5}, 0.2)
            end)
            
            cancelButton.MouseLeave:Connect(function()
                _G.CensuraG.AnimationManager:Tween(cancelButton, {BackgroundTransparency = 0.7}, 0.2)
            end)
            
            -- Button functionality
            saveButton.MouseButton1Click:Connect(function()
                player.Notes = noteInput.Text
                noteFrame:Destroy()
                
                -- Show saved note if there is one
                if player.Notes and player.Notes ~= "" then
                    local noteDisplay = Instance.new("TextLabel")
                    noteDisplay.Size = UDim2.new(1, -12, 0, 60)
                    noteDisplay.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
                    noteDisplay.BackgroundTransparency = 0.8
                    noteDisplay.BorderSizePixel = 0
                    noteDisplay.Text = "Note: " .. player.Notes
                    noteDisplay.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
                    noteDisplay.Font = _G.CensuraG.Config:GetTheme().Font
                    noteDisplay.TextSize = 14
                    noteDisplay.TextWrapped = true
                    noteDisplay.TextXAlignment = Enum.TextXAlignment.Left
                    noteDisplay.TextYAlignment = Enum.TextYAlignment.Top
                    
                    local noteDisplayCorner = Instance.new("UICorner", noteDisplay)
                    noteDisplayCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)
                    
                    detailGrid:AddComponent({Instance = noteDisplay})
                end
            end)
            
            cancelButton.MouseButton1Click:Connect(function()
                noteFrame:Destroy()
            end)
            
            detailGrid:AddComponent({Instance = noteFrame})
        end
    )
    detailGrid:AddComponent(addNoteButton)
    
    -- Display existing note if there is one
    if player.Notes and player.Notes ~= "" then
        local noteDisplay = Instance.new("TextLabel")
        noteDisplay.Size = UDim2.new(1, -12, 0, 60)
        noteDisplay.BackgroundColor3 = _G.CensuraG.Config:GetTheme().SecondaryColor
        noteDisplay.BackgroundTransparency = 0.8
        noteDisplay.BorderSizePixel = 0
        noteDisplay.Text = "Note: " .. player.Notes
        noteDisplay.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
        noteDisplay.Font = _G.CensuraG.Config:GetTheme().Font
        noteDisplay.TextSize = 14
        noteDisplay.TextWrapped = true
        noteDisplay.TextXAlignment = Enum.TextXAlignment.Left
        noteDisplay.TextYAlignment = Enum.TextYAlignment.Top
        
        local noteDisplayCorner = Instance.new("UICorner", noteDisplay)
        noteDisplayCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)
        
        detailGrid:AddComponent({Instance = noteDisplay})
    end
    
    -- Set up position update loop
    local updateConnection
    updateConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if not self.IsActive or not detailWindow.Frame.Visible then
            updateConnection:Disconnect()
            return
        end
        
        -- Update position
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local pos = player.Character.HumanoidRootPart.Position
            positionDisplay.Text = string.format("Position: %.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
            
            -- Update distance
            local localPlayer = game.Players.LocalPlayer
            if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local distance = (localPlayer.Character.HumanoidRootPart.Position - pos).Magnitude
                distanceDisplay.Text = string.format("Distance from you: %.1f studs", distance)
            else
                distanceDisplay.Text = "Distance from you: N/A"
            end
        else
            positionDisplay.Text = "Position: N/A (Character not loaded)"
            distanceDisplay.Text = "Distance from you: N/A"
        end
    end)
    
    -- Clean up when window is closed
    detailWindow.MinimizeButton.MouseButton1Click:Connect(function()
        if updateConnection then
            updateConnection:Disconnect()
        end
        self.PlayerDetailWindows[player.UserId] = nil
    end)
end

-- Filter players based on current filter
function Playr:FilterPlayers(players)
    local result = {}
    
    for _, player in ipairs(players) do
        local shouldInclude = true
        
        if self.CurrentFilter == "Friends Only" then
            shouldInclude = player.IsFriend
        elseif self.CurrentFilter == "Tracked Only" then
            shouldInclude = player:HasTag("Tracked")
        elseif self.CurrentFilter == "Alive Only" then
            shouldInclude = player.IsAlive
        elseif self.CurrentFilter == "Dead Only" then
            shouldInclude = not player.IsAlive
        end
        
        if shouldInclude then
            table.insert(result, player)
        end
    end
    
    return result
end

-- Sort players based on current sort option
function Playr:SortPlayers(players)
    local sortFunc
    
    if self.CurrentSort == "Name (A-Z)" then
        sortFunc = function(a, b) return a.Name < b.Name end
    elseif self.CurrentSort == "Name (Z-A)" then
        sortFunc = function(a, b) return a.Name > b.Name end
    elseif self.CurrentSort == "Team" then
        sortFunc = function(a, b)
            local teamA = a.Team and a.Team.Name or "ZZZ" -- Sort players without team last
            local teamB = b.Team and b.Team.Name or "ZZZ"
            return teamA < teamB
        end
    elseif self.CurrentSort == "Account Age" then
        sortFunc = function(a, b) return a.AccountAge > b.AccountAge end
    elseif self.CurrentSort == "Join Time" then
        sortFunc = function(a, b) return a.JoinTime < b.JoinTime end
    elseif self.CurrentSort == "Distance" then
        sortFunc = function(a, b)
            local localPlayer = game.Players.LocalPlayer
            if not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then
                return a.Name < b.Name -- Fall back to name sort if we can't calculate distance
            end
            
            local distA = a:DistanceTo(localPlayer)
            local distB = b:DistanceTo(localPlayer)
            return distA < distB
        end
    else
        -- Default sort
        sortFunc = function(a, b) return a.Name < b.Name end
    end
    
    table.sort(players, sortFunc)
    return players
end

-- Refresh the player list display
function Playr:RefreshPlayerList()
    -- Clear existing entries
    for _, child in ipairs(Playr.Components.PlayerList:GetChildren()) do
        if child:IsA("Frame") and child.Name:match("^PlayerEntry_") then
            child:Destroy()
        end
    end
    
    -- Get all players as array
    local allPlayers = {}
    for _, player in pairs(_G.PlayrService.Players) do
        table.insert(allPlayers, player)
    end
    
    -- Apply filter
    local filteredPlayers = self:FilterPlayers(allPlayers)
    
    -- Apply sort
    local sortedPlayers = self:SortPlayers(filteredPlayers)
    
    -- Create entries for all filtered and sorted players
    for i, player in ipairs(sortedPlayers) do
        local entry = self:CreatePlayerEntry(player)
        entry.LayoutOrder = i
        entry.Parent = Playr.Components.PlayerList
    end
    
    -- Update stats
    local totalPlayers = #allPlayers
    local shownPlayers = #sortedPlayers
    local filterText = self.CurrentFilter ~= "All Players" and " (" .. self.CurrentFilter .. ")" or ""
    
    Playr.Components.PlayerListStats.Text = "Showing " .. shownPlayers .. " of " .. totalPlayers .. " players" .. filterText
end

-- Refresh team list
function Playr:RefreshTeamList()
    -- Clear existing entries
    for _, child in ipairs(Playr.Components.TeamList:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Create entries for all teams
    local i = 0
    for teamName, teamData in pairs(_G.PlayrService.Teams) do
        local entry = self:CreateTeamEntry(teamName, teamData)
        entry.LayoutOrder = i
        entry.Parent = Playr.Components.TeamList
        i = i + 1
    end
    
    -- Add neutral team if there are players without a team
    local neutralPlayers = {}
    for _, player in pairs(_G.PlayrService.Players) do
        if not player.Team then
            table.insert(neutralPlayers, player)
        end
    end
    
    if #neutralPlayers > 0 then
        local neutralTeam = {
            Color = BrickColor.new("Institutional white"),
            Players = neutralPlayers
        }
        
        local entry = self:CreateTeamEntry("No Team", neutralTeam)
        entry.LayoutOrder = i
        entry.Parent = Playr.Components.TeamList
    end
end

-- Format time as HH:MM:SS
function Playr:FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Refresh dashboard statistics
function Playr:RefreshStats()
    local stats = _G.PlayrService:GetStatistics()
    
    -- Update player count
    Playr.Components.PlayerCountLabel.Text = "Players: " .. stats.TotalPlayers .. " (" .. stats.AlivePlayers .. " alive, " .. stats.DeadPlayers .. " dead)"
    
    -- Update friends count
    Playr.Components.FriendsLabel.Text = "Friends: " .. stats.Friends
    
    -- Update session time
    Playr.Components.SessionLabel.Text = "Session Time: " .. self:FormatTime(stats.SessionTime)
    
    -- Update account age
    Playr.Components.AccountAgeLabel.Text = "Avg. Account Age: " .. math.floor(stats.AverageAccountAge) .. " days"
end

-- Main refresh function for all UI elements
function Playr:RefreshUI()
    self:RefreshStats()
    self:RefreshTeamList()
    self:RefreshPlayerList()
    
    -- Update any open detail windows
    for userId, window in pairs(self.PlayerDetailWindows) do
        local player = _G.PlayrService:GetPlayerByUserId(userId)
        if not player then
            -- Player left, close window
            window.Frame:Destroy()
            self.PlayerDetailWindows[userId] = nil
        end
    end
}

-- Initialize UI refresh loop
function Playr:StartRefreshLoop()
    game:GetService("RunService").Heartbeat:Connect(function()
        if not self.IsActive then return end
        
        local currentTime = tick()
        if currentTime - self.LastRefresh >= self.RefreshInterval then
            self:RefreshUI()
            self.LastRefresh = currentTime
        end
    end)
end

-- Connect to PlayrService events
function Playr:ConnectEvents()
    -- Player added/removed events
    _G.PlayrService:ConnectEvent("PlayerAdded", function(player)
        self:RefreshPlayerList()
    end)
    
    _G.PlayrService:ConnectEvent("PlayerRemoving", function(player)
        self:RefreshPlayerList()
        
        -- Close any detail window for this player
        if self.PlayerDetailWindows[player.UserId] then
            self.PlayerDetailWindows[player.UserId].Frame:Destroy()
            self.PlayerDetailWindows[player.UserId] = nil
        end
    end)
    
    -- Player status change events
    _G.PlayrService:ConnectEvent("PlayerDied", function(player)
        self:RefreshPlayerList()
    end)
    
    _G.PlayrService:ConnectEvent("CharacterAdded", function(player)
        self:RefreshPlayerList()
    end)
    
    -- Team changes
    _G.PlayrService:ConnectEvent("TeamChanged", function(player, oldTeam, newTeam)
        self:RefreshTeamList()
        self:RefreshPlayerList()
    end)
    
    -- Friend status changes
    _G.PlayrService:ConnectEvent("FriendStatusChanged", function(player)
        self:RefreshPlayerList()
    end)
    
    -- Tag changes
    _G.PlayrService:ConnectEvent("PlayerTagged", function(player, tag)
        if tag == "Tracked" then
            self:RefreshPlayerList()
        end
    end)
    
    _G.PlayrService:ConnectEvent("PlayerUntagged", function(player, tag)
        if tag == "Tracked" then
            self:RefreshPlayerList()
        end
    end)
}

-- Initialize Playr
function Playr:Initialize()
    self:ConnectEvents()
    self:RefreshUI()
    self:StartRefreshLoop()
    
    _G.Playr = self
    return self
end

-- Start the UI
Playr:Initialize()
print("Playr v" .. Playr.Version .. " initialized successfully!")

return Playr

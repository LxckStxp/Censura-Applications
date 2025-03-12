--[[
    PlayrService - Robust Player Management System Backend
    Part of CensuraG-Applications
    
    Features:
    - Tracks all players joining and leaving the game
    - Maintains a consistent player database with extended player information
    - Provides events for player joining, leaving, and updates
    - Includes player filtering and searching functionality
    - Offers team management and player grouping
    - Exposes a clean API for other applications to use
]]

-- Initialize PlayrService
local PlayrService = {
    Version = "1.0.0",
    Players = {}, -- Database of player objects
    Teams = {}, -- Team tracking
    Friends = {}, -- Friends list
    Events = {}, -- Custom events
    Connections = {}, -- Roblox connections
    Config = {
        AutoTrackTeams = true,
        AutoTrackFriends = true,
        AutoTrackCharacters = true,
        RefreshRate = 5, -- Seconds between automatic refreshes
        MaxHistorySize = 100 -- Max number of events to keep in history
    },
    History = {} -- Event history
}

-- Player class definition
local PlayerClass = {}
PlayerClass.__index = PlayerClass

function PlayerClass.new(player)
    local self = setmetatable({}, PlayerClass)
    
    -- Basic player info
    self.Instance = player
    self.UserId = player.UserId
    self.Name = player.Name
    self.DisplayName = player.DisplayName
    self.TeamColor = player.TeamColor
    self.Neutral = player.Neutral
    self.Team = player.Team
    self.Character = player.Character
    self.RespawnLocation = player.RespawnLocation
    self.AccountAge = player.AccountAge
    
    -- Extended tracking info
    self.JoinTime = os.time()
    self.LastUpdate = os.time()
    self.IsAlive = player.Character ~= nil and player.Character:FindFirstChild("Humanoid") ~= nil and player.Character.Humanoid.Health > 0
    self.IsFriend = false -- Will be updated if friend tracking enabled
    self.Stats = {} -- For custom stats
    self.Tags = {} -- For custom tagging
    self.Notes = "" -- For custom notes
    
    -- Connect character events if auto-tracking enabled
    if PlayrService.Config.AutoTrackCharacters then
        self:ConnectCharacterEvents()
    end
    
    return self
end

function PlayerClass:ConnectCharacterEvents()
    -- Track character added
    local characterAddedConn = self.Instance.CharacterAdded:Connect(function(character)
        self.Character = character
        self.IsAlive = true
        self.LastUpdate = os.time()
        
        -- Create character removed event
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            local diedConn = humanoid.Died:Connect(function()
                self.IsAlive = false
                self.LastUpdate = os.time()
                PlayrService:FireEvent("PlayerDied", self)
            end)
            
            table.insert(PlayrService.Connections, diedConn)
        end
        
        PlayrService:FireEvent("CharacterAdded", self)
    end)
    
    table.insert(PlayrService.Connections, characterAddedConn)
    
    -- Track character removing
    local characterRemovingConn = self.Instance.CharacterRemoving:Connect(function()
        self.IsAlive = false
        self.LastUpdate = os.time()
        PlayrService:FireEvent("CharacterRemoving", self)
    end)
    
    table.insert(PlayrService.Connections, characterRemovingConn)
end

function PlayerClass:Refresh()
    -- Update core properties
    self.TeamColor = self.Instance.TeamColor
    self.Neutral = self.Instance.Neutral
    self.Team = self.Instance.Team
    self.Character = self.Instance.Character
    self.RespawnLocation = self.Instance.RespawnLocation
    self.DisplayName = self.Instance.DisplayName
    
    -- Update extended properties
    self.IsAlive = self.Character ~= nil and 
                  self.Character:FindFirstChild("Humanoid") ~= nil and 
                  self.Character.Humanoid.Health > 0
    
    self.LastUpdate = os.time()
    
    -- Check if friend status needs updating
    if PlayrService.Config.AutoTrackFriends then
        self:UpdateFriendStatus()
    end
    
    return self
end

function PlayerClass:UpdateFriendStatus()
    local localPlayer = game.Players.LocalPlayer
    
    -- Don't check friend status with self
    if self.UserId == localPlayer.UserId then
        self.IsFriend = false
        return
    end
    
    -- Check if friend
    local success, isFriend = pcall(function()
        return localPlayer:IsFriendsWith(self.UserId)
    end)
    
    if success then
        -- Only fire event if status changed
        local statusChanged = self.IsFriend ~= isFriend
        self.IsFriend = isFriend
        
        if statusChanged then
            PlayrService:FireEvent("FriendStatusChanged", self)
        end
    end
end

function PlayerClass:DistanceTo(otherPlayer)
    -- Calculate distance between players if both have characters
    if not self.Character or not self.Character:FindFirstChild("HumanoidRootPart") then
        return math.huge
    end
    
    local otherChar
    if typeof(otherPlayer) == "Instance" and otherPlayer:IsA("Player") then
        otherChar = otherPlayer.Character
    elseif typeof(otherPlayer) == "table" and otherPlayer.Character then
        otherChar = otherPlayer.Character
    else
        return math.huge
    end
    
    if not otherChar or not otherChar:FindFirstChild("HumanoidRootPart") then
        return math.huge
    end
    
    return (self.Character.HumanoidRootPart.Position - otherChar.HumanoidRootPart.Position).Magnitude
end

function PlayerClass:AddTag(tag)
    if not table.find(self.Tags, tag) then
        table.insert(self.Tags, tag)
        PlayrService:FireEvent("PlayerTagged", self, tag)
    end
end

function PlayerClass:RemoveTag(tag)
    local index = table.find(self.Tags, tag)
    if index then
        table.remove(self.Tags, index)
        PlayrService:FireEvent("PlayerUntagged", self, tag)
    end
end

function PlayerClass:HasTag(tag)
    return table.find(self.Tags, tag) ~= nil
end

function PlayerClass:SetStat(statName, value)
    local oldValue = self.Stats[statName]
    self.Stats[statName] = value
    
    if oldValue ~= value then
        PlayrService:FireEvent("PlayerStatChanged", self, statName, oldValue, value)
    end
end

function PlayerClass:GetStat(statName)
    return self.Stats[statName]
end

-- Event system for PlayrService
function PlayrService:CreateEvent(eventName)
    if not self.Events[eventName] then
        self.Events[eventName] = {
            Connections = {}
        }
    end
end

function PlayrService:ConnectEvent(eventName, callback)
    if not self.Events[eventName] then
        self:CreateEvent(eventName)
    end
    
    local connection = {
        Callback = callback,
        Disconnect = function(self)
            local index = table.find(PlayrService.Events[eventName].Connections, self)
            if index then
                table.remove(PlayrService.Events[eventName].Connections, index)
            end
        end,
        Connected = true
    }
    
    table.insert(self.Events[eventName].Connections, connection)
    return connection
end

function PlayrService:FireEvent(eventName, ...)
    -- Add to history
    local historyEntry = {
        Event = eventName,
        Time = os.time(),
        Args = {...}
    }
    
    table.insert(self.History, 1, historyEntry)
    
    -- Trim history if it's too large
    if #self.History > self.Config.MaxHistorySize then
        table.remove(self.History, #self.History)
    end
    
    -- Fire event
    if not self.Events[eventName] then
        self:CreateEvent(eventName)
    end
    
    for _, connection in ipairs(self.Events[eventName].Connections) do
        if connection.Connected then
            -- pcall to prevent errors in callbacks from breaking everything
            pcall(function()
                connection.Callback(...)
            end)
        end
    end
end

-- Main PlayrService functionality
function PlayrService:Initialize()
    -- Initialize standard events
    self:CreateEvent("PlayerAdded")
    self:CreateEvent("PlayerRemoving")
    self:CreateEvent("PlayerDied")
    self:CreateEvent("CharacterAdded")
    self:CreateEvent("CharacterRemoving")
    self:CreateEvent("FriendStatusChanged")
    self:CreateEvent("PlayerTagged")
    self:CreateEvent("PlayerUntagged")
    self:CreateEvent("PlayerStatChanged")
    self:CreateEvent("TeamChanged")
    
    -- Setup tracking for existing players
    for _, player in pairs(game.Players:GetPlayers()) do
        self:AddPlayer(player)
    end
    
    -- Connect player events
    local playerAddedConn = game.Players.PlayerAdded:Connect(function(player)
        self:AddPlayer(player)
    end)
    
    table.insert(self.Connections, playerAddedConn)
    
    local playerRemovingConn = game.Players.PlayerRemoving:Connect(function(player)
        self:RemovePlayer(player)
    end)
    
    table.insert(self.Connections, playerRemovingConn)
    
    -- Set up team tracking if enabled
    if self.Config.AutoTrackTeams then
        self:SetupTeamTracking()
    end
    
    -- Set up periodic refresh
    self:StartRefreshLoop()
    
    return self
end

function PlayrService:AddPlayer(player)
    -- Create new player object
    local playerObj = PlayerClass.new(player)
    self.Players[player.UserId] = playerObj
    
    -- Check if friend
    if self.Config.AutoTrackFriends then
        playerObj:UpdateFriendStatus()
    end
    
    -- Fire event
    self:FireEvent("PlayerAdded", playerObj)
    
    return playerObj
end

function PlayrService:RemovePlayer(player)
    local playerObj = self.Players[player.UserId]
    
    if playerObj then
        -- Fire event before removing
        self:FireEvent("PlayerRemoving", playerObj)
        
        -- Remove from players table
        self.Players[player.UserId] = nil
    end
end

function PlayrService:GetPlayerByUserId(userId)
    return self.Players[userId]
end

function PlayrService:GetPlayerByName(name)
    for _, player in pairs(self.Players) do
        if player.Name:lower() == name:lower() or player.DisplayName:lower() == name:lower() then
            return player
        end
    end
    return nil
end

function PlayrService:GetPlayersByTag(tag)
    local result = {}
    for _, player in pairs(self.Players) do
        if player:HasTag(tag) then
            table.insert(result, player)
        end
    end
    return result
end

function PlayrService:GetPlayersByTeam(team)
    local result = {}
    for _, player in pairs(self.Players) do
        if player.Team == team then
            table.insert(result, player)
        end
    end
    return result
end

function PlayrService:GetPlayersSorted(sortFunc)
    local result = {}
    
    -- Copy all players to result table
    for _, player in pairs(self.Players) do
        table.insert(result, player)
    end
    
    -- Sort using provided function or default to name sort
    sortFunc = sortFunc or function(a, b) return a.Name < b.Name end
    table.sort(result, sortFunc)
    
    return result
end

function PlayrService:GetNearestPlayer(position)
    local nearestPlayer = nil
    local shortestDistance = math.huge
    
    -- If position is a player or player object, use their position
    if typeof(position) == "Instance" and position:IsA("Player") and position.Character then
        position = position.Character.HumanoidRootPart.Position
    elseif typeof(position) == "table" and position.Character and position.Character:FindFirstChild("HumanoidRootPart") then
        position = position.Character.HumanoidRootPart.Position
    end
    
    -- Ensure position is a Vector3
    if typeof(position) ~= "Vector3" then
        position = game.Players.LocalPlayer.Character and 
                  game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and
                  game.Players.LocalPlayer.Character.HumanoidRootPart.Position or
                  Vector3.new(0, 0, 0)
    end
    
    for _, player in pairs(self.Players) do
        -- Skip local player
        if player.UserId == game.Players.LocalPlayer.UserId then
            continue
        end
        
        -- Skip players without characters
        if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
            continue
        end
        
        local distance = (player.Character.HumanoidRootPart.Position - position).Magnitude
        if distance < shortestDistance then
            shortestDistance = distance
            nearestPlayer = player
        end
    end
    
    return nearestPlayer, shortestDistance
end

function PlayrService:SetupTeamTracking()
    -- Track existing teams
    for _, team in pairs(game:GetService("Teams"):GetTeams()) do
        self.Teams[team.Name] = {
            Instance = team,
            Color = team.TeamColor,
            Players = {}
        }
    end
    
    -- Update team player lists
    self:RefreshTeams()
    
    -- Connect team events
    local teamCreatedConn = game:GetService("Teams").TeamCreated:Connect(function(team)
        self.Teams[team.Name] = {
            Instance = team,
            Color = team.TeamColor,
            Players = {}
        }
        self:RefreshTeams()
    end)
    
    table.insert(self.Connections, teamCreatedConn)
    
    local teamRemovedConn = game:GetService("Teams").TeamRemoved:Connect(function(team)
        self.Teams[team.Name] = nil
        self:RefreshTeams()
    end)
    
    table.insert(self.Connections, teamRemovedConn)
    
    -- Connect player team change events
    local playerTeamChangeConn = game.Players.PlayerAdded:Connect(function(player)
        player:GetPropertyChangedSignal("Team"):Connect(function()
            local playerObj = self:GetPlayerByUserId(player.UserId)
            if playerObj then
                local oldTeam = playerObj.Team
                playerObj:Refresh()
                self:FireEvent("TeamChanged", playerObj, oldTeam, playerObj.Team)
                self:RefreshTeams()
            end
        end)
    end)
    
    table.insert(self.Connections, playerTeamChangeConn)
    
    -- Connect existing players
    for _, player in pairs(game.Players:GetPlayers()) do
        player:GetPropertyChangedSignal("Team"):Connect(function()
            local playerObj = self:GetPlayerByUserId(player.UserId)
            if playerObj then
                local oldTeam = playerObj.Team
                playerObj:Refresh()
                self:FireEvent("TeamChanged", playerObj, oldTeam, playerObj.Team)
                self:RefreshTeams()
            end
        end)
    end
end

function PlayrService:RefreshTeams()
    -- Clear current team player lists
    for teamName, team in pairs(self.Teams) do
        team.Players = {}
    end
    
    -- Assign players to teams
    for _, player in pairs(self.Players) do
        if player.Team and self.Teams[player.Team.Name] then
            table.insert(self.Teams[player.Team.Name].Players, player)
        end
    end
end

function PlayrService:StartRefreshLoop()
    -- Set up periodic refresh of all players
    local refreshConn = game:GetService("RunService").Heartbeat:Connect(function()
        if not self._lastRefresh or (os.time() - self._lastRefresh) >= self.Config.RefreshRate then
            self:RefreshAllPlayers()
            self._lastRefresh = os.time()
        end
    end)
    
    table.insert(self.Connections, refreshConn)
end

function PlayrService:RefreshAllPlayers()
    for _, player in pairs(self.Players) do
        player:Refresh()
    end
    
    if self.Config.AutoTrackTeams then
        self:RefreshTeams()
    end
end

function PlayrService:GetPlayerCount()
    local count = 0
    for _ in pairs(self.Players) do
        count = count + 1
    end
    return count
end

function PlayrService:GetFriendCount()
    local count = 0
    for _, player in pairs(self.Players) do
        if player.IsFriend then
            count = count + 1
        end
    end
    return count
end

function PlayrService:GetStatistics()
    local stats = {
        TotalPlayers = self:GetPlayerCount(),
        Friends = self:GetFriendCount(),
        Teams = {},
        AlivePlayers = 0,
        DeadPlayers = 0,
        AverageAccountAge = 0,
        OldestPlayer = nil,
        NewestPlayer = nil,
        SessionTime = os.time() - (self._initTime or os.time())
    }
    
    local totalAge = 0
    local oldestAge = 0
    local newestAge = math.huge
    
    for _, player in pairs(self.Players) do
        -- Count alive/dead
        if player.IsAlive then
            stats.AlivePlayers = stats.AlivePlayers + 1
        else
            stats.DeadPlayers = stats.DeadPlayers + 1
        end
        
        -- Calculate account age stats
        totalAge = totalAge + player.AccountAge
        
        if player.AccountAge > oldestAge then
            oldestAge = player.AccountAge
            stats.OldestPlayer = player
        end
        
        if player.AccountAge < newestAge then
            newestAge = player.AccountAge
            stats.NewestPlayer = player
        end
        
        -- Count teams
        if player.Team then
            local teamName = player.Team.Name
            stats.Teams[teamName] = (stats.Teams[teamName] or 0) + 1
        end
    end
    
    -- Calculate average age
    if stats.TotalPlayers > 0 then
        stats.AverageAccountAge = totalAge / stats.TotalPlayers
    end
    
    return stats
end

function PlayrService:Cleanup()
    -- Disconnect all connections
    for _, connection in ipairs(self.Connections) do
        if typeof(connection) == "RBXScriptConnection" and connection.Connected then
            connection:Disconnect()
        elseif typeof(connection) == "table" and connection.Disconnect then
            connection:Disconnect()
        end
    end
    
    self.Connections = {}
    
    -- Clear events
    for eventName, event in pairs(self.Events) do
        event.Connections = {}
    end
    
    -- Clear player data
    self.Players = {}
    self.Teams = {}
    
    print("PlayrService cleaned up successfully")
end

-- Initialize and expose the service
PlayrService._initTime = os.time()
PlayrService:Initialize()
_G.PlayrService = PlayrService

return PlayrService

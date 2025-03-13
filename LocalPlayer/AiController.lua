local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

if not _G.CensuraG then error("CensuraG not initialized.") end

local Logger, Methods = _G.CensuraG.Logger, _G.CensuraG.Methods
local lp = Players.LocalPlayer

local AI = {__index = AI}
local CFG = {
    URL = "http://127.0.0.1:5000/webhook",
    MAX_MSG = 180,
    MSG_DELAY = 1,
    DEC_INTERVAL = 10,
    TYPING = {min = 0.05, max = 0.12},
    MOVE_RAND = 0.3,
    INT_DIST = 6,
    DET_RADIUS = 60,
    CHAT_MEM = 15,
    ACT_TIMEOUT = 30,
    RATE_LIMIT = 2
}

function AI.new()
    local self = setmetatable({
        On = false,
        Log = {},
        LastMsg = 0,
        Act = nil,
        ActTime = 0,
        Tgt = nil,
        Path = nil,
        Dec = nil,
        Pos = {},
        Emotes = {
            wave = function(s) s.Humanoid:PlayEmote("wave") end,
            dance = function(s) s.Humanoid:PlayEmote("dance") end,
            laugh = function(s) s.Humanoid:PlayEmote("laugh") end,
            point = function(s) s.Humanoid:PlayEmote("point") end,
            sit = function(s) s.Humanoid.Sit = true end,
            jump = function(s) s.Humanoid.Jump = true end
        }
    }, AI)
    
    self.Char = lp.Character or lp.CharacterAdded:Wait()
    self.Humanoid = self.Char:WaitForChild("Humanoid")
    self.Root = self.Char:WaitForChild("HumanoidRootPart")
    self:SetupUI():SetupEvents()
    spawn(function() self:TrackPos() end)
    Logger:info("AI initialized")
    return self
end

function AI:SetupUI()
    local w = _G.CensuraG.CreateWindow("AI Control")
    w.Frame.Position = UDim2.new(0, 100, 0, 100)
    w:SetSize(300, 350)
    local g = Methods:CreateGrid(w.ContentFrame)
    
    self.Toggle = Methods:CreateSwitch(g.Instance, "Enable AI", false, function(s) self:Toggle(s) end)
    g:AddComponent(self.Toggle)
    g:AddComponent(Methods:CreateLabel(g.Instance, "Settings"))
    self.IntSlide = Methods:CreateSlider(g.Instance, "Decision Interval", 2, 15, CFG.DEC_INTERVAL, function(v) CFG.DEC_INTERVAL = v end)
    self.RadSlide = Methods:CreateSlider(g.Instance, "Detection Radius", 20, 100, CFG.DET_RADIUS, function(v) CFG.DET_RADIUS = v end)
    self.Stat = Methods:CreateLabel(g.Instance, "Status: Idle")
    self.ActLbl = Methods:CreateLabel(g.Instance, "Action: None")
    self.TgtLbl = Methods:CreateLabel(g.Instance, "Target: None")
    g:AddComponent(self.IntSlide):AddComponent(self.RadSlide):AddComponent(self.Stat):AddComponent(self.ActLbl):AddComponent(self.TgtLbl)
    g:AddComponent(Methods:CreateLabel(g.Instance, "Manual"))
    g:AddComponent(Methods:CreateButton(g.Instance, "Wander", function() if self.On then self:Wander() self:Update("wander") end end))
    g:AddComponent(Methods:CreateButton(g.Instance, "Say", function()
        if self.On then
            local m = {"Hey all!", "What's up?", "Exploring!", "Cool place!", "How's it going?"}[math.random(5)]
            self:Say(m)
            self:Update("say", nil, m)
        end
    end))
    _G.CensuraG.SetTheme("Cyberpunk")
    return self
end

function AI:Update(a, t, m)
    self.Stat:SetText("Status: " .. (self.On and "Active" or "Idle"))
    self.ActLbl:SetText("Action: " .. (a or "None"))
    self.TgtLbl:SetText("Target: " .. (t or "None"))
    if a then Logger:info(("AI: %s%s%s"):format(a, t and " → "..t or "", m and " | "..m or "")) end
end

function AI:Toggle(s)
    self.On = s
    if s then
        self.ActTime = tick()
        spawn(function() self:Run() end)
        self:Update("Starting")
    else
        self.Humanoid:MoveTo(self.Root.Position)
        self:Update("Stopped")
    end
    Logger:info("AI " .. (s and "on" or "off"))
end

function AI:SetupEvents()
    for _, p in pairs(Players:GetPlayers()) do if p ~= lp then self:ChatHook(p) end end
    Players.PlayerAdded:Connect(function(p) self:ChatHook(p) end)
    if TextChatService.MessageReceived then
        TextChatService.MessageReceived:Connect(function(m)
            local s = m.TextSource
            if s and s.UserId ~= lp.UserId then
                local p = Players:GetPlayerByUserId(s.UserId)
                if p then self:LogMsg(p.Name, m.Text) if self.On and self:ShouldReply(m.Text, p.Name) then self:Ask(m.Text, p.Name) end end
            end
        end)
    end
    lp.CharacterAdded:Connect(function(c)
        self.Char, self.Humanoid, self.Root = c, c:WaitForChild("Humanoid"), c:WaitForChild("HumanoidRootPart")
        self.Act, self.Tgt, self.Path, self.Pos = nil, nil, nil, {}
        spawn(function() self:TrackPos() end)
    end)
    return self
end

function AI:ChatHook(p) p.Chatted:Connect(function(m) self:LogMsg(p.Name, m) if self.On and self:ShouldReply(m, p.Name) then self:Ask(m, p.Name) end end) end

function AI:ShouldReply(m, s)
    if m:lower():find(lp.Name:lower()) then return true end
    local p = Players:FindFirstChild(s)
    return p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and 
           (p.Character.HumanoidRootPart.Position - self.Root.Position).Magnitude <= CFG.DET_RADIUS * 0.7 or math.random() < 0.3
end

function AI:TrackPos()
    while self.Char do
        if self.Root then
            table.insert(self.Pos, self.Root.Position)
            if #self.Pos > 3 then table.remove(self.Pos, 1) end
            if #self.Pos == 3 and self.Act and self:IsStuck() then
                Logger:warn("Stuck! Forcing new action")
                self:Reset()
            end
        end
        wait(2)
    end
end

function AI:IsStuck()
    local r = self.Pos[1]
    for i = 2, #self.Pos do if (self.Pos[i] - r).Magnitude > 1 then return false end end
    return true
end

function AI:Reset()
    self.Act, self.Tgt, self.Path = nil, nil, nil
    self.Humanoid.Jump = true
    self.Humanoid:MoveTo(self.Root.Position + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10)))
    self.ActTime = tick() - CFG.ACT_TIMEOUT + 2
end

function AI:LogMsg(s, m) table.insert(self.Log, {sender = s, message = m, time = os.time()}) if #self.Log > CFG.CHAT_MEM then table.remove(self.Log, 1) end end

function AI:Say(m)
    if not m or tick() - self.LastMsg < CFG.RATE_LIMIT then return end
    local c = TextChatService.TextChannels and TextChatService.TextChannels.RBXGeneral
    if not c then return end
    for _, t in pairs(self:Chunk(m)) do
        spawn(function()
            wait(#t * math.random(CFG.TYPING.min, CFG.TYPING.max))
            c:SendAsync(t)
            self.LastMsg = tick()
        end)
        wait(CFG.MSG_DELAY)
    end
end

function AI:Chunk(m)
    local r = {}
    while #m > 0 do
        if #m <= CFG.MAX_MSG then table.insert(r, m) break end
        local c = m:sub(1, CFG.MAX_MSG)
        local b = c:match(".*()%.%s") or c:find("%s[^%s]*$") or CFG.MAX_MSG + 1
        table.insert(r, m:sub(1, b - 1))
        m = m:sub(b):match("^%s*(.-)%s*$") or ""
    end
    return r
end

function AI:Run()
    while self.On do
        if not self.Act or (tick() - self.ActTime > (self.Dec and self.Dec.duration or CFG.ACT_TIMEOUT)) then
            local d = self:Call(self:Context())
            if d then self.Dec, self.ActTime = d, tick() self:Do(d) else self:Say("Chilling here!") self.ActTime = tick() end
        end
        wait(CFG.DEC_INTERVAL * (0.8 + math.random() * 0.4))
    end
end

function AI:Context()
    local p, d = {}, {}
    for _, pl in pairs(Players:GetPlayers()) do
        if pl ~= lp and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (pl.Character.HumanoidRootPart.Position - self.Root.Position).Magnitude
            if dist <= CFG.DET_RADIUS then
                table.insert(p, ("%s (%d studs)"):format(pl.Name, math.floor(dist)))
                table.insert(d, {name = pl.Name, dist = math.floor(dist), moving = pl.Character.Humanoid.MoveDirection.Magnitude > 0.1})
            end
        end
    end
    local c = ("You are %s in Roblox. Decide my next action:\nGame: %s (ID: %d), %d players\nEnv: %s\nState: %s%s\nNearby: %s\nChat:"):format(
        lp.Name, game.Name, game.PlaceId, #Players:GetPlayers(), self:Env(), self.Act or "idle", self.Tgt and " → "..self.Tgt or "", p[1] and table.concat(p, ", ") or "none"
    )
    for _, e in pairs(self.Log) do c = c .. ("\n[%s - %ds ago]: %s"):format(e.sender, os.time() - e.time, e.message) end
    if #d > 0 then c = c .. "\n\nPlayers:" for _, i in pairs(d) do c = c .. ("\n- %s: %d studs, %s"):format(i.name, i.dist, i.moving and "moving" or "still") end end
    return c
end

function AI:Env()
    local pos, r = self.Root.Position, RaycastParams.new()
    r.FilterType = Enum.RaycastFilterType.Blacklist
    r.FilterDescendantsInstances = {self.Char}
    local dirs = {Vector3.new(1,0,0), Vector3.new(-1,0,0), Vector3.new(0,0,1), Vector3.new(0,0,-1), Vector3.new(0,1,0), Vector3.new(0,-1,0)}
    local o, indoor = {}, true
    for _, d in pairs(dirs) do
        local hit = workspace:Raycast(pos, d * 50, r)
        if hit and hit.Instance.Name ~= "Terrain" and not table.find(o, hit.Instance.Name) then table.insert(o, hit.Instance.Name) end
        if not hit and d.Y == 0 then indoor = false end
    end
    local g = workspace:Raycast(pos, Vector3.new(0,-10,0), r)
    return ("%s on %s%s"):format(indoor and "Indoors" or "Outdoors", g and (g.Instance.Name == "Terrain" and "terrain" or g.Instance.Name) or "unknown", #o > 0 and ", near "..table.concat(o, ", ") or "")
end

function AI:Ask(m, s)
    local d = self:Call(self:Context() .. "\nFrom " .. s .. ": " .. m)
    if d then self.Dec, self.ActTime = d, tick() self:Do(d) else self:Say("Hey " .. s .. ", what?") end
end

function AI:Call(m)
    local b = HttpService:JSONEncode({message = m, player_name = lp.Name, game_id = game.PlaceId})
    local s, r = pcall(function()
        local res = HttpService:RequestAsync({Url = CFG.URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = b})
        return res.Success and HttpService:JSONDecode(res.Body) or error(res.StatusCode .. " - " .. res.StatusMessage)
    end)
    if s and r.action then return r end
    Logger:error("Webhook fail: " .. tostring(r))
    return nil
end

function AI:Do(d)
    self.Act, self.Tgt = d.action, d.target
    self:Update(d.action, d.target, d.message)
    if d.action == "wander" then self:Wander()
    elseif d.action == "approach" and d.target then self:Approach(Players:FindFirstChild(d.target))
    elseif d.action == "interact" and d.target then self:Interact(Players:FindFirstChild(d.target), d.message)
    elseif d.action == "say" and d.message then self:Say(d.message)
    elseif d.action == "emote" and d.message then self.Emote(d.message)
    elseif d.action == "explore" then self:Explore()
    elseif d.action == "follow" and d.target then self:Follow(Players:FindFirstChild(d.target), d.duration or 5)
    end
end

function AI:Wander()
    local p = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true})
    p:ComputeAsync(self.Root.Position, self:RandPos())
    if p.Status == Enum.PathStatus.Success then self:MovePath(p) else self.Humanoid:MoveTo(self:RandPos()) end
end

function AI:RandPos()
    local pos = self.Root.Position
    local a, d = math.random() * 2 * math.pi, math.random(10, 50)
    local o = Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
    local r = workspace:Raycast(pos + o + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0), RaycastParams.new{FilterType = Enum.RaycastFilterType.Blacklist, FilterDescendantsInstances = {self.Char}})
    return r and r.Position + Vector3.new(0, 3, 0) or pos + o
end

function AI:MovePath(p)
    for i, w in pairs(p:GetWaypoints()) do
        if i > 1 and self.On and self.Act == "wander" then
            if w.Action == Enum.PathWaypointAction.Jump then self.Humanoid.Jump = true end
            self.Humanoid:MoveTo(w.Position + (math.random() < CFG.MOVE_RAND and Vector3.new(math.random(-2, 2) * 0.1, 0, math.random(-2, 2) * 0.1) or Vector3.new()))
            local t = tick()
            while self.On and (self.Root.Position - w.Position).Magnitude > 3 and tick() - t < 5 do wait(0.1) end
            if i < #p:GetWaypoints() and math.random() < 0.3 then wait(math.random() * 0.5) end
        end
    end
end

function AI:Approach(p)
    if not p or not p.Character or not p.Character:FindFirstChild("HumanoidRootPart") then return end
    local t = tick()
    while self.On and self.Act == "approach" and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and tick() - t < 30 do
        local pos = p.Character.HumanoidRootPart.Position
        if (pos - self.Root.Position).Magnitude <= CFG.INT_DIST then break end
        local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true})
        path:ComputeAsync(self.Root.Position, pos)
        if path.Status == Enum.PathStatus.Success then self:MovePath(path) else self.Humanoid:MoveTo(pos) wait(1) end
        wait(0.5)
    end
end

function AI:Interact(p, m)
    if not p or not p.Character then return end
    self:Approach(p)
    self:Say(m or ("Hey %s, what's up?"):format(p.Name))
    self:Emote({"wave", "point", "dance"}[math.random(3)])
end

function AI:Explore()
    local pts = self:FindPts()
    if #pts > 0 then
        local p = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true})
        p:ComputeAsync(self.Root.Position, pts[math.random(#pts)])
        if p.Status == Enum.PathStatus.Success then
            self:MovePath(p)
            self:Look()
            if math.random() < 0.7 then self:Say({"Cool spot!", "Exploring here!", "Nice find!"}[math.random(3)]) end
        else
            self:Wander()
        end
    else
        self:Wander()
    end
end

function AI:FindPts()
    local pts, pos = {}, self.Root.Position
    for _, c in pairs(workspace:GetDescendants()) do
        if c:IsA("BasePart") and ({["Part"]=1,["Model"]=1,["SpawnLocation"]=1,["Seat"]=1})[c.ClassName] then
            local d = (c.Position - pos).Magnitude
            if d > 20 and d < 200 then table.insert(pts, c.Position) if #pts >= 10 then break end end
        end
    end
    if #pts == 0 then for i = 1, 5 do table.insert(pts, pos + Vector3.new(math.random(-100, 100), 0, math.random(-100, 100))) end end
    return pts
end

function AI:Look()
    local s = self.Root.CFrame
    for _, d in pairs({Vector3.new(1,0,0), Vector3.new(0,0,1), Vector3.new(-1,0,0), Vector3.new(0,0,-1)}) do
        if not self.On then break end
        self.Root.CFrame = CFrame.lookAt(self.Root.Position, self.Root.Position + d)
        wait(0.5 + math.random() * 0.5)
    end
    self.Root.CFrame = s
end

function AI:Follow(p, dur)
    if not p or not p.Character then return end
    local t = tick()
    if math.random() < 0.7 then self:Say(("Following you, %s!"):format(p.Name)) end
    while self.On and self.Act == "follow" and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and tick() - t < (dur or 15) do
        local pos = p.Character.HumanoidRootPart.Position
        local d = (pos - self.Root.Position).Magnitude
        if d > CFG.INT_DIST + 2 and d < 50 then
            self.Humanoid:MoveTo(pos - (p.Character.HumanoidRootPart.CFrame.LookVector * CFG.INT_DIST * 0.8))
            local mt = tick()
            while tick() - mt < 2 and self.On and self.Act == "follow" and (self.Root.Position - pos).Magnitude > 5 do wait(0.1) end
        end
        if math.random() < 0.1 then self:Say({"Cool!", "Where to?", "Nice!"}[math.random(3)]) end
        wait(0.5)
    end
    if math.random() < 0.5 then self:Say("Thanks for the tour!") end
end

function AI:Emote(e) if self.Emotes[e:lower()] then self.Emotes[e:lower()](self) else self.Humanoid:PlayEmote(e) end end

return AI.new()

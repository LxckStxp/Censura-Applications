-- UIManager.lua (Built with CensuraG for Roblox AI Controller)
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- Load CensuraG (assuming it's already loaded globally via CensuraG.lua)
local CensuraG = _G.CensuraG
if not CensuraG then
    warn("CensuraG not loaded. Please run CensuraG.lua first.")
    return
end

local UIManager = {}
UIManager.__index = UIManager

-- Configuration
local WEBHOOK_URL = "http://127.0.0.1:5000" -- Adjust if your server runs elsewhere
local DEFAULT_THEME = "Cyberpunk" -- Matches dashboard's vibrant style

-- Helper function to make HTTP POST requests
local function postRequest(endpoint, data)
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = WEBHOOK_URL .. endpoint,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
    if success and response.Success then
        return HttpService:JSONDecode(response.Body)
    else
        CensuraG.Logger:error("HTTP POST failed to " .. endpoint .. ": " .. (response and response.StatusMessage or "Unknown error"))
        return nil
    end
end

-- Helper function to make HTTP GET requests
local function getRequest(endpoint)
    local success, response = pcall(function()
        return HttpService:GetAsync(WEBHOOK_URL .. endpoint)
    end)
    if success then
        return HttpService:JSONDecode(response)
    else
        CensuraG.Logger:error("HTTP GET failed to " .. endpoint .. ": " .. tostring(response))
        return nil
    end
end

function UIManager.new()
    local self = setmetatable({}, UIManager)
    
    -- Set theme to match dashboard/admin
    CensuraG.SetTheme(DEFAULT_THEME)
    
    -- Create main window
    self.Window = CensuraG.CreateWindow("AI Controller Manager")
    if not self.Window then
        CensuraG.Logger:error("Failed to create UIManager window")
        return nil
    end
    self.Window:SetSize(400, 500) -- Larger to fit all options
    
    -- Create grid for list layout
    self.Grid = CensuraG.Components.grid(self.Window.ContentFrame)
    if not self.Grid then
        CensuraG.Logger:error("Failed to create grid for UIManager")
        return nil
    end
    
    -- Initialize components
    self:SetupUIComponents()
    
    CensuraG.Logger:info("UIManager initialized")
    return self
end

function UIManager:SetupUIComponents()
    -- Title Label
    local titleLabel = CensuraG.Components.textlabel(self.Grid.Instance, "AI Controller Settings")
    titleLabel.Instance.TextSize = 20
    titleLabel.Instance.TextColor3 = Color3.fromRGB(0, 212, 255) -- Cyan to match dashboard
    self.Grid:AddComponent(titleLabel)
    
    -- Section: Server Actions
    local actionsLabel = CensuraG.Components.textlabel(self.Grid.Instance, "Server Actions")
    actionsLabel.Instance.TextColor3 = Color3.fromRGB(255, 107, 129) -- Pink accent
    self.Grid:AddComponent(actionsLabel)
    
    local clearHistoryButton = CensuraG.Components.textbutton(self.Grid.Instance, "Clear History", function()
        local response = postRequest("/admin/clear_history", {})
        if response and response.status == "success" then
            CensuraG.Logger:info("History cleared successfully")
        end
    end)
    self.Grid:AddComponent(clearHistoryButton)
    
    local resetStatsButton = CensuraG.Components.textbutton(self.Grid.Instance, "Reset Stats", function()
        local response = postRequest("/admin/reset_stats", {})
        if response and response.status == "success" then
            CensuraG.Logger:info("Stats reset successfully")
        end
    end)
    self.Grid:AddComponent(resetStatsButton)
    
    -- Section: Configuration
    local configLabel = CensuraG.Components.textlabel(self.Grid.Instance, "Configuration")
    configLabel.Instance.TextColor3 = Color3.fromRGB(255, 107, 129)
    self.Grid:AddComponent(configLabel)
    
    -- Rate Limiting Toggle
    local rateLimitToggle = CensuraG.Components.switch(self.Grid.Instance, "Rate Limiting", true, function(state)
        local configData = {
            rate_limit = { enabled = state }
        }
        local response = postRequest("/admin/update_config", configData)
        if response and response.status == "success" then
            CensuraG.Logger:info("Rate limiting " .. (state and "enabled" or "disabled"))
        end
    end)
    self.Grid:AddComponent(rateLimitToggle)
    
    -- Max Requests Slider
    local maxRequestsSlider = CensuraG.Components.slider(self.Grid.Instance, "Max Requests/Min", 10, 1000, 60, function(value)
        local configData = {
            rate_limit = { max_requests = math.floor(value) }
        }
        local response = postRequest("/admin/update_config", configData)
        if response and response.status == "success" then
            CensuraG.Logger:info("Max requests set to " .. math.floor(value))
        end
    end)
    self.Grid:AddComponent(maxRequestsSlider)
    
    -- Theme Dropdown
    local themeOptions = {"Military", "Cyberpunk"}
    local themeDropdown = CensuraG.Components.dropdown(self.Grid.Instance, "Theme", themeOptions, function(selected)
        CensuraG.SetTheme(selected)
        CensuraG.Logger:info("Theme changed to " .. selected)
    end)
    themeDropdown:SetSelected(DEFAULT_THEME, true) -- Set default without triggering callback
    self.Grid:AddComponent(themeDropdown)
    
    -- Section: Stats Display
    local statsLabel = CensuraG.Components.textlabel(self.Grid.Instance, "Server Stats")
    statsLabel.Instance.TextColor3 = Color3.fromRGB(255, 107, 129)
    self.Grid:AddComponent(statsLabel)
    
    self.StatsDisplay = CensuraG.Components.textlabel(self.Grid.Instance, "Requests: 0 | Errors: 0")
    self.StatsDisplay.Instance.TextSize = 14
    self.Grid:AddComponent(self.StatsDisplay)
    
    -- Refresh Stats Button
    local refreshStatsButton = CensuraG.Components.textbutton(self.Grid.Instance, "Refresh Stats", function()
        self:UpdateStats()
    end)
    self.Grid:AddComponent(refreshStatsButton)
end

function UIManager:UpdateStats()
    local stats = getRequest("/api/stats")
    if stats then
        self.StatsDisplay.Instance.Text = string.format(
            "Requests: %d | Errors: %d | Avg Response: %.2fs",
            stats.requests or 0,
            stats.errors or 0,
            stats.avg_response_time or 0
        )
        CensuraG.Logger:info("Stats updated")
    end
end

function UIManager:Show()
    if self.Window then
        self.Window.Frame.Visible = true
        self:UpdateStats() -- Initial stats update
        CensuraG.Logger:info("UIManager shown")
    end
end

function UIManager:Hide()
    if self.Window then
        self.Window.Frame.Visible = false
        CensuraG.Logger:info("UIManager hidden")
    end
end

-- Auto-initialize when script runs
local manager = UIManager.new()
if manager then
    manager:Show()
end

return UIManager

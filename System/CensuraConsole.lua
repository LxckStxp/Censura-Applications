--[[
    CensuraConsole - Custom Console UI
    Part of CensuraG-Applications
    
    Depends on:
    - CensuraG UI API
    
    Features:
    - Real-time log capture via LogService
    - RichText display with dynamic scrolling
    - Multi-color per line with specific string patterns
    - Raw log caching and copy functionality
    - Keyword filtering for logs
    - Duplicate message stacking
    - Simplified buttons in a horizontal grid (Copy All, Clear Logs, Auto-Scroll)
    - Code execution input with ">" placeholder
    - Consistent CensuraG styling
]]

-- Ensure CensuraG is loaded
if not _G.CensuraG then
    _G.CensuraG.Logger:error("CensuraConsole requires CensuraG to be loaded. Please load CensuraG first.")
    return
end

-- Initialize CensuraConsole
local CensuraConsole = {
    Version = "1.0.0",
    Window = nil,
    Components = {},
    LogBuffer = {}, -- Stores {raw = "...", formatted = "...", type = Enum.MessageType, count = number}
    MaxLogs = 1000,
    AutoScroll = true,
    FilterText = "",
    LastMessage = nil,
    LastMessageCount = 0
}

-- Create the console window using CensuraG
CensuraConsole.Window = _G.CensuraG.Methods:CreateWindow("Censura Console v" .. CensuraConsole.Version)
if not CensuraConsole.Window then
    _G.CensuraG.Logger:error("Failed to create Censura Console window")
    return
end
CensuraConsole.Window:SetSize(600, 500) -- Larger window size

-- Create grid layout for the window content
local consoleGrid = _G.CensuraG.Components.grid(CensuraConsole.Window.ContentFrame)
CensuraConsole.Components.Grid = consoleGrid

-- Filter input
local filterFrame = Instance.new("Frame")
filterFrame.Size = UDim2.new(1, -12, 0, 30)
filterFrame.BackgroundTransparency = 1 -- Grid handles background

local filterInput = Instance.new("TextBox", filterFrame)
filterInput.Size = UDim2.new(1, -10, 1, -5)
filterInput.Position = UDim2.new(0, 5, 0, 2.5)
filterInput.BackgroundColor3 = _G.CensuraG.Config:GetTheme().PrimaryColor
filterInput.BackgroundTransparency = 0.7
filterInput.BorderSizePixel = 0
filterInput.Text = ""
filterInput.PlaceholderText = "Filter logs..."
filterInput.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
filterInput.Font = _G.CensuraG.Config:GetTheme().Font
filterInput.TextSize = _G.CensuraG.Config:GetTheme().TextSize
filterInput.TextXAlignment = Enum.TextXAlignment.Left
filterInput.ClearTextOnFocus = false

local filterInputCorner = Instance.new("UICorner", filterInput)
filterInputCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)

CensuraConsole.Components.FilterInput = filterInput
consoleGrid:AddComponent({Instance = filterFrame})

-- Log display (Dynamic ScrollingFrame with TextLabel)
local logFrame = Instance.new("Frame")
logFrame.Size = UDim2.new(1, -12, 1, -100) -- Adjusted for filter, command input, and buttons
logFrame.BackgroundTransparency = 1 -- Grid handles background

local logScroll = Instance.new("ScrollingFrame", logFrame)
logScroll.Size = UDim2.new(1, -10, 1, -10)
logScroll.Position = UDim2.new(0, 5, 0, 5)
logScroll.BackgroundTransparency = 1
logScroll.BorderSizePixel = 0
logScroll.ScrollBarThickness = 6
logScroll.ScrollBarImageColor3 = _G.CensuraG.Config:GetTheme().AccentColor
logScroll.ScrollBarImageTransparency = 0.3
logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

local logLabel = Instance.new("TextLabel", logScroll)
logLabel.Size = UDim2.new(1, -10, 0, 0)
logLabel.BackgroundTransparency = 1
logLabel.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
logLabel.Font = _G.CensuraG.Config:GetTheme().Font
logLabel.TextSize = _G.CensuraG.Config:GetTheme().TextSize
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.TextWrapped = true
logLabel.RichText = true
logLabel.Text = ""

local padding = Instance.new("UIPadding", logLabel)
padding.PaddingLeft = UDim.new(0, 5)
padding.PaddingRight = UDim.new(0, 5)
padding.PaddingTop = UDim.new(0, 5)
padding.PaddingBottom = UDim.new(0, 5)

CensuraConsole.Components.LogDisplay = logLabel
consoleGrid:AddComponent({Instance = logFrame})

-- Command input
local inputFrame = Instance.new("Frame")
inputFrame.Size = UDim2.new(1, -12, 0, 40)
inputFrame.BackgroundTransparency = 1 -- Grid handles background

local commandInput = Instance.new("TextBox", inputFrame)
commandInput.Size = UDim2.new(1, -10, 1, -10)
commandInput.Position = UDim2.new(0, 5, 0, 5)
commandInput.BackgroundColor3 = _G.CensuraG.Config:GetTheme().PrimaryColor
commandInput.BackgroundTransparency = 0.7
commandInput.BorderSizePixel = 0
commandInput.Text = ""
commandInput.PlaceholderText = ">"
commandInput.TextColor3 = _G.CensuraG.Config:GetTheme().TextColor
commandInput.Font = _G.CensuraG.Config:GetTheme().Font
commandInput.TextSize = _G.CensuraG.Config:GetTheme().TextSize
commandInput.TextXAlignment = Enum.TextXAlignment.Left
commandInput.ClearTextOnFocus = false

local commandInputCorner = Instance.new("UICorner", commandInput)
commandInputCorner.CornerRadius = UDim.new(0, _G.CensuraG.Config.Math.CornerRadius)

CensuraConsole.Components.CommandInput = commandInput
consoleGrid:AddComponent({Instance = inputFrame})

-- Button row with grid layout
local buttonFrame = Instance.new("Frame")
buttonFrame.Size = UDim2.new(1, -12, 0, 30)
buttonFrame.BackgroundTransparency = 1 -- Grid handles background

local buttonGrid = Instance.new("UIGridLayout", buttonFrame)
buttonGrid.CellSize = UDim2.new(0, 120, 0, 25)
buttonGrid.CellPadding = UDim2.new(0, 10, 0, 5)
buttonGrid.FillDirection = Enum.FillDirection.Horizontal
buttonGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
buttonGrid.VerticalAlignment = Enum.VerticalAlignment.Center

-- Copy All button
local copyButton = _G.CensuraG.Components.textbutton(buttonFrame, "Copy All", function()
    local rawLogs = {}
    for _, log in ipairs(CensuraConsole.LogBuffer) do
        for i = 1, (log.count or 1) do
            table.insert(rawLogs, log.raw)
        end
    end
    local rawText = table.concat(rawLogs, "\n")
    setclipboard(rawText)
    CensuraConsole:AddLog("All raw logs copied to clipboard", Enum.MessageType.MessageInfo)
end)

-- Clear Logs button
local clearButton = _G.CensuraG.Components.textbutton(buttonFrame, "Clear Logs", function()
    CensuraConsole.LogBuffer = {}
    CensuraConsole.LastMessage = nil
    CensuraConsole.LastMessageCount = 0
    CensuraConsole:UpdateDisplay()
end)

-- Auto-Scroll button
local autoScrollButton = _G.CensuraG.Components.textbutton(buttonFrame, "Auto-Scroll: ON", function()
    CensuraConsole.AutoScroll = not CensuraConsole.AutoScroll
    autoScrollButton.SetText(autoScrollButton, "Auto-Scroll: " .. (CensuraConsole.AutoScroll and "ON" or "OFF"))
end)

-- Add buttons to the grid
consoleGrid:AddComponent({Instance = copyButton.Instance})
consoleGrid:AddComponent({Instance = clearButton.Instance})
consoleGrid:AddComponent({Instance = autoScrollButton.Instance})
consoleGrid:AddComponent({Instance = buttonFrame})

-- Color patterns for specific strings
local colorPatterns = {
    ["[!]"] = "#FF0000",      -- Red
    ["[~]"] = "#FFFF00",      -- Yellow
    ["[+]"] = "#808080",      -- Grey
    ["[-]"] = "#800080",      -- Purple
    ["[CensuraG]"] = "#FF00FF", -- Magenta
    ["[INFO]"] = "#808080",   -- Grey
    ["[WARN]"] = "#FFFF00",   -- Yellow
    ["[WARNING]"] = "#FFFF00",-- Yellow
    ["[DEBUG]"] = "#EE82EE"   -- Violet
}

-- Log formatting function
function CensuraConsole:FormatLog(message, logType, count)
    local timestamp = os.date("%H:%M:%S")
    local theme = _G.CensuraG.Config:GetTheme()
    local baseColor = "#FFFFFF" -- Default white
    
    if logType == Enum.MessageType.MessageOutput then
        baseColor = "#FFFFFF"
    elseif logType == Enum.MessageType.MessageWarning then
        baseColor = "#FFA500"
    elseif logType == Enum.MessageType.MessageError then
        baseColor = "#FF0000"
    elseif logType == Enum.MessageType.MessageInfo then
        baseColor = "#00FFFF"
    end
    
    local escapedMessage = message:gsub("<", "<"):gsub(">", ">")
    
    for pattern, color in pairs(colorPatterns) do
        escapedMessage = escapedMessage:gsub(
            pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"),
            '<font color="' .. color .. '">%1</font>'
        )
    end
    
    local displayMessage = count > 1 and (escapedMessage .. " x" .. count) or escapedMessage
    return string.format(
        '<font color="%s">[%s] %s</font>',
        baseColor,
        timestamp,
        displayMessage
    )
end

-- Add log to buffer and update display
function CensuraConsole:AddLog(message, logType)
    -- Check for duplicates
    if message == self.LastMessage and logType == (self.LogBuffer[#self.LogBuffer] and self.LogBuffer[#self.LogBuffer].type) then
        self.LastMessageCount = self.LastMessageCount + 1
        self.LogBuffer[#self.LogBuffer].count = self.LastMessageCount
        self.LogBuffer[#self.LogBuffer].formatted = self:FormatLog(message, logType, self.LastMessageCount)
    else
        self.LastMessage = message
        self.LastMessageCount = 1
        local formattedLog = self:FormatLog(message, logType, 1)
        table.insert(self.LogBuffer, {raw = message, formatted = formattedLog, type = logType, count = 1})
    end
    
    if #self.LogBuffer > self.MaxLogs then
        table.remove(self.LogBuffer, 1)
    end
    
    self:UpdateDisplay()
end

-- Update the log display with dynamic scaling and filtering
function CensuraConsole:UpdateDisplay()
    local filteredLogs = {}
    for _, log in ipairs(self.LogBuffer) do
        if self.FilterText == "" or log.raw:lower():find(self.FilterText:lower()) then
            table.insert(filteredLogs, log.formatted)
        end
    end
    local text = table.concat(filteredLogs, "\n")
    self.Components.LogDisplay.Text = text
    
    local textBounds = self.Components.LogDisplay.TextBounds
    self.Components.LogDisplay.Size = UDim2.new(1, -10, 0, textBounds.Y + 10)
    self.Components.LogDisplay.Parent.CanvasSize = UDim2.new(0, 0, 0, textBounds.Y + 10)
    
    if self.AutoScroll then
        task.spawn(function()
            self.Components.LogDisplay.Parent.CanvasPosition = Vector2.new(0, math.huge)
        end)
    end
end

-- Hook into LogService for all output
function CensuraConsole:HookOutput()
    local logService = game:GetService("LogService")
    
    logService.MessageOut:Connect(function(message, messageType)
        self:AddLog(message, messageType)
    end)
end

-- Execute command from input
function CensuraConsole:ExecuteCommand()
    local code = self.Components.CommandInput.Text
    if code == "" then return end
    
    self:AddLog("> " .. code, Enum.MessageType.MessageOutput)
    
    local success, result = pcall(function()
        local func = loadstring(code)
        if func then
            return func()
        else
            return "Invalid code"
        end
    end)
    
    if success then
        if result ~= nil then
            self:AddLog(tostring(result), Enum.MessageType.MessageOutput)
        end
    else
        self:AddLog(tostring(result), Enum.MessageType.MessageError)
    end
    
    self.Components.CommandInput.Text = ""
end

-- Connect input events
function CensuraConsole:ConnectEvents()
    self.Components.CommandInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            self:ExecuteCommand()
        end
    end)
    
    self.Components.FilterInput.Changed:Connect(function(property)
        if property == "Text" then
            self.FilterText = self.Components.FilterInput.Text
            self:UpdateDisplay()
        end
    end)
end

-- Initialize CensuraConsole
function CensuraConsole:Initialize()
    self:HookOutput()
    self:ConnectEvents()
    
    self:AddLog("Censura Console v" .. self.Version .. " initialized [CensuraG]", Enum.MessageType.MessageOutput)
    
    _G.CensuraConsole = self
    return self
end

-- Refresh the console UI
function CensuraConsole:Refresh()
    _G.CensuraG.Methods:RefreshComponent("window", self.Window)
    self:UpdateDisplay()
end

-- Start the console
CensuraConsole:Initialize()
loadstring(game:HttpGet("https://raw.githubusercontent.com/LxckStxp/Censura-Applications/main/System/Remote.lua"))()

return CensuraConsole

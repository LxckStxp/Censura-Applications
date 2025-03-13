-- Logger Module
local Logger = {}

Logger.Levels = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4
}

Logger.Settings = {
    CurrentLevel = Logger.Levels.INFO,
    MaxHistory = 100,
    TimestampFormat = "%H:%M:%S"
}
Logger.History = {}

function Logger:log(level, message)
    if self.Levels[level] < self.Settings.CurrentLevel then return end
    
    local timestamp = os.date(self.Settings.TimestampFormat)
    local entry = string.format("[%s] [%s] %s", timestamp, level, message)
    
    table.insert(self.History, entry)
    if #self.History > self.Settings.MaxHistory then
        table.remove(self.History, 1)
    end
    
    print(entry)
    if _G.CensuraG and _G.CensuraG.Logger then
        local cgLogger = _G.CensuraG.Logger
        if level == "ERROR" then cgLogger:error(message)
        elseif level == "WARN" then cgLogger:warn(message)
        else cgLogger:info(message) end
    end
end

function Logger:debug(message)
    self:log("DEBUG", message)
end

function Logger:info(message)
    self:log("INFO", message)
end

function Logger:warn(message)
    self:log("WARN", message)
end

function Logger:error(message)
    self:log("ERROR", message)
end

function Logger:SetLevel(level)
    if self.Levels[level] then
        self.Settings.CurrentLevel = self.Levels[level]
        self:info("Log level set to " .. level)
    else
        self:warn("Invalid log level: " .. tostring(level))
    end
end

function Logger:GetRecentLogs(count)
    count = math.min(count or self.Settings.MaxHistory, #self.History)
    local logs = {}
    for i = #self.History - count + 1, #self.History do
        table.insert(logs, self.History[i])
    end
    return logs
end

function Logger:ClearHistory()
    self.History = {}
    self:info("Log history cleared")
end

return Logger

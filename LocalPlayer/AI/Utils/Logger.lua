-- Enhanced Logger Module
-- /LxckStxp/Censura-Applications/LocalPlayer/AI/Utils/Logger.lua

local Logger = {}

-- Log levels
Logger.Levels = {
    DEBUG = "DEBUG",
    INFO = "INFO",
    WARN = "WARN",
    ERROR = "ERROR"
}

-- Current log level (can be changed at runtime)
Logger.CurrentLevel = Logger.Levels.INFO

-- Log history
Logger.History = {}
Logger.MaxHistory = 100

-- Log a message with a specific level
function Logger:log(level, message)
    if not self:ShouldLog(level) then return end
    
    local timestamp = os.date("%H:%M:%S")
    local logEntry = "[" .. timestamp .. "] [" .. level .. "] " .. message
    
    -- Store in history
    table.insert(self.History, logEntry)
    if #self.History > self.MaxHistory then
        table.remove(self.History, 1)
    end
    
    -- Print to console
    print(logEntry)
    
    -- If CensuraG logger exists, use it too
    if _G.CensuraG and _G.CensuraG.Logger then
        if level == self.Levels.ERROR then
            _G.CensuraG.Logger:error(message)
        elseif level == self.Levels.WARN then
            _G.CensuraG.Logger:warn(message)
        else
            _G.CensuraG.Logger:info(message)
        end
    end
end

-- Check if we should log at this level
function Logger:ShouldLog(level)
    local levels = {
        [self.Levels.DEBUG] = 1,
        [self.Levels.INFO] = 2,
        [self.Levels.WARN] = 3,
        [self.Levels.ERROR] = 4
    }
    
    return levels[level] >= levels[self.CurrentLevel]
end

-- Convenience methods for different log levels
function Logger:debug(message)
    self:log(self.Levels.DEBUG, message)
end

function Logger:info(message)
    self:log(self.Levels.INFO, message)
end

function Logger:warn(message)
    self:log(self.Levels.WARN, message)
end

function Logger:error(message)
    self:log(self.Levels.ERROR, message)
end

-- Get recent logs
function Logger:GetRecentLogs(count)
    count = count or self.MaxHistory
    local result = {}
    local startIdx = math.max(1, #self.History - count + 1)
    
    for i = startIdx, #self.History do
        table.insert(result, self.History[i])
    end
    
    return result
end

return Logger

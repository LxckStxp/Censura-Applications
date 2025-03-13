local SpamDetection = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

function SpamDetection:Initialize()
    self.MessageCounts = {}
    spawn(function()
        while wait(5) do
            self.MessageCounts = {}
        end
    end)
    return self
end

function SpamDetection:IsSpam(playerName, message)
    if not Config.SPAM_DETECTION.enabled then return false end
    
    self.MessageCounts[playerName] = (self.MessageCounts[playerName] or 0) + 1
    if self.MessageCounts[playerName] > Config.SPAM_DETECTION.messageThreshold then
        System.State.IgnoredPlayers[playerName] = os.time() + Config.SPAM_DETECTION.cooldownTime
        Logger:info("Ignoring " .. playerName .. " for spam")
        return true
    end
    return false
end

return SpamDetection

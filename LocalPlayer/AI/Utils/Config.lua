-- AI Controller Configuration
local Config = {
    -- Core Settings
    WEBHOOK_URL = "http://127.0.0.1:5000/webhook",
    DECISION_INTERVAL = 5,      -- Seconds between AI decisions
    ACTION_TIMEOUT = 30,        -- Max seconds for an action before refresh
    
    -- Chat Settings
    MAX_MESSAGE_LENGTH = 300,   -- Max characters per message
    MESSAGE_DELAY = 0.5,        -- Delay between message chunks
    TYPING_SPEED = {            -- Typing simulation speed (seconds per char)
        min = 0.05,
        max = 0.12
    },
    CHAT_MEMORY_SIZE = 15,      -- Number of messages to remember
    
    -- Movement Settings
    DETECTION_RADIUS = 60,      -- Studs distance to detect players
    INTERACTION_DISTANCE = 6,   -- Studs distance for interactions
    MOVEMENT_RANDOMIZATION = 0.3, -- Random movement variation (0-1)
    STUCK_DETECTION = {         -- Stuck detection parameters
        interval = 2,           -- Check interval (seconds)
        threshold = 3,          -- Number of checks
        distance = 1            -- Max movement distance to consider stuck
    },
    
    -- Spam Detection Settings
    SPAM_DETECTION = {
        enabled = true,
        messageThreshold = 3,   -- Messages in timeWindow to flag spam
        timeWindow = 5,         -- Seconds for message frequency check
        similarityThreshold = 0.7, -- Similarity score for repetitive messages
        cooldownTime = 10       -- Seconds to ignore spammers
    },
    
    -- Emote Mappings (example IDs, adjust as needed)
    EMOTE_ACTIONS = {
        wave = "507770239",
        dance = "507771019",
        laugh = "507770453",
        point = "507770818"
    }
}

-- Basic validation
for key, value in pairs(Config) do
    if type(value) == "table" and key ~= "EMOTE_ACTIONS" then
        for subKey, subValue in pairs(value) do
            if subValue == nil then
                Logger:warn("Nil value detected in Config." .. key .. "." .. subKey)
            end
        end
    elseif value == nil then
        Logger:warn("Nil value detected in Config." .. key)
    end
end

return Config

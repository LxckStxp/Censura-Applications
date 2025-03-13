-- AI Controller Configuration
-- /LxckStxp/Censura-Applications/LocalPlayer/AI/Utils/Config.lua

local Config = {
    -- Basic configuration
    WEBHOOK_URL = "http://127.0.0.1:5000/webhook",
    MAX_MESSAGE_LENGTH = 300,
    MESSAGE_DELAY = 0.5,
    DECISION_INTERVAL = 5,
    
    -- Advanced configuration
    TYPING_SPEED = { min = 0.05, max = 0.12 },
    MOVEMENT_RANDOMIZATION = 0.3,
    INTERACTION_DISTANCE = 6,
    DETECTION_RADIUS = 60,
    CHAT_MEMORY_SIZE = 15,
    ACTION_TIMEOUT = 30,
    
    -- Spam detection configuration
    SPAM_DETECTION = {
        enabled = true,
        messageThreshold = 3,
        timeWindow = 5,
        similarityThreshold = 0.7,
        cooldownTime = 10
    },
    
    -- Character settings
    STUCK_DETECTION = {
        interval = 2,
        threshold = 3,
        distance = 1
    },
    
    -- Emote actions mapping
    EMOTE_ACTIONS = {
        ["wave"] = "wave",
        ["dance"] = "dance",
        ["laugh"] = "laugh",
        ["point"] = "point",
        ["sit"] = "sit",
        ["jump"] = "jump"
    }
}

return Config

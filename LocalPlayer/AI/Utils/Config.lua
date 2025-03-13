local Config = {
    WEBHOOK_URL = "http://127.0.0.1:5000/webhook",
    MAX_MESSAGE_LENGTH = 200,
    DECISION_INTERVAL = 5,
    DETECTION_RADIUS = 60,
    INTERACTION_DISTANCE = 6,
    ACTION_TIMEOUT = 15,
    SPAM_DETECTION = {
        enabled = true,
        messageThreshold = 3,
        cooldownTime = 10
    }
}
return Config

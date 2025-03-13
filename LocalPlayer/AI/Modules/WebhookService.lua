local HttpService = game:GetService("HttpService")

local WebhookService = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

function WebhookService:Initialize()
    return self
end

function WebhookService:CallGrok(message)
    local body = HttpService:JSONEncode({message = message})
    local success, result = pcall(function()
        local response = HttpService:PostAsync(Config.WEBHOOK_URL, body, Enum.HttpContentType.ApplicationJson)
        return HttpService:JSONDecode(response)
    end)
    
    if success and result then
        return result
    else
        Logger:error("Webhook failed")
        return {action = "say", message = "Something went wrong!"}
    end
end

return WebhookService

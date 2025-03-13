-- Webhook Service Module
-- /LxckStxp/Censura-Applications/LocalPlayer/AI/Modules/WebhookService.lua

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local WebhookService = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

function WebhookService:Initialize()
    return self
end

-- Call Webhook Server with enhanced player information
function WebhookService:CallGrok(message)
    local requestBody = { 
        message = message,
        player_name = localPlayer.Name,
        game_id = game.PlaceId
    }
    
    local body = HttpService:JSONEncode(requestBody)
    
    local response, success, err
    if typeof(request) == "function" then
        Logger:info("Using executor 'request' function")
        success, response = pcall(function()
            local res = request({
                Url = Config.WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = body
            })
            if res.StatusCode == 200 then
                local decoded = HttpService:JSONDecode(res.Body)
                Logger:info("Raw response: " .. tostring(res.Body))
                return decoded
            else
                error("Request returned status: " .. res.StatusCode)
            end
        end)
    else
        Logger:info("Falling back to HttpService")
        success, response = pcall(function()
            local res = HttpService:RequestAsync({
                Url = Config.WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = body
            })
            if res.Success then
                local decoded = HttpService:JSONDecode(res.Body)
                Logger:info("Raw response: " .. tostring(res.Body))
                return decoded
            else
                error("HttpService failed: " .. res.StatusCode .. " - " .. res.StatusMessage)
            end
        end)
    end
    
    if success and response and response.action then
        Logger:info("Decision: action=" .. tostring(response.action) .. 
                   ", target=" .. tostring(response.target) .. 
                   ", message=" .. tostring(response.message) ..
                   ", priority=" .. tostring(response.priority or "N/A") ..
                   ", duration=" .. tostring(response.duration or "N/A"))
        return response
    else
        Logger:error("Failed to call webhook or invalid response: " .. tostring(err or response))
        return nil
    end
end

return WebhookService

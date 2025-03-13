local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local localPlayer = Players.LocalPlayer

local ChatManager = {}
local System = _G.AiSystem
local Config = System.Config
local Logger = System.Utils.Logger

function ChatManager:Initialize(controller)
    self.Controller = controller
    self:SetupChatHandler()
    return self
end

function ChatManager:SetupChatHandler()
    TextChatService.MessageReceived:Connect(function(msg)
        local sender = msg.TextSource and Players:GetPlayerByUserId(msg.TextSource.UserId)
        if sender and sender ~= localPlayer then
            local isSpam = System.Modules.SpamDetection:IsSpam(sender.Name, msg.Text)
            if not isSpam and System.State.IsActive then
                self.Controller:QueryGrokWithChat(msg.Text, sender.Name)
            end
        end
    end)
end

function ChatManager:SendMessage(message)
    local channel = TextChatService.TextChannels.RBXGeneral
    if channel then
        wait(#message * 0.05) -- Simple typing delay
        channel:SendAsync(message)
        Logger:info("Sent: " .. message)
    end
end

return ChatManager

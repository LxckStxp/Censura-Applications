local UIManager = {}
local System = _G.AiSystem
local Logger = System.Utils.Logger

function UIManager:Initialize(controller)
    self.Controller = controller
    self:SetupUI()
    return self
end

function UIManager:SetupUI()
    self.Window = _G.CensuraG.CreateWindow("AI Control")
    self.Window:SetSize(200, 150)
    
    self.Toggle = _G.CensuraG.Methods:CreateSwitch(self.Window.ContentFrame, "Enable AI", false, function(state)
        self.Controller:ToggleAIControl(state)
    end)
    
    self.Status = Instance.new("TextLabel")
    self.Status.Size = UDim2.new(1, 0, 0, 20)
    self.Status.Position = UDim2.new(0, 0, 0, 40)
    self.Status.Text = "Status: Stopped"
    self.Status.Parent = self.Window.ContentFrame
end

function UIManager:UpdateStatusLabels(status)
    self.Status.Text = "Status: " .. status
end

return UIManager

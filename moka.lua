--[[
    MokAa - Auto Spam Parry (Optimized Allusive-Style)
    Velocidad: Ejecución por Frame (Heartbeat)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ParryAttempt = Remotes:WaitForChild("ParryAttempt")

-- ========== CONFIGURACIÓN ==========
local active = false
local spamConnection = nil
local activationKey = Enum.KeyCode.F
local customKeyName = "F"

-- ========== LÓGICA DE SPAM (OPTIMIZADA) ==========
local function startSpam()
    if spamConnection then return end
    -- Usamos Heartbeat para ejecutar el spam en cada ciclo del servidor
    spamConnection = RunService.Heartbeat:Connect(function()
        if not active then return end
        
        -- Ejecución directa sin esperas
        ParryAttempt:FireServer()
        VIM:SendKeyEvent(true, activationKey, false, game)
        VIM:SendKeyEvent(false, activationKey, false, game)
    end)
end

local function stopSpam()
    if spamConnection then
        spamConnection:Disconnect()
        spamConnection = nil
    end
end

local function toggleSpam()
    active = not active
    if active then
        startSpam()
    else
        stopSpam()
    end
    -- Actualizar UI
    if ToggleBtn then
        ToggleBtn.Text = active and "DESACTIVAR" or "ACTIVAR"
        ToggleBtn.BackgroundColor3 = active and Color3.fromRGB(120, 40, 120) or Color3.fromRGB(70, 40, 90)
    end
    if StatusLabel then
        StatusLabel.Text = active and "ACTIVO" or "INACTIVO"
        StatusLabel.TextColor3 = active and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(255, 150, 150)
    end
end

-- ========== GUI ==========
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "MokAa"
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 260, 0, 140)
MainFrame.Position = UDim2.new(0.5, -130, 0.5, -70)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 20, 45)
MainFrame.BackgroundTransparency = 0.1
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", MainFrame).Color = Color3.fromRGB(150, 100, 200)

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Text = "MokAa - High Speed"
Title.TextColor3 = Color3.fromRGB(220, 180, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 12)

StatusLabel = Instance.new("TextLabel", MainFrame)
StatusLabel.Size = UDim2.new(0.9, 0, 0, 25)
StatusLabel.Position = UDim2.new(0.05, 0, 0, 50)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "INACTIVO"
StatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)

ToggleBtn = Instance.new("TextButton", MainFrame)
ToggleBtn.Size = UDim2.new(0.4, 0, 0, 32)
ToggleBtn.Position = UDim2.new(0.05, 0, 0, 80)
ToggleBtn.Text = "ACTIVAR"
ToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 40, 90)
ToggleBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 6)

local KeyButton = Instance.new("TextButton", MainFrame)
KeyButton.Size = UDim2.new(0.4, 0, 0, 32)
KeyButton.Position = UDim2.new(0.55, 0, 0, 80)
KeyButton.Text = "TECLA: " .. customKeyName
KeyButton.BackgroundColor3 = Color3.fromRGB(50, 35, 70)
KeyButton.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", KeyButton).CornerRadius = UDim.new(0, 6)

-- ========== EVENTOS ==========
ToggleBtn.MouseButton1Click:Connect(toggleSpam)

local waitingForKey = false
KeyButton.MouseButton1Click:Connect(function()
    waitingForKey = true
    KeyButton.Text = "PRESS KEY..."
    local conn
    conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not waitingForKey then return end
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            activationKey = input.KeyCode
            customKeyName = input.KeyCode.Name
            KeyButton.Text = "TECLA: " .. customKeyName
            waitingForKey = false
            conn:Disconnect()
        end
    end)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if waitingForKey then return end
    if input.KeyCode == activationKey then
        toggleSpam()
    end
end)

-- Arrastrar GUI
local dragging, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.MouseMovement then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

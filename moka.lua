--[[
    KRY5.2 - BLADE BALL [PREMIUM OVERLOAD EDITION]
    - Overload Burst: 50 paquetes instantáneos al activar.
    - Estética: Navy Blue Premium & Snow Effect.
    - Estabilidad: 0 lag, ms bajo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local function getParryRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:FindFirstChild("Events") or ReplicatedStorage
    for _, v in pairs(remotes:GetDescendants()) do
        local name = v.Name:lower()
        if (name:find("parry") or name:find("block") or name:find("deflect")) and v:IsA("RemoteEvent") then
            return v
        end
    end
    return nil
end

local autoSpam = false
local activationKey = Enum.KeyCode.F
local isBinding = false
local remoteCache = getParryRemote()

-- ========== MOTOR DE SPAM (OVERLOAD BURST) ==========
local function startAutoSpam()
    task.spawn(function()
        -- OVERLOAD: Ráfaga de inicio masiva (50 paquetes)
        if remoteCache then
            for i = 1, 50 do
                remoteCache:FireServer()
            end
        end
        
        -- Bucle estable
        while autoSpam do
            if remoteCache then
                for i = 1, 5 do
                    remoteCache:FireServer()
                end
                VIM:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game)
            end
            task.wait(0.01)
        end
    end)
end

-- ========== GUI (PREMIUM NAVY) ==========
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "MokAaPremium"

local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 260, 0, 160)
Frame.Position = UDim2.new(0.5, -130, 0.5, -80)
Frame.BackgroundColor3 = Color3.fromRGB(0, 15, 40) -- Navy Premium
Frame.Active = true 
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", Frame).Color = Color3.fromRGB(0, 150, 255)
Instance.new("UIStroke", Frame).Thickness = 2

-- Efecto Nieve (Premium)
task.spawn(function()
    while true do
        local flake = Instance.new("Frame", Frame)
        flake.Size = UDim2.new(0, 2, 0, 2)
        flake.Position = UDim2.new(math.random(), 0, 0, 0)
        flake.BackgroundColor3 = Color3.fromRGB(200, 240, 255)
        flake.BackgroundTransparency = 0.3
        task.spawn(function()
            for i = 1, 30 do
                flake.Position = flake.Position + UDim2.new(0, 0, 0.03, 0)
                task.wait(0.05)
            end
            flake:Destroy()
        end)
        task.wait(0.4)
    end
end)

local DragBar = Instance.new("Frame", Frame)
DragBar.Size = UDim2.new(1, 0, 0, 30)
DragBar.BackgroundColor3 = Color3.fromRGB(0, 25, 60)
DragBar.BackgroundTransparency = 0.2
Instance.new("UICorner", DragBar).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel", DragBar)
Title.Size = UDim2.new(1, 0, 1, 0)
Title.Text = "KRY5.2 - OVERLOAD"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.BackgroundTransparency = 1

local SpamBtn = Instance.new("TextButton", Frame)
SpamBtn.Size = UDim2.new(0.8, 0, 0, 35)
SpamBtn.Position = UDim2.new(0.1, 0, 0, 50)
SpamBtn.Text = "AUTO SPAM [OFF]"
SpamBtn.Font = Enum.Font.GothamBold
SpamBtn.BackgroundColor3 = Color3.fromRGB(0, 40, 80)
SpamBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", SpamBtn).CornerRadius = UDim.new(0, 6)

local KeyBtn = Instance.new("TextButton", Frame)
KeyBtn.Size = UDim2.new(0.8, 0, 0, 35)
KeyBtn.Position = UDim2.new(0.1, 0, 0, 100)
KeyBtn.Text = "TECLA: " .. activationKey.Name
KeyBtn.Font = Enum.Font.GothamBold
KeyBtn.BackgroundColor3 = Color3.fromRGB(0, 40, 80)
KeyBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", KeyBtn).CornerRadius = UDim.new(0, 6)

-- ========== LÓGICA DE ARRASTRE ==========
local dragging, dragStart, startPos
DragBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = Frame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.MouseMovement then
        local delta = input.Position - dragStart
        Frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- ========== EVENTOS ==========
SpamBtn.MouseButton1Click:Connect(function()
    autoSpam = not autoSpam
    SpamBtn.Text = autoSpam and "AUTO SPAM [ON]" or "AUTO SPAM [OFF]"
    SpamBtn.BackgroundColor3 = autoSpam and Color3.fromRGB(0, 100, 200) or Color3.fromRGB(0, 40, 80)
    if autoSpam then startAutoSpam() end
end)

KeyBtn.MouseButton1Click:Connect(function()
    isBinding = true
    KeyBtn.Text = "PRESIONA TECLA..."
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if isBinding then
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            activationKey = input.KeyCode
            KeyBtn.Text = "TECLA: " .. activationKey.Name
            isBinding = false
        end
        return
    end
    if not gameProcessed and input.KeyCode == activationKey then
        autoSpam = not autoSpam
        SpamBtn.Text = autoSpam and "AUTO SPAM [ON]" or "AUTO SPAM [OFF]"
        SpamBtn.BackgroundColor3 = autoSpam and Color3.fromRGB(0, 100, 200) or Color3.fromRGB(0, 40, 80)
        if autoSpam then startAutoSpam() end
    end
end)

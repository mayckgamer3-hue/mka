-- ╔══════════════════════════════════════════╗
-- ║           M o k A a                      ║
-- ║     High-precision macro engine          ║
-- ╚══════════════════════════════════════════╝

local clicking  = false
local holdMode  = false
local KPS       = 80
local interval  = 1 / KPS
local accum     = 0

local RING_SIZE      = 512
local ring           = table.create(RING_SIZE, 0)
local ring_head      = 0
local last_tier      = -1
local last_count_str = "0"

local TOGGLE_KEY        = Enum.KeyCode.E
local spam_keys_enabled = {false, false, false, false}
local spam_keys         = {
    Enum.KeyCode.Unknown,
    Enum.KeyCode.Unknown,
    Enum.KeyCode.Unknown,
    Enum.KeyCode.Unknown,
}

local UIS          = game:GetService("UserInputService")
local VIM          = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local Players      = game:GetService("Players")
local player       = Players.LocalPlayer
local playerGui    = player:WaitForChild("PlayerGui")

local hrt     = os.clock
local m_floor = math.floor
local m_clamp = math.clamp
local tostr   = tostring

local C_BG        = Color3.fromRGB(10,  8,   6)
local C_BG2       = Color3.fromRGB(18,  14,  10)
local C_BG3       = Color3.fromRGB(28,  22,  16)
local C_AMBER     = Color3.fromRGB(255, 165, 50)
local C_AMBER_DIM = Color3.fromRGB(140, 90,  25)
local C_AMBER_LO  = Color3.fromRGB(60,  42,  18)
local C_WHITE     = Color3.fromRGB(240, 230, 215)
local C_GREY      = Color3.fromRGB(140, 128, 110)
local C_BG3_MED   = Color3.fromRGB(38,  30,  20)
local C_GREEN     = Color3.fromRGB(80,  180, 80)

local TI_02  = TweenInfo.new(0.2)
local TI_03  = TweenInfo.new(0.3)
local TI_015 = TweenInfo.new(0.15)
local TI_04  = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI_05  = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI_06  = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function applyKPS(newKPS)
    KPS      = m_clamp(newKPS, 1, 2000)
    interval = 1 / KPS
end

-- ══════════════════════════════════════════════════════════════════════════
--  FIRE — F + Mouse1 siempre activos, slots extra configurables
-- ══════════════════════════════════════════════════════════════════════════
local function fireAllKeys()
    VIM:SendKeyEvent(true,  Enum.KeyCode.F, false, game)
    VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    VIM:SendMouseButtonEvent(0, 0, 0, true,  game, 1)
    VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    for i = 1, 4 do
        if spam_keys_enabled[i] and spam_keys[i] ~= Enum.KeyCode.Unknown then
            VIM:SendKeyEvent(true,  spam_keys[i], false, game)
            VIM:SendKeyEvent(false, spam_keys[i], false, game)
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════
--  HEARTBEAT LOOP — siempre corriendo, dispara solo si clicking
-- ══════════════════════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function(dt)
    if not clicking then
        accum = 0
        return
    end
    accum = accum + dt
    local shots = m_floor(accum / interval)
    if shots <= 0 then return end
    accum = accum - shots * interval
    local now = hrt()
    for _ = 1, shots do
        fireAllKeys()
        ring_head = (ring_head % RING_SIZE) + 1
        ring[ring_head] = now
    end
end)

-- ══════════════════════════════════════════════════════════════════════════
--  GUI SETUP
-- ══════════════════════════════════════════════════════════════════════════
local FRAME_W = 320
local FRAME_H = 520

local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "MokAaGUI"
screenGui.ResetOnSpawn    = false
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset  = true
screenGui.Parent          = playerGui

local function mkCorner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
end

local function mkLabel(parent, txt, sz, col, font, xa)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size           = sz
    l.Text           = txt
    l.TextColor3     = col or C_WHITE
    l.TextScaled     = true
    l.Font           = font or Enum.Font.GothamBold
    l.TextXAlignment = xa or Enum.TextXAlignment.Center
    l.Parent         = parent
    return l
end

local function mkDivider(y)
    local d = Instance.new("Frame")
    d.Size             = UDim2.new(1, -24, 0, 1)
    d.Position         = UDim2.new(0, 12, 0, y)
    d.BackgroundColor3 = C_BG3_MED
    d.BorderSizePixel  = 0
    d.Parent           = frame
    return d
end

local function mkRowLabel(txt, y)
    return mkLabel(frame, txt,
        UDim2.new(0.5, -10, 0, 14), C_GREY, Enum.Font.Gotham,
        Enum.TextXAlignment.Left,
        UDim2.new(0, 14, 0, y))
end

-- ─── Badge MokAa ──────────────────────────────────────────────────────────
local titleBox = Instance.new("Frame")
titleBox.Name                   = "TitleBox"
titleBox.Size                   = UDim2.new(0, 90, 0, 32)
titleBox.Position               = UDim2.new(0, 20, 0, 20)
titleBox.BackgroundColor3       = C_BG2
titleBox.BorderSizePixel        = 0
titleBox.BackgroundTransparency = 1
titleBox.Parent                 = screenGui
mkCorner(titleBox, 10)

local titleLabel = mkLabel(titleBox, "MokAa",
    UDim2.new(1, 0, 1, 0), C_AMBER, Enum.Font.GothamBold)
titleLabel.TextTransparency = 1

local titleBtn = Instance.new("TextButton")
titleBtn.Size                   = UDim2.new(1, 0, 1, 0)
titleBtn.BackgroundTransparency = 1
titleBtn.Text                   = ""
titleBtn.ZIndex                 = 5
titleBtn.Parent                 = titleBox

-- ─── Main frame ───────────────────────────────────────────────────────────
frame = Instance.new("Frame")
frame.Name                   = "MainFrame"
frame.Size                   = UDim2.new(0, FRAME_W, 0, FRAME_H)
frame.Position               = UDim2.new(0, 20, 0, 20)
frame.BackgroundColor3       = C_BG
frame.BorderSizePixel        = 0
frame.BackgroundTransparency = 1
frame.Visible                = false
frame.Parent                 = screenGui
mkCorner(frame, 14)

-- top accent bar
local topBar = Instance.new("Frame")
topBar.Size                   = UDim2.new(1, -28, 0, 2)
topBar.Position               = UDim2.new(0, 14, 0, 0)
topBar.BackgroundColor3       = C_AMBER
topBar.BorderSizePixel        = 0
topBar.BackgroundTransparency = 0.35
topBar.Parent                 = frame

-- close / minimize button
local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 24, 0, 24)
closeBtn.Position         = UDim2.new(1, -32, 0, 6)
closeBtn.BackgroundColor3 = C_BG3
closeBtn.BorderSizePixel  = 0
closeBtn.Text             = "–"
closeBtn.TextColor3       = C_GREY
closeBtn.TextSize         = 18
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.ZIndex           = 10
closeBtn.Parent           = frame
mkCorner(closeBtn, 5)

closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TI_02, {TextColor3 = C_AMBER}):Play()
end)
closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TI_02, {TextColor3 = C_GREY}):Play()
end)

-- header
local headerLbl = mkLabel(frame, "MokAa",
    UDim2.new(1, 0, 0, 42), C_AMBER, Enum.Font.GothamBold)
headerLbl.Position = UDim2.new(0, 0, 0, 8)

local subLbl = mkLabel(frame, "macro engine",
    UDim2.new(1, 0, 0, 16), C_AMBER_DIM, Enum.Font.Gotham)
subLbl.Position = UDim2.new(0, 0, 0, 48)

local statusDot = Instance.new("Frame")
statusDot.Size             = UDim2.new(0, 9, 0, 9)
statusDot.Position         = UDim2.new(0.5, -4, 0, 67)
statusDot.BackgroundColor3 = C_AMBER_LO
statusDot.BorderSizePixel  = 0
statusDot.Parent           = frame
mkCorner(statusDot, 10)

-- KPS display
local kpsBg = Instance.new("Frame")
kpsBg.Size             = UDim2.new(1, -24, 0, 72)
kpsBg.Position         = UDim2.new(0, 12, 0, 82)
kpsBg.BackgroundColor3 = C_BG2
kpsBg.BorderSizePixel  = 0
kpsBg.Parent           = frame
mkCorner(kpsBg, 10)

local kpsNumber = mkLabel(kpsBg, "0",
    UDim2.new(0.5, 0, 1, 0), C_AMBER, Enum.Font.GothamBold)
kpsNumber.Position = UDim2.new(0, 0, 0, 0)

local kpsUnit = mkLabel(kpsBg, "KPS",
    UDim2.new(0.5, -8, 0, 20), C_GREY, Enum.Font.Gotham,
    Enum.TextXAlignment.Left)
kpsUnit.Position = UDim2.new(0.5, 8, 0, 6)

local kpsTargetLbl = mkLabel(kpsBg, "TARGET: 80",
    UDim2.new(0.5, -8, 0, 16), C_AMBER_DIM, Enum.Font.Gotham,
    Enum.TextXAlignment.Left)
kpsTargetLbl.Position = UDim2.new(0.5, 8, 0, 28)

local instantLbl = mkLabel(kpsBg, "INSTANT START",
    UDim2.new(0.5, -8, 0, 14), C_GREEN, Enum.Font.Gotham,
    Enum.TextXAlignment.Left)
instantLbl.Position = UDim2.new(0.5, 8, 0, 46)

-- ─── KPS TARGET row ───────────────────────────────────────────────────────
local Y = 164

local function mkDividerAt(y)
    local d = Instance.new("Frame")
    d.Size             = UDim2.new(1, -24, 0, 1)
    d.Position         = UDim2.new(0, 12, 0, y)
    d.BackgroundColor3 = C_BG3_MED
    d.BorderSizePixel  = 0
    d.Parent           = frame
end

local function mkRowLbl(txt, y)
    local l = mkLabel(frame, txt,
        UDim2.new(0.45, 0, 0, 14), C_GREY, Enum.Font.Gotham,
        Enum.TextXAlignment.Left)
    l.Position = UDim2.new(0, 14, 0, y)
    return l
end

mkDividerAt(Y)
mkRowLbl("KPS TARGET:", Y + 8)

local btnMinus = Instance.new("TextButton")
btnMinus.Size             = UDim2.new(0, 44, 0, 28)
btnMinus.Position         = UDim2.new(0, 12, 0, Y + 24)
btnMinus.BackgroundColor3 = C_BG3
btnMinus.BorderSizePixel  = 0
btnMinus.Text             = "–"
btnMinus.TextColor3       = C_WHITE
btnMinus.TextScaled       = true
btnMinus.Font             = Enum.Font.GothamBold
btnMinus.Parent           = frame
mkCorner(btnMinus, 7)

local targetNum = mkLabel(frame, "80",
    UDim2.new(0, 100, 0, 28), C_AMBER, Enum.Font.GothamBold)
targetNum.Position = UDim2.new(0.5, -50, 0, Y + 24)

local btnPlus = Instance.new("TextButton")
btnPlus.Size             = UDim2.new(0, 44, 0, 28)
btnPlus.Position         = UDim2.new(1, -56, 0, Y + 24)
btnPlus.BackgroundColor3 = C_BG3
btnPlus.BorderSizePixel  = 0
btnPlus.Text             = "+"
btnPlus.TextColor3       = C_WHITE
btnPlus.TextScaled       = true
btnPlus.Font             = Enum.Font.GothamBold
btnPlus.Parent           = frame
mkCorner(btnPlus, 7)

-- presets
local presetRow = Instance.new("Frame")
presetRow.Size                   = UDim2.new(1, -24, 0, 22)
presetRow.Position               = UDim2.new(0, 12, 0, Y + 58)
presetRow.BackgroundTransparency = 1
presetRow.Parent                 = frame

local presetLayout = Instance.new("UIListLayout")
presetLayout.FillDirection       = Enum.FillDirection.Horizontal
presetLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
presetLayout.Padding             = UDim.new(0, 5)
presetLayout.Parent              = presetRow

local presets    = {20, 80, 200, 500, 2000}
local presetBtns = {}
for _, v in ipairs(presets) do
    local pb = Instance.new("TextButton")
    pb.Size             = UDim2.new(0, 48, 1, 0)
    pb.BackgroundColor3 = C_BG3
    pb.BorderSizePixel  = 0
    pb.Text             = tostr(v)
    pb.TextColor3       = C_GREY
    pb.TextScaled       = true
    pb.Font             = Enum.Font.Gotham
    pb.Parent           = presetRow
    mkCorner(pb, 4)
    table.insert(presetBtns, {btn = pb, val = v})
end

-- ─── MODE row ─────────────────────────────────────────────────────────────
local Y2 = Y + 90

mkDividerAt(Y2)
mkRowLbl("MODE:", Y2 + 8)

local modeBtn = Instance.new("TextButton")
modeBtn.Size             = UDim2.new(0, 110, 0, 24)
modeBtn.Position         = UDim2.new(1, -122, 0, Y2 + 6)
modeBtn.BackgroundColor3 = C_BG3
modeBtn.BorderSizePixel  = 0
modeBtn.Text             = "TOGGLE"
modeBtn.TextColor3       = C_WHITE
modeBtn.TextScaled       = true
modeBtn.Font             = Enum.Font.GothamBold
modeBtn.Parent           = frame
mkCorner(modeBtn, 6)

-- ─── ACTIVATE KEY row ─────────────────────────────────────────────────────
local Y3 = Y2 + 38

mkDividerAt(Y3)
mkRowLbl("ACTIVATE KEY:", Y3 + 8)

local activateBtn = Instance.new("TextButton")
activateBtn.Size             = UDim2.new(0, 60, 0, 24)
activateBtn.Position         = UDim2.new(1, -72, 0, Y3 + 6)
activateBtn.BackgroundColor3 = C_BG3
activateBtn.BorderSizePixel  = 0
activateBtn.Text             = "E"
activateBtn.TextColor3       = C_WHITE
activateBtn.TextScaled       = true
activateBtn.Font             = Enum.Font.GothamBold
activateBtn.Parent           = frame
mkCorner(activateBtn, 6)

-- ─── DEFAULT KEYS (fijos, no configurables) ───────────────────────────────
local Y4 = Y3 + 38

mkDividerAt(Y4)
mkRowLbl("DEFAULT KEYS:", Y4 + 8)

local fixedFrame = Instance.new("Frame")
fixedFrame.Size                   = UDim2.new(1, -24, 0, 28)
fixedFrame.Position               = UDim2.new(0, 12, 0, Y4 + 26)
fixedFrame.BackgroundTransparency = 1
fixedFrame.Parent                 = frame

local fixedLayout = Instance.new("UIListLayout")
fixedLayout.FillDirection       = Enum.FillDirection.Horizontal
fixedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
fixedLayout.Padding             = UDim.new(0, 8)
fixedLayout.Parent              = fixedFrame

for _, txt in ipairs({"F", "MOUSE 1"}) do
    local b = Instance.new("Frame")
    b.Size             = UDim2.new(0, txt == "F" and 50 or 100, 1, 0)
    b.BackgroundColor3 = C_AMBER_LO
    b.BorderSizePixel  = 0
    b.Parent           = fixedFrame
    mkCorner(b, 6)
    mkLabel(b, txt, UDim2.new(1, 0, 1, 0), C_AMBER, Enum.Font.GothamBold)
end

-- ─── EXTRA KEYS (4 slots configurables) ───────────────────────────────────
local Y5 = Y4 + 64

mkDividerAt(Y5)
mkRowLbl("EXTRA KEYS:", Y5 + 8)

local keyGrid = Instance.new("Frame")
keyGrid.Size                   = UDim2.new(1, -24, 0, 70)
keyGrid.Position               = UDim2.new(0, 12, 0, Y5 + 26)
keyGrid.BackgroundTransparency = 1
keyGrid.Parent                 = frame

local keyGridLayout = Instance.new("UIGridLayout")
keyGridLayout.CellSize    = UDim2.new(0.5, -4, 0, 28)
keyGridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
keyGridLayout.Parent      = keyGrid

local spamBtns = {}
for i = 1, 4 do
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, 0, 1, 0)
    btn.BackgroundColor3 = C_BG3
    btn.BorderSizePixel  = 0
    btn.Text             = "SLOT " .. i .. ": —"
    btn.TextColor3       = C_GREY
    btn.TextScaled       = true
    btn.Font             = Enum.Font.GothamBold
    btn.Parent           = keyGrid
    mkCorner(btn, 6)
    spamBtns[i] = btn
end

-- ══════════════════════════════════════════════════════════════════════════
--  OPEN / MINIMIZE
-- ══════════════════════════════════════════════════════════════════════════
local mainOpen = false
local guiOpen  = false

local function openMainGui()
    if mainOpen then return end
    mainOpen = true
    guiOpen  = true
    local tbPos = titleBox.AbsolutePosition
    TweenService:Create(titleBox,   TI_04, {BackgroundTransparency = 1}):Play()
    TweenService:Create(titleLabel, TI_04, {TextTransparency = 1}):Play()
    task.delay(0.2, function()
        titleBox.Visible = false
        frame.Position   = UDim2.new(0, tbPos.X, 0, tbPos.Y)
        frame.Size       = UDim2.new(0, FRAME_W, 0, 36)
        frame.BackgroundTransparency = 0
        frame.Visible    = true
        TweenService:Create(frame, TI_06,
            {Size = UDim2.new(0, FRAME_W, 0, FRAME_H)}):Play()
    end)
end

local function minimizeGui()
    if not mainOpen then return end
    mainOpen = false
    guiOpen  = false
    local fPos = frame.AbsolutePosition
    TweenService:Create(frame, TI_04, {
        Size                 = UDim2.new(0, FRAME_W, 0, 36),
        BackgroundTransparency = 1,
    }):Play()
    task.delay(0.3, function()
        frame.Visible     = false
        frame.Size        = UDim2.new(0, FRAME_W, 0, FRAME_H)
        titleBox.Position = UDim2.new(0, fPos.X, 0, fPos.Y)
        titleBox.Visible  = true
        TweenService:Create(titleBox,   TI_05, {BackgroundTransparency = 0}):Play()
        TweenService:Create(titleLabel, TI_05, {
            TextTransparency = 0,
            TextColor3       = clicking and C_AMBER or C_GREY,
        }):Play()
    end)
end

-- badge interactions
local tbDidDrag   = false
local tbPending   = false
local tbPendDownX = 0
local tbPendDownY = 0

titleBtn.MouseEnter:Connect(function()
    TweenService:Create(titleLabel, TI_02, {TextColor3 = C_WHITE}):Play()
end)
titleBtn.MouseLeave:Connect(function()
    TweenService:Create(titleLabel, TI_02,
        {TextColor3 = clicking and C_AMBER or C_GREY}):Play()
end)
titleBtn.MouseButton1Click:Connect(function()
    if not tbDidDrag then openMainGui() end
end)

closeBtn.MouseButton1Click:Connect(function()
    minimizeGui()
end)

-- startup animation
task.spawn(function()
    task.wait(0.4)
    titleBox.Visible = true
    TweenService:Create(titleBox, TI_05, {BackgroundTransparency = 0}):Play()
    task.wait(0.15)
    TweenService:Create(titleLabel,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {TextTransparency = 0}):Play()
end)

-- ══════════════════════════════════════════════════════════════════════════
--  KEY BIND
-- ══════════════════════════════════════════════════════════════════════════
local waitingForKey = false

local function bindKey(btn, blockedKeys, onSuccess)
    if waitingForKey then return end
    waitingForKey  = true
    local prev     = btn.Text
    btn.Text       = "..."
    btn.TextColor3 = C_GREY
    local conn
    conn = UIS.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        for _, blocked in ipairs(blockedKeys) do
            if input.KeyCode == blocked then
                btn.Text = "!"
                task.delay(0.8, function()
                    btn.Text       = prev
                    btn.TextColor3 = C_WHITE
                    waitingForKey  = false
                end)
                conn:Disconnect(); return
            end
        end
        local name = tostr(input.KeyCode.Name)
        if #name > 6 then name = string.sub(name, 1, 6) end
        btn.Text       = name
        btn.TextColor3 = C_WHITE
        waitingForKey  = false
        onSuccess(input.KeyCode)
        conn:Disconnect()
    end)
end

activateBtn.MouseButton1Click:Connect(function()
    local blocked = {}
    for i = 1, 4 do
        if spam_keys[i] ~= Enum.KeyCode.Unknown then
            table.insert(blocked, spam_keys[i])
        end
    end
    bindKey(activateBtn, blocked, function(key)
        TOGGLE_KEY = key
        local name = tostr(key.Name)
        activateBtn.Text = #name > 6 and string.sub(name, 1, 6) or name
    end)
end)

for i = 1, 4 do
    local btn = spamBtns[i]
    btn.MouseButton1Click:Connect(function()
        local blocked = {TOGGLE_KEY}
        for j = 1, 4 do
            if j ~= i and spam_keys[j] ~= Enum.KeyCode.Unknown then
                table.insert(blocked, spam_keys[j])
            end
        end
        bindKey(btn, blocked, function(key)
            spam_keys[i]         = key
            spam_keys_enabled[i] = true
            local name = tostr(key.Name)
            if #name > 6 then name = string.sub(name, 1, 6) end
            btn.Text       = "S" .. i .. ": " .. name
            btn.TextColor3 = C_AMBER
            TweenService:Create(btn, TI_02, {BackgroundColor3 = C_AMBER_LO}):Play()
        end)
    end)
    btn.MouseButton2Click:Connect(function()
        spam_keys[i]         = Enum.KeyCode.Unknown
        spam_keys_enabled[i] = false
        btn.Text             = "SLOT " .. i .. ": —"
        btn.TextColor3       = C_GREY
        TweenService:Create(btn, TI_02, {BackgroundColor3 = C_BG3}):Play()
    end)
end

-- ══════════════════════════════════════════════════════════════════════════
--  MODE
-- ══════════════════════════════════════════════════════════════════════════
modeBtn.MouseButton1Click:Connect(function()
    holdMode     = not holdMode
    modeBtn.Text = holdMode and "HOLD" or "TOGGLE"
    if holdMode and clicking then
        clicking              = false
        accum                 = 0
        statusDot.BackgroundColor3 = C_AMBER_LO
        kpsNumber.Text        = "0"
        last_tier             = -1
        titleLabel.TextColor3 = C_GREY
    end
end)

-- ══════════════════════════════════════════════════════════════════════════
--  KPS CONTROLS
-- ══════════════════════════════════════════════════════════════════════════
local targetKPS = 80

local function updateTarget(newVal)
    targetKPS            = m_clamp(newVal, 1, 2000)
    targetNum.Text       = tostr(targetKPS)
    kpsTargetLbl.Text    = "TARGET: " .. tostr(targetKPS)
    applyKPS(targetKPS)
end

local function holdButton(btn, delta)
    local held = false
    btn.MouseButton1Down:Connect(function()
        held = true
        updateTarget(targetKPS + delta)
        task.spawn(function()
            task.wait(0.4)
            while held do
                updateTarget(targetKPS + delta)
                task.wait(0.06)
            end
        end)
    end)
    btn.MouseButton1Up:Connect(function()  held = false end)
    btn.MouseLeave:Connect(function()      held = false end)
end

holdButton(btnMinus, -1)
holdButton(btnPlus,   1)
btnMinus.MouseButton2Click:Connect(function() updateTarget(targetKPS - 10) end)
btnPlus.MouseButton2Click:Connect(function()  updateTarget(targetKPS + 10) end)

for _, pd in ipairs(presetBtns) do
    pd.btn.MouseButton1Click:Connect(function()
        updateTarget(pd.val)
        for _, o in ipairs(presetBtns) do
            TweenService:Create(o.btn, TI_015, {
                TextColor3       = o.val == pd.val and C_AMBER or C_GREY,
                BackgroundColor3 = o.val == pd.val and C_AMBER_LO or C_BG3,
            }):Play()
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════
--  START / STOP
-- ══════════════════════════════════════════════════════════════════════════
local function startClicking()
    if clicking then return end
    clicking              = true
    accum                 = 0
    last_tier             = -1
    statusDot.BackgroundColor3 = C_AMBER
    if not guiOpen then
        titleLabel.TextColor3 = C_AMBER
    end
end

local function stopClicking()
    if not clicking then return end
    clicking              = false
    accum                 = 0
    statusDot.BackgroundColor3 = C_AMBER_LO
    kpsNumber.Text        = "0"
    last_tier             = -1
    titleLabel.TextColor3 = C_GREY
end

UIS.InputBegan:Connect(function(input, _)
    if waitingForKey then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode ~= TOGGLE_KEY then return end
    if holdMode then
        startClicking()
    else
        if clicking then stopClicking() else startClicking() end
    end
end)

UIS.InputEnded:Connect(function(input)
    if waitingForKey then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode ~= TOGGLE_KEY then return end
    if holdMode then stopClicking() end
end)

-- ══════════════════════════════════════════════════════════════════════════
--  DRAG — corregido: offset calculado correctamente con AbsolutePosition
-- ══════════════════════════════════════════════════════════════════════════
local dragActive  = false
local dragTarget  = nil
local dragOffX    = 0
local dragOffY    = 0
local THRESH      = 6

-- Drag del main frame
frame.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    dragActive = true
    dragTarget = frame
    dragOffX   = input.Position.X - frame.AbsolutePosition.X
    dragOffY   = input.Position.Y - frame.AbsolutePosition.Y
end)

-- Drag del badge
titleBtn.MouseButton1Down:Connect(function(input)
    tbPending   = true
    tbDidDrag   = false
    tbPendDownX = input.Position.X
    tbPendDownY = input.Position.Y
    dragOffX    = input.Position.X - titleBox.AbsolutePosition.X
    dragOffY    = input.Position.Y - titleBox.AbsolutePosition.Y
end)

UIS.InputChanged:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

    -- detectar si el badge empieza a arrastrarse
    if tbPending and not tbDidDrag then
        local dx = input.Position.X - tbPendDownX
        local dy = input.Position.Y - tbPendDownY
        if dx*dx + dy*dy >= THRESH*THRESH then
            tbDidDrag  = true
            dragActive = true
            dragTarget = titleBox
        end
    end

    if not dragActive or not dragTarget then return end

    local ss  = screenGui.AbsoluteSize
    local fs  = dragTarget.AbsoluteSize
    local newX = m_clamp(input.Position.X - dragOffX, 0, ss.X - fs.X)
    local newY = m_clamp(input.Position.Y - dragOffY, 0, ss.Y - fs.Y)
    dragTarget.Position = UDim2.new(0, newX, 0, newY)
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    dragActive = false
    dragTarget = nil
    tbPending  = false
end)

-- ══════════════════════════════════════════════════════════════════════════
--  LIVE KPS COUNTER
-- ══════════════════════════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(0.2)
        if not clicking then continue end
        local now    = hrt()
        local cutoff = now - 1
        local count  = 0
        for i = 1, RING_SIZE do
            if ring[i] > cutoff then count = count + 1 end
        end
        local str = tostr(count)
        if str ~= last_count_str then
            last_count_str = str
            if guiOpen then
                kpsNumber.Text = str
            end
        end
        if not guiOpen then continue end
        local tier
        if     count >= 500 then tier = 3
        elseif count >= 200 then tier = 2
        elseif count >= 80  then tier = 1
        else                      tier = 0
        end
        if tier ~= last_tier then
            last_tier            = tier
            kpsNumber.TextColor3 = tier == 3 and C_WHITE
                                or tier == 2 and C_AMBER
                                or tier == 1 and C_AMBER_DIM
                                or C_GREY
        end
    end
end)

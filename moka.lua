-- ╔══════════════════════════════════════════╗
-- ║           M O K A  v2.1                  ║
-- ║     High-precision macro engine          ║
-- ╚══════════════════════════════════════════╝

local clicking  = false
local holdMode  = false
local KPS       = 80
local interval  = 1 / KPS

-- ─── PI Controller ────────────────────────────────────────────────────────
local pi_integral     = 0
local PI_INTEGRAL_CAP = 2 * interval
local PI_DEADBAND     = interval * 0.015
local PI_KP           = 0.35
local PI_KI           = 0.012
local EMA_ALPHA       = 0.12
local EMA_ONE_MINUS   = 1 - EMA_ALPHA
local PI_DECAY        = 1 - (1/512)

local drift_accum = 0
local pi_residual = 0

local tick_n_absolute  = 0
local suppressed_count = 0
local session_start    = 0
local ema_error        = 0
local phase_offset     = 0

local nano_cd  = 16
local micro_cd = 64

local NANO_CLAMP      = interval * 0.2
local MICRO_CLAMP     = interval * 0.4
local NANO_GAIN       = 0.05
local MICRO_GAIN      = 0.15
local HALF_INTERVAL   = interval * 0.5
local MAX_LAG         = interval

-- ─── Ring buffer for real-time KPS ────────────────────────────────────────
local RING_SIZE      = 512
local ring           = table.create(RING_SIZE, 0)
local ring_head      = 0
local last_tier      = -1
local last_count_str = "0"

-- ─── Keys ─────────────────────────────────────────────────────────────────
local TOGGLE_KEY = Enum.KeyCode.E
local SPAM_KEY1  = Enum.KeyCode.F
local SPAM_KEY2  = Enum.KeyCode.Unknown
local SPAM_KEY3  = Enum.KeyCode.Unknown
local SPAM_KEY4  = Enum.KeyCode.Unknown

local spam_keys_enabled = {true, false, false, false}
local spam_keys         = {SPAM_KEY1, SPAM_KEY2, SPAM_KEY3, SPAM_KEY4}

-- ─── Services / shortcuts ─────────────────────────────────────────────────
local UIS          = game:GetService("UserInputService")
local VIM          = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")
local player       = Players.LocalPlayer
local playerGui    = player:WaitForChild("PlayerGui")

local hrt       = os.clock
local task_wait = task.wait
local m_floor   = math.floor
local m_abs     = math.abs
local m_clamp   = math.clamp
local tostr     = tostring

-- ─── Colors (Coffee / Amber theme) ────────────────────────────────────────
local C_BG        = Color3.fromRGB(10,  8,   6)
local C_BG2       = Color3.fromRGB(18,  14,  10)
local C_BG3       = Color3.fromRGB(28,  22,  16)
local C_AMBER     = Color3.fromRGB(255, 165, 50)
local C_AMBER_DIM = Color3.fromRGB(140, 90,  25)
local C_AMBER_LO  = Color3.fromRGB(60,  42,  18)
local C_WHITE     = Color3.fromRGB(240, 230, 215)
local C_GREY      = Color3.fromRGB(140, 128, 110)
local C_DARK_STK  = Color3.fromRGB(55,  42,  25)
local C_ON_STK    = Color3.fromRGB(255, 165, 50)

-- ─── TweenInfos ───────────────────────────────────────────────────────────
local TI_02  = TweenInfo.new(0.2)
local TI_03  = TweenInfo.new(0.3)
local TI_015 = TweenInfo.new(0.15)
local TI_04  = TweenInfo.new(0.4, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TI_05  = TweenInfo.new(0.5, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TI_06  = TweenInfo.new(0.6, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)

-- ══════════════════════════════════════════════════════════════════════════
--  CORE LOGIC
-- ══════════════════════════════════════════════════════════════════════════

local function applyKPS(newKPS)
    KPS             = m_clamp(newKPS, 1, 2000)
    interval        = 1 / KPS
    PI_INTEGRAL_CAP = 2 * interval
    PI_DEADBAND     = interval * 0.015
    NANO_CLAMP      = interval * 0.2
    MICRO_CLAMP     = interval * 0.4
    HALF_INTERVAL   = interval * 0.5
    MAX_LAG         = interval
end

local function fireAllKeys()
    for i = 1, 4 do
        if spam_keys_enabled[i] and spam_keys[i] ~= Enum.KeyCode.Unknown then
            VIM:SendKeyEvent(true,  spam_keys[i], false, game)
            VIM:SendKeyEvent(false, spam_keys[i], false, game)
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════
--  FPS FIX: eliminado busy-wait loop, reemplazado con task.wait()
-- ══════════════════════════════════════════════════════════════════════════
local function spam_loop()
    task_wait(0.05)
    if not clicking then return end

    pi_integral      = 0
    pi_residual      = 0
    ema_error        = 0
    drift_accum      = 0
    tick_n_absolute  = 0
    suppressed_count = 0
    phase_offset     = 0
    nano_cd          = 16
    micro_cd         = 64
    ring_head        = 0
    for i = 1, RING_SIZE do ring[i] = 0 end
    EMA_ONE_MINUS = 1 - EMA_ALPHA

    session_start = hrt()

    while clicking do
        local next_fire = session_start
            + (tick_n_absolute - suppressed_count) * interval
            + phase_offset

        -- FPS FIX: sin busy-wait, cedemos el hilo a Roblox
        local remaining = next_fire - hrt()
        if remaining > 0.001 then
            task_wait(remaining * 0.85)
        end
        task_wait() -- cede el hilo para que Roblox renderice

        if not clicking then break end

        local fire_time = hrt()
        fireAllKeys()

        tick_n_absolute = tick_n_absolute + 1
        ring_head       = (ring_head % RING_SIZE) + 1
        ring[ring_head] = fire_time

        local abs_elapsed  = fire_time - session_start
        local abs_expected = (tick_n_absolute - suppressed_count) * interval

        -- Nano correction (every 16 ticks)
        nano_cd = nano_cd - 1
        if nano_cd == 0 then
            nano_cd = 16
            local err = abs_elapsed - abs_expected
            if err >  NANO_CLAMP then err =  NANO_CLAMP
            elseif err < -NANO_CLAMP then err = -NANO_CLAMP end
            phase_offset = phase_offset - err * NANO_GAIN
        end

        -- Micro correction (every 64 ticks)
        micro_cd = micro_cd - 1
        if micro_cd == 0 then
            micro_cd = 64
            local err = abs_elapsed - abs_expected
            if err >  MICRO_CLAMP then err =  MICRO_CLAMP
            elseif err < -MICRO_CLAMP then err = -MICRO_CLAMP end
            phase_offset = phase_offset - err * MICRO_GAIN
        end

        -- PI Controller
        local raw_error = abs_elapsed - abs_expected
        ema_error = EMA_ONE_MINUS * ema_error + EMA_ALPHA * raw_error
        local error = ema_error

        if error > PI_DEADBAND or error < -PI_DEADBAND then
            pi_integral = pi_integral + error
            if pi_integral >  PI_INTEGRAL_CAP then pi_integral =  PI_INTEGRAL_CAP
            elseif pi_integral < -PI_INTEGRAL_CAP then pi_integral = -PI_INTEGRAL_CAP end
            local correction = PI_KP * error + PI_KI * pi_integral
            drift_accum = drift_accum + correction
            local carry = m_floor(drift_accum / interval + 0.5) * interval
            drift_accum = drift_accum - carry
            pi_residual = pi_residual + (correction - carry)
            local res_carry = m_floor(pi_residual / interval + 0.5) * interval
            pi_residual = pi_residual - res_carry
            phase_offset = phase_offset - correction
        else
            pi_integral = pi_integral * PI_DECAY
        end

        -- Lag recovery
        local now        = hrt()
        local next_ideal = session_start
            + (tick_n_absolute - suppressed_count) * interval
            + phase_offset
        local lag = now - next_ideal

        if lag > MAX_LAG then
            session_start = now
                - (tick_n_absolute - suppressed_count) * interval
                - phase_offset
            suppressed_count = suppressed_count + 1
        elseif lag > HALF_INTERVAL then
            session_start = session_start + lag * 0.5
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════
--  GUI  (GUI más ancha: 260px → 320px)
-- ══════════════════════════════════════════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "MokaGUI"
screenGui.ResetOnSpawn    = false
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.Parent          = playerGui

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thick, trans)
    local s = Instance.new("UIStroke")
    s.Color        = color or C_DARK_STK
    s.Thickness    = thick or 1.2
    s.Transparency = trans or 0
    s.Parent       = parent
    return s
end

local function label(parent, text, size, color, font, xalign)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size        = size
    l.Text        = text
    l.TextColor3  = color or C_WHITE
    l.TextScaled  = true
    l.Font        = font or Enum.Font.GothamBold
    l.TextXAlignment = xalign or Enum.TextXAlignment.Center
    l.Parent      = parent
    return l
end

-- ─── Dimensiones GUI más ancha ────────────────────────────────────────────
local FRAME_W = 320
local FRAME_H = 440

-- ─── Title badge ──────────────────────────────────────────────────────────
local titleBox = Instance.new("Frame")
titleBox.Name                = "TitleBox"
titleBox.Size                = UDim2.new(0, 120, 0, 38)
titleBox.Position            = UDim2.new(0.5, -60, 0.5, -19)
titleBox.BackgroundColor3    = C_BG2
titleBox.BorderSizePixel     = 0
titleBox.BackgroundTransparency = 1
titleBox.Parent              = screenGui
corner(titleBox, 10)

local titleStroke = stroke(titleBox, C_DARK_STK, 1.5, 1)

local titleLabel = label(titleBox, "MOKA  v2.1",
    UDim2.new(1, 0, 1, 0), C_AMBER, Enum.Font.GothamBold)
titleLabel.TextTransparency = 1

local titleBtn = Instance.new("TextButton")
titleBtn.Size                = UDim2.new(1, 0, 1, 0)
titleBtn.BackgroundTransparency = 1
titleBtn.Text                = ""
titleBtn.Parent              = titleBox

-- ─── Main frame ───────────────────────────────────────────────────────────
local frame = Instance.new("Frame")
frame.Name               = "MainFrame"
frame.Size               = UDim2.new(0, FRAME_W, 0, FRAME_H)
frame.Position           = UDim2.new(0.5, -FRAME_W/2, 0.5, -FRAME_H/2)
frame.BackgroundColor3   = C_BG
frame.BorderSizePixel    = 0
frame.BackgroundTransparency = 1
frame.Visible            = false
frame.Parent             = screenGui
corner(frame, 14)

local mainStroke = stroke(frame, C_DARK_STK, 1.5, 1)

local topBar = Instance.new("Frame")
topBar.Size              = UDim2.new(1, -28, 0, 2)
topBar.Position          = UDim2.new(0, 14, 0, 0)
topBar.BackgroundColor3  = C_AMBER
topBar.BorderSizePixel   = 0
topBar.BackgroundTransparency = 0.3
topBar.Parent            = frame

-- ─── Close button ─────────────────────────────────────────────────────────
local closeBtn = Instance.new("TextButton")
closeBtn.Size            = UDim2.new(0, 22, 0, 22)
closeBtn.Position        = UDim2.new(1, -30, 0, 7)
closeBtn.BackgroundColor3 = C_BG3
closeBtn.BorderSizePixel = 0
closeBtn.Text            = "×"
closeBtn.TextColor3      = C_GREY
closeBtn.TextSize        = 17
closeBtn.Font            = Enum.Font.GothamBold
closeBtn.ZIndex          = 10
closeBtn.Parent          = frame
corner(closeBtn, 5)

closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TI_02, {TextColor3 = C_AMBER}):Play()
end)
closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TI_02, {TextColor3 = C_GREY}):Play()
end)

-- ─── Header ───────────────────────────────────────────────────────────────
local headerLbl = label(frame, "MOKA",
    UDim2.new(1, 0, 0, 40), C_AMBER, Enum.Font.GothamBold)
headerLbl.Position = UDim2.new(0, 0, 0, 8)

local subLbl = label(frame, "macro engine  v2.1",
    UDim2.new(1, 0, 0, 15), C_AMBER_DIM, Enum.Font.Gotham)
subLbl.Position = UDim2.new(0, 0, 0, 46)

local statusDot = Instance.new("Frame")
statusDot.Size            = UDim2.new(0, 9, 0, 9)
statusDot.Position        = UDim2.new(0.5, -4, 0, 64)
statusDot.BackgroundColor3 = C_AMBER_LO
statusDot.BorderSizePixel = 0
statusDot.Parent          = frame
corner(statusDot, 10)

-- ─── KPS display (más ancho) ──────────────────────────────────────────────
local kpsBg = Instance.new("Frame")
kpsBg.Size             = UDim2.new(1, -24, 0, 70)
kpsBg.Position         = UDim2.new(0, 12, 0, 78)
kpsBg.BackgroundColor3 = C_BG2
kpsBg.BorderSizePixel  = 0
kpsBg.Parent           = frame
corner(kpsBg, 10)
stroke(kpsBg, C_DARK_STK, 1)

local kpsNumber = label(kpsBg, "0",
    UDim2.new(0.55, 0, 1, 0), C_AMBER, Enum.Font.GothamBold)
kpsNumber.Position = UDim2.new(0, 0, 0, 0)

local kpsUnit = label(kpsBg, "KPS",
    UDim2.new(0.45, -8, 0, 20), C_GREY, Enum.Font.Gotham)
kpsUnit.Position = UDim2.new(0.55, 0, 0, 6)
kpsUnit.TextXAlignment = Enum.TextXAlignment.Left

local kpsTarget = label(kpsBg, "TARGET: 80",
    UDim2.new(0.45, -8, 0, 15), C_AMBER_DIM, Enum.Font.Gotham)
kpsTarget.Position = UDim2.new(0.55, 0, 0, 28)
kpsTarget.TextXAlignment = Enum.TextXAlignment.Left

-- FPS label (nuevo)
local fpsLabel = label(kpsBg, "FPS-SAFE MODE",
    UDim2.new(0.45, -8, 0, 13), Color3.fromRGB(80, 180, 80), Enum.Font.Gotham)
fpsLabel.Position = UDim2.new(0.55, 0, 0, 46)
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left

-- ─── Helpers ──────────────────────────────────────────────────────────────
local function divider(y)
    local d = Instance.new("Frame")
    d.Size             = UDim2.new(1, -24, 0, 1)
    d.Position         = UDim2.new(0, 12, 0, y)
    d.BackgroundColor3 = C_BG3
    d.BorderSizePixel  = 0
    d.Parent           = frame
end

local function rowLabel(text, y)
    local l = label(frame, text,
        UDim2.new(0.5, -10, 0, 14), C_GREY, Enum.Font.Gotham,
        Enum.TextXAlignment.Left)
    l.Position = UDim2.new(0, 14, 0, y)
    return l
end

local function makeKeyBtn(txt, x, y, w)
    local btn = Instance.new("TextButton")
    btn.Size              = UDim2.new(0, w or 54, 0, 24)
    btn.Position          = UDim2.new(0, x, 0, y)
    btn.BackgroundColor3  = C_BG3
    btn.BorderSizePixel   = 0
    btn.Text              = txt
    btn.TextColor3        = C_WHITE
    btn.TextScaled        = true
    btn.Font              = Enum.Font.GothamBold
    btn.Parent            = frame
    corner(btn, 6)
    local s = stroke(btn, C_DARK_STK, 1)
    return btn, s
end

-- ─── KPS row ──────────────────────────────────────────────────────────────
divider(158)
rowLabel("KPS TARGET:", 166)

local btnMinus = Instance.new("TextButton")
btnMinus.Size             = UDim2.new(0, 44, 0, 28)
btnMinus.Position         = UDim2.new(0, 12, 0, 182)
btnMinus.BackgroundColor3 = C_BG3
btnMinus.BorderSizePixel  = 0
btnMinus.Text             = "–"
btnMinus.TextColor3       = C_WHITE
btnMinus.TextScaled       = true
btnMinus.Font             = Enum.Font.GothamBold
btnMinus.Parent           = frame
corner(btnMinus, 7)

local targetNum = label(frame, "80",
    UDim2.new(0, 90, 0, 28), C_AMBER, Enum.Font.GothamBold)
targetNum.Position = UDim2.new(0.5, -45, 0, 182)

local btnPlus = Instance.new("TextButton")
btnPlus.Size             = UDim2.new(0, 44, 0, 28)
btnPlus.Position         = UDim2.new(1, -56, 0, 182)
btnPlus.BackgroundColor3 = C_BG3
btnPlus.BorderSizePixel  = 0
btnPlus.Text             = "+"
btnPlus.TextColor3       = C_WHITE
btnPlus.TextScaled       = true
btnPlus.Font             = Enum.Font.GothamBold
btnPlus.Parent           = frame
corner(btnPlus, 7)

-- Presets (más espacio con GUI ancha)
local presetRow = Instance.new("Frame")
presetRow.Size             = UDim2.new(1, -24, 0, 20)
presetRow.Position         = UDim2.new(0, 12, 0, 216)
presetRow.BackgroundTransparency = 1
presetRow.Parent           = frame

local presetList = Instance.new("UIListLayout")
presetList.FillDirection   = Enum.FillDirection.Horizontal
presetList.HorizontalAlignment = Enum.HorizontalAlignment.Center
presetList.Padding         = UDim.new(0, 6)
presetList.Parent          = presetRow

local presets = {20, 80, 200, 500, 2000}
local presetBtns = {}
for _, v in ipairs(presets) do
    local pb = Instance.new("TextButton")
    pb.Size             = UDim2.new(0, 46, 1, 0)
    pb.BackgroundColor3 = C_BG3
    pb.BorderSizePixel  = 0
    pb.Text             = tostr(v)
    pb.TextColor3       = C_GREY
    pb.TextScaled       = true
    pb.Font             = Enum.Font.Gotham
    pb.Parent           = presetRow
    corner(pb, 4)
    stroke(pb, C_DARK_STK, 1)
    table.insert(presetBtns, {btn=pb, val=v})
end

-- ─── Mode row ─────────────────────────────────────────────────────────────
divider(244)
rowLabel("MODE:", 252)

local modeBtn = Instance.new("TextButton")
modeBtn.Size             = UDim2.new(0, 100, 0, 22)
modeBtn.Position         = UDim2.new(1, -112, 0, 250)
modeBtn.BackgroundColor3 = C_BG3
modeBtn.BorderSizePixel  = 0
modeBtn.Text             = "TOGGLE"
modeBtn.TextColor3       = C_WHITE
modeBtn.TextScaled       = true
modeBtn.Font             = Enum.Font.GothamBold
modeBtn.Parent           = frame
corner(modeBtn, 6)
local modeStroke = stroke(modeBtn, C_DARK_STK, 1)

-- ─── ACTIVATE row ─────────────────────────────────────────────────────────
divider(280)
rowLabel("ACTIVATE KEY:", 288)
local activateBtn, activateStroke = makeKeyBtn("E", FRAME_W - 74, 285)

-- ─── 4 Spam Keys (grid 2x2 más ancho) ────────────────────────────────────
divider(318)
rowLabel("SPAM KEYS:", 326)

local keyGrid = Instance.new("Frame")
keyGrid.Size             = UDim2.new(1, -24, 0, 62)
keyGrid.Position         = UDim2.new(0, 12, 0, 344)
keyGrid.BackgroundTransparency = 1
keyGrid.Parent           = frame

local keyLayout = Instance.new("UIGridLayout")
keyLayout.CellSize       = UDim2.new(0.5, -4, 0, 26)
keyLayout.CellPadding    = UDim2.new(0, 6, 0, 6)
keyLayout.Parent         = keyGrid

local spamBtnDefs = {
    {label="KEY 1: F",  key=SPAM_KEY1, idx=1},
    {label="KEY 2: —",  key=SPAM_KEY2, idx=2},
    {label="KEY 3: —",  key=SPAM_KEY3, idx=3},
    {label="KEY 4: —",  key=SPAM_KEY4, idx=4},
}

local spamBtns    = {}
local spamStrokes = {}

for i, def in ipairs(spamBtnDefs) do
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, 0, 1, 0)
    btn.BackgroundColor3 = i == 1 and C_AMBER_LO or C_BG3
    btn.BorderSizePixel  = 0
    btn.Text             = def.label
    btn.TextColor3       = i == 1 and C_AMBER or C_GREY
    btn.TextScaled       = true
    btn.Font             = Enum.Font.GothamBold
    btn.Parent           = keyGrid
    corner(btn, 6)
    local s = stroke(btn, i == 1 and C_AMBER_DIM or C_DARK_STK, 1)
    spamBtns[i]    = btn
    spamStrokes[i] = s
end

-- ─── Open / Close helpers ─────────────────────────────────────────────────
local mainOpen = false

local function openMainGui()
    if mainOpen then return end
    mainOpen = true
    local tbPos = titleBox.AbsolutePosition
    TweenService:Create(titleBox,    TI_04, {BackgroundTransparency = 1}):Play()
    TweenService:Create(titleStroke, TI_04, {Transparency = 1}):Play()
    TweenService:Create(titleLabel,  TI_04, {TextTransparency = 1}):Play()
    task.delay(0.25, function()
        titleBox.Visible = false
        frame.Position   = UDim2.new(0, tbPos.X, 0, tbPos.Y)
        frame.Size       = UDim2.new(0, FRAME_W, 0, 36)
        frame.BackgroundTransparency = 0
        frame.Visible    = true
        TweenService:Create(frame,       TI_06, {Size = UDim2.new(0, FRAME_W, 0, FRAME_H)}):Play()
        TweenService:Create(mainStroke,  TI_05, {Transparency = 0}):Play()
    end)
end

local function closeMainGui()
    if not mainOpen then return end
    mainOpen = false
    local fPos = frame.AbsolutePosition
    TweenService:Create(frame,      TI_04, {Size = UDim2.new(0, FRAME_W, 0, 36), BackgroundTransparency = 1}):Play()
    TweenService:Create(mainStroke, TI_04, {Transparency = 1}):Play()
    task.delay(0.35, function()
        frame.Visible = false
        frame.Size    = UDim2.new(0, FRAME_W, 0, FRAME_H)
        titleBox.Position = UDim2.new(0, fPos.X, 0, fPos.Y)
        titleBox.Visible  = true
        TweenService:Create(titleBox,    TI_05, {BackgroundTransparency = 0}):Play()
        TweenService:Create(titleStroke, TI_05, {Transparency = 0}):Play()
        TweenService:Create(titleLabel,  TI_05, {TextTransparency = 0}):Play()
    end)
end

-- ─── Title badge interactions ─────────────────────────────────────────────
local tbDidDrag = false

titleBtn.MouseEnter:Connect(function()
    TweenService:Create(titleStroke, TI_02, {Color = C_ON_STK}):Play()
    TweenService:Create(titleLabel,  TI_02, {TextColor3 = C_WHITE}):Play()
end)
titleBtn.MouseLeave:Connect(function()
    TweenService:Create(titleStroke, TI_02, {Color = C_DARK_STK}):Play()
    TweenService:Create(titleLabel,  TI_02, {TextColor3 = C_AMBER}):Play()
end)
titleBtn.MouseButton1Click:Connect(function()
    if not tbDidDrag then openMainGui() end
end)

closeBtn.MouseButton1Click:Connect(function()
    if clicking then
        clicking = false
        TweenService:Create(statusDot, TI_02, {BackgroundColor3 = C_AMBER_LO}):Play()
        TweenService:Create(mainStroke,TI_02, {Color = C_DARK_STK}):Play()
        kpsNumber.Text = "0"
        last_tier = -1
    end
    closeMainGui()
end)

-- ─── Startup animation ────────────────────────────────────────────────────
task.spawn(function()
    task_wait(0.3)
    titleBox.Visible = true
    TweenService:Create(titleBox,    TI_05, {BackgroundTransparency = 0}):Play()
    TweenService:Create(titleStroke, TI_05, {Transparency = 0}):Play()
    task_wait(0.1)
    TweenService:Create(titleLabel,
        TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {TextTransparency = 0}):Play()
    task_wait(0.7)
    TweenService:Create(titleStroke, TI_03, {Color = C_ON_STK}):Play()
    task_wait(0.4)
    TweenService:Create(titleStroke, TI_03, {Color = C_DARK_STK}):Play()
end)

-- ─── Key-bind helper ──────────────────────────────────────────────────────
local waitingForKey = false

local function bindKey(btn, btnStroke, blockedKeys, onSuccess)
    if waitingForKey then return end
    waitingForKey = true
    local prev = btn.Text
    btn.Text       = "..."
    btn.TextColor3 = C_GREY
    TweenService:Create(btnStroke, TI_02, {Color = C_GREY}):Play()

    local conn
    conn = UIS.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        for _, blocked in ipairs(blockedKeys) do
            if input.KeyCode == blocked then
                btn.Text = "!"
                task.delay(0.8, function()
                    btn.Text       = prev
                    btn.TextColor3 = C_WHITE
                    TweenService:Create(btnStroke, TI_02, {Color = C_DARK_STK}):Play()
                    waitingForKey = false
                end)
                conn:Disconnect(); return
            end
        end
        local name = tostr(input.KeyCode.Name)
        if #name > 6 then name = string.sub(name, 1, 6) end
        btn.Text       = name
        btn.TextColor3 = C_WHITE
        TweenService:Create(btnStroke, TI_02, {Color = C_DARK_STK}):Play()
        waitingForKey = false
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
    bindKey(activateBtn, activateStroke, blocked, function(key)
        TOGGLE_KEY = key
    end)
end)

for i = 1, 4 do
    local btn = spamBtns[i]
    local s   = spamStrokes[i]

    btn.MouseButton1Click:Connect(function()
        local blocked = {TOGGLE_KEY}
        for j = 1, 4 do
            if j ~= i and spam_keys[j] ~= Enum.KeyCode.Unknown then
                table.insert(blocked, spam_keys[j])
            end
        end

        bindKey(btn, s, blocked, function(key)
            spam_keys[i] = key
            spam_keys_enabled[i] = true

            local name = tostr(key.Name)
            if #name > 6 then name = string.sub(name, 1, 6) end
            btn.Text       = "K" .. i .. ": " .. name
            btn.TextColor3 = C_AMBER
            TweenService:Create(btn, TI_02, {BackgroundColor3 = C_AMBER_LO}):Play()
            TweenService:Create(s,   TI_02, {Color = C_AMBER_DIM}):Play()

            if clicking then
                clicking = false; task_wait(0.02)
                clicking = true;  task.spawn(spam_loop)
            end
        end)
    end)

    btn.MouseButton2Click:Connect(function()
        if i == 1 then return end
        spam_keys[i]         = Enum.KeyCode.Unknown
        spam_keys_enabled[i] = false
        btn.Text       = "K" .. i .. ": —"
        btn.TextColor3 = C_GREY
        TweenService:Create(btn, TI_02, {BackgroundColor3 = C_BG3}):Play()
        TweenService:Create(s,   TI_02, {Color = C_DARK_STK}):Play()
    end)
end

-- ─── Mode toggle ──────────────────────────────────────────────────────────
modeBtn.MouseButton1Click:Connect(function()
    holdMode = not holdMode
    if holdMode then
        modeBtn.Text = "HOLD"
        TweenService:Create(modeStroke, TI_02, {Color = C_AMBER_DIM}):Play()
        if clicking then
            clicking = false
            TweenService:Create(statusDot, TI_02, {BackgroundColor3 = C_AMBER_LO}):Play()
            TweenService:Create(mainStroke,TI_02, {Color = C_DARK_STK}):Play()
            kpsNumber.Text = "0"; last_tier = -1
        end
    else
        modeBtn.Text = "TOGGLE"
        TweenService:Create(modeStroke, TI_02, {Color = C_DARK_STK}):Play()
    end
end)

-- ─── KPS controls ─────────────────────────────────────────────────────────
local targetKPS = 80

local function updateTarget(newVal)
    targetKPS = m_clamp(newVal, 1, 2000)
    targetNum.Text   = tostr(targetKPS)
    kpsTarget.Text   = "TARGET: " .. tostr(targetKPS)
    applyKPS(targetKPS)
    if clicking then
        clicking = false; task_wait(0.02)
        clicking = true;  task.spawn(spam_loop)
    end
end

local function holdButton(btn, delta)
    local held = false
    btn.MouseButton1Down:Connect(function()
        held = true
        updateTarget(targetKPS + delta)
        task.spawn(function()
            task_wait(0.4)
            while held do
                updateTarget(targetKPS + delta)
                task_wait(0.06)
            end
        end)
    end)
    btn.MouseButton1Up:Connect(function() held = false end)
    btn.MouseLeave:Connect(function() held = false end)
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

-- ─── Activation ───────────────────────────────────────────────────────────
local function startClicking()
    if clicking then return end
    clicking  = true
    last_tier = -1
    TweenService:Create(statusDot,  TI_02, {BackgroundColor3 = C_AMBER}):Play()
    TweenService:Create(mainStroke, TI_02, {Color = C_ON_STK}):Play()
    task.spawn(spam_loop)
end

local function stopClicking()
    if not clicking then return end
    clicking = false
    TweenService:Create(statusDot,  TI_02, {BackgroundColor3 = C_AMBER_LO}):Play()
    TweenService:Create(mainStroke, TI_02, {Color = C_DARK_STK}):Play()
    TweenService:Create(kpsNumber,  TI_03, {TextColor3 = C_AMBER}):Play()
    kpsNumber.Text = "0"
    last_tier = -1
end

UIS.InputBegan:Connect(function(input, _)
    if waitingForKey then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode ~= TOGGLE_KEY then return end
    if holdMode then startClicking()
    else if clicking then stopClicking() else startClicking() end
    end
end)

UIS.InputEnded:Connect(function(input)
    if waitingForKey then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode ~= TOGGLE_KEY then return end
    if holdMode then stopClicking() end
end)

-- ─── Drag ─────────────────────────────────────────────────────────────────
local dragActive  = false
local dragTarget  = nil
local dragOffsetX = 0
local dragOffsetY = 0
local tbPending   = false
local tbPendDownX = 0
local tbPendDownY = 0
local THRESH      = 8

frame.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    dragActive  = true
    dragTarget  = frame
    dragOffsetX = input.Position.X - frame.AbsolutePosition.X
    dragOffsetY = input.Position.Y - frame.AbsolutePosition.Y
end)

titleBtn.MouseButton1Down:Connect(function(input)
    tbPending   = true
    tbDidDrag   = false
    tbPendDownX = input.Position.X
    tbPendDownY = input.Position.Y
    dragOffsetX = input.Position.X - titleBox.AbsolutePosition.X
    dragOffsetY = input.Position.Y - titleBox.AbsolutePosition.Y
end)

UIS.InputChanged:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
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
    local ss = screenGui.AbsoluteSize
    local fs = dragTarget.AbsoluteSize
    dragTarget.Position = UDim2.new(0,
        m_clamp(input.Position.X - dragOffsetX, 0, ss.X - fs.X),
        0,
        m_clamp(input.Position.Y - dragOffsetY, 0, ss.Y - fs.Y))
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    dragActive = false; dragTarget = nil; tbPending = false
end)

-- ─── Live KPS counter ─────────────────────────────────────────────────────
task.spawn(function()
    while true do
        task_wait(0.1)
        if clicking then
            local now    = hrt()
            local cutoff = now - 1
            local count  = 0
            for i = 1, RING_SIZE do
                if ring[i] > cutoff then count = count + 1 end
            end
            local str = tostr(count)
            if str ~= last_count_str then
                last_count_str = str
                kpsNumber.Text = str
            end
            local tier
            if     count >= 500 then tier = 3
            elseif count >= 200 then tier = 2
            elseif count >= 80  then tier = 1
            else                      tier = 0 end
            if tier ~= last_tier then
                last_tier = tier
                local col = tier == 3 and C_WHITE
                         or tier == 2 and C_AMBER
                         or tier == 1 and C_AMBER_DIM
                         or C_GREY
                TweenService:Create(kpsNumber, TI_015, {TextColor3 = col}):Play()
            end
        end
    end
end)

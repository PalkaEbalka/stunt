local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local localPlayer = Players.LocalPlayer

local KEYS_URL = "https://raw.githubusercontent.com/PalkaEbalka/stunt/refs/heads/main/keys.txt"

local BASE_MAX_FORCE        = 2500
local BASE_TARGET_ANGLE     = 45
local BASE_STOPPIE_ANGLE    = 35
local BASE_STOPPIE_DELAY    = 1.5
local BASE_STOPPIE_RISE     = 3.0
local BASE_STOPPIE_MINSPEED = 15

_G.MaxForce        = BASE_MAX_FORCE
_G.TargetAngle     = BASE_TARGET_ANGLE
_G.StuntKey        = Enum.KeyCode.LeftShift
_G.BrakeKey        = Enum.KeyCode.S
_G.StoppieAngle    = BASE_STOPPIE_ANGLE
_G.StoppieDelay    = BASE_STOPPIE_DELAY
_G.StoppieRiseTime = BASE_STOPPIE_RISE
_G.StoppieMinSpeed = BASE_STOPPIE_MINSPEED

local isStunting = false
local currentGyro = nil
local currentAttachment = nil
local stuntConnection = nil

local isStoppie = false
local stoppieGyro = nil
local stoppieAttachment = nil
local stoppieConnection = nil
local stoppieRiseStart = nil
local stoppieAccumulated = 0
local brakeHoldStart = nil

local function applyWheelie(seat)
    if not seat or not seat.Parent then return end
    local root = seat.Parent.PrimaryPart or seat

    currentAttachment = Instance.new("Attachment")
    currentAttachment.Name = "StuntAttachment"
    currentAttachment.Parent = root

    local angularVelocity = Instance.new("AngularVelocity")
    angularVelocity.Name = "WheelieForce"
    angularVelocity.Attachment0 = currentAttachment
    angularVelocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
    angularVelocity.MaxTorque = _G.MaxForce
    angularVelocity.AngularVelocity = Vector3.new(2.5, 0, 0)
    angularVelocity.Parent = root

    currentGyro = angularVelocity

    stuntConnection = RunService.Heartbeat:Connect(function()
        if not root or not currentGyro then return end
        local look = root.CFrame.LookVector
        local up = Vector3.new(0, 1, 0)
        local currentAngleDeg = math.deg(math.asin(look:Dot(up)))
        local angleError = _G.TargetAngle - currentAngleDeg
        local targetSpeed = math.clamp(angleError * 0.2, -4, 4)

        if math.abs(angleError) < 1 then
            currentGyro.AngularVelocity = Vector3.new(0, 0, 0)
        else
            currentGyro.AngularVelocity = Vector3.new(targetSpeed, 0, 0)
        end
    end)
end

local function removeWheelie()
    if stuntConnection then stuntConnection:Disconnect() stuntConnection = nil end
    if currentGyro then currentGyro:Destroy() currentGyro = nil end
    if currentAttachment then currentAttachment:Destroy() currentAttachment = nil end
end

local function removeStoppie(resetProgress)
    if stoppieConnection then stoppieConnection:Disconnect() stoppieConnection = nil end
    if stoppieGyro then stoppieGyro:Destroy() stoppieGyro = nil end
    if stoppieAttachment then stoppieAttachment:Destroy() stoppieAttachment = nil end
    stoppieRiseStart = nil
    isStoppie = false
    if resetProgress then stoppieAccumulated = 0 end
end

local function applyStoppie(seat)
    if not seat or not seat.Parent then return end
    local root = seat.Parent.PrimaryPart or seat

    stoppieAttachment = Instance.new("Attachment")
    stoppieAttachment.Name = "StoppieAttachment"
    stoppieAttachment.Parent = root

    local angularVelocity = Instance.new("AngularVelocity")
    angularVelocity.Name = "StoppieForce"
    angularVelocity.Attachment0 = stoppieAttachment
    angularVelocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
    angularVelocity.MaxTorque = _G.MaxForce * 0.1
    angularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
    angularVelocity.Parent = root

    stoppieGyro = angularVelocity
    stoppieRiseStart = tick() - stoppieAccumulated

    stoppieConnection = RunService.Heartbeat:Connect(function()
        if not root or not stoppieGyro then return end
        if not stoppieRiseStart then return end

        local elapsed = tick() - stoppieRiseStart
        local t = math.clamp(elapsed / _G.StoppieRiseTime, 0, 1)
        local eased = 1 - (1 - t) ^ 2
        local targetAngle = _G.StoppieAngle * eased

        local forceRamp = math.clamp(elapsed / 1.5, 0.1, 1.0)
        stoppieGyro.MaxTorque = _G.MaxForce * forceRamp

        local speedRamp = math.clamp(elapsed / 1.0, 0.2, 1.0)

        local look = root.CFrame.LookVector
        local up = Vector3.new(0, 1, 0)
        local currentAngleDeg = math.deg(math.asin(look:Dot(up)))

        local angleError = (-targetAngle) - currentAngleDeg
        local targetSpeed = math.clamp(angleError * 0.04 * speedRamp, -0.8, 0.8)

        if math.abs(currentAngleDeg) < 2 and elapsed > 0.5 then
            stoppieAccumulated = 0
        end

        if math.abs(angleError) < 0.5 then
            stoppieGyro.AngularVelocity = Vector3.new(0, 0, 0)
        else
            stoppieGyro.AngularVelocity = Vector3.new(targetSpeed, 0, 0)
        end
    end)
end

local function makeDraggable(guiObject, dragHandle)
    dragHandle = dragHandle or guiObject
    local dragging = false
    local dragStart = nil
    local startPos = nil

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local Themes = {
    Purple = { name = "Purple", accent = Color3.fromRGB(138, 43, 226), accentLight = Color3.fromRGB(186, 124, 255), accentDark = Color3.fromRGB(80, 20, 150), bgTop = Color3.fromRGB(25, 15, 35), bgBottom = Color3.fromRGB(10, 5, 15), glow = Color3.fromRGB(138, 43, 226) },
    Green = { name = "Green", accent = Color3.fromRGB(34, 197, 94), accentLight = Color3.fromRGB(74, 222, 128), accentDark = Color3.fromRGB(20, 120, 60), bgTop = Color3.fromRGB(15, 35, 25), bgBottom = Color3.fromRGB(5, 15, 10), glow = Color3.fromRGB(34, 197, 94) },
    Orange = { name = "Orange", accent = Color3.fromRGB(249, 115, 22), accentLight = Color3.fromRGB(251, 146, 60), accentDark = Color3.fromRGB(150, 60, 10), bgTop = Color3.fromRGB(40, 25, 12), bgBottom = Color3.fromRGB(15, 8, 3), glow = Color3.fromRGB(249, 115, 22) },
    Pink = { name = "Pink", accent = Color3.fromRGB(236, 72, 153), accentLight = Color3.fromRGB(244, 114, 182), accentDark = Color3.fromRGB(140, 30, 90), bgTop = Color3.fromRGB(35, 15, 28), bgBottom = Color3.fromRGB(15, 5, 10), glow = Color3.fromRGB(236, 72, 153) },
    Gray = { name = "Gray", accent = Color3.fromRGB(120, 120, 130), accentLight = Color3.fromRGB(160, 160, 175), accentDark = Color3.fromRGB(60, 60, 70), bgTop = Color3.fromRGB(25, 25, 30), bgBottom = Color3.fromRGB(10, 10, 15), glow = Color3.fromRGB(120, 120, 130) },
    White = { name = "White", accent = Color3.fromRGB(230, 230, 240), accentLight = Color3.fromRGB(255, 255, 255), accentDark = Color3.fromRGB(150, 150, 170), bgTop = Color3.fromRGB(35, 35, 45), bgBottom = Color3.fromRGB(15, 15, 20), glow = Color3.fromRGB(230, 230, 240) },
    Blue = { name = "Blue", accent = Color3.fromRGB(59, 130, 246), accentLight = Color3.fromRGB(96, 165, 250), accentDark = Color3.fromRGB(20, 60, 140), bgTop = Color3.fromRGB(15, 25, 45), bgBottom = Color3.fromRGB(5, 10, 20), glow = Color3.fromRGB(59, 130, 246) },
    Red = { name = "Red", accent = Color3.fromRGB(220, 38, 38), accentLight = Color3.fromRGB(248, 80, 80), accentDark = Color3.fromRGB(130, 20, 20), bgTop = Color3.fromRGB(35, 15, 15), bgBottom = Color3.fromRGB(15, 5, 5), glow = Color3.fromRGB(220, 38, 38) },
}

local currentTheme = Themes.Purple
local menuTransparency = 0
local themeListeners = {}

local function registerThemeListener(fn) table.insert(themeListeners, fn) end
local function applyTheme(theme)
    currentTheme = theme
    for _, fn in ipairs(themeListeners) do fn(theme) end
end

local function createGradient(parent, c1, c2, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(1, c2) })
    g.Rotation = rotation or 45
    g.Parent = parent
    return g
end

local function addHover(btn, baseColor, hoverColor)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = hoverColor }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = baseColor }):Play()
    end)
end

local function loadAndVerifyKey(enteredKey)
    local success, result = pcall(function()
        return game:HttpGet(KEYS_URL, true)
    end)

    if not success or not result or #result == 0 then
        return false, "ОШИБКА ЗАГРУЗКИ КЛЮЧЕЙ"
    end

    local myUserId = tostring(localPlayer.UserId)

    for line in result:gmatch("[^\r\n]+") do
        local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed ~= "" and not trimmed:match("^#") then
            local key, userId = trimmed:match("^([^:]+):([^:]+)$")
            if key and userId and key == enteredKey and userId == myUserId then
                return true, "OK"
            end
        end
    end

    return false, "НЕВЕРНЫЙ КЛЮЧ ИЛИ USER ID"
end

local function createAuthUI(callback)
    local sg = Instance.new("ScreenGui")
    sg.Name = "ApexAuthUI"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 1000
    sg.Parent = localPlayer:WaitForChild("PlayerGui")

    local authFrame = Instance.new("Frame")
    authFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    authFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    authFrame.Size = UDim2.new(0, 380, 0, 240)
    authFrame.BackgroundColor3 = currentTheme.bgTop
    authFrame.BorderSizePixel = 0
    authFrame.Parent = sg

    local authCorner = Instance.new("UICorner", authFrame)
    authCorner.CornerRadius = UDim.new(0, 2)

    local authGradient = createGradient(authFrame, currentTheme.bgTop, currentTheme.bgBottom, 135)

    local authStroke = Instance.new("UIStroke", authFrame)
    authStroke.Color = currentTheme.accent
    authStroke.Thickness = 2
    authStroke.Transparency = 0.1

    local topLine = Instance.new("Frame")
    topLine.Size = UDim2.new(1, 0, 0, 4)
    topLine.BackgroundColor3 = currentTheme.accent
    topLine.BorderSizePixel = 0
    topLine.Parent = authFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 20)
    title.BackgroundTransparency = 1
    title.Text = "APEX STUNT // AUTH"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 18
    title.Parent = authFrame

    local subTitle = Instance.new("TextLabel")
    subTitle.Size = UDim2.new(1, 0, 0, 20)
    subTitle.Position = UDim2.new(0, 0, 0, 55)
    subTitle.BackgroundTransparency = 1
    subTitle.Text = "ENTER YOUR LICENSE KEY"
    subTitle.TextColor3 = currentTheme.accentLight
    subTitle.Font = Enum.Font.GothamBold
    subTitle.TextSize = 11
    subTitle.Parent = authFrame

    local boxContainer = Instance.new("Frame")
    boxContainer.Size = UDim2.new(1, -60, 0, 40)
    boxContainer.Position = UDim2.new(0, 30, 0, 90)
    boxContainer.BackgroundColor3 = currentTheme.bgBottom
    boxContainer.BorderSizePixel = 0
    boxContainer.Parent = authFrame

    local boxCorner = Instance.new("UICorner", boxContainer)
    boxCorner.CornerRadius = UDim.new(0, 2)

    local boxStroke = Instance.new("UIStroke", boxContainer)
    boxStroke.Color = currentTheme.accentDark
    boxStroke.Thickness = 1

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -20, 1, 0)
    box.Position = UDim2.new(0, 10, 0, 0)
    box.BackgroundTransparency = 1
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.PlaceholderText = "XXXX-XXXX-XXXX"
    box.PlaceholderColor3 = Color3.fromRGB(100, 90, 110)
    box.Text = ""
    box.Font = Enum.Font.GothamBlack
    box.TextSize = 14
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.Parent = boxContainer

    local submitBtn = Instance.new("TextButton")
    submitBtn.Size = UDim2.new(1, -60, 0, 40)
    submitBtn.Position = UDim2.new(0, 30, 0, 150)
    submitBtn.BackgroundColor3 = currentTheme.accent
    submitBtn.Text = "ACTIVATE"
    submitBtn.TextColor3 = currentTheme.bgBottom
    submitBtn.Font = Enum.Font.GothamBlack
    submitBtn.TextSize = 14
    submitBtn.BorderSizePixel = 0
    submitBtn.AutoButtonColor = false
    submitBtn.Parent = authFrame

    local submitCorner = Instance.new("UICorner", submitBtn)
    submitCorner.CornerRadius = UDim.new(0, 2)

    addHover(submitBtn, currentTheme.accent, currentTheme.accentLight)

    local statusText = Instance.new("TextLabel")
    statusText.Size = UDim2.new(1, 0, 0, 20)
    statusText.Position = UDim2.new(0, 0, 1, -30)
    statusText.BackgroundTransparency = 1
    statusText.Text = ""
    statusText.TextColor3 = Color3.fromRGB(255, 100, 100)
    statusText.Font = Enum.Font.GothamBold
    statusText.TextSize = 11
    statusText.Parent = authFrame

    local isProcessing = false
    submitBtn.MouseButton1Click:Connect(function()
        if isProcessing then return end
        local enteredKey = string.gsub(box.Text, "[%s%c]+", "")

        if enteredKey == "" then
            statusText.Text = "ENTER A KEY"
            return
        end

        isProcessing = true
        submitBtn.Text = "CHECKING..."
        statusText.Text = ""
        boxStroke.Color = currentTheme.accent

        task.spawn(function()
            local isValid, message = loadAndVerifyKey(enteredKey)

            if isValid then
                statusText.Text = "ACCESS GRANTED"
                statusText.TextColor3 = Color3.fromRGB(0, 255, 150)
                submitBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
                submitBtn.Text = "SUCCESS"

                task.wait(1)
                sg:Destroy()
                callback()
            else
                statusText.Text = message
                statusText.TextColor3 = Color3.fromRGB(255, 50, 50)
                boxStroke.Color = Color3.fromRGB(255, 50, 50)
                submitBtn.Text = "ACTIVATE"
                isProcessing = false

                local originalPos = boxContainer.Position
                for i = 1, 3 do
                    TweenService:Create(boxContainer, TweenInfo.new(0.05), { Position = originalPos + UDim2.new(0, 5, 0, 0) }):Play()
                    task.wait(0.05)
                    TweenService:Create(boxContainer, TweenInfo.new(0.05), { Position = originalPos - UDim2.new(0, 5, 0, 0) }):Play()
                    task.wait(0.05)
                end
                TweenService:Create(boxContainer, TweenInfo.new(0.05), { Position = originalPos }):Play()
            end
        end)
    end)
end

local function createSettingsMenu()
    local sg = Instance.new("ScreenGui")
    sg.Name = "ApexStuntMenu"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 999
    sg.Parent = localPlayer:WaitForChild("PlayerGui")

    local MENU_W, MENU_H = 580, 520

    local mainContainer = Instance.new("Frame")
    mainContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    mainContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainContainer.Size = UDim2.new(0, MENU_W, 0, MENU_H)
    mainContainer.BackgroundTransparency = 1
    mainContainer.Visible = false
    mainContainer.Parent = sg

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = currentTheme.bgTop
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.ClipsDescendants = true
    frame.Parent = mainContainer

    local frameCorner = Instance.new("UICorner", frame)
    frameCorner.CornerRadius = UDim.new(0, 2)

    local bgGradient = createGradient(frame, currentTheme.bgTop, currentTheme.bgBottom, 135)

    registerThemeListener(function(t)
        bgGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, t.bgTop), ColorSequenceKeypoint.new(1, t.bgBottom) })
        frame.BackgroundColor3 = t.bgTop
    end)

    local frameStroke = Instance.new("UIStroke", frame)
    frameStroke.Color = currentTheme.accent
    frameStroke.Thickness = 2
    frameStroke.Transparency = 0.1

    local strokeGradient = Instance.new("UIGradient")
    strokeGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, currentTheme.accent), ColorSequenceKeypoint.new(1, currentTheme.accentDark) })
    strokeGradient.Rotation = 90
    strokeGradient.Parent = frameStroke

    registerThemeListener(function(t)
        strokeGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, t.accent), ColorSequenceKeypoint.new(1, t.accentDark) })
    end)

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 50)
    topBar.BackgroundColor3 = currentTheme.accentDark
    topBar.BorderSizePixel = 0
    topBar.ZIndex = 2
    topBar.Parent = frame

    local topBarGradient = createGradient(topBar, currentTheme.accentDark, currentTheme.bgBottom, 0)

    registerThemeListener(function(t)
        topBar.BackgroundColor3 = t.accentDark
        topBarGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, t.accentDark), ColorSequenceKeypoint.new(1, t.bgBottom) })
    end)

    local topBarLine = Instance.new("Frame")
    topBarLine.Size = UDim2.new(1, 0, 0, 2)
    topBarLine.Position = UDim2.new(0, 0, 1, -2)
    topBarLine.BackgroundColor3 = currentTheme.accent
    topBarLine.BorderSizePixel = 0
    topBarLine.ZIndex = 3
    topBarLine.Parent = topBar
    registerThemeListener(function(t) topBarLine.BackgroundColor3 = t.accent end)

    local logoFrame = Instance.new("Frame")
    logoFrame.Size = UDim2.new(0, 30, 0, 30)
    logoFrame.Position = UDim2.new(0, 16, 0.5, -15)
    logoFrame.BackgroundColor3 = currentTheme.accent
    logoFrame.BorderSizePixel = 0
    logoFrame.ZIndex = 3
    logoFrame.Parent = topBar
    local logoCorner = Instance.new("UICorner", logoFrame)
    logoCorner.CornerRadius = UDim.new(0, 4)

    local logoText = Instance.new("TextLabel")
    logoText.Size = UDim2.new(1, 0, 1, 0)
    logoText.BackgroundTransparency = 1
    logoText.Text = "A"
    logoText.TextColor3 = currentTheme.bgBottom
    logoText.Font = Enum.Font.GothamBlack
    logoText.TextSize = 20
    logoText.ZIndex = 4
    logoText.Parent = logoFrame

    registerThemeListener(function(t)
        logoFrame.BackgroundColor3 = t.accent
        logoText.TextColor3 = t.bgBottom
    end)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 300, 1, 0)
    title.Position = UDim2.new(0, 60, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "APEX STUNT"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 3
    title.Parent = topBar

    local byLabel = Instance.new("TextLabel")
    byLabel.Size = UDim2.new(0, 220, 0, 20)
    byLabel.Position = UDim2.new(1, -230, 0.5, -10)
    byLabel.BackgroundTransparency = 1
    byLabel.Text = "by assetfinder"
    byLabel.TextColor3 = currentTheme.accentLight
    byLabel.Font = Enum.Font.GothamBold
    byLabel.TextSize = 14
    byLabel.TextXAlignment = Enum.TextXAlignment.Right
    byLabel.ZIndex = 3
    byLabel.Parent = topBar
    registerThemeListener(function(t) byLabel.TextColor3 = t.accentLight end)

    makeDraggable(mainContainer, topBar)

    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 150, 1, -90)
    sidebar.Position = UDim2.new(0, 0, 0, 50)
    sidebar.BackgroundColor3 = currentTheme.bgBottom
    sidebar.BorderSizePixel = 0
    sidebar.ZIndex = 2
    sidebar.Parent = frame

    local sidebarGradient = createGradient(sidebar, currentTheme.bgTop, currentTheme.bgBottom, 90)
    registerThemeListener(function(t)
        sidebarGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, t.bgTop), ColorSequenceKeypoint.new(1, t.bgBottom) })
    end)

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(0, 2, 1, 0)
    divider.Position = UDim2.new(1, -2, 0, 0)
    divider.BackgroundColor3 = currentTheme.accentDark
    divider.BorderSizePixel = 0
    divider.ZIndex = 3
    divider.Parent = sidebar
    registerThemeListener(function(t) divider.BackgroundColor3 = t.accentDark end)

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -150, 1, -90)
    content.Position = UDim2.new(0, 150, 0, 50)
    content.BackgroundTransparency = 1
    content.ClipsDescendants = true
    content.ZIndex = 2
    content.Parent = frame

    local tabButtons = {}
    local tabContents = {}
    local currentTab = nil

    local function switchTab(name)
        if currentTab == name then return end
        local oldTab = currentTab
        currentTab = name

        for tabName, tab in pairs(tabButtons) do
            if tabName == name then
                TweenService:Create(tab.button, TweenInfo.new(0.15), { BackgroundTransparency = 0 }):Play()
                TweenService:Create(tab.stroke, TweenInfo.new(0.15), { Transparency = 0, Thickness = 2 }):Play()
                TweenService:Create(tab.text, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(255,255,255) }):Play()
                TweenService:Create(tab.number, TweenInfo.new(0.15), { TextColor3 = currentTheme.accent }):Play()
                TweenService:Create(tab.indicator, TweenInfo.new(0.15), { Size = UDim2.new(0, 4, 1, 0) }):Play()
            else
                TweenService:Create(tab.button, TweenInfo.new(0.15), { BackgroundTransparency = 0.8 }):Play()
                TweenService:Create(tab.stroke, TweenInfo.new(0.15), { Transparency = 1, Thickness = 1 }):Play()
                TweenService:Create(tab.text, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(150,140,170) }):Play()
                TweenService:Create(tab.number, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(150,140,170) }):Play()
                TweenService:Create(tab.indicator, TweenInfo.new(0.15), { Size = UDim2.new(0, 0, 1, 0) }):Play()
            end
        end

        if oldTab and tabContents[oldTab] then tabContents[oldTab].Visible = false end
        if tabContents[name] then tabContents[name].Visible = true end
    end

    local function createTab(name, yPos, numText)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 48)
        btn.Position = UDim2.new(0, 0, 0, yPos * 52)
        btn.BackgroundColor3 = currentTheme.accentDark
        btn.BackgroundTransparency = 0.8
        btn.Text = ""
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.ZIndex = 3
        btn.Parent = sidebar

        local btnStroke = Instance.new("UIStroke", btn)
        btnStroke.Color = currentTheme.accent
        btnStroke.Thickness = 1
        btnStroke.Transparency = 1

        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(0, 0, 1, 0)
        indicator.Position = UDim2.new(0, 0, 0, 0)
        indicator.BackgroundColor3 = currentTheme.accent
        indicator.BorderSizePixel = 0
        indicator.ZIndex = 4
        indicator.Parent = btn
        registerThemeListener(function(t) indicator.BackgroundColor3 = t.accent end)

        local numberLabel = Instance.new("TextLabel")
        numberLabel.Size = UDim2.new(0, 30, 1, 0)
        numberLabel.Position = UDim2.new(0, 16, 0, 0)
        numberLabel.BackgroundTransparency = 1
        numberLabel.Text = numText or "01"
        numberLabel.TextColor3 = Color3.fromRGB(150,140,170)
        numberLabel.Font = Enum.Font.GothamBlack
        numberLabel.TextSize = 16
        numberLabel.ZIndex = 4
        numberLabel.Parent = btn

        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, -56, 1, 0)
        textLabel.Position = UDim2.new(0, 48, 0, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = name
        textLabel.TextColor3 = Color3.fromRGB(150,140,170)
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextSize = 13
        textLabel.TextXAlignment = Enum.TextXAlignment.Left
        textLabel.ZIndex = 4
        textLabel.Parent = btn

        registerThemeListener(function(t)
            btn.BackgroundColor3 = t.accentDark
            btnStroke.Color = t.accent
            if currentTab == name then
                numberLabel.TextColor3 = t.accent
            end
        end)

        tabButtons[name] = {
            button = btn, stroke = btnStroke, text = textLabel,
            number = numberLabel, indicator = indicator
        }

        return btn
    end

    local function createTabContent(name)
        local sc = Instance.new("ScrollingFrame")
        sc.Name = name .. "Tab"
        sc.Size = UDim2.new(1, -16, 1, -16)
        sc.Position = UDim2.new(0, 8, 0, 8)
        sc.BackgroundTransparency = 1
        sc.BorderSizePixel = 0
        sc.ScrollBarThickness = 3
        sc.ScrollBarImageColor3 = currentTheme.accent
        sc.CanvasSize = UDim2.new(0, 0, 0, 200)
        sc.Visible = false
        sc.ZIndex = 3
        sc.Parent = content
        tabContents[name] = sc
        registerThemeListener(function(t) sc.ScrollBarImageColor3 = t.accent end)
        return sc
    end

    local stuntTab = createTabContent("Stunt")
    local stoppieTab = createTabContent("Stoppie")
    local settingsTab = createTabContent("Settings")
    local themesTab = createTabContent("Themes")

    local function createSlider(parent, name, yPos, minVal, maxVal, baseVal, callback)
        local SLIDER_H = 54
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -16, 0, SLIDER_H)
        container.Position = UDim2.new(0, 8, 0, yPos)
        container.BackgroundColor3 = currentTheme.bgTop
        container.BorderSizePixel = 0
        container.ZIndex = 4
        container.Parent = parent

        local containerCorner = Instance.new("UICorner", container)
        containerCorner.CornerRadius = UDim.new(0, 2)

        local containerGradient = createGradient(container, currentTheme.bgTop, currentTheme.bgBottom, 45)
        local containerStroke = Instance.new("UIStroke", container)
        containerStroke.Color = currentTheme.accent
        containerStroke.Thickness = 1
        containerStroke.Transparency = 0.5

        registerThemeListener(function(t)
            containerGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, t.bgTop), ColorSequenceKeypoint.new(1, t.bgBottom) })
            containerStroke.Color = t.accent
        end)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.6, 0, 0, 20)
        label.Position = UDim2.new(0, 12, 0, 8)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(180,170,200)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 5
        label.Parent = container

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.new(0, 80, 0, 20)
        valueLabel.Position = UDim2.new(1, -92, 0, 8)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = tostring(math.floor(baseVal))
        valueLabel.TextColor3 = currentTheme.accentLight
        valueLabel.Font = Enum.Font.GothamBlack
        valueLabel.TextSize = 14
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.ZIndex = 5
        valueLabel.Parent = container

        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(1, -24, 0, 4)
        barBg.Position = UDim2.new(0, 12, 0, 38)
        barBg.BackgroundColor3 = currentTheme.bgBottom
        barBg.BorderSizePixel = 0
        barBg.ZIndex = 5
        barBg.Parent = container

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((baseVal - minVal) / (maxVal - minVal), 0, 1, 0)
        fill.BackgroundColor3 = currentTheme.accent
        fill.BorderSizePixel = 0
        fill.ZIndex = 5
        fill.Parent = barBg

        local fillGradient = createGradient(fill, currentTheme.accent, currentTheme.accentLight, 0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 12, 0, 12)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.new((baseVal - minVal) / (maxVal - minVal), 0, 0.5, 0)
        knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
        knob.BorderSizePixel = 0
        knob.ZIndex = 10
        knob.Active = true
        knob.Rotation = 45
        knob.Parent = barBg

        local knobStroke = Instance.new("UIStroke", knob)
        knobStroke.Color = currentTheme.accent
        knobStroke.Thickness = 2

        registerThemeListener(function(t)
            container.BackgroundColor3 = t.bgTop
            valueLabel.TextColor3 = t.accentLight
            barBg.BackgroundColor3 = t.bgBottom
            fill.BackgroundColor3 = t.accent
            fillGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, t.accent), ColorSequenceKeypoint.new(1, t.accentLight) })
            knobStroke.Color = t.accent
        end)

        local dragging = false

        local function applyValue(relX)
            relX = math.clamp(relX, 0, 1)
            local value = minVal + (maxVal - minVal) * relX
            fill.Size = UDim2.new(relX, 0, 1, 0)
            knob.Position = UDim2.new(relX, 0, 0.5, 0)
            valueLabel.Text = tostring(maxVal <= 10 and string.format("%.1f", value) or math.floor(value))
            callback(value)
        end

        knob.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                TweenService:Create(knob, TweenInfo.new(0.15), { Size = UDim2.new(0, 16, 0, 16), Rotation = 0 }):Play()
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local relX = (input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X
                applyValue(relX)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                TweenService:Create(knob, TweenInfo.new(0.15), { Size = UDim2.new(0, 12, 0, 12), Rotation = 45 }):Play()
            end
        end)

        return {
            container = container,
            reset = function(val)
                local relX = (val - minVal) / (maxVal - minVal)
                applyValue(relX)
            end
        }
    end

    local resetAngle = createSlider(stuntTab, "Угол станта", 0, 10, 90, BASE_TARGET_ANGLE, function(v) _G.TargetAngle = v end)
    local resetForce = createSlider(stuntTab, "Резкость подъёма", 66, 500, 8000, BASE_MAX_FORCE, function(v) _G.MaxForce = v; if currentGyro then currentGyro.MaxTorque = v end end)

    local resetStoppieAngle = createSlider(stoppieTab, "Угол стоппи", 0, 5, 75, BASE_STOPPIE_ANGLE, function(v) _G.StoppieAngle = v end)
    local resetStoppieDelay = createSlider(stoppieTab, "Задержка тормоза (сек)", 66, 0.5, 3.0, BASE_STOPPIE_DELAY, function(v) _G.StoppieDelay = v end)
    local resetStoppieRise = createSlider(stoppieTab, "Время подъёма (сек)", 132, 1.0, 6.0, BASE_STOPPIE_RISE, function(v) _G.StoppieRiseTime = v end)
    local resetStoppieMinSpeed = createSlider(stoppieTab, "Мин. скорость стоппи", 198, 5, 50, BASE_STOPPIE_MINSPEED, function(v) _G.StoppieMinSpeed = v end)

    local resetAllBtn = Instance.new("TextButton")
    resetAllBtn.Size = UDim2.new(1, -16, 0, 46)
    resetAllBtn.Position = UDim2.new(0, 8, 0, 0)
    resetAllBtn.BackgroundColor3 = currentTheme.accent
    resetAllBtn.Text = "RESET ALL"
    resetAllBtn.TextColor3 = Color3.fromRGB(255,255,255)
    resetAllBtn.Font = Enum.Font.GothamBlack
    resetAllBtn.TextSize = 14
    resetAllBtn.BorderSizePixel = 0
    resetAllBtn.AutoButtonColor = false
    resetAllBtn.ZIndex = 5
    resetAllBtn.Parent = settingsTab
    local resetBtnCorner = Instance.new("UICorner", resetAllBtn)
    resetBtnCorner.CornerRadius = UDim.new(0, 2)
    local resetBtnGradient = createGradient(resetAllBtn, currentTheme.accent, currentTheme.accentDark, 0)
    registerThemeListener(function(t)
        resetAllBtn.BackgroundColor3 = t.accent
        resetBtnGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, t.accent), ColorSequenceKeypoint.new(1, t.accentDark) })
    end)
    addHover(resetAllBtn, currentTheme.accent, currentTheme.accentLight)
    resetAllBtn.MouseButton1Click:Connect(function()
        resetAngle.reset(BASE_TARGET_ANGLE)
        resetForce.reset(BASE_MAX_FORCE)
        resetStoppieAngle.reset(BASE_STOPPIE_ANGLE)
        resetStoppieDelay.reset(BASE_STOPPIE_DELAY)
        resetStoppieRise.reset(BASE_STOPPIE_RISE)
        resetStoppieMinSpeed.reset(BASE_STOPPIE_MINSPEED)
    end)

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, -16, 0, 80)
    infoLabel.Position = UDim2.new(0, 8, 0, 56)
    infoLabel.BackgroundColor3 = currentTheme.bgTop
    infoLabel.Text = "LeftShift — стант (Wheelie)\n\nДолгий S на скорости ≥15 — стоппи"
    infoLabel.TextColor3 = currentTheme.accentLight
    infoLabel.Font = Enum.Font.GothamBold
    infoLabel.TextSize = 12
    infoLabel.TextYAlignment = Enum.TextYAlignment.Center
    infoLabel.ZIndex = 5
    infoLabel.Parent = settingsTab
    local infoCorner = Instance.new("UICorner", infoLabel)
    infoCorner.CornerRadius = UDim.new(0, 2)
    registerThemeListener(function(t)
        infoLabel.BackgroundColor3 = t.bgTop
        infoLabel.TextColor3 = t.accentLight
    end)

    local transSlider = createSlider(settingsTab, "Прозрачность меню (%)", 156, 0, 90, 0, function(v)
        menuTransparency = v / 100
        frame.BackgroundTransparency = menuTransparency
        topBar.BackgroundTransparency = menuTransparency
        sidebar.BackgroundTransparency = menuTransparency
    end)

    local themeButtons = {}
    local themeKeys = {"Purple", "Green", "Orange", "Pink", "Gray", "White", "Blue", "Red"}
    local function refreshThemeButtons()
        for key, btn in pairs(themeButtons) do
            if currentTheme == Themes[key] then
                TweenService:Create(btn.stroke, TweenInfo.new(0.2), { Thickness = 2, Transparency = 0 }):Play()
                TweenService:Create(btn.button, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
            else
                TweenService:Create(btn.stroke, TweenInfo.new(0.2), { Thickness = 1, Transparency = 0.5 }):Play()
                TweenService:Create(btn.button, TweenInfo.new(0.2), { BackgroundTransparency = 0.3 }):Play()
            end
        end
    end

    for i, key in ipairs(themeKeys) do
        local theme = Themes[key]
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local btnW = 200
        local btnH = 60

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, btnW, 0, btnH)
        btn.Position = UDim2.new(0, 8 + col * (btnW + 10), 0, row * (btnH + 10))
        btn.BackgroundColor3 = theme.accentDark
        btn.BackgroundTransparency = 0.3
        btn.Text = ""
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.ClipsDescendants = true
        btn.ZIndex = 5
        btn.Parent = themesTab

        local btnCorner = Instance.new("UICorner", btn)
        btnCorner.CornerRadius = UDim.new(0, 2)

        local btnGrad = createGradient(btn, theme.accent, theme.accentDark, 45)
        local btnStroke = Instance.new("UIStroke", btn)
        btnStroke.Color = theme.accentLight
        btnStroke.Thickness = 1
        btnStroke.Transparency = 0.5

        local colorDot = Instance.new("Frame")
        colorDot.Size = UDim2.new(0, 20, 0, 20)
        colorDot.Position = UDim2.new(0, 10, 0.5, -10)
        colorDot.BackgroundColor3 = theme.accent
        colorDot.BorderSizePixel = 0
        colorDot.Rotation = 45
        colorDot.ZIndex = 6
        colorDot.Parent = btn

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -40, 1, 0)
        label.Position = UDim2.new(0, 40, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = theme.name
        label.TextColor3 = Color3.fromRGB(255,255,255)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 6
        label.Parent = btn

        themeButtons[key] = { button = btn, stroke = btnStroke }
        addHover(btn, theme.accentDark, theme.accent)
        btn.MouseButton1Click:Connect(function() applyTheme(theme); refreshThemeButtons() end)
    end
    themesTab.CanvasSize = UDim2.new(0, 0, 0, math.ceil(#themeKeys / 2) * 70)

    createTab("Stunt", 0, "01")
    createTab("Stoppie", 1, "02")
    createTab("Settings", 2, "03")
    createTab("Themes", 3, "04")

    for tabName, tab in pairs(tabButtons) do
        tab.button.MouseButton1Click:Connect(function() switchTab(tabName) end)
    end
    switchTab("Stunt")

    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(1, 0, 0, 40)
    statusBar.Position = UDim2.new(0, 0, 1, -40)
    statusBar.BackgroundColor3 = currentTheme.bgBottom
    statusBar.BorderSizePixel = 0
    statusBar.ZIndex = 2
    statusBar.Parent = frame

    local statusGrad = createGradient(statusBar, currentTheme.bgBottom, currentTheme.bgTop, 0)
    registerThemeListener(function(t)
        statusBar.BackgroundColor3 = t.bgBottom
        statusGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, t.bgBottom), ColorSequenceKeypoint.new(1, t.bgTop) })
    end)

    local statusLine = Instance.new("Frame")
    statusLine.Size = UDim2.new(1, 0, 0, 1)
    statusLine.Position = UDim2.new(0, 0, 0, 0)
    statusLine.BackgroundColor3 = currentTheme.accent
    statusLine.BorderSizePixel = 0
    statusLine.ZIndex = 3
    statusLine.Parent = statusBar
    registerThemeListener(function(t) statusLine.BackgroundColor3 = t.accent end)

    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 6, 0, 6)
    statusDot.Position = UDim2.new(0, 16, 0.5, -3)
    statusDot.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
    statusDot.BorderSizePixel = 0
    statusDot.Rotation = 45
    statusDot.ZIndex = 3
    statusDot.Parent = statusBar

    local statusText = Instance.new("TextLabel")
    statusText.Size = UDim2.new(0.6, 0, 1, 0)
    statusText.Position = UDim2.new(0, 30, 0, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text = "SYSTEM ACTIVE"
    statusText.TextColor3 = currentTheme.accentLight
    statusText.Font = Enum.Font.GothamBold
    statusText.TextSize = 11
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.ZIndex = 3
    statusText.Parent = statusBar
    registerThemeListener(function(t) statusText.TextColor3 = t.accentLight end)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 100, 0, 24)
    closeBtn.Position = UDim2.new(1, -116, 0.5, -12)
    closeBtn.BackgroundColor3 = currentTheme.accentDark
    closeBtn.Text = "HIDE MENU"
    closeBtn.TextColor3 = currentTheme.accentLight
    closeBtn.Font = Enum.Font.GothamBlack
    closeBtn.TextSize = 11
    closeBtn.BorderSizePixel = 0
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 3
    closeBtn.Parent = statusBar
    local closeCorner = Instance.new("UICorner", closeBtn)
    closeCorner.CornerRadius = UDim.new(0, 2)
    registerThemeListener(function(t) closeBtn.BackgroundColor3 = t.accentDark; closeBtn.TextColor3 = t.accentLight end)
    addHover(closeBtn, currentTheme.accentDark, currentTheme.accent)

    local miniContainer = Instance.new("Frame")
    miniContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    miniContainer.Size = UDim2.new(0, 60, 0, 60)
    miniContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
    miniContainer.BackgroundTransparency = 1
    miniContainer.Visible = false
    miniContainer.Parent = sg

    local miniOuter = Instance.new("Frame")
    miniOuter.Size = UDim2.new(1, -10, 1, -10)
    miniOuter.Position = UDim2.new(0, 5, 0, 5)
    miniOuter.BackgroundColor3 = currentTheme.bgTop
    miniOuter.BorderSizePixel = 0
    miniOuter.Rotation = 45
    miniOuter.Parent = miniContainer
    local miniOuterCorner = Instance.new("UICorner", miniOuter)
    miniOuterCorner.CornerRadius = UDim.new(0, 2)
    local miniOuterStroke = Instance.new("UIStroke", miniOuter)
    miniOuterStroke.Color = currentTheme.accent
    miniOuterStroke.Thickness = 2
    registerThemeListener(function(t) miniOuter.BackgroundColor3 = t.bgTop; miniOuterStroke.Color = t.accent end)

    local miniBtn = Instance.new("TextButton")
    miniBtn.Size = UDim2.new(1, -24, 1, -24)
    miniBtn.Position = UDim2.new(0, 12, 0, 12)
    miniBtn.BackgroundColor3 = currentTheme.accent
    miniBtn.Text = ""
    miniBtn.Rotation = 45
    miniBtn.BorderSizePixel = 0
    miniBtn.AutoButtonColor = false
    miniBtn.Parent = miniContainer
    local miniBtnCorner = Instance.new("UICorner", miniBtn)
    miniBtnCorner.CornerRadius = UDim.new(0, 2)
    registerThemeListener(function(t) miniBtn.BackgroundColor3 = t.accent end)

    local letterA = Instance.new("TextLabel")
    letterA.Size = UDim2.new(1, 0, 1, 0)
    letterA.BackgroundTransparency = 1
    letterA.Text = "A"
    letterA.TextColor3 = currentTheme.bgBottom
    letterA.Font = Enum.Font.GothamBlack
    letterA.TextSize = 20
    letterA.Rotation = -45
    letterA.ZIndex = 5
    letterA.Parent = miniBtn
    registerThemeListener(function(t) letterA.TextColor3 = t.bgBottom end)

    local miniGlow = Instance.new("ImageLabel")
    miniGlow.BackgroundTransparency = 1
    miniGlow.Image = "rbxassetid://5028857084"
    miniGlow.ImageColor3 = currentTheme.accent
    miniGlow.ImageTransparency = 0.5
    miniGlow.ScaleType = Enum.ScaleType.Slice
    miniGlow.SliceCenter = Rect.new(24, 24, 276, 276)
    miniGlow.Size = UDim2.new(1, 30, 1, 30)
    miniGlow.Position = UDim2.new(0, -15, 0, -15)
    miniGlow.Parent = miniContainer
    registerThemeListener(function(t) miniGlow.ImageColor3 = t.accent end)

    task.spawn(function()
        while miniContainer.Parent do
            TweenService:Create(miniGlow, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = 0.1 }):Play()
            task.wait(1.5)
            TweenService:Create(miniGlow, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = 0.6 }):Play()
            task.wait(1.5)
        end
    end)

    makeDraggable(miniContainer, miniBtn)

    local isOpen = true
    local animating = false
    local lastMenuPosition = UDim2.new(0.5, 0, 0.5, 0)

    local function openMenu()
        if isOpen or animating then return end
        animating = true

        local containerAbs = miniContainer.AbsolutePosition
        local containerSize = miniContainer.AbsoluteSize
        local centerX = containerAbs.X + containerSize.X / 2
        local centerY = containerAbs.Y + containerSize.Y / 2

        mainContainer.AnchorPoint = Vector2.new(0.5, 0.5)
        mainContainer.Position = UDim2.new(0, centerX, 0, centerY)
        mainContainer.Size = UDim2.new(0, 0, 0, 0)
        mainContainer.Visible = true
        frame.BackgroundTransparency = 1
        frameStroke.Transparency = 1

        miniContainer.Visible = false

        local targetPos = lastMenuPosition
        local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

        TweenService:Create(mainContainer, tweenInfo, {
            Size = UDim2.new(0, MENU_W, 0, MENU_H),
            Position = targetPos
        }):Play()

        TweenService:Create(frame, tweenInfo, { BackgroundTransparency = menuTransparency }):Play()
        TweenService:Create(frameStroke, tweenInfo, { Transparency = 0.1 }):Play()

        task.delay(0.4, function() isOpen = true; animating = false end)
    end

    local function closeMenu()
        if not isOpen or animating then return end
        animating = true

        lastMenuPosition = mainContainer.Position

        local targetPos = mainContainer.Position
        local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

        TweenService:Create(mainContainer, tweenInfo, {
            Size = UDim2.new(0, 0, 0, 0),
            Position = targetPos
        }):Play()

        TweenService:Create(frame, tweenInfo, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(frameStroke, tweenInfo, { Transparency = 1 }):Play()

        task.delay(0.4, function()
            mainContainer.Visible = false
            miniContainer.Position = targetPos
            miniContainer.Visible = true
            isOpen = false
            animating = false
        end)
    end

    local lastClickTime = 0
    miniBtn.MouseButton1Click:Connect(function()
        local currentTime = tick()
        if currentTime - lastClickTime < 0.35 then
            openMenu()
            lastClickTime = 0
        else
            lastClickTime = currentTime
            TweenService:Create(miniBtn, TweenInfo.new(0.1), { BackgroundColor3 = currentTheme.accentLight }):Play()
            task.delay(0.1, function()
                TweenService:Create(miniBtn, TweenInfo.new(0.1), { BackgroundColor3 = currentTheme.accent }):Play()
            end)
        end
    end)

    closeBtn.MouseButton1Click:Connect(closeMenu)

    mainContainer.Visible = true
    mainContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainContainer.Size = UDim2.new(0, MENU_W * 0.5, 0, MENU_H * 0.5)
    frame.BackgroundTransparency = 1
    frameStroke.Transparency = 1

    local appearInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    TweenService:Create(mainContainer, appearInfo, { Size = UDim2.new(0, MENU_W, 0, MENU_H) }):Play()
    TweenService:Create(frame, appearInfo, { BackgroundTransparency = menuTransparency }):Play()
    TweenService:Create(frameStroke, appearInfo, { Transparency = 0.1 }):Play()

    task.delay(0.5, function()
        lastMenuPosition = UDim2.new(0.5, 0, 0.5, 0)
        isOpen = true
    end)
end

local function LaunchUniversalVehicleScript()
    createSettingsMenu()

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == _G.StuntKey and not isStunting then
            local char = localPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
                isStunting = true
                applyWheelie(hum.SeatPart)
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == _G.StuntKey and isStunting then
            isStunting = false
            removeWheelie()
        end
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == _G.BrakeKey then brakeHoldStart = tick() end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == _G.BrakeKey then
            brakeHoldStart = nil
            if isStoppie then
                if stoppieRiseStart then stoppieAccumulated = tick() - stoppieRiseStart end
                removeStoppie(false)
            end
        end
    end)

    RunService.Heartbeat:Connect(function()
        local char = localPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or not hum.SeatPart or not hum.SeatPart:IsA("VehicleSeat") then return end

        local seat = hum.SeatPart
        local vel = seat.AssemblyLinearVelocity
        local flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude

        if isStoppie and flatSpeed < 1 then
            if stoppieRiseStart then stoppieAccumulated = tick() - stoppieRiseStart end
            removeStoppie(false)
        end

        if isStoppie then
            if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.D) then
                if stoppieRiseStart then stoppieAccumulated = tick() - stoppieRiseStart end
                removeStoppie(false)
            end
        end

        if brakeHoldStart and not isStoppie and not isStunting then
            local elapsed = tick() - brakeHoldStart
            if elapsed >= _G.StoppieDelay then
                local look = (seat.Parent.PrimaryPart or seat).CFrame.LookVector
                local forwardDot = flatSpeed > 0 and vel.Unit:Dot(look) or 0
                local turning = UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.D)

                if flatSpeed >= _G.StoppieMinSpeed and forwardDot > 0.3 and not turning then
                    isStoppie = true
                    applyStoppie(seat)
                end
            end
        end
    end)

    pcall(function()
        game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
            Text = "[Premium] Actived. LeftShift = Stunt, long S = Stoppie.",
            Color = Color3.fromRGB(0, 255, 150),
            Font = Enum.Font.SourceSansBold,
            TextSize = 14
        })
    end)
end

createAuthUI(function()
    LaunchUniversalVehicleScript()
end)

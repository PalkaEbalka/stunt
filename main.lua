-- ====================================================================
-- НАСТРОЙКИ: ССЫЛКА НА ФАЙЛ С КЛЮЧАМИ
-- ====================================================================
local KEYS_URL = "https://raw.githubusercontent.com/PalkaEbalka/stunt/refs/heads/main/keys.txt"

-- ====================================================================
-- БАЗОВЫЕ СЕРВИСЫ
-- ====================================================================
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local localPlayer = Players.LocalPlayer

-- ====================================================================
-- БАЗОВЫЕ (ЗАВОДСКИЕ) НАСТРОЙКИ ЧИТА
-- ====================================================================
local BASE_MAX_FORCE    = 2500
local BASE_TARGET_ANGLE = 45

_G.MaxForce    = BASE_MAX_FORCE
_G.TargetAngle = BASE_TARGET_ANGLE
_G.StuntKey    = Enum.KeyCode.LeftShift

local isStunting = false
local currentGyro = nil
local currentAttachment = nil
local stuntConnection = nil

-- ====================================================================
-- ФИЗИКА СТАНТА (WHEELIE)
-- ====================================================================
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

-- ====================================================================
-- УНИВЕРСАЛЬНОЕ ПЕРЕТАСКИВАНИЕ
-- ====================================================================
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

-- ====================================================================
-- МЕНЮ НАСТРОЕК
-- ====================================================================
local function createSettingsMenu()
    local sg = Instance.new("ScreenGui")
    sg.Name = "StuntSettingsMenu"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.Parent = localPlayer:WaitForChild("PlayerGui")

    local MENU_W, MENU_H = 340, 360
    local GEAR_SIZE = 46
    local OPEN_W, OPEN_H = 90, 34

    -- ================================================================
    -- ОСНОВНОЙ ФРЕЙМ МЕНЮ
    -- ================================================================
    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.Size = UDim2.new(0, MENU_W, 0, MENU_H)
    frame.BackgroundColor3 = Color3.fromRGB(18, 16, 24)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Visible = false
    frame.Parent = sg

    local frameCorner = Instance.new("UICorner", frame)
    frameCorner.CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(138, 43, 226)
    stroke.Thickness = 2

    local lastMenuPosition = UDim2.new(0.5, 0, 0.5, 0)

    -- Шапка (за неё таскаем меню)
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 34)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundTransparency = 1
    header.Parent = frame

    local logo = Instance.new("TextLabel")
    logo.Size = UDim2.new(1, 0, 0, 20)
    logo.Position = UDim2.new(0, 0, 0, 8)
    logo.BackgroundTransparency = 1
    logo.Text = "by assetfinder"
    logo.TextColor3 = Color3.fromRGB(186, 124, 255)
    logo.Font = Enum.Font.GothamBold
    logo.TextSize = 13
    logo.TextXAlignment = Enum.TextXAlignment.Right
    logo.Parent = header

    local logoPadding = Instance.new("UIPadding", logo)
    logoPadding.PaddingRight = UDim.new(0, 12)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "⚙ STUNT SETTINGS"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = frame

    local separator = Instance.new("Frame")
    separator.Size = UDim2.new(0.9, 0, 0, 1)
    separator.Position = UDim2.new(0.05, 0, 0, 72)
    separator.BackgroundColor3 = Color3.fromRGB(80, 60, 110)
    separator.BorderSizePixel = 0
    separator.Parent = frame

    makeDraggable(frame, header)

    -- ================================================================
    -- ПОЛЗУНОК
    -- ================================================================
    local function createSlider(name, yPos, minVal, maxVal, baseVal, callback)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.9, 0, 0, 20)
        label.Position = UDim2.new(0.05, 0, 0, yPos)
        label.BackgroundTransparency = 1
        label.Text = name .. ": " .. math.floor(baseVal)
        label.TextColor3 = Color3.fromRGB(220, 210, 235)
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(0.9, 0, 0, 8)
        barBg.Position = UDim2.new(0.05, 0, 0, yPos + 24)
        barBg.BackgroundColor3 = Color3.fromRGB(40, 34, 52)
        barBg.BorderSizePixel = 0
        barBg.Parent = frame

        local barBgCorner = Instance.new("UICorner", barBg)
        barBgCorner.CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((baseVal - minVal) / (maxVal - minVal), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
        fill.BorderSizePixel = 0
        fill.Parent = barBg

        local fillCorner = Instance.new("UICorner", fill)
        fillCorner.CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 20, 0, 20)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.new((baseVal - minVal) / (maxVal - minVal), 0, 0.5, 0)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.ZIndex = 10
        knob.Active = true
        knob.Parent = barBg

        local knobCorner = Instance.new("UICorner", knob)
        knobCorner.CornerRadius = UDim.new(1, 0)

        local knobStroke = Instance.new("UIStroke", knob)
        knobStroke.Color = Color3.fromRGB(138, 43, 226)
        knobStroke.Thickness = 2

        local dragging = false

        local function applyValue(relX)
            relX = math.clamp(relX, 0, 1)
            local value = minVal + (maxVal - minVal) * relX
            fill.Size = UDim2.new(relX, 0, 1, 0)
            knob.Position = UDim2.new(relX, 0, 0.5, 0)
            label.Text = name .. ": " .. math.floor(value)
            callback(value)
        end

        knob.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
                local relX = (input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X
                applyValue(relX)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        return function(resetVal)
            local relX = (resetVal - minVal) / (maxVal - minVal)
            applyValue(relX)
        end
    end

    local resetAngle, resetForce

    resetAngle = createSlider("Угол станта", 90, 10, 90, BASE_TARGET_ANGLE, function(v)
        _G.TargetAngle = v
    end)

    resetForce = createSlider("Резкость подъёма", 160, 500, 8000, BASE_MAX_FORCE, function(v)
        _G.MaxForce = v
        if currentGyro then currentGyro.MaxTorque = v end
    end)

    -- Кнопка сброса
    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(0.9, 0, 0, 32)
    resetBtn.Position = UDim2.new(0.05, 0, 0, 240)
    resetBtn.BackgroundColor3 = Color3.fromRGB(45, 20, 60)
    resetBtn.Text = "СБРОСИТЬ НА БАЗУ"
    resetBtn.TextColor3 = Color3.fromRGB(220, 200, 255)
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.TextSize = 13
    resetBtn.BorderSizePixel = 0
    resetBtn.Parent = frame

    local resetCorner = Instance.new("UICorner", resetBtn)
    resetCorner.CornerRadius = UDim.new(0, 6)

    resetBtn.MouseButton1Click:Connect(function()
        resetAngle(BASE_TARGET_ANGLE)
        resetForce(BASE_MAX_FORCE)
    end)

    -- Кнопка скрытия
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0.9, 0, 0, 32)
    closeBtn.Position = UDim2.new(0.05, 0, 1, -44)
    closeBtn.BackgroundColor3 = Color3.fromRGB(45, 20, 60)
    closeBtn.Text = "СКРЫТЬ"
    closeBtn.TextColor3 = Color3.fromRGB(220, 200, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 13
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = frame

    local closeCorner = Instance.new("UICorner", closeBtn)
    closeCorner.CornerRadius = UDim.new(0, 6)

    -- ================================================================
    -- КОНТЕЙНЕР: ШЕСТЕРЁНКА + КНОПКА OPEN
    -- ================================================================
    local gearContainer = Instance.new("Frame")
    gearContainer.Name = "GearContainer"
    gearContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    gearContainer.Size = UDim2.new(0, GEAR_SIZE + OPEN_W + 10, 0, GEAR_SIZE)
    gearContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
    gearContainer.BackgroundTransparency = 1
    gearContainer.Visible = false
    gearContainer.Active = true
    gearContainer.Parent = sg

    local gear = Instance.new("TextButton")
    gear.Size = UDim2.new(0, GEAR_SIZE, 0, GEAR_SIZE)
    gear.Position = UDim2.new(0, 0, 0, 0)
    gear.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    gear.Text = "⚙"
    gear.TextColor3 = Color3.fromRGB(255, 255, 255)
    gear.Font = Enum.Font.GothamBold
    gear.TextSize = 24
    gear.BorderSizePixel = 0
    gear.Active = true
    gear.AutoButtonColor = false
    gear.Parent = gearContainer

    local gearCorner = Instance.new("UICorner", gear)
    gearCorner.CornerRadius = UDim.new(1, 0)

    local gearStroke = Instance.new("UIStroke", gear)
    gearStroke.Color = Color3.fromRGB(200, 150, 255)
    gearStroke.Thickness = 2

    local openBtn = Instance.new("TextButton")
    openBtn.Size = UDim2.new(0, OPEN_W, 0, OPEN_H)
    openBtn.Position = UDim2.new(0, GEAR_SIZE + 10, 0.5, -OPEN_H / 2)
    openBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    openBtn.Text = "OPEN"
    openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    openBtn.Font = Enum.Font.GothamBold
    openBtn.TextSize = 14
    openBtn.BorderSizePixel = 0
    openBtn.AutoButtonColor = false
    openBtn.Parent = gearContainer

    local openCorner = Instance.new("UICorner", openBtn)
    openCorner.CornerRadius = UDim.new(0, 8)

    local openStroke = Instance.new("UIStroke", openBtn)
    openStroke.Color = Color3.fromRGB(200, 150, 255)
    openStroke.Thickness = 2

    -- Hover на OPEN
    openBtn.MouseEnter:Connect(function()
        TweenService:Create(openBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(160, 70, 240)
        }):Play()
    end)
    openBtn.MouseLeave:Connect(function()
        TweenService:Create(openBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(138, 43, 226)
        }):Play()
    end)

    makeDraggable(gearContainer, gear)

    -- ================================================================
    -- АНИМАЦИИ
    -- ================================================================
    local isOpen = true
    local animating = false

    local function showMenuContents(visible)
        for _, child in ipairs(frame:GetDescendants()) do
            if child:IsA("GuiObject") and child ~= frame then
                child.Visible = visible
            end
        end
    end

    local function openMenu()
        if isOpen or animating then return end
        animating = true

        showMenuContents(false)

        -- Старт — из центра шестерёнки
        local containerAbs = gearContainer.AbsolutePosition
        local containerSize = gearContainer.AbsoluteSize
        local gearCenterX = containerAbs.X + GEAR_SIZE / 2
        local gearCenterY = containerAbs.Y + containerSize.Y / 2

        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.Position = UDim2.new(0, gearCenterX, 0, gearCenterY)
        frame.Size = UDim2.new(0, GEAR_SIZE, 0, GEAR_SIZE)
        frame.BackgroundTransparency = 1
        stroke.Transparency = 1
        frame.Visible = true

        gearContainer.Visible = false

        local targetPos = lastMenuPosition
        local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        TweenService:Create(frame, tweenInfo, {
            Size = UDim2.new(0, MENU_W, 0, MENU_H),
            Position = targetPos,
            BackgroundTransparency = 0
        }):Play()

        TweenService:Create(stroke, tweenInfo, { Transparency = 0 }):Play()

        task.delay(0.4, function()
            showMenuContents(true)
            isOpen = true
            animating = false
        end)
    end

    local function closeMenu()
        if not isOpen or animating then return end
        animating = true

        lastMenuPosition = frame.Position
        showMenuContents(false)

        local targetPos = frame.Position
        local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

        TweenService:Create(frame, tweenInfo, {
            Size = UDim2.new(0, GEAR_SIZE, 0, GEAR_SIZE),
            Position = targetPos,
            BackgroundTransparency = 1
        }):Play()

        TweenService:Create(stroke, tweenInfo, { Transparency = 1 }):Play()

        task.delay(0.4, function()
            frame.Visible = false

            -- Ставим контейнер так, чтобы шестерёнка оказалась в targetPos
            local containerWidth = GEAR_SIZE + OPEN_W + 10
            local gearCenterOffsetX = (GEAR_SIZE / 2) - (containerWidth / 2)

            gearContainer.Position = UDim2.new(
                targetPos.X.Scale,
                targetPos.X.Offset - gearCenterOffsetX,
                targetPos.Y.Scale,
                targetPos.Y.Offset
            )

            gearContainer.Visible = true
            isOpen = false
            animating = false
        end)
    end

    openBtn.MouseButton1Click:Connect(openMenu)
    closeBtn.MouseButton1Click:Connect(closeMenu)

    -- ================================================================
    -- СТАРТОВОЕ ПОЯВЛЕНИЕ МЕНЮ ПО ЦЕНТРУ
    -- ================================================================
    showMenuContents(false)
    frame.Visible = true
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.Size = UDim2.new(0, MENU_W * 0.85, 0, MENU_H * 0.85)
    frame.BackgroundTransparency = 1
    stroke.Transparency = 1

    local appearInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    TweenService:Create(frame, appearInfo, {
        Size = UDim2.new(0, MENU_W, 0, MENU_H),
        BackgroundTransparency = 0
    }):Play()

    TweenService:Create(stroke, appearInfo, { Transparency = 0 }):Play()

    task.delay(0.6, function()
        showMenuContents(true)
        lastMenuPosition = UDim2.new(0.5, 0, 0.5, 0)
        isOpen = true
    end)
end

-- ====================================================================
-- ЗАПУСК ЧИТА
-- ====================================================================
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

    pcall(function()
        game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
            Text = "[Premium] Активировано! Зажмите LeftShift в машине для станта.",
            Color = Color3.fromRGB(0, 255, 150),
            Font = Enum.Font.SourceSansBold,
            TextSize = 14
        })
    end)
end

-- ====================================================================
-- ЗАГРУЗКА КЛЮЧЕЙ
-- ====================================================================
local function loadAndVerifyKey(enteredKey)
    local success, result = pcall(function()
        return game:HttpGet(KEYS_URL, true)
    end)

    if not success or not result or #result == 0 then
        return false, "Не удалось загрузить список ключей"
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

-- ====================================================================
-- UI АВТОРИЗАЦИИ
-- ====================================================================
local authSg = Instance.new("ScreenGui")
authSg.Name = "XenoFixPanel"
authSg.ResetOnSpawn = false
authSg.Parent = localPlayer:WaitForChild("PlayerGui")

local packLabel = Instance.new("TextLabel")
packLabel.Size = UDim2.new(0, 440, 0, 30)
packLabel.Position = UDim2.new(0.5, -220, 0.4, -45)
packLabel.BackgroundTransparency = 1
packLabel.Text = "STANDARD STUNT PACK"
packLabel.TextColor3 = Color3.fromRGB(186, 124, 255)
packLabel.Font = Enum.Font.GothamBold
packLabel.TextSize = 16
packLabel.Parent = authSg

local box = Instance.new("TextBox")
box.Size = UDim2.new(0, 440, 0, 45)
box.Position = UDim2.new(0.5, -220, 0.4, 0)
box.BackgroundColor3 = Color3.fromRGB(24, 20, 31)
box.TextColor3 = Color3.fromRGB(255, 255, 255)
box.PlaceholderText = "ВСТАВЬТЕ КЛЮЧ И НАЖМИТЕ ENTER"
box.PlaceholderColor3 = Color3.fromRGB(130, 115, 145)
box.Text = ""
box.Font = Enum.Font.GothamBold
box.TextSize = 11
box.BorderSizePixel = 2
box.BorderColor3 = Color3.fromRGB(138, 43, 226)
box.Parent = authSg

local UICorner = Instance.new("UICorner", box)
UICorner.CornerRadius = UDim.new(0, 6)

box.FocusLost:Connect(function(enterPressed)
    if not enterPressed then return end

    local enteredKey = string.gsub(box.Text, "[%s%c]+", "")

    if enteredKey == "" then
        box.Text = ""
        box.PlaceholderText = "ПОЛЕ НЕ МОЖЕТ БЫТЬ ПУСТЫМ!"
        box.BorderColor3 = Color3.fromRGB(255, 100, 0)
        return
    end

    box.Text = "ПРОВЕРКА КЛЮЧА..."
    box.BorderColor3 = Color3.fromRGB(186, 124, 255)
    task.wait(0.3)

    task.spawn(function()
        local isValid, message = loadAndVerifyKey(enteredKey)

        if isValid then
            box.Text = "УСПЕШНО!"
            box.TextColor3 = Color3.fromRGB(0, 255, 150)
            box.BorderColor3 = Color3.fromRGB(0, 255, 150)
            task.wait(0.8)
            authSg:Destroy()
            LaunchUniversalVehicleScript()
        else
            box.Text = "ОТКЛОНЕНО: " .. string.upper(tostring(message))
            box.BorderColor3 = Color3.fromRGB(255, 0, 0)
            task.wait(2.5)
            box.Text = ""
            box.PlaceholderText = "ВСТАВЬТЕ КЛЮЧ И НАЖМИТЕ ENTER"
            box.BorderColor3 = Color3.fromRGB(138, 43, 226)
        end
    end)
end)

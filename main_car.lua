-- ====================================================================
-- BY ASSETFINDER — VEHICLE SPEED SCRIPT
-- Стиль и механика скрытия — как в стант-скрипте
-- + система ключей (keys_2.txt)
-- ====================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- ====================================================================
-- НАСТРОЙКИ: ССЫЛКА НА ФАЙЛ С КЛЮЧАМИ (keys_2)
-- ====================================================================
local KEYS_URL = "https://raw.githubusercontent.com/PalkaEbalka/stunt/refs/heads/main/keys_2.txt"

-- ====================================================================
-- БАЗОВЫЕ НАСТРОЙКИ (ЗАВОДСКИЕ)
-- ====================================================================
local BASE_SPEED_MULT   = 0.025
local BASE_BRAKE_MULT   = 0.150
local BASE_VELOCITY_KEY = Enum.KeyCode.W
local BASE_BRAKE_KEY    = Enum.KeyCode.S
local BASE_STOP_KEY     = Enum.KeyCode.P

local currentSpeedMult  = BASE_SPEED_MULT
local currentBrakeMult  = BASE_BRAKE_MULT
local velocityKey       = BASE_VELOCITY_KEY
local brakeKey          = BASE_BRAKE_KEY
local stopKey           = BASE_STOP_KEY

-- Стадии (л.с.)
local currentStage = 0
local STAGE_HP = {
    [1] = 120,
    [2] = 260,
    [3] = 380,
}

-- ====================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ====================================================================
local function GetVehicleFromDescendant(Descendant)
    return
        Descendant:FindFirstAncestor(LocalPlayer.Name .. "\'s Car") or
        (Descendant:FindFirstAncestor("Body") and Descendant:FindFirstAncestor("Body").Parent) or
        (Descendant:FindFirstAncestor("Misc") and Descendant:FindFirstAncestor("Misc").Parent) or
        Descendant:FindFirstAncestorWhichIsA("Model")
end

local function GetSeatPart()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if not hum then return nil end
    local seat = hum.SeatPart
    if seat and seat:IsA("VehicleSeat") then
        return seat
    end
    return nil
end

local function GetVehicle()
    local seat = GetSeatPart()
    if not seat then return nil end
    return GetVehicleFromDescendant(seat)
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
-- ПРОВЕРКА КЛЮЧЕЙ С ПРИВЯЗКОЙ К USERID
-- ====================================================================
local function loadAndVerifyKey(enteredKey)
    local success, result = pcall(function()
        return game:HttpGet(KEYS_URL, true)
    end)

    if not success or not result or #result == 0 then
        return false, "Не удалось загрузить список ключей"
    end

    local myUserId = tostring(LocalPlayer.UserId)

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
authSg.Name = "AssetFinderAuthPanel"
authSg.ResetOnSpawn = false
authSg.IgnoreGuiInset = true
authSg.Parent = LocalPlayer:WaitForChild("PlayerGui")

local packLabel = Instance.new("TextLabel")
packLabel.Size = UDim2.new(0, 440, 0, 30)
packLabel.Position = UDim2.new(0.5, -220, 0.4, -45)
packLabel.BackgroundTransparency = 1
packLabel.Text = "STANDARD VEHICLE PACK"
packLabel.TextColor3 = Color3.fromRGB(186, 124, 255)
packLabel.Font = Enum.Font.GothamBold
packLabel.TextSize = 16
packLabel.Parent = authSg

local packShadow = Instance.new("UIStroke", packLabel)
packShadow.Color = Color3.fromRGB(60, 20, 100)
packShadow.Thickness = 1

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

-- ====================================================================
-- ФУНКЦИЯ ЗАПУСКА VEHICLE-СКРИПТА
-- ====================================================================
local function LaunchVehicleScript()

    -- ================================================================
    -- UI
    -- ================================================================
    local sg = Instance.new("ScreenGui")
    sg.Name = "AssetFinderVehicleMenu"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local MENU_W, MENU_H = 360, 420
    local GEAR_SIZE = 46
    local OPEN_W, OPEN_H = 90, 34

    -- ================================================================
    -- ОСНОВНОЙ ФРЕЙМ
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

    -- Шапка
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
    title.Text = "⚡ VEHICLE SPEED"
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

    -- ================================================================
    -- ПОЛЗУНКИ
    -- ================================================================
    local resetSpeed, resetBrake

    resetSpeed = createSlider("Скорость", 90, 0, 50, BASE_SPEED_MULT * 1000, function(v)
        currentSpeedMult = v / 1000
    end)

    resetBrake = createSlider("Тормоз", 160, 0, 300, BASE_BRAKE_MULT * 1000, function(v)
        currentBrakeMult = v / 1000
    end)

    -- ================================================================
    -- КНОПКИ STAGE 1/2/3 (с toggle-логикой)
    -- ================================================================
    local stageY = 240
    local stageBtnW = (MENU_W * 0.9 - 20) / 3

    local stageButtons = {}

    local function refreshStageButtons()
        for i, btn in ipairs(stageButtons) do
            if i == currentStage then
                btn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
                btn:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(200, 150, 255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(45, 20, 60)
                btn:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(80, 40, 120)
            end
        end
    end

    local function createStageButton(text, stageNum, xOffset)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, stageBtnW, 0, 36)
        btn.Position = UDim2.new(0.05, xOffset, 0, stageY)
        btn.BackgroundColor3 = Color3.fromRGB(45, 20, 60)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(220, 200, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.BorderSizePixel = 0
        btn.Parent = frame

        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(0, 6)

        local stageStroke = Instance.new("UIStroke", btn)
        stageStroke.Color = Color3.fromRGB(80, 40, 120)
        stageStroke.Thickness = 1

        btn.MouseButton1Click:Connect(function()
            if currentStage == stageNum then
                currentStage = 0
            else
                currentStage = stageNum
            end
            refreshStageButtons()
        end)

        table.insert(stageButtons, btn)
        return btn
    end

    createStageButton("STAGE 1", 1, 0)
    createStageButton("STAGE 2", 2, stageBtnW + 10)
    createStageButton("STAGE 3", 3, (stageBtnW + 10) * 2)

    -- ================================================================
    -- КНОПКА СБРОСА
    -- ================================================================
    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(0.9, 0, 0, 32)
    resetBtn.Position = UDim2.new(0.05, 0, 0, 290)
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
        resetSpeed(BASE_SPEED_MULT * 1000)
        resetBrake(BASE_BRAKE_MULT * 1000)
        currentStage = 0
        refreshStageButtons()
    end)

    -- ================================================================
    -- КНОПКА СКРЫТИЯ
    -- ================================================================
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
    -- КОНТЕЙНЕР: ШЕСТЕРЁНКА + OPEN
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
    -- СТАРТОВОЕ ПОЯВЛЕНИЕ
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

    -- ================================================================
    -- ЛОГИКА УСКОРЕНИЯ И ТОРМОЖЕНИЯ
    -- ================================================================
    local keybindActive = true

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.KeyCode == velocityKey and keybindActive then
            task.spawn(function()
                while UserInputService:IsKeyDown(velocityKey) and keybindActive do
                    task.wait(0)
                    local seat = GetSeatPart()
                    if seat then
                        local vehicle = GetVehicle()
                        if vehicle then
                            local stageBonus = 1 + (STAGE_HP[currentStage] or 0) / 1000
                            seat.AssemblyLinearVelocity *= Vector3.new(1 + currentSpeedMult * stageBonus, 1, 1 + currentSpeedMult * stageBonus)
                        end
                    end
                end
            end)
        end

        if input.KeyCode == brakeKey and keybindActive then
            task.spawn(function()
                while UserInputService:IsKeyDown(brakeKey) and keybindActive do
                    task.wait(0)
                    local seat = GetSeatPart()
                    if seat then
                        seat.AssemblyLinearVelocity *= Vector3.new(1 - currentBrakeMult, 1, 1 - currentBrakeMult)
                    end
                end
            end)
        end

        if input.KeyCode == stopKey and keybindActive then
            local seat = GetSeatPart()
            if seat then
                seat.AssemblyLinearVelocity *= Vector3.new(0, 0, 0)
                seat.AssemblyAngularVelocity *= Vector3.new(0, 0, 0)
            end
        end
    end)
end

-- ====================================================================
-- ЛОГИКА ПРОВЕРКИ КЛЮЧА
-- ====================================================================
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
            LaunchVehicleScript()
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

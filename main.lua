-- ====================================================================
-- ЛОКАЛЬНАЯ СИСТЕМА КЛЮЧЕЙ (РЕДАКТИРУЙ ЗДЕСЬ)
-- ====================================================================
-- Добавляй ключи в этот список. Формат: ["ключ"] = true,
-- Чтобы удалить ключ — просто удали строку с ним или поставь false.
local VALID_KEYS = {
    ["STUNT-2024-AAA"] = true,
    ["STUNT-2024-BBB"] = true,
    ["STUNT-2024-CCC"] = true,
    ["PREMIUM-KEY-001"] = true,
    ["TEST-KEY-12345"]  = true,
}

-- ====================================================================
-- БАЗОВЫЕ СЕРВИСЫ
-- ====================================================================
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

-- ====================================================================
-- НАСТРОЙКИ ЧИТА (СТАНТ / WHEELIE)
-- ====================================================================
_G.MaxForce = 2500
_G.TargetAngle = 45
_G.StuntKey = Enum.KeyCode.LeftShift

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
-- ЗАПУСК ЧИТА ПОСЛЕ УСПЕШНОЙ АВТОРИЗАЦИИ
-- ====================================================================
local function LaunchUniversalVehicleScript()
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
-- UI ДЛЯ ВВОДА КЛЮЧА
-- ====================================================================
local authSg = Instance.new("ScreenGui")
authSg.Name = "XenoFixPanel"
authSg.ResetOnSpawn = false
authSg.Parent = localPlayer:WaitForChild("PlayerGui")

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

-- Логика проверки (полностью локальная, без интернета)
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

    if VALID_KEYS[enteredKey] == true then
        box.Text = "УСПЕШНО!"
        box.TextColor3 = Color3.fromRGB(0, 255, 150)
        box.BorderColor3 = Color3.fromRGB(0, 255, 150)
        task.wait(0.8)
        authSg:Destroy()
        LaunchUniversalVehicleScript()
    else
        box.Text = "ОТКЛОНЕНО: НЕВЕРНЫЙ КЛЮЧ"
        box.BorderColor3 = Color3.fromRGB(255, 0, 0)
        task.wait(2)
        box.Text = ""
        box.PlaceholderText = "ВСТАВЬТЕ КЛЮЧ И НАЖМИТЕ ENTER"
        box.BorderColor3 = Color3.fromRGB(138, 43, 226)
    end
end)

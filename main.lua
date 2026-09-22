-- ====================================================================
-- НАСТРОЙКИ KEYAUTH (ТВОИ ДАННЫЕ)
-- ====================================================================
local KeyAuthApp = {
    Name = "StuntRideScript",
    OwnerId = "7crCQYeTdu",
    Secret = "ef961ebc9e78ce17119a46d1aeacfb5fe000413fc444ae8290c2f9fcf58403d0",
    Version = "1.0"
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

-- HWID для ПК
local fakeHwid = "XenoPC_" .. tostring(localPlayer.UserId or 12345)

-- ====================================================================
-- ПАРСЕР ОТВЕТОВ KEYAUTH
-- ====================================================================
local function customParseField(body, fieldName)
    if not body or body == "" then return nil end
    local pattern = '"' .. fieldName .. '"%s*:%s*"([^"]+)"'
    local match = string.match(body, pattern)
    if not match then
        pattern = '"' .. fieldName .. '"%s*:%s*([%w]+)'
        match = string.match(body, pattern)
    end
    return match
end

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

    -- Приятное уведомление в чате
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
-- МЕТОД ЗАПРОСА (XENO)
-- ====================================================================
local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request

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

-- Логика верификации
box.FocusLost:Connect(function(enterPressed)
    if not enterPressed then return end
    
    local enteredKey = string.gsub(box.Text, "[%s%c]+", "")
    
    if enteredKey == "" then
        box.Text = ""
        box.PlaceholderText = "ПОЛЕ НЕ МОЖЕТ БЫТЬ ПУСТЫМ!"
        box.BorderColor3 = Color3.fromRGB(255, 100, 0)
        return
    end

    box.Text = "ПОДКЛЮЧЕНИЕ..."
    box.BorderColor3 = Color3.fromRGB(186, 124, 255)
    task.wait(0.05)

    if not requestFunc then
        box.Text = "ОШИБКА: XENO НЕ ПОДДЕРЖИВАЕТ ИНТЕРНЕТ"
        box.BorderColor3 = Color3.fromRGB(255, 0, 0)
        return
    end

    task.spawn(function()
        -- ШАГ 1: INIT
        local successInit, initResponse = pcall(function()
            return requestFunc({
                Url = "https://keyauth.win/api/1.3/",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/x-www-form-urlencoded",
                    ["User-Agent"] = "Mozilla/5.0"
                },
                Body = "type=init&name=" .. KeyAuthApp.Name .. "&ownerid=" .. KeyAuthApp.OwnerId .. "&secret=" .. KeyAuthApp.Secret .. "&version=" .. KeyAuthApp.Version
            })
        end)

        if successInit and initResponse and initResponse.Body then
            local responseBody = tostring(initResponse.Body)
            local isInitSuccess = customParseField(responseBody, "success")
            
            if isInitSuccess == "true" then
                local sessionId = customParseField(responseBody, "sessionid")
                
                if sessionId and sessionId ~= "" then
                    box.Text = "ПРОВЕРКА КЛЮЧА..."
                    
                    -- ШАГ 2: LICENSE
                    local successLicense, licenseResponse = pcall(function()
                        return requestFunc({
                            Url = "https://keyauth.win/api/1.3/",
                            Method = "POST",
                            Headers = {
                                ["Content-Type"] = "application/x-www-form-urlencoded",
                                ["User-Agent"] = "Mozilla/5.0"
                            },
                            Body = "type=license&key=" .. enteredKey .. "&sessionid=" .. sessionId .. "&name=" .. KeyAuthApp.Name .. "&ownerid=" .. KeyAuthApp.OwnerId .. "&secret=" .. KeyAuthApp.Secret .. "&version=" .. KeyAuthApp.Version .. "&hwid=" .. fakeHwid
                        })
                    end)

                    if successLicense and licenseResponse and licenseResponse.Body then
                        local licenseBody = tostring(licenseResponse.Body)
                        local isLicenseSuccess = customParseField(licenseBody, "success")
                        
                        if isLicenseSuccess == "true" then
                            box.Text = "УСПЕШНО!"
                            box.TextColor3 = Color3.fromRGB(0, 255, 150)
                            box.BorderColor3 = Color3.fromRGB(0, 255, 150)
                            task.wait(0.8)
                            authSg:Destroy()
                            
                            -- ЗАПУСК ЧИТА
                            LaunchUniversalVehicleScript()
                        else
                            local errorMsg = customParseField(licenseBody, "message") or "НЕВЕРНЫЙ КЛЮЧ"
                            box.Text = "ОТКЛОНЕНО: " .. string.upper(tostring(errorMsg))
                            box.BorderColor3 = Color3.fromRGB(255, 0, 0)
                        end
                    else
                        box.Text = "ОШИБКА ОТВЕТА ЛИЦЕНЗИИ"
                        box.BorderColor3 = Color3.fromRGB(255, 0, 0)
                    end
                else
                    box.Text = "ОШИБКА СЕССИИ"
                    box.BorderColor3 = Color3.fromRGB(255, 0, 0)
                end
            else
                local initError = customParseField(responseBody, "message") or "ДАННЫЕ ПАНЕЛИ НЕВЕРНЫ"
                box.Text = "ОТКЛОНЕНО: " .. string.upper(tostring(initError))
                box.BorderColor3 = Color3.fromRGB(255, 0, 0)
            end
        else
            box.Text = "СЕТЬ ЗАКРЫТА (ТАЙМАУТ)"
            box.BorderColor3 = Color3.fromRGB(255, 0, 0)
            task.wait(3)
            box.Text = ""
            box.PlaceholderText = "ВСТАВЬТЕ КЛЮЧ И НАЖМИТЕ ENTER"
            box.BorderColor3 = Color3.fromRGB(138, 43, 226)
        end
    end)
end)

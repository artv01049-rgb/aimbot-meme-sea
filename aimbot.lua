local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Silent Aim - Meme Sea",
    LoadingTitle = "Carregando...",
    LoadingSubtitle = "ART",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false, Invite = "noinvitelink", RememberJoins = true },
    KeySystem = false
})

local MainTab = Window:CreateTab("Principal", nil)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local SilentAimEnabled = false
local TeamCheck = false
local FOV = 150
local MAX_DISTANCE = 600
local RELEASE_DELAY = 0.15
local StreamerMode = false

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local CurrentCamera = Workspace.CurrentCamera
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    CurrentCamera = Workspace.CurrentCamera
end)

local cachedPart = nil
local cachedPos = nil
local cachedCFrame = nil
local cachedUnitRay = nil
local cachedRayInfo = nil

local aiming = false
local aimToken = 0

local oldIndex = nil
local oldNamecall = nil
local hooksInstalled = false

local function GetCenterPart(character)
    if not character then return nil end
    local upper = character:FindFirstChild("UpperTorso")
    if upper then return upper end
    local lower = character:FindFirstChild("LowerTorso")
    if lower then return lower end
    local torso = character:FindFirstChild("Torso")
    if torso then return torso end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp end
    return character:FindFirstChild("Head")
end

local function FindClosestPlayer()
    local closest = nil
    local shortest = FOV

    local refX, refY
    if isMobile then
        refX = CurrentCamera.ViewportSize.X / 2
        refY = CurrentCamera.ViewportSize.Y / 2
    else
        refX = Mouse.X
        refY = Mouse.Y
    end

    local myPos = CurrentCamera.CFrame.Position

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if TeamCheck and player.Team == LocalPlayer.Team then continue end

        local character = player.Character
        if not character then continue end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        local part = GetCenterPart(character)
        if not part then continue end

        local pos = part.Position
        if (pos - myPos).Magnitude > MAX_DISTANCE then continue end

        local screenPos, onScreen = CurrentCamera:WorldToViewportPoint(pos)
        if onScreen then
            local dx = screenPos.X - refX
            local dy = screenPos.Y - refY
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < shortest then
                closest = part
                shortest = dist
            end
        end
    end

    return closest
end

local function RefreshTarget()
    if not SilentAimEnabled then
        cachedPart = nil
        cachedPos = nil
        cachedCFrame = nil
        cachedUnitRay = nil
        cachedRayInfo = nil
        return
    end

    local part = FindClosestPlayer()
    if part and part.Parent then
        cachedPart = part
        cachedPos = part.Position
        cachedCFrame = CFrame.new(cachedPos)

        local camPos = CurrentCamera.CFrame.Position
        local dir = cachedPos - camPos
        if dir.Magnitude > 0.5 then
            local unitDir = dir.Unit
            cachedUnitRay = Ray.new(camPos, unitDir)
            cachedRayInfo = { origin = camPos, dir = unitDir }
        else
            cachedUnitRay = nil
            cachedRayInfo = nil
        end
    else
        cachedPart = nil
        cachedPos = nil
        cachedCFrame = nil
        cachedUnitRay = nil
        cachedRayInfo = nil
    end
end

task.spawn(function()
    while task.wait(0.1) do
        RefreshTarget()
    end
end)

local function InstallHooks()
    if hooksInstalled then return end

    local ok = pcall(function()
        oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
            if cachedPart and self == Mouse then
                if key == "Hit" then return cachedCFrame end
                if key == "Target" then return cachedPart end
                if key == "UnitRay" then return cachedUnitRay end
            end
            return oldIndex(self, key)
        end))

        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            if aiming and cachedRayInfo then
                if self == CurrentCamera then
                    local method = getnamecallmethod()
                    if method == "ViewportPointToRay" or method == "ScreenPointToRay" then
                        return Ray.new(cachedRayInfo.origin, cachedRayInfo.dir)
                    end
                elseif self == Workspace then
                    local method = getnamecallmethod()
                    if method == "Raycast" then
                        local origin, direction, params = ...
                        if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                            local camPos = CurrentCamera.CFrame.Position
                            if (origin - camPos).Magnitude < 15 then
                                local newDir = cachedPos - origin
                                if newDir.Magnitude > 0.5 then
                                    return oldNamecall(self, origin, newDir.Unit * direction.Magnitude, params)
                                end
                            end
                        end
                    elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
                        local ray = ...
                        if typeof(ray) == "Ray" then
                            local camPos = CurrentCamera.CFrame.Position
                            if (ray.Origin - camPos).Magnitude < 15 then
                                local newDir = cachedPos - ray.Origin
                                if newDir.Magnitude > 0.5 then
                                    local newRay = Ray.new(ray.Origin, newDir.Unit * ray.Direction.Magnitude)
                                    return oldNamecall(self, newRay, select(2, ...))
                                end
                            end
                        end
                    end
                end
            end
            return oldNamecall(self, ...)
        end))
    end)

    if ok then hooksInstalled = true end
end

local function RemoveHooks()
    if not hooksInstalled then return end
    pcall(function()
        if oldIndex then hookmetamethod(game, "__index", oldIndex) end
        if oldNamecall then hookmetamethod(game, "__namecall", oldNamecall) end
    end)
    hooksInstalled = false
end

local function BeginAim()
    RefreshTarget()
    if not cachedPos then return end
    aiming = true
    aimToken = aimToken + 1
end

local function EndAim()
    local myToken = aimToken
    task.delay(RELEASE_DELAY, function()
        if aimToken == myToken then
            aiming = false
        end
    end)
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if not SilentAimEnabled then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        BeginAim()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        if aiming then EndAim() end
    end
end)

local RayfieldGui = nil

local function FindRayfieldGui()
    local ok, children = pcall(function()
        return game:GetService("CoreGui"):GetChildren()
    end)
    if ok then
        for _, obj in ipairs(children) do
            if obj:IsA("ScreenGui") and obj.Name:lower():find("rayfield") then
                return obj
            end
        end
    end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, obj in ipairs(pg:GetChildren()) do
            if obj:IsA("ScreenGui") and obj.Name:lower():find("rayfield") then
                return obj
            end
        end
    end
    return nil
end

task.spawn(function()
    for _ = 1, 10 do
        RayfieldGui = FindRayfieldGui()
        if RayfieldGui then return end
        task.wait(0.2)
    end
end)

local panicGui = Instance.new("ScreenGui")
panicGui.Name = "MemeSeaStreamerPanic"
panicGui.ResetOnSpawn = false
panicGui.IgnoreGuiInset = true
panicGui.DisplayOrder = 2147483647
panicGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parentOk = pcall(function()
    panicGui.Parent = game:GetService("CoreGui")
end)
if not parentOk then
    panicGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local panicButton = Instance.new("TextButton")
panicButton.Name = "PanicBtn"
panicButton.Size = UDim2.fromOffset(28, 28)
panicButton.Position = UDim2.new(1, -38, 1, -38)
panicButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
panicButton.BackgroundTransparency = 0.8
panicButton.BorderSizePixel = 0
panicButton.TextColor3 = Color3.fromRGB(255, 255, 255)
panicButton.Text = "×"
panicButton.TextSize = 18
panicButton.Font = Enum.Font.GothamBold
panicButton.AutoButtonColor = false
panicButton.Visible = false
panicButton.Parent = panicGui

local panicCorner = Instance.new("UICorner")
panicCorner.CornerRadius = UDim.new(1, 0)
panicCorner.Parent = panicButton

local panicStroke = Instance.new("UIStroke")
panicStroke.Thickness = 1
panicStroke.Color = Color3.fromRGB(255, 255, 255)
panicStroke.Transparency = 0.7
panicStroke.Parent = panicButton

local function SetStreamerMode(state)
    StreamerMode = state
    if not RayfieldGui then
        RayfieldGui = FindRayfieldGui()
    end
    if RayfieldGui then
        RayfieldGui.Enabled = not state
    end
    panicButton.Visible = state
end

panicButton.MouseButton1Click:Connect(function()
    SetStreamerMode(false)
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        SetStreamerMode(not StreamerMode)
    end
end)

MainTab:CreateSection("Silent Aim")

MainTab:CreateToggle({
    Name = "Ativar Silent Aim",
    CurrentValue = false,
    Flag = "SilentAimToggle",
    Callback = function(value)
        SilentAimEnabled = value
        if value then
            InstallHooks()
            task.defer(RefreshTarget)
        else
            aiming = false
            cachedPart = nil
            cachedPos = nil
            cachedCFrame = nil
            cachedUnitRay = nil
            cachedRayInfo = nil
        end
    end,
})

MainTab:CreateToggle({
    Name = "Verificar Time",
    CurrentValue = false,
    Flag = "TeamCheckToggle",
    Callback = function(value)
        TeamCheck = value
    end,
})

MainTab:CreateSlider({
    Name = "FOV",
    Range = {50, 400},
    Increment = 10,
    Suffix = "px",
    CurrentValue = 150,
    Flag = "FOVSlider",
    Callback = function(value)
        FOV = value
    end,
})

MainTab:CreateSlider({
    Name = "Distancia Maxima",
    Range = {50, 800},
    Increment = 25,
    Suffix = " studs",
    CurrentValue = 600,
    Flag = "MaxDistSlider",
    Callback = function(value)
        MAX_DISTANCE = value
    end,
})

MainTab:CreateSection("Privacidade")

MainTab:CreateToggle({
    Name = "Modo Streamer (esconde tudo)",
    CurrentValue = false,
    Flag = "StreamerModeToggle",
    Callback = function(value)
        SetStreamerMode(value)
    end,
})

MainTab:CreateLabel("PC: RightShift alterna | Mobile: botao X no canto")

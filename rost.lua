local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local environment = getgenv()
local calledUnloaders = {}
local function callUnloader(unloader)
    if type(unloader) == "function" and not calledUnloaders[unloader] then
        calledUnloaders[unloader] = true
        pcall(unloader)
    end
end
callUnloader(environment.RostCombinedUnload)
callUnloader(environment.RostBoxESPUnload)
callUnloader(environment.RostAlphaSilentAimUnload)

local localPlayer = Players.LocalPlayer
local characters = Workspace:WaitForChild("Characters")
local connections = {}
local tracked = {}

environment.Enabled = true
environment.HitPart = "Head"
environment.HitChance = 100
environment.FOV = tonumber(environment.FOV) or 200
environment.Prediction = true
environment.GravityCompensation = true
environment.NoSpread = true
environment.NoRecoil = true

local function disconnect(connection)
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
    end
end

local function getNumber(name, default, minimum, maximum)
    return math.clamp(tonumber(environment[name]) or default, minimum, maximum)
end

local guiParent = localPlayer:WaitForChild("PlayerGui")
local guiParents = { guiParent }
local hiddenUiOk, hiddenUi = pcall(function()
    return gethui()
end)
if hiddenUiOk and hiddenUi and hiddenUi ~= guiParent then
    guiParents[#guiParents + 1] = hiddenUi
end
for _, parent in ipairs(guiParents) do
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("ScreenGui") and child.Name == "RostBoxESP" then
            child:Destroy()
        end
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "RostBoxESP"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.Parent = guiParent

local bodyNames = {
    Head = true,
    Torso = true,
    ["Left Arm"] = true,
    ["Right Arm"] = true,
    ["Left Leg"] = true,
    ["Right Leg"] = true,
    HumanoidRootPart = true,
}

local cornerSigns = {
    Vector3.new(-1, -1, -1), Vector3.new(-1, -1, 1),
    Vector3.new(-1, 1, -1), Vector3.new(-1, 1, 1),
    Vector3.new(1, -1, -1), Vector3.new(1, -1, 1),
    Vector3.new(1, 1, -1), Vector3.new(1, 1, 1),
}

local function makeLine(parent, name, color, position, size)
    local line = Instance.new("Frame")
    line.Name = name
    line.BackgroundColor3 = color
    line.BorderSizePixel = 0
    line.Position = position
    line.Size = size
    line.Parent = parent
end

local function makeRectangle(parent, prefix, color, inset)
    makeLine(parent, prefix .. "Top", color, UDim2.fromOffset(inset, inset), UDim2.new(1, -inset * 2, 0, 1))
    makeLine(parent, prefix .. "Bottom", color, UDim2.new(0, inset, 1, -inset - 1), UDim2.new(1, -inset * 2, 0, 1))
    makeLine(parent, prefix .. "Left", color, UDim2.fromOffset(inset, inset), UDim2.new(0, 1, 1, -inset * 2))
    makeLine(parent, prefix .. "Right", color, UDim2.new(1, -inset - 1, 0, inset), UDim2.new(0, 1, 1, -inset * 2))
end

local function createBox(model)
    if tracked[model] or not model:IsA("Model") or model.Name == localPlayer.Name then
        return
    end

    local frame = Instance.new("Frame")
    frame.Name = model.Name
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = gui

    makeRectangle(frame, "Outer", Color3.new(0, 0, 0), 0)
    makeRectangle(frame, "White", Color3.new(1, 1, 1), 1)
    makeRectangle(frame, "Inner", Color3.new(0, 0, 0), 2)
    tracked[model] = frame
end

local function removeBox(model)
    local frame = tracked[model]
    if frame then
        frame:Destroy()
        tracked[model] = nil
    end
end

local function projectModel(model)
    local camera = Workspace.CurrentCamera
    if not camera then
        return nil
    end

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local found = false

    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("BasePart") and bodyNames[child.Name] then
            local half = child.Size * 0.5
            for _, sign in ipairs(cornerSigns) do
                local point = camera:WorldToViewportPoint(child.CFrame:PointToWorldSpace(half * sign))
                if point.Z > 0 then
                    found = true
                    minX = math.min(minX, point.X)
                    minY = math.min(minY, point.Y)
                    maxX = math.max(maxX, point.X)
                    maxY = math.max(maxY, point.Y)
                end
            end
        end
    end

    if not found then
        return nil
    end

    local viewport = camera.ViewportSize
    if maxX < 0 or maxY < 0 or minX > viewport.X or minY > viewport.Y then
        return nil
    end

    minX = math.floor(math.clamp(minX, 0, viewport.X))
    minY = math.floor(math.clamp(minY, 0, viewport.Y))
    maxX = math.ceil(math.clamp(maxX, 0, viewport.X))
    maxY = math.ceil(math.clamp(maxY, 0, viewport.Y))

    local width, height = maxX - minX, maxY - minY
    if width < 7 or height < 7 then
        return nil
    end
    return Vector2.new(minX, minY), Vector2.new(width, height)
end

for _, model in ipairs(characters:GetChildren()) do
    createBox(model)
end

connections[#connections + 1] = characters.ChildAdded:Connect(createBox)
connections[#connections + 1] = characters.ChildRemoved:Connect(removeBox)

local function lockDaytime()
    if Lighting.ClockTime ~= 12 then
        Lighting.ClockTime = 12
    end
end

lockDaytime()
connections[#connections + 1] = Lighting:GetPropertyChangedSignal("ClockTime"):Connect(lockDaytime)
connections[#connections + 1] = RunService.RenderStepped:Connect(function()
    for model, frame in pairs(tracked) do
        if model.Parent ~= characters then
            removeBox(model)
        else
            local position, size = projectModel(model)
            if position then
                frame.Position = UDim2.fromOffset(position.X, position.Y)
                frame.Size = UDim2.fromOffset(size.X, size.Y)
                frame.Visible = true
            else
                frame.Visible = false
            end
        end
    end
end)

local silentState = environment.__RostAlphaSilentAim or {}
environment.__RostAlphaSilentAim = silentState
disconnect(silentState.Connection)
silentState.Connection = nil
if silentState.Circle then
    pcall(function()
        silentState.Circle:Remove()
    end)
    silentState.Circle = nil
end

local GunClientModule = ReplicatedStorage:FindFirstChild("GunClient", true)
assert(GunClientModule and GunClientModule:IsA("ModuleScript"), "GunClient module was not found")
local GunClient = require(GunClientModule)
assert(type(GunClient) == "table" and type(GunClient.getfireDirection) == "function", "GunClient.getfireDirection was not found")

local RecoilHandlerModule = ReplicatedStorage:FindFirstChild("RecoilHandler", true)
assert(RecoilHandlerModule and RecoilHandlerModule:IsA("ModuleScript"), "RecoilHandler module was not found")
local RecoilHandler = require(RecoilHandlerModule)
assert(type(RecoilHandler) == "table" and type(RecoilHandler.nextStep) == "function", "RecoilHandler.nextStep was not found")

local function getTarget()
    local camera = Workspace.CurrentCamera
    if not camera then
        return nil
    end

    local closestDistance = getNumber("FOV", 200, 0, 5000)
    local closestPart = nil
    local center = camera.ViewportSize * 0.5
    local hitPartName = type(environment.HitPart) == "string" and environment.HitPart or "Head"

    for _, character in ipairs(characters:GetChildren()) do
        if character:IsA("Model") and character.Name ~= localPlayer.Name then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local part = character:FindFirstChild(hitPartName) or character:FindFirstChild("HumanoidRootPart")
            if humanoid and humanoid.Health > 0 and part and part:IsA("BasePart") then
                local point, onScreen = camera:WorldToViewportPoint(part.Position)
                if onScreen and point.Z > 0 then
                    local distance = (Vector2.new(point.X, point.Y) - center).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        closestPart = part
                    end
                end
            end
        end
    end
    return closestPart
end

silentState.GetTarget = getTarget

local function getEquippedTool()
    local character = characters:FindFirstChild(localPlayer.Name)
    if not character then
        return nil
    end
    return character:FindFirstChildOfClass("Tool")
end

local function getGunObject()
    local equippedTool = getEquippedTool()
    if silentState.GunObject and (not equippedTool or silentState.GunObject.Tool == equippedTool) then
        return silentState.GunObject
    end

    silentState.GunObject = nil
    if type(filtergc) == "function" then
        local ok, object = pcall(function()
            if equippedTool then
                return filtergc("table", {
                    Keys = { "BaseBulletVelocity", "FireVisuals" },
                    KeyValuePairs = { Tool = equippedTool },
                }, true)
            end
            return filtergc("table", { Keys = { "BaseBulletVelocity", "FireVisuals" } }, true)
        end)
        if ok and type(object) == "table" then
            silentState.GunObject = object
        end
    end
    return silentState.GunObject
end

local function getProjectileData()
    local gunObject = getGunObject()
    local speed = 2000
    local acceleration = Vector3.zero

    if gunObject then
        if type(gunObject.BaseBulletVelocity) == "number" then
            speed = gunObject.BaseBulletVelocity
        end
        local fireVisuals = gunObject.FireVisuals
        if type(fireVisuals) == "table" then
            if type(fireVisuals.Velocity) == "number" then
                speed = fireVisuals.Velocity
            end
            local packet = fireVisuals.CastDataPacket
            if type(packet) == "table" and typeof(packet.Acceleration) == "Vector3" then
                acceleration = packet.Acceleration
            end
        end
    end

    return math.max(speed, 1), acceleration
end

silentState.GetProjectileData = getProjectileData

if not silentState.HookInstalled then
    local original
    local function fireDirectionHook(...)
        local arguments = table.pack(...)
        local results = table.pack(original(table.unpack(arguments, 1, arguments.n)))
        if not environment.Enabled or math.random(1, 100) > getNumber("HitChance", 100, 0, 100) then
            return table.unpack(results, 1, results.n)
        end

        local origin = arguments[2]
        local targetPart = silentState.GetTarget and silentState.GetTarget()
        if typeof(origin) ~= "Vector3" or not targetPart or not targetPart.Parent then
            return table.unpack(results, 1, results.n)
        end

        local targetPosition = targetPart.Position
        if environment.Prediction ~= false then
            local speed, acceleration = getProjectileData()
            local targetVelocity = targetPart.AssemblyLinearVelocity
            local travelTime = (targetPosition - origin).Magnitude / speed
            for _ = 1, 2 do
                targetPosition = targetPart.Position + targetVelocity * travelTime
                if environment.GravityCompensation ~= false then
                    targetPosition -= acceleration * (0.5 * travelTime * travelTime)
                end
                travelTime = (targetPosition - origin).Magnitude / speed
            end
        end

        local offset = targetPosition - origin
        if offset.Magnitude > 0 then
            results[1] = offset.Unit
            results.n = math.max(results.n, 1)
        end
        return table.unpack(results, 1, results.n)
    end

    local wrapped = type(newcclosure) == "function" and newcclosure(fireDirectionHook) or fireDirectionHook
    original = hookfunction(GunClient.getfireDirection, wrapped)
    silentState.Original = original
    silentState.HookInstalled = true
end

if type(GunClient.getBulletSpread) == "function" and not silentState.SpreadHookInstalled then
    local originalSpread
    local function spreadHook(...)
        if environment.NoSpread then
            return 0
        end
        return originalSpread(...)
    end
    local wrappedSpread = type(newcclosure) == "function" and newcclosure(spreadHook) or spreadHook
    originalSpread = hookfunction(GunClient.getBulletSpread, wrappedSpread)
    silentState.OriginalSpread = originalSpread
    silentState.SpreadHookInstalled = true
end

if not silentState.RecoilHookInstalled then
    local originalRecoil
    local function recoilHook(...)
        if environment.NoRecoil then
            return nil
        end
        return originalRecoil(...)
    end
    local wrappedRecoil = type(newcclosure) == "function" and newcclosure(recoilHook) or recoilHook
    originalRecoil = hookfunction(RecoilHandler.nextStep, wrappedRecoil)
    silentState.OriginalRecoil = originalRecoil
    silentState.RecoilHookInstalled = true
end

if type(Drawing) == "table" and type(Drawing.new) == "function" then
    local circle = Drawing.new("Circle")
    circle.Color = Color3.new(1, 1, 1)
    circle.Thickness = 1
    circle.NumSides = 64
    circle.Filled = false
    circle.Visible = true
    silentState.Circle = circle

    silentState.Connection = RunService.PreRender:Connect(function()
        local camera = Workspace.CurrentCamera
        circle.Visible = environment.Enabled == true
        if circle.Visible and camera then
            circle.Radius = getNumber("FOV", 200, 0, 5000)
            circle.Position = camera.ViewportSize * 0.5
        end
    end)
end

environment.RostCombinedUnload = function()
    environment.Enabled = false
    for _, connection in ipairs(connections) do
        disconnect(connection)
    end
    table.clear(connections)
    disconnect(silentState.Connection)
    silentState.Connection = nil
    if silentState.Circle then
        pcall(function()
            silentState.Circle:Remove()
        end)
        silentState.Circle = nil
    end
    if silentState.HookInstalled and type(restorefunction) == "function" then
        pcall(function()
            restorefunction(GunClient.getfireDirection)
        end)
        silentState.HookInstalled = false
        silentState.Original = nil
    end
    if silentState.SpreadHookInstalled and type(restorefunction) == "function" then
        pcall(function()
            restorefunction(GunClient.getBulletSpread)
        end)
        silentState.SpreadHookInstalled = false
        silentState.OriginalSpread = nil
    end
    if silentState.RecoilHookInstalled and type(restorefunction) == "function" then
        pcall(function()
            restorefunction(RecoilHandler.nextStep)
        end)
        silentState.RecoilHookInstalled = false
        silentState.OriginalRecoil = nil
    end
    for _, frame in pairs(tracked) do
        frame:Destroy()
    end
    table.clear(tracked)
    if gui.Parent then
        gui:Destroy()
    end
end

environment.RostBoxESPUnload = environment.RostCombinedUnload
environment.RostAlphaSilentAimUnload = environment.RostCombinedUnload

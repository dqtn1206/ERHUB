local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local VirtualInputManager = game:GetService('VirtualInputManager')

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end
if not player.Character or not player.Character.Parent then
    player.CharacterAdded:Wait()
end

local character = player.Character
local humanoid = character:WaitForChild('Humanoid')
local backpack = player:WaitForChild('Backpack')
local leaderstats = player:WaitForChild('leaderstats', 10)
local cash = leaderstats:WaitForChild('Cash', 10)

local RemoteFunctions = ReplicatedStorage:WaitForChild('RemoteFunctions', 10)
local UpgradeUnit = RemoteFunctions:WaitForChild('UpgradeUnit', 10)

local map = workspace:WaitForChild('Map', 10)
local Entities = map:WaitForChild('Entities', 10)

local toolName = 'Pineapple Cannon'
local spawnPositions = {
    Vector3.new(-851.3934, 61.9303, -134.8235), -- A
    Vector3.new(-836.6157, 61.9303, -162.7367), -- B
}
local togglePos = 1
local unitPrice = 400
local upgradePrices = { 250, 350 }
local unitPlaced = false
local currentUpgrade = 1
local placedUnitId = nil

local function getTool()
    return backpack:FindFirstChild(toolName)
end

local function moveTo(pos)
    local offsetX = (math.random() - 0.5) * 2
    local offsetZ = (math.random() - 0.5) * 2
    local targetPos = Vector3.new(pos.X + offsetX, pos.Y, pos.Z + offsetZ)
    humanoid:MoveTo(targetPos)
    humanoid.MoveToFinished:Wait()
end

local function resetState()
    unitPlaced = false
    currentUpgrade = 1
    placedUnitId = nil
end

-- Đặt unit thật như con người: cầm tool, di chuyển, Activate
local function placeUnit()
    if unitPlaced then
        return
    end
    local currentCash = tonumber(cash.Value) or 0
    if currentCash < unitPrice then
        return
    end

    local tool = getTool()
    if not tool then
        warn('[AutoUnit] Không tìm thấy Tool: ' .. toolName)
        return
    end

    local pos = spawnPositions[togglePos]
    togglePos = 3 - togglePos -- luân phiên

    moveTo(pos)
    humanoid:EquipTool(tool)
    task.wait(0.1)
    tool:Activate() -- sẽ đặt unit tại vị trí nhân vật đứng
    unitPlaced = true
    print('[AutoUnit] Đã đặt Pineapple Cannon tại ' .. tostring(pos))
end

-- Lấy ID unit khi spawn
Entities.ChildAdded:Connect(function(child)
    if child.Name == 'unit_pineapple' and not placedUnitId then
        local idValue = child:GetAttribute('ID')
        if idValue then
            placedUnitId = idValue
        end
    end
end)

Entities.ChildRemoved:Connect(function()
    task.delay(1, function()
        if #Entities:GetChildren() == 0 then
            resetState()
        end
    end)
end)

-- Nâng cấp unit khi đủ tiền
local function tryUpgradeUnit()
    if not placedUnitId then
        return
    end
    if currentUpgrade > #upgradePrices then
        return
    end
    local currentCash = tonumber(cash.Value) or 0
    local cost = upgradePrices[currentUpgrade]

    while currentCash >= cost do
        local ok = pcall(function()
            UpgradeUnit:InvokeServer(placedUnitId)
        end)
        if ok then
            print('[AutoUnit] Nâng cấp unit lên lv' .. currentUpgrade)
            currentUpgrade += 1
        end
        currentCash = tonumber(cash.Value) or 0
        if currentUpgrade > #upgradePrices then
            break
        end
        cost = upgradePrices[currentUpgrade]
        task.wait(0.05)
    end
end

-- Anti-AFK
task.spawn(function()
    while true do
        pcall(function()
            VirtualInputManager:SendKeyEvent(
                true,
                Enum.KeyCode.Space,
                false,
                game
            )
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(
                false,
                Enum.KeyCode.Space,
                false,
                game
            )
        end)
        task.wait(60)
    end
end)

-- Theo dõi tiền
cash:GetPropertyChangedSignal('Value'):Connect(function()
    placeUnit()
    tryUpgradeUnit()
end)

-- Chạy lần đầu
placeUnit()
tryUpgradeUnit()

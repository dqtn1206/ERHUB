local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local VirtualInputManager = game:GetService('VirtualInputManager')

----------------------------------------------------------------
-- Chờ LocalPlayer và Character
----------------------------------------------------------------
local player = nil
while not player do
    player = Players.LocalPlayer
    task.wait()
end

if not player.Character or not player.Character.Parent then
    player.CharacterAdded:Wait()
end

-- Chờ leaderstats
local leaderstats = player:WaitForChild('leaderstats', 10)
if not leaderstats then
    warn('[AutoUnit] Không tìm thấy leaderstats trong 10 giây!')
    return
end

local cash = leaderstats:WaitForChild('Cash', 10)
if not cash then
    warn('[AutoUnit] Không tìm thấy Cash trong leaderstats!')
    return
end

-- Chờ RemoteFunctions
local RemoteFunctions = ReplicatedStorage:WaitForChild('RemoteFunctions', 10)
if not RemoteFunctions then
    warn(
        '[AutoUnit] Không tìm thấy RemoteFunctions trong ReplicatedStorage!'
    )
    return
end

local PlaceUnit = RemoteFunctions:WaitForChild('PlaceUnit', 10)
local UpgradeUnit = RemoteFunctions:WaitForChild('UpgradeUnit', 10)
if not PlaceUnit or not UpgradeUnit then
    warn(
        '[AutoUnit] Không tìm thấy PlaceUnit hoặc UpgradeUnit trong RemoteFunctions!'
    )
    return
end

-- Chờ Map và Entities
local map = workspace:WaitForChild('Map', 10)
if not map then
    warn('[AutoUnit] Không tìm thấy Map trong workspace!')
    return
end

local Entities = map:WaitForChild('Entities', 10)
if not Entities then
    warn('[AutoUnit] Không tìm thấy Entities trong Map!')
    return
end

----------------------------------------------------------------
-- Anti-AFK
----------------------------------------------------------------
task.spawn(function()
    while true do
        -- Mô phỏng nhấn phím Space để tránh AFK
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

----------------------------------------------------------------
-- Logic auto unit
----------------------------------------------------------------
-- 💰 Giá unit & upgrade
local unitPrices = { unit_pineapple = 400 }
local upgradePrices = { 250, 360 } -- 2 lần nâng cấp

-- ⚙️ Trạng thái
local placedUnitId = nil
local placed = false
local currentUpgrade = 1

-- Reset logic khi map mới
local function resetState()
    placedUnitId = nil
    placed = false
    currentUpgrade = 1
end

-- Theo dõi unit spawn để lấy ID
Entities.ChildAdded:Connect(function(child)
    if child.Name == 'unit_pineapple' and not placedUnitId then
        local idValue = child:GetAttribute('ID')
        if idValue then
            placedUnitId = idValue
        end
    end
end)

-- Hàm thử đặt unit
local function tryPlaceUnit()
    if placed then
        return
    end
    local cost = unitPrices.unit_pineapple
    local currentCash = tonumber(cash.Value) or 0

    if currentCash >= cost then
        -- Random nhẹ vị trí để tránh anti-cheat
        local baseX, baseY, baseZ = -848.284, 61.9303, -162.2305
        local offsetX = math.random(-1, 1)
        local offsetZ = math.random(-1, 1)
        local pos = Vector3.new(baseX + offsetX, baseY, baseZ + offsetZ)

        local args = {
            'unit_pineapple',
            {
                Valid = true,
                Rotation = 180,
                CF = CFrame.new(
                    pos.X,
                    pos.Y,
                    pos.Z,
                    -1,
                    0,
                    -8.742e-08,
                    0,
                    1,
                    0,
                    8.742e-08,
                    0,
                    -1
                ),
                Position = pos,
            },
        }

        local ok = pcall(function()
            return PlaceUnit:InvokeServer(unpack(args))
        end)

        if ok then
            placed = true
        end
    end
end

-- Hàm thử nâng cấp unit
local function tryUpgradeUnit()
    if not placedUnitId then
        return
    end
    if currentUpgrade > #upgradePrices then
        return
    end

    local cost = upgradePrices[currentUpgrade]
    local currentCash = tonumber(cash.Value) or 0

    if currentCash >= cost then
        local ok = pcall(function()
            return UpgradeUnit:InvokeServer(placedUnitId)
        end)

        if ok then
            currentUpgrade += 1
        end
    end
end

-- Theo dõi khi tiền thay đổi
cash:GetPropertyChangedSignal('Value'):Connect(function()
    tryPlaceUnit()
    tryUpgradeUnit()
end)

-- Theo dõi khi Entities trống -> reset map
Entities.ChildRemoved:Connect(function()
    task.delay(1, function()
        if #Entities:GetChildren() == 0 then
            resetState()
        end
    end)
end)

-- Kiểm tra ngay khi chạy
tryPlaceUnit()

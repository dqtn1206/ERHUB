--// ===== Auto Farmer 10 unit (place & upgrade 1->10) =====
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")

----------------------------------------------------------------
-- Wait for player / character / stats
----------------------------------------------------------------
local player
repeat player = Players.LocalPlayer; task.wait() until player

if not player.Character or not player.Character.Parent then
    player.CharacterAdded:Wait()
end

local character = player.Character
local humanoid = character:WaitForChild("Humanoid")
local backpack = player:WaitForChild("Backpack")
local leaderstats = player:WaitForChild("leaderstats", 10)
local cash = leaderstats:WaitForChild("Cash", 10)

----------------------------------------------------------------
-- Remotes / Map (chỉ chạy khi có Entities)
----------------------------------------------------------------
local RemoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions", 10)
local PlaceUnit      = RemoteFunctions:WaitForChild("PlaceUnit", 10)
local UpgradeUnit    = RemoteFunctions:WaitForChild("UpgradeUnit", 10)
local SellUnit       = RemoteFunctions:WaitForChild("SellUnit", 10) -- không dùng cũng không sao

local map = workspace:FindFirstChild("Map")
if not map or not map:FindFirstChild("Entities") then
    return
end
local Entities = map:WaitForChild("Entities", 10)

----------------------------------------------------------------
-- Config
----------------------------------------------------------------
local toolName = "Farmer"
local unitServerName = "unit_farmer_npc"

-- 10 Vị trí ĐẶT UNIT (cố định)
local positions = {
    Vector3.new(-330.31, 65.17, -132.49),
    Vector3.new(-324.81, 65.17, -132.29),
    Vector3.new(-316.68, 65.17, -132.55),
    Vector3.new(-308.55, 65.17, -132.55),
    Vector3.new(-310.49, 65.17, -142.65),
    Vector3.new(-310.50, 65.17, -150.78),
    Vector3.new(-310.64, 65.17, -158.57),
    Vector3.new(-310.57, 65.17, -165.91),
    Vector3.new(-310.30, 65.17, -170.03),
    Vector3.new(-315.32, 65.17, -169.91),
}

local MAX_UNITS = #positions

local placeCost   = 200
-- 4 lần nâng = max, theo thứ tự giá
local upgradeCost = {250, 350, 500, 850}  -- level 1,2,3,4
local MAX_LEVEL   = #upgradeCost          -- 4

local PLACEMENT_COOLDOWN = 1.0

-- Vị trí đứng (tùy, mình cho gần khu farm)
local STAND_POS       = Vector3.new(-320, 65.17, -150)
local STAND_JITTER    = 1.0
local APPROACH_RADIUS = 40
local RETURN_TO_STAND = true

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local nextIndex = 1            -- đơn vị tiếp theo cần đặt
local busy, standingHere = false, false
local lastPlaceTime = 0
local standSpot = STAND_POS

-- Lưu ID theo slot để upgrade
local unitIds = {}
local unitLevels = {}          -- số lần đã nâng của từng unit
for i = 1, MAX_UNITS do
    unitIds[i] = nil
    unitLevels[i] = 0
end

local awaitingPlaceIndex = nil
local currentUpgradeIndex = 1   -- đang upgrade unit thứ mấy (1 -> 10)

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function parseCash(v)
    if typeof(v) == "number" then return v end
    if typeof(v) == "string" then
        local s = v:gsub("[^%d%.-]", "")
        return tonumber(s) or 0
    end
    return 0
end
local function getCash()
    return parseCash(cash and cash.Value or 0)
end

local function getTool()
    return backpack:FindFirstChild(toolName) or character:FindFirstChild(toolName)
end

local function moveTo(pos)
    humanoid:MoveTo(pos)
    humanoid.MoveToFinished:Wait()
end

local function jitterAround(v, r)
    local ox = (math.random() - 0.5) * 2 * r
    local oz = (math.random() - 0.5) * 2 * r
    return Vector3.new(v.X + ox, v.Y, v.Z + oz)
end

local function goStandOnce()
    if standingHere then return end
    standSpot = jitterAround(STAND_POS, STAND_JITTER)
    moveTo(standSpot)
    standingHere = true
end

local function dist(a, b)
    return (a - b).Magnitude
end

local function resetState()
    nextIndex = 1
    busy, standingHere = false, false
    lastPlaceTime = 0
    for i = 1, MAX_UNITS do
        unitIds[i] = nil
        unitLevels[i] = 0
    end
    currentUpgradeIndex = 1
    task.defer(goStandOnce)
end

----------------------------------------------------------------
-- Bắt ID unit sau khi đặt
----------------------------------------------------------------
Entities.ChildAdded:Connect(function(child)
    if child.Name ~= unitServerName then return end
    if awaitingPlaceIndex and unitIds[awaitingPlaceIndex] == nil then
        local idValue = child:GetAttribute("ID")
        if idValue then
            unitIds[awaitingPlaceIndex] = idValue
        end
    end
end)

-- Reset khi map sạch Entities (tùy game, nếu không muốn auto reset thì bỏ block này)
Entities.ChildRemoved:Connect(function()
    task.delay(1, function()
        if #Entities:GetChildren() == 0 then
            resetState()
        end
    end)
end)

----------------------------------------------------------------
-- Đặt tuần tự 1 -> 10
----------------------------------------------------------------
local function placeNext()
    if nextIndex > MAX_UNITS then return end
    if (os.clock() - lastPlaceTime) < PLACEMENT_COOLDOWN then return end
    if busy then return end
    if getCash() < placeCost then return end

    goStandOnce()

    local tool = getTool()
    if not tool then return end

    busy = true
    local idx = nextIndex
    local targetPos = positions[idx]

    local here = character.PrimaryPart and character.PrimaryPart.Position or standSpot
    local needApproach = (dist(here, targetPos) > APPROACH_RADIUS)

    local cameCloser = false
    if needApproach then
        moveTo(jitterAround(targetPos, 1.0))
        cameCloser = true
    end

    humanoid:EquipTool(tool)
    task.wait(0.05)

    awaitingPlaceIndex = idx

    local args = {
        unitServerName,
        {
            Valid = true,
            Rotation = 180,
            Position = targetPos,
            CF = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z),
            -- Nếu server không cần PathIndex / Distance thì để như này
        }
    }

    local ok = pcall(function()
        return PlaceUnit:InvokeServer(unpack(args))
    end)

    pcall(function()
        humanoid:UnequipTools()
    end)

    if ok then
        nextIndex = idx + 1
        lastPlaceTime = os.clock()
        task.wait(PLACEMENT_COOLDOWN)
    end

    if cameCloser and RETURN_TO_STAND then
        moveTo(standSpot)
    end

    awaitingPlaceIndex = nil
    busy = false
end

----------------------------------------------------------------
-- Nâng cấp lần lượt unit 1 -> 10, mỗi unit nâng max 4 lần
----------------------------------------------------------------
local function upgradeUnitsSequential()
    -- chỉ bắt đầu nâng khi đã đặt xong hết 10 con
    if nextIndex <= MAX_UNITS then return end
    if busy then return end
    if currentUpgradeIndex > MAX_UNITS then return end -- đã nâng xong hết

    local slot = currentUpgradeIndex
    local unitId = unitIds[slot]
    if not unitId then
        -- chưa bắt được ID thì tạm bỏ qua
        return
    end

    local currentLevel = unitLevels[slot]
    if currentLevel >= MAX_LEVEL then
        -- con này đã max, chuyển sang con kế
        currentUpgradeIndex = currentUpgradeIndex + 1
        return
    end

    local cost = upgradeCost[currentLevel + 1] or 0
    if getCash() < cost then
        return
    end

    busy = true
    local ok = pcall(function()
        return UpgradeUnit:InvokeServer(unitId)
    end)
    if ok then
        unitLevels[slot] = currentLevel + 1
        if unitLevels[slot] >= MAX_LEVEL then
            currentUpgradeIndex = currentUpgradeIndex + 1
        end
    end
    busy = false
end

----------------------------------------------------------------
-- Anti-AFK
----------------------------------------------------------------
task.spawn(function()
    local VIM = game:GetService("VirtualInputManager")
    while true do
        pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.1)
            VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
        task.wait(0.5)
    end
end)

----------------------------------------------------------------
-- Driver
----------------------------------------------------------------
local function drive()
    placeNext()             -- đặt 1 -> 10
    upgradeUnitsSequential()-- nâng 1 max -> 2 max -> ... -> 10 max
end

goStandOnce()
task.spawn(function()
    while true do
        drive()
        task.wait(0.6)
    end
end)
cash:GetPropertyChangedSignal("Value"):Connect(drive)
drive()

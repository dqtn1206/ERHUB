--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorkspaceService = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

--// Player
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")
local backpack = player:WaitForChild("Backpack")
local leaderstats = player:WaitForChild("leaderstats")
local cash = leaderstats:WaitForChild("Cash")

--// Remotes & Map
local RemoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local PlaceUnit = RemoteFunctions:WaitForChild("PlaceUnit")
local UpgradeUnit = RemoteFunctions:WaitForChild("UpgradeUnit")
local map = WorkspaceService:WaitForChild("Map")
local Entities = map:WaitForChild("Entities")

--// Config
local toolName = "Farmer"
local UNIT_NAME = "unit_farmer_npc"

local spawnPositions = {
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

local unitPrice = 400
local upgradePrices = {250, 350, 500, 850}

--// Params
local UPGRADE_TIMEOUT = 15     -- nếu đợi quá 15s mà không nâng được -> bỏ qua
local MAX_ATTEMPTS = 5         -- mỗi lần upgrade thử tối đa 5 lần

local isRunning = false
local lastResetState = false

----------------------------------------------------------------
-- Helper
----------------------------------------------------------------
local function getTool()
    return backpack:FindFirstChild(toolName)
end

local function moveTo(pos)
    humanoid:MoveTo(pos)
    humanoid.MoveToFinished:Wait()
end

local function waitForCash(amount, timeout)
    local deadline = tick() + (timeout or 999)
    while (tonumber(cash.Value) or 0) < amount do
        if tick() > deadline then return false end
        task.wait(0.1)
    end
    return true
end

----------------------------------------------------------------
-- Đặt unit
----------------------------------------------------------------
local function placeUnitAt(pos)
    if not waitForCash(unitPrice, 60) then return nil end

    moveTo(pos)

    local tool = getTool()
    if not tool then return nil end
    humanoid:EquipTool(tool)
    task.wait(0.2)

    local idHolder
    local conn
    conn = Entities.ChildAdded:Connect(function(c)
        if c.Name == UNIT_NAME and c:GetAttribute("ID") then
            idHolder = c:GetAttribute("ID")
        end
    end)

    local ok = pcall(function()
        PlaceUnit:InvokeServer(
            UNIT_NAME,
            {Valid = true, Rotation = 180, CF = hrp.CFrame, Position = hrp.Position}
        )
    end)
    humanoid:UnequipTools()

    if conn then conn:Disconnect() end
    if not ok then return nil end

    local deadline = tick() + 5
    while not idHolder and tick() < deadline do task.wait(0.1) end
    return idHolder
end

----------------------------------------------------------------
-- Nâng unit 4 lần bằng đếm số lần upgrade thành công
----------------------------------------------------------------
local function upgradeUnitToMax(id)
    local done = 0
    for i, cost in ipairs(upgradePrices) do
        if not waitForCash(cost, UPGRADE_TIMEOUT) then
            warn("Timeout tiền cho upgrade #" .. i)
            return false
        end

        local attempts = 0
        local success = false
        while attempts < MAX_ATTEMPTS do
            attempts += 1
            local ok = pcall(function()
                UpgradeUnit:InvokeServer(id)
            end)
            if ok then
                print("[AutoUnit] Upgrade #" .. i .. " thành công cho ID=" .. id)
                success = true
                break
            end
            task.wait(0.2)
        end
        if not success then
            warn("Upgrade #" .. i .. " thất bại nhiều lần, bỏ unit.")
            return false
        end
        done += 1
    end
    return (done == #upgradePrices)
end

----------------------------------------------------------------
-- Reset vòng mới
----------------------------------------------------------------
local function isEntitiesResetIgnoringFarmers()
    local children = Entities:GetChildren()
    for _, c in ipairs(children) do
        if c.Name ~= UNIT_NAME then return false end
    end
    return true
end

----------------------------------------------------------------
-- Main loop
----------------------------------------------------------------
local function runPlacementPass()
    if isRunning then return end
    isRunning = true
    print("=== BẮT ĐẦU VÒNG MỚI ===")

    for idx, pos in ipairs(spawnPositions) do
        print(">>> Vị trí #" .. idx)
        local id = placeUnitAt(pos)
        if not id then
            warn("Không đặt được unit tại #" .. idx)
        else
            local ok = upgradeUnitToMax(id)
            if ok then
                print("Unit #" .. idx .. " nâng max thành công")
            else
                warn("Unit #" .. idx .. " chưa max, chuyển vị trí kế")
            end
        end
        task.wait(0.5)
    end

    print("=== HOÀN TẤT VÒNG HIỆN TẠI ===")
    isRunning = false
end

----------------------------------------------------------------
-- Watch reset
----------------------------------------------------------------
task.spawn(function()
    lastResetState = isEntitiesResetIgnoringFarmers()
    while true do
        local nowReset = isEntitiesResetIgnoringFarmers()
        if nowReset and not lastResetState and not isRunning then
            print(">>> Reset vòng, chạy lại")
            runPlacementPass()
        end
        lastResetState = nowReset
        task.wait(1)
    end
end)

----------------------------------------------------------------
-- Anti AFK
----------------------------------------------------------------
task.spawn(function()
    while true do
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        task.wait(60)
    end
end)

-- Chạy lần đầu
task.spawn(runPlacementPass)

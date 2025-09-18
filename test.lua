--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorkspaceService = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

--// Chờ LocalPlayer & các thành phần cần thiết
local player
repeat
    player = Players.LocalPlayer
    task.wait()
until player

if not player.Character or not player.Character.Parent then
    player.CharacterAdded:Wait()
end

local character = player.Character
local humanoid = character:WaitForChild("Humanoid")
local backpack = player:WaitForChild("Backpack")
local leaderstats = player:WaitForChild("leaderstats", 10)
local cash = leaderstats:WaitForChild("Cash", 10)

--// RemoteFunctions & Map
local RemoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions", 10)
local PlaceUnit = RemoteFunctions:WaitForChild("PlaceUnit", 10)
local UpgradeUnit = RemoteFunctions:WaitForChild("UpgradeUnit", 10)
local map = WorkspaceService:WaitForChild("Map", 10)
local Entities = map:WaitForChild("Entities", 10)

--// Cấu hình
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
local upgradePrices = {250, 350, 500, 850} -- 4 lần nâng = max cấp

--// Helper
local function getTool()
    return backpack:FindFirstChild(toolName)
end

local function moveTo(pos)
    -- đi kèm 1 chút ngẫu nhiên để tránh trùng exact point
    local offsetX = (math.random() - 0.5) * 2
    local offsetZ = (math.random() - 0.5) * 2
    local targetPos = Vector3.new(pos.X + offsetX, pos.Y, pos.Z + offsetZ)
    humanoid:MoveTo(targetPos)
    humanoid.MoveToFinished:Wait()
end

local function waitForCash(amount)
    while (tonumber(cash.Value) or 0) < amount do
        task.wait(0.1)
    end
end

-- Chờ unit mới xuất hiện trong Entities và lấy Attribute "ID"
local function waitForNewUnitId(timeout)
    local deadline = tick() + (timeout or 6)
    local newId = nil

    local connection
    connection = Entities.ChildAdded:Connect(function(child)
        if child.Name == UNIT_NAME then
            -- chờ attribute "ID" được set
            local subDeadline = tick() + 5
            while not child:GetAttribute("ID") and tick() < subDeadline do
                task.wait()
            end
            newId = child:GetAttribute("ID")
        end
    end)

    while not newId and tick() < deadline do
        task.wait(0.05)
    end

    if connection then
        connection:Disconnect()
    end
    return newId
end

-- Đặt unit tại 1 vị trí cụ thể, trả về placedUnitId (nếu thành công)
local function placeUnitAt(pos)
    local tool = getTool()
    if not tool then
        warn("[AutoUnit] Không tìm thấy Tool: " .. toolName)
        return nil
    end

    -- đủ tiền để đặt
    waitForCash(unitPrice)

    -- di chuyển tới điểm đặt
    moveTo(pos)

    -- Equip tool trước khi gọi PlaceUnit
    humanoid:EquipTool(tool)
    task.wait(0.1)

    -- Chuẩn bị đợi unit mới sinh ra để lấy ID
    local idPromiseStartedAt = tick()
    local idFromEvent = nil
    local connection
    connection = Entities.ChildAdded:Connect(function(child)
        if child.Name == UNIT_NAME then
            local subDeadline = tick() + 5
            while not child:GetAttribute("ID") and tick() < subDeadline do
                task.wait()
            end
            idFromEvent = child:GetAttribute("ID")
        end
    end)

    -- Gọi PlaceUnit ở đúng chỗ đang đứng (đã move tới pos)
    local placePos = character.PrimaryPart and character.PrimaryPart.Position or pos
    local args = {
        UNIT_NAME,
        {
            Valid = true,
            Rotation = 180,
            CF = CFrame.new(placePos.X, placePos.Y, placePos.Z),
            Position = placePos
        }
    }

    local ok = pcall(function()
        PlaceUnit:InvokeServer(unpack(args))
    end)

    -- Ngay sau khi đặt xong thì bỏ cầm tool
    humanoid:UnequipTools()

    if not ok then
        if connection then connection:Disconnect() end
        warn("[AutoUnit] PlaceUnit thất bại tại " .. tostring(placePos))
        return nil
    end

    -- Chờ ID xuất hiện từ sự kiện (tối đa 6s tính từ lúc bắt đầu nghe)
    local timeoutLeft = math.max(0, 6 - (tick() - idPromiseStartedAt))
    local deadline = tick() + timeoutLeft
    while not idFromEvent and tick() < deadline do
        task.wait(0.05)
    end
    if connection then connection:Disconnect() end

    if not idFromEvent then
        warn("[AutoUnit] Không bắt được ID unit vừa đặt!")
        return nil
    end

    print(("[AutoUnit] Đã đặt %s tại %s, ID=%s"):format(UNIT_NAME, tostring(placePos), tostring(idFromEvent)))
    return idFromEvent
end

-- Nâng cấp 4 lần theo upgradePrices
local function upgradeUnitToMax(unitId)
    for i = 1, #upgradePrices do
        local cost = upgradePrices[i]
        waitForCash(cost)

        local ok = pcall(function()
            UpgradeUnit:InvokeServer(unitId)
        end)

        if ok then
            print(("[AutoUnit] Nâng cấp %s -> Level %d (cost=%d)"):format(tostring(unitId), i, cost))
            task.wait(0.05)
        else
            warn("[AutoUnit] Nâng cấp thất bại cho ID " .. tostring(unitId) .. " ở lần " .. i)
            return false
        end
    end
    -- 4 lần xong coi như max cấp
    return true
end

-- Anti-AFK
task.spawn(function()
    while true do
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
        task.wait(60)
    end
end)

-- Quy trình chính: đi lần lượt qua toàn bộ spawnPositions
task.spawn(function()
    for idx, pos in ipairs(spawnPositions) do
        print(("[AutoUnit] >>> Bắt đầu vị trí #%d/%d"):format(idx, #spawnPositions))

        -- Đặt unit
        local unitId = placeUnitAt(pos)
        if not unitId then
            warn("[AutoUnit] Bỏ qua vị trí #" .. idx .. " vì không lấy được ID của unit vừa đặt.")
            continue
        end

        -- Nâng 4 lần (max)
        local ok = upgradeUnitToMax(unitId)
        if ok then
            print(("[AutoUnit] >>> Vị trí #%d hoàn tất (đã max cấp)."):format(idx))
        else
            warn("[AutoUnit] >>> Vị trí #" .. idx .. " chưa nâng max do lỗi.")
        end
        task.wait(0.25)
    end

    print("[AutoUnit] Hoàn thành tất cả vị trí trong spawnPositions.")
end)

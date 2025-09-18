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
local hrp = character:WaitForChild("HumanoidRootPart")
local backpack = player:WaitForChild("Backpack")
local leaderstats = player:WaitForChild("leaderstats", 10)
local cash = leaderstats:WaitForChild("Cash", 10)

--// RemoteFunctions & Map
local RemoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions", 10)
local PlaceUnit = RemoteFunctions:WaitForChild("PlaceUnit", 10)
local UpgradeUnit = RemoteFunctions:WaitForChild("UpgradeUnit", 10)
local map = WorkspaceService:WaitForChild("Map", 10)
local Entities = map:WaitForChild("Entities", 10)

--// Cấu hình unit/điểm đặt
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
local upgradePrices = {250, 350, 500, 850} -- 4 lần = max

--// Tham số chống kẹt/nâng
local CASH_WAIT_TIMEOUT_PER_LEVEL = 120   -- tối đa đợi tiền cho mỗi level (giây)
local STALL_TIMEOUT = 15                  -- không có tiến triển trong bao lâu thì coi là kẹt (giây)
local MAX_ATTEMPTS_PER_LEVEL = 5          -- số lần thử nâng tối đa cho mỗi level
local FIND_UNIT_TIMEOUT = 6               -- tối đa đợi unit instance sau khi đặt (giây)
local LOST_UNIT_GRACE = 3                 -- nếu unit biến mất, đợi thêm chút trước khi bỏ qua (giây)

--// Trạng thái vòng reset & chạy
local isRunning = false
local lastResetState = false

----------------------------------------------------------------
-- Helper cơ bản
----------------------------------------------------------------
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

local function now()
    return tick()
end

-- Đợi đủ tiền với timeout; trả về true nếu đạt, false nếu hết giờ
local function waitForCash(targetAmount, timeoutSeconds)
    local deadline = now() + (timeoutSeconds or 1e9)
    while (tonumber(cash.Value) or 0) < targetAmount do
        if now() >= deadline then
            return false
        end
        task.wait(0.1)
    end
    return true
end

-- Tìm instance unit theo ID trong Entities
local function findUnitInstanceById(id)
    local ok, children = pcall(function() return Entities:GetChildren() end)
    if not ok or not children then return nil end
    for _, child in ipairs(children) do
        -- Không ép buộc child.Name == UNIT_NAME để an toàn; nhưng ưu tiên đúng tên
        if child:GetAttribute("ID") == id then
            return child
        end
    end
    return nil
end

-- Chờ unit instance theo ID xuất hiện (sau khi đặt)
local function waitForUnitInstanceById(id, timeoutSec)
    local deadline = now() + (timeoutSec or FIND_UNIT_TIMEOUT)
    repeat
        local inst = findUnitInstanceById(id)
        if inst then return inst end
        task.wait(0.05)
    until now() >= deadline
    return nil
end

-- Cố đọc level/upgrade count từ attribute (nếu game có)
local function readServerUpgradeCount(unitInst)
    if not unitInst then return nil end
    local attrs
    pcall(function() attrs = unitInst:GetAttributes() end)
    if not attrs then return nil end

    -- Ưu tiên các key phổ biến: Level, Lvl, UpgradeLevel, UpgradeCount, Upgrades, Rank
    local candidates = {"Level", "Lvl", "UpgradeLevel", "UpgradeCount", "Upgrades", "Rank"}
    for _, key in ipairs(candidates) do
        local v = attrs[key]
        if typeof(v) == "number" then
            return v
        end
    end

    -- fallback: thử scan tất cả key có chữ "upgrade" hoặc "level"
    for k, v in pairs(attrs) do
        if typeof(v) == "number" then
            local lk = string.lower(k)
            if string.find(lk, "upgrade") or string.find(lk, "level") or lk == "lvl" then
                return v
            end
        end
    end
    return nil
end

----------------------------------------------------------------
-- Đặt unit tại 1 vị trí cụ thể, trả về placedUnitId (nếu thành công)
----------------------------------------------------------------
local function placeUnitAt(pos)
    local tool = getTool()
    if not tool then
        warn("[AutoUnit] Không tìm thấy Tool: " .. toolName)
        return nil
    end

    -- đủ tiền để đặt
    if not waitForCash(unitPrice, CASH_WAIT_TIMEOUT_PER_LEVEL) then
        warn("[AutoUnit] Hết thời gian chờ tiền để đặt unit.")
        return nil
    end

    -- di chuyển tới điểm đặt
    moveTo(pos)

    -- Equip tool trước khi gọi PlaceUnit
    humanoid:EquipTool(tool)
    task.wait(0.1)

    -- Chuẩn bị listener ChildAdded để lấy ID
    local newId = nil
    local addedConn
    addedConn = Entities.ChildAdded:Connect(function(child)
        if child.Name == UNIT_NAME then
            -- chờ Attribute ID
            local subDeadline = now() + 5
            while not child:GetAttribute("ID") and now() < subDeadline do
                task.wait()
            end
            if child:GetAttribute("ID") then
                newId = child:GetAttribute("ID")
            end
        end
    end)

    -- Gọi PlaceUnit
    local placePos = hrp.Position
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

    -- Bỏ cầm tool ngay sau khi đặt xong
    humanoid:UnequipTools()

    if addedConn then addedConn:Disconnect() end

    if not ok then
        warn("[AutoUnit] PlaceUnit thất bại tại " .. tostring(placePos))
        return nil
    end

    -- Nếu chưa có ID từ sự kiện, quét trực tiếp trong thời gian ngắn
    if not newId then
        local deadline = now() + FIND_UNIT_TIMEOUT
        while not newId and now() < deadline do
            local kids = Entities:GetChildren()
            for _, child in ipairs(kids) do
                if child.Name == UNIT_NAME then
                    local id = child:GetAttribute("ID")
                    if id then
                        newId = id
                        break
                    end
                end
            end
            task.wait(0.05)
        end
    end

    if not newId then
        warn("[AutoUnit] Không bắt được ID unit vừa đặt!")
        return nil
    end

    print(("[AutoUnit] Đã đặt %s tại %s, ID=%s"):format(UNIT_NAME, tostring(placePos), tostring(newId)))
    return newId
end

----------------------------------------------------------------
-- Nâng unit lên max (4 lần) với cơ chế chống kẹt
----------------------------------------------------------------
local function upgradeUnitToMaxRobust(unitId)
    if not unitId then return false end

    local successCount = 0                   -- số lần nâng thành công (client đếm)
    local lastProgress = now()
    local levelFromServer = nil              -- nếu đọc được attribute Level/UpgradeCount
    local lastServerLevel = nil

    for levelIndex = 1, #upgradePrices do
        local cost = upgradePrices[levelIndex]
        local attempts = 0
        local reachedThisLevel = false

        -- Chờ tiền đủ cho level này (có timeout)
        if not waitForCash(cost, CASH_WAIT_TIMEOUT_PER_LEVEL) then
            warn(("[AutoUnit] Đợi tiền cho level %d quá lâu, bỏ qua unit."):format(levelIndex))
            return false
        end

        -- Vòng thử nâng cho từng level
        while true do
            attempts += 1

            -- Kiểm tra unit vẫn còn tồn tại
            local inst = findUnitInstanceById(unitId)
            if not inst then
                warn("[AutoUnit] Unit biến mất trong lúc nâng. Chờ " .. LOST_UNIT_GRACE .. "s rồi bỏ qua.")
                task.wait(LOST_UNIT_GRACE)
                return false
            end

            -- Nếu đọc được level server, dùng nó để xác nhận tiến triển
            levelFromServer = readServerUpgradeCount(inst)

            -- Thử nâng
            local ok = pcall(function()
                UpgradeUnit:InvokeServer(unitId)
            end)

            if ok then
                successCount += 1
                lastProgress = now()
                print(("[AutoUnit] Nâng thành công lần %d (chi phí=%d) [ID=%s]"):format(successCount, cost, tostring(unitId)))

                -- Nếu server có level, cập nhật
                if levelFromServer ~= nil then
                    lastServerLevel = levelFromServer
                end

                reachedThisLevel = true
                break
            else
                warn(("[AutoUnit] Nâng thất bại (attempt=%d) cho ID=%s ở levelIndex=%d"):format(attempts, tostring(unitId), levelIndex))
            end

            -- Kiểm tra tiến triển dựa trên server-level (nếu đọc được)
            if levelFromServer ~= nil then
                if lastServerLevel == nil then lastServerLevel = levelFromServer end
                if levelFromServer > lastServerLevel then
                    -- Có vẻ server đã tăng level (dù lệnh trước fail do return), coi như đạt
                    lastServerLevel = levelFromServer
                    reachedThisLevel = true
                    print("[AutoUnit] Phát hiện level server tăng, coi như đã đạt level này.")
                    break
                end
            end

            -- Nếu quá nhiều lần thử trong khi có đủ tiền -> kẹt
            if attempts >= MAX_ATTEMPTS_PER_LEVEL and (tonumber(cash.Value) or 0) >= cost then
                warn("[AutoUnit] Vượt quá số lần thử nâng cho một level. Bỏ qua unit này.")
                return false
            end

            -- Nếu không có tiến triển quá lâu -> kẹt
            if (now() - lastProgress) > STALL_TIMEOUT and (tonumber(cash.Value) or 0) >= cost then
                warn("[AutoUnit] Không có tiến triển nâng cấp quá lâu, bỏ qua unit này.")
                return false
            end

            task.wait(0.2)
        end

        if not reachedThisLevel then
            -- Không đạt level hiện tại, bỏ qua unit này
            return false
        end

        -- chuyển sang level tiếp theo (nếu còn)
        task.wait(0.05)
    end

    -- 4 lần xong = max
    return true
end

----------------------------------------------------------------
-- Reset vòng mới: kiểm tra Entities rỗng trừ UNIT_NAME
----------------------------------------------------------------
local function isEntitiesResetIgnoringFarmers()
    local ok, children = pcall(function() return Entities:GetChildren() end)
    if not ok or not children then return false end
    for _, child in ipairs(children) do
        if child.Name ~= UNIT_NAME then
            return false
        end
    end
    return true
end

----------------------------------------------------------------
-- Gói quy trình đặt → nâng 4 lần cho toàn bộ spawnPositions
----------------------------------------------------------------
local function runPlacementPass()
    if isRunning then return end
    isRunning = true
    print("[AutoUnit] === BẮT ĐẦU VÒNG MỚI ===")

    for idx = 1, #spawnPositions do
        local pos = spawnPositions[idx]
        print(("[AutoUnit] >>> Vị trí #%d/%d"):format(idx, #spawnPositions))

        -- Đặt unit
        local unitId = placeUnitAt(pos)
        if not unitId then
            warn("[AutoUnit] Bỏ qua vị trí #" .. idx .. " (không lấy được ID).")
        else
            -- Nâng 4 lần (max) với chống kẹt
            local ok = upgradeUnitToMaxRobust(unitId)
            if ok then
                print(("[AutoUnit] >>> Vị trí #%d hoàn tất (đã max)."):format(idx))
            else
                warn("[AutoUnit] >>> Vị trí #" .. idx .. " bị kẹt/chưa max, chuyển vị trí kế.")
            end
        end

        task.wait(0.25)
    end

    print("[AutoUnit] === HOÀN TẤT VÒNG HIỆN TẠI ===")
    isRunning = false
end

----------------------------------------------------------------
-- Vòng giám sát reset: phát hiện Entities rỗng (trừ UNIT_NAME) -> chạy pass mới
----------------------------------------------------------------
local function watchResetLoop()
    lastResetState = isEntitiesResetIgnoringFarmers()
    while true do
        local nowReset = isEntitiesResetIgnoringFarmers()
        if nowReset and not lastResetState and not isRunning then
            print("[AutoUnit] Phát hiện Map reset: Entities rỗng (trừ " .. UNIT_NAME .. "). Bắt đầu vòng mới.")
            runPlacementPass()
        end
        lastResetState = nowReset
        task.wait(1)
    end
end

----------------------------------------------------------------
-- Anti-AFK
----------------------------------------------------------------
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

-- Chạy lần đầu rồi bật giám sát reset
task.spawn(runPlacementPass)
task.spawn(watchResetLoop)

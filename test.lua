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

-- Giá có thể điều chỉnh theo game của bạn:
local unitPrice = 200
local upgradePrices = {250, 350, 500, 850} -- 4 lần = max

-- Retry / an toàn mạng
local MAX_ATTEMPTS_PER_CALL = 6
local FIND_UNIT_TIMEOUT = 8   -- đợi model & ID xuất hiện sau PlaceUnit (giây)

-- Trạng thái
local isRunning = false
local lastResetState = false

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function getTool()
    return backpack:FindFirstChild(toolName)
end

local function moveTo(pos)
    -- thêm chút jitter để tránh va chạm
    local ox, oz = (math.random()-0.5)*2, (math.random()-0.5)*2
    local target = Vector3.new(pos.X+ox, pos.Y, pos.Z+oz)
    humanoid:MoveTo(target)
    humanoid.MoveToFinished:Wait()
end

-- Chờ đủ tiền (KHÔNG timeout) -> đảm bảo nâng tuần tự theo yêu cầu
local function waitUntilCash(amount)
    while (tonumber(cash.Value) or 0) < amount do
        task.wait(0.1)
    end
end

-- Lấy danh sách ID hiện có để tránh bắt nhầm unit cũ
local function currentKnownIdsSet()
    local set = {}
    for _, child in ipairs(Entities:GetChildren()) do
        local id = child:GetAttribute("ID")
        if id then set[id] = true end
    end
    return set
end

----------------------------------------------------------------
-- Đặt unit tại vị trí, trả về ID (bắt ID chắc chắn)
----------------------------------------------------------------
local function placeUnitAt(pos)
    -- chờ đủ tiền để đặt
    waitUntilCash(unitPrice)

    moveTo(pos)

    local tool = getTool()
    if not tool then
        warn("[AutoUnit] Không có tool: " .. toolName)
        return nil
    end

    -- snapshot các ID đã có trước khi đặt
    local beforeSet = currentKnownIdsSet()

    -- cầm tool
    humanoid:EquipTool(tool)
    task.wait(0.15)

    -- gọi PlaceUnit (có retry)
    local ok = false
    for attempt = 1, MAX_ATTEMPTS_PER_CALL do
        ok = pcall(function()
            PlaceUnit:InvokeServer(
                UNIT_NAME,
                { Valid = true, Rotation = 180, CF = hrp.CFrame, Position = hrp.Position }
            )
        end)
        if ok then break end
        task.wait(0.2)
    end

    -- bỏ cầm tool ngay
    humanoid:UnequipTools()

    if not ok then
        warn("[AutoUnit] PlaceUnit thất bại tại " .. tostring(pos))
        return nil
    end

    -- đợi model mới + ID mới xuất hiện (không nằm trong beforeSet)
    local deadline = tick() + FIND_UNIT_TIMEOUT
    local newId = nil

    -- ưu tiên nghe ChildAdded rồi chờ ID
    local conn
    conn = Entities.ChildAdded:Connect(function(child)
        if child.Name == UNIT_NAME then
            -- chờ attribute ID được set
            local subDeadline = tick() + 5
            repeat
                local id = child:GetAttribute("ID")
                if id and not beforeSet[id] then
                    newId = id
                    break
                end
                task.wait(0.05)
            until tick() >= subDeadline
        end
    end)

    while not newId and tick() < deadline do
        -- fallback quét toàn bộ (nếu missed sự kiện)
        for _, child in ipairs(Entities:GetChildren()) do
            if child.Name == UNIT_NAME then
                local id = child:GetAttribute("ID")
                if id and not beforeSet[id] then
                    newId = id
                    break
                end
            end
        end
        task.wait(0.05)
    end
    if conn then conn:Disconnect() end

    if not newId then
        warn("[AutoUnit] Không tìm thấy ID unit vừa đặt (có thể bị chặn/giới hạn).")
        return nil
    end

    print(("[AutoUnit] Đặt xong ID=%s tại %s"):format(tostring(newId), tostring(pos)))
    return newId
end

----------------------------------------------------------------
-- Nâng 1 unit lên max, CHỜ TIỀN TỚI KHI ĐỦ (tuần tự tuyệt đối)
----------------------------------------------------------------
local function upgradeUnitToMax_sequential(id)
    if not id then return false end
    for i, cost in ipairs(upgradePrices) do
        -- CHỜ cho đủ tiền (không timeout) để đảm bảo tuần tự 1→2→… đúng ý bạn
        print(("[AutoUnit] Chờ tiền để nâng #%d cho ID=%s (cần %d, hiện có %d)")
            :format(i, tostring(id), cost, tonumber(cash.Value) or 0))
        waitUntilCash(cost)

        -- gọi Upgrade (retry nếu lỗi mạng)
        local success = false
        for attempt = 1, MAX_ATTEMPTS_PER_CALL do
            local ok = pcall(function()
                UpgradeUnit:InvokeServer(id)
            end)
            if ok then
                success = true
                print(("[AutoUnit] ✔ Nâng #%d thành công cho ID=%s (tiền còn %d)")
                    :format(i, tostring(id), tonumber(cash.Value) or 0))
                break
            end
            task.wait(0.2)
        end

        if not success then
            warn(("[AutoUnit] ✖ Nâng #%d thất bại nhiều lần cho ID=%s -> bỏ unit này.")
                :format(i, tostring(id)))
            return false
        end

        task.wait(0.05)
    end
    return true
end

----------------------------------------------------------------
-- Reset vòng mới: Entities rỗng (trừ UNIT_NAME)
----------------------------------------------------------------
local function isEntitiesResetIgnoringFarmers()
    for _, c in ipairs(Entities:GetChildren()) do
        if c.Name ~= UNIT_NAME then
            return false
        end
    end
    return true
end

----------------------------------------------------------------
-- Main: ĐẶT TẤT CẢ → NÂNG TUẦN TỰ TỪ #1 → #N (mỗi unit max rồi mới sang unit kế)
----------------------------------------------------------------
local function runPlacementPass()
    if isRunning then return end
    isRunning = true
    print("=== BẮT ĐẦU VÒNG MỚI ===")

    -- Vòng 1: Đặt tất cả
    local ids = {}
    for idx, pos in ipairs(spawnPositions) do
        print((">>> Đặt unit tại vị trí #%d"):format(idx))
        local id = placeUnitAt(pos)
        if id then
            table.insert(ids, id)
        else
            warn(("Không đặt được unit tại #%d"):format(idx))
        end
        task.wait(0.25)
    end

    -- Vòng 2: Nâng TUẦN TỰ từ unit đầu tiên tới cuối cùng
    for idx, id in ipairs(ids) do
        print((">>> NÂNG unit #%d (ID=%s) lên MAX"):format(idx, tostring(id)))
        local ok = upgradeUnitToMax_sequential(id)
        if ok then
            print(("Unit #%d (ID=%s) đã MAX"):format(idx, tostring(id)))
        else
            warn(("Unit #%d (ID=%s) lỗi nâng, bỏ qua."):format(idx, tostring(id)))
        end
        task.wait(0.2)
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
            print(">>> Phát hiện reset map -> chạy lại")
            runPlacementPass()
        end
        lastResetState = nowReset
        task.wait(5)
    end
end)

----------------------------------------------------------------
-- Anti AFK
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

-- Chạy lần đầu
task.spawn(runPlacementPass)

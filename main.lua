-- 🔁 Auto Raid Runner (scan tất cả RaidPos, chạy bộ bám mục tiêu, chuyển khi chết)
-- Yêu cầu: nhân vật có Humanoid; boss dùng Humanoid hoặc có NumberValue "Health/MaxHealth"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
-- ⚡ Auto Attack + Skill 3 spam liên tục
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local LP = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local Humanoid = Char:WaitForChild("Humanoid")
local HRP = Char:WaitForChild("HumanoidRootPart")

local RaidPos = workspace:WaitForChild("RaidPos")

-- === Utils ===
local function getPrimaryPart(model)
    if model:IsA("Model") then
        if model.PrimaryPart then return model.PrimaryPart end
        local part = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
        if part then
            pcall(function() model.PrimaryPart = part end)
            return part
        end
    elseif model:IsA("BasePart") then
        return model
    end
end

local function numberValue(obj, name)
    local v = obj and obj:FindFirstChild(name)
    if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then
        return v.Value
    end
end

local function isAlive(model)
    if not (model and model:IsDescendantOf(workspace)) then return false end
    local hum = model:FindFirstChildWhichIsA("Humanoid")
    if hum then
        return hum.Health > 0
    else
        local hp = numberValue(model, "Health")
        local mhp = numberValue(model, "MaxHealth")
        if hp and mhp then
            return hp > 0
        end
    end
    -- nếu không có thông tin máu, coi như còn tồn tại là "sống"
    return getPrimaryPart(model) ~= nil
end

local function distance(a, b)
    return (a - b).Magnitude
end

-- Tìm boss còn sống trong 1 node (ưu tiên "Douma", nếu không thì bất kỳ Model có Humanoid)
local function findAliveBossInNode(node)
    if not (node and node:IsDescendantOf(workspace)) then return nil end
    local cand = node:FindFirstChild("Douma")
    if cand and isAlive(cand) then return cand end
    -- fallback: tìm model có humanoid
    for _, d in ipairs(node:GetDescendants()) do
        if d:IsA("Model") then
            local hum = d:FindFirstChildWhichIsA("Humanoid")
            if hum and hum.Health > 0 then
                return d
            end
        end
    end
    return nil
end

-- Lấy danh sách boss còn sống trong toàn bộ RaidPos
local function getAliveBosses()
    local alive = {}
    for _, node in ipairs(RaidPos:GetChildren()) do
        local boss = findAliveBossInNode(node)
        if boss then
            table.insert(alive, {node = node, boss = boss})
        end
    end
    return alive
end

-- Chọn boss gần nhất hiện tại
local function pickNearest(aliveList)
    local best, bestDist
    for _, item in ipairs(aliveList) do
        local part = getPrimaryPart(item.boss)
        if part then
            local d = distance(HRP.Position, part.Position)
            if not bestDist or d < bestDist then
                best = item
                bestDist = d
            end
        end
    end
    return best
end

-- Di chuyển “chạy bộ” bám mục tiêu liên tục (không teleport)
local function chaseTarget(boss, stopDist)
    stopDist = stopDist or 8  -- khoảng cách dừng (đứng sát để đánh)
    local lastPos = HRP.Position
    local lastCheck = time()

    while isAlive(boss) do
        local part = getPrimaryPart(boss)
        if not part then break end

        local targetPos = part.Position
        local d = distance(HRP.Position, targetPos)

        -- đến đủ gần thì dừng “chase” (để bạn đánh)
        if d <= stopDist then
            -- vẫn giữ loop để theo dõi khi boss di chuyển/respawn
            task.wait(0.2)
        else
            -- ra lệnh chạy đến vị trí hiện tại của boss (update liên tục mỗi 0.2s)
            Humanoid:MoveTo(targetPos)
            -- chờ ngắn để không bị “đứng chỗ”
            Humanoid.MoveToFinished:Wait(0.4)
        end

        -- chống kẹt: nếu sau 2s mà không tiến gần hơn → đẩy 1 bước nhỏ lệch hướng
        if time() - lastCheck >= 2 then
            local newD = distance(HRP.Position, targetPos)
            if newD >= d - 1 then  -- gần như không cải thiện
                local offset = (HRP.CFrame.LookVector * 4) + Vector3.new(0, 0, 0)
                Humanoid:MoveTo(HRP.Position + offset)
                Humanoid.MoveToFinished:Wait(0.2)
            end
            lastCheck = time()
        end
    end
end

print("✅ Auto Raid Runner đang chạy...")
-- Vòng chính: luôn quét toàn bộ RaidPos, chọn 1 con còn sống, bám cho tới khi chết, rồi chuyển
task.spawn(function()
    while task.wait(0.3) do
        -- nếu nhân vật respawn
        if not (LP.Character and LP.Character:FindFirstChild("Humanoid") and LP.Character:FindFirstChild("HumanoidRootPart")) then
            Char = LP.Character or LP.CharacterAdded:Wait()
            Humanoid = Char:WaitForChild("Humanoid")
            HRP = Char:WaitForChild("HumanoidRootPart")
        end

        local alive = getAliveBosses()
        if #alive == 0 then
            -- không có mục tiêu → đợi rồi quét lại
            task.wait(0.5)
        else
            local target = pickNearest(alive)
            if target and isAlive(target.boss) then
                print("🎯 Bám mục tiêu:", target.node.Name, target.boss.Name)
                chaseTarget(target.boss, 8)
                print("✅ Xong mục tiêu:", target.node.Name, "→ chuyển mục tiêu kế tiếp")
            end
        end
    end
end)

-- Auto Skill 3
task.spawn(function()
    while true do
        local args = {3}
        RemoteEvents:WaitForChild("SkillAttack"):FireServer(unpack(args))
        task.wait() -- spam nhanh nhất (0s delay, chỉ yield 1 frame)
    end
end)

-- Auto Đánh Thường
task.spawn(function()
    while true do
        local args = {2}
        RemoteEvents:WaitForChild("GeneralAttack"):FireServer(unpack(args))
        task.wait() -- spam nhanh nhất
    end
end)



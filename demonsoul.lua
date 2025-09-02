-- ⚡ Demon Soul Hub với Rayfield UI
-- ✅ Auto Raid (chạy bộ bám boss)
-- ✅ Auto Attack thường
-- ✅ Auto Skill 3 spam
-- ✅ Auto Speed (85 khi bật, 16 khi tắt)
-- ✅ Anti AFK (ngầm, không vào menu)

-- // Load Rayfield UI
local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)
if not success then
    warn("❌ Failed to load UI: ", Rayfield)
    return
end


-- // Key System
local Window = Rayfield:CreateWindow({
    Name = "🔥 ER HUB | Demon Soul",
    LoadingTitle = "ER HUB | Demon Soul",
    LoadingSubtitle = "by Nguyên",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = nil,
        FileName = "DemonSoulHub"
    },
    KeySystem = true,
    KeySettings = {
        Title = "Key | Demon Soul",
        Subtitle = "Key System",
        FileName = "demonhub_key",
        SaveKey = false,
        GrabKeyFromSite = false,
        Key = {"nguyen"}
    }
})

-- // Tab chính
local MainTab = Window:CreateTab("⚔️ Main", nil)
local RaidSection = MainTab:CreateSection("Raid Farm")
local CombatSection = MainTab:CreateSection("Combat")
local MoveSection = MainTab:CreateSection("Movement")
local TeleportSection = MainTab:CreateSection("Teleport")
local MiscSection = MainTab:CreateSection("Misc")

-- // Anti AFK ngầm
task.spawn(function()
    local vu = game:GetService("VirtualUser")
    game:GetService("Players").LocalPlayer.Idled:Connect(function()
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end)
end)

-- ========== SCRIPT CHÍNH ==========
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local Humanoid = Char:WaitForChild("Humanoid")
local HRP = Char:WaitForChild("HumanoidRootPart")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local RaidPos = workspace:WaitForChild("RaidPos")

-- Utils
local function getPrimaryPart(model)
    if model:IsA("Model") then
        return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
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
    if hum then return hum.Health > 0 end
    local hp = numberValue(model, "Health")
    return hp and hp > 0
end

local function findAliveBossInNode(node)
    if not (node and node:IsDescendantOf(workspace)) then return nil end
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

local function chaseTarget(boss, stopDist)
    stopDist = stopDist or 8
    while isAlive(boss) do
        local part = getPrimaryPart(boss)
        if not part then break end
        local d = (HRP.Position - part.Position).Magnitude
        if d <= stopDist then
            task.wait(0.2)
        else
            Humanoid:MoveTo(part.Position)
            Humanoid.MoveToFinished:Wait(0.4)
        end
    end
end

-- ========== TOGGLES ==========
-- Auto Raid
MainTab:CreateToggle({
    Name = "Auto Raid Farm",
    CurrentValue = false,
    Callback = function(v)
        if v then
            task.spawn(function()
                while v do
                    local alive = getAliveBosses()
                    if #alive > 0 then
                        local target = alive[1]
                        if target and isAlive(target.boss) then
                            chaseTarget(target.boss, 8)
                        end
                    else
                        task.wait(0.5)
                    end
                    task.wait(0.3)
                end
            end)
        end
    end
})

-- Auto Attack
MainTab:CreateToggle({
    Name = "Auto Attack",
    CurrentValue = false,
    Callback = function(v)
        if v then
            task.spawn(function()
                while v do
                    RemoteEvents.GeneralAttack:FireServer(2)
                    task.wait()
                end
            end)
        end
    end
})

-- Auto Skill 3
MainTab:CreateToggle({
    Name = "Auto Skill 3",
    CurrentValue = false,
    Callback = function(v)
        if v then
            task.spawn(function()
                while v do
                    RemoteEvents.SkillAttack:FireServer(3)
                    task.wait()
                end
            end)
        end
    end
})

-- Auto Speed (85 khi bật, 16 khi tắt)
MainTab:CreateToggle({
    Name = "Auto Speed (85)",
    CurrentValue = false,
    Callback = function(v)
        local humanoid = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = v and 85 or 16
        end
    end
})

-- ========== Teleport (mẫu) ==========
TeleportSection:CreateButton({Name = "Teleport A", Callback = function() print("TP A") end})
TeleportSection:CreateButton({Name = "Teleport B", Callback = function() print("TP B") end})
TeleportSection:CreateButton({Name = "Teleport C", Callback = function() print("TP C") end})

-- ========== Misc (mẫu) ==========
MiscSection:CreateButton({Name = "Misc A", Callback = function() print("Misc A") end})
MiscSection:CreateButton({Name = "Misc B", Callback = function() print("Misc B") end})
MiscSection:CreateButton({Name = "Misc C", Callback = function() print("Misc C") end})

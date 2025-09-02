-- ⚡ Demon Soul Hub với Rayfield UI
-- ✅ Auto Raid (chạy bộ bám boss)
-- ✅ Auto Attack thường
-- ✅ Auto Skill 3 spam
-- ✅ Auto Speed 85 (bật/tắt cố định)
-- ✅ Anti AFK (ngầm, không vào menu)
-- ✅ Teleport + Misc có tab riêng

-- // Load Rayfield UI
local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)
if not success then
    warn("❌ Failed to load UI: ", Rayfield)
    return
end
print("✅ Rayfield UI loaded")

-- // Key System
local Window = Rayfield:CreateWindow({
    Name = "🔥 ER HUB | Demon Soul",
    LoadingTitle = "ER HUB | Demon Soul",
    LoadingSubtitle = "by Nguyên",
    KeySystem = true,
    KeySettings = {
        Title = "Key | Demon Soul",
        Subtitle = "Key System",
        Note = "⚠️ DISCORD:/n liên hệ để mua key → dqtn392 ⚠️",
        FileName = "demonhub_key",
        SaveKey = false,
        GrabKeyFromSite = false,
        Key = {"nguyen"}
    }
})

-- // Tab Main
local MainTab = Window:CreateTab("⚔️ Main", nil)
local MainSection = MainTab:CreateSection("Main Features")

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

-- ========== TOGGLE ==========
local AutoRaid = false
local AutoAttack = false
local AutoSkill3 = false
local AutoSpeed = false

-- Auto Raid
MainTab:CreateToggle({
    Name = "Auto Raid Farm",
    CurrentValue = false,
    Flag = "AutoRaid",
    Callback = function(v)
        AutoRaid = v
        if v then
            task.spawn(function()
                while AutoRaid do
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

-- Auto Attack thường
MainTab:CreateToggle({
    Name = "Auto Attack",
    CurrentValue = false,
    Flag = "AutoAttack",
    Callback = function(v)
        AutoAttack = v
        if v then
            task.spawn(function()
                while AutoAttack do
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
    Flag = "AutoSkill3",
    Callback = function(v)
        AutoSkill3 = v
        if v then
            task.spawn(function()
                while AutoSkill3 do
                    RemoteEvents.SkillAttack:FireServer(3)
                    task.wait()
                end
            end)
        end
    end
})

-- Auto Speed (bật tắt cố định 85)
MainTab:CreateToggle({
    Name = "Auto Speed 85",
    CurrentValue = false,
    Flag = "AutoSpeed",
    Callback = function(v)
        AutoSpeed = v
        if v then
            task.spawn(function()
                while AutoSpeed do
                    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum.WalkSpeed = 85 end
                    task.wait(0.2)
                end
            end)
        end
    end
})

-- // Tab Teleport
local TeleportTab = Window:CreateTab("🗺️ Teleport", nil)
local TeleportSection = TeleportTab:CreateSection("Teleport Locations")
TeleportTab:CreateButton({Name = "Teleport A", Callback = function() print("Teleport A clicked") end})
TeleportTab:CreateButton({Name = "Teleport B", Callback = function() print("Teleport B clicked") end})
TeleportTab:CreateButton({Name = "Teleport C", Callback = function() print("Teleport C clicked") end})

-- // Tab Misc
local MiscTab = Window:CreateTab("⚙️ Misc", nil)
local MiscSection = MiscTab:CreateSection("Misc Functions")
MiscTab:CreateButton({Name = "Misc A", Callback = function() print("Misc A clicked") end})
MiscTab:CreateButton({Name = "Misc B", Callback = function() print("Misc B clicked") end})
MiscTab:CreateButton({Name = "Misc C", Callback = function() print("Misc C clicked") end})

-- ⚡ Demon Soul Hub với Rayfield UI
-- ✅ Auto Raid (chạy bộ bám boss)
-- ✅ Auto Attack thường
-- ✅ Auto Skill 3 spam
-- ✅ WalkSpeed chỉnh bằng slider (giữ liên tục)
-- ✅ Anti AFK (ngầm, không vào menu)

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
        Note = "DISCORD:\n👉 DM me for key: dqtn392 👈"
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

local function findAliveBoss

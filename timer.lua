-- === Time-based placer — dùng đúng timer path bạn đã xác nhận ===

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== 1) TIMER LABEL (đường dẫn bạn xác nhận) =====
local TimerLabel = playerGui
    :WaitForChild("TopbarStandard")
    :WaitForChild("Holders")
    :WaitForChild("Right")
    :WaitForChild("Widget")
    :WaitForChild("IconButton")
    :WaitForChild("Menu")
    :WaitForChild("IconSpot")
    :WaitForChild("Contents")
    :WaitForChild("IconLabelContainer")
    :WaitForChild("IconLabel")

-- ===== 2) CONFIG =====
local TARGET_SECONDS = 10            -- mốc đặt
local COUNT_MODE = "auto"            -- "auto" | "up" | "down"
local LOG_INTERVAL = 0.5

-- ===== 3) ARGS MỚI (PathIndex=3, vị trí mới) =====
local UNIT_NAME   = "unit_log_roller"
local PATH_INDEX  = 3
local POS         = Vector3.new(-857.3809814453125, 62.18030548095703, -130.04051208496094)
local DIST_ALONG  = 227.5109100341797
local ROT         = 180
local CF          = CFrame.new(-857.3809814453125, 62.18030548095703, -130.04051208496094, 1, 0, 0, 0, 1, 0, 0, 0, 1)

-- ===== 4) Utils: tách & parse thời gian =====
local function extractTimeText(s)
    if typeof(s) ~= "string" then return nil end
    local last
    for h,m,ss in s:gmatch("(%d+):(%d+):(%d+)") do last = string.format("%s:%s:%s", h,m,ss) end
    if last then return last end
    for m,ss in s:gmatch("(%d+):(%d%d)") do last = string.format("%s:%s", m,ss) end
    if last then return last end
    last = s:match("(%d+)")
    return last
end

local function toSeconds(t)
    if not t then return nil end
    local h,m,s = t:match("^(%d+):(%d+):(%d+)$")
    if h then return tonumber(h)*3600 + tonumber(m)*60 + tonumber(s) end
    local mm,ss = t:match("^(%d+):(%d+)$")
    if mm then return tonumber(mm)*60 + tonumber(ss) end
    return tonumber(t)
end

local function readTimer()
    local raw = TimerLabel.Text
    local tt  = extractTimeText(raw)
    local sec = toSeconds(tt)
    return raw, sec
end

-- ===== 5) Đặt unit một lần =====
local PlaceUnit = ReplicatedStorage:WaitForChild("RemoteFunctions"):WaitForChild("PlaceUnit")
local placed = false

local function placeOnce()
    if placed then return end
    placed = true
    local args = {
        UNIT_NAME,
        {
            Valid = true,
            PathIndex = PATH_INDEX,
            Position = POS,
            DistanceAlongPath = DIST_ALONG,
            Rotation = ROT,
            CF = CF
        }
    }
    local ok, err = pcall(function()
        PlaceUnit:InvokeServer(table.unpack(args))
    end)
    if ok then
        warn(("[TimePlacer] >>> ĐÃ ĐẶT %s tại mốc %ds (PathIndex=%d)"):format(UNIT_NAME, TARGET_SECONDS, PATH_INDEX))
    else
        warn("[TimePlacer] LỖI đặt unit:", err)
    end
end

-- ===== 6) Log thời gian hiện tại + kích hoạt khi đạt mốc =====
local lastSecs, mode
warn("[TimePlacer] Theo dõi timer tại:", TimerLabel:GetFullName())

task.spawn(function()
    while not placed do
        local raw, sec = readTimer()
        print(("[Timer] raw='%s'  ->  %s s"):format(tostring(raw), tostring(sec)))
        task.wait(LOG_INTERVAL)
    end
end)

TimerLabel:GetPropertyChangedSignal("Text"):Connect(function()
    local raw, sec = readTimer()
    if not sec then return end

    if COUNT_MODE == "auto" and lastSecs and not mode then
        if sec > lastSecs then mode = "up" elseif sec < lastSecs then mode = "down" end
        if mode then print("[TimePlacer] Mode:", mode) end
    elseif COUNT_MODE ~= "auto" then
        mode = COUNT_MODE
    end

    if not placed and mode then
        if (mode == "up" and sec >= TARGET_SECONDS) or (mode == "down" and sec <= TARGET_SECONDS) then
            print(("[TimePlacer] Điều kiện đạt (sec=%d, mode=%s) -> đặt unit"):format(sec, mode))
            placeOnce()
        end
    end

    lastSecs = sec
end)

do
    local _, s0 = readTimer()
    lastSecs = s0
end

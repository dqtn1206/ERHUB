-- [TimePlacer] Bắt IconLabel timer + in thời gian hiện tại + đặt unit lúc 10s

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- 1) THAM SỐ
----------------------------------------------------------------
local TARGET_SECONDS = 10                 -- mốc cần đặt
local COUNT_MODE = "auto"                 -- "auto" | "up" | "down" (mặc định tự phát hiện)

-- Unit & args bạn đưa:
local UNIT_NAME = "unit_log_roller"
local POS = Vector3.new(-305.38128662109375, 61.93030548095703, -163.8728485107422)
local CF  = CFrame.new(-305.38128662109375, 61.93030548095703, -163.8728485107422, -1, 0, -0, -0, 1, -0, -0, 0, -1)
local PATH_INDEX = 1
local DIST_ALONG = 100.32081599071108
local ROT = 180

----------------------------------------------------------------
-- 2) LẤY ĐÚNG ICONLABEL (đường dẫn bạn đã tìm)
----------------------------------------------------------------
local function getTimerLabel()
    local ok, label = pcall(function()
        return playerGui
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
    end)
    if ok and label then return label end
    return nil
end

local TimerLabel = getTimerLabel()
if not TimerLabel then
    warn("[TimePlacer] Không tìm thấy IconLabel timer. Kiểm tra lại path trong getTimerLabel().")
    return
end

----------------------------------------------------------------
-- 3) PARSE TIME
----------------------------------------------------------------
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

local function parseToSeconds(t)
    if not t then return nil end
    local h,m,s = t:match("^(%d+):(%d+):(%d+)$")
    if h then return tonumber(h)*3600 + tonumber(m)*60 + tonumber(s) end
    local mm,ss = t:match("^(%d+):(%d+)$")
    if mm then return tonumber(mm)*60 + tonumber(ss) end
    return tonumber(t)
end

----------------------------------------------------------------
-- 4) ĐỌC TIMER + LOG LIÊN TỤC
----------------------------------------------------------------
local lastSecs, mode
local function readTimer()
    local raw = TimerLabel.Text
    local tText = extractTimeText(raw)
    local secs = parseToSeconds(tText)
    return raw, secs
end

-- log đều để bạn thấy “thời gian hiện tại”
task.spawn(function()
    while true do
        local raw, secs = readTimer()
        print(("[Timer] raw='%s'  ->  %s giây  (mode=%s)")
            :format(tostring(raw), tostring(secs), tostring(mode or "detecting")))
        task.wait(0.5)
    end
end)

----------------------------------------------------------------
-- 5) ĐẶT UNIT KHI ĐỦ ĐIỀU KIỆN
----------------------------------------------------------------
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
        warn(("[TimePlacer] >>> ĐÃ ĐẶT %s tại mốc %ds."):format(UNIT_NAME, TARGET_SECONDS))
    else
        warn("[TimePlacer] LỖI đặt unit:", err)
    end
end

----------------------------------------------------------------
-- 6) MAIN LOOP: tự phát hiện đếm lên/đếm xuống & kích hoạt đặt
----------------------------------------------------------------
task.spawn(function()
    warn(("[TimePlacer] Theo dõi IconLabel: %s"):format(TimerLabel:GetFullName()))
    -- bám theo thay đổi Text
    TimerLabel:GetPropertyChangedSignal("Text"):Connect(function()
        local raw, secs = readTimer()
        if not secs then return end

        -- phát hiện mode
        if COUNT_MODE == "auto" then
            if lastSecs and not mode then
                if secs > lastSecs then mode = "up"
                elseif secs < lastSecs then mode = "down"
                end
                if mode then print("[TimePlacer] Detected mode =", mode) end
            end
        else
            mode = COUNT_MODE
        end

        -- điều kiện đặt
        if not placed and mode then
            if (mode == "up" and secs >= TARGET_SECONDS) or (mode == "down" and secs <= TARGET_SECONDS) then
                print(("[TimePlacer] Điều kiện đạt: %ds (mode=%s), tiến hành đặt..."):format(secs, mode))
                placeOnce()
            end
        end

        lastSecs = secs
    end)

    -- kích hoạt lần đầu để cập nhật lastSecs/mode sớm
    local _, firstSecs = readTimer()
    lastSecs = firstSecs
end)

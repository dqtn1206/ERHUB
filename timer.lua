-- Debug đặt unit theo mốc thời gian UI + in log đầy đủ
-- by: bạn và mình ^^

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--========================
-- CONFIG MỐC THỜI GIAN
--========================
local TARGET_SECONDS = 10            -- muốn đặt lúc 10s (nếu đếm lên). Nếu timer là đếm xuống, sẽ đặt khi <= 10s (tự phát hiện)
local LOG_EVERY = 0.5                -- in log thời gian hiện tại mỗi X giây

-- Unit args bạn đưa:
local UNIT_NAME = "unit_log_roller"
local POS = Vector3.new(-305.38128662109375, 61.93030548095703, -163.8728485107422)
local CF  = CFrame.new(-305.38128662109375, 61.93030548095703, -163.8728485107422, -1, 0, -0, -0, 1, -0, -0, 0, -1)
local PATH_INDEX = 1
local DIST_ALONG = 100.32081599071108
local ROT = 180

local PlaceUnit = ReplicatedStorage:WaitForChild("RemoteFunctions"):WaitForChild("PlaceUnit")

--========================
-- HÀM TÌM & ĐỌC TIMER
--========================
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

-- Quét toàn bộ PlayerGui, lấy **đoạn thời gian mới nhất** tìm thấy + object chứa nó
local function readTimerOnce()
    local bestText, bestSecs, bestObj
    for _, obj in ipairs(playerGui:GetDescendants()) do
        local ok, text = pcall(function() return obj.Text end)
        if ok and text then
            local t = extractTimeText(text)
            if t then
                bestText = t
                bestSecs = parseToSeconds(t)
                bestObj = obj
            end
        end
    end
    return bestText, bestSecs, bestObj
end

--========================
-- ĐẶT UNIT
--========================
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
        warn(("[TimePlacer] >>> ĐÃ ĐẶT %s tại mốc thời gian yêu cầu."):format(UNIT_NAME))
    else
        warn("[TimePlacer] LỖI khi đặt unit:", err)
    end
end

--========================
-- MAIN LOOP + LOG
--========================
task.spawn(function()
    warn(("[TimePlacer] Đang theo dõi timer… mục tiêu = %ds."):format(TARGET_SECONDS))
    local lastSecs, lastText, lastObjPath = nil, nil, nil
    local mode -- "up" = đếm lên, "down" = đếm xuống (tự phát hiện)
    local lastLog = 0

    while not placed do
        local text, secs, obj = readTimerOnce()

        -- In log theo chu kỳ, cho bạn thấy **thời gian hiện tại** và **đường dẫn label**:
        if os.clock() - lastLog >= LOG_EVERY then
            if text and secs and obj then
                local path = obj:GetFullName()
                print(("[Timer] %s  ->  %ds   | %s"):format(text, secs, path))
                lastObjPath = path
            else
                print("[Timer] (chưa bắt được timer từ UI) – vẫn quét…")
            end
            lastLog = os.clock()
        end

        -- Tự phát hiện timer đếm lên/đếm xuống khi có 2 mẫu liên tiếp
        if secs and lastSecs then
            if not mode then
                if secs > lastSecs then mode = "up" elseif secs < lastSecs then mode = "down" end
                if mode then print("[TimePlacer] Phát hiện chế độ timer:", mode) end
            end
        end

        -- Điều kiện kích hoạt đặt:
        -- - Nếu đếm **lên**: secs >= TARGET_SECONDS
        -- - Nếu đếm **xuống**: secs <= TARGET_SECONDS
        if secs then
            if (mode == "up" and secs >= TARGET_SECONDS) or (mode == "down" and secs <= TARGET_SECONDS) then
                print(("[TimePlacer] Điều kiện đạt: timer=%ds (mode=%s). Tiến hành đặt…"):format(secs, tostring(mode or "?")))
                placeOnce()
                break
            end
        end

        lastSecs = secs or lastSecs
        lastText = text or lastText
        task.wait(0.1)
    end
end)

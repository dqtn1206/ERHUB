-- SmartTimerPicker + Time-based placer
-- Tự tìm timer thật (tránh nhãn số của Hotbar), in thời gian hiện tại, đặt unit khi đạt mốc

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local TARGET_SECONDS = 10              -- mốc muốn đặt
local COUNT_MODE = "auto"              -- "auto" | "up" | "down"

-- Unit args (bạn đã cung cấp):
local UNIT_NAME = "unit_log_roller"
local POS = Vector3.new(-305.38128662109375, 61.93030548095703, -163.8728485107422)
local CF  = CFrame.new(-305.38128662109375, 61.93030548095703, -163.8728485107422, -1, 0, -0, -0, 1, -0, -0, 0, -1)
local PATH_INDEX = 1
local DIST_ALONG = 100.32081599071108
local ROT = 180

local PlaceUnit = ReplicatedStorage:WaitForChild("RemoteFunctions"):WaitForChild("PlaceUnit")

-- Các từ khóa path cần loại trừ (gây nhiễu như Hotbar/Inventory/Shop)
local EXCLUDED_PATH_PARTS = {
  "BackpackGui", "Backpack", "Hotbar", "Inventory", "Shop", "EventShop", "Number",
}

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------
local function pathContainsAny(path, parts)
  for _, p in ipairs(parts) do
    if string.find(path, p, 1, true) then return true end
  end
  return false
end

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

local function scoreFormat(tText)
  -- ưu tiên h:mm:ss và mm:ss hơn số thuần
  if not tText then return 0 end
  if tText:match("^%d+:%d+:%d+$") then return 3 end
  if tText:match("^%d+:%d+$") then return 2 end
  return 1
end

----------------------------------------------------------------
-- TÌM TIMER THẬT: chấm điểm các ứng viên, theo dõi xem có thay đổi hay không
----------------------------------------------------------------
local function pickTimerLabel(timeoutSec)
  local deadline = tick() + (timeoutSec or 6)
  local candidates = {}  -- obj -> {path=..., last=..., changes=0, fmtScore=...}

  -- thu thập ứng viên ban đầu
  for _, obj in ipairs(playerGui:GetDescendants()) do
    local ok, text = pcall(function() return obj.Text end)
    if ok and text ~= nil then
      local tText = extractTimeText(text)
      if tText then
        local path = obj:GetFullName()
        if not pathContainsAny(path, EXCLUDED_PATH_PARTS) then
          candidates[obj] = { path = path, last = tText, changes = 0, fmtScore = scoreFormat(tText) }
        end
      end
    end
  end

  -- theo dõi thay đổi trong vài giây để biết ai là timer thật
  while tick() < deadline do
    for obj, info in pairs(candidates) do
      if obj.Parent then
        local ok, nowTextRaw = pcall(function() return obj.Text end)
        if ok and nowTextRaw ~= nil then
          local tText = extractTimeText(nowTextRaw)
          if tText and tText ~= info.last then
            info.changes += 1
            info.last = tText
            -- cập nhật độ ưu tiên theo format mới nhất
            info.fmtScore = math.max(info.fmtScore, scoreFormat(tText))
          end
        end
      end
    end
    task.wait(0.25)
  end

  -- chọn obj có (changes nhiều nhất) + (fmtScore cao) + (không nằm trong blacklist)
  local bestObj, bestScore = nil, -1
  for obj, info in pairs(candidates) do
    -- điểm tổng: thay đổi nặng điểm, format ưu tiên
    local score = info.changes * 10 + info.fmtScore
    if score > bestScore then
      bestScore = score
      bestObj = obj
    end
  end

  if bestObj then
    warn(("[TimerPicker] Chọn: %s (score=%d)"):format(bestObj:GetFullName(), bestScore))
  else
    warn("[TimerPicker] Không tìm thấy timer phù hợp (có thể UI khác thường).")
  end
  return bestObj
end

----------------------------------------------------------------
-- ĐẶT UNIT
----------------------------------------------------------------
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
    ReplicatedStorage.RemoteFunctions.PlaceUnit:InvokeServer(table.unpack(args))
  end)
  if ok then
    warn(("[TimePlacer] >>> ĐÃ ĐẶT %s tại mốc %ds."):format(UNIT_NAME, TARGET_SECONDS))
  else
    warn("[TimePlacer] LỖI đặt unit:", err)
  end
end

----------------------------------------------------------------
-- MAIN
----------------------------------------------------------------
task.spawn(function()
  -- 1) Tìm timer thật (tránh Hotbar/Backpack)
  local TimerLabel = pickTimerLabel(6)
  if not TimerLabel then
    warn("[TimePlacer] Không bắt được timer. (Log: kiểm tra xem có path chứa Backpack/Hotbar không)")
    return
  end

  -- 2) Theo dõi & IN THỜI GIAN HIỆN TẠI liên tục
  local lastSecs, mode
  local function readTimer()
    local raw = TimerLabel.Text
    local tText = extractTimeText(raw)
    local secs = parseToSeconds(tText)
    return raw, secs
  end

  -- log đều để bạn thấy “thời gian hiện tại”
  task.spawn(function()
    while not placed do
      local raw, secs = readTimer()
      print(("[Timer] %s  ->  %s s  | %s")
        :format(tostring(raw), tostring(secs), TimerLabel:GetFullName()))
      task.wait(0.5)
    end
  end)

  -- 3) Gắn listener để phát hiện chiều đếm & kích hoạt đặt
  TimerLabel:GetPropertyChangedSignal("Text"):Connect(function()
    local raw, secs = readTimer()
    if not secs then return end

    if COUNT_MODE == "auto" and lastSecs and not mode then
      if secs > lastSecs then mode = "up"
      elseif secs < lastSecs then mode = "down"
      end
      if mode then print("[TimePlacer] Mode =", mode) end
    elseif COUNT_MODE ~= "auto" then
      mode = COUNT_MODE
    end

    if not placed and mode then
      if (mode == "up" and secs >= TARGET_SECONDS) or (mode == "down" and secs <= TARGET_SECONDS) then
        print(("[TimePlacer] Điều kiện đạt tại %ds (mode=%s) -> đặt unit"):format(secs, mode))
        placeOnce()
      end
    end

    lastSecs = secs
  end)

  -- kickstart
  local _, s0 = readTimer()
  lastSecs = s0
end)

-- === Bắt timer trong IconLabelContainer (lọc icon) + đặt unit lúc 10s (PathIndex=3) ===

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 1) Lấy CONTAINER chứa icon + text (đúng path UI)
local container = playerGui
  :WaitForChild("TopbarStandard")
  :WaitForChild("Holders")
  :WaitForChild("Right")
  :WaitForChild("Widget")
  :WaitForChild("IconButton")
  :WaitForChild("Menu")
  :WaitForChild("IconSpot")
  :WaitForChild("Contents")
  :WaitForChild("IconLabelContainer")

-- 2) Helpers: tách & parse thời gian (bỏ icon/ký tự lạ)
local function extractTimeText(s: string?)
  if type(s) ~= "string" then return nil end
  -- ưu tiên h:mm:ss
  local last
  for h,m,ss in s:gmatch("(%d+):(%d+):(%d+)") do last = string.format("%s:%s:%s", h,m,ss) end
  if last then return last end
  -- mm:ss
  for m,ss in s:gmatch("(%d+):(%d%d)") do last = string.format("%s:%s", m,ss) end
  if last then return last end
  -- fallback: số thuần
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

-- 3) Tìm node hiển thị số thời gian bên trong container
local function findTimerNode()
  local best, bestScore = nil, -1
  for _, d in ipairs(container:GetDescendants()) do
    local ok, txt = pcall(function() return d.Text end)
    if ok and type(txt) == "string" and #txt > 0 then
      local tt = extractTimeText(txt)
      if tt then
        local score = 1
        if tt:match("^%d+:%d+:%d+$") then score = 3
        elseif tt:match("^%d+:%d+$")   then score = 2 end
        if score > bestScore then
          best, bestScore = d, score
        end
      end
    end
  end
  return best
end

local TimerNode = findTimerNode()
if not TimerNode then
  warn("[Timer] Không tìm thấy node thời gian trong IconLabelContainer. In toàn bộ text để debug:")
  for _, d in ipairs(container:GetDescendants()) do
    local ok, txt = pcall(function() return d.Text end)
    if ok and txt then print(" -", d:GetFullName(), "=>", txt) end
  end
  return
end
warn("[Timer] Bắt tại:", TimerNode:GetFullName())

local function readTimer()
  local raw = TimerNode.Text
  local tt  = extractTimeText(raw)
  local sec = toSeconds(tt)
  return raw, sec
end

-- 4) Cấu hình đặt theo thời gian
local TARGET_SECONDS = 10          -- mốc muốn đặt
local COUNT_MODE = "auto"          -- "auto" | "up" | "down"
local LOG_INTERVAL = 0.5

-- Args unit (PathIndex=3, vị trí mới)
local UNIT_NAME  = "unit_log_roller"
local PATH_INDEX = 3
local POS        = Vector3.new(-857.3809814453125, 62.18030548095703, -130.04051208496094)
local DIST_ALONG = 227.5109100341797
local ROT        = 180
local CF         = CFrame.new(-857.3809814453125, 62.18030548095703, -130.04051208496094, 1,0,0, 0,1,0, 0,0,1)

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
    warn(("[TimePlacer] >>> ĐÃ ĐẶT %s tại %ds (PathIndex=%d)"):format(UNIT_NAME, TARGET_SECONDS, PATH_INDEX))
  else
    warn("[TimePlacer] LỖI đặt unit:", err)
  end
end

-- 5) Log & kích hoạt khi đạt mốc
local lastSecs, mode

task.spawn(function()
  while not placed do
    local raw, sec = readTimer()
    print(("[Timer] raw='%s' -> %s s"):format(tostring(raw), tostring(sec)))
    task.wait(LOG_INTERVAL)
  end
end)

TimerNode:GetPropertyChangedSignal("Text"):Connect(function()
  local _, sec = readTimer()
  if not sec then return end

  if COUNT_MODE == "auto" and lastSecs and not mode then
    if sec > lastSecs then mode = "up"
    elseif sec < lastSecs then mode = "down" end
    if mode then print("[Timer] Mode:", mode) end
  elseif COUNT_MODE ~= "auto" then
    mode = COUNT_MODE
  end

  if not placed and mode then
    if (mode == "up" and sec >= TARGET_SECONDS) or (mode == "down" and sec <= TARGET_SECONDS) then
      print(("[Timer] Điều kiện đạt: %ds (mode=%s) -> đặt unit"):format(sec, mode))
      placeOnce()
    end
  end

  lastSecs = sec
end)

do
  local _, s0 = readTimer()
  lastSecs = s0
end

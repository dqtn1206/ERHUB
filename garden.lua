local TweenService = game:GetService('TweenService')
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Lighting = game:GetService('Lighting')

----------------------------------------------------------------
-- Chờ LocalPlayer + Character
----------------------------------------------------------------
local player = nil
while not player do
    player = Players.LocalPlayer
    task.wait()
end

if not player.Character or not player.Character.Parent then
    player.CharacterAdded:Wait()
end

local character = player.Character
local hrp = character:WaitForChild('HumanoidRootPart')

----------------------------------------------------------------
-- Hàm giảm đồ họa và ẩn quái
----------------------------------------------------------------
local function hideCharacter(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA('BasePart') then
            part.LocalTransparencyModifier = 1
        elseif part:IsA('Decal') then
            part.Transparency = 1
        end
    end
end

local function hideEntities()
    local EntitiesFolder = workspace:FindFirstChild('Map')
        and workspace.Map:FindFirstChild('Entities')
    if not EntitiesFolder then
        return
    end

    local function processEntity(entity)
        for _, obj in ipairs(entity:GetDescendants()) do
            if obj:IsA('BasePart') then
                obj.LocalTransparencyModifier = 1
                obj.CanCollide = false
            elseif obj:IsA('Decal') or obj:IsA('Texture') then
                obj.Transparency = 1
            end
        end
        -- Ẩn HPHolder nếu có
        local anchor = entity:FindFirstChild('Anchor')
        if anchor and anchor:FindFirstChild('HPHolder') then
            for _, obj in ipairs(anchor.HPHolder:GetDescendants()) do
                if obj:IsA('BasePart') then
                    obj.LocalTransparencyModifier = 1
                elseif obj:IsA('Decal') or obj:IsA('Texture') then
                    obj.Transparency = 1
                elseif obj:IsA('BillboardGui') or obj:IsA('SurfaceGui') then
                    obj.Enabled = false
                end
            end
        end
    end

    -- Ẩn tất cả quái hiện có
    for _, entity in ipairs(EntitiesFolder:GetChildren()) do
        processEntity(entity)
    end

    -- Nếu spawn quái mới thì ẩn luôn
    EntitiesFolder.ChildAdded:Connect(function(child)
        task.wait(0.2)
        processEntity(child)
    end)
end

local function enableLow()
    -- Lighting
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 1e6
    Lighting.Brightness = 0
    Lighting.EnvironmentSpecularScale = 0
    Lighting.EnvironmentDiffuseScale = 0

    -- Toàn map
    for _, v in ipairs(workspace:GetDescendants()) do
        if
            v:IsA('ParticleEmitter')
            or v:IsA('Trail')
            or v:IsA('Beam')
            or v:IsA('Fire')
            or v:IsA('Smoke')
            or v:IsA('Sparkles')
        then
            v.Enabled = false
        elseif v:IsA('Decal') or v:IsA('Texture') then
            v.Transparency = 1
        elseif v:IsA('BasePart') then
            v.Material = Enum.Material.SmoothPlastic
        elseif v:IsA('SpecialMesh') then
            v.VertexColor = Vector3.new(0, 0, 0)
        end
    end

    -- Ẩn nhân vật
    local char = player.Character or player.CharacterAdded:Wait()
    hideCharacter(char)

    -- Ẩn quái + HPHolder
    hideEntities()

    print('[LowGfx] Đã bật giảm đồ họa + ẩn quái + HPHolder')
end

-- Gọi giảm đồ họa ngay khi khởi tạo
enableLow()

-- Nếu respawn thì tiếp tục ẩn nhân vật
player.CharacterAdded:Connect(function(char)
    char:WaitForChild('HumanoidRootPart')
    task.wait(1)
    hideCharacter(char)
end)

----------------------------------------------------------------
-- Hàm hỗ trợ
----------------------------------------------------------------
local function SafeTeleport(targetPos, duration)
    local tweenInfo = TweenInfo.new(
        duration or 1,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.Out
    )
    local goal = { CFrame = CFrame.new(targetPos) }
    local tween = TweenService:Create(hrp, tweenInfo, goal)
    tween:Play()
    tween.Completed:Wait()
end

local function IsInLobby()
    local Map = workspace:FindFirstChild('Map')
    return Map and Map:FindFirstChild('Garden') ~= nil
end

local function IsInFarm()
    return not IsInLobby()
end

----------------------------------------------------------------
-- Tính năng mới: Kiểm tra Entities rỗng và quay về lobby
----------------------------------------------------------------
local function CheckEntitiesAndReturnToLobby()
    task.spawn(function()
        local EntitiesFolder = workspace:FindFirstChild('Map')
            and workspace.Map:FindFirstChild('Entities')
        if not EntitiesFolder then
            return
        end

        local emptyTime = 0

        while true do
            if IsInFarm() then
                local validEntities = {}
                for _, entity in ipairs(EntitiesFolder:GetChildren()) do
                    if entity.Name ~= 'unit_pineapple' then
                        table.insert(validEntities, entity)
                    end
                end

                if #validEntities == 0 then
                    emptyTime += 1
                    if emptyTime >= 20 then
                        pcall(function()
                            local RemoteFunctions =
                                ReplicatedStorage:WaitForChild(
                                    'RemoteFunctions'
                                )
                            local BackToMainLobby =
                                RemoteFunctions:WaitForChild('BackToMainLobby')
                            BackToMainLobby:InvokeServer()
                        end)
                        emptyTime = 0
                    end
                else
                    emptyTime = 0
                end
            else
                emptyTime = 0
            end

            task.wait(1)
        end
    end)
end

-- Gọi hàm kiểm tra Entities ngay khi khởi tạo
CheckEntitiesAndReturnToLobby()

----------------------------------------------------------------
-- Lobby actions
----------------------------------------------------------------
----------------------------------------------------------------
-- Lobby actions (di chuyển bằng chân qua waypoint + set map + giảm player)
----------------------------------------------------------------
local function DoLobbyActions()
    local RemoteFunctions = ReplicatedStorage:WaitForChild('RemoteFunctions')
    local LobbySetMap = RemoteFunctions:FindFirstChild('LobbySetMap_9')
    local LobbySetMaxPlayers =
        RemoteFunctions:FindFirstChild('LobbySetMaxPlayers_9')

    -- Waypoints di chuyển bằng chân
    local waypoints = {
        Vector3.new(103.19132995605469, 65.77661895751953, 851.7169799804688),
        Vector3.new(124.56021881103516, 66.77661895751953, 785.1851196289062),
    }

    -- Lấy character, humanoid, root
    local function getCharacter()
        local char = player.Character or player.CharacterAdded:Wait()
        local humanoid = char:WaitForChild('Humanoid', 10)
        local root = char:WaitForChild('HumanoidRootPart', 10)
        return char, humanoid, root
    end

    -- Kiểm tra khoảng cách
    local function reachedTarget(pos, target, range)
        range = range or 3
        return (pos - target).Magnitude <= range
    end

    -- Di chuyển qua waypoint
    local function moveThroughWaypoints(waypoints)
        local char, humanoid, root = getCharacter()

        for idx, wp in ipairs(waypoints) do
            local arrived = false
            repeat
                if not (char and humanoid and root and humanoid.Parent) then
                    char, humanoid, root = getCharacter()
                end
                humanoid:MoveTo(wp)
                task.wait(0.15)
                if reachedTarget(root.Position, wp, 3) then
                    arrived = true
                end
            until arrived
            task.wait(0.2)
        end
    end

    -- Gọi RemoteFunctions set map + giảm player
    local function invokeRemotes()
        if LobbySetMap then
            for i = 1, 3 do
                pcall(function()
                    LobbySetMap:InvokeServer('map_back_garden')
                end)
                task.wait(1)
            end
        end

        if LobbySetMaxPlayers then
            for i = 1, 3 do
                pcall(function()
                    LobbySetMaxPlayers:InvokeServer(1)
                end)
                task.wait(1)
            end
        end
    end

    -- Main loop lobby
    while IsInLobby() do
        print('[Lobby] Bắt đầu đi qua waypoint...')
        moveThroughWaypoints(waypoints)
        print(
            '[Lobby] Đã tới waypoint cuối, bắt đầu set map + giảm player...'
        )
        invokeRemotes()
        print('[Lobby] Hoàn tất RemoteFunctions.')

        -- Đợi 10 giây nếu vẫn còn ở lobby trước khi lặp lại
        local t = 0
        repeat
            task.wait(1)
            t = t + 1
        until not IsInLobby() or t >= 10

        if not IsInLobby() then
            break
        end
    end
end

----------------------------------------------------------------
-- Farm actions
----------------------------------------------------------------
local function DoFarmActions()
    local RemoteFunctions = ReplicatedStorage:WaitForChild('RemoteFunctions')
    local ChangeTickSpeed = RemoteFunctions:WaitForChild('ChangeTickSpeed')
    local SkipWave = RemoteFunctions:WaitForChild('SkipWave')
    local PlaceDifficultyVote =
        RemoteFunctions:WaitForChild('PlaceDifficultyVote')

    pcall(function()
        ChangeTickSpeed:InvokeServer(2)
    end)

    task.spawn(function()
        local guiPath = nil
        pcall(function()
            guiPath = player.PlayerGui
                :WaitForChild('GameGui', 10)
                :WaitForChild('Screen', 10)
                :WaitForChild('Middle', 10)
                :WaitForChild('DifficultyVote', 10)
        end)

        if guiPath then
            while IsInFarm() do
                pcall(function()
                    PlaceDifficultyVote:InvokeServer('dif_hard')
                end)
                task.wait(2)
            end
        end
    end)

    while IsInFarm() do
        task.wait(0.5)
        pcall(function()
            SkipWave:InvokeServer('y')
        end)
    end
end

-----

task.spawn(function()
    local ReplicatedStorage = game:GetService('ReplicatedStorage')
    local RestartGame = ReplicatedStorage:WaitForChild('RemoteFunctions')
        :WaitForChild('RestartGame')
    local successCount = 0 -- Biến đếm số lần restart thành công

    while true do
        local success, result = pcall(function()
            return RestartGame:InvokeServer() -- Gọi RemoteFunction
        end)

        if success and result == true then -- Kiểm tra nếu pcall thành công VÀ server trả về true
            successCount = successCount + 1
            print(
                'RestartGame thành công! Tổng số lần thành công: '
                    .. successCount
            )
        else
            if not success then
                warn('RestartGame thất bại (lỗi): ' .. tostring(result))
            else
                warn(
                    'RestartGame thất bại (server trả về false hoặc không hợp lệ): '
                        .. tostring(result)
                )
            end
        end

        task.wait(2) -- Chờ 2 giây trước khi thử lại
    end
end)

-- Show info

local Players = game:GetService('Players')
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild('PlayerGui')

-- Tạo ScreenGui
local screenGui = Instance.new('ScreenGui')
screenGui.Name = 'FullGameOverlay'
screenGui.ResetOnSpawn = false
screenGui.Parent = PlayerGui

-- Background mờ phủ toàn bộ game
local background = Instance.new('Frame')
background.Size = UDim2.new(1, 0, 1, 0) -- full screen
background.Position = UDim2.new(0, 0, 0, 0)
background.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- màu đen mờ
background.BackgroundTransparency = 0.7 -- mờ vừa phải
background.BorderSizePixel = 0
background.Parent = screenGui

-- Frame chứa tên + seed, căn giữa
local infoFrame = Instance.new('Frame')
infoFrame.Size = UDim2.new(0.4, 0, 0.2, 0)
infoFrame.AnchorPoint = Vector2.new(0.5, 0.5)
infoFrame.Position = UDim2.new(0.5, 0, 0.5, 0) -- chính giữa màn hình
infoFrame.BackgroundTransparency = 1
infoFrame.Parent = background

-- Tên acc
local nameLabel = Instance.new('TextLabel')
nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
nameLabel.Position = UDim2.new(0, 0, 0, 0)
nameLabel.Text = player.Name
nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
nameLabel.BackgroundTransparency = 1
nameLabel.TextScaled = true
nameLabel.Font = Enum.Font.GothamBlack
nameLabel.TextStrokeTransparency = 0
nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
nameLabel.TextXAlignment = Enum.TextXAlignment.Center
nameLabel.TextYAlignment = Enum.TextYAlignment.Center
nameLabel.Parent = infoFrame

-- Seed acc
local seedLabel = Instance.new('TextLabel')
seedLabel.Size = UDim2.new(1, 0, 0.4, 0)
seedLabel.Position = UDim2.new(0, 0, 0.6, 0)
seedLabel.Text = 'Seeds: 0'
seedLabel.TextColor3 = Color3.fromRGB(0, 255, 128)
seedLabel.BackgroundTransparency = 1
seedLabel.TextScaled = true
seedLabel.Font = Enum.Font.GothamBold
seedLabel.TextStrokeTransparency = 0
seedLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
seedLabel.TextXAlignment = Enum.TextXAlignment.Center
seedLabel.TextYAlignment = Enum.TextYAlignment.Center
seedLabel.Parent = infoFrame

-- Cập nhật seed theo thời gian thực
local leaderstats = player:WaitForChild('leaderstats')
local seeds = leaderstats:WaitForChild('Seeds')

seeds.Changed:Connect(function(value)
    seedLabel.Text = 'Seeds: ' .. value
end)
seedLabel.Text = 'Seeds: ' .. seeds.Value

----------------------------------------------------------------
-- Main loop
----------------------------------------------------------------
task.wait(5)

while true do
    if IsInLobby() then
        DoLobbyActions()
    elseif IsInFarm() then
        DoFarmActions()
    else
        task.wait(3)
    end
    task.wait(1)
end

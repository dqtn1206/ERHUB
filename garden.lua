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
    local workspace = game:GetService('Workspace')
    return workspace:FindFirstChild('Map')
        and workspace.Map:FindFirstChild('BackGarden') ~= nil
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
        if not EntitiesFolder then return end

        local emptyTime = 0

        while true do
            if IsInFarm() then
                local validEntities = {}
                for _, entity in ipairs(EntitiesFolder:GetChildren()) do
                    if entity.Name ~= "unit_pineapple" then
                        table.insert(validEntities, entity)
                    end
                end

                if #validEntities == 0 then
                    emptyTime += 1
                    if emptyTime >= 25 then
                        pcall(function()
                            local RemoteFunctions = ReplicatedStorage:WaitForChild('RemoteFunctions')
                            local BackToMainLobby = RemoteFunctions:WaitForChild('BackToMainLobby')
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
local function DoLobbyActions()
    local RemoteFunctions = ReplicatedStorage:WaitForChild('RemoteFunctions')
    local LobbySetMaxPlayers =
        RemoteFunctions:WaitForChild('LobbySetMaxPlayers_15')

    while IsInLobby() do
        -- Teleport tới chỗ lobby
        SafeTeleport(Vector3.new(179.1495, 87.3262, 812.2331), 2)

        -- Set max players 5 lần
        for i = 1, 5 do
            pcall(function()
                LobbySetMaxPlayers:InvokeServer(1)
            end)
            task.wait(1.5)
        end

        -- Đợi 10 giây, nếu vẫn còn ở lobby thì lặp lại
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

----------------------------------------------------------------
-- Auto Again (RestartGame spam mỗi 2 giây)
----------------------------------------------------------------
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

--// Variables
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local cache = {}

local bones = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "LowerTorso"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

--// Settings
local ESP_SETTINGS = {
    BoxOutlineColor = Color3.new(0, 0, 0),
    BoxColor = Color3.new(1, 1, 1),
    NameColor = Color3.new(1, 1, 1),
    HealthOutlineColor = Color3.new(0, 0, 0),
    HealthHighColor = Color3.new(0, 1, 0),
    HealthLowColor = Color3.new(1, 0, 0),
    CharSize = Vector2.new(4, 6),
    Teamcheck = false,
    WallCheck = false,
    Enabled = false,
    ShowBox = false,
    BoxType = "2D",
    ShowName = false,
    ShowHealth = false,
    ShowDistance = false,
    ShowSkeletons = false,
    ShowTracer = false,
    TracerColor = Color3.new(1, 1, 1), 
    TracerThickness = 2,
    SkeletonsColor = Color3.new(1, 1, 1),
    TracerPosition = "Bottom",
}

local function create(class, properties)
    local drawing = Drawing.new(class)
    for property, value in pairs(properties) do
        drawing[property] = value
    end
    return drawing
end

local function createEsp(player)
    local esp = {
        tracer = create("Line", {
            Thickness = ESP_SETTINGS.TracerThickness,
            Color = ESP_SETTINGS.TracerColor,
            Transparency = 0.5
        }),
        boxOutline = create("Square", {
            Color = ESP_SETTINGS.BoxOutlineColor,
            Thickness = 3,
            Filled = false
        }),
        box = create("Square", {
            Color = ESP_SETTINGS.BoxColor,
            Thickness = 1,
            Filled = false
        }),
        name = create("Text", {
            Color = ESP_SETTINGS.NameColor,
            Outline = true,
            Center = true,
            Size = 13
        }),
        healthOutline = create("Line", {
            Thickness = 3,
            Color = ESP_SETTINGS.HealthOutlineColor
        }),
        health = create("Line", {
            Thickness = 1
        }),
        distance = create("Text", {
            Color = Color3.new(1, 1, 1),
            Size = 12,
            Outline = true,
            Center = true
        }),
        boxLines = {},
        skeletonlines = {}
    }

    cache[player] = esp
end

local function isPlayerBehindWall(player)
    local character = player.Character
    if not character then
        return false
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return false
    end

    local ray = Ray.new(camera.CFrame.Position, (rootPart.Position - camera.CFrame.Position).Unit * (rootPart.Position - camera.CFrame.Position).Magnitude)
    local hit, position = workspace:FindPartOnRayWithIgnoreList(ray, {localPlayer.Character, character})
    
    return hit and hit:IsA("Part")
end

local function removeEsp(player)
    local esp = cache[player]
    if not esp then return end

    for _, drawing in pairs(esp) do
        if type(drawing) == "table" then
            for _, line in ipairs(drawing) do
                if type(line) == "table" then
                    line[1]:Remove()
                else
                    line:Remove()
                end
            end
        else
            drawing:Remove()
        end
    end

    cache[player] = nil
end

local function cleanupBoxLines(esp)
    for _, line in ipairs(esp.boxLines) do
        line.Visible = false
    end
end

local function cleanupSkeletonLines(esp)
    for _, lineData in ipairs(esp.skeletonlines) do
        lineData[1].Visible = false
    end
end

local function updateEsp()
    for player, esp in pairs(cache) do
        local character, team = player.Character, player.Team
        if character and (not ESP_SETTINGS.Teamcheck or (team and team ~= localPlayer.Team)) then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local head = character:FindFirstChild("Head")
            local humanoid = character:FindFirstChild("Humanoid")
            local isBehindWall = ESP_SETTINGS.WallCheck and isPlayerBehindWall(player)
            local shouldShow = not isBehindWall and ESP_SETTINGS.Enabled
            
            if rootPart and head and humanoid and shouldShow then
                local position, onScreen = camera:WorldToViewportPoint(rootPart.Position)
                
                if onScreen then
                    local hrp2D = camera:WorldToViewportPoint(rootPart.Position)
                    local charSize = (camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0)).Y - camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 2.6, 0)).Y) / 2
                    local boxSize = Vector2.new(math.floor(charSize * 1.8), math.floor(charSize * 1.9))
                    local boxPosition = Vector2.new(math.floor(hrp2D.X - charSize * 1.8 / 2), math.floor(hrp2D.Y - charSize * 1.6 / 2))

                    -- Name ESP
                    if ESP_SETTINGS.ShowName then
                        esp.name.Visible = true
                        esp.name.Text = string.lower(player.Name)
                        esp.name.Position = Vector2.new(boxSize.X / 2 + boxPosition.X, boxPosition.Y - 16)
                        esp.name.Color = ESP_SETTINGS.NameColor
                    else
                        esp.name.Visible = false
                    end

                    -- Box ESP
                    if ESP_SETTINGS.ShowBox then
                        if ESP_SETTINGS.BoxType == "2D" then
                            -- Show 2D box, hide corner box lines
                            esp.boxOutline.Size = boxSize
                            esp.boxOutline.Position = boxPosition
                            esp.boxOutline.Visible = true
                            
                            esp.box.Size = boxSize
                            esp.box.Position = boxPosition
                            esp.box.Color = ESP_SETTINGS.BoxColor
                            esp.box.Visible = true
                            
                            -- Hide corner box lines
                            cleanupBoxLines(esp)
                            
                        elseif ESP_SETTINGS.BoxType == "Corner Box Esp" then
                            -- Hide 2D boxes
                            esp.box.Visible = false
                            esp.boxOutline.Visible = false
                            
                            -- Create corner box lines if they don't exist
                            if #esp.boxLines == 0 then
                                for i = 1, 16 do
                                    local boxLine = create("Line", {
                                        Thickness = 1,
                                        Color = ESP_SETTINGS.BoxColor,
                                        Transparency = 1
                                    })
                                    esp.boxLines[i] = boxLine
                                end
                            end
                            
                            -- Update corner box lines
                            local lineW = (boxSize.X / 5)
                            local lineH = (boxSize.Y / 6)
                            local lineT = 1

                            -- top left
                            esp.boxLines[1].From = Vector2.new(boxPosition.X - lineT, boxPosition.Y - lineT)
                            esp.boxLines[1].To = Vector2.new(boxPosition.X + lineW, boxPosition.Y - lineT)
                            esp.boxLines[1].Color = ESP_SETTINGS.BoxColor

                            esp.boxLines[2].From = Vector2.new(boxPosition.X - lineT, boxPosition.Y - lineT)
                            esp.boxLines[2].To = Vector2.new(boxPosition.X - lineT, boxPosition.Y + lineH)
                            esp.boxLines[2].Color = ESP_SETTINGS.BoxColor

                            -- top right
                            esp.boxLines[3].From = Vector2.new(boxPosition.X + boxSize.X - lineW, boxPosition.Y - lineT)
                            esp.boxLines[3].To = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y - lineT)
                            esp.boxLines[3].Color = ESP_SETTINGS.BoxColor

                            esp.boxLines[4].From = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y - lineT)
                            esp.boxLines[4].To = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y + lineH)
                            esp.boxLines[4].Color = ESP_SETTINGS.BoxColor

                            -- bottom left
                            esp.boxLines[5].From = Vector2.new(boxPosition.X - lineT, boxPosition.Y + boxSize.Y - lineH)
                            esp.boxLines[5].To = Vector2.new(boxPosition.X - lineT, boxPosition.Y + boxSize.Y + lineT)
                            esp.boxLines[5].Color = ESP_SETTINGS.BoxColor

                            esp.boxLines[6].From = Vector2.new(boxPosition.X - lineT, boxPosition.Y + boxSize.Y + lineT)
                            esp.boxLines[6].To = Vector2.new(boxPosition.X + lineW, boxPosition.Y + boxSize.Y + lineT)
                            esp.boxLines[6].Color = ESP_SETTINGS.BoxColor

                            -- bottom right
                            esp.boxLines[7].From = Vector2.new(boxPosition.X + boxSize.X - lineW, boxPosition.Y + boxSize.Y + lineT)
                            esp.boxLines[7].To = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y + boxSize.Y + lineT)
                            esp.boxLines[7].Color = ESP_SETTINGS.BoxColor

                            esp.boxLines[8].From = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y + boxSize.Y - lineH)
                            esp.boxLines[8].To = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y + boxSize.Y + lineT)
                            esp.boxLines[8].Color = ESP_SETTINGS.BoxColor

                            -- Set outline properties for lines 9-16
                            for i = 9, 16 do
                                esp.boxLines[i].Thickness = 2
                                esp.boxLines[i].Color = ESP_SETTINGS.BoxOutlineColor
                            end

                            -- inline top left
                            esp.boxLines[9].From = Vector2.new(boxPosition.X, boxPosition.Y)
                            esp.boxLines[9].To = Vector2.new(boxPosition.X, boxPosition.Y + lineH)

                            esp.boxLines[10].From = Vector2.new(boxPosition.X, boxPosition.Y)
                            esp.boxLines[10].To = Vector2.new(boxPosition.X + lineW, boxPosition.Y)

                            -- inline top right
                            esp.boxLines[11].From = Vector2.new(boxPosition.X + boxSize.X - lineW, boxPosition.Y)
                            esp.boxLines[11].To = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y)

                            esp.boxLines[12].From = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y)
                            esp.boxLines[12].To = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y + lineH)

                            -- inline bottom left
                            esp.boxLines[13].From = Vector2.new(boxPosition.X, boxPosition.Y + boxSize.Y - lineH)
                            esp.boxLines[13].To = Vector2.new(boxPosition.X, boxPosition.Y + boxSize.Y)

                            esp.boxLines[14].From = Vector2.new(boxPosition.X, boxPosition.Y + boxSize.Y)
                            esp.boxLines[14].To = Vector2.new(boxPosition.X + lineW, boxPosition.Y + boxSize.Y)

                            -- inline bottom right
                            esp.boxLines[15].From = Vector2.new(boxPosition.X + boxSize.X - lineW, boxPosition.Y + boxSize.Y)
                            esp.boxLines[15].To = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y + boxSize.Y)

                            esp.boxLines[16].From = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y + boxSize.Y - lineH)
                            esp.boxLines[16].To = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y + boxSize.Y)

                            -- Show all corner box lines
                            for _, line in ipairs(esp.boxLines) do
                                line.Visible = true
                            end
                        end
                    else
                        -- Hide all box elements
                        esp.box.Visible = false
                        esp.boxOutline.Visible = false
                        cleanupBoxLines(esp)
                    end

                    -- Health ESP
                    if ESP_SETTINGS.ShowHealth then
                        esp.healthOutline.Visible = true
                        esp.health.Visible = true
                        local healthPercentage = humanoid.Health / humanoid.MaxHealth
                        esp.healthOutline.From = Vector2.new(boxPosition.X - 8, boxPosition.Y + boxSize.Y)
                        esp.healthOutline.To = Vector2.new(esp.healthOutline.From.X, esp.healthOutline.From.Y - boxSize.Y)
                        esp.health.From = Vector2.new(boxPosition.X - 7, boxPosition.Y + boxSize.Y)
                        esp.health.To = Vector2.new(esp.health.From.X, esp.health.From.Y - healthPercentage * boxSize.Y)
                        esp.health.Color = ESP_SETTINGS.HealthLowColor:Lerp(ESP_SETTINGS.HealthHighColor, healthPercentage)
                    else
                        esp.healthOutline.Visible = false
                        esp.health.Visible = false
                    end

                    -- Distance ESP
                    if ESP_SETTINGS.ShowDistance then
                        local distance = (camera.CFrame.p - rootPart.Position).Magnitude
                        local distanceInMeters = distance * 0.28
                        esp.distance.Text = string.format("%.1f meters", distanceInMeters)
                        esp.distance.Position = Vector2.new(boxPosition.X + boxSize.X / 2, boxPosition.Y + boxSize.Y + 5)
                        esp.distance.Visible = true
                    else
                        esp.distance.Visible = false
                    end

                    -- Skeleton ESP
                    if ESP_SETTINGS.ShowSkeletons then
                        if #esp.skeletonlines == 0 then
                            for _, bonePair in ipairs(bones) do
                                local parentBone, childBone = bonePair[1], bonePair[2]
                                
                                if character:FindFirstChild(parentBone) and character:FindFirstChild(childBone) then
                                    local skeletonLine = create("Line", {
                                        Thickness = 1,
                                        Color = ESP_SETTINGS.SkeletonsColor,
                                        Transparency = 1
                                    })
                                    table.insert(esp.skeletonlines, {skeletonLine, parentBone, childBone})
                                end
                            end
                        end
                        
                        for _, lineData in ipairs(esp.skeletonlines) do
                            local skeletonLine, parentBone, childBone = lineData[1], lineData[2], lineData[3]
                            
                            if character:FindFirstChild(parentBone) and character:FindFirstChild(childBone) then
                                local parentPos = camera:WorldToViewportPoint(character[parentBone].Position)
                                local childPos = camera:WorldToViewportPoint(character[childBone].Position)
                                
                                if parentPos.Z > 0 and childPos.Z > 0 then
                                    skeletonLine.From = Vector2.new(parentPos.X, parentPos.Y)
                                    skeletonLine.To = Vector2.new(childPos.X, childPos.Y)
                                    skeletonLine.Color = ESP_SETTINGS.SkeletonsColor
                                    skeletonLine.Visible = true
                                else
                                    skeletonLine.Visible = false
                                end
                            else
                                skeletonLine.Visible = false
                            end
                        end
                    else
                        cleanupSkeletonLines(esp)
                    end

                    -- Tracer ESP
                    if ESP_SETTINGS.ShowTracer then
                        local tracerY
                        if ESP_SETTINGS.TracerPosition == "Top" then
                            tracerY = 0
                        elseif ESP_SETTINGS.TracerPosition == "Middle" then
                            tracerY = camera.ViewportSize.Y / 2
                        else
                            tracerY = camera.ViewportSize.Y
                        end
                        
                        if ESP_SETTINGS.Teamcheck and player.TeamColor == localPlayer.TeamColor then
                            esp.tracer.Visible = false
                        else
                            esp.tracer.Visible = true
                            esp.tracer.From = Vector2.new(camera.ViewportSize.X / 2, tracerY)
                            esp.tracer.To = Vector2.new(hrp2D.X, hrp2D.Y)
                            esp.tracer.Color = ESP_SETTINGS.TracerColor
                        end
                    else
                        esp.tracer.Visible = false
                    end

                else
                    -- Player is off screen, hide everything
                    esp.box.Visible = false
                    esp.boxOutline.Visible = false
                    esp.name.Visible = false
                    esp.healthOutline.Visible = false
                    esp.health.Visible = false
                    esp.distance.Visible = false
                    esp.tracer.Visible = false
                    cleanupBoxLines(esp)
                    cleanupSkeletonLines(esp)
                end
            else
                -- Character not valid, hide everything
                esp.box.Visible = false
                esp.boxOutline.Visible = false
                esp.name.Visible = false
                esp.healthOutline.Visible = false
                esp.health.Visible = false
                esp.distance.Visible = false
                esp.tracer.Visible = false
                cleanupBoxLines(esp)
                cleanupSkeletonLines(esp)
            end
        else
            -- Team check failed or other conditions, hide everything
            esp.box.Visible = false
            esp.boxOutline.Visible = false
            esp.name.Visible = false
            esp.healthOutline.Visible = false
            esp.health.Visible = false
            esp.distance.Visible = false
            esp.tracer.Visible = false
            cleanupBoxLines(esp)
            cleanupSkeletonLines(esp)
        end
    end
end

-- Initialize ESP for existing players
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= localPlayer then
        createEsp(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= localPlayer then
        createEsp(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    removeEsp(player)
end)

RunService.RenderStepped:Connect(updateEsp)

return ESP_SETTINGS

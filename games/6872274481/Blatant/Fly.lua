run(function()
    local Value
    local VerticalValue
    local WallCheck
    local PopBalloons
    local TP
    local lastonground = false
    local MobileButtons
    local FlyAnywayProgressBar = {Enabled = false}
    local FlyAnywayProgressBarFrame
    local BarColor
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local up, down, old = 0, 0
    local mobileControls = {}
    local groundtime = nil
    local onground = false
    local flyCooldownActive = false
    local lastGroundTouchTime = 0
    local MAX_FLY_TIME = 2.5
    local TP_DOWN_INTERVAL = 2
    local tpReturning = false
    local tick = tick
    local task_wait = task.wait
    local math_max = math.max
    local math_floor = math.floor
    local string_format = string.format
    local vector3new = Vector3.new
    local vector3zero = Vector3.zero
    local udim2new = UDim2.new
    local cframeLookAlong = CFrame.lookAlong
    local cachedBalloonCount = 0
    local lastBalloonCheck = 0
    local balloonCheckInterval = 0.2 
    local cachedMatchState = 0
    local lastMatchStateCheck = 0
    local lastGroundTime = tick()
    local airTime = 0
    
    local function createMobileButton(name, position, icon)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Size = udim2new(0, 60, 0, 60)
        button.Position = position
        button.BackgroundTransparency = 0.2
        button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        button.BorderSizePixel = 0
        button.Text = icon
        button.TextScaled = true
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.Font = Enum.Font.SourceSansBold
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = button
        return button
    end

    local function cleanupMobileControls()
        for _, control in pairs(mobileControls) do
            if control then
                control:Destroy()
            end
        end
        mobileControls = {}
    end

    local progressBarFrameCounter = 0
    local MAX_FRAME_COUNTER = 600
    local function updateProgressBar()
        if not FlyAnywayProgressBarFrame then return end

        if not Fly.Enabled or not entitylib.isAlive or not lplr.Character then
            FlyAnywayProgressBarFrame.Visible = false
            return
        end
        
        local now = tick()
        if now - lastBalloonCheck > balloonCheckInterval then
            lastBalloonCheck = now
            cachedBalloonCount = lplr.Character:GetAttribute('InflatedBalloons') or 0
            cachedMatchState = store.matchState
        end
        
        local flyAllowed = cachedBalloonCount > 0 or cachedMatchState == 2
        
        if flyAllowed then
            FlyAnywayProgressBarFrame.Frame.Size = udim2new(1, 0, 0, 20)
            FlyAnywayProgressBarFrame.TextLabel.Text = "∞"
            FlyAnywayProgressBarFrame.Visible = FlyAnywayProgressBar.Enabled
            return
        end
        
        if TP and TP.Enabled then
            local timeLeft = math_max(0, TP_DOWN_INTERVAL - airTime)
            FlyAnywayProgressBarFrame.Frame.Size = udim2new(timeLeft / TP_DOWN_INTERVAL, 0, 0, 20)
            FlyAnywayProgressBarFrame.TextLabel.Text = tpReturning and 'Returning' or string_format('TP Down: %.1fs', timeLeft)
            FlyAnywayProgressBarFrame.Visible = FlyAnywayProgressBar.Enabled
            return
        end

        progressBarFrameCounter = (progressBarFrameCounter + 1) % MAX_FRAME_COUNTER
        if progressBarFrameCounter % 3 == 0 then
            local hipHeight = entitylib.character.Humanoid.HipHeight
            local checkPos = entitylib.character.HumanoidRootPart.Position + vector3new(0, (hipHeight * -2) - 1, 0)
            local newray = getPlacedBlock(checkPos)
            onground = newray ~= nil
        end
        
        if onground then
            groundtime = nil
            flyCooldownActive = false
            lastGroundTouchTime = now
            
            FlyAnywayProgressBarFrame.Frame.Size = udim2new(1, 0, 0, 20)
            FlyAnywayProgressBarFrame.TextLabel.Text = string_format("%.1fs", MAX_FLY_TIME)
            FlyAnywayProgressBarFrame.Visible = FlyAnywayProgressBar.Enabled and Fly.Enabled
            
            local tween = FlyAnywayProgressBarFrame.Frame:FindFirstChild("Tween")
            if tween then
                tween:Destroy()
            end
        else
            if not groundtime then
                groundtime = now + MAX_FLY_TIME
                flyCooldownActive = false
            end
            
            local timeLeft = math_max(0, groundtime - now)
            local progress = timeLeft / MAX_FLY_TIME
            
            FlyAnywayProgressBarFrame.Frame.Size = udim2new(progress, 0, 0, 20)
            FlyAnywayProgressBarFrame.TextLabel.Text = string_format("%.1fs", timeLeft)
            FlyAnywayProgressBarFrame.Visible = FlyAnywayProgressBar.Enabled and Fly.Enabled
            
            if timeLeft <= 0 and not flyCooldownActive then
                flyCooldownActive = true
            end
        end
        
        lastonground = onground
    end

    Fly = vape.Categories.Blatant:CreateModule({
        Name = 'Fly',
        Function = function(callback)
            frictionTable.Fly = callback or nil
            updateVelocity()
            if callback then
                up, down, old = 0, 0, bedwars.BalloonController.deflateBalloon
                bedwars.BalloonController.deflateBalloon = function() end
                local tpTick, tpToggle, oldy = tick(), true
                lastGroundTime = tick()
                airTime = 0
                tpReturning = false
                groundtime = nil
                onground = false
                cachedBalloonCount = lplr.Character and lplr.Character:GetAttribute('InflatedBalloons') or 0
                cachedMatchState = store.matchState

                if lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
                    bedwars.BalloonController:inflateBalloon()
                end

                Fly:Clean(vapeEvents.AttributeChanged.Event:Connect(function(changed)
                    if changed == 'InflatedBalloons' then
                        local char = lplr.Character
                        if not char then return end
                        cachedBalloonCount = char:GetAttribute('InflatedBalloons') or 0
                        if cachedBalloonCount == 0 and getItem('balloon') then
                            bedwars.BalloonController:inflateBalloon()
                        end
                    end
                end))

                local renderFrameCounter = 0
                Fly:Clean(runService.RenderStepped:Connect(function(delta)
                    if FlyAnywayProgressBar.Enabled and Fly.Enabled then
                        renderFrameCounter = renderFrameCounter + 1
                        if renderFrameCounter % 2 == 0 then
                            updateProgressBar()
                        end
                    end
                end))

                local preSimFrameCounter = 0
                local lastWallRaycast = 0
                local wallRaycastInterval = 0.05
                
                Fly:Clean(runService.PreSimulation:Connect(function(dt)
                    if entitylib.isAlive and isnetworkowner(entitylib.character.RootPart) then
                        preSimFrameCounter = preSimFrameCounter + 1
                        local now = tick()
                        
                        if preSimFrameCounter % 12 == 0 then
                            cachedBalloonCount = lplr.Character and lplr.Character:GetAttribute('InflatedBalloons') or 0
                            cachedMatchState = store.matchState
                        end

                        local humanoid = entitylib.character.Humanoid
                        if humanoid.FloorMaterial ~= Enum.Material.Air then
                            lastGroundTime = now
                        end
                        airTime = now - lastGroundTime
                        
                        local flyAllowed = cachedBalloonCount > 0 or cachedMatchState == 2
                        
                        local oscillation = (now % 0.4 < 0.2) and -1 or 1
                        local mass = (1.95 + (flyAllowed and 6 or 0) * oscillation) + ((up + down) * VerticalValue.Value)
                        
                        local root = entitylib.character.RootPart
                        local moveDirection = entitylib.character.Humanoid.MoveDirection
                        local velo = getSpeed()
                        local destination = (moveDirection * math_max(Value.Value - velo, 0) * dt)
                        
                        if WallCheck.Enabled and (now - lastWallRaycast) > wallRaycastInterval then
                            lastWallRaycast = now
                            local filterList = {lplr.Character, gameCamera}
                            if AntiVoidPart then table.insert(filterList, AntiVoidPart) end
                            rayCheck.FilterDescendantsInstances = filterList
                            rayCheck.CollisionGroup = root.CollisionGroup

                            if destination.Magnitude > 0.001 then
                                local ray = workspace:Raycast(root.Position, destination, rayCheck)
                                if ray then
                                    destination = ((ray.Position + ray.Normal) - root.Position)
                                end
                            end
                        end

                        if not flyAllowed then
                            if tpToggle then
                                if airTime > TP_DOWN_INTERVAL then
                                    if not oldy then
                                        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiVoidPart}
                                        rayCheck.CollisionGroup = root.CollisionGroup
                                        local ray = workspace:Raycast(root.Position, vector3new(0, -1000, 0), rayCheck)
                                        if ray and TP.Enabled then
                                            tpToggle = false
                                            tpReturning = true
                                            oldy = root.Position.Y
                                            tpTick = now + 0.11
                                            root.CFrame = cframeLookAlong(vector3new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
                                        end
                                    end
                                end
                            else
                                if oldy then
                                    if tpTick < now then
                                        local newpos = vector3new(root.Position.X, oldy, root.Position.Z)
                                        root.CFrame = cframeLookAlong(newpos, root.CFrame.LookVector)
                                        tpToggle = true
                                        tpReturning = false
                                        oldy = nil
                                    else
                                        mass = 0
                                    end
                                end
                            end
                        end

                        root.CFrame += destination
                        root.AssemblyLinearVelocity = (moveDirection * velo) + vector3new(0, mass, 0)
                    end
                end))

                local isMobile = inputService.TouchEnabled and not inputService.KeyboardEnabled and not inputService.MouseEnabled
                local MobileEnabled = MobileButtons.Enabled or isMobile
                if MobileEnabled then
                    local gui = Instance.new("ScreenGui")
                    gui.Name = "FlyControls"
                    gui.ResetOnSpawn = false
                    gui.Parent = lplr.PlayerGui

                    local upButton = createMobileButton("UpButton", udim2new(0.9, -70, 0.7, -140), "↑")
                    local downButton = createMobileButton("DownButton", udim2new(0.9, -70, 0.7, -70), "↓")

                    mobileControls.UpButton = upButton
                    mobileControls.DownButton = downButton
                    mobileControls.ScreenGui = gui

                    upButton.Parent = gui
                    downButton.Parent = gui

                    Fly:Clean(upButton.MouseButton1Down:Connect(function()
                        up = 1
                    end))
                    Fly:Clean(upButton.MouseButton1Up:Connect(function()
                        up = 0
                    end))
                    Fly:Clean(downButton.MouseButton1Down:Connect(function()
                        down = -1
                    end))
                    Fly:Clean(downButton.MouseButton1Up:Connect(function()
                        down = 0
                    end))
                end

                Fly:Clean(inputService.InputBegan:Connect(function(input)
                    if not inputService:GetFocusedTextBox() then
                        if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
                            up = 1
                        elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
                            down = -1
                        end
                    end
                end))
                Fly:Clean(inputService.InputEnded:Connect(function(input)
                    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
                        up = 0
                    elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
                        down = 0
                    end
                end))
                if inputService.TouchEnabled then
                    pcall(function()
                        local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
                        Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
                            if not mobileControls.UpButton then
                                up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
                            end
                        end))
                    end)
                end
            else
                if FlyAnywayProgressBarFrame then
                    FlyAnywayProgressBarFrame.Visible = false
                end
                lastonground = nil
                groundtime = nil
                flyCooldownActive = false
                tpReturning = false
                airTime = 0
                bedwars.BalloonController.deflateBalloon = old
                if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
                    for _ = 1, 3 do
                        bedwars.BalloonController:deflateBalloon()
                    end
                end
                cleanupMobileControls()
                cachedBalloonCount = 0
                lastBalloonCheck = 0
                cachedMatchState = 0
            end
        end,
        ExtraText = function()
            return 'Heatseeker'
        end,
        Tooltip = 'makes you go zoom!'
    })
    Value = Fly:CreateSlider({
        Name = 'Speed',
        Min = 1,
        Max = 23,
        Default = 23,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    VerticalValue = Fly:CreateSlider({
        Name = 'Vertical Speed',
        Min = 1,
        Max = 150,
        Default = 50,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    WallCheck = Fly:CreateToggle({
        Name = 'Wall Check',
        Default = true
    })
    PopBalloons = Fly:CreateToggle({
        Name = 'Pop Balloons',
        Default = true
    })
    FlyAnywayProgressBar = Fly:CreateToggle({
        Name = "Progress Bar",
        Function = function(callback)
            if BarColor and BarColor.Object then
                BarColor.Object.Visible = callback
            end
            if callback then
                FlyAnywayProgressBarFrame = Instance.new("Frame")
                FlyAnywayProgressBarFrame.AnchorPoint = Vector2.new(0.5, 0)
                FlyAnywayProgressBarFrame.Position = udim2new(0.5, 0, 1, -200)
                FlyAnywayProgressBarFrame.Size = udim2new(0.2, 0, 0, 20)
                FlyAnywayProgressBarFrame.BackgroundTransparency = 0.5
                FlyAnywayProgressBarFrame.BorderSizePixel = 0
                FlyAnywayProgressBarFrame.BackgroundColor3 = Color3.new(0, 0, 0)
                FlyAnywayProgressBarFrame.Visible = false
                FlyAnywayProgressBarFrame.Parent = vape.gui
                
                local FlyAnywayProgressBarFrame2 = Instance.new("Frame")
                FlyAnywayProgressBarFrame2.Name = "Frame"
                FlyAnywayProgressBarFrame2.AnchorPoint = Vector2.new(0, 0)
                FlyAnywayProgressBarFrame2.Position = udim2new(0, 0, 0, 0)
                FlyAnywayProgressBarFrame2.Size = udim2new(1, 0, 0, 20)
                FlyAnywayProgressBarFrame2.BackgroundTransparency = 0
                FlyAnywayProgressBarFrame2.BorderSizePixel = 0
                FlyAnywayProgressBarFrame2.BackgroundColor3 = BarColor and Color3.fromHSV(BarColor.H, BarColor.S, BarColor.V) or Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
                FlyAnywayProgressBarFrame2.Visible = true
                FlyAnywayProgressBarFrame2.Parent = FlyAnywayProgressBarFrame
                
                local FlyAnywayProgressBartext = Instance.new("TextLabel")
                FlyAnywayProgressBartext.Name = "TextLabel"
                FlyAnywayProgressBartext.Text = "2.5s"
                FlyAnywayProgressBartext.Font = Enum.Font.Gotham
                FlyAnywayProgressBartext.TextStrokeTransparency = 0
                FlyAnywayProgressBartext.TextColor3 = Color3.new(0.9, 0.9, 0.9)
                FlyAnywayProgressBartext.TextSize = 20
                FlyAnywayProgressBartext.Size = udim2new(1, 0, 1, 0)
                FlyAnywayProgressBartext.BackgroundTransparency = 1
                FlyAnywayProgressBartext.Position = udim2new(0, 0, 0, 0)
                FlyAnywayProgressBartext.Parent = FlyAnywayProgressBarFrame
            else
                if FlyAnywayProgressBarFrame then 
                    FlyAnywayProgressBarFrame:Destroy() 
                    FlyAnywayProgressBarFrame = nil 
                end
            end
        end,
        Tooltip = "shows time until TP Down, or remaining fly time when TP Down is off",
        Default = true
    })
    BarColor = Fly:CreateColorSlider({
        Name = 'Bar Color',
        Darker = true,
        Visible = false,
        Function = function(h, s, v, o)
            if FlyAnywayProgressBarFrame then
                FlyAnywayProgressBarFrame:FindFirstChild('Frame').BackgroundColor3 = Color3.fromHSV(h, s, v)
                FlyAnywayProgressBarFrame:FindFirstChild('Frame').BackgroundTransparency = 1 - o
            end
        end
    })

    TP = Fly:CreateToggle({
        Name = 'TP Down',
        Default = true,
        Function = function(callback)
            groundtime = nil
            onground = false
            if FlyAnywayProgressBarFrame then
                updateProgressBar()
            end
        end
    })
    MobileButtons = Fly:CreateToggle({
        Name = "Mobile Buttons",
        Visible = false,
        Tooltip = 'puts up n down buttons on ur screen gng',
        Function = function() 
            if Fly.Enabled then
                Fly:Toggle()
                Fly:Toggle()
            end
        end
    })

    task.defer(function()
        if BarColor and BarColor.Object then
            BarColor.Object.Visible = FlyAnywayProgressBar.Enabled
        end
        if MobileButtons and MobileButtons.Object then
            MobileButtons.Object.Visible = inputService.TouchEnabled
        end
    end)
end)
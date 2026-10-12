run(function()
    if isMobile then
        local AutoClicker
        local CPS
        local BlockCPS = {}
        local Thread

        local function getSafeCPS()
            if store.hand and store.hand.toolType == 'block' and BlockCPS and BlockCPS.GetRandomValue then
                return BlockCPS
            end
            if CPS and CPS.GetRandomValue then
                return CPS
            end
            return nil
        end

        local function AutoClick()
            if Thread then
                task.cancel(Thread)
                Thread = nil
            end

            local initialCPS = getSafeCPS()
            if not initialCPS then return end

            Thread = task.delay(1 / initialCPS.GetRandomValue(), function()
                repeat
                    if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
                        local blockPlacer = bedwars.BlockPlacementController and bedwars.BlockPlacementController.blockPlacer
                        local toolType = store.hand and store.hand.toolType

                        if toolType == 'block' and blockPlacer then
                            task.spawn(function()
                                blockPlacer:autoBridge(workspace:GetServerTimeNow() - bedwars.KnockbackController:getLastKnockbackTime() >= 0.2)
                            end)
                        elseif toolType == 'sword' then
                            bedwars.SwordController:swingSwordAtMouse(0.39)
                        end
                    end

                    local currentCPS = getSafeCPS()
                    if not currentCPS then
                        task.wait(0.1)
                    else
                        task.wait(1 / currentCPS.GetRandomValue())
                    end
                until not AutoClicker.Enabled
            end)
        end

        local function StopClick()
            if Thread then
                task.cancel(Thread)
                Thread = nil
            end
        end

        AutoClicker = vape.Categories.Combat:CreateModule({
            Name = 'AutoClicker',
            Function = function(callback)
                if callback then
                    AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            AutoClick()
                        end
                    end))

                    AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            StopClick()
                        end
                    end))

                    for _, v in {'2', '5'} do
                        pcall(function()
                            AutoClicker:Clean(lplr.PlayerGui.MobileUI[v].MouseButton1Down:Connect(AutoClick))
                            AutoClicker:Clean(lplr.PlayerGui.MobileUI[v].MouseButton1Up:Connect(StopClick))
                        end)
                    end
                else
                    StopClick()
                end
            end,
            Tooltip = 'clicks for you'
        })

        CPS = AutoClicker:CreateTwoSlider({
            Name = 'CPS',
            Min = 1,
            Max = 9,
            DefaultMin = 7,
            DefaultMax = 7
        })

        AutoClicker:CreateToggle({
            Name = 'Place Blocks',
            Default = true,
            Function = function(callback)
                if BlockCPS.Object then
                    BlockCPS.Object.Visible = callback
                end
            end
        })

        BlockCPS = AutoClicker:CreateTwoSlider({
            Name = 'Block CPS',
            Min = 1,
            Max = 20,
            DefaultMin = 12,
            DefaultMax = 12,
            Darker = true
        })

        task.defer(function()
            if BlockCPS and BlockCPS.Object then
                BlockCPS.Object.Visible = PlaceBlocksToggle and PlaceBlocksToggle.Enabled
            end
        end)

    else
        local AutoClicker
        local CPS
        local BlockCPS = {}
        local SwordCPS = {}
        local PlaceBlocksToggle
        local SwingSwordToggle
        local Thread

        local task_wait = task.wait
        local task_spawn = task.spawn
        local workspace_GetServerTimeNow = function() return workspace:GetServerTimeNow() end

        local function getSafeCPS()
            local toolType = store.hand and store.hand.toolType or nil
            if toolType == 'block' and PlaceBlocksToggle and PlaceBlocksToggle.Enabled and BlockCPS and BlockCPS.GetRandomValue then
                return BlockCPS
            elseif toolType == 'sword' and SwingSwordToggle and SwingSwordToggle.Enabled and SwordCPS and SwordCPS.GetRandomValue then
                return SwordCPS
            elseif CPS and CPS.GetRandomValue then
                return CPS
            end
            return nil
        end

        local function AutoClickskid()
            if Thread then task.cancel(Thread) end
            Thread = task_spawn(function()
                repeat
                    if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
                        local toolType = store.hand and store.hand.toolType
                        if PlaceBlocksToggle.Enabled and toolType == 'block' then
                            local blockPlacer = bedwars.BlockPlacementController and bedwars.BlockPlacementController.blockPlacer
                            if blockPlacer then
                                if (workspace_GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / 12) * 0.5) then
                                    local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
                                    if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
                                        task_spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
                                    end
                                end
                            end
                        elseif SwingSwordToggle.Enabled and toolType == 'sword' then
                            bedwars.SwordController:swingSwordAtMouse(0.39)
                        end
                    end

                    local currentCPS = getSafeCPS()
                    task_wait(1 / (currentCPS and currentCPS.GetRandomValue() or 7))
                until not AutoClicker.Enabled
            end)
        end

        local function StopAutoClick()
            if Thread then
                task.cancel(Thread)
                Thread = nil
            end
        end

        local MIN_HOLD_TIME = 0.12
        local ActivationScheduled = nil

        AutoClicker = vape.Categories.Combat:CreateModule({
            Name = 'AutoClicker',
            Function = function(callback)
                if callback then
                    AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            ActivationScheduled = task.delay(MIN_HOLD_TIME, function()
                                ActivationScheduled = nil
                                if inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                                    AutoClickskid()
                                end
                            end)
                        end
                    end))
                    AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            if ActivationScheduled then
                                task.cancel(ActivationScheduled)
                                ActivationScheduled = nil
                            end
                            if Thread then
                                task.cancel(Thread)
                                Thread = nil
                            end
                        end
                    end))
                else
                    StopAutoClick()
                end
            end,
            Tooltip = 'clicks for you'
        })

        PlaceBlocksToggle = AutoClicker:CreateToggle({
            Name = 'Place Blocks',
            Default = false,
            Function = function(callback)
                task.defer(function()
                    if BlockCPS and BlockCPS.Object then BlockCPS.Object.Visible = callback end
                end)
            end
        })

        BlockCPS = AutoClicker:CreateTwoSlider({
            Name = 'Block CPS',
            Min = 1,
            Max = 20,
            DefaultMin = 12,
            DefaultMax = 12,
            Darker = true
        })

        SwingSwordToggle = AutoClicker:CreateToggle({
            Name = 'Swing Sword',
            Default = false,
            Function = function(callback)
                if SwordCPS.Object then SwordCPS.Object.Visible = callback end
            end
        })

        SwordCPS = AutoClicker:CreateTwoSlider({
            Name = 'Sword CPS',
            Min = 1,
            Max = 9,
            DefaultMin = 7,
            DefaultMax = 7,
            Darker = true
        })

        task.defer(function()
            if BlockCPS and BlockCPS.Object then
                BlockCPS.Object.Visible = PlaceBlocksToggle and PlaceBlocksToggle.Enabled
            end
            if SwordCPS and SwordCPS.Object then
                SwordCPS.Object.Visible = SwingSwordToggle and SwingSwordToggle.Enabled
            end
        end)
    end
end)
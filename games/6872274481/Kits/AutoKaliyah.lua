run(function()
    local Kaliyah
    local AutoPunch
    local RangeSlider
    local Stacks
    local PunchDelay
    local DelaySlider
    local NoSlow
    local punchActive = false
    local punchDebounce = {}

    local function getKaliyahTargets()
        local targets = {}
        if not entitylib.isAlive then return targets end
        
        local localPosition = entitylib.character.RootPart.Position
        local range = RangeSlider.Value
        
        if store.equippedKit ~= 'dragon_slayer' then return targets end
        if not bedwars.DragonSlayerController or not bedwars.DragonSlayerController.dragonEmblems then return targets end
        local minStacks = Stacks.Value
        for model, emblem in bedwars.DragonSlayerController.dragonEmblems do
            if emblem.stackCount >= minStacks and model.PrimaryPart then
                local distance = (localPosition - model.PrimaryPart.Position).Magnitude
                if distance <= range then
                    table.insert(targets, model)
                end
            end
        end
        table.sort(targets, function(a, b)
            return (localPosition - a.PrimaryPart.Position).Magnitude < (localPosition - b.PrimaryPart.Position).Magnitude
        end)
        
        return targets
    end

    local function punchTarget(target)
        if not target.PrimaryPart then return false end
        if not bedwars.AbilityController or not bedwars.AbilityController:canUseAbility('dragon_slayer_punch', {disableBlockedAbilityAlert = true}) then return false end
        local targetId = target
        
        if punchDebounce[targetId] then return false end
        punchDebounce[targetId] = true
        
        local character = lplr.Character
        if not character or not character.PrimaryPart then 
            punchDebounce[targetId] = nil
            return false 
        end
        
        local playerPos = character:GetPivot().Position
        local targetPos = target.PrimaryPart.Position * Vector3.new(1, 0, 1) + Vector3.new(0, playerPos.Y, 0)
        local lookAtCFrame = CFrame.new(playerPos, targetPos)
        
        character:PivotTo(lookAtCFrame)
        
        pcall(function()
            bedwars.DragonSlayerController:playPunchAnimation(lookAtCFrame - lookAtCFrame.Position)
        end)
        
        local success = pcall(function()
            replicatedStorage:WaitForChild('events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'):WaitForChild('useAbility'):FireServer('dragon_slayer_punch')
        end)
        
        task.delay(0.4, function()
            punchDebounce[targetId] = nil
        end)
        
        return success
    end

    local function startAutoPunch()
        if punchActive then return end
        punchActive = true
        
        task.spawn(function()
            while Kaliyah.Enabled and AutoPunch.Enabled and punchActive do
                if not entitylib.isAlive then 
                    task.wait(0.5)
                    continue 
                end
                
                local targets = getKaliyahTargets()
                local punchedThisCycle = false
                
                for _, target in targets do
                    if not Kaliyah.Enabled or not AutoPunch.Enabled or not punchActive then 
                        break 
                    end
                    
                    if PunchDelay.Enabled and DelaySlider.Value > 0 then
                        task.wait(DelaySlider.Value)
                    end
                    
                    if punchTarget(target) then
                        punchedThisCycle = true
                        task.wait(0.2)
                    end
                end
                
                task.wait(punchedThisCycle and 0.15 or 0.1)
            end
            
            punchActive = false
        end)
    end

    local function stopAutoPunch()
        punchActive = false
        table.clear(punchDebounce)
    end

    local originalPlayPunchAnimation
    local function hookNoSlow()
        if not bedwars.DragonSlayerController then return end
        
        originalPlayPunchAnimation = bedwars.DragonSlayerController.playPunchAnimation
        
        bedwars.DragonSlayerController.playPunchAnimation = function(self, arg2)
            if NoSlow.Enabled then
                local any_import_result1_6_upvr = debug.getupvalue(originalPlayPunchAnimation, 1)
                local GameAnimationUtil_upvr = debug.getupvalue(originalPlayPunchAnimation, 2)
                local Players_upvr = debug.getupvalue(originalPlayPunchAnimation, 3)
                local AnimationType_upvr = debug.getupvalue(originalPlayPunchAnimation, 4)
                local KnitClient_upvr = debug.getupvalue(originalPlayPunchAnimation, 5)
                local RunService_upvr = debug.getupvalue(originalPlayPunchAnimation, 6)
                
                local any_new_result1_upvr_2 = any_import_result1_6_upvr.new()
                local any_playAnimation_result1_upvr_2 = GameAnimationUtil_upvr:playAnimation(Players_upvr.LocalPlayer, AnimationType_upvr.DRAGON_SLAYER_PUNCH)
                any_new_result1_upvr_2:GiveTask(function()
                    local var137 = any_playAnimation_result1_upvr_2
                    if var137 ~= nil then
                        var137:Stop()
                    end
                end)
                
                any_new_result1_upvr_2:GiveTask(RunService_upvr.Heartbeat:Connect(function()
                    local Character = Players_upvr.LocalPlayer.Character
                    local var141 = Character
                    if var141 ~= nil then
                        var141 = var141.PrimaryPart
                    end
                    if not var141 then
                        any_new_result1_upvr_2:DoCleaning()
                        return nil
                    end
                    Character:PivotTo(CFrame.new(Character:GetPrimaryPartCFrame().Position) * arg2)
                end))
                
                task.delay(0.46, function()
                    any_new_result1_upvr_2:DoCleaning()
                end)
                
                return any_new_result1_upvr_2
            else
                return originalPlayPunchAnimation(self, arg2)
            end
        end
    end

    local function unhookNoSlow()
        if originalPlayPunchAnimation and bedwars.DragonSlayerController then
            bedwars.DragonSlayerController.playPunchAnimation = originalPlayPunchAnimation
        end
    end

    Kaliyah = vape.Categories.Kits:CreateModule({
        Name = 'AutoKaliyah',
        Function = function(callback)
            if callback then
                if AutoPunch.Enabled then
                    startAutoPunch()
                end
                if NoSlow.Enabled then
                    hookNoSlow()
                end
            else
                stopAutoPunch()
                unhookNoSlow()
            end
        end,
        Tooltip = 'autokit with more features lmao'
    })
    
    AutoPunch = Kaliyah:CreateToggle({
        Name = 'Auto Punch',
        Default = false,
        Function = function(callback)
            if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = callback end
            if PunchDelay and PunchDelay.Object then PunchDelay.Object.Visible = callback end
            if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = (callback and PunchDelay.Enabled) end
            if not callback then
                if DelaySlider and DelaySlider.Object then
                    DelaySlider.Object.Visible = false
                end
            else
                if PunchDelay and PunchDelay.Enabled then
                    if DelaySlider and DelaySlider.Object then
                        DelaySlider.Object.Visible = true
                    end
                end
            end
            
            if Kaliyah.Enabled then
                if callback then
                    startAutoPunch()
                else
                    stopAutoPunch()
                end
            end
        end
    })
    
    RangeSlider = Kaliyah:CreateSlider({
        Name = 'Range',
        Min = 1, 
        Max = 18,
        Default = 18,
        Decimal = 1,
        Suffix = ' studs',
    })
    
    Stacks = Kaliyah:CreateSlider({
        Name = 'Stacks',
        Min = 1,
        Max = 3,
        Default = 3,
        Suffix = function(val)
            return val <= 1 and ' stack' or ' stacks'
        end,
        Tooltip = 'how many emblems gotta be on em before ts punches'
    })
    
    PunchDelay = Kaliyah:CreateToggle({
        Name = 'Punch Delay',
        Default = false,
        Function = function(callback)
            if DelaySlider and DelaySlider.Object then
                DelaySlider.Object.Visible = callback
            end
        end
    })
    
    DelaySlider = Kaliyah:CreateSlider({
        Name = 'Delay',
        Min = 1,
        Max = 3,
        Default = 1,
        Decimal = 10,
        Suffix = 's',
    })
    
    NoSlow = Kaliyah:CreateToggle({
        Name = 'No Slow',
        Default = false,
        Function = function(callback)
            if Kaliyah.Enabled then
                if callback then
                    hookNoSlow()
                else
                    unhookNoSlow()
                end
            end
        end
    })

    task.defer(function()
        if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = false end
        if PunchDelay and PunchDelay.Object then PunchDelay.Object.Visible = false end
        if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = false end
    end)
end)
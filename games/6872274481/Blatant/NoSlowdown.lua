run(function()
	local NoSlowDown
    local old
    local SophiaCheck
    local FROZEN_THRESHOLD = 10
    local cachedModifier = nil
    local nsHooked = false
    local origPunch = nil
    local origGroveDisable = nil

    local function hookKitNoSlow()
        if bedwars.DragonSlayerController and not origPunch then
            origPunch = bedwars.DragonSlayerController.playPunchAnimation
            bedwars.DragonSlayerController.playPunchAnimation = function(self, arg2)
                local ok, maid = pcall(function()
                    local imp = debug.getupvalue(origPunch, 1)
                    local anim = debug.getupvalue(origPunch, 2)
                    local plrs = debug.getupvalue(origPunch, 3)
                    local atype = debug.getupvalue(origPunch, 4)
                    local rs = debug.getupvalue(origPunch, 6)
                    local m = imp.new()
                    local track = anim:playAnimation(plrs.LocalPlayer, atype.DRAGON_SLAYER_PUNCH)
                    m:GiveTask(function()
                        if track then track:Stop() end
                    end)
                    m:GiveTask(rs.Heartbeat:Connect(function()
                        local char = plrs.LocalPlayer.Character
                        if not char or not char.PrimaryPart then
                            m:DoCleaning()
                            return
                        end
                        char:PivotTo(CFrame.new(char:GetPrimaryPartCFrame().Position) * arg2)
                    end))
                    task.delay(0.46, function() m:DoCleaning() end)
                    return m
                end)
                if ok and maid then return maid end
                return origPunch(self, arg2)
            end
        end

        if bedwars.SpiritGardenerController and not origGroveDisable then
            origGroveDisable = bedwars.SpiritGardenerController.disableActionsOnCharge
            bedwars.SpiritGardenerController.disableActionsOnCharge = function(self, maid, character)
                if character ~= lplr.Character then
                    return origGroveDisable(self, maid, character)
                end
                local ok = pcall(function()
                    local KnitClient = bedwars.KnitClient
                    KnitClient.Controllers.SwordController:toggleSwordSwing(true)
                    KnitClient.Controllers.BlockPlacementController:disableBlockPlacer()
                    local ClientSyncEvents = debug.getupvalue(origGroveDisable, 3)
                    local projConn = ClientSyncEvents.BeginProjectileTargeting:connect(function(event)
                        event:setCancelled(true)
                    end)
                    local jumpMod = KnitClient.Controllers.JumpHeightController:getJumpModifier():addModifier({
                        jumpHeightMultiplier = 0
                    })
                    maid:GiveTask(function()
                        KnitClient.Controllers.SwordController:toggleSwordSwing(false)
                        KnitClient.Controllers.BlockPlacementController:enableBlockPlacer()
                        projConn:Destroy()
                        jumpMod.Destroy()
                    end)
                end)
                if not ok then
                    return origGroveDisable(self, maid, character)
                end
            end
        end
    end

    local function unhookKitNoSlow()
        if origPunch and bedwars.DragonSlayerController then
            bedwars.DragonSlayerController.playPunchAnimation = origPunch
        end
        origPunch = nil
        if origGroveDisable and bedwars.SpiritGardenerController then
            bedwars.SpiritGardenerController.disableActionsOnCharge = origGroveDisable
        end
        origGroveDisable = nil
    end
    NoSlowdown = vape.Categories.Blatant:CreateModule({
        Name = 'NoSlowdown',
        Function = function(callback)
            if not cachedModifier then
                if not bedwars.SprintController then return end
                cachedModifier = bedwars.SprintController:getMovementStatusModifier()
            end
            local modifier = cachedModifier
            if callback then
                if nsHooked then return end
                hookKitNoSlow()
                old = modifier.addModifier
                if not old then return end
                local orig = old

                local function removeSlow(tab)
                    if type(tab) ~= 'table' then
                        return false, false
                    end

                    local changed = false
                    local unblocked = false

                    local move = tonumber(tab.moveSpeedMultiplier)
                    local constant = tonumber(tab.constantSpeedMultiplier)

                    if move and move < 1 then
                        tab.moveSpeedMultiplier = 1
                        changed = true
                    end

                    if constant and constant < 1 then
                        tab.constantSpeedMultiplier = 1
                        changed = true
                    end

                    if tab.blockSprint == true and not (constant and constant > 1) then
                        tab.blockSprint = false
                        changed = true
                        unblocked = true
                    end

                    return changed, unblocked
                end

                nsHooked = true
                modifier.addModifier = function(self, tab)
                    if not orig then return end

                    if SophiaCheck and SophiaCheck.Enabled and isFrozen(nil, FROZEN_THRESHOLD) then
                        return orig(self, tab)
                    end

                    removeSlow(tab)
                    return orig(self, tab)
                end

                local changed = false
                local unblocked = false

                for i, v in modifier.modifiers do
                    local mod = type(v) == 'table' and v or (type(i) == 'table' and i or nil)

                    if mod then
                        local didChange, didUnblock = removeSlow(mod)

                        if didChange then
                            changed = true
                        end

                        if didUnblock then
                            unblocked = true
                        end
                    end
                end

                if changed and modifier.updateModifiers then
                    modifier:updateModifiers()
                end

                if unblocked
                    and entitylib.isAlive
                    and entitylib.character.Humanoid.MoveDirection.Magnitude > 0 then

                    pcall(function()
                        bedwars.SprintController:startSprinting()
                    end)
                end

                NoSlowdown:Clean(runService.PreSimulation:Connect(function()
                    if not NoSlowdown.Enabled or not cachedModifier then
                        return
                    end

                    if SophiaCheck and SophiaCheck.Enabled and isFrozen(nil, FROZEN_THRESHOLD) then
                        return
                    end

                    local updated = false
                    local resumeSprint = false

                    for i, v in cachedModifier.modifiers do
                        local mod = type(v) == 'table' and v or (type(i) == 'table' and i or nil)

                        if mod then
                            local didChange, didUnblock = removeSlow(mod)

                            if didChange then
                                updated = true
                            end

                            if didUnblock then
                                resumeSprint = true
                            end
                        end
                    end

                    if updated and cachedModifier.updateModifiers then
                        cachedModifier:updateModifiers()
                    end

                    if resumeSprint
                        and entitylib.isAlive
                        and entitylib.character.Humanoid.MoveDirection.Magnitude > 0 then

                        pcall(function()
                            bedwars.SprintController:startSprinting()
                        end)
                    end
                end))
            else
                unhookKitNoSlow()
                if cachedModifier then
                    cachedModifier.addModifier = old
                    cachedModifier = nil
                end
                old = nil
                nsHooked = false
            end
        end,
        Tooltip = 'prevents slowing down when using items.'
    })

    SophiaCheck = NoSlowdown:CreateToggle({
        Name = 'Sophia Check',
        Default = false
    })
end)
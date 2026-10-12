run(function()
    local autoZenoModule
    local targetSettings
    local targetSelectionMode
    local itemLimitToggle
    local shockwaveToggle
    local shockwaveRadius
    local lightningStrikeToggle
    local lightningStormToggle
    local attackRange
    local actionDelay

    local function fetchAttackItem()
        if itemLimitToggle.Enabled then
            local wizardStaff = (store.hand.tool and store.hand.tool.Name:find('wizard_staff')) and store.hand.tool or nil
            return wizardStaff, wizardStaff and getHotbar(wizardStaff) or nil, wizardStaff and (tonumber(wizardStaff.Name:sub(#wizardStaff.Name, #wizardStaff.Name)) or 1) or nil
        end

        if store.hand.tool and store.hand.tool.Name:find('wizard_staff') then
            local item = store.hand.tool
            return item, getHotbar(item), tonumber(item.Name:sub(#item.Name, #item.Name)) or 1
        end

        for index, item in pairs(store.inventory.inventory.items) do
            if item.itemType:find('wizard_staff') then
                switchItem(item, 0)
                return item, index, tonumber(item.itemType:sub(#item.itemType, #item.itemType)) or 1
            end
        end

        return nil
    end

    autoZenoModule = vape.Categories.Kits:CreateModule({
        Name = 'AutoZeno',
        Function = function(callback)
            if callback then
                repeat
                    if entitylib.isAlive then
                        local staff, _, level = fetchAttackItem()

                        if staff then
                            local playerPosition = entitylib.character.RootPart.Position
                            local nearestEntity = entitylib.EntityPosition({
                                Origin = playerPosition,
                                Range = (attackRange.Value < 6 and shockwaveToggle.Enabled and 7) or attackRange.Value,
                                Part = 'RootPart',
                                Players = targetSettings.Players.Enabled,
                                NPCs = targetSettings.NPCs.Enabled,
                                Sort = sortmethods[targetSelectionMode.Value]
                            })

                            if nearestEntity then
                                if shockwaveToggle.Enabled and level > 2 then
                                    if bedwars.AbilityController:canUseAbility('SHOCKWAVE') and (playerPosition - nearestEntity.RootPart.Position).Magnitude <= shockwaveRadius.Value then
                                        bedwars.AbilityController:useAbility('SHOCKWAVE', newproxy(true), {
                                            target = CFrame.lookAt(playerPosition, nearestEntity.RootPart.Position).LookVector
                                        })
                                        task.wait(actionDelay.Value)
                                    end
                                end

                                if lightningStrikeToggle.Enabled and bedwars.AbilityController:canUseAbility('LIGHTNING_STRIKE') then
                                    bedwars.AbilityController:useAbility('LIGHTNING_STRIKE', newproxy(true), {
                                        target = nearestEntity.RootPart.Position + ((nearestEntity.Humanoid.MoveDirection or Vector3.zero) * (1 + lplr:GetNetworkPing()))
                                    })
                                    task.wait(actionDelay.Value)
                                end

                                if lightningStormToggle.Enabled and level > 1 then
                                    if bedwars.AbilityController:canUseAbility('LIGHTNING_STORM') then
                                        bedwars.AbilityController:useAbility('LIGHTNING_STORM', newproxy(true), {
                                            target = nearestEntity.RootPart.Position + ((nearestEntity.Humanoid.MoveDirection or Vector3.zero) * (1 + lplr:GetNetworkPing()))
                                        })
                                        task.wait(actionDelay.Value)
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                until not autoZenoModule.Enabled
            end
        end,
    })

    targetSettings = autoZenoModule:CreateTargets({
        Players = true,
        NPCs = false
    })

    local availableSortingMethods = {'Damage', 'Distance'}
    for method in sortmethods do
        if not table.find(availableSortingMethods, method) then
            table.insert(availableSortingMethods, method)
        end
    end

    targetSelectionMode = autoZenoModule:CreateDropdown({
        Name = 'Target Mode',
        List = availableSortingMethods,
        Default = 'Distance'
    })

    itemLimitToggle = autoZenoModule:CreateToggle({
        Name = 'Limit to item',
        Default = true
    })

    lightningStrikeToggle = autoZenoModule:CreateToggle({
        Name = 'Use Lightning Strike',
        Default = true
    })

    lightningStormToggle = autoZenoModule:CreateToggle({
        Name = 'Use Lightning Storm'
    })

    shockwaveRadius = autoZenoModule:CreateSlider({
        Name = 'Shockwave Range',
        Visible = false,
        Darker = true,
        Min = 1,
        Max = 12,
        Suffix = function(value)
            return value > 1 and 'studs' or 'stud'
        end,
        Decimal = 5,
        Default = 12
    })

    shockwaveToggle = autoZenoModule:CreateToggle({
        Name = 'Auto Shockwave',
        Function = function(enabled)
            pcall(function()
                shockwaveRadius.Object.Visible = enabled
            end)
        end
    })

    attackRange = autoZenoModule:CreateSlider({
        Name = 'Attack Range',
        Min = 1,
        Max = 60,
        Default = 35,
        Suffix = function(value)
            return value > 1 and 'studs' or 'stud'
        end,
        Decimal = 5
    })

    actionDelay = autoZenoModule:CreateSlider({
        Name = 'Delay',
        Min = 0,
        Max = 10,
        Default = 0.5,
        Decimal = 5,
        Suffix = function(value)
            return value > 1 and 'secs' or 'sec'
        end
    })
end)
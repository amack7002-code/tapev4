run(function()
    local AutoUma
    local rangeSlider
    local limitToStaff
    local playAnim
    local autoSummon
    local useHeal
    local useAttack
    local targetDrops
    local allowDiamond
    local allowEmerald

    local function findStaff()
        if limitToStaff.Enabled then
            local held = store.hand.tool
            if held and held.Name == 'spirit_staff' then
                return held, getHotbar(held)
            end
            return nil
        end

        for slot, item in pairs(store.inventory.inventory.items) do
            if item.itemType == 'spirit_staff' then
                switchItem(item, 0)
                return item, slot
            end
        end
    end

    local function getClosestDrop(origin, drops)
        local closest, shortest = nil, rangeSlider.Value + 1

        for _, drop in pairs(drops) do
            local valid = (drop.Name == 'emerald' and allowEmerald.Enabled) or (drop.Name == 'diamond' and allowDiamond.Enabled)

            if valid then
                local dist = (origin - drop.Position).Magnitude

                if dist <= shortest and not entitylib.Wallcheck(origin, drop.Position, {gameCamera, lplr.Character, drop}) then
                    closest = drop
                    shortest = dist
                end
            end
        end

        return closest
    end

    local function fireSpirit(staff, origin, targetPos, hasAttackSpirit)
        local shootFrom = origin + Vector3.new(0, 2, 0)

        local predicted = targetPos + Vector3.new(0,(origin - targetPos).Magnitude / 5, 0)

        local direction = CFrame.lookAt(origin, predicted).LookVector * 100

        local _spiritRemote = bedwars.Client:Get(remotes.FireProjectile).instance
        if _spiritRemote then
            _spiritRemote:InvokeServer(staff, nil, hasAttackSpirit and 'attack_spirit' or 'heal_spirit',shootFrom,origin,direction,httpService:GenerateGUID(),{drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)},workspace:GetServerTimeNow() - 0.045)
        end

        if playAnim.Enabled then
            bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.WIZARD_BALL_CAST )
            bedwars.SoundManager:playSound(bedwars.SoundList.SPIRIT_SUMMONER_CHANGE_AFFINITY,{})
        end
    end

	AutoUma = vape.Categories.Kits:CreateModule({
        Name = 'AutoUma',
        Tooltip = 'auto uses spirit staff usage for drops',
        Function = function(enabled)
            if not enabled then return end
            repeat
                local drops = collection('ItemDrop', AutoUma)
                local staff = findStaff()

                if staff and targetDrops.Enabled then
                    local atkCount = lplr:GetAttribute('ReadySummonedAttackSpirits') or 0
                    local healCount = lplr:GetAttribute('ReadySummonedHealSpirits') or 0

                    if autoSummon.Enabled and getItem('summon_stone') then
                        if useAttack.Enabled and atkCount < 1 then
                            bedwars.AbilityController:useAbility('summon_attack_spirit')
                        end

                        if useHeal.Enabled and healCount < 1 then
                            bedwars.AbilityController:useAbility('summon_heal_spirit')
                        end
                    end

                    if (atkCount + healCount) > 0 then
                        local root = entitylib.character.RootPart
                        if root then
                            local pos = root.Position
                            local target = getClosestDrop(pos, drops)

                            if target then
                                fireSpirit(staff, pos, target.Position, atkCount > 0)
                                task.wait(1.5)
                            end
                        end
                    end
                end

                task.wait(0.1)
            until not AutoUma.Enabled
        end
    })

    rangeSlider = AutoUma:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 80,
        Default = 50,
        Decimal = 5,
        Suffix = function(v)
            return v == 1 and 'stud' or 'studs'
        end
    })

    playAnim = AutoUma:CreateToggle({
        Name = 'Play Animation',
        Default = true
    })

    limitToStaff = AutoUma:CreateToggle({
        Name = 'Only When Holding Staff',
        Default = true
    })

    autoSummon = AutoUma:CreateToggle({
        Name = 'Auto Summon',
        Function = function(state)
            pcall(function()
                useAttack.Object.Visible = state
                useHeal.Object.Visible = state
            end)
        end
    })

    useHeal = AutoUma:CreateToggle({
        Name = 'Heal Spirit',
        Default = true,
        Visible = false,
        Darker = true
    })

    useAttack = AutoUma:CreateToggle({
        Name = 'Attack Spirit',
        Default = true,
        Visible = false,
        Darker = true
    })

    targetDrops = AutoUma:CreateToggle({
        Name = 'Target Drops',
        Default = true,
        Function = function(state)
            pcall(function()
                allowEmerald.Object.Visible = state
                allowDiamond.Object.Visible = state
            end)
        end
    })

    allowEmerald = AutoUma:CreateToggle({
        Name = 'Emerald',
        Default = true,
        Darker = true
    })

    allowDiamond = AutoUma:CreateToggle({
        Name = 'Diamond',
        Default = true,
        Darker = true
    })
end)
run(function()
    local AutoHeph
    local AutoRepair
    local AttackOnRepair
    local RepairAt

    local COOLDOWN = 6
    local ABILITY_NAMES = {
        'hephaestus_self_repair', 'tinker_self_repair',
        'hephaestus_repair', 'tinker_repair',
        'HEPHAESTUS_SELF_REPAIR', 'TINKER_SELF_REPAIR',
        'HEPHAESTUS_REPAIR', 'TINKER_REPAIR',
        'self_repair', 'SELF_REPAIR',
        'shield_repair', 'SHIELD_REPAIR',
        'kit_repair', 'KIT_REPAIR',
        'forge_repair', 'FORGE_REPAIR',
    }

    local repairingUntil = 0

    local function getKitShield(char)
        local best = 0
        for name, val in char:GetAttributes() do
            if name:find('Shield') and type(val) == 'number' and val > best and name ~= 'Shield_POTION' and name ~= 'TotalShield' then
                best = val
            end
        end
        return best
    end

    local function discoverRepairAbilities()
        local found = {}
        pcall(function()
            local ac = bedwars.AbilityController
            for _, v in next, ac do
                if type(v) ~= 'table' then continue end
                for k in next, v do
                    if type(k) == 'string' and k:lower():find('repair') and not table.find(found, k) then
                        table.insert(found, k)
                    end
                end
            end
            for _, fn in {ac.canUseAbility, ac.useAbility, ac.getAbilityCooldown, ac.registerAbility} do
                if type(fn) ~= 'function' then continue end
                for i = 1, 40 do
                    local ok, _, val = pcall(debug.getupvalue, fn, i)
                    if not ok then break end
                    if type(val) ~= 'table' then continue end
                    for k in next, val do
                        if type(k) == 'string' and k:lower():find('repair') and not table.find(found, k) then
                            table.insert(found, k)
                        end
                    end
                end
            end
        end)
        return found
    end

    local function getCharAbilityName()
        local char = lplr.Character
        if char then
            for _, obj in {char, lplr} do
                for attrName, attrVal in obj:GetAttributes() do
                    if type(attrVal) == 'string' and attrVal:lower():find('repair') then
                        return attrVal
                    end
                end
            end
        end
        return nil
    end

    local function fireRepair()
        local ac = bedwars.AbilityController
        local names = discoverRepairAbilities()
        local charAbility = getCharAbilityName()
        if charAbility and not table.find(names, charAbility) then
            table.insert(names, 1, charAbility)
        end
        for _, n in ABILITY_NAMES do
            if not table.find(names, n) then table.insert(names, n) end
        end
        for _, name in names do
            local ok, canUse = pcall(function() return ac:canUseAbility(name) end)
            if ok and canUse then
                pcall(function() ac:useAbility(name) end)
                return true
            end
        end
        return false
    end

    local weaponConfig = nil
    pcall(function()
        local swc = bedwars.SwordController
        for _, fn in {swc.sendServerRequest, swc.swingSwordAtMouse, swc.swingSwordInRegion, swc.isClickingTooFast} do
            if type(fn) ~= 'function' then continue end
            for i = 1, 40 do
                local ok2, weapon, ok3
                local ok, _, val = pcall(debug.getupvalue, fn, i)
                if not ok then break end
                if type(val) ~= 'table' then continue end
                ok2, weapon = pcall(function() return val.Weapon end)
                if not ok2 or type(weapon) ~= 'table' then continue end
                ok3 = pcall(function() return weapon.respectAttackOverride end)
                if ok3 then weaponConfig = val return end
            end
        end
    end)

    local oldIsClickingTooFast = bedwars.SwordController.isClickingTooFast
    local syncConn = nil
    local stunConn = nil
    local charConn = nil

    local function attackUnlocked()
        if not AttackOnRepair or not AttackOnRepair.Enabled then return false end
        return tick() < repairingUntil
    end

    local function connectStunClear(char)
        if stunConn then stunConn:Disconnect() stunConn = nil end
        if not char then return end
        stunConn = char:GetAttributeChangedSignal('StunnedUntilTime'):Connect(function()
            if not attackUnlocked() then return end
            local val = char:GetAttribute('StunnedUntilTime')
            if val and val > workspace:GetServerTimeNow() then
                pcall(function() char:SetAttribute('StunnedUntilTime', 0) end)
            end
        end)
    end

    AutoHeph = vape.Categories.Kits:CreateModule({
        Name = 'AutoHeph',
        Function = function(callback)
            if callback then
                repairingUntil = 0

                bedwars.SwordController.isClickingTooFast = function(self, ...)
                    if attackUnlocked() then
                        if weaponConfig then
                            pcall(function() weaponConfig.Weapon.respectAttackOverride = false end)
                        end
                        return false
                    end
                    return oldIsClickingTooFast(self, ...)
                end

                connectStunClear(lplr.Character)
                charConn = lplr.CharacterAdded:Connect(function(char)
                    connectStunClear(char)
                end)

                pcall(function()
                    local sync = bedwars.ClientSync
                    if sync and type(sync.SwordSwing) == 'table' and type(sync.SwordSwing.setPriority) == 'function' then
                        syncConn = sync.SwordSwing:setPriority(1):Connect(function()
                            if attackUnlocked() and weaponConfig then
                                pcall(function() weaponConfig.Weapon.respectAttackOverride = false end)
                            end
                        end)
                    end
                end)

                local maxShield = 0
                local lastFired = 0
                local prevAlive = false
                local stableVal = -1
                local stableCount = 0

                repeat
                    local alive, char, current, now, cooldownLeft, needsRepair, healPoint
                    task.wait(0.1)

                    if not AutoRepair or not AutoRepair.Enabled then
                        prevAlive = false
                        continue
                    end

                    alive = entitylib.isAlive
                    if not alive then
                        maxShield = 0
                        lastFired = 0
                        prevAlive = false
                        continue
                    end

                    char = lplr.Character
                    if not char then continue end

                    current = getKitShield(char)

                    if current == stableVal then
                        stableCount = stableCount + 1
                    else
                        stableVal = current
                        stableCount = 1
                    end

                    if not prevAlive and current > 0 then
                        maxShield = current
                    elseif stableCount >= 2 and current > maxShield then
                        maxShield = current
                    end
                    prevAlive = true

                    now = tick()
                    cooldownLeft = math.max(0, COOLDOWN - (now - lastFired))
                    healPoint = maxShield * ((RepairAt and RepairAt.Value or 50) / 100)
                    needsRepair = maxShield > 0 and current <= healPoint

                    if cooldownLeft <= 0 and needsRepair then
                        if fireRepair() then
                            repairingUntil = now + 2
                            lastFired = now
                        end
                    end

                until not AutoHeph.Enabled
            else
                repairingUntil = 0
                bedwars.SwordController.isClickingTooFast = oldIsClickingTooFast
                if stunConn then stunConn:Disconnect() stunConn = nil end
                if charConn then charConn:Disconnect() charConn = nil end
                if syncConn then
                    pcall(function() syncConn:Disconnect() end)
                    syncConn = nil
                end
            end
        end,
        Tooltip = 'fixes ur heph shield by itself when it gets low so u dont gotta think about it'
    })

    AutoRepair = AutoHeph:CreateToggle({
        Name = 'Auto Repair',
        Default = true,
        Tooltip = 'turns the auto fixing on. leave this on gng'
    })

    AttackOnRepair = AutoHeph:CreateToggle({
        Name = 'Attack on Repair',
        Default = true,
        Tooltip = 'lets u keep swingin while ur shield is fixing instead of getting frozen'
    })

    RepairAt = AutoHeph:CreateSlider({
        Name = 'repair at',
        Min = 5,
        Max = 95,
        Default = 50,
        Suffix = '%',
        Tooltip = 'fixes ur shield once it drops to this much of its full amount'
    })
end)
run(function()
    local Melody
    local SelfHeal
    local TeammateHeal
    local RangeSlider
    local PlayerDropdown
    local healRunning = false
    local lastHealTime = 0
    local healCooldown = 1

    local function getItem(itemName)
        if not entitylib.isAlive then return false end
        
        local inventory = store.inventory
        if inventory and inventory.inventory and inventory.inventory.hand then
            local handItem = inventory.inventory.hand
            if handItem and handItem.itemType == itemName then
                return true
            end
        end
        return false
    end

    local function getLowestHealthTeammate()
        if not entitylib.isAlive then return nil end

        local localPosition = entitylib.character.RootPart.Position
        local range = RangeSlider.Value
        local picked = PlayerDropdown and PlayerDropdown.Value

        if picked and picked ~= 'None' then
            for _, v in entitylib.List do
                if v.Player and v.Player ~= lplr and v.Player.Name == picked then
                    local distance = (localPosition - v.RootPart.Position).Magnitude
                    if distance <= range and v.Health < v.MaxHealth then
                        return v
                    end
                    return nil
                end
            end
            return nil
        end

        local lowestHp = math.huge
        local targetEntity = nil

        for _, v in entitylib.List do
            if v.Player and v.Player ~= lplr and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') then
                local distance = (localPosition - v.RootPart.Position).Magnitude

                if distance <= range and v.Health < lowestHp and v.Health < v.MaxHealth then
                    lowestHp = v.Health
                    targetEntity = v
                end
            end
        end

        return targetEntity
    end

    local function shouldSelfHeal()
        if not entitylib.isAlive then return false end
        
        local currentHealth = lplr.Character:GetAttribute('Health') or 0
        local maxHealth = lplr.Character:GetAttribute('MaxHealth') or 100
        
        return currentHealth < maxHealth
    end

    local function performHeal(target)
        local currentTime = tick()
        if currentTime - lastHealTime < healCooldown then
            return false
        end
        
        if not getItem('guitar') then
            return false
        end
        
        bedwars.Client:Get(remotes.GuitarHeal):SendToServer({
            healTarget = target
        })
        
        lastHealTime = currentTime
        return true
    end

    local function startHealing()
        healRunning = true
        task.spawn(function()
            while healRunning and Melody.Enabled do
                if not entitylib.isAlive then
                    task.wait(0.1)
                    continue
                end
                
                if not getItem('guitar') then
                    task.wait(0.2)
                    continue
                end
                
                local healed = false
                
                if SelfHeal.Enabled and shouldSelfHeal() then
                    if performHeal(lplr.Character) then
                        healed = true
                    end
                end
                
                if not healed and TeammateHeal.Enabled then
                    local teammate = getLowestHealthTeammate()
                    if teammate then
                        if performHeal(teammate.Character) then
                            healed = true
                        end
                    end
                end
                
                task.wait(0.1)
            end
            healRunning = false
        end)
    end

    Melody = vape.Categories.Kits:CreateModule({
        Name = 'AutoMelody',
        Function = function(callback)
            if callback then
                lastHealTime = 0
                startHealing()
                local function refreshList()
                    if PlayerDropdown and type(PlayerDropdown.SetList) == 'function' then
                        local list = {'None'}
                        for _, name in ipairs(getTeammates(true)) do
                            table.insert(list, name)
                        end
                        PlayerDropdown:SetList(list)
                    end
                end
                refreshList()
                Melody:Clean(playersService.PlayerAdded:Connect(function() task.wait(0.5) refreshList() end))
                Melody:Clean(playersService.PlayerRemoving:Connect(function() task.wait(0.5) refreshList() end))
                Melody:Clean(lplr:GetAttributeChangedSignal('Team'):Connect(function() task.wait(1) refreshList() end))
            else
                healRunning = false
                lastHealTime = 0
            end
        end,
        Tooltip = 'auto heal yourself and teammates with guitar'
    })
    
    SelfHeal = Melody:CreateToggle({
        Name = 'Self Heal',
        Default = true,
    })
    
    TeammateHeal = Melody:CreateToggle({
        Name = 'Teammate Heal',
        Default = true,
        Function = function(callback)
            if RangeSlider and RangeSlider.Object then
                RangeSlider.Object.Visible = callback
            end
        end
    })
    
    RangeSlider = Melody:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 20,
        Default = 20,
        Decimal = 1,
        Suffix = ' studs',
    })

    PlayerDropdown = Melody:CreateDropdown({
        Name = 'Target Teammate',
        List = {'None'},
        Default = 'None',
        Tooltip = 'pick who u wanna heal, None just heals whoevers lowest hp'
    })
end)
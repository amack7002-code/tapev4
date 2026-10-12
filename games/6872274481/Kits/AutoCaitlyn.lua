run(function()
    local Caitlyn
    local MethodDropdown
    local LowHealthSlider
    local ExecuteRangeSlider
    local HitRangeSlider
    local ProximityRangeSlider
    local connections = {}
    local Players = playersService
    local lplr = Players.LocalPlayer
    local currentTarget = nil
    local lastHitTime = 0
    local lastContractSelect = 0
    
    local function selectContract(targetPlayer)
        if not entitylib.isAlive then return false end
        if tick() - lastContractSelect < 0.1 then return false end
        
        local storeState = bedwars.Store:getState()
        local activeContract = storeState.Kit.activeContract
        local availableContracts = storeState.Kit.availableContracts or {}
        
        if activeContract then return false end
        if #availableContracts == 0 then return false end
        
        for _, contract in pairs(availableContracts) do
            if contract.target == targetPlayer then
                bedwars.Client:Get(remotes.BloodAssassinSelectContract):SendToServer({
                    contractId = contract.id
                })
                lastContractSelect = tick()
                return true
            end
        end
        return false
    end
    
    local function executeOnLowHealth()
        if not currentTarget or tick() - lastHitTime > 3 then
            currentTarget = nil
            return
        end
        
        if not currentTarget.Character then return end
        
        local humanoid = currentTarget.Character:FindFirstChild("Humanoid")
        local rootPart = currentTarget.Character:FindFirstChild("HumanoidRootPart")
        
        if humanoid and rootPart and lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart") then
            local health = humanoid.MaxHealth > 0 and (humanoid.Health / humanoid.MaxHealth) * 100 or 0
            local distance = (lplr.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
            
            if health > 0 and health <= LowHealthSlider.Value and distance <= ExecuteRangeSlider.Value then
                selectContract(currentTarget)
            end
        end
    end
    
    local function contractOnHit()
        if not currentTarget or tick() - lastHitTime > 0.5 then
            currentTarget = nil
            return
        end
        
        if not currentTarget.Character then return end
        
        local rootPart = currentTarget.Character:FindFirstChild("HumanoidRootPart")
        
        if rootPart and lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (lplr.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
            
            if distance <= HitRangeSlider.Value then
                selectContract(currentTarget)
            end
        end
    end
    
    local function proximityContract()
        if not entitylib.isAlive then return end
        
        local myRoot = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        
        local closestPlayer = nil
        local closestDistance = ProximityRangeSlider.Value
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= lplr and player.Character then
                local theirRoot = player.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = player.Character:FindFirstChild("Humanoid")
                
                if theirRoot and humanoid and humanoid.Health > 0 then
                    local distance = (myRoot.Position - theirRoot.Position).Magnitude
                    
                    if distance < closestDistance then
                        closestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
        
        if closestPlayer then
            selectContract(closestPlayer)
        end
    end
    
    Caitlyn = vape.Categories.Kits:CreateModule({
        Name = 'AutoCaitlyn',
        Function = function(callback)
            if callback then
                local damageConnection = vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
                    if not entitylib.isAlive then return end
                    
                    local attacker = playersService:GetPlayerFromCharacter(damageTable.fromEntity)
                    local victim = playersService:GetPlayerFromCharacter(damageTable.entityInstance)
                
                    if attacker == lplr and victim and victim ~= lplr then
                        currentTarget = victim
                        lastHitTime = tick()
                    end
                end)
                table.insert(connections, damageConnection)
                
                task.spawn(function()
                    repeat
                        if entitylib.isAlive then
                            local method = MethodDropdown.Value
                            
                            if method == "Low HP" then
                                executeOnLowHealth()
                            elseif method == "Contract on Hit" then
                                contractOnHit()
                            elseif method == "Proximity Select" then
                                proximityContract()
                            end
                        end
                        task.wait(0.1)
                    until not Caitlyn.Enabled
                end)
            else
                for _, conn in pairs(connections) do
                    if typeof(conn) == "RBXScriptConnection" then
                        conn:Disconnect()
                    end
                end
                table.clear(connections)
                
                currentTarget = nil
                lastHitTime = 0
            end
        end,
        Tooltip = 'auto select contracts for cait based off varius situation'
    })
    
    MethodDropdown = Caitlyn:CreateDropdown({
        Name = 'Method',
        List = {"Low HP", "Contract on Hit", "Proximity Select"},
        Default = "Low HP",
        Tooltip = 'selection methods',
        Function = function(value)
            LowHealthSlider.Object.Visible = (value == "Low HP")
            ExecuteRangeSlider.Object.Visible = (value == "Low HP")
            HitRangeSlider.Object.Visible = (value == "Contract on Hit")
            ProximityRangeSlider.Object.Visible = (value == "Proximity Select")
        end
    })
    
    LowHealthSlider = Caitlyn:CreateSlider({
        Name = 'Select Health',
        Min = 1,
        Max = 100,
        Default = 30,
        Suffix = '%',
    })
    
    ExecuteRangeSlider = Caitlyn:CreateSlider({
        Name = 'Select Range',
        Min = 5,
        Max = 50,
        Default = 20,
        Suffix = ' studs',
    })
    
    HitRangeSlider = Caitlyn:CreateSlider({
        Name = 'Hit Range',
        Min = 10,
        Max = 200,
        Default = 100,
        Suffix = ' studs',
    })
    
    ProximityRangeSlider = Caitlyn:CreateSlider({
        Name = 'Proximity Range',
        Min = 10,
        Max = 200,
        Default = 50,
        Suffix = ' studs',
    })
    
    LowHealthSlider.Object.Visible = true
    ExecuteRangeSlider.Object.Visible = true
    HitRangeSlider.Object.Visible = false
    ProximityRangeSlider.Object.Visible = false
end)
run(function()
    local AutoWhisper
    local PlayerDropdown
    local AutoHeal
    local AutoHealSlider
    local AutoFly
    local LimitToItem
    local RefreshButton
    local running = false
    local healRunning = false
    local flyRunning = false
    local currentTarget = nil
    local currentMountedPlayer = nil
    local fallCheckTimer = 0
    local hasActivatedFly = false
    
    local function isHoldingOwlOrb()
        if not entitylib.isAlive then return false end
        
        local inventory = store.inventory
        if inventory and inventory.inventory and inventory.inventory.hand then
            local handItem = inventory.inventory.hand
            if handItem and handItem.itemType == "owl_orb" then
                return true
            end
        end
        return false
    end
    
    local function getMountedPlayer()
        local owlTarget = lplr:GetAttribute('OwlTarget')
        if owlTarget then
            return playersService:GetPlayerByUserId(owlTarget)
        end
        return nil
    end
    
    local function mountBirdToPlayer(targetPlayer)
        if not targetPlayer or not targetPlayer.Character then return false end
        
        if LimitToItem.Enabled and not isHoldingOwlOrb() then
            return false
        end
        
        local success = false
        pcall(function()
            local result = bedwars.Client:Get(remotes.SummonOwl).instance:InvokeServer(targetPlayer)
            
            if result then
            task.wait(0.05)
            
            pcall(function()
    			bedwars.Client:Get(remotes.UseAbility).instance:FireServer("SUMMON_OWL")
			end)
                
                currentMountedPlayer = targetPlayer
                success = true
            end
        end)
        
        return success
    end
    
    local function demountOwl()
        pcall(function()
            bedwars.Client:Get(remotes.UseAbility).instance:FireServer("DEACTIVE_OWL")
            
            task.wait(0.05)
            
            bedwars.Client:Get(remotes.RemoveOwl).instance:FireServer()
        end)
        
        currentMountedPlayer = nil
    end
    
    local function healTarget()
        pcall(function()
            replicatedStorage:WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events"):WaitForChild("useAbility"):FireServer("OWL_HEAL")
        end)
    end
    
    local function isFalling(player)
        if not player or not player.Character or not player.Character.PrimaryPart then
            return false
        end
        
        local velocity = player.Character.PrimaryPart.AssemblyLinearVelocity.Y
        return velocity < -20
    end
    
	local voidRayParams = RaycastParams.new()
	voidRayParams.FilterType = Enum.RaycastFilterType.Blacklist
	voidRayParams.RespectCanCollide = true

	local function isAboveVoid(player)
		if not player or not player.Character or not player.Character.PrimaryPart then
			return false
		end
		
		local rayOrigin = player.Character.PrimaryPart.Position
		local rayDirection = Vector3.new(0, -1000, 0)
		
		voidRayParams.FilterDescendantsInstances = {player.Character, gameCamera}
		
		local rayResult = workspace:Raycast(rayOrigin, rayDirection, voidRayParams)
		
		if not rayResult then
			return true
		end
		
		return rayResult.Distance > 200
	end
    
    local function activateFly()
        pcall(function()
            replicatedStorage:WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events"):WaitForChild("useAbility"):FireServer("OWL_LIFT")
            
            hasActivatedFly = true
            task.spawn(function()
                task.wait(85)
                hasActivatedFly = false
            end)
        end)
    end
    
    AutoWhisper = vape.Categories.Kits:CreateModule({
        Name = "AutoWhisper",
        Function = function(callback)
            running = callback
            healRunning = callback
            flyRunning = callback
            
            if callback then
                task.spawn(function()
                    while running do
                        if LimitToItem.Enabled and not isHoldingOwlOrb() then
                            task.wait(0.2)
                            continue
                        end
                        
                        local targetPlayer = playersService:FindFirstChild(PlayerDropdown.Value)
                        if targetPlayer then
                            currentTarget = targetPlayer
                            
                            local mountedTo = getMountedPlayer()
                            
                            if mountedTo ~= targetPlayer then
                                if mountedTo and mountedTo ~= targetPlayer then
                                    demountOwl()
                                    task.wait(0.3)
                                end
                                
                                if not mountedTo or mountedTo ~= targetPlayer then
                                    local success = mountBirdToPlayer(targetPlayer)
                                    if not success then
                                        task.wait(0.5)
                                    else
                                        task.wait(1)
                                    end
                                end
                            else
                                task.wait(0.5)
                            end
                        else
                            task.wait(0.5)
                        end
                    end
                end)
                
                if AutoHeal.Enabled then
                    task.spawn(function()
                        while healRunning and AutoHeal.Enabled do
                            if currentTarget then
                                local health, maxHealth = getPlayerHealth(currentTarget)
                                if health and maxHealth and maxHealth > 0 then
                                    local healthPercent = (health / maxHealth) * 100
                                    if healthPercent < AutoHealSlider.Value and healthPercent < 90 then
                                        healTarget()
                                        task.wait(8.5)
                                    end
                                end
                            end
                            
                            task.wait(0.5)
                        end
                    end)
                end
                
                if AutoFly.Enabled then
                    task.spawn(function()
                        while flyRunning and AutoFly.Enabled do
                            if currentTarget and not hasActivatedFly then
                                if isFalling(currentTarget) and isAboveVoid(currentTarget) then
                                    fallCheckTimer = fallCheckTimer + 0.1
                                    
                                    if fallCheckTimer >= 0.5 then
                                        activateFly()
                                        fallCheckTimer = 0
                                    end
                                else
                                    fallCheckTimer = 0
                                end
                            else
                                fallCheckTimer = 0
                            end
                            
                            task.wait(0.1)
                        end
                    end)
                end
                
                AutoWhisper:Clean(playersService.PlayerAdded:Connect(function()
                    task.wait(0.5)
                    local newList = getTeammates(true)
                    if PlayerDropdown then
                        PlayerDropdown:Change(newList)
                        
                        if #newList > 0 then
                            if not PlayerDropdown.Value or PlayerDropdown.Value == "" or not table.find(newList, PlayerDropdown.Value) then
                                PlayerDropdown:SetValue(newList[1])
                            end
                        end
                    end
                end))
                
                AutoWhisper:Clean(playersService.PlayerRemoving:Connect(function(player)
                    task.wait(0.5)
                    local newList = getTeammates(true)
                    if PlayerDropdown then
                        PlayerDropdown:Change(newList)
                        
                        if #newList > 0 then
                            if not PlayerDropdown.Value or PlayerDropdown.Value == "" or not table.find(newList, PlayerDropdown.Value) then
                                PlayerDropdown:SetValue(newList[1])
                            end
                        end
                    end
                    
                    if currentTarget == player then
                        currentTarget = nil
                        currentMountedPlayer = nil
                    end
                end))
                
                AutoWhisper:Clean(lplr:GetAttributeChangedSignal('Team'):Connect(function()
                    task.wait(0.5)
                    local newList = getTeammates(true)
                    if PlayerDropdown then
                        PlayerDropdown:Change(newList)
                        
                        if #newList > 0 then
                            if not PlayerDropdown.Value or PlayerDropdown.Value == "" or not table.find(newList, PlayerDropdown.Value) then
                                PlayerDropdown:SetValue(newList[1])
                            end
                        end
                    end
                    currentTarget = nil
                    currentMountedPlayer = nil
                    hasActivatedFly = false
                end))
                
            else
                running = false
                healRunning = false
                flyRunning = false
                currentTarget = nil
                currentMountedPlayer = nil
                hasActivatedFly = false
                fallCheckTimer = 0
            end
        end,
    })
    
    PlayerDropdown = AutoWhisper:CreateDropdown({
        Name = "Bird Target",
        List = {},
        Function = function(val)
            if val then
                local targetPlayer = playersService:FindFirstChild(val)
                if targetPlayer then
                    currentTarget = targetPlayer
                end
            end
        end,
    })
    RefreshButton = AutoWhisper:CreateButton({
        Name = "Refresh Teammates",
        Function = function()
            task.spawn(function()
                local newList = getTeammates(true)
                
                if PlayerDropdown then
                    pcall(function()
                        PlayerDropdown:Change(newList)
                        
                        if #newList > 0 then
                            if not PlayerDropdown.Value or PlayerDropdown.Value == "" or not table.find(newList, PlayerDropdown.Value) then
                                PlayerDropdown:SetValue(newList[1])
                            else
                                PlayerDropdown:SetValue(PlayerDropdown.Value)
                            end
                        end
                    end)
                end
                
                notif("AutoWhisper", string.format("teammate list (%d teammates)", #newList), 2)
            end)
        end,
    })
    
    LimitToItem = AutoWhisper:CreateToggle({
        Name = "Limit to Owl Orb",
        Default = true,
        Function = function(val)
        end,
    })

    AutoFly = AutoWhisper:CreateToggle({
        Name = "Auto Fly",
        Default = true,
        Function = function(val)
            if AutoWhisper.Enabled then
                if val then
                    flyRunning = true
                    hasActivatedFly = false
                    fallCheckTimer = 0
                    
                    task.spawn(function()
                        while flyRunning and AutoFly.Enabled do
                            if currentTarget and not hasActivatedFly then
                                if isFalling(currentTarget) and isAboveVoid(currentTarget) then
                                    fallCheckTimer = fallCheckTimer + 0.1
                                    
                                    if fallCheckTimer >= 0.5 then
                                        activateFly()
                                        fallCheckTimer = 0
                                    end
                                else
                                    fallCheckTimer = 0
                                end
                            else
                                fallCheckTimer = 0
                            end
                            
                            task.wait(0.1)
                        end
                    end)
                else
                    flyRunning = false
                    hasActivatedFly = false
                    fallCheckTimer = 0
                end
            end
        end,
    })
    
    AutoHeal = AutoWhisper:CreateToggle({
        Name = "Auto Heal",
        Default = true,
        Function = function(val)
            if AutoHealSlider and AutoHealSlider.Object then
                AutoHealSlider.Object.Visible = val
            end
            
            if AutoWhisper.Enabled then
                if val then
                    healRunning = true
                    task.spawn(function()
                        while healRunning and AutoHeal.Enabled do
                            if currentTarget then
                                local health, maxHealth = getPlayerHealth(currentTarget)
                                if not (health and maxHealth and maxHealth > 0) then task.wait(0.5) continue end
                                local healthPercent = (health / maxHealth) * 100
                                if healthPercent < AutoHealSlider.Value and healthPercent < 90 then
                                    healTarget()
                                    task.wait(8.5)
                                end
                            end
                            
                            task.wait(0.5)
                        end
                    end)
                else
                    healRunning = false
                end
            end
        end,
    })
    
    AutoHealSlider = AutoWhisper:CreateSlider({
        Name = "Heal Threshold",
        Min = 1,
        Max = 100,
        Default = 50,
        Suffix = "%",
    })
end)
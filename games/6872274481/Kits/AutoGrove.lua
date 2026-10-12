run(function()
    local Grove
    local NoSlow
    local NoSlowOnAbility
    local AutoWater
    local AutoWaterRange
    local AutoCollect
    local CollectRange
    local SpiritESP
    local ESPNotify
    local ESPBackground
    local ESPColor
    local DistanceCheck
    local DistanceLimit
    
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local Reference = {}
    local lastNotification = 0
    local spawnQueue = {}
    local notificationCooldown = 1
    local noSlowActive = false
    local autoWaterActive = false
    local autoCollectActive = false
    local originalDisableActionsOnCharge
    local originalCheckForPickup
    
    local function sendNotification(count)
        notif("Spirit ESP", string.format("%d spirit orbs spawned", count), 3)
    end

    local function processSpawnQueue()
        if #spawnQueue > 0 then
            local currentTime = tick()
            if currentTime - lastNotification >= notificationCooldown then
                sendNotification(#spawnQueue)
                lastNotification = currentTime
                spawnQueue = {}
            else
                task.delay(notificationCooldown - (currentTime - lastNotification), function()
                    if #spawnQueue > 0 then
                        sendNotification(#spawnQueue)
                        spawnQueue = {}
                    end
                end)
            end
        end
    end

    local function getProperImage()
        return bedwars.getIcon({itemType = 'spirit'}, true)
    end

    local function Added(v)
        if Reference[v] then return end
        local _bpUserId = v:GetAttribute('PlacedByUserId')
        if _bpUserId then
            local _bpOk, _bpOwner = pcall(function() return playersService:GetPlayerByUserId(_bpUserId) end)
        end
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = 'spirit-energy'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
        billboard.Size = UDim2.fromOffset(36, 36)
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = v
        
        local blur = addBlur(billboard)
        blur.Visible = ESPBackground.Enabled
        
        local image = Instance.new('ImageLabel')
        image.Size = UDim2.fromOffset(36, 36)
        image.Position = UDim2.fromScale(0.5, 0.5)
        image.AnchorPoint = Vector2.new(0.5, 0.5)
        image.BackgroundColor3 = Color3.fromHSV(ESPColor.Hue, ESPColor.Sat, ESPColor.Value)
        image.BackgroundTransparency = 1 - (ESPBackground.Enabled and ESPColor.Opacity or 0)
        image.BorderSizePixel = 0
        image.Image = getProperImage()
        image.Parent = billboard
        
        local uicorner = Instance.new('UICorner')
        uicorner.CornerRadius = UDim.new(0, 4)
        uicorner.Parent = image
        
        Reference[v] = billboard
        
        if ESPNotify.Enabled then
            table.insert(spawnQueue, {item = 'spirit', time = tick()})
            processSpawnQueue()
        end
    end

    local function Removed(v)
        if Reference[v] then
            Reference[v]:Destroy()
            Reference[v] = nil
        end
    end

    local function setupESP()
        for _, v in workspace:GetChildren() do
            if v.Name == "SpiritGardenerEnergy" and v:IsA("Model") and v.PrimaryPart then
                Added(v.PrimaryPart)
            end
        end

        Grove:Clean(workspace.ChildAdded:Connect(function(v)
            if v.Name == "SpiritGardenerEnergy" and v:IsA("Model") then
                task.wait(0.1)
                if v.PrimaryPart then
                    Added(v.PrimaryPart)
                end
            end
        end))

        Grove:Clean(workspace.ChildRemoved:Connect(function(v)
            if v.Name == "SpiritGardenerEnergy" and v.PrimaryPart then
                Removed(v.PrimaryPart)
            end
        end))

        local _grLastUpdate = 0
        Grove:Clean(runService.RenderStepped:Connect(function()
            if not SpiritESP.Enabled then return end
            local _now = tick()
            if _now - _grLastUpdate < 0.1 then return end
            _grLastUpdate = _now
            
            for v, billboard in pairs(Reference) do
                if not v or not v.Parent then
                    Removed(v)
                    continue
                end

                local shouldShow = true

                if shouldShow and DistanceCheck.Enabled and entitylib.isAlive then
                    local distance = (entitylib.character.RootPart.Position - v.Position).Magnitude
                    if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
                        shouldShow = false
                    end
                end

                billboard.Enabled = shouldShow
            end
        end))
    end

    local function getNearbyFlowers()
        local flowers = {}
        if not entitylib.isAlive then return flowers end
        
        local localPosition = entitylib.character.RootPart.Position
        local range = AutoWaterRange.Value
        
        for _, v in collectionService:GetTagged('SpiritGardenerFlower') do
            if v:IsA("Model") and v.PrimaryPart then
                if v:GetAttribute("PlacedByUserId") == lplr.UserId then
                    local needsEnergy = not v:GetAttribute("HasFullyGrown")
                    if needsEnergy then
                        local distance = (localPosition - v.PrimaryPart.Position).Magnitude
                        if distance <= range then
                            table.insert(flowers, v)
                        end
                    end
                end
            end
        end
        
        return flowers
    end

    local function useWaterAbility()
        local success = pcall(function()
            game:GetService("ReplicatedStorage"):WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events"):WaitForChild("useAbility"):FireServer("spirit_gardener_water")
        end)
        return success
    end

    local function startAutoWater()
        if autoWaterActive then return end
        autoWaterActive = true
        
        task.spawn(function()
            while Grove.Enabled and AutoWater.Enabled and autoWaterActive do
                if not entitylib.isAlive then 
                    task.wait(0.5)
                    continue 
                end
                
                local flowers = getNearbyFlowers()
                
                if #flowers > 0 then
                    if useWaterAbility() then
                        task.wait(0.6) 
                    else
                        task.wait(0.3)
                    end
                else
                    task.wait(0.5)
                end
            end
            
            autoWaterActive = false
        end)
    end

    local function stopAutoWater()
        autoWaterActive = false
    end

    local function hookAutoCollect()
        if not bedwars.SpiritGardenerSeedController then return end
        
        originalCheckForPickup = bedwars.SpiritGardenerSeedController.checkForPickup
        
        bedwars.SpiritGardenerSeedController.checkForPickup = function(self)
            if not AutoCollect.Enabled then
                return originalCheckForPickup(self)
            end
            
            local Players = playersService
            local CollectionService = collectionService
            local Workspace = game:GetService("Workspace")
            
            local Character = Players.LocalPlayer.Character
            if not Character or not Character.PrimaryPart then
                return nil
            end
            
            local localPosition = Character.PrimaryPart.Position
            local range = CollectRange.Value
            
            local validTypes = self:validCollectableEntityTypes()
            
            for _, collectableType in validTypes do
                local tagged = CollectionService:GetTagged(collectableType)
                
                for _, orb in tagged do
                    local spawnTime = orb:GetAttribute("SpawnTime")
                    if spawnTime and (Workspace:GetServerTimeNow() - spawnTime) >= 1 then
                        local orbPosition = orb:GetPivot().Position
                        local distance = (localPosition - orbPosition).Magnitude
                        
                        if distance <= range then
                            self:collectEntity(Players.LocalPlayer, orb, collectableType)
                        end
                    end
                end
            end
        end
    end

    local function unhookAutoCollect()
        if originalCheckForPickup and bedwars.SpiritGardenerSeedController then
            bedwars.SpiritGardenerSeedController.checkForPickup = originalCheckForPickup
        end
    end

    local function startAutoCollect()
        if autoCollectActive then return end
        autoCollectActive = true
        
        hookAutoCollect()
        
        if bedwars.SpiritGardenerSeedController then
            pcall(function()
                bedwars.SpiritGardenerSeedController:listenToPickup()
            end)
        end
    end

    local function stopAutoCollect()
        autoCollectActive = false
        unhookAutoCollect()
    end

    local function hookNoSlow()
        if not bedwars.SpiritGardenerController then return end
        
        originalDisableActionsOnCharge = bedwars.SpiritGardenerController.disableActionsOnCharge
        
        bedwars.SpiritGardenerController.disableActionsOnCharge = function(self, maid, character)
            if not NoSlow.Enabled then
                return originalDisableActionsOnCharge(self, maid, character)
            end
            
            if NoSlowOnAbility.Enabled then
                local isLocalPlayer = character == lplr.Character
                if not isLocalPlayer then
                    return originalDisableActionsOnCharge(self, maid, character)
                end
            end
            
            if character == lplr.Character then
                local KnitClient = bedwars.KnitClient
                
                KnitClient.Controllers.SwordController:toggleSwordSwing(true)
                KnitClient.Controllers.BlockPlacementController:disableBlockPlacer()
                
                local ClientSyncEvents = debug.getupvalue(originalDisableActionsOnCharge, 3)
                local projectileConnection = ClientSyncEvents.BeginProjectileTargeting:connect(function(event)
                    event:setCancelled(true)
                    return nil
                end)
                
                local jumpModifier = KnitClient.Controllers.JumpHeightController:getJumpModifier():addModifier({
                    jumpHeightMultiplier = 0;
                })
                
                maid:GiveTask(function()
                    KnitClient.Controllers.SwordController:toggleSwordSwing(false)
                    KnitClient.Controllers.BlockPlacementController:enableBlockPlacer()
                    projectileConnection:Destroy()
                    jumpModifier.Destroy()
                end)
            end
        end
    end

    local function unhookNoSlow()
        if originalDisableActionsOnCharge and bedwars.SpiritGardenerController then
            bedwars.SpiritGardenerController.disableActionsOnCharge = originalDisableActionsOnCharge
        end
    end

    Grove = vape.Categories.Kits:CreateModule({
        Name = 'AutoGrove',
        Function = function(callback)
            if callback then
                if SpiritESP.Enabled then 
                    setupESP() 
                end
                
                if NoSlow.Enabled then
                    hookNoSlow()
                end
                
                if AutoCollect.Enabled then
                    startAutoCollect()
                end
            else
                stopAutoCollect()
                unhookNoSlow()
                Folder:ClearAllChildren()
                table.clear(Reference)
                table.clear(spawnQueue)
                lastNotification = 0
            end
        end,
        Tooltip = 'cool features for grove '
    })
    
    NoSlow = Grove:CreateToggle({
        Name = 'No Slow',
        Default = false,
        Tooltip = 'Remove movement lock when using water ability',
        Function = function(callback)
            if NoSlowOnAbility and NoSlowOnAbility.Object then 
                NoSlowOnAbility.Object.Visible = callback 
            end
            
            if Grove.Enabled then
                if callback then
                    hookNoSlow()
                else
                    unhookNoSlow()
                end
            end
        end
    })
    
    NoSlowOnAbility = Grove:CreateToggle({
        Name = 'Only On Ability Use',
        Default = false,
        Tooltip = 'noslow down only works when u manually use the ability'
    })
    
    AutoWater = Grove:CreateToggle({
        Name = 'Auto Water',
        Default = false,
        Tooltip = 'uses water ability on nearby flowers',
        Function = function(callback)
            if AutoWaterRange and AutoWaterRange.Object then 
                AutoWaterRange.Object.Visible = callback 
            end
            
            if Grove.Enabled then
                if callback then
                    startAutoWater()
                else
                    stopAutoWater()
                end
            end
        end
    })
    
    AutoWaterRange = Grove:CreateSlider({
        Name = 'Water Range',
        Min = 1, 
        Max = 30,
        Default = 20,
        Decimal = 1,
        Suffix = ' studs',
    })
    
    AutoCollect = Grove:CreateToggle({
        Name = 'Auto Collect',
        Default = false,
        Function = function(callback)
            if CollectRange and CollectRange.Object then 
                CollectRange.Object.Visible = callback 
            end
            
            if Grove.Enabled then
                if callback then
                    startAutoCollect()
                else
                    stopAutoCollect()
                end
            end
        end
    })
    
    CollectRange = Grove:CreateSlider({
        Name = 'Collect Range',
        Min = 5, 
        Max = 12,
        Default = 12,
        Decimal = 10,
        Suffix = ' studs',
    })
    
    SpiritESP = Grove:CreateToggle({
        Name = 'Spirit ESP',
        Default = false,
        Function = function(callback)
            if ESPNotify and ESPNotify.Object then ESPNotify.Object.Visible = callback end
            if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = callback end
            if ESPColor and ESPColor.Object then ESPColor.Object.Visible = callback end
            if DistanceCheck and DistanceCheck.Object then DistanceCheck.Object.Visible = callback end
            if DistanceLimit and DistanceLimit.Object then
                DistanceLimit.Object.Visible = (callback and DistanceCheck.Enabled)
            end

            if not callback then
                if ESPColor and ESPColor.Object then
                    ESPColor.Object.Visible = false
                end
                if DistanceLimit and DistanceLimit.Object then
                    DistanceLimit.Object.Visible = false
                end
            else
                if ESPBackground and ESPBackground.Enabled then
                    if ESPColor and ESPColor.Object then
                        ESPColor.Object.Visible = true
                    end
                end
                if DistanceCheck and DistanceCheck.Enabled then
                    if DistanceLimit and DistanceLimit.Object then
                        DistanceLimit.Object.Visible = true
                    end
                end
            end
            
            if Grove.Enabled then
                if callback then 
                    setupESP() 
                else
                    Folder:ClearAllChildren()
                    table.clear(Reference)
                end
            end
        end
    })
    
    ESPNotify = Grove:CreateToggle({
        Name = 'Notify',
        Default = false,
    })
    
    ESPBackground = Grove:CreateToggle({
        Name = 'Background',
        Default = true,
        Function = function(callback)
            if ESPColor and ESPColor.Object then ESPColor.Object.Visible = callback end
            for _, v in Reference do
                if v and v:FindFirstChild("ImageLabel") then
                    local blur = v:FindFirstChild("BlurEffect")
                    if blur then blur.Visible = callback end
                    v.ImageLabel.BackgroundTransparency = 1 - (callback and ESPColor.Opacity or 0)
                end
            end
        end
    })
    
    ESPColor = Grove:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0.5,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, v in Reference do
                if v and v:FindFirstChild("ImageLabel") then
                    v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                    v.ImageLabel.BackgroundTransparency = 1 - opacity
                end
            end
        end,
        Darker = true
    })
    
    DistanceCheck = Grove:CreateToggle({
        Name = 'Distance Check',
        Default = false,
        Function = function(callback)
            if DistanceLimit and DistanceLimit.Object then
                DistanceLimit.Object.Visible = callback
            end
        end
    })
    
    DistanceLimit = Grove:CreateTwoSlider({
        Name = 'Spirit Distance',
        Min = 0,
        Max = 256,
        DefaultMin = 0,
        DefaultMax = 64,
        Darker = true,
    })

    task.defer(function()
        if ESPNotify and ESPNotify.Object then ESPNotify.Object.Visible = false end
        if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = false end
        if ESPColor and ESPColor.Object then ESPColor.Object.Visible = false end
        if DistanceCheck and DistanceCheck.Object then DistanceCheck.Object.Visible = false end
        if DistanceLimit and DistanceLimit.Object then DistanceLimit.Object.Visible = false end
        if CollectRange and CollectRange.Object then
            CollectRange.Object.Visible = false
        end
        if NoSlowOnAbility and NoSlowOnAbility.Object then
            NoSlowOnAbility.Object.Visible = false
        end
    end)
end)
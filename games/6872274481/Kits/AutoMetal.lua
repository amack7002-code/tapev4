run(function()
    local AutoMetal
    local CollectionToggle
    local LimitToItem
    local Animation
    local CollectionDelay
    local DelaySlider
    local RangeSlider
    local ESPToggle
    local ESPNotify
    local ESPBackground
    local ESPColor
    local HoldingCheck
    local DistanceCheck
    local DistanceLimit
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local Reference = {}
    local lastNotification = 0
    local notificationPending = false
    local spawnQueue = {}
    local notificationCooldown = 1
    local collectionActive = false
    local collectedMetals = {}
    local animationDebounce = {}

    local function isHoldingAutoMetal()
        if not store.hand or not store.hand.tool then return false end
        return store.hand.tool.Name == 'metal_detector'
    end

    local function sendNotification(count)
        notif("Metal ESP", string.format("%d metals spawned", count), 3)
    end

    local function processSpawnQueue()
        if #spawnQueue == 0 then return end
        local currentTime = tick()
        local remaining = notificationCooldown - (currentTime - lastNotification)
        if remaining <= 0 then
            sendNotification(#spawnQueue)
            lastNotification = currentTime
            spawnQueue = {}
            notificationPending = false
        elseif not notificationPending then
            notificationPending = true
            task.delay(remaining, function()
                if #spawnQueue > 0 then
                    sendNotification(#spawnQueue)
                    lastNotification = tick()
                    spawnQueue = {}
                end
                notificationPending = false
            end)
        end
    end

    local function getProperImage()
        return bedwars.getIcon({itemType = 'iron'}, true)
    end

    local function Added(v)
        if Reference[v] then return end
        local _bpUserId = v:GetAttribute('PlacedByUserId')
        if _bpUserId then
            local _bpOk, _bpOwner = pcall(function() return playersService:GetPlayerByUserId(_bpUserId) end)
        end
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = 'hidden-metal'
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
            table.insert(spawnQueue, {item = 'metal', time = tick()})
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
        for _, v in collectionService:GetTagged('hidden-metal') do
            if v:IsA("Model") and v.PrimaryPart then
                Added(v.PrimaryPart)
            end
        end

        AutoMetal:Clean(collectionService:GetInstanceAddedSignal('hidden-metal'):Connect(function(v)
            if v:IsA("Model") and v.PrimaryPart then
                Added(v.PrimaryPart)
            end
        end))

        AutoMetal:Clean(collectionService:GetInstanceRemovedSignal('hidden-metal'):Connect(function(v)
            if v.PrimaryPart then
                Removed(v.PrimaryPart)
            end
        end))

        local _mdLastUpdate = 0
        AutoMetal:Clean(runService.RenderStepped:Connect(function()
            if not ESPToggle.Enabled then return end
            local _now = tick()
            if _now - _mdLastUpdate < 0.1 then return end
            _mdLastUpdate = _now
            
            for v, billboard in pairs(Reference) do
                if not v or not v.Parent then
                    Removed(v)
                    continue
                end

                local shouldShow = true

                if HoldingCheck.Enabled and not isHoldingAutoMetal() then
                    shouldShow = false
                end

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

    local function collectMetal(metalModel)
        local metalId = metalModel:GetAttribute('Id')
        if not metalId then return false end
        if collectedMetals[metalId] then return false end

        collectedMetals[metalId] = true

        local success = pcall(function()
            bedwars.Client:Get(remotes.CollectCollectableEntity).instance:FireServer({ id = metalId })
        end)

        if Animation.Enabled then
            local currentTick = tick()
            if not animationDebounce[metalId] or (currentTick - animationDebounce[metalId]) >= 0.5 then
                animationDebounce[metalId] = currentTick
                pcall(function()
                    bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.SHOVEL_DIG)
                    bedwars.SoundManager:playSound(bedwars.SoundList.SNAP_TRAP_CONSUME_MARK)
                end)
            end
        end

        task.delay(2, function()
            collectedMetals[metalId] = nil
            animationDebounce[metalId] = nil
        end)
        
        return success
    end

    local function startAutoCollect()
        if collectionActive then return end
        collectionActive = true
        
        task.spawn(function()
            while AutoMetal.Enabled and CollectionToggle.Enabled and collectionActive do
                if not entitylib.isAlive then 
                    task.wait(0.5)
                    continue 
                end
                
                if LimitToItem.Enabled and not isHoldingAutoMetal() then 
                    task.wait(0.5)
                    continue 
                end
                
                local localPosition = entitylib.character.RootPart.Position
                local range = RangeSlider.Value
                local collectedThisCycle = false
								
				for _, v in collectionService:GetTagged('hidden-metal') do
					if not AutoMetal.Enabled or not CollectionToggle.Enabled or not collectionActive then 
						break 
					end
					
					if v:IsA("Model") and v.PrimaryPart then
						local distance = (localPosition - v.PrimaryPart.Position).Magnitude
						
						if distance <= range then
							if CollectionDelay.Enabled and DelaySlider.Value > 0 then
								task.wait(DelaySlider.Value)
							end
							if collectMetal(v) then
								collectedThisCycle = true
								if Animation.Enabled then
									task.wait(0.15)
								end
							end
						end
					end
				end
                
                task.wait(collectedThisCycle and (Animation.Enabled and 0.3 or 0.05) or 0.5)
            end
            
            collectionActive = false
        end)
    end

    local function stopAutoCollect()
        collectionActive = false
        table.clear(collectedMetals)
        table.clear(animationDebounce)
    end

    AutoMetal = vape.Categories.Kits:CreateModule({
        Name = 'AutoMetal',
        Function = function(callback)
            if callback then
                if ESPToggle.Enabled then 
                    setupESP() 
                end
                if CollectionToggle.Enabled then
                    startAutoCollect()
                end
            else
                stopAutoCollect()
                Folder:ClearAllChildren()
                table.clear(Reference)
                spawnQueue = {}
                lastNotification = 0
                notificationPending = false
            end
        end,
        Tooltip = 'automatically collects metal loot and esp'
    })
    
    CollectionToggle = AutoMetal:CreateToggle({
        Name = 'Auto Collect',
        Default = true,
        Function = function(callback)
            if LimitToItem and LimitToItem.Object then LimitToItem.Object.Visible = callback end
            if Animation and Animation.Object then Animation.Object.Visible = callback end
            if CollectionDelay and CollectionDelay.Object then CollectionDelay.Object.Visible = callback end
            if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = callback end
            if DelaySlider and DelaySlider.Object then
                DelaySlider.Object.Visible = callback and CollectionDelay and CollectionDelay.Enabled
            end
            
            if AutoMetal.Enabled then
                if callback then
                    startAutoCollect()
                else
                    stopAutoCollect()
                end
            end
        end
    })
    
    LimitToItem = AutoMetal:CreateToggle({
        Name = 'Limit to Items',
        Default = true,
    })
    
    Animation = AutoMetal:CreateToggle({
        Name = 'Animation',
        Default = true,
    })
    
    CollectionDelay = AutoMetal:CreateToggle({
        Name = 'Collection Delay',
        Default = false,
        Function = function(callback)
            if DelaySlider and DelaySlider.Object then
                DelaySlider.Object.Visible = callback
            end
        end
    })
    
    DelaySlider = AutoMetal:CreateSlider({
        Name = 'Delay',
        Min = 0,
        Max = 2,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
        Visible = false,
    })
    
    RangeSlider = AutoMetal:CreateSlider({
        Name = 'Range',
        Min = 1, 
        Max = 10,
        Default = 10,
        Decimal = 1,
        Suffix = ' studs',
    })
    
    ESPToggle = AutoMetal:CreateToggle({
        Name = 'Metal ESP',
        Default = false,
        Function = function(callback)
            if ESPNotify and ESPNotify.Object then ESPNotify.Object.Visible = callback end
            if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = callback end
            if ESPColor and ESPColor.Object then ESPColor.Object.Visible = callback end
            if HoldingCheck and HoldingCheck.Object then HoldingCheck.Object.Visible = callback end
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
            
            if AutoMetal.Enabled then
                if callback then setupESP() else
                    Folder:ClearAllChildren()
                    table.clear(Reference)
                end
            end
        end
    })
    
    ESPNotify = AutoMetal:CreateToggle({
        Name = 'Notify',
        Default = false,
    })
    
    ESPBackground = AutoMetal:CreateToggle({
        Name = 'Background',
        Default = true,
        Function = function(callback)
            if ESPColor and ESPColor.Object then ESPColor.Object.Visible = callback end
            for _, v in Reference do
                if v and v:FindFirstChild("ImageLabel") then
                    local blur = v:FindFirstChild("Blur")
                    if blur then blur.Visible = callback end
                    v.ImageLabel.BackgroundTransparency = 1 - (callback and ESPColor.Opacity or 0)
                end
            end
        end
    })
    
    ESPColor = AutoMetal:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
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
    
    HoldingCheck = AutoMetal:CreateToggle({
        Name = 'Holding Detector',
        Default = false,
    })
    
    DistanceCheck = AutoMetal:CreateToggle({
        Name = 'Distance Check',
        Default = false,
        Function = function(callback)
            if DistanceLimit and DistanceLimit.Object then
                DistanceLimit.Object.Visible = callback
            end
        end
    })
    
    DistanceLimit = AutoMetal:CreateTwoSlider({
        Name = 'Metal Distance',
        Min = 0,
        Max = 256,
        DefaultMin = 0,
        DefaultMax = 64,
        Darker = true,
    })

    task.defer(function()
        if DelaySlider and DelaySlider.Object then
            DelaySlider.Object.Visible = CollectionDelay.Enabled  
        end
        local espOn = ESPToggle and ESPToggle.Enabled
        if ESPNotify and ESPNotify.Object then ESPNotify.Object.Visible = espOn end
        if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = espOn end
        if ESPColor and ESPColor.Object then ESPColor.Object.Visible = (espOn and ESPBackground.Enabled) end
        if HoldingCheck and HoldingCheck.Object then HoldingCheck.Object.Visible = espOn end
        if DistanceCheck and DistanceCheck.Object then DistanceCheck.Object.Visible = espOn end
        if DistanceLimit and DistanceLimit.Object then DistanceLimit.Object.Visible = (espOn and DistanceCheck.Enabled) end
    end)
end)
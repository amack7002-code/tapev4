run(function()
    local Beekeeper
    local isRealBee
    local CollectionToggle
	local LimitToNet
	local HiveLimit
	local function maxHiveLevel()
		return HiveLimit and HiveLimit.Value or 12
	end
    local maxedBeehives = {}
    local maxedNotificationSent = {}
    local CollectionDelay
    local DelaySlider
    local RangeSlider
    local ESPToggle
    local BeesESP
    local BeesNotify
    local BeesBackground
    local BeesColor
    local BeehiveESP
    local ShowOtherBeehives
    local BeehiveBackground
    local BeehiveColor
    local AutoDeposit
    local DepositDelay
    local DepositDelaySlider
    local DepositRange
    local ESPLimitToNet  
    local collectionRunning = false
    local depositRunning = false
    local BeesFolder = Instance.new('Folder')
    BeesFolder.Parent = vape.gui
    local BeehiveFolder = Instance.new('Folder')
    BeehiveFolder.Parent = vape.gui
    local BeesReference = {}
    local BeehiveReference = {}
    local lastNotification = 0
    local spawnQueue = {}
    local notificationCooldown = 1

    local function sendNotification(count)
        notif("Bee ESP", string.format("%d bees spawned", count), 3)
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

    local function getBeeIcon()
        return bedwars.getIcon({itemType = 'bee'}, true)
    end

    local function AddedBee(v)
        if BeesReference[v] then return end
        local model = v.Parent
        if model and not isRealBee(model) then
            return
        end
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = BeesFolder
        billboard.Name = 'bee'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
        billboard.Size = UDim2.fromOffset(36, 36)
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = v
        
        local blur = addBlur(billboard)
        blur.Visible = BeesBackground.Enabled
        
        local image = Instance.new('ImageLabel')
        image.Size = UDim2.fromOffset(36, 36)
        image.Position = UDim2.fromScale(0.5, 0.5)
        image.AnchorPoint = Vector2.new(0.5, 0.5)
        image.BackgroundColor3 = Color3.fromHSV(BeesColor.Hue, BeesColor.Sat, BeesColor.Value)
        image.BackgroundTransparency = 1 - (BeesBackground.Enabled and BeesColor.Opacity or 0)
        image.BorderSizePixel = 0
        image.Image = getBeeIcon()
        image.Parent = billboard
        
        local uicorner = Instance.new('UICorner')
        uicorner.CornerRadius = UDim.new(0, 4)
        uicorner.Parent = image
        
        BeesReference[v] = billboard
        
        if BeesNotify.Enabled then
            table.insert(spawnQueue, {item = 'bee', time = tick()})
            processSpawnQueue()
        end
    end

    local function RemovedBee(v)
        if BeesReference[v] then
            BeesReference[v]:Destroy()
            BeesReference[v] = nil
        end
    end

    local function isMyBeehive(beehive)
        if not beehive then return false end
        local placedBy = beehive:GetAttribute("PlacedByUserId")
        return placedBy and placedBy == lplr.UserId
    end
    
    local function getBeehiveOwnerName(beehive)
        if not beehive then return "Unknown" end
        local placedBy = beehive:GetAttribute("PlacedByUserId")
        if not placedBy then return "Unknown" end
        
        local player = game.Players:GetPlayerByUserId(placedBy)
        if player then
            return player.Name
        end
        
        return "Player"
    end

    local function AddedBeehive(beehive)
        local isOwn = isMyBeehive(beehive)
        
        if not isOwn and not (ShowOtherBeehives and ShowOtherBeehives.Enabled) then 
            return 
        end
        
        if BeehiveReference[beehive] then return end
        
        local level = beehive:GetAttribute("Level") or 0
        local isMaxed = level >= maxHiveLevel() and isOwn
        
        if isMaxed and isOwn then
            maxedBeehives[beehive] = true
        end
        
        local ownerName = isOwn and nil or getBeehiveOwnerName(beehive)
        local hasOwnerName = ownerName ~= nil
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = BeehiveFolder
        billboard.Name = 'beehive-esp'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
        billboard.Size = isMaxed and UDim2.fromOffset(90, 40) or (hasOwnerName and UDim2.fromOffset(120, 40) or UDim2.fromOffset(80, 30))
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = beehive
        
        local blur = addBlur(billboard)
        blur.Visible = BeehiveBackground.Enabled
        
        local frame = Instance.new('Frame')
        frame.Size = UDim2.fromScale(1, 1)
        frame.BackgroundColor3 = isMaxed and Color3.fromRGB(255, 50, 50) or Color3.fromHSV(BeehiveColor.Hue, BeehiveColor.Sat, BeehiveColor.Value)
        frame.BackgroundTransparency = 1 - (BeehiveBackground.Enabled and (isMaxed and 0.5 or BeehiveColor.Opacity) or 0)
        frame.BorderSizePixel = 0
        frame.Parent = billboard
        
        local uicorner = Instance.new('UICorner')
        uicorner.CornerRadius = UDim.new(0, 6)
        uicorner.Parent = frame
        
        if hasOwnerName then
            local nameLabel = Instance.new('TextLabel')
            nameLabel.Name = 'OwnerName'
            nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
            nameLabel.Position = UDim2.new(0, 0, 0, -20)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = ownerName
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.TextSize = 12
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextStrokeTransparency = 0.5
            nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            nameLabel.Parent = billboard
        end
        
        local homeImage = Instance.new('ImageLabel')
		homeImage.Size = UDim2.fromOffset(20, 20)
		homeImage.Position = UDim2.new(0, 5, 0.5, 0)
		homeImage.AnchorPoint = Vector2.new(0, 0.5)
		homeImage.BackgroundTransparency = 1
		homeImage.BorderSizePixel = 0
		homeImage.Image = bedwars.getIcon({itemType = 'beehive'}, true)
		homeImage.Parent = frame
        
        local beeImage = Instance.new('ImageLabel')
        beeImage.Size = UDim2.fromOffset(18, 18)
        beeImage.Position = UDim2.new(0.5, -5, 0.5, 0)
        beeImage.AnchorPoint = Vector2.new(0, 0.5)
        beeImage.BackgroundTransparency = 1
        beeImage.Image = getBeeIcon()
        beeImage.Parent = frame
        
        local levelLabel = Instance.new('TextLabel')
        levelLabel.Name = 'Level'
        levelLabel.Size = UDim2.new(0, 25, 1, 0)
        levelLabel.Position = UDim2.new(1, -30, 0, 0)
        levelLabel.BackgroundTransparency = 1
        levelLabel.Text = tostring(level)
        levelLabel.TextColor3 = isMaxed and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 255, 255)
        levelLabel.TextSize = 16
        levelLabel.Font = Enum.Font.GothamBold
        levelLabel.TextStrokeTransparency = 0.5
        levelLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        levelLabel.Parent = frame
        
        if isMaxed and isOwn then
            local maxText = Instance.new('TextLabel')
            maxText.Name = 'MaxText'
            maxText.Size = UDim2.new(1, 0, 0.4, 0)
            maxText.Position = UDim2.new(0, 0, 0, hasOwnerName and -40 or -20)
            maxText.BackgroundTransparency = 1
            maxText.Text = "MAX"
            maxText.TextColor3 = Color3.fromRGB(255, 50, 50)
            maxText.TextSize = 12
            maxText.Font = Enum.Font.GothamBold
            maxText.TextStrokeTransparency = 0.5
            maxText.TextStrokeColor3 = Color3.new(0, 0, 0)
            maxText.Parent = billboard
        end
        
        BeehiveReference[beehive] = {
            billboard = billboard,
            levelLabel = levelLabel,
            beehive = beehive,
            isMaxed = isMaxed,
            isOwn = isOwn
        }
        
        local function updateLevel()
            local level = beehive:GetAttribute("Level") or 0
            local isMaxed = level >= maxHiveLevel() and isOwn
            
            if isMaxed and isOwn then
                maxedBeehives[beehive] = true
                
                if not maxedNotificationSent[beehive] then
                    notif("Bee Keeper", "Beehive is full (MAX)", 3)
                    maxedNotificationSent[beehive] = true
                end
                
                if BeehiveReference[beehive] and BeehiveReference[beehive].billboard then
                    local maxText = BeehiveReference[beehive].billboard:FindFirstChild("MaxText")
                    if not maxText then
                        maxText = Instance.new('TextLabel')
                        maxText.Name = 'MaxText'
                        maxText.Size = UDim2.new(1, 0, 0.4, 0)
                        maxText.Position = UDim2.new(0, 0, 0, hasOwnerName and -40 or -20)
                        maxText.BackgroundTransparency = 1
                        maxText.Text = "MAX"
                        maxText.TextColor3 = Color3.fromRGB(255, 50, 50)
                        maxText.TextSize = 12
                        maxText.Font = Enum.Font.GothamBold
                        maxText.TextStrokeTransparency = 0.5
                        maxText.TextStrokeColor3 = Color3.new(0, 0, 0)
                        maxText.Parent = BeehiveReference[beehive].billboard
                    end
                    
                    local frame = BeehiveReference[beehive].billboard:FindFirstChild("Frame")
                    if frame then
                        frame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
                        frame.BackgroundTransparency = 1 - (BeehiveBackground.Enabled and 0.5 or 0)
                    end
                end
            else
                if isOwn then
                    maxedBeehives[beehive] = nil
                    maxedNotificationSent[beehive] = nil
                end
                
                if BeehiveReference[beehive] and BeehiveReference[beehive].billboard then
                    local maxText = BeehiveReference[beehive].billboard:FindFirstChild("MaxText")
                    if maxText then
                        maxText:Destroy()
                    end
                    
                    local frame = BeehiveReference[beehive].billboard:FindFirstChild("Frame")
                    if frame then
                        frame.BackgroundColor3 = Color3.fromHSV(BeehiveColor.Hue, BeehiveColor.Sat, BeehiveColor.Value)
                        frame.BackgroundTransparency = 1 - (BeehiveBackground.Enabled and BeehiveColor.Opacity or 0)
                    end
                end
            end
            
            if BeehiveReference[beehive] and BeehiveReference[beehive].levelLabel then
                BeehiveReference[beehive].levelLabel.Text = tostring(level)
            end
            
            if BeehiveReference[beehive] then
                BeehiveReference[beehive].isMaxed = isMaxed
            end
        end
        
        updateLevel()
        
        if isOwn then
            Beekeeper:Clean(beehive:GetAttributeChangedSignal("Level"):Connect(updateLevel))
        else
            Beekeeper:Clean(beehive:GetAttributeChangedSignal("Level"):Connect(function()
                local level = beehive:GetAttribute("Level") or 0
                if BeehiveReference[beehive] and BeehiveReference[beehive].levelLabel then
                    BeehiveReference[beehive].levelLabel.Text = tostring(level)
                end
            end))
        end
    end


    local function RemovedBeehive(beehive)
        if BeehiveReference[beehive] then
            BeehiveReference[beehive].billboard:Destroy()
            BeehiveReference[beehive] = nil
        end
    end

    local function getBeeId(v)
        if not v then return nil end

        local beeId = v:GetAttribute('BeeId')
        if beeId ~= nil then
            return beeId
        end

        local part = v.PrimaryPart or v:FindFirstChildWhichIsA('BasePart', true)
        return part and part:GetAttribute('BeeId')
    end

    isRealBee = function(v)
        local beeId = getBeeId(v)
        return beeId ~= nil and beeId > -1
    end

    local function setupBeesESP()
        for _, tagName in {'bee', 'MeadowBee', 'ChromaBee'} do
            for _, v in collectionService:GetTagged(tagName) do
                if v:IsA("Model") and v.PrimaryPart then
                    if isRealBee(v) then
                        AddedBee(v.PrimaryPart)
                    end
                end
            end

            Beekeeper:Clean(collectionService:GetInstanceAddedSignal(tagName):Connect(function(v)
                if v:IsA("Model") and v.PrimaryPart then
                    task.wait(0.1)
                    if isRealBee(v) then
                        AddedBee(v.PrimaryPart)
                    end
                end
            end))

            Beekeeper:Clean(collectionService:GetInstanceRemovedSignal(tagName):Connect(function(v)
                if v.PrimaryPart then
                    RemovedBee(v.PrimaryPart)
                end
            end))
        end
    end

    local function setupBeehiveESP()
        for _, beehive in collectionService:GetTagged('beehive') do
            AddedBeehive(beehive)
        end

        Beekeeper:Clean(collectionService:GetInstanceAddedSignal('beehive'):Connect(function(beehive)
            task.wait(0.1)
            AddedBeehive(beehive)
        end))

        Beekeeper:Clean(collectionService:GetInstanceRemovedSignal('beehive'):Connect(function(beehive)
            RemovedBeehive(beehive)
        end))
    end

    local function isHoldingBeeNet()
        if not store.hand or not store.hand.tool then return false end

        local name = store.hand.tool.Name

        return name == 'bee_net'
            or name == 'bee-net'
            or name == 'beekeeper_chroma_bee_net'
            or name == 'beekeeper_meadow_bee_net'
    end

	local function kitCollection(id, func, range, specific)
		repeat
			if entitylib.isAlive then
				local objs = type(id) == 'table' and id or collection(id, Beekeeper)
				local localPosition = entitylib.character.RootPart.Position
				for _, v in objs do
					if not Beekeeper.Enabled then break end
					local part = not v:IsA('Model') and v or v.PrimaryPart
					if part and (part.Position - localPosition).Magnitude <= range then
						local success, err = pcall(func, v)
						task.wait(0.02)
					end
				end
			end
			task.wait(0.05)
		until not Beekeeper.Enabled
	end

    local collectionThreads = {}

    local function startCollection()
        collectionRunning = true
        for _, tagName in {'bee', 'MeadowBee', 'ChromaBee'} do
            local thread = task.spawn(function()
                kitCollection(tagName, function(v)
                    if not isRealBee(v) then return end
                    if LimitToNet.Enabled and not isHoldingBeeNet() then return end
                    bedwars.Client:Get(remotes.BeePickup):SendToServer({beeId = getBeeId(v)})
                end, RangeSlider.Value, false)
            end)
            table.insert(collectionThreads, thread)
        end
        Beekeeper:Clean(function()
            for _, thread in collectionThreads do
                task.cancel(thread)
            end
            table.clear(collectionThreads)
        end)
    end

    local function startDeposit()
        depositRunning = true
        task.spawn(function()
            while depositRunning and Beekeeper.Enabled and AutoDeposit.Enabled do
                if not entitylib.isAlive then 
                    task.wait(0.1) 
                    continue 
                end
                
                local currentTool = store.hand and store.hand.tool
                if not currentTool or currentTool.Name ~= 'bee' then
                    task.wait(0.1)
                    continue
                end
                
                local localPosition = entitylib.character.RootPart.Position
                local range = DepositRange.Value
                local depositedThisCycle = false
                
                local availableBeehives = {}
                for _, beehive in collectionService:GetTagged('beehive') do
                    if isMyBeehive(beehive) and not maxedBeehives[beehive] then
                        local beehivePos = beehive.Position
                        local distance = (localPosition - beehivePos).Magnitude
                        
                        if distance <= range then
                            table.insert(availableBeehives, {
                                beehive = beehive,
                                distance = distance
                            })
                        end
                    end
                end
                
                table.sort(availableBeehives, function(a, b)
                    return a.distance < b.distance
                end)
                
                for _, beehiveData in ipairs(availableBeehives) do
                    if not depositRunning or not Beekeeper.Enabled or not AutoDeposit.Enabled then 
                        break 
                    end
                    local beehive = beehiveData.beehive
                    if maxedBeehives[beehive] then
                        continue
                    end
                    
                    local prompt = beehive:FindFirstChildOfClass("ProximityPrompt")
                    
                    if prompt and prompt.Enabled then
                        if DepositDelay.Enabled and DepositDelaySlider.Value > 0 then
                            local originalDuration = prompt.HoldDuration
                            prompt.HoldDuration = DepositDelaySlider.Value
                            
                            if fireproximityprompt then
                                fireproximityprompt(prompt)
                            else
                                prompt:InputHoldBegin()
                                task.wait(DepositDelaySlider.Value)
                                prompt:InputHoldEnd()
                            end
                            
                            task.wait(DepositDelaySlider.Value + 0.1)
                            prompt.HoldDuration = originalDuration
                        else
                            if fireproximityprompt then
                                fireproximityprompt(prompt)
                            else
                                prompt:InputHoldBegin()
                                prompt:InputHoldEnd()
                            end
                            task.wait(0.1)
                        end
                        
                        depositedThisCycle = true
                        break 
                    end
                end
                
                if not depositedThisCycle and #availableBeehives > 0 then
                    local allMaxed = true
                    for _, beehiveData in ipairs(availableBeehives) do
                        if not maxedBeehives[beehiveData.beehive] then
                            allMaxed = false
                            break
                        end
                    end
                    
                    if allMaxed then
                        notif("Bee Keeper", "All nearby beehives are full", 3)
                    end
                end
                
                task.wait(depositedThisCycle and 0.3 or 0.2)
            end
            depositRunning = false
        end)
    end

    Beekeeper = vape.Categories.Kits:CreateModule({
        Name = 'AutoBeekeeper',
        Function = function(callback)
            if callback then
                if ESPToggle.Enabled then
                    if BeesESP.Enabled then
                        setupBeesESP()
                    end
                    if BeehiveESP.Enabled then
                        setupBeehiveESP()
                    end
                end
                
                if CollectionToggle.Enabled then
                    startCollection()
                end
                
                if AutoDeposit.Enabled then
                    startDeposit()
                end
                
                local _bkLastUpdate = 0
                Beekeeper:Clean(runService.RenderStepped:Connect(function()
                    if not ESPToggle.Enabled then return end
                    local _now = tick()
                    if _now - _bkLastUpdate < 0.1 then return end
                    _bkLastUpdate = _now
                    
                    for v, billboard in pairs(BeesReference) do
                        if not v or not v.Parent then
                            RemovedBee(v)
                            continue
                        end

                        local shouldShow = true

                        if ESPLimitToNet.Enabled and not isHoldingBeeNet() then
                            shouldShow = false
                        end

                        billboard.Enabled = shouldShow
                    end
                    
                    for beehive, ref in pairs(BeehiveReference) do
                        if not beehive or not beehive.Parent then
                            RemovedBeehive(beehive)
                            continue
                        end

                        local shouldShow = true

                        if ESPLimitToNet.Enabled and not isHoldingBeeNet() then
                            shouldShow = false
                        end

                        if ref.billboard then
                            ref.billboard.Enabled = shouldShow
                        end
                    end
                end))
            else
                collectionRunning = false
                depositRunning = false
                BeesFolder:ClearAllChildren()
                BeehiveFolder:ClearAllChildren()
                table.clear(BeesReference)
                table.clear(BeehiveReference)
                table.clear(spawnQueue)
                lastNotification = 0
            end
        end,
    })
    
    CollectionToggle = Beekeeper:CreateToggle({
        Name = 'Auto Collect',
        Default = true,
        Function = function(callback)
            if LimitToNet and LimitToNet.Object then LimitToNet.Object.Visible = callback end
            if CollectionDelay and CollectionDelay.Object then CollectionDelay.Object.Visible = callback end
            if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = (callback and CollectionDelay.Enabled) end
            if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = callback end
            
            if callback and Beekeeper.Enabled then
                startCollection()
            else
                collectionRunning = false
            end
        end
    })
    
    LimitToNet = Beekeeper:CreateToggle({
        Name = 'Limit to Net',
        Default = false,
    })
    
    CollectionDelay = Beekeeper:CreateToggle({
        Name = 'Collection Delay',
        Default = false,
        Function = function(callback)
            if DelaySlider and DelaySlider.Object then
                DelaySlider.Object.Visible = callback
            end
        end
    })
    
    DelaySlider = Beekeeper:CreateSlider({
        Name = 'Delay',
        Min = 0,
        Max = 2,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
    })
    
    RangeSlider = Beekeeper:CreateSlider({
        Name = 'Range',
        Min = 1, 
        Max = 10,
        Default = 10,
        Decimal = 1,
        Suffix = ' studs',
    })
    
    ESPToggle = Beekeeper:CreateToggle({
        Name = 'ESP',
        Default = true,
		Function = function(callback)
			if BeesESP and BeesESP.Object then BeesESP.Object.Visible = callback end
			if BeehiveESP and BeehiveESP.Object then BeehiveESP.Object.Visible = callback end
			if ESPLimitToNet and ESPLimitToNet.Object then ESPLimitToNet.Object.Visible = callback end

			if not callback then
				if BeesNotify and BeesNotify.Object then BeesNotify.Object.Visible = false end
				if BeesBackground and BeesBackground.Object then BeesBackground.Object.Visible = false end
				if BeesColor and BeesColor.Object then BeesColor.Object.Visible = false end
				if ShowOtherBeehives and ShowOtherBeehives.Object then ShowOtherBeehives.Object.Visible = false end
				if BeehiveBackground and BeehiveBackground.Object then BeehiveBackground.Object.Visible = false end
				if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = false end
			else
				if BeesESP and BeesESP.Enabled then
					if BeesNotify and BeesNotify.Object then BeesNotify.Object.Visible = true end
					if BeesBackground and BeesBackground.Object then BeesBackground.Object.Visible = true end
					if BeesColor and BeesColor.Object then BeesColor.Object.Visible = BeesBackground.Enabled end
				end
				if BeehiveESP and BeehiveESP.Enabled then
					if ShowOtherBeehives and ShowOtherBeehives.Object then ShowOtherBeehives.Object.Visible = true end
					if BeehiveBackground and BeehiveBackground.Object then BeehiveBackground.Object.Visible = true end
					if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = BeehiveBackground.Enabled end
				end
			end

			if Beekeeper.Enabled then
				if callback then
					if BeesESP.Enabled then setupBeesESP() end
					if BeehiveESP.Enabled then setupBeehiveESP() end
				else
					BeesFolder:ClearAllChildren()
					BeehiveFolder:ClearAllChildren()
					table.clear(BeesReference)
					table.clear(BeehiveReference)
				end
			end
		end
    })
    
    ESPLimitToNet = Beekeeper:CreateToggle({
        Name = 'Limit to Net',
        Default = false,
    })
    
    BeesESP = Beekeeper:CreateToggle({
        Name = 'Bees',
        Default = false,
        Function = function(callback)
            if BeesNotify and BeesNotify.Object then BeesNotify.Object.Visible = callback end
            if BeesBackground and BeesBackground.Object then BeesBackground.Object.Visible = callback end
            if BeesColor and BeesColor.Object then BeesColor.Object.Visible = callback end
            
            if Beekeeper.Enabled and ESPToggle.Enabled then
                if callback then setupBeesESP() else
                    BeesFolder:ClearAllChildren()
                    table.clear(BeesReference)
                end
            end
        end
    })
    
    BeesNotify = Beekeeper:CreateToggle({
        Name = 'Notify',
        Default = false,
    })
    
    BeesBackground = Beekeeper:CreateToggle({
        Name = 'Background',
        Default = true,
        Function = function(callback)
            if BeesColor and BeesColor.Object then BeesColor.Object.Visible = callback end
            for _, v in BeesReference do
                if v and v:FindFirstChild("ImageLabel") then
                    v.ImageLabel.BackgroundTransparency = 1 - (callback and BeesColor.Opacity or 0)
                    if v:FindFirstChild("Blur") then
                        v.Blur.Visible = callback
                    end
                end
            end
        end
    })
    
	BeesColor = Beekeeper:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in BeesReference do
				if v and v:FindFirstChild("ImageLabel") then
					v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					v.ImageLabel.BackgroundTransparency = 1 - opacity
				end
			end
		end,
		Darker = true
	})
    
    BeehiveESP = Beekeeper:CreateToggle({
        Name = 'Beehives',
        Default = false,
        Function = function(callback)
            if ShowOtherBeehives and ShowOtherBeehives.Object then ShowOtherBeehives.Object.Visible = callback end
            if BeehiveBackground and BeehiveBackground.Object then BeehiveBackground.Object.Visible = callback end
            if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = callback end
            
            if Beekeeper.Enabled and ESPToggle.Enabled then
                if callback then setupBeehiveESP() else
                    BeehiveFolder:ClearAllChildren()
                    table.clear(BeehiveReference)
                end
            end
        end
    })
    
    ShowOtherBeehives = Beekeeper:CreateToggle({
        Name = 'Show Others',
        Default = false,
        Function = function(callback)
            if Beekeeper.Enabled and ESPToggle.Enabled and BeehiveESP.Enabled then
                BeehiveFolder:ClearAllChildren()
                table.clear(BeehiveReference)
                setupBeehiveESP()
            end
        end
    })
    
    BeehiveBackground = Beekeeper:CreateToggle({
        Name = 'Beehive Background',
        Default = true,
        Function = function(callback)
            if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = callback end
            for _, ref in BeehiveReference do
                if ref and ref.billboard then
                    local frame = ref.billboard:FindFirstChild("Frame")
                    if frame then
                        if ref.isMaxed and ref.isOwn then
                            frame.BackgroundTransparency = 1 - (callback and 0.5 or 0)
                        else
                            frame.BackgroundTransparency = 1 - (callback and BeehiveColor.Opacity or 0)
                        end
                    end
                    if ref.billboard:FindFirstChild("Blur") then
                        ref.billboard.Blur.Visible = callback
                    end
                end
            end
        end
    })
    
    BeehiveColor = Beekeeper:CreateColorSlider({
        Name = 'Beehive Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, ref in BeehiveReference do
                if ref and ref.billboard then
                    local frame = ref.billboard:FindFirstChild("Frame")
                    if frame and not (ref.isMaxed and ref.isOwn) then
                        frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                        frame.BackgroundTransparency = 1 - opacity
                    end
                end
            end
        end,
        Darker = true
    })
    
    AutoDeposit = Beekeeper:CreateToggle({
        Name = 'Auto Deposit',
        Default = false,
		Function = function(callback)
			if DepositDelay and DepositDelay.Object then DepositDelay.Object.Visible = callback end
			if DepositDelaySlider and DepositDelaySlider.Object then DepositDelaySlider.Object.Visible = (callback and DepositDelay.Enabled) end
			if DepositRange and DepositRange.Object then DepositRange.Object.Visible = callback end
			if HiveLimit and HiveLimit.Object then HiveLimit.Object.Visible = callback end
			
			if not callback then
				if DepositDelaySlider and DepositDelaySlider.Object then DepositDelaySlider.Object.Visible = false end
			end

			if callback and Beekeeper.Enabled then
				startDeposit()
			else
				depositRunning = false
			end
		end
    })
    
    DepositDelay = Beekeeper:CreateToggle({
        Name = 'Deposit Delay',
        Default = false,
        Function = function(callback)
            if DepositDelaySlider and DepositDelaySlider.Object then
                DepositDelaySlider.Object.Visible = callback
            end
        end
    })
    
    DepositDelaySlider = Beekeeper:CreateSlider({
        Name = 'Deposit Delay',
        Min = 0,
        Max = 2,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
    })
    
    DepositRange = Beekeeper:CreateSlider({
        Name = 'Deposit Range',
        Min = 1,
        Max = 10,
        Default = 10,
        Decimal = 1,
        Suffix = ' studs',
    })
    
    HiveLimit = Beekeeper:CreateSlider({
        Name = 'Hive Limit',
        Min = 1,
        Max = 20,
        Default = 12,
        Decimal = 1,
        Suffix = ' bees',
        Function = function()
            table.clear(maxedBeehives)
            table.clear(maxedNotificationSent)
        end
    })
	task.defer(function()
		if HiveLimit and HiveLimit.Object then HiveLimit.Object.Visible = AutoDeposit.Enabled end
		if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = CollectionDelay.Enabled end
		if not ESPToggle.Enabled or not BeesESP.Enabled then
			if BeesNotify and BeesNotify.Object then BeesNotify.Object.Visible = false end
			if BeesBackground and BeesBackground.Object then BeesBackground.Object.Visible = false end
			if BeesColor and BeesColor.Object then BeesColor.Object.Visible = false end
		else
			if BeesColor and BeesColor.Object then BeesColor.Object.Visible = BeesBackground.Enabled end
		end

		if not ESPToggle.Enabled or not BeehiveESP.Enabled then
			if ShowOtherBeehives and ShowOtherBeehives.Object then ShowOtherBeehives.Object.Visible = false end
			if BeehiveBackground and BeehiveBackground.Object then BeehiveBackground.Object.Visible = false end
			if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = false end
		else
			if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = BeehiveBackground.Enabled end
		end

		if AutoDeposit and not AutoDeposit.Enabled then
			if DepositDelay and DepositDelay.Object then DepositDelay.Object.Visible = false end
			if DepositDelaySlider and DepositDelaySlider.Object then DepositDelaySlider.Object.Visible = false end
			if DepositRange and DepositRange.Object then DepositRange.Object.Visible = false end
		end

		if DepositDelaySlider and DepositDelaySlider.Object then
			DepositDelaySlider.Object.Visible = (AutoDeposit.Enabled and DepositDelay.Enabled)
		end
	end)
end)
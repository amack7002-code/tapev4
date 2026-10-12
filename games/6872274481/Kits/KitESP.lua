run(function()
	local KitESP
	local Notify
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
    local currentSize = 36
	Folder.Parent = vape.gui
	
	local ESPKits = {
		alchemist = {'alchemist_ingedients', 'thorns'},
		beekeeper = {'bee', 'bee'},
		bigman = {'treeOrb', 'natures_essence_1'},
		ghost_catcher = {'ghost', 'ghost_orb'},
		metal_detector = {'hidden-metal', 'iron'},
		sheep_herder = {'SheepModel', 'purple_hay_bale'},
		sorcerer = {'alchemy_crystal', 'wild_flower'},
		star_collector = {'stars', 'crit_star'},
		black_market_trader = {'shadow_coin', 'shadow_coin'},
		miner = {'petrified-player', 'large_rock'},
		trapper = {'snap_trap', 'snap_trap'},
		mage = {'ElementTome', 'mage_spellbook'},
	}
	local NONTaggedKits = {
		necromancer = {'Gravestone', true},
		battery = {'Open', true},
	}
	local DescendantKits = {
		['farmer_cletus'] = {
			{'carrot', 'carrot_seeds'},
			{'melon', 'melon_seeds'},
			{'pumpkin', 'pumpkin_seeds'},
		},
	}

	local function isMineOnMyTeam(part)
		local teamAttr = part:GetAttribute('Team') or part:GetAttribute('TeamId') or part:GetAttribute('TeamID')
		if teamAttr then
			local myTeam = lplr:GetAttribute('Team') or lplr:GetAttribute('TeamId') or lplr:GetAttribute('TeamID')
			if myTeam and tostring(teamAttr) == tostring(myTeam) then
				return true
			end
		end
		local placedBy = part:GetAttribute('PlacedByUserId')
		if placedBy then
			local player = playersService:GetPlayerByUserId(placedBy)
			if player then
				local myTeam = lplr:GetAttribute('Team')
				if myTeam and player:GetAttribute('Team') == myTeam then
					return true
				end
			end
		end
		return false
	end

	local function getAlchemistImage(v)
		local name = v and v.Name or ''
		if name == 'Mushrooms' then
			return bedwars.getIcon({itemType = 'mushrooms'}, true)
		elseif name == 'Thorns' then
			return bedwars.getIcon({itemType = 'thorns'}, true)
		else
			return bedwars.getIcon({itemType = 'wild_flower'}, true)
		end
	end

	local function getStarImage(v)
		local parent = v and v.Parent
		if parent and parent:IsA("Model") then
			local modelName = parent.Name
			if modelName == "CritStar" or modelName:lower():find("crit") then
				return bedwars.getIcon({itemType = 'crit_star'}, true)
			elseif modelName == "VitalityStar" or modelName:lower():find("vitality") then
				return bedwars.getIcon({itemType = 'vitality_star'}, true)
			end
		end
		return bedwars.getIcon({itemType = 'crit_star'}, true)
	end

	local function Added(v, icon, non)
		if Reference[v] then return end
		if Notify.Enabled then
			vape:CreateNotification("KitESP", `New object is added {v.Name}`, 2)
		end
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = icon
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(currentSize, currentSize)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.fromOffset(currentSize, currentSize)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		if non then
			image.Image = icon
		else
			image.Image = bedwars.getIcon({itemType = icon}, true)
		end
		image.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		Reference[v] = billboard
	end

	local function AddedStar(v)
		if not v or not v.Parent then return end
		if Reference[v] then return end

		if Notify.Enabled then
			vape:CreateNotification("KitESP", `New object is added {v.Name}`, 2)
		end
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'star'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(currentSize, currentSize)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.fromOffset(currentSize, currentSize)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		image.Image = getStarImage(v)
		image.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		Reference[v] = billboard
	end
	
	local currentConnections = {}
	local currentKit = nil

	local function disconnectAll()
		for _, conn in ipairs(currentConnections) do
			conn:Disconnect()
		end
		table.clear(currentConnections)
	end

	local function isRealBee(v)
		if not v then return false end

		local beeId = v:GetAttribute('BeeId')

		if beeId == nil then
			local part = v.PrimaryPart or v:FindFirstChildWhichIsA('BasePart', true)
			beeId = part and part:GetAttribute('BeeId')
		end

		return beeId ~= nil and beeId > -1
	end

	local function addKit(tag, icon)
		if tag == 'bee' then
			local beeIcon = bedwars.getIcon({itemType = 'bee'}, true)
			for _, tagName in {'bee', 'MeadowBee', 'ChromaBee'} do
				local connAdded = collectionService:GetInstanceAddedSignal(tagName):Connect(function(v)
					if v:IsA("Model") and v.PrimaryPart then
						task.wait(0.1)
						if isRealBee(v) then
							Added(v.PrimaryPart, beeIcon, true)
						end
					end
				end)
				table.insert(currentConnections, connAdded)
				local connRemoved = collectionService:GetInstanceRemovedSignal(tagName):Connect(function(v)
					if v.PrimaryPart and Reference[v.PrimaryPart] then
						Reference[v.PrimaryPart]:Destroy()
						Reference[v.PrimaryPart] = nil
					end
				end)
				table.insert(currentConnections, connRemoved)
				for _, v in collectionService:GetTagged(tagName) do
					if v:IsA("Model") and v.PrimaryPart and isRealBee(v) then
						Added(v.PrimaryPart, beeIcon, true)
					end
				end
			end
			return
		end
		if tag == 'alchemist_ingedients' then
			local connAdded = collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
				if v.PrimaryPart then
					task.wait(0.1)
					if Reference[v.PrimaryPart] then return end
					local billboard = Instance.new('BillboardGui')
					billboard.Parent = Folder
					billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
					billboard.Size = UDim2.fromOffset(currentSize, currentSize)
					billboard.AlwaysOnTop = true
					billboard.ClipsDescendants = false
					billboard.Adornee = v.PrimaryPart
					local blur = addBlur(billboard)
					blur.Visible = Background.Enabled
					local image = Instance.new('ImageLabel')
					image.Size = UDim2.fromOffset(currentSize, currentSize)
					image.Position = UDim2.fromScale(0.5, 0.5)
					image.AnchorPoint = Vector2.new(0.5, 0.5)
					image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
					image.BorderSizePixel = 0
					image.Image = getAlchemistImage(v)
					image.Parent = billboard
					local uicorner = Instance.new('UICorner')
					uicorner.CornerRadius = UDim.new(0, 4)
					uicorner.Parent = image
					Reference[v.PrimaryPart] = billboard
				end
			end)
			table.insert(currentConnections, connAdded)
			local connRemoved = collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
				if v.PrimaryPart and Reference[v.PrimaryPart] then
					Reference[v.PrimaryPart]:Destroy()
					Reference[v.PrimaryPart] = nil
				end
			end)
			table.insert(currentConnections, connRemoved)
			for _, v in collectionService:GetTagged(tag) do
				if v.PrimaryPart and not Reference[v.PrimaryPart] then
					local billboard = Instance.new('BillboardGui')
					billboard.Parent = Folder
					billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
					billboard.Size = UDim2.fromOffset(currentSize, currentSize)
					billboard.AlwaysOnTop = true
					billboard.ClipsDescendants = false
					billboard.Adornee = v.PrimaryPart
					local blur = addBlur(billboard)
					blur.Visible = Background.Enabled
					local image = Instance.new('ImageLabel')
					image.Size = UDim2.fromOffset(currentSize, currentSize)
					image.Position = UDim2.fromScale(0.5, 0.5)
					image.AnchorPoint = Vector2.new(0.5, 0.5)
					image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
					image.BorderSizePixel = 0
					image.Image = getAlchemistImage(v)
					image.Parent = billboard
					local uicorner = Instance.new('UICorner')
					uicorner.CornerRadius = UDim.new(0, 4)
					uicorner.Parent = image
					Reference[v.PrimaryPart] = billboard
				end
			end
			return
		end
		if tag == 'stars' then
			local connAdded = collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
				if v:IsA("Model") and v.PrimaryPart then
					task.wait(0.1)
					AddedStar(v.PrimaryPart)
				end
			end)
			table.insert(currentConnections, connAdded)
			local connRemoved = collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
				if v.PrimaryPart and Reference[v.PrimaryPart] then
					Reference[v.PrimaryPart]:Destroy()
					Reference[v.PrimaryPart] = nil
				end
			end)
			table.insert(currentConnections, connRemoved)
			for _, v in collectionService:GetTagged(tag) do
				if v:IsA("Model") and v.PrimaryPart then
					AddedStar(v.PrimaryPart)
				end
			end
			return
		end

		if tag == 'petrified-player' then
			local connAdded = collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
				if v.PrimaryPart and not isMineOnMyTeam(v.PrimaryPart) then
					Added(v.PrimaryPart, icon, false)
				end
			end)
			table.insert(currentConnections, connAdded)
			local connRemoved = collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
				if v.PrimaryPart and Reference[v.PrimaryPart] then
					Reference[v.PrimaryPart]:Destroy()
					Reference[v.PrimaryPart] = nil
				end
			end)
			table.insert(currentConnections, connRemoved)
			for _, v in collectionService:GetTagged(tag) do
				if v.PrimaryPart and not isMineOnMyTeam(v.PrimaryPart) then
					Added(v.PrimaryPart, icon, false)
				end
			end
			return
		end

		local connAdded = collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if tag == 'bee' and (v.Name:find('TamedBee') or v:FindFirstChild('TamedBee')) then return end
			Added(v.PrimaryPart, icon, false)
		end)
		table.insert(currentConnections, connAdded)
		local connRemoved = collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if Reference[v.PrimaryPart] then
				Reference[v.PrimaryPart]:Destroy()
				Reference[v.PrimaryPart] = nil
			end
		end)
		table.insert(currentConnections, connRemoved)
		for _, v in collectionService:GetTagged(tag) do
			if tag == 'bee' and (v.Name:find('TamedBee') or v:FindFirstChild('TamedBee')) then continue end
			Added(v.PrimaryPart, icon, false)
		end
	end

	local function addKitNon(objName, icon)
		if typeof(icon) == "boolean" then
			if objName == "Gravestone" then
				icon = "rbxassetid://6307844310"
			elseif objName == "Open" then
				icon = "rbxassetid://10159166528"
			else
				icon = bedwars.getIcon({itemType = icon}, true) or ''
			end
		else
			icon = bedwars.getIcon({itemType = icon}, true)
		end
		local connAdded = workspace.ChildAdded:Connect(function(child)
			if child:IsA("Model") and child.Name == objName then
				task.wait(0.1)
				if child.PrimaryPart then
					Added(child, icon, true)
				end
			end
		end)
		table.insert(currentConnections, connAdded)
		local connRemoved = workspace.ChildRemoved:Connect(function(child)
			if child:IsA("Model") and child.Name == objName then
				if Reference[child] then
					Reference[child]:Destroy()
					Reference[child] = nil
				end
			end
		end)
		table.insert(currentConnections, connRemoved)
	end

	local function addKitDescendant(partName, icon)
		local resolvedIcon = bedwars.getIcon({itemType = icon}, true)
		
		local function shouldSkip(obj)
			local p = obj.Parent
			while p and p ~= workspace do
				if p.Name == partName then return true end
				p = p.Parent
			end
			return false
		end

		scanDescendants(workspace, function(obj)
			if obj:IsA("BasePart") and obj.Name == partName and not shouldSkip(obj) then
				if not Reference[obj] then
					Added(obj, resolvedIcon, true)
				end
			end
		end)
		local connAdded = workspace.DescendantAdded:Connect(function(obj)
			if obj:IsA("BasePart") and obj.Name == partName and not shouldSkip(obj) then
				task.wait(0.1)
				if not Reference[obj] then
					Added(obj, resolvedIcon, true)
				end
			end
		end)
		table.insert(currentConnections, connAdded)
		local connRemoved = workspace.DescendantRemoving:Connect(function(obj)
			if obj:IsA("BasePart") and obj.Name == partName and Reference[obj] then
				Reference[obj]:Destroy()
				Reference[obj] = nil
			end
		end)
		table.insert(currentConnections, connRemoved)
	end

	local function setupKit(kitName)
		local kit = ESPKits[kitName]
		local nontag = NONTaggedKits[kitName]
		local desctag = DescendantKits[kitName]
		if kit then
			addKit(kit[1], kit[2])
		end
		if nontag then
			addKitNon(nontag[1], nontag[2])
		end
		if desctag then
			for _, entry in ipairs(desctag) do
				addKitDescendant(entry[1], entry[2])
			end
		end
	end

	KitESP = vape.Categories.Kits:CreateModule({
		Name = 'KitESP',
		Function = function(callback)
			if callback then
				task.spawn(function()
					while KitESP.Enabled do
						if not currentKit then
							repeat
								task.wait()
							until store.equippedKit ~= '' or not KitESP.Enabled
							if not KitESP.Enabled then break end
						end
						local newKit = table.concat(getLocalKits(), ',')
						if newKit ~= currentKit then
							disconnectAll()
							Folder:ClearAllChildren()
							table.clear(Reference)
							for _, kit in ipairs(getLocalKits()) do
								setupKit(kit)
							end
							currentKit = newKit
						end
						task.wait(1)
					end
					disconnectAll()
					Folder:ClearAllChildren()
					table.clear(Reference)
					currentKit = nil
				end)
			else
				disconnectAll()
				Folder:ClearAllChildren()
				table.clear(Reference)
				currentKit = nil
			end
		end,
		Tooltip = 'esp for kits'
	})
	Notify = KitESP:CreateToggle({
		Name = "Notify",
		Default = false
	})
	Background = KitESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, v in Reference do
				v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
    Color = KitESP:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, v in Reference do
                v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                v.ImageLabel.BackgroundTransparency = 1 - opacity
            end
        end,
        Darker = true
    })
    Sizeable = KitESP:CreateToggle({
        Name = "Sizeable",
        Default = false,
        Function = function(callback)
            if callback then
                SizeSlider.Object.Visible = true
                currentSize = SizeSlider.Value or 36
                for _, v in Reference do
                    v.Size = UDim2.fromOffset(currentSize, currentSize)
                    v.ImageLabel.Size = UDim2.fromOffset(currentSize, currentSize)
                end
            else
                SizeSlider.Object.Visible = false
                currentSize = 36
                for _, v in Reference do
                    v.Size = UDim2.fromOffset(currentSize, currentSize)
                    v.ImageLabel.Size = UDim2.fromOffset(currentSize, currentSize)
                end
            end
        end
    })
    SizeSlider = KitESP:CreateSlider({
        Name = "Size",
        Default = 36,
        Min = 10,
        Max = 80,
        Visible = false,
        Function = function(value)
            if not Sizeable.Enabled then return end
            currentSize = value
            for _, v in Reference do
                v.Size = UDim2.fromOffset(value, value)
                v.ImageLabel.Size = UDim2.fromOffset(value, value)
            end
        end
    })

    task.defer(function()
        if Color and Color.Object then
            Color.Object.Visible = Background.Enabled  
        end
    end)
end)
run(function()
	local AutoGompy
	local AutoCollect
	local CollectRange
	local CollectLimit
	local GhostESP
	local ESPBackground
	local ESPColor
	local ESPLimitVacuum
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local Reference = {}
	local ghostIcon
	local collectionActive = false
	local collectRemote = replicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("CollectCollectableEntity")
	local function isHoldingVacuum()
		return isHoldingItem({'vacuum'})
	end

	local function getGhostIcon()
		if not ghostIcon then
			ghostIcon = bedwars.getIcon({itemType = 'ghost_orb'}, true)
		end
		return ghostIcon
	end

	local function Added(obj)
		if Reference[obj] then return end
		local part = not obj:IsA('Model') and obj or obj.PrimaryPart
		if not part then return end
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'ghost'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = part
		local blur = addBlur(billboard)
		blur.Visible = ESPBackground.Enabled
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.fromOffset(36, 36)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(ESPColor.Hue, ESPColor.Sat, ESPColor.Value)
		image.BackgroundTransparency = 1 - (ESPBackground.Enabled and ESPColor.Opacity or 0)
		image.BorderSizePixel = 0
		image.Image = getGhostIcon()
		image.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		Reference[obj] = billboard
	end

	local function Removed(obj)
		if Reference[obj] then
			Reference[obj]:Destroy()
			Reference[obj] = nil
		end
	end

	local function setupESP()
		for _, v in collectionService:GetTagged('ghost') do
			Added(v)
		end
		AutoGompy:Clean(collectionService:GetInstanceAddedSignal('ghost'):Connect(function(v)
			if GhostESP.Enabled then Added(v) end
		end))
		AutoGompy:Clean(collectionService:GetInstanceRemovedSignal('ghost'):Connect(function(v)
			Removed(v)
		end))
		local lastUpdate = 0
		AutoGompy:Clean(runService.RenderStepped:Connect(function()
			if not GhostESP.Enabled then return end
			local now = tick()
			if now - lastUpdate < 0.1 then return end
			lastUpdate = now
			for obj, billboard in pairs(Reference) do
				if not obj or not obj.Parent then
					Removed(obj)
					continue
				end
				local shouldShow = true
				if ESPLimitVacuum.Enabled and not isHoldingVacuum() then
					shouldShow = false
				end
				billboard.Enabled = shouldShow
			end
		end))
	end

	local function startAutoCollect()
		if collectionActive then return end
		collectionActive = true
		task.spawn(function()
			while AutoGompy.Enabled and AutoCollect.Enabled and collectionActive do
				if not entitylib.isAlive then
					task.wait(0.5)
					continue
				end
				if CollectLimit.Enabled and not isHoldingVacuum() then
					task.wait(0.5)
					continue
				end
				local localPosition = entitylib.character.RootPart.Position
				local range = CollectRange.Value
				for _, obj in collectionService:GetTagged('ghost') do
					if not AutoGompy.Enabled or not AutoCollect.Enabled or not collectionActive then break end
					local part = not obj:IsA('Model') and obj or obj.PrimaryPart
					if part and (localPosition - part.Position).Magnitude <= range then
						local id = obj:GetAttribute('Id') or obj:GetAttribute('id')
							or obj:GetAttribute('CollectableId') or tonumber(obj.Name:match('%d+'))
						if id then
							pcall(function() collectRemote:FireServer({ id = id }) end)
							if CollectDelay.Value > 0 then
								task.wait(CollectDelay.Value)
							end
						end
					end
				end
				task.wait(0.1)
			end
			collectionActive = false
		end)
	end

	local function stopAutoCollect()
		collectionActive = false
	end

	AutoGompy = vape.Categories.Kits:CreateModule({
		Name = 'AutoGompy',
		Function = function(callback)
			if callback then
				if GhostESP.Enabled then setupESP() end
				if AutoCollect.Enabled then startAutoCollect() end
			else
				stopAutoCollect()
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'ghost stuff for gompy fr'
	})

	AutoCollect = AutoGompy:CreateToggle({
		Name = 'Auto Collect',
		Tooltip = 'grabs the ghosts for u no cap',
		Function = function(callback)
			if CollectRange and CollectRange.Object then CollectRange.Object.Visible = callback end
			if CollectDelay and CollectDelay.Object then CollectDelay.Object.Visible = callback end
			if CollectLimit and CollectLimit.Object then CollectLimit.Object.Visible = callback end
			if AutoGompy.Enabled then
				if callback then startAutoCollect() else stopAutoCollect() end
			end
		end
	})
	CollectRange = AutoGompy:CreateSlider({
		Name = 'Range',
		Tooltip = 'how far it grabs ghosts gng',
		Min = 10,
		Max = 30,
		Default = 30,
		Visible = false
	})
	CollectDelay = AutoGompy:CreateSlider({
		Name = 'Delay',
		Tooltip = 'wait time between grabs',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100,
		Suffix = 's',
		Visible = false
	})
	CollectLimit = AutoGompy:CreateToggle({
		Name = 'Limit to Vacuum',
		Tooltip = 'only grabs ghosts when ur holding the vacuum'
	})

	GhostESP = AutoGompy:CreateToggle({
		Name = 'Ghost ESP',
		Tooltip = 'shows u where the ghosts at',
		Function = function(callback)
			if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = callback end
			if ESPColor and ESPColor.Object then ESPColor.Object.Visible = (callback and ESPBackground and ESPBackground.Enabled) end
			if ESPLimitVacuum and ESPLimitVacuum.Object then ESPLimitVacuum.Object.Visible = callback end
			if AutoGompy.Enabled then
				if callback then
					setupESP()
				else
					Folder:ClearAllChildren()
					table.clear(Reference)
				end
			end
		end
	})
	ESPBackground = AutoGompy:CreateToggle({
		Name = 'Background',
		Tooltip = 'adds a lil box behind the icon',
		Default = true,
		Function = function(callback)
			if ESPColor and ESPColor.Object then ESPColor.Object.Visible = (callback and GhostESP and GhostESP.Enabled) end
			for _, v in Reference do
				if v and v:FindFirstChild('ImageLabel') then
					local blur = v:FindFirstChild('Blur')
					if blur then blur.Visible = callback end
					v.ImageLabel.BackgroundTransparency = 1 - (callback and ESPColor.Opacity or 0)
				end
			end
		end
	})
	ESPColor = AutoGompy:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Darker = true,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				if v and v:FindFirstChild('ImageLabel') then
					v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					v.ImageLabel.BackgroundTransparency = 1 - opacity
				end
			end
		end
	})
	ESPLimitVacuum = AutoGompy:CreateToggle({
		Name = 'ESP Limit to Vacuum',
		Tooltip = 'only shows ghosts when ur holding the vacuum'
	})

	task.defer(function()
		local collectOn = AutoCollect and AutoCollect.Enabled
		if CollectRange and CollectRange.Object then CollectRange.Object.Visible = collectOn end
		if CollectDelay and CollectDelay.Object then CollectDelay.Object.Visible = collectOn end
		if CollectLimit and CollectLimit.Object then CollectLimit.Object.Visible = collectOn end
		local espOn = GhostESP and GhostESP.Enabled
		if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = espOn end
		if ESPColor and ESPColor.Object then ESPColor.Object.Visible = (espOn and ESPBackground.Enabled) end
		if ESPLimitVacuum and ESPLimitVacuum.Object then ESPLimitVacuum.Object.Visible = espOn end
	end)
end)
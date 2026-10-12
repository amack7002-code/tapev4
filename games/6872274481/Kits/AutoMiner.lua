run(function()
	local AutoMiner
	local AutoCollect
	local CollectRange
	local PetrifiedESP
	local ESPBackground
	local ESPColor
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local Reference = {}
	local rockIcon
	local collectionActive = false

	local function getRockIcon()
		if not rockIcon then
			rockIcon = bedwars.getIcon({itemType = 'large_rock'}, true)
		end
		return rockIcon
	end

	local function Added(obj)
		if Reference[obj] then return end
		local part = not obj:IsA('Model') and obj or obj.PrimaryPart
		if not part then return end
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'petrified-player'
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
		image.Image = getRockIcon()
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
		for _, v in collectionService:GetTagged('petrified-player') do
			Added(v)
		end
		AutoMiner:Clean(collectionService:GetInstanceAddedSignal('petrified-player'):Connect(function(v)
			if PetrifiedESP.Enabled then Added(v) end
		end))
		AutoMiner:Clean(collectionService:GetInstanceRemovedSignal('petrified-player'):Connect(function(v)
			Removed(v)
		end))
		local lastUpdate = 0
		AutoMiner:Clean(runService.RenderStepped:Connect(function()
			if not PetrifiedESP.Enabled then return end
			local now = tick()
			if now - lastUpdate < 0.2 then return end
			lastUpdate = now
			for obj in pairs(Reference) do
				if not obj or not obj.Parent then
					Removed(obj)
				end
			end
		end))
	end

	local function startAutoCollect()
		if collectionActive then return end
		collectionActive = true
		task.spawn(function()
			while AutoMiner.Enabled and AutoCollect.Enabled and collectionActive do
				if not entitylib.isAlive then
					task.wait(0.5)
					continue
				end
				local localPosition = entitylib.character.RootPart.Position
				local range = CollectRange.Value
				for _, obj in collectionService:GetTagged('petrified-player') do
					if not AutoMiner.Enabled or not AutoCollect.Enabled or not collectionActive then break end
					local part = not obj:IsA('Model') and obj or obj.PrimaryPart
					if part and (localPosition - part.Position).Magnitude <= range then
						local petrifyId = obj:GetAttribute('petrifyId') or obj:GetAttribute('PetrifyId')
						if petrifyId then
							pcall(function()
								bedwars.Client:Get(remotes.DestroyPetrifiedPlayer):SendToServer({ petrifyId = petrifyId })
							end)
							task.wait(0.1)
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

	AutoMiner = vape.Categories.Kits:CreateModule({
		Name = 'AutoMiner',
		Function = function(callback)
			if callback then
				if PetrifiedESP.Enabled then setupESP() end
				if AutoCollect.Enabled then startAutoCollect() end
			else
				stopAutoCollect()
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'frees petrified players + esp for miner'
	})

	AutoCollect = AutoMiner:CreateToggle({
		Name = 'Auto Collect',
		Tooltip = 'auto frees the petrified players',
		Function = function(callback)
			if CollectRange and CollectRange.Object then CollectRange.Object.Visible = callback end
			if AutoMiner.Enabled then
				if callback then startAutoCollect() else stopAutoCollect() end
			end
		end
	})
	CollectRange = AutoMiner:CreateSlider({
		Name = 'Range',
		Tooltip = 'how far it collects em from',
		Min = 1,
		Max = 10,
		Default = 6,
		Visible = false
	})

	PetrifiedESP = AutoMiner:CreateToggle({
		Name = 'Petrified ESP',
		Tooltip = 'shows u where the petrified players at',
		Function = function(callback)
			if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = callback end
			if ESPColor and ESPColor.Object then ESPColor.Object.Visible = (callback and ESPBackground and ESPBackground.Enabled) end
			if AutoMiner.Enabled then
				if callback then
					setupESP()
				else
					Folder:ClearAllChildren()
					table.clear(Reference)
				end
			end
		end
	})
	ESPBackground = AutoMiner:CreateToggle({
		Name = 'Background',
		Default = true,
		Function = function(callback)
			if ESPColor and ESPColor.Object then ESPColor.Object.Visible = (callback and PetrifiedESP and PetrifiedESP.Enabled) end
			for _, v in Reference do
				if v and v:FindFirstChild('ImageLabel') then
					local blur = v:FindFirstChild('Blur')
					if blur then blur.Visible = callback end
					v.ImageLabel.BackgroundTransparency = 1 - (callback and ESPColor.Opacity or 0)
				end
			end
		end
	})
	ESPColor = AutoMiner:CreateColorSlider({
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

	task.defer(function()
		local collectOn = AutoCollect and AutoCollect.Enabled
		if CollectRange and CollectRange.Object then CollectRange.Object.Visible = collectOn end
		local espOn = PetrifiedESP and PetrifiedESP.Enabled
		if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = espOn end
		if ESPColor and ESPColor.Object then ESPColor.Object.Visible = (espOn and ESPBackground.Enabled) end
	end)
end)
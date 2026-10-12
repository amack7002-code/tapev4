run(function()
	local AutoDeathAdder
	local AutoCollect
	local CollectRange
	local CrystalESP
	local ESPBackground
	local ESPColor
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local Reference = {}
	local crystalIcon
	local collectionActive = false
	local collectRemote = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('CollectCollectableEntity')

	local function getCrystalIcon()
		if not crystalIcon then
			crystalIcon = bedwars.getIcon({itemType = 'wild_flower'}, true)
		end
		return crystalIcon
	end

	local function Added(obj)
		if Reference[obj] then return end
		local part = not obj:IsA('Model') and obj or obj.PrimaryPart
		if not part then return end
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'alchemy_crystal'
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
		image.Image = getCrystalIcon()
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
		for _, v in collectionService:GetTagged('alchemy_crystal') do
			Added(v)
		end
		AutoDeathAdder:Clean(collectionService:GetInstanceAddedSignal('alchemy_crystal'):Connect(function(v)
			if CrystalESP.Enabled then Added(v) end
		end))
		AutoDeathAdder:Clean(collectionService:GetInstanceRemovedSignal('alchemy_crystal'):Connect(function(v)
			Removed(v)
		end))
		local lastUpdate = 0
		AutoDeathAdder:Clean(runService.RenderStepped:Connect(function()
			if not CrystalESP.Enabled then return end
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
			while AutoDeathAdder.Enabled and AutoCollect.Enabled and collectionActive do
				if not entitylib.isAlive then
					task.wait(0.5)
					continue
				end
				local localPosition = entitylib.character.RootPart.Position
				local range = CollectRange.Value
				for _, obj in collectionService:GetTagged('alchemy_crystal') do
					if not AutoDeathAdder.Enabled or not AutoCollect.Enabled or not collectionActive then break end
					local part = not obj:IsA('Model') and obj or obj.PrimaryPart
					if part and (localPosition - part.Position).Magnitude <= range then
						local id = obj:GetAttribute('Id') or obj:GetAttribute('id')
							or obj:GetAttribute('CollectableId') or tonumber(obj.Name:match('%d+'))
						if id then
							pcall(function()
								bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
							end)
							pcall(function()
								bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
							end)
							pcall(function()
								collectRemote:FireServer({ id = id, collectableName = 'AlchemyCrystal' })
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

	AutoDeathAdder = vape.Categories.Kits:CreateModule({
		Name = 'AutoDeathAdder',
		Function = function(callback)
			if callback then
				if CrystalESP.Enabled then setupESP() end
				if AutoCollect.Enabled then startAutoCollect() end
			else
				stopAutoCollect()
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'grabs crystals + esp for deathadder'
	})

	AutoCollect = AutoDeathAdder:CreateToggle({
		Name = 'Auto Collect',
		Tooltip = 'auto grabs the crystals no cap',
		Function = function(callback)
			if CollectRange and CollectRange.Object then CollectRange.Object.Visible = callback end
			if CollectDelay and CollectDelay.Object then CollectDelay.Object.Visible = callback end
			if AutoDeathAdder.Enabled then
				if callback then startAutoCollect() else stopAutoCollect() end
			end
		end
	})
	CollectRange = AutoDeathAdder:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 10,
		Default = 10,
		Visible = false
	})
	CollectDelay = AutoDeathAdder:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100,
		Suffix = 's',
		Visible = false
	})

	CrystalESP = AutoDeathAdder:CreateToggle({
		Name = 'Crystal ESP',
		Tooltip = 'shows u where the crystals at',
		Function = function(callback)
			if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = callback end
			if ESPColor and ESPColor.Object then ESPColor.Object.Visible = (callback and ESPBackground and ESPBackground.Enabled) end
			if AutoDeathAdder.Enabled then
				if callback then
					setupESP()
				else
					Folder:ClearAllChildren()
					table.clear(Reference)
				end
			end
		end
	})
	ESPBackground = AutoDeathAdder:CreateToggle({
		Name = 'Background',
		Default = true,
		Function = function(callback)
			if ESPColor and ESPColor.Object then ESPColor.Object.Visible = (callback and CrystalESP and CrystalESP.Enabled) end
			for _, v in Reference do
				if v and v:FindFirstChild('ImageLabel') then
					local blur = v:FindFirstChild('Blur')
					if blur then blur.Visible = callback end
					v.ImageLabel.BackgroundTransparency = 1 - (callback and ESPColor.Opacity or 0)
				end
			end
		end
	})
	ESPColor = AutoDeathAdder:CreateColorSlider({
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
		if CollectDelay and CollectDelay.Object then CollectDelay.Object.Visible = collectOn end
		local espOn = CrystalESP and CrystalESP.Enabled
		if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = espOn end
		if ESPColor and ESPColor.Object then ESPColor.Object.Visible = (espOn and ESPBackground.Enabled) end
	end)
end)
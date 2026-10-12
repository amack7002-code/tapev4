run(function()
	local AutoCrypt
	local AutoCollect
	local CollectRange
	local SoulESP
	local ESPBackground
	local ESPColor
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local Reference = {}
	local collectionActive = false

	local function Added(obj)
		if Reference[obj] then return end
		local part = not obj:IsA('Model') and obj or obj.PrimaryPart
		if not part then return end
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'Gravestone'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = part
		local blur = addBlur(billboard)
		blur.Visible = ESPBackground.Enabled
		local image = Instance.new('TextLabel')
		image.Name = 'Icon'
		image.Size = UDim2.fromOffset(36, 36)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(ESPColor.Hue, ESPColor.Sat, ESPColor.Value)
		image.BackgroundTransparency = 1 - (ESPBackground.Enabled and ESPColor.Opacity or 0)
		image.BorderSizePixel = 0
		image.Text = '👻'
		image.TextSize = 26
		image.TextColor3 = Color3.fromRGB(255, 255, 255)
		image.Font = Enum.Font.GothamBold
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
		for _, v in collectionService:GetTagged('Gravestone') do
			Added(v)
		end
		AutoCrypt:Clean(collectionService:GetInstanceAddedSignal('Gravestone'):Connect(function(v)
			if SoulESP.Enabled then Added(v) end
		end))
		AutoCrypt:Clean(collectionService:GetInstanceRemovedSignal('Gravestone'):Connect(function(v)
			Removed(v)
		end))
		local lastUpdate = 0
		AutoCrypt:Clean(runService.RenderStepped:Connect(function()
			if not SoulESP.Enabled then return end
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
			while AutoCrypt.Enabled and AutoCollect.Enabled and collectionActive do
				if not entitylib.isAlive then
					task.wait(0.5)
					continue
				end
				local localPosition = entitylib.character.RootPart.Position
				local range = CollectRange.Value
				for _, obj in collectionService:GetTagged('Gravestone') do
					if not AutoCrypt.Enabled or not AutoCollect.Enabled or not collectionActive then break end
					local part = not obj:IsA('Model') and obj or obj.PrimaryPart
					if part and (localPosition - part.Position).Magnitude <= range then
						local armorType = obj:GetAttribute('ArmorType')
						local weaponType = obj:GetAttribute('SwordType')
						local associatedPlayerUserId = obj:GetAttribute('GravestonePlayerUserId')
						local secret = obj:GetAttribute('GravestoneSecret')
						local position = obj:GetAttribute('GravestonePosition')
						if secret then
							local ok, result = pcall(function()
								return bedwars.Client:Get(remotes.ActivateGravestone).instance:InvokeServer({
									skeletonData = {
										armorType = armorType,
										weaponType = weaponType,
										associatedPlayerUserId = associatedPlayerUserId
									},
									secret = secret,
									position = position
								})
							end)
							if ok and result and result.success then
								local NecroController = bedwars.Knit.Controllers.NecromancerController
								if NecroController then
									pcall(function()
										NecroController:useGravestone(lplr, obj)
									end)
								end
							end
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

	AutoCrypt = vape.Categories.Kits:CreateModule({
		Name = 'AutoCrypt',
		Function = function(callback)
			if callback then
				if SoulESP.Enabled then setupESP() end
				if AutoCollect.Enabled then startAutoCollect() end
			else
				stopAutoCollect()
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'grabs gravestones + esp for crypt'
	})

	AutoCollect = AutoCrypt:CreateToggle({
		Name = 'Auto Collect',
		Tooltip = 'auto uses the gravestones no cap',
		Function = function(callback)
			if CollectRange and CollectRange.Object then CollectRange.Object.Visible = callback end
			if CollectDelay and CollectDelay.Object then CollectDelay.Object.Visible = callback end
			if AutoCrypt.Enabled then
				if callback then startAutoCollect() else stopAutoCollect() end
			end
		end
	})
	CollectRange = AutoCrypt:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 40,
		Default = 12,
		Visible = false
	})
	CollectDelay = AutoCrypt:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100,
		Suffix = 's',
		Visible = false
	})

	SoulESP = AutoCrypt:CreateToggle({
		Name = 'SoulESP',
		Tooltip = 'shows u where the gravestones at',
		Function = function(callback)
			if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = callback end
			if ESPColor and ESPColor.Object then ESPColor.Object.Visible = (callback and ESPBackground and ESPBackground.Enabled) end
			if AutoCrypt.Enabled then
				if callback then
					setupESP()
				else
					Folder:ClearAllChildren()
					table.clear(Reference)
				end
			end
		end
	})
	ESPBackground = AutoCrypt:CreateToggle({
		Name = 'Background',
		Default = true,
		Function = function(callback)
			if ESPColor and ESPColor.Object then ESPColor.Object.Visible = (callback and SoulESP and SoulESP.Enabled) end
			for _, v in Reference do
				if v and v:FindFirstChild('Icon') then
					local blur = v:FindFirstChild('Blur')
					if blur then blur.Visible = callback end
					v.Icon.BackgroundTransparency = 1 - (callback and ESPColor.Opacity or 0)
				end
			end
		end
	})
	ESPColor = AutoCrypt:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Darker = true,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				if v and v:FindFirstChild('Icon') then
					v.Icon.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					v.Icon.BackgroundTransparency = 1 - opacity
				end
			end
		end
	})

	task.defer(function()
		local collectOn = AutoCollect and AutoCollect.Enabled
		if CollectRange and CollectRange.Object then CollectRange.Object.Visible = collectOn end
		if CollectDelay and CollectDelay.Object then CollectDelay.Object.Visible = collectOn end
		local espOn = SoulESP and SoulESP.Enabled
		if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = espOn end
		if ESPColor and ESPColor.Object then ESPColor.Object.Visible = (espOn and ESPBackground.Enabled) end
	end)
end)
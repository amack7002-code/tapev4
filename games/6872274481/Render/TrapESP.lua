run(function()
	local TrapESP
	local Background = {}
	local Color = {}
	local Snap, Venom, Explosive, Landmine, Tesla, Gloop
	local Reference = {}
	local Watch = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui

	local Tags = {
		'snap_trap',
		'trapper_trap',
		'invisible-landmine',
		'invisible_landmine',
		'tesla-trap',
		'tesla_trap',
		'glue_trap',
		'GlueTrap'
	}

	local function getToggle(kind)
		return kind == 'snap' and Snap
			or kind == 'venom' and Venom
			or kind == 'explosive' and Explosive
			or kind == 'landmine' and Landmine
			or kind == 'tesla' and Tesla
			or kind == 'gloop' and Gloop
	end

	local function getTrap(v, tag)
		if tag == 'trapper_trap' then
			local trapType = tostring(
				v:GetAttribute('trapType')
				or v:GetAttribute('TrapType')
				or v:GetAttribute('Type')
				or ''
			):lower()

			if trapType:find('venom', 1, true)
				or v.Name:lower():find('venom', 1, true)
				or v:FindFirstChild('venom_trap', true) then
				return 'venom', 'venom_trap'
			end

			if trapType:find('explosive', 1, true)
				or v.Name:lower():find('explosive', 1, true)
				or v:FindFirstChild('explosive_trap', true) then
				return 'explosive', 'explosive_trap'
			end

			if trapType:find('snap', 1, true)
				or v.Name:lower():find('snap', 1, true)
				or v:FindFirstChild('snap_trap', true) then
				return 'snap', 'snap_trap'
			end

			return
		elseif tag == 'snap_trap' then
			return 'snap', 'snap_trap'
		elseif tag == 'invisible-landmine' or tag == 'invisible_landmine' then
			return 'landmine', 'invisible_landmine'
		elseif tag == 'tesla-trap' or tag == 'tesla_trap' then
			return 'tesla', 'tesla_trap'
		elseif tag == 'glue_trap' or tag == 'GlueTrap' or v.Name == 'GlueTrap' then
			return 'gloop', 'glue_projectile'
		end
	end

	local function isFriendly(v)
		local owner = tonumber(v:GetAttribute('PlacedByUserId') or v:GetAttribute('ownerId'))
		if owner and owner == lplr.UserId then
			return true
		end

		local teamName = lplr.Team and lplr.Team.Name
		local teamId = lplr:GetAttribute('Team')

		for _, attribute in {'SnapTrapTeamId', 'TrapperTeamId', 'LandmineTeam', 'TeamId'} do
			local value = v:GetAttribute(attribute)
			if value ~= nil then
				if typeof(value) == 'Instance' then
					value = value.Name
				end
				value = tostring(value)

				if (teamName and value == tostring(teamName))
					or (teamId ~= nil and value == tostring(teamId)) then
					return true
				end
			end
		end

		return false
	end

	local function remove(v)
		if Reference[v] then
			Reference[v]:Destroy()
			Reference[v] = nil
		end
		if Watch[v] then
			for _, conn in Watch[v] do
				conn:Disconnect()
			end
			Watch[v] = nil
		end
	end

	local function clearAll()
		for v in Watch do
			remove(v)
		end
		for v in Reference do
			remove(v)
		end
		Folder:ClearAllChildren()
	end

	local function pickAdornee(v)
		if v:IsA('BasePart') then return v end
		if v:IsA('Model') and v.PrimaryPart then return v.PrimaryPart end
		local best, size = nil, -1
		for _, part in v:GetDescendants() do
			if part:IsA('BasePart') and part.Transparency < 1 then
				local vol = part.Size.X * part.Size.Y * part.Size.Z
				if vol > size then
					best, size = part, vol
				end
			end
		end
		return best or v:FindFirstChildWhichIsA('BasePart', true)
	end

	local function added(v, icon, kind)
		if Reference[v] or isFriendly(v) then return end

		local toggle = getToggle(kind)
		if not toggle or not toggle.Enabled then return end

		local adornee = pickAdornee(v)

		if not adornee then return end

		Watch[v] = {
			v.AncestryChanged:Connect(function(_, parent)
				if not parent then
					remove(v)
				end
			end),
			v.AttributeChanged:Connect(function()
				if isFriendly(v) then
					remove(v)
				end
			end)
		}

		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = icon
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = adornee

		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled

		local image = Instance.new('ImageLabel')
		image.Name = 'ImageLabel'
		image.Size = UDim2.fromOffset(36, 36)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		image.Image = bedwars.getIcon({itemType = icon}, true)
		image.Parent = billboard

		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = image

		Reference[v] = billboard
	end

	local function addByTag(v, tag)
		local kind, icon = getTrap(v, tag)
		if kind then
			added(v, icon, kind)
		end
	end

	local function addGloop(v)
		if v.Name ~= 'GlueTrap' then return end

		task.spawn(function()
			for _ = 1, 12 do
				if not TrapESP.Enabled or not v.Parent then return end

				addByTag(v, 'GlueTrap')

				if Reference[v] then
					return
				end

				task.wait(0.05)
			end
		end)
	end

	local function refresh()
		clearAll()

		if not TrapESP.Enabled then return end

		for _, tag in Tags do
			for _, v in collectionService:GetTagged(tag) do
				addByTag(v, tag)
			end
		end
	end

	TrapESP = vape.Categories.Render:CreateModule({
		Name = 'TrapESP',
		Function = function(callback)
			if callback then
				TrapESP:Clean(workspace.DescendantAdded:Connect(function(v)
					if v.Name == 'GlueTrap' then
						addGloop(v)
					end
				end))

				for _, v in workspace:GetDescendants() do
					if v.Name == 'GlueTrap' then
						addGloop(v)
					end
				end
				for _, tag in Tags do
					TrapESP:Clean(collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
						addByTag(v, tag)
					end))

					TrapESP:Clean(collectionService:GetInstanceRemovedSignal(tag):Connect(remove))
				end

				refresh()
				TrapESP:Clean(runService.Heartbeat:Connect(function()
					for v, bb in Reference do
						if not v.Parent or not bb.Adornee or not bb.Adornee.Parent then
							remove(v)
						end
					end
				end))
			else
				clearAll()
			end
		end,
		Tooltip = 'shows the traps u choose through walls'
	})

	local function trapToggle(name)
		return TrapESP:CreateToggle({
			Name = name,
			Default = true,
			Function = refresh
		})
	end

	Snap = trapToggle('Snap traps')
	Venom = trapToggle('Venom traps')
	Explosive = trapToggle('Explosive traps')
	Landmine = trapToggle('Landmines')
	Tesla = trapToggle('Tesla traps')
	Gloop = trapToggle('Gloops')

	Background = TrapESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end

			for _, v in Reference do
				v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true,
		Visible = true
	})

	Color = TrapESP:CreateColorSlider({
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
end)
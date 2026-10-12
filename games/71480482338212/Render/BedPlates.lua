run(function()
	local BedPlates
	local Background
	local Color
	local Counter
	local Reach
	local Reference = {}
	local folder = Instance.new('Folder')
	folder.Parent = vape.gui
	vape:Clean(folder)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include

	-- the kinds of block stacked around a bed, most of them first
	local function scan(hitbox)
		local container = workspace:FindFirstChild('PlayersBlocksContainer')
		if not container then return {} end
		overlap.FilterDescendantsInstances = {container}
		local reach = Reach.Value * 3 * 2
		local counts, seen = {}, {}
		for _, part in workspace:GetPartBoundsInBox(hitbox.CFrame, hitbox.Size + Vector3.new(reach, reach, reach), overlap) do
			local node = part
			while node.Parent and node.Parent.Parent ~= container and node.Parent ~= container do
				node = node.Parent
			end
			local kind = node.Parent and node.Parent ~= container and node.Parent.Name or node.Name
			-- a block made of several parts counts once
			if not seen[node] then
				seen[node] = true
				counts[kind] = (counts[kind] or 0) + 1
			end
		end
		local list = {}
		for kind, amount in counts do
			table.insert(list, {kind, amount})
		end
		table.sort(list, function(a, b)
			return a[2] == b[2] and a[1] < b[1] or a[2] > b[2]
		end)
		return list
	end

	local function refresh(billboard)
		local frame = billboard.Frame
		local list = scan(billboard.Adornee)
		local key = ''
		for _, entry in list do
			key ..= entry[1]..entry[2]..';'
		end
		if frame:GetAttribute('Shown') == key then return end
		frame:SetAttribute('Shown', key)
		for _, obj in frame:GetChildren() do
			if obj:IsA('ImageLabel') or obj:IsA('TextLabel') then
				obj:Destroy()
			end
		end
		billboard.Enabled = #list > 0
		for index, entry in list do
			if index > 6 then break end
			local data = bedfight.ItemsData and bedfight.ItemsData[entry[1]]
			local image = Instance.new('ImageLabel')
			image.Size = UDim2.fromOffset(32, 32)
			image.BackgroundTransparency = 1
			image.Image = data and data.Image or ''
			image.Parent = frame
			local amount = Instance.new('TextLabel')
			amount.Name = 'Amount'
			amount.Size = UDim2.fromScale(1, 1)
			amount.BackgroundTransparency = 1
			-- a kind with no picture is named
			amount.Text = (data and data.Image) and (Counter.Enabled and tostring(entry[2]) or '') or entry[1]:sub(1, 6)
			amount.TextColor3 = Color3.new(1, 1, 1)
			amount.TextSize = (data and data.Image) and 16 or 10
			amount.TextStrokeTransparency = 0.3
			amount.Font = Enum.Font.Arial
			amount.Parent = image
		end
	end

	-- nothing may ever be parented into a bed, the game treats that as bed ESP
	local function added(bed)
		if Reference[bed] then return end
		local hitbox = bed:IsA('Model') and bed:WaitForChild('BedHitbox', 5)
		if not hitbox or Reference[bed] or not BedPlates.Enabled then return end
		local billboard = Instance.new('BillboardGui')
		billboard.Name = 'bed'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = hitbox
		local frame = Instance.new('Frame')
		frame.Name = 'Frame'
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		frame.Parent = billboard
		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 4)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
		end)
		layout.Parent = frame
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame
		billboard.Parent = folder
		Reference[bed] = billboard
		refresh(billboard)
	end

	local function removed(bed)
		if Reference[bed] then
			Reference[bed]:Destroy()
			Reference[bed] = nil
		end
	end

	local function watch(container)
		BedPlates:Clean(container.ChildAdded:Connect(function(bed)
			task.spawn(added, bed)
		end))
		BedPlates:Clean(container.ChildRemoved:Connect(removed))
		for _, bed in container:GetChildren() do
			task.spawn(added, bed)
		end
	end

	BedPlates = vape.Categories.Render:CreateModule({
		Name = 'BedPlates',
		Function = function(callback)
			if callback then
				if workspace:FindFirstChild('BedsContainer') then
					watch(workspace.BedsContainer)
				end
				BedPlates:Clean(workspace.ChildAdded:Connect(function(v)
					if v.Name == 'BedsContainer' then
						watch(v)
					end
				end))
				repeat
					for bed, billboard in Reference do
						if bed.Parent and billboard.Adornee and billboard.Adornee.Parent then
							refresh(billboard)
						else
							removed(bed)
						end
					end
					task.wait(1)
				until not BedPlates.Enabled
			else
				for bed in Reference do
					removed(bed)
				end
			end
		end,
		Tooltip = 'Shows over every bed which blocks are built around it'
	})
	Reach = BedPlates:CreateSlider({
		Name = 'Layers',
		Min = 1,
		Max = 5,
		Default = 3,
		Tooltip = 'How many blocks out from the bed are counted'
	})
	Counter = BedPlates:CreateToggle({
		Name = 'Block count',
		Default = true,
		Function = function()
			for _, billboard in Reference do
				billboard.Frame:SetAttribute('Shown', nil)
			end
		end
	})
	Background = BedPlates:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color and Color.Object then
				Color.Object.Visible = callback
			end
			for _, billboard in Reference do
				billboard.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
			end
		end,
		Default = true
	})
	Color = BedPlates:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, billboard in Reference do
				billboard.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				billboard.Frame.BackgroundTransparency = 1 - (Background.Enabled and opacity or 0)
			end
		end,
		Darker = true
	})
end)

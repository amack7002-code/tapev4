run(function()
	local OreESP
	local Background
	local Color
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local tracked = {}
	local function getIronIcon()
		local ok, icon = pcall(function() return bedwars.getIcon({itemType = 'iron'}, true) end)
		return ok and icon or 'rbxassetid://0'
	end
	local function createESP(obj)
		if tracked[obj] then return end
		if obj.Name:lower() ~= 'iron_ore_mesh_block' then return end
		local bill = Instance.new('BillboardGui')
		bill.Size = UDim2.fromOffset(40, 40)
		bill.Adornee = obj
		bill.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		bill.AlwaysOnTop = true
		bill.Parent = Folder
		local frame = Instance.new('Frame')
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundTransparency = Background.Enabled and 0.4 or 1
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.Parent = bill
		local uic = Instance.new('UICorner')
		uic.CornerRadius = UDim.new(0, 4)
		uic.Parent = frame
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.new(1, -6, 1, -6)
		image.Position = UDim2.new(0.5, 0, 0.5, 0)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundTransparency = 1
		image.Image = getIronIcon()
		image.Parent = frame
		tracked[obj] = {Billboard = bill, Frame = frame}
	end
	local function removeESP(obj)
		if tracked[obj] then
			tracked[obj].Billboard:Destroy()
			tracked[obj] = nil
		end
	end
	local function scanAll()
		scanDescendants(workspace, function(obj)
			createESP(obj)
		end)
	end
	local function cleanup()
		for _, v in pairs(tracked) do
			v.Billboard:Destroy()
		end
		table.clear(tracked)
	end
	OreESP = vape.Categories.Render:CreateModule({
		Name = 'OreESP',
		Function = function(callback)
			if callback then
				scanAll()
				OreESP:Clean(workspace.DescendantAdded:Connect(function(obj)
					if obj.Name:lower() ~= 'iron_ore_mesh_block' then return end
					task.wait(0.1)
					if OreESP.Enabled and obj.Parent then
						createESP(obj)
					end
				end))
				OreESP:Clean(workspace.DescendantRemoving:Connect(function(obj)
					if tracked[obj] then
						removeESP(obj)
					end
				end))
			else
				cleanup()
			end
		end,
		Tooltip = 'puts an icon above iron ore blocks so u can find em? - idea from piston the goat'
	})
	Background = OreESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color and Color.Object then Color.Object.Visible = callback end
			for _, v in pairs(tracked) do
				v.Frame.BackgroundTransparency = callback and 0.4 or 1
			end
		end,
		Default = true
	})
	Color = OreESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.6,
		Function = function(hue, sat, val, opacity)
			for _, v in pairs(tracked) do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
	task.defer(function()
		if Color and Color.Object then
			Color.Object.Visible = Background.Enabled
		end
	end)
end)
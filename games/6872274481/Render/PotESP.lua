run(function()
	local PotESP
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local tracked = {}
	local function getSandIcon()
		local ok, icon = pcall(function() return bedwars.getIcon({itemType = 'sand'}, true) end)
		return ok and icon or 'rbxassetid://0'
	end
	local function createESP(obj)
		if tracked[obj] then return end
		if obj.Name:lower() ~= 'desert_pot' then return end
		local bill = Instance.new('BillboardGui')
		bill.Size = UDim2.fromOffset(40, 40)
		bill.Adornee = obj
		bill.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		bill.AlwaysOnTop = true
		bill.Parent = Folder
		local frame = Instance.new('Frame')
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundTransparency = 0.4
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
		image.Image = getSandIcon()
		image.Parent = frame
		tracked[obj] = bill
	end
	local function removeESP(obj)
		if tracked[obj] then
			tracked[obj]:Destroy()
			tracked[obj] = nil
		end
	end
	local function scanAll()
		scanDescendants(workspace, function(obj)
			createESP(obj)
		end)
	end
	local function cleanup()
		for _, bill in pairs(tracked) do
			bill:Destroy()
		end
		table.clear(tracked)
	end
	PotESP = vape.Categories.Render:CreateModule({
		Name = 'PotESP',
		Function = function(callback)
			if callback then
				scanAll()
				PotESP:Clean(workspace.DescendantAdded:Connect(function(obj)
					if obj.Name:lower() ~= 'desert_pot' then return end
					task.wait(0.1)
					if PotESP.Enabled and obj.Parent then
						createESP(obj)
					end
				end))
				PotESP:Clean(workspace.DescendantRemoving:Connect(function(obj)
					if tracked[obj] then
						removeESP(obj)
					end
				end))
			else
				cleanup()
			end
		end,
		Tooltip = 'shows a sand block icon above each desert pot'
	})
end)
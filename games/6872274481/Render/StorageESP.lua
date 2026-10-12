run(function()
	local StorageESP
	local List
	local Background
	local Color = {}
	local Reference = {}
	local ChestContents = {} 
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function getEnabledItemsSet()
		local set = {}
		for _, v in ipairs(List.ListEnabled) do
			set[v] = true
		end
		return set
	end
	
	local function nearStorageItem(item, enabledSet)
		for itemName in pairs(enabledSet) do
			if item:find(itemName, 1, true) then return itemName end
		end
		return nil
	end
	
	local function refreshAdornee(billboard)
		local chestPart = billboard.Adornee
		local folderValue = chestPart and chestPart:FindFirstChild('ChestFolderValue')
		local chest = folderValue and folderValue.Value or nil

		for _, obj in ipairs(billboard:GetChildren()) do
			if obj:IsA('ImageLabel') and obj.Name == 'Icon' then
				obj:Destroy()
			end
		end

		if not chest then
			billboard.Enabled = false
			return
		end

		local chestitems = chest:GetChildren()
		local enabledSet = getEnabledItemsSet()
		local listIsEmpty = next(enabledSet) == nil

		local matchedItems = {}
		local amounts = {}
		for _, item in ipairs(chestitems) do
			if item:IsA('Accessory') then
				if listIsEmpty or enabledSet[item.Name] or nearStorageItem(item.Name, enabledSet) then
					if amounts[item.Name] == nil then
						amounts[item.Name] = 0
						table.insert(matchedItems, item.Name)
					end
					amounts[item.Name] = amounts[item.Name] + (item:GetAttribute('Amount') or 1)
				end
			end
		end

		local count = #matchedItems
		if count == 0 then
			billboard.Enabled = false
			return
		end

		billboard.Enabled = true
		local iconSize = 36
		local padding = 2
		local totalWidth = count * iconSize + (count - 1) * padding
		billboard.Size = UDim2.fromOffset(totalWidth, iconSize)

		for i, itemName in ipairs(matchedItems) do
			local icon = Instance.new('ImageLabel')
			icon.Name = 'Icon'
			icon.Size = UDim2.fromOffset(iconSize, iconSize)
			icon.Position = UDim2.fromOffset((i - 1) * (iconSize + padding), 0)
			icon.AnchorPoint = Vector2.new(0, 0)
			icon.BackgroundColor3 = Color3.new(0, 0, 0)
			icon.BackgroundTransparency = 0.3
			icon.BorderSizePixel = 0
			icon.Image = bedwars.getIcon({itemType = itemName}, true)
			icon.Parent = billboard

			local uicorner = Instance.new('UICorner')
			uicorner.CornerRadius = UDim.new(0, 4)
			uicorner.Parent = icon

			local amt = Instance.new('TextLabel')
			amt.Name = 'Amt'
			amt.AnchorPoint = Vector2.new(1, 1)
			amt.Position = UDim2.new(1, -1, 1, -1)
			amt.Size = UDim2.fromOffset(iconSize, 14)
			amt.BackgroundTransparency = 1
			amt.Text = tostring(amounts[itemName] or 0)
			amt.TextColor3 = Color3.fromRGB(255, 255, 255)
			amt.TextStrokeTransparency = 0.4
			amt.TextSize = 13
			amt.Font = Enum.Font.GothamBold
			amt.TextXAlignment = Enum.TextXAlignment.Right
			amt.TextYAlignment = Enum.TextYAlignment.Bottom
			amt.Parent = icon
		end
	end
	
	local function Added(v)
		if Reference[v] then return end

		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'chest'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		billboard.Enabled = false

		local blur = addBlur(billboard)

		Reference[v] = billboard

		refreshAdornee(billboard)

		task.defer(function()
			local folderValue = v:FindFirstChild('ChestFolderValue')
			local chest = folderValue and folderValue.Value or nil
			if chest and Reference[v] then
				local conn1 = chest.ChildAdded:Connect(function()
					if Reference[v] then refreshAdornee(Reference[v]) end
				end)
				local conn2 = chest.ChildRemoved:Connect(function()
					if Reference[v] then refreshAdornee(Reference[v]) end
				end)
				billboard.AncestryChanged:Connect(function()
					conn1:Disconnect()
					conn2:Disconnect()
				end)
			end
		end)
	end
	
	local function Removed(v)
		if Reference[v] then
			Reference[v]:Destroy()
			Reference[v] = nil
			ChestContents[v] = nil
		end
	end
	
	StorageESP = vape.Categories.Render:CreateModule({
		Name = 'StorageESP',
		Function = function(callback)
			if callback then
				local tagged = collectionService:GetTagged('chest')
				for _, v in ipairs(tagged) do
					Added(v)
				end
				
				StorageESP:Clean(collectionService:GetInstanceAddedSignal('chest'):Connect(Added))
				StorageESP:Clean(collectionService:GetInstanceRemovedSignal('chest'):Connect(Removed))
				cleanThread(StorageESP, task.spawn(function()
					while StorageESP.Enabled do
						task.wait(0.5)
						if not StorageESP.Enabled then break end
						for chest, billboard in pairs(Reference) do
							if not chest or not chest.Parent then
								Removed(chest)
							else
								refreshAdornee(billboard)
							end
						end
					end
				end))
			else
				for chest in pairs(Reference) do
					Removed(chest)
				end
			end
		end,
		Tooltip = 'shows what items are in a chest'
	})
	
	List = StorageESP:CreateTextList({
		Name = 'Item',
		Function = function()
			table.clear(ChestContents)
			for _, v in pairs(Reference) do
				refreshAdornee(v)
			end
		end
	})
	
	Background = StorageESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, v in pairs(Reference) do
				local icon = v:FindFirstChild('Icon')
				if icon then
					icon.BackgroundTransparency = callback and 0.3 or 1
				end
			end
		end,
		Default = true
	})
	
    Color = StorageESP:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, v in pairs(Reference) do
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
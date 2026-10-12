run(function()
	local InventoryESP
	local TeamCheck
	local Kits
	local Whitelist
	local Tools
	local Weapon
	local Loot
	local PersonalChest
	local Filter
	local FilterMode
	local FilterRange
	local FilterPlayers
	local SizeToggle
	local SizeSlider
	local warnedNames = {}
	local gui
	local rows = {}
	local thumbCache = {}
	local ICON_SIZE = 18
	local MAX_PER_ROW = 8
	local function teamColor(plr)
		local t = tonumber(plr:GetAttribute('Team'))
		local entry = t and getgenv().aeroTeamColors[t]
		return entry and entry.color or Color3.fromRGB(255, 255, 255)
	end
	local PLACEHOLDER = 'rbxassetid://6031075931' 
	local lootNames = {iron = true, gold = true, diamond = true, emerald = true}

	local function classify(itemType)
		if lootNames[itemType] or itemType:find('iron') or itemType:find('diamond') or itemType:find('emerald') or itemType:find('gold') then
			return 'loot'
		end
		local meta = bedwars.ItemMeta[itemType]
		if meta then
			if meta.sword or meta.projectile or meta.projectileSource or itemType:find('bow') or itemType:find('sword') then
				return 'weapon'
			end
			if meta.breakBlock or itemType:find('pickaxe') or itemType:find('axe') or itemType:find('shear') then
				return 'tool'
			end
		end
		return 'etc'
	end

	local function passesWhitelist(itemType)
		if not Whitelist.Enabled then return true end
		local c = classify(itemType)
		if c == 'tool' then return Tools.Enabled end
		if c == 'weapon' then return Weapon.Enabled end
		if c == 'loot' then return Loot.Enabled end
		return false 
	end

	local function applySize()
		if not gui or not gui:FindFirstChild('Holder') then return end
		local s = (SizeToggle and SizeToggle.Enabled and SizeSlider) and SizeSlider.Value or 1
		local holder = gui.Holder
		local hs = holder:FindFirstChild('HolderScale') or Instance.new('UIScale')
		hs.Name = 'HolderScale'
		hs.Scale = s
		hs.Parent = holder
		holder.Size = UDim2.new(0, 190, 0.9 / s, 0)
	end

	local function makeGui()
		gui = Instance.new('ScreenGui')
		gui.Name = 'InventoryESP'
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.DisplayOrder = 50
		pcall(function() gui.Parent = gethui and gethui() or game:GetService('CoreGui') end)
		if not gui.Parent then gui.Parent = lplr:WaitForChild('PlayerGui') end

		local holder = Instance.new('Frame')
		holder.Name = 'Holder'
		holder.AnchorPoint = Vector2.new(1, 0.5)
		holder.Position = UDim2.new(1, -2, 0.5, 0)
		holder.Size = UDim2.new(0, 190, 0.9, 0)
		holder.BackgroundTransparency = 1
		holder.Parent = gui

		local list = Instance.new('UIListLayout')
		list.FillDirection = Enum.FillDirection.Vertical
		list.HorizontalAlignment = Enum.HorizontalAlignment.Left
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Padding = UDim.new(0, 4)
		list.SortOrder = Enum.SortOrder.Name
		list.Parent = holder
		applySize()
	end

	local function getThumb(userId)
		if not thumbCache[userId] then
			thumbCache[userId] = 'rbxthumb://type=AvatarHeadShot&id=' .. userId .. '&w=150&h=150'
		end
		return thumbCache[userId]
	end

	local function invFolder(plr, personal)
		local inv = replicatedStorage:FindFirstChild('Inventories')
		if not inv then return nil end
		return inv:FindFirstChild(personal and (plr.Name .. '_personal') or plr.Name)
	end

	local function makeSection(parent, titleText)
		local wrap = Instance.new('Frame')
		wrap.Name = titleText
		wrap.BackgroundTransparency = 1
		wrap.Size = UDim2.new(1, 0, 0, 0)
		wrap.AutomaticSize = Enum.AutomaticSize.Y
		wrap.Parent = parent

		local wl = Instance.new('UIListLayout')
		wl.Padding = UDim.new(0, 2)
		wl.SortOrder = Enum.SortOrder.LayoutOrder
		wl.Parent = wrap

		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.LayoutOrder = 0
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0, 12)
		title.Text = titleText
		title.TextColor3 = Color3.fromRGB(160, 200, 255)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextSize = 11
		title.Font = Enum.Font.GothamBold
		title.Parent = wrap

		local grid = Instance.new('Frame')
		grid.Name = 'Grid'
		grid.LayoutOrder = 1
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, 0, 0, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.Parent = wrap

		local gl = Instance.new('UIGridLayout')
		gl.CellSize = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
		gl.CellPadding = UDim2.new(0, 3, 0, 3)
		gl.FillDirectionMaxCells = MAX_PER_ROW
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		gl.Parent = grid

		return {wrap = wrap, grid = grid, title = title, icons = {}}
	end

	local function buildRow(plr)
		local frame = Instance.new('Frame')
		frame.Name = plr.Name
		frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		frame.BackgroundTransparency = 0.25
		frame.BorderSizePixel = 0
		frame.Size = UDim2.new(1, 0, 0, 44)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.Parent = gui.Holder
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame
		local stroke = Instance.new('UIStroke')
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(60, 60, 70)
		stroke.Transparency = 0.3
		stroke.Parent = frame
		local pad = Instance.new('UIPadding')
		pad.PaddingLeft = UDim.new(0, 4)
		pad.PaddingRight = UDim.new(0, 4)
		pad.PaddingTop = UDim.new(0, 3)
		pad.PaddingBottom = UDim.new(0, 3)
		pad.Parent = frame
		local left = Instance.new('Frame')
		left.Name = 'Left'
		left.BackgroundTransparency = 1
		left.Size = UDim2.new(0, 30, 1, 0)
		left.Parent = frame
		local name = Instance.new('TextLabel')
		name.Name = 'PName'
		name.BackgroundTransparency = 1
		name.Position = UDim2.new(0, 0, 0, 0)
		name.Size = UDim2.new(1, 0, 0, 12)
		name.Text = plr.DisplayName or plr.Name
		name.TextColor3 = teamColor(plr)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextSize = 11
		name.Font = Enum.Font.GothamBold
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.ZIndex = 3
		name.Parent = frame
		local face = Instance.new('ImageLabel')
		face.Name = 'Face'
		face.AnchorPoint = Vector2.new(0.5, 0)
		face.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
		face.Size = UDim2.new(0, 24, 0, 24)
		face.Position = UDim2.new(0.5, 0, 0, 16) 
		face.Image = getThumb(plr.UserId)
		face.Parent = left
		local fc = Instance.new('UICorner')
		fc.CornerRadius = UDim.new(1, 0)
		fc.Parent = face
		local fs = Instance.new('UIStroke')
		fs.Thickness = 1.5
		fs.Color = teamColor(plr)
		fs.Parent = face
		local right = Instance.new('Frame')
		right.Name = 'Right'
		right.BackgroundTransparency = 1
		right.Position = UDim2.new(0, 34, 0, 14)
		right.Size = UDim2.new(1, -34, 0, 0)
		right.AutomaticSize = Enum.AutomaticSize.Y
		right.Parent = frame
		local rl = Instance.new('UIListLayout')
		rl.Padding = UDim.new(0, 4)
		rl.SortOrder = Enum.SortOrder.LayoutOrder
		rl.Parent = right

		local kiticon = Instance.new('ImageLabel')
		kiticon.Name = 'KitIcon'
		kiticon.AnchorPoint = Vector2.new(1, 0)
		kiticon.Position = UDim2.new(1, -2, 0, 0)
		kiticon.Size = UDim2.new(0, 20, 0, 20)
		kiticon.BackgroundTransparency = 1
		kiticon.ScaleType = Enum.ScaleType.Fit
		kiticon.Visible = false
		kiticon.ZIndex = 4
		kiticon.Parent = frame

		rows[plr] = {
			frame = frame,
			pname = name,
			pstroke = fs,
			kiticon = kiticon,
			inv = makeSection(right, 'Inventory'),
			personal = makeSection(right, 'Personal')
		}
		rows[plr].inv.wrap.LayoutOrder = 0
		rows[plr].personal.wrap.LayoutOrder = 1
		return rows[plr]
	end

	local function updateSection(section, folder, personalMode)
		local seen = {}
		local order = 0
		if folder then
			for _, item in folder:GetChildren() do
				local itemType = item.Name
				if personalMode or passesWhitelist(itemType) then
					seen[itemType] = true
					order += 1
					local icon = section.icons[itemType]
					if not icon then
						icon = Instance.new('ImageLabel')
						icon.Name = itemType
						icon.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
						icon.BackgroundTransparency = 0.2
						icon.ClipsDescendants = false
						icon.Parent = section.grid
						local ic = Instance.new('UICorner')
						ic.CornerRadius = UDim.new(0, 4)
						ic.Parent = icon
						local amt = Instance.new('TextLabel')
						amt.Name = 'Amt'
						amt.BackgroundTransparency = 1
						amt.Size = UDim2.new(1, -1, 1, -1)
						amt.Position = UDim2.new(0, 0, 0, 0)
						amt.TextColor3 = Color3.fromRGB(255, 255, 255)
						amt.TextStrokeTransparency = 0
						amt.TextXAlignment = Enum.TextXAlignment.Right
						amt.TextYAlignment = Enum.TextYAlignment.Bottom
						amt.TextSize = 10
						amt.ZIndex = 2
						amt.TextScaled = false
						amt.Font = Enum.Font.GothamBold
						amt.Parent = icon
						local img = PLACEHOLDER
						pcall(function()
							local got = bedwars.getIcon({itemType = itemType}, true)
							if got and got ~= '' then img = got end
						end)
						icon.Image = img
						section.icons[itemType] = icon
					end
					icon.LayoutOrder = order
					local count = item:GetAttribute('Amount') or item:GetAttribute('amount') or item:GetAttribute('Count')
					icon.Amt.Text = (count and count > 1) and tostring(count) or ''
				end
			end
		end
		for iname, icon in section.icons do
			if not seen[iname] then
				icon:Destroy()
				section.icons[iname] = nil
			end
		end
		section.wrap.Visible = order > 0
	end

	local function passesFilter(plr)
		if not Filter or not Filter.Enabled then return true end
		if FilterMode.Value == 'Range' then
			local myRoot = entitylib.character and entitylib.character.RootPart
			local theirRoot = plr.Character and plr.Character:FindFirstChild('HumanoidRootPart')
			if not myRoot or not theirRoot then return false end
			return (theirRoot.Position - myRoot.Position).Magnitude <= FilterRange.Value
		end
		if FilterMode.Value == 'Players' then
			local list = FilterPlayers.ListEnabled
			if #list == 0 then return false end
			local lname = plr.Name:lower()
			local ldisp = plr.DisplayName:lower()
			for _, v in list do
				local lv = tostring(v):lower()
				if lv == lname or lv == ldisp then return true end
			end
			return false
		end
		return true
	end

	local function removeRow(plr)
		if rows[plr] then
			rows[plr].frame:Destroy()
			rows[plr] = nil
		end
	end

	InventoryESP = vape.Categories.Render:CreateModule({
		Name = 'InventoryESP',
		Function = function(callback)
			if callback then
				makeGui()
				repeat
					local myTeam = lplr:GetAttribute('Team')
					for _, plr in playersService:GetPlayers() do
						local skip = false
						if TeamCheck.Enabled and (plr == lplr or (plr:GetAttribute('Team') and plr:GetAttribute('Team') == myTeam)) then
							skip = true
						end
						if not skip and plr ~= lplr and not passesFilter(plr) then
							skip = true
						end
						if skip then
							removeRow(plr)
						else
							local liveInv = invFolder(plr, false)
							local personalInv = PersonalChest.Enabled and invFolder(plr, true) or nil
							local anything = (liveInv and #liveInv:GetChildren() > 0) or (personalInv and #personalInv:GetChildren() > 0)
							if anything then
								local row = rows[plr] or buildRow(plr)
								local col = teamColor(plr)
								row.pname.TextColor3 = col
								row.pstroke.Color = col
								if Kits.Enabled then
									local kit = plr:GetAttribute('PlayingAsKits')
									local kitImage = kit and kitImageIds[kit:lower()]
									row.kiticon.Image = kitImage or kitImageIds['none']
									row.kiticon.Visible = true
								else
									row.kiticon.Visible = false
								end
								updateSection(row.inv, liveInv, false)
								updateSection(row.personal, personalInv, true)
								row.personal.wrap.Visible = PersonalChest.Enabled and row.personal.wrap.Visible
							else
								removeRow(plr)
							end
						end
					end
					for plr in rows do
						if not plr.Parent then removeRow(plr) end
					end
					task.wait(0.5)
				until not InventoryESP.Enabled
			else
				for plr in rows do removeRow(plr) end
				rows = {}
				if gui then gui:Destroy() gui = nil end
			end
		end,
		Tooltip = 'shows what everyone has in their inventory (n chest) on the side gng'
	})

	Whitelist = InventoryESP:CreateToggle({
		Name = 'Whitelist',
		Tooltip = 'only show the categories u pick below',
		Function = function(callback)
			if Tools then Tools.Object.Visible = callback end
			if Weapon then Weapon.Object.Visible = callback end
			if Loot then Loot.Object.Visible = callback end
		end
	})
	Tools = InventoryESP:CreateToggle({
		Name = 'Tools',
		Default = true,
		Darker = true,
		Visible = false,
		Tooltip = 'pickaxes, axes, shears'
	})
	Weapon = InventoryESP:CreateToggle({
		Name = 'Weapon',
		Default = true,
		Darker = true,
		Visible = false,
		Tooltip = 'swords n projectiles'
	})
	Loot = InventoryESP:CreateToggle({
		Name = 'Loot',
		Default = true,
		Darker = true,
		Visible = false,
		Tooltip = 'iron, gold, diamond, emerald'
	})
	PersonalChest = InventoryESP:CreateToggle({
		Name = 'Personal Chest',
		Tooltip = 'also show their personal chest items'
	})
	TeamCheck = InventoryESP:CreateToggle({
		Name = 'Team check',
		Default = true,
		Tooltip = 'dont show ppl on ur team'
	})

	Kits = InventoryESP:CreateToggle({
		Name = 'Kits',
		Default = false,
		Tooltip = 'puts the kit icon next to each persons name'
	})

	SizeToggle = InventoryESP:CreateToggle({
		Name = 'Custom Size',
		Function = function(callback)
			if SizeSlider then SizeSlider.Object.Visible = callback end
			applySize()
		end,
		Tooltip = 'turn on to pick ur own size for the inventory esp'
	})

	SizeSlider = InventoryESP:CreateSlider({
		Name = 'Size',
		Min = 0.5,
		Max = 2.5,
		Default = 1.3,
		Decimal = 10,
		Darker = true,
		Visible = false,
		Function = function()
			applySize()
		end,
		Tooltip = 'makes the inventory esp bigger or smaller gng'
	})

	local function syncFilterVisibility()
		local on = Filter and Filter.Enabled
		if FilterMode then FilterMode.Object.Visible = on end
		if FilterRange then FilterRange.Object.Visible = on and FilterMode.Value == 'Range' end
		if FilterPlayers then FilterPlayers.Object.Visible = on and FilterMode.Value == 'Players' end
	end

	Filter = InventoryESP:CreateToggle({
		Name = 'Filter',
		Default = false,
		Tooltip = 'only show certain ppl instead of everyone',
		Function = function()
			syncFilterVisibility()
		end
	})

	FilterMode = InventoryESP:CreateDropdown({
		Name = 'Filter Mode',
		List = {'Range', 'Players'},
		Default = 'Range',
		Darker = true,
		Visible = false,
		Tooltip = 'range = ppl close to u, players = only the ppl u type in',
		Function = function()
			syncFilterVisibility()
		end
	})

	FilterRange = InventoryESP:CreateSlider({
		Name = 'Filter Range',
		Min = 1,
		Max = 30,
		Default = 20,
		Darker = true,
		Visible = false,
		Tooltip = 'only show ppl this close to u, they disappear when they leave',
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	FilterPlayers = InventoryESP:CreateTextList({
		Name = 'Filter Players',
		Darker = true,
		Visible = false,
		Placeholder = 'username...',
		Tooltip = 'only show the ppl u add here',
		Function = function(list)
			for _, v in list do
				local lv = tostring(v):lower()
				if not warnedNames[lv] then
					local found = false
					for _, p in playersService:GetPlayers() do
						if p.Name:lower() == lv or p.DisplayName:lower() == lv then
							found = true
							break
						end
					end
					if not found then
						warnedNames[lv] = true
						notif('InventoryESP', tostring(v)..' aint in this game gng', 4)
					end
				end
			end
		end
	})

	task.defer(syncFilterVisibility)
end)
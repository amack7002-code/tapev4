run(function()
	local AutoBank
	local UIToggle
	local GUICheck
	local UI
	local Chests
	local Items = {}
	local BankToggles = {
		iron = nil,
		diamond = nil,
		emerald = nil
	}
	local cachedChest
	local lastChestCheck = 0
	local lastHotbarUpdate = 0

	local function addItem(itemType, shop)
		local item = Instance.new('ImageLabel')
		item.Image = bedwars.getIcon({itemType = itemType}, true)
		item.Size = UDim2.fromOffset(32, 32)
		item.Name = itemType
		item.BackgroundTransparency = 1
		item.LayoutOrder = #UI:GetChildren()
		item.Parent = UI
		local itemtext = Instance.new('TextLabel')
		itemtext.Name = 'Amount'
		itemtext.Size = UDim2.fromScale(1, 1)
		itemtext.BackgroundTransparency = 1
		itemtext.Text = ''
		itemtext.TextColor3 = Color3.new(1, 1, 1)
		itemtext.TextSize = 16
		itemtext.TextStrokeTransparency = 0.3
		itemtext.Font = Enum.Font.Arial
		itemtext.Parent = item
		Items[itemType] = {Object = itemtext, Type = shop}
	end

	local function refreshBank(echest)
		for i, v in pairs(Items) do
			local item = echest:FindFirstChild(i)
			v.Object.Text = item and item:GetAttribute('Amount') or ''
		end
	end

	local function nearChest()
		if not entitylib.isAlive then return false end

		local pos = entitylib.character.RootPart.Position
		local maxDistanceSq = 22 * 22

		for _, chest in pairs(Chests) do
			if chest.Parent then
				local offset = chest.Position - pos
				local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
				if distanceSq < maxDistanceSq then
					return true
				end
			end
		end

		return false
	end

	local function isNearOwnBase()
		if not entitylib.isAlive then return false end
		local myTeam = tostring(lplr:GetAttribute('Team') or '')
		if myTeam == '' then return false end
		local myBed = nil
		for _, bed in collectionService:GetTagged('bed') do
			if not bed:IsA('BasePart') then continue end
			local bedTeam = tostring(bed:GetAttribute('Team') or bed:GetAttribute('TeamId') or '')
			if bedTeam == myTeam then myBed = bed break end
		end
		if not myBed then return false end
		local bedPos = myBed.Position
		local closestChest, closestDist = nil, math.huge
		for _, chest in pairs(Chests) do
			if chest.Parent then
				local dist = (chest.Position - bedPos).Magnitude
				if dist < closestDist then closestChest = chest closestDist = dist end
			end
		end
		if not closestChest then return false end
		local myPos = entitylib.character.RootPart.Position
		return (myPos - closestChest.Position).Magnitude <= 60
	end

	local function handleState()
		local currentTime = tick()

		if not cachedChest or not cachedChest.Parent or (currentTime - lastChestCheck) > 1 then
			cachedChest = replicatedStorage.Inventories:FindFirstChild(lplr.Name..'_personal')
			lastChestCheck = currentTime
		end

		if not cachedChest then return end

		if not nearChest() and not GUICheck.Enabled then
			return
		end

		local itemsToDeposit = {}
		for _, v in ipairs(store.inventory.inventory.items) do
			local itemInfo = Items[v.itemType]
			if itemInfo and BankToggles[v.itemType] and BankToggles[v.itemType].Enabled then
				table.insert(itemsToDeposit, v)
			end
		end

		if #itemsToDeposit > 0 then
			for _, v in ipairs(itemsToDeposit) do
				bedwars.Client:GetNamespace('Inventory'):Get('ChestGiveItem'):CallServer(cachedChest, v.tool)
			end
			task.defer(function()
				if cachedChest and cachedChest.Parent then
					refreshBank(cachedChest)
				end
			end)
		end
	end


	AutoBank = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBank',
		Function = function(callback)
			if callback then
				Chests = collection('chest', AutoBank)
				cachedChest = nil
				lastChestCheck = 0
				lastHotbarUpdate = 0
				UI = Instance.new('Frame')
				UI.Size = UDim2.new(1, 0, 0, 44)
				UI.Position = UDim2.fromOffset(0, -256)
				UI.BackgroundTransparency = 1
				UI.Visible = UIToggle.Enabled
				UI.Parent = vape.gui
				AutoBank:Clean(UI)

				local Sort = Instance.new('UIListLayout')
				Sort.FillDirection = Enum.FillDirection.Horizontal
				Sort.HorizontalAlignment = Enum.HorizontalAlignment.Center
				Sort.SortOrder = Enum.SortOrder.LayoutOrder
				Sort.Parent = UI

				addItem('iron', true)
				addItem('diamond', false)
				addItem('emerald', true)
				addItem('serpents_touch_potion', false)
				addItem('jump_potion', false)
				addItem('mini_shield', false)

				local cachedHotbar
				local guiInset = guiService:GetGuiInset().Y

				repeat
					local currentTime = tick()

					if (currentTime - lastHotbarUpdate) > 0.5 then
						local playerGui = lplr.PlayerGui
						if playerGui then
							local hotbar = playerGui:FindFirstChild('hotbar')
							if hotbar then
								local container = hotbar['1']:FindFirstChild('HotbarHealthbarContainer')
								if container then
									cachedHotbar = container
									UI.Position = UDim2.fromOffset(0, (container.AbsolutePosition.Y + guiInset) - 40)
									lastHotbarUpdate = currentTime
								end
							end
						end
					end

					if not cachedChest or not cachedChest.Parent or (currentTime - lastChestCheck) > 1 then
						cachedChest = replicatedStorage.Inventories:FindFirstChild(lplr.Name .. '_personal')
						lastChestCheck = currentTime
					end
					if UIToggle.Enabled and UI and cachedChest then
						refreshBank(cachedChest)
					end

					local shouldBank = false

					if GUICheck.Enabled then
						shouldBank = bedwars.AppController:isAppOpen('ChestApp') or
						             bedwars.AppController:isAppOpen('BedwarsAppIds.CHEST_INVENTORY')
					else
						shouldBank = nearChest()
					end

					if shouldBank and not (TeamCheck and TeamCheck.Enabled and isNearOwnBase()) then
						handleState()
					end

					task.wait(0.1)
				until (not AutoBank.Enabled)
			else
				table.clear(Items)
				cachedChest = nil
			end
		end,
		Tooltip = 'automatically puts resources in pchest'
	})

	UIToggle = AutoBank:CreateToggle({
		Name = 'UI',
		Function = function(callback)
			if AutoBank.Enabled and UI then
				UI.Visible = callback
			end
		end,
		Default = true
	})

	GUICheck = AutoBank:CreateToggle({
		Name = 'GUI Check',
	})

	BankToggles.iron = AutoBank:CreateToggle({
		Name = 'Bank Iron',
		Default = true
	})

	BankToggles.diamond = AutoBank:CreateToggle({
		Name = 'Bank Diamond',
		Default = true
	})

	BankToggles.emerald = AutoBank:CreateToggle({
		Name = 'Bank Emerald',
		Default = true
	})

	BankToggles.serpents_touch_potion = AutoBank:CreateToggle({
		Name = 'Bank Serpent Potion',
		Default = false
	})

	BankToggles.jump_potion = AutoBank:CreateToggle({
		Name = 'Bank Jump Potion',
		Default = false
	})

	BankToggles.mini_shield = AutoBank:CreateToggle({
		Name = 'Bank Shield Potion',
		Default = false
	})

	TeamCheck = AutoBank:CreateToggle({
		Name = 'Team Check',
		Default = false
	})
end)
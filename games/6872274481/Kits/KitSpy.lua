run(function()
	local KitSpy
	local BeehiveToggle
	local BeehiveBackground
	local BeehiveColor
	local LuciaToggle
	local LuciaIgnoreTeammates
	local LuciaDisplayName
	local FishermanToggle
	local FishermanIgnoreTeammates
	local BountyHunterToggle
	local BountyTargetToggle
	local BountyLootToggle
	local huntTargets = {}
	local BeehiveFolder = Instance.new('Folder')
	BeehiveFolder.Parent = vape.gui
	local BeehiveReference = {}
	local trackedPinatas = {}
	local FishNames = {
		fish_iron = "Iron Fish",
		fish_diamond = "Diamond Fish",
		fish_emerald = "Emerald Fish",
		fish_special = "Special Fish",
		fish_gold = "Gold Fish",
	}

	local function addBlur(parent)
		local blur = Instance.new('ImageLabel')
		blur.Name = 'Blur'
		blur.Size = UDim2.new(1, 89, 1, 52)
		blur.Position = UDim2.fromOffset(-48, -31)
		blur.BackgroundTransparency = 1
		blur.Image = getcustomasset('aerov4/assets/new/blur.png')
		blur.ScaleType = Enum.ScaleType.Slice
		blur.SliceCenter = Rect.new(52, 31, 261, 502)
		blur.Parent = parent
		return blur
	end

	local function isMyBeehive(beehive)
		if not beehive then return false end
		local placedBy = beehive:GetAttribute("PlacedByUserId")
		return placedBy and placedBy == lplr.UserId
	end

	local function getBeehiveOwnerName(beehive)
		if not beehive then return "Unknown" end
		local placedBy = beehive:GetAttribute("PlacedByUserId")
		if not placedBy then return "Unknown" end
		local player = playersService:GetPlayerByUserId(placedBy)
		if player then return player.Name end
		return "Player"
	end

	local function getBeehiveOwner(beehive)
		if not beehive then return nil end
		local placedBy = beehive:GetAttribute("PlacedByUserId")
		if not placedBy then return nil end
		return playersService:GetPlayerByUserId(placedBy)
	end

	local function AddedBeehive(beehive)
		if isMyBeehive(beehive) then return end
		if BeehiveReference[beehive] then return end

		local level = beehive:GetAttribute("Level") or 0
		local ownerName = getBeehiveOwnerName(beehive)
		local owner = getBeehiveOwner(beehive)
		if not owner then return end

		local billboard = Instance.new('BillboardGui')
		billboard.Parent = BeehiveFolder
		billboard.Name = 'beehive-spy'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		billboard.Size = UDim2.fromOffset(120, 40)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = beehive

		local blur = addBlur(billboard)
		blur.Visible = BeehiveBackground and BeehiveBackground.Enabled or true

		local hue, sat, val, opacity = 0, 0, 1, 0.5
		if BeehiveColor then
			hue, sat, val, opacity = BeehiveColor.Hue, BeehiveColor.Sat, BeehiveColor.Value, BeehiveColor.Opacity
		end

		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		frame.BackgroundTransparency = 1 - ((BeehiveBackground and BeehiveBackground.Enabled or true) and opacity or 0)
		frame.BorderSizePixel = 0
		frame.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 6)
		uicorner.Parent = frame
		local nameLabel = Instance.new('TextLabel')
		nameLabel.Name = 'OwnerName'
		nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
		nameLabel.Position = UDim2.new(0, 0, 0, -20)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = ownerName
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 12
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextStrokeTransparency = 0.5
		nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		nameLabel.Parent = billboard
		local homeLabel = Instance.new('ImageLabel')
		homeLabel.Size = UDim2.fromOffset(20, 20)
		homeLabel.Position = UDim2.new(0, 5, 0.5, 0)
		homeLabel.AnchorPoint = Vector2.new(0, 0.5)
		homeLabel.BackgroundTransparency = 1
		homeLabel.BorderSizePixel = 0
		homeLabel.Image = bedwars.getIcon({itemType = 'beehive'}, true)
		homeLabel.Parent = frame
		local levelLabel = Instance.new('TextLabel')
		levelLabel.Name = 'Level'
		levelLabel.Size = UDim2.new(0, 25, 1, 0)
		levelLabel.Position = UDim2.new(1, -30, 0, 0)
		levelLabel.BackgroundTransparency = 1
		levelLabel.Text = tostring(level)
		levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		levelLabel.TextSize = 16
		levelLabel.Font = Enum.Font.GothamBold
		levelLabel.TextStrokeTransparency = 0.5
		levelLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		levelLabel.Parent = frame

		BeehiveReference[beehive] = {
			billboard = billboard,
			levelLabel = levelLabel,
			frame = frame,
		}

		KitSpy:Clean(beehive:GetAttributeChangedSignal("Level"):Connect(function()
			local ref = BeehiveReference[beehive]
			if ref and ref.levelLabel then
				ref.levelLabel.Text = tostring(beehive:GetAttribute("Level") or 0)
			end
		end))
	end

	local function RemovedBeehive(beehive)
		if BeehiveReference[beehive] then
			BeehiveReference[beehive].billboard:Destroy()
			BeehiveReference[beehive] = nil
		end
	end

	local function setupBeehiveSpy()
		for _, beehive in collectionService:GetTagged('beehive') do
			AddedBeehive(beehive)
		end

		KitSpy:Clean(collectionService:GetInstanceAddedSignal('beehive'):Connect(function(beehive)
			task.wait(0.1)
			AddedBeehive(beehive)
		end))

		KitSpy:Clean(collectionService:GetInstanceRemovedSignal('beehive'):Connect(function(beehive)
			RemovedBeehive(beehive)
		end))
	end

	local function cleanupBeehive()
		BeehiveFolder:ClearAllChildren()
		table.clear(BeehiveReference)
	end

	local function getPlayerName(player)
		if LuciaDisplayName and LuciaDisplayName.Enabled then
			return player.DisplayName ~= "" and player.DisplayName or player.Name
		end
		return player.Name
	end

	local function getTeamName(player)
		if player.Team then return player.Team.Name end
		return "Unknown"
	end

	local function getCandyAmount(pinataPart)
		return pinataPart:GetAttribute("Coin") or 0
	end

	local function isTeammateSpy(pinataPart)
		if not LuciaIgnoreTeammates or not LuciaIgnoreTeammates.Enabled then return false end
		local placerId = pinataPart:GetAttribute("PlacedByUserId") or pinataPart:GetAttribute("PlacerId")
		if not placerId then
			local parent = pinataPart.Parent
			if parent then
				placerId = parent:GetAttribute("PlacedByUserId") or parent:GetAttribute("PlacerId")
			end
		end
		if placerId then
			if placerId == lplr.UserId then return true end
			local placer = playersService:GetPlayerByUserId(placerId)
			if placer and placer.Team == lplr.Team then return true end
		end
		return false
	end

	local function setupLuciaSpy()
		local util = require(game:GetService("ReplicatedStorage").TS.games.bedwars.kit.kits['piggy-bank']['piggy-bank-util']).PiggyBankUtil
		for _, obj in pairs(workspace:GetDescendants()) do
			if obj:IsA("BasePart") and obj.Name == "pinata" then
				if not isTeammateSpy(obj) then
					local placerId = obj:GetAttribute("PlacedByUserId") or obj:GetAttribute("PlacerId")
					if placerId then
						local placer = playersService:GetPlayerByUserId(placerId)
						trackedPinatas[obj] = {
							player = placer,
							lastCandy = getCandyAmount(obj),
							exists = true,
							placedTime = tick()
						}
					end
				end
			end
		end

		KitSpy:Clean(workspace.DescendantAdded:Connect(function(obj)
			if not LuciaToggle.Enabled then return end
			if obj:IsA("BasePart") and obj.Name == "pinata" then
				task.wait(0.2)
				if not isTeammateSpy(obj) then
					local placerId = obj:GetAttribute("PlacedByUserId") or obj:GetAttribute("PlacerId")
					if placerId then
						local placer = playersService:GetPlayerByUserId(placerId)
						trackedPinatas[obj] = {
							player = placer,
							lastCandy = getCandyAmount(obj),
							exists = true,
							placedTime = tick()
						}
					end
				end
			end
		end))

		KitSpy:Clean(bedwars.Client:Get("PiggyBankPop"):Connect(function(self)
			if not LuciaToggle.Enabled then return end
			local plr = self.awardedPlayer
			if not plr then return end
			if LuciaIgnoreTeammates and LuciaIgnoreTeammates.Enabled then
				if plr == lplr or (plr.Team and plr.Team == lplr.Team) then return end
			end

			local rewards = util:getRewardsFromCoins(self.coins)
			local I, D, E = 0, 0, 0
			for _, reward in ipairs(rewards) do
				if reward.itemType == "iron" then
					I = I + (reward.amount or 0)
				elseif reward.itemType == "diamond" then
					D = D + (reward.amount or 0)
				elseif reward.itemType == "emerald" then
					E = E + (reward.amount or 0)
				end
			end

			local playerName = getPlayerName(plr)
			local teamName = getTeamName(plr)
			local loot = string.format("%d irons, %d diamonds, %d emeralds", I, D, E)

			notif("KitSpy", string.format("%s (%s) opened their pinata and got %s", playerName, teamName, loot), 8)

			for pinataPart, data in pairs(trackedPinatas) do
				if data.player and data.player.UserId == plr.UserId then
					trackedPinatas[pinataPart] = nil
				end
			end
		end))

		local counter = 0
		KitSpy:Clean(runService.Heartbeat:Connect(function()
			if not LuciaToggle.Enabled then return end
			counter = counter + 1
			if counter % 6 ~= 0 then return end

			local toRemove = {}
			for pinataPart, data in pairs(trackedPinatas) do
				if pinataPart and pinataPart.Parent then
					local currentCandy = getCandyAmount(pinataPart)
					if currentCandy ~= data.lastCandy then
						local difference = currentCandy - data.lastCandy
						if difference > 0 and data.player then
							local playerName = getPlayerName(data.player)
							local teamName = getTeamName(data.player)
							notif("KitSpy", string.format("%s (%s) deposited %d candy (now %d)", playerName, teamName, difference, currentCandy), 5)
						end
						data.lastCandy = currentCandy
					end
				else
					if data.exists and data.player then
						local timeSincePlaced = tick() - (data.placedTime or tick())
						if timeSincePlaced > 2 then
							local playerName = getPlayerName(data.player)
							local teamName = getTeamName(data.player)
							notif("KitSpy", string.format("%s (%s) broke their pinata (had %d candy)", playerName, teamName, data.lastCandy), 5)
						end
					end
					table.insert(toRemove, pinataPart)
				end
			end

			for _, pinataPart in ipairs(toRemove) do
				trackedPinatas[pinataPart] = nil
			end
		end))
	end

	local function cleanupLucia()
		table.clear(trackedPinatas)
	end

	local function setupBountyHunterSpy()
		bedwars.Client:WaitFor(remotes.BountyHunterTargetChanged):andThen(function(rbx)
			KitSpy:Clean(rbx:Connect(function(tbl)
				if not BountyHunterToggle.Enabled then return end
				local hunter = tbl.hunter
				if not hunter then return end
				huntTargets[hunter] = {targetUserId = tbl.newTargetUserId, reward = tbl.reward}
				if not BountyTargetToggle.Enabled then return end
				local hunterName = getPlayerName(hunter)
				local targetPlr = tbl.newTargetUserId and tbl.newTargetUserId ~= 0 and playersService:GetPlayerByUserId(tbl.newTargetUserId)
				if targetPlr then
					notif("KitSpy", hunterName .. " is huntin " .. getPlayerName(targetPlr), 8)
				else
					notif("KitSpy", hunterName .. " lost their bounty target", 8)
				end
			end))
		end)

		KitSpy:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
			if not BountyHunterToggle.Enabled or not BountyLootToggle.Enabled then return end
			local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
			local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
			if not killer or not killed then return end
			local info = huntTargets[killer]
			if not info or info.targetUserId ~= killed.UserId then return end
			local reward = info.reward
			local iron = reward and reward.iron or 0
			local emerald = reward and reward.emerald or 0
			local lootText = 'iron x' .. iron
			if emerald and emerald > 0 then
				lootText = lootText .. ', emerald x' .. emerald
			end
			notif("KitSpy", getPlayerName(killer) .. " bounty killed " .. getPlayerName(killed) .. " | Loot: " .. lootText, 8)
			huntTargets[killer] = nil
		end))
	end

	local function cleanupBountyHunter()
		table.clear(huntTargets)
	end

	local function setupFishermanSpy()
		bedwars.Client:WaitFor(remotes.FishCaught):andThen(function(rbx)
			KitSpy:Clean(rbx:Connect(function(tbl)
				if not FishermanToggle.Enabled then return end
				local char = tbl.catchingPlayer and tbl.catchingPlayer.Character
				if not char then return end
				local fish = tbl.dropData and tbl.dropData.fishModel
				local allDrops = tbl.dropData and tbl.dropData.drops
				local plrName = char.Name
				local str = plrName:sub(1, 1):upper() .. plrName:sub(2)
				local strfish = FishNames[tostring(fish)] or 'Unknown Fish'
				local lootText = ''
				if allDrops then
					local totals = {}
					local order = {}
					for _, drop in ipairs(allDrops) do
						local item = tostring(drop.itemType) or 'unknown'
						local amount = tonumber(drop.amount) or 0
						if not totals[item] then
							totals[item] = 0
							table.insert(order, item)
						end
						totals[item] = totals[item] + amount
					end
					local parts = {}
					for _, item in ipairs(order) do
						table.insert(parts, item .. ' x' .. math.ceil(totals[item] * 1.4))
					end
					if #parts > 0 then
						lootText = ' | Loot: ' .. table.concat(parts, ', ')
					end
				end
				if FishermanIgnoreTeammates and FishermanIgnoreTeammates.Enabled then
					local currentplr = playersService:GetPlayerFromCharacter(char)
					if currentplr and currentplr.Team == lplr.Team then return end
				end
				notif("KitSpy", str .. " caught a " .. strfish .. lootText, 8)
			end))
		end)
	end

	KitSpy = vape.Categories.Kits:CreateModule({
		Name = "KitSpy",
		Tooltip = "gives u info on stuff other ppl are doing with certain kits - piston inspired :D",
		Function = function(callback)
			if callback then
				if BeehiveToggle.Enabled then setupBeehiveSpy() end
				if LuciaToggle.Enabled then setupLuciaSpy() end
				if FishermanToggle.Enabled then setupFishermanSpy() end
				if BountyHunterToggle.Enabled then setupBountyHunterSpy() end
			else
				cleanupBeehive()
				cleanupLucia()
				cleanupBountyHunter()
			end
		end
	})

	BeehiveToggle = KitSpy:CreateToggle({
		Name = 'Beehive',
		Function = function(callback)
			if BeehiveBackground and BeehiveBackground.Object then BeehiveBackground.Object.Visible = callback end
			if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = callback and BeehiveBackground.Enabled end
			if KitSpy.Enabled then
				if callback then setupBeehiveSpy() else cleanupBeehive() end
			end
		end
	})

	BeehiveBackground = KitSpy:CreateToggle({
		Name = 'Beehive Background',
		Default = true,
		Darker = true,
		Visible = false,
		Function = function(callback)
			if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = callback end
			for _, ref in BeehiveReference do
				if ref and ref.frame then
					local opacity = BeehiveColor and BeehiveColor.Opacity or 0.5
					ref.frame.BackgroundTransparency = 1 - (callback and opacity or 0)
				end
				if ref and ref.billboard then
					local blur = ref.billboard:FindFirstChild("Blur")
					if blur then blur.Visible = callback end
				end
			end
		end
	})

	BeehiveColor = KitSpy:CreateColorSlider({
		Name = 'Beehive Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Darker = true,
		Visible = false,
		Function = function(hue, sat, val, opacity)
			for _, ref in BeehiveReference do
				if ref and ref.frame then
					ref.frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					ref.frame.BackgroundTransparency = 1 - (BeehiveBackground.Enabled and opacity or 0)
				end
			end
		end
	})

	LuciaToggle = KitSpy:CreateToggle({
		Name = 'Lucia',
		Function = function(callback)
			if LuciaIgnoreTeammates and LuciaIgnoreTeammates.Object then LuciaIgnoreTeammates.Object.Visible = callback end
			if LuciaDisplayName and LuciaDisplayName.Object then LuciaDisplayName.Object.Visible = callback end
			if KitSpy.Enabled then
				if callback then setupLuciaSpy() else cleanupLucia() end
			end
		end
	})

	LuciaIgnoreTeammates = KitSpy:CreateToggle({
		Name = 'Lucia Ignore Teammates',
		Default = true,
		Darker = true,
		Visible = false,
	})

	LuciaDisplayName = KitSpy:CreateToggle({
		Name = 'Lucia Display Name',
		Default = false,
		Darker = true,
		Visible = false,
	})

	FishermanToggle = KitSpy:CreateToggle({
		Name = 'Fisherman',
		Function = function(callback)
			if FishermanIgnoreTeammates and FishermanIgnoreTeammates.Object then FishermanIgnoreTeammates.Object.Visible = callback end
			if KitSpy.Enabled and callback then
				setupFishermanSpy()
			end
		end
	})

	FishermanIgnoreTeammates = KitSpy:CreateToggle({
		Name = 'Fisherman Ignore Teammates',
		Default = true,
		Darker = true,
		Visible = false,
	})

	BountyHunterToggle = KitSpy:CreateToggle({
		Name = 'Bounty Hunter',
		Tooltip = 'shows u who a bounty hunter is huntin and the loot they get when they get em',
		Function = function(callback)
			if BountyTargetToggle and BountyTargetToggle.Object then BountyTargetToggle.Object.Visible = callback end
			if BountyLootToggle and BountyLootToggle.Object then BountyLootToggle.Object.Visible = callback end
			if KitSpy.Enabled then
				if callback then setupBountyHunterSpy() else cleanupBountyHunter() end
			end
		end
	})

	BountyTargetToggle = KitSpy:CreateToggle({
		Name = 'Bounty Hunter Target',
		Default = true,
		Darker = true,
		Visible = false,
	})

	BountyLootToggle = KitSpy:CreateToggle({
		Name = 'Bounty Hunter Loot',
		Default = true,
		Darker = true,
		Visible = false,
	})
end)
run(function()
	local PlayerProfileSpoof
	local RankDrop
	local RPSlider
	local LBSlider
	local ImageId = require(game:GetService('ReplicatedStorage').TS.image['image-id']).BedwarsImageId

	local rankKeys = {
		['Bronze 1'] = 'BRONZE_RANK', ['Bronze 2'] = 'BRONZE_RANK', ['Bronze 3'] = 'BRONZE_RANK',
		['Silver 1'] = 'SILVER_RANK', ['Silver 2'] = 'SILVER_RANK', ['Silver 3'] = 'SILVER_RANK',
		['Gold 1'] = 'GOLD_RANK', ['Gold 2'] = 'GOLD_RANK', ['Gold 3'] = 'GOLD_RANK',
		['Platinum 1'] = 'PLATINUM_RANK', ['Platinum 2'] = 'PLATINUM_RANK', ['Platinum 3'] = 'PLATINUM_RANK',
		['Diamond 1'] = 'DIAMOND_RANK', ['Diamond 2'] = 'DIAMOND_RANK', ['Diamond 3'] = 'DIAMOND_RANK',
		['Emerald 1'] = 'EMERALD_RANK', ['Emerald 2'] = 'EMERALD_RANK', ['Emerald 3'] = 'EMERALD_RANK',
		Nightmare = 'NIGHTMARE_RANK'
	}

	local barColors = {
		Bronze = Color3.fromRGB(188, 110, 60),
		Silver = Color3.fromRGB(180, 180, 190),
		Gold = Color3.fromRGB(255, 200, 0),
		Platinum = Color3.fromRGB(60, 220, 255),
		Diamond = Color3.fromRGB(90, 150, 255),
		Emerald = Color3.fromRGB(0, 200, 100)
	}

	local rankImages = {}
	for _, key in {'BRONZE_RANK', 'SILVER_RANK', 'GOLD_RANK', 'PLATINUM_RANK', 'DIAMOND_RANK', 'EMERALD_RANK', 'NIGHTMARE_RANK'} do
		local img = ImageId[key]
		if img and img ~= '' then
			rankImages[img] = true
		end
	end

	local hooked = setmetatable({}, {__mode = 'k'})
	local addedConn
	local scanThread
	local busy = false

	local function fix(obj)
		if not PlayerProfileSpoof.Enabled then return end
		local rank = RankDrop.Value
		local rp = RPSlider.Value
		local nightmare = rank == 'Nightmare'

		busy = true
		if obj:IsA('ImageLabel') then
			local img = ImageId[rankKeys[rank]]
			if rankImages[obj.Image] and obj.Image ~= img then
				obj.Image = img
			end
		elseif obj:IsA('TextLabel') then
			if obj.Name == 'CurrentRP' then
				obj.Visible = not nightmare
				if not nightmare then
					obj.Text = rp .. ' RP / 100'
				end
			elseif obj.Name == 'RankName' then
				obj.Text = rank
			elseif obj.Text:find('Leaderboard Rank:') then
				local txt = 'Leaderboard Rank: ' .. LBSlider.Value
				if obj.Text ~= txt then
					obj.Text = txt
				end
			end
		elseif obj.Name == 'ProgressBar' then
			obj.Visible = not nightmare
			if not nightmare then
				local col = barColors[rank:match('^(%a+)')]
				if col then
					obj.BackgroundColor3 = col
				end
				obj.Size = UDim2.new(math.clamp(rp / 100, 0, 1), 0, obj.Size.Y.Scale, obj.Size.Y.Offset)
			end
		elseif obj.Name == 'ProgressBarContainer' then
			obj.Visible = not nightmare
		end
		busy = false
	end

	local function wanted(obj)
		if obj:IsA('ImageLabel') then
			return rankImages[obj.Image] == true
		elseif obj:IsA('TextLabel') then
			return obj.Name == 'CurrentRP' or obj.Name == 'RankName' or obj.Text:find('Leaderboard Rank:') ~= nil
		elseif obj:IsA('Frame') then
			return obj.Name == 'ProgressBar' or obj.Name == 'ProgressBarContainer'
		end
		return false
	end

	local function hook(obj)
		if hooked[obj] or not wanted(obj) then return end
		local props = {'Visible', 'Size', 'BackgroundColor3'}
		if obj:IsA('ImageLabel') then
			props = {'Image'}
		elseif obj:IsA('TextLabel') then
			props = {'Text', 'Visible'}
		end
		local real = {}
		local conns = {}
		for _, prop in props do
			real[prop] = obj[prop]
			table.insert(conns, obj:GetPropertyChangedSignal(prop):Connect(function()
				if not busy then
					real[prop] = obj[prop]
					fix(obj)
				end
			end))
		end
		hooked[obj] = {conns = conns, real = real}
		fix(obj)
	end

	local function scan()
		local gui = lplr:FindFirstChild('PlayerGui')
		if not gui then return end
		for _, obj in gui:GetDescendants() do
			if hooked[obj] then
				fix(obj)
			else
				hook(obj)
			end
		end
	end

	local function unhook()
		if scanThread then
			task.cancel(scanThread)
			scanThread = nil
		end
		if addedConn then
			addedConn:Disconnect()
			addedConn = nil
		end
		for obj, data in hooked do
			for _, c in data.conns do
				c:Disconnect()
			end
			if obj.Parent then
				busy = true
				for prop, value in data.real do
					pcall(function()
						obj[prop] = value
					end)
				end
				busy = false
			end
			hooked[obj] = nil
		end
	end

	PlayerProfileSpoof = vape.Categories.Minigames:CreateModule({
		Name = 'PlayerProfileSpoof',
		Function = function(callback)
			unhook()
			if callback then
				local gui = lplr:FindFirstChild('PlayerGui') or lplr:WaitForChild('PlayerGui')
				addedConn = gui.DescendantAdded:Connect(function(obj)
					if PlayerProfileSpoof.Enabled then
						hook(obj)
					end
				end)
				scan()
				scanThread = task.spawn(function()
					while PlayerProfileSpoof.Enabled do
						task.wait(0.5)
						scan()
					end
				end)
			end
		end,
		Tooltip = 'fakes ur rank, rp bar n leaderboard spot on ur profile (only u see it)'
	})

	RankDrop = PlayerProfileSpoof:CreateDropdown({
		Name = 'Rank',
		List = {
			'Bronze 1', 'Bronze 2', 'Bronze 3',
			'Silver 1', 'Silver 2', 'Silver 3',
			'Gold 1', 'Gold 2', 'Gold 3',
			'Platinum 1', 'Platinum 2', 'Platinum 3',
			'Diamond 1', 'Diamond 2', 'Diamond 3',
			'Emerald 1', 'Emerald 2', 'Emerald 3',
			'Nightmare'
		},
		Default = 'Nightmare',
		Function = function()
			if PlayerProfileSpoof.Enabled then scan() end
		end
	})

	RPSlider = PlayerProfileSpoof:CreateSlider({
		Name = 'RP',
		Min = 0,
		Max = 100,
		Default = 50,
		Function = function()
			if PlayerProfileSpoof.Enabled then scan() end
		end
	})

	LBSlider = PlayerProfileSpoof:CreateSlider({
		Name = 'Leaderboard Rank',
		Min = 1,
		Max = 10000,
		Default = 1,
		Function = function()
			if PlayerProfileSpoof.Enabled then scan() end
		end
	})
end)
run(function()
	local StatsBoardSpoof
	local RankDrop, LBSlider, RPSlider, LevelSlider, WinsSlider, BedsSlider, KillsSlider, HonorSlider
	local ImageId = require(game:GetService('ReplicatedStorage').TS.image['image-id']).BedwarsImageId
	local rankList = {}
	local rankImageKey = {}
	for _, tier in {'Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond', 'Emerald'} do
		for i = 1, 4 do
			local name = tier .. ' ' .. i
			table.insert(rankList, name)
			rankImageKey[name] = tier:upper() .. '_RANK'
		end
	end
	table.insert(rankList, 'Nightmare')
	rankImageKey.Nightmare = 'NIGHTMARE_RANK'

	local barColors = {
		Bronze = Color3.fromRGB(188, 110, 60),
		Silver = Color3.fromRGB(180, 180, 190),
		Gold = Color3.fromRGB(255, 200, 0),
		Platinum = Color3.fromRGB(60, 220, 255),
		Diamond = Color3.fromRGB(90, 150, 255),
		Emerald = Color3.fromRGB(0, 200, 100)
	}

	local watchProps = {
		rankImage = {'Image'},
		levelLabel = {'Text'},
		rankName = {'Text'},
		lbRank = {'Text'},
		currentRP = {'Text', 'Visible'},
		rpHolder = {'Visible'},
		rpBar = {'Size', 'BackgroundColor3'},
		honorVal = {'Text'},
		winsVal = {'Text'},
		bedVal = {'Text'},
		killsVal = {'Text'}
	}

	local hooked = setmetatable({}, {__mode = 'k'})
	local scanThread
	local busy = false

	local function commas(n)
		local s = tostring(math.floor(n))
		local out = ''
		for i = 1, #s do
			out = out .. s:sub(i, i)
			if (#s - i) % 3 == 0 and i ~= #s then
				out = out .. ','
			end
		end
		return out
	end

	local function getBoard()
		local lobby = workspace:FindFirstChild('Lobby')
		local boards = lobby and lobby:FindFirstChild('Boards')
		local sb = boards and boards:FindFirstChild('StatsBoard')
		local board = sb and sb:FindFirstChild('Board')
		return board and board:FindFirstChild('StatsBoard')
	end

	local function child(obj, ...)
		for _, name in {...} do
			obj = obj and obj:FindFirstChild(name)
		end
		return obj
	end

	local function getElements(gui)
		local inner = child(gui, '1', '1')
		local scroll = inner and inner:FindFirstChild('AutoCanvasScrollingFrame')
		if not scroll then return nil end
		local level = scroll:FindFirstChild('3')
		local rankDisplay = child(scroll, '4', '3')
		local rankInfo = rankDisplay and rankDisplay:FindFirstChild('3')
		local nameFrame = rankInfo and rankInfo:FindFirstChild('2')
		local rpFrame = rankInfo and rankInfo:FindFirstChild('3')
		local holder = rpFrame and rpFrame:FindFirstChild('ProgressBarContainer')
		local stats = child(scroll, '5', '3', '2')
		return {
			rankImage = rankDisplay and rankDisplay:FindFirstChild('2'),
			levelLabel = level and level:FindFirstChild('2'),
			rankName = nameFrame and nameFrame:FindFirstChild('RankName'),
			lbRank = nameFrame and nameFrame:FindFirstChild('LeaderboardRank'),
			currentRP = rpFrame and rpFrame:FindFirstChild('CurrentRP'),
			rpHolder = holder,
			rpBar = holder and holder:FindFirstChild('ProgressBar'),
			honorVal = child(stats, '2', '5'),
			winsVal = child(stats, '3', '5'),
			bedVal = child(stats, '4', '5'),
			killsVal = child(stats, '5', '5')
		}
	end

	local function wanted(key)
		local rank = RankDrop.Value
		local nightmare = rank == 'Nightmare'
		local rp = math.floor(RPSlider.Value)
		if key == 'rankImage' then
			local img = ImageId[rankImageKey[rank]]
			return img and {Image = img} or {}
		elseif key == 'levelLabel' then
			return {Text = 'Player Level ' .. math.floor(LevelSlider.Value)}
		elseif key == 'rankName' then
			return {Text = rank}
		elseif key == 'lbRank' then
			return {Text = 'Leaderboard Rank: <b><font color="rgb(185,188,255)">' .. commas(LBSlider.Value) .. '</font></b>'}
		elseif key == 'currentRP' then
			if nightmare then
				return {Visible = false}
			end
			return {Visible = true, Text = '<b><font color="#ffffff">' .. rp .. ' RP</font></b> / 100'}
		elseif key == 'rpHolder' then
			return {Visible = not nightmare}
		elseif key == 'rpBar' then
			if nightmare then return {} end
			return {Size = UDim2.new(rp / 100, 0, 1, 0), BackgroundColor3 = barColors[rank:match('^(%a+)')]}
		elseif key == 'honorVal' then
			return {Text = tostring(math.floor(HonorSlider.Value))}
		elseif key == 'winsVal' then
			return {Text = tostring(math.floor(WinsSlider.Value))}
		elseif key == 'bedVal' then
			return {Text = tostring(math.floor(BedsSlider.Value))}
		elseif key == 'killsVal' then
			return {Text = tostring(math.floor(KillsSlider.Value))}
		end
		return {}
	end

	local function fix(obj)
		local data = hooked[obj]
		if not data or not StatsBoardSpoof.Enabled then return end
		busy = true
		for prop, value in wanted(data.key) do
			if obj[prop] ~= value then
				obj[prop] = value
			end
		end
		busy = false
	end

	local function hook(obj, key)
		if hooked[obj] then return end
		local data = {key = key, real = {}, conns = {}}
		hooked[obj] = data
		for _, prop in watchProps[key] do
			data.real[prop] = obj[prop]
			table.insert(data.conns, obj:GetPropertyChangedSignal(prop):Connect(function()
				if not busy then
					data.real[prop] = obj[prop]
					fix(obj)
				end
			end))
		end
		fix(obj)
	end

	local function scan()
		local gui = getBoard()
		local parts = gui and getElements(gui)
		if not parts then return false end
		for key, obj in parts do
			if hooked[obj] then
				fix(obj)
			else
				hook(obj, key)
			end
		end
		return true
	end

	local function unhook()
		if scanThread then
			task.cancel(scanThread)
			scanThread = nil
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

	local function refresh()
		if StatsBoardSpoof.Enabled then
			scan()
		end
	end

	StatsBoardSpoof = vape.Categories.Minigames:CreateModule({
		Name = 'StatsBoardSpoof',
		Function = function(callback)
			unhook()
			if callback then
				if not scan() then
					notif('StatsBoardSpoof', 'cant find the stats board, u gotta be in the lobby', 3)
				end
				scanThread = task.spawn(function()
					while StatsBoardSpoof.Enabled do
						task.wait(0.5)
						scan()
					end
				end)
			end
		end,
		Tooltip = 'fakes ur stats on the lobby stats board (only u see it)'
	})

	RankDrop = StatsBoardSpoof:CreateDropdown({
		Name = 'Rank',
		List = rankList,
		Default = 'Silver 3',
		Function = refresh
	})
	LBSlider = StatsBoardSpoof:CreateSlider({
		Name = 'Leaderboard Rank',
		Min = 1,
		Max = 100000,
		Default = 11469,
		Decimal = 1,
		Function = refresh
	})
	RPSlider = StatsBoardSpoof:CreateSlider({
		Name = 'RP',
		Min = 0,
		Max = 100,
		Default = 26,
		Decimal = 1,
		Function = refresh
	})
	LevelSlider = StatsBoardSpoof:CreateSlider({
		Name = 'Player Level',
		Min = 1,
		Max = 200,
		Default = 40,
		Decimal = 1,
		Function = refresh
	})
	WinsSlider = StatsBoardSpoof:CreateSlider({
		Name = 'Wins',
		Min = 0,
		Max = 50000,
		Default = 621,
		Decimal = 1,
		Function = refresh
	})
	BedsSlider = StatsBoardSpoof:CreateSlider({
		Name = 'Bed Breaks',
		Min = 0,
		Max = 50000,
		Default = 269,
		Decimal = 1,
		Function = refresh
	})
	KillsSlider = StatsBoardSpoof:CreateSlider({
		Name = 'Final Kills',
		Min = 0,
		Max = 100000,
		Default = 457,
		Decimal = 1,
		Function = refresh
	})
	HonorSlider = StatsBoardSpoof:CreateSlider({
		Name = 'Honor',
		Min = 0,
		Max = 10000,
		Default = 2,
		Decimal = 1,
		Function = refresh
	})
end)
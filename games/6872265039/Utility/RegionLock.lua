run(function()
	local RegionLock
	local AllowedRegions
	local readyGate = getgenv().aeroReadyGate or {Release = function() end}
	local lockLabel = 'next match'
	local knownRegion
	local fetchBusy = false
	local nextFetch = 0
	local warnedUnknown = false
	local shorthand = {
		AU = 'SEA', AUS = 'SEA', AUSTRALIA = 'SEA', NZ = 'SEA', OCE = 'SEA', OCEANIA = 'SEA',
		AS = 'SEA', ASIA = 'SEA', SG = 'SEA', SGP = 'SEA',
		US = 'NA', USA = 'NA', AMERICA = 'NA',
		EUROPE = 'EU', GB = 'EU', UK = 'EU'
	}

	local function normalize(text)
		text = tostring(text):gsub('%s+', ''):upper()
		return shorthand[text] or text
	end

	local function currentRegion()
		local okState, gameState = pcall(function()
			return bedwars.Store:getState().Game
		end)
		local fromStore = okState and type(gameState) == 'table' and gameState.serverRegion or nil
		if type(fromStore) == 'string' and fromStore ~= '' then
			knownRegion = fromStore
			return fromStore
		end
		if not knownRegion and not fetchBusy and os.clock() >= nextFetch then
			fetchBusy = true
			task.spawn(function()
				local okFetch, reply = pcall(function()
					return bedwars.Client:Get('FetchServerRegion'):CallServer()
				end)
				nextFetch = os.clock() + 5
				fetchBusy = false
				if okFetch and type(reply) == 'string' and reply ~= '' then
					knownRegion = reply
				end
			end)
		end
		return knownRegion
	end

	local function regionOk()
		if #AllowedRegions.ListEnabled == 0 then
			return true
		end
		local region = currentRegion()
		if not region then
			return false
		end
		region = normalize(region)
		for _, want in AllowedRegions.ListEnabled do
			want = normalize(want)
			if want ~= '' and region:sub(1, #want) == want then
				return true
			end
		end
		return false
	end

	RegionLock = vape.Categories.Utility:CreateModule({
		Name = 'RegionLock',
		Function = function(callback)
			if callback then
				readyGate.Claimed = true
				warnedUnknown = false
				repeat
					if not readyGate.Held then
						lockLabel = lplr:GetAttribute('PlayerConnected') and 'loaded' or 'next match'
					else
						local heldSince = readyGate.Started or os.clock()
						if regionOk() then
							lockLabel = knownRegion or 'any region'
							readyGate.Release()
						elseif knownRegion then
							lockLabel = 'wrong region ('..knownRegion..')'
						elseif os.clock() - heldSince >= 20 then
							if not warnedUnknown then
								warnedUnknown = true
								notif('RegionLock', 'couldnt read this server region so ur loadin in anyway', 8, 'warning')
							end
							lockLabel = 'unknown region'
							readyGate.Release()
						else
							lockLabel = 'finding region'
						end
					end
					task.wait(0.5)
				until not RegionLock.Enabled
			else
				readyGate.Release()
				lockLabel = 'loaded'
				readyGate.Claimed = false
			end
		end,
		ExtraText = function()
			return lockLabel
		end,
		Tooltip = 'keeps u outta matches that aint in the regions u picked bedwars only has NA,EU adn SEA n picks urs from ur account country so this only skips the odd server in another region'
	})

	AllowedRegions = RegionLock:CreateTextList({
		Name = 'Regions',
		Placeholder = 'NA / EU / SEA',
		Default = {'NA', 'EU', 'SEA'},
		Function = function()
			if not AllowedRegions then
				return
			end
			for i, v in AllowedRegions.List do
				AllowedRegions.List[i] = v:gsub('%s+', ''):upper()
			end
			for i, v in AllowedRegions.ListEnabled do
				AllowedRegions.ListEnabled[i] = v:gsub('%s+', ''):upper()
			end
		end,
		Tooltip = 'turn off the regions u dont want. AUS OCE AU n NZ count as SEA n US counts as NA. leavin them all on lets anything in'
	})

	task.spawn(function()
		repeat
			task.wait()
		until vape.Loaded ~= false
		if vape.Loaded and not readyGate.Claimed then
			readyGate.Release()
		end
	end)
end)
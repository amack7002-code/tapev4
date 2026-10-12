run(function()
	local StaffHUD
	local ShowSpec
	local ShowMod
	local ShowImpossible
	local STAFF_GROUP_ID = 5774246
	local STAFF_MIN_RANK = 100

	local rowDefs = {
		{key='spec', label='Spec', color=Color3.fromRGB(100,180,255), order=1},
		{key='mod', label='Mod', color=Color3.fromRGB(255,60,60), order=3},
		{key='impossible', label='Impossible', color=Color3.fromRGB(200,50,255), order=4},
	}

	local tracked  = {}
	local counts   = {spec=0, closet=0, mod=0, impossible=0}
	local watchers = {}

	local apiClosetNames = {}
	local apiModNames = {}
	local listsLoaded = false

	local function loadLists()
		for _, name in ipairs({'chasemaser','IllIlllIIIllllIIIll','7SlyR','DoordashRP','OrionYeets','lIllllllllllIllIIlll','AUW345678','the2ndtestaccount','IllIIIIlllIlllIIIIIl','IllIIIIlllIlllIlIIII','ProSurferGamer1','22willow_place','celisnix','G_TP56','celisnix_3','nwrkr','lIIlIlIllllllIIlI','IllIIIIIIlllllIIlIlI','GorillaWithASuit','liilliilliiiliill','IllIllIllllIIIIIIlIl','Typhoon_Kang','VictoryForLife2468','IlIIIlllllIIIIlIIIIl','Erin_Ireland22','IIIIllIIIIIIlllIlIII','IIIIIlllIlllllIlII','Ghostwxstaken','wvwvwvwwvwvvwvw','lllIIllIllIIllIllII','TheAwkwardSponge','TotallyKoaIa','YT_GoraPlays','LegendaryToragon','appleapplelllllll','Yo_johnny67','llIIllIIllllIlIl','PoopFarm_1','llIIIllIIIIIllllIII','Lemon01204','HugeMudOtter','AGameMasterHD','krustykrab204','kevinchuey','IllIIIIlIllIlIIIlI','YoZevStar','pzlican','Deevicus','Blackprincess1','yhpro1230','eple_147','whoisdv2_erin','whoisdv4_erin','whoisdv3_erin','VicForLife14','SleeplessSoulmate','Jsquire07','DVwastaken','pxIican','devzebu','FunFamilyKids177','Artan3333','3MEWMTS5LJCB','Zengoulen','GloriousConfigB2','heywasupsir','c6chisa'}) do
			apiModNames[name:lower()] = true
		end
		listsLoaded = true
	end

	local gui = Instance.new('ScreenGui')
	gui.Name = 'StaffHUD'
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = vape.gui
	gui.Enabled = false

	local frame = Instance.new('Frame')
	frame.Name = 'Container'
	frame.Parent = gui
	frame.BackgroundColor3 = Color3.fromRGB(15,15,15)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(1,1)
	frame.Position = UDim2.new(1,-8,1,-8)
	frame.Size = UDim2.new(0,110,0,14)
	frame.AutomaticSize = Enum.AutomaticSize.Y

	local uicorner = Instance.new('UICorner')
	uicorner.CornerRadius = UDim.new(0,6)
	uicorner.Parent = frame

	local pad = Instance.new('UIPadding')
	pad.PaddingLeft=UDim.new(0,6) pad.PaddingRight=UDim.new(0,6)
	pad.PaddingTop=UDim.new(0,4)  pad.PaddingBottom=UDim.new(0,4)
	pad.Parent = frame

	local layout = Instance.new('UIListLayout')
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0,2)
	layout.Parent = frame

	local rowObjects = {}
	for _, r in rowDefs do
		local lbl = Instance.new('TextLabel')
		lbl.Name = r.key
		lbl.Parent = frame
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1,0,0,13)
		lbl.TextColor3 = r.color
		lbl.TextSize = 11
		lbl.Font = Enum.Font.GothamBold
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextStrokeTransparency = 0.4
		lbl.TextStrokeColor3 = Color3.new(0,0,0)
		lbl.LayoutOrder = r.order
		lbl.Visible = false
		rowObjects[r.key] = lbl
	end

	local function updateDisplay()
		if not StaffHUD or not StaffHUD.Enabled then gui.Enabled = false return end
		local toggleMap = {spec=ShowSpec,mod=ShowMod,impossible=ShowImpossible}
		local anyVisible = false
		for _, r in rowDefs do
			local show = toggleMap[r.key] and toggleMap[r.key].Enabled
			rowObjects[r.key].Text = r.label .. ': ' .. (counts[r.key] or 0)
			rowObjects[r.key].Visible = show
			if show then anyVisible = true end
		end
		gui.Enabled = anyVisible
	end

	local function setTracked(userId, newCat)
		local old = tracked[userId]
		if old == newCat then return end
		if old then counts[old] = math.max(0,(counts[old] or 1)-1) end
		if newCat then
			tracked[userId] = newCat
			counts[newCat] = (counts[newCat] or 0) + 1
		else
			tracked[userId] = nil
		end
		updateDisplay()
	end

	local function removePlayer(userId)
		setTracked(userId, nil)
		if watchers[userId] then
			for _, c in ipairs(watchers[userId]) do pcall(function() c:Disconnect() end) end
			watchers[userId] = nil
		end
	end

	local function hasFriendInServer(plr)
		for _, other in ipairs(playersService:GetPlayers()) do
			if other ~= plr then
				local ok, res = pcall(function() return plr:IsFriendsWith(other.UserId) end)
				if ok and res then return true end
			end
		end
		return false
	end

	local function recheckSpec(plr)
		if not StaffHUD or not StaffHUD.Enabled then return end
		local cat = tracked[plr.UserId]
		if cat == 'closet' or cat == 'mod' then return end
		if plr:GetAttribute('Spectator') == true then
			task.spawn(function()
				local hasFriend = hasFriendInServer(plr)
				setTracked(plr.UserId, hasFriend and 'spec' or 'impossible')
			end)
		else
			if cat == 'spec' or cat == 'impossible' then
				setTracked(plr.UserId, nil)
			end
		end
	end

	local function watchPlayer(plr)
		if plr == lplr or watchers[plr.UserId] then return end
		local conns = {}
		table.insert(conns, plr:GetAttributeChangedSignal('Spectator'):Connect(function() recheckSpec(plr) end))
		table.insert(conns, plr:GetAttributeChangedSignal('Team'):Connect(function() recheckSpec(plr) end))
		watchers[plr.UserId] = conns
	end

	local function classifyPlayer(plr)
		if plr == lplr then return end
		local lowerName = plr.Name:lower()
		if apiModNames[lowerName] then
			setTracked(plr.UserId, 'mod')
			watchPlayer(plr)
			return
		end

		watchPlayer(plr)
		recheckSpec(plr)
	end

	local function cleanAll()
		for _, conns in pairs(watchers) do
			for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		end
		table.clear(watchers)
		table.clear(tracked)
		counts = {spec=0, closet=0, mod=0, impossible=0}
	end

	StaffHUD = vape.Categories.Utility:CreateModule({
		Name = 'StaffHUD',
		Function = function(callback)
			if callback then
				cleanAll()
				loadLists()
				task.spawn(function()
					local t = tick()
					repeat task.wait(0.1) until listsLoaded or (tick() - t > 5)
					for _, plr in ipairs(playersService:GetPlayers()) do
						classifyPlayer(plr)
					end
				end)
				StaffHUD:Clean(playersService.PlayerAdded:Connect(function(plr)
					classifyPlayer(plr)
				end))
				StaffHUD:Clean(playersService.PlayerRemoving:Connect(function(plr)
					removePlayer(plr.UserId)
				end))
				StaffHUD:Clean(runService.Heartbeat:Connect(function()
					local compactUI = vape.gui:FindFirstChild('GeneratorCompactUI')
					frame.Position = (compactUI and compactUI.Enabled) and UDim2.new(1, -136, 1, -8) or UDim2.new(1, -8, 1, -8)
				end))
				updateDisplay()
			else
				cleanAll()
				table.clear(apiClosetNames)
				table.clear(apiModNames)
				listsLoaded = false
				gui.Enabled = false
			end
		end,
		Tooltip = 'little counter ui for staff'
	})

	ShowSpec = StaffHUD:CreateToggle({Name='Spectators', Default=true, Function=function() updateDisplay() end})
	ShowMod = StaffHUD:CreateToggle({Name='Mods', Default=true, Function=function() updateDisplay() end})
	ShowImpossible = StaffHUD:CreateToggle({Name='Impossible Joins',Default=true, Function=function() updateDisplay() end})

	vape:Clean(function()
		cleanAll()
		pcall(function() gui:Destroy() end)
	end)
end)
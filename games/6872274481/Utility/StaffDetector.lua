run(function()
	local StaffDetector
	local Mode
	local Clans
	local Party
	local Profile
	local Users
	local AlertDuration
	local blacklistedclans = {'gg', 'gg2', 'DV', 'DV2', 'nwr'}
	local blacklisteduserids = {1502104539, 3826146717, 4531785383, 1049767300, 4926350670, 653085195, 184655415, 2752307430, 5087196317, 5744061325, 1536265275}
	local apiModNames = {}
	local teamNameMap = { [1] = 'Blue', [2] = 'Orange', [3] = 'Pink', [4] = 'Yellow' }
	local joined = {}
	local detectedPlayers = {}
	local processing = {}
	for _, name in ipairs({'chasemaser','IllIlllIIIllllIIIll','7SlyR','DoordashRP','OrionYeets','lIllllllllllIllIIlll','AUW345678','the2ndtestaccount','IllIIIIlllIlllIIIIIl','IllIIIIlllIlllIlIIII','ProSurferGamer1','22willow_place','celisnix','G_TP56','celisnix_3','nwrkr','lIIlIlIllllllIIlI','IllIIIIIIlllllIIlIlI','GorillaWithASuit','liilliilliiiliill','IllIllIllllIIIIIIlIl','Typhoon_Kang','VictoryForLife2468','IlIIIlllllIIIIlIIIIl','Erin_Ireland22','IIIIllIIIIIIlllIlIII','IIIIIlllIlllllIlII','Ghostwxstaken','wvwvwvwwvwvvwvw','lllIIllIllIIllIllII','TheAwkwardSponge','TotallyKoaIa','YT_GoraPlays','LegendaryToragon','appleapplelllllll','Yo_johnny67','llIIllIIllllIlIl','PoopFarm_1','llIIIllIIIIIllllIII','Lemon01204','HugeMudOtter','AGameMasterHD','krustykrab204','kevinchuey','IllIIIIlIllIlIIIlI','YoZevStar','pzlican','Deevicus','Blackprincess1','yhpro1230','eple_147','whoisdv2_erin','whoisdv4_erin','whoisdv3_erin','VicForLife14','SleeplessSoulmate','Jsquire07','DVwastaken','pxIican','devzebu','FunFamilyKids177','Artan3333','3MEWMTS5LJCB','Zengoulen','GloriousConfigB2','heywasupsir','c6chisa'}) do
		apiModNames[name:lower()] = true
	end
	local listsLoaded = true

	getgenv()._onnation_staffCounts = {spec=0, mod=0, impossible=0}
	local function refreshStaffCounts()
		local c = {spec=0, mod=0, impossible=0}
		for _, data in pairs(detectedPlayers) do
			local ct = data.checktype
			if ct == 'spectator' then c.spec += 1
			elseif ct == 'impossible_join' then c.impossible += 1
			elseif ct == 'unverified' then c.impossible += 1
			else c.mod += 1 end
		end
		getgenv()._aerov4_staffCounts = c
		vapeEvents.StaffCountUpdate:Fire()
	end

	local function staffFunction(plr, checktype)
		if detectedPlayers[plr.UserId] then return end
		if not vape.Loaded then repeat task.wait() until vape.Loaded end
		local duration = AlertDuration.Value
		local playerName = plr.Name
		local playerId = plr.UserId
		detectedPlayers[playerId] = {name=playerName, checktype=checktype, detectedTime=tick()}
		notif('StaffDetector', 'Staff Detected (' .. checktype .. '): ' .. playerName .. ' (' .. playerId .. ')', duration, 'alert')
		whitelist.customtags[playerName] = {{text='GAME STAFF', color=Color3.new(1,0,0)}}
		local isClanCheck = checktype:find('clan')
		if Party.Enabled and not isClanCheck then pcall(bedwars.PartyController.leaveParty) end
		local modeValue = Mode.Value
		if modeValue == 'Uninject' then
			task.spawn(function() vape:Uninject() end)
			game:GetService('StarterGui'):SetCore('SendNotification', {Title='StaffDetector',Text='Staff Detected ('..checktype..')\n'..playerName..' ('..playerId..')',Duration=duration})
		elseif modeValue == 'Requeue' then
			pcall(bedwars.QueueController.leaveQueue)
			bedwars.QueueController:joinQueue(store.queueType)
		elseif modeValue == 'Profile' then
			if checktype == 'known_mod' or checktype == 'blacklisted_user' then
				vape.Save = function() end
				if vape.Profile ~= Profile.Value then vape:Load(true, Profile.Value) end
			end
		elseif modeValue == 'AutoConfig' then
			local safe = {AutoClicker=true,Reach=true,Sprint=true,HitFix=true,StaffDetector=true}
			vape.Save = function() end
			for i, v in vape.Modules do
				if not (safe[i] or v.Category == 'Render') then
					if v.Enabled then v:Toggle() end
					v:SetBind('')
				end
			end
		end
		refreshStaffCounts()
	end

	local function playerAdded(plr)
		joined[plr.UserId] = plr.Name
		if plr == lplr then return end
		if processing[plr.UserId] then return end
		processing[plr.UserId] = true

		if not listsLoaded then
			local t = tick()
			repeat task.wait(0.1) until listsLoaded or (tick()-t > 3)
		end

		if table.find(blacklisteduserids, plr.UserId) or (Users and table.find(Users.ListEnabled, tostring(plr.UserId))) then
			staffFunction(plr, 'blacklisted_user')
			processing[plr.UserId] = nil
			return
		end

		if apiModNames[plr.Name:lower()] then
			staffFunction(plr, 'known_mod')
			processing[plr.UserId] = nil
			return
		end

		local function spectatorFunction(plr)
			if detectedPlayers[plr.UserId] then return end
			if not vape.Loaded then repeat task.wait() until vape.Loaded end
			detectedPlayers[plr.UserId] = {name=plr.Name, checktype='spectator', detectedTime=tick()}
			notif('StaffDetector', 'Spectator: '..plr.Name..' ('..tostring(plr.UserId)..') [has friend(s) in server]', AlertDuration.Value, 'warning')
			refreshStaffCounts()
		end

		local function unverifiedFunction(plr, failed, checked)
			if detectedPlayers[plr.UserId] then return end
			if not vape.Loaded then repeat task.wait() until vape.Loaded end
			detectedPlayers[plr.UserId] = {name=plr.Name, checktype='unverified', detectedTime=tick()}
			notif('StaffDetector', 'cant check '..plr.Name..' ('..tostring(plr.UserId)..') friends list gng, could be staff. couldnt check '..tostring(failed)..'/'..tostring(checked)..' ppl', AlertDuration.Value, 'warning')
			refreshStaffCounts()
		end

		local function checkJoin()
			if not plr:GetAttribute('Team') and plr:GetAttribute('Spectator') then
				local hasFriend = false
				local failed = 0
				local checked = 0
				for _, sp in ipairs(playersService:GetPlayers()) do
					if sp ~= plr then
						checked = checked + 1
						local ok, res = pcall(function() return plr:IsFriendsWith(sp.UserId) end)
						if not ok then failed = failed + 1 end
						if ok and res then hasFriend = true break end
					end
				end
				if hasFriend then
					spectatorFunction(plr)
				elseif failed > 0 or checked == 0 then
					unverifiedFunction(plr, failed, checked)
				else
					staffFunction(plr, 'impossible_join')
				end
				return true
			end
			return false
		end

		local spectatorConnection
		spectatorConnection = plr:GetAttributeChangedSignal('Spectator'):Connect(function()
			if checkJoin() then spectatorConnection:Disconnect() processing[plr.UserId] = nil end
		end)
		StaffDetector:Clean(spectatorConnection)

		if checkJoin() then processing[plr.UserId] = nil return end

		if Clans.Enabled then
			local function checkClanTag()
				local clanTag = plr:GetAttribute('ClanTag')
				if clanTag and table.find(blacklistedclans, clanTag) then
					staffFunction(plr, 'blacklisted_clan_' .. clanTag:lower())
				end
			end
			if plr:GetAttribute('ClanTag') then
				checkClanTag()
			else
				local clanConnection
				clanConnection = plr:GetAttributeChangedSignal('ClanTag'):Connect(function()
					clanConnection:Disconnect()
					checkClanTag()
				end)
				StaffDetector:Clean(clanConnection)
				task.delay(5, function() if clanConnection then clanConnection:Disconnect() end end)
			end
		end

		processing[plr.UserId] = nil
	end

	local function playerRemoving(plr)
		local userId = plr.UserId
		joined[userId] = nil
		processing[userId] = nil
		if detectedPlayers[userId] then
			local data = detectedPlayers[userId]
			notif('StaffDetector', data.name .. ' (' .. data.checktype .. ') has left the server', AlertDuration.Value, 'warning')
			if whitelist.customtags[data.name] then whitelist.customtags[data.name] = nil end
			detectedPlayers[userId] = nil
			refreshStaffCounts()
		end
	end

	StaffDetector = vape.Categories.Utility:CreateModule({
		Name = 'StaffDetector',
		Function = function(callback)
			if callback then
				StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
				StaffDetector:Clean(playersService.PlayerRemoving:Connect(playerRemoving))
				for _, v in playersService:GetPlayers() do task.spawn(playerAdded, v) end
			else
				table.clear(joined) table.clear(processing) table.clear(detectedPlayers)
				refreshStaffCounts()
			end
		end,
		Tooltip = 'detects people with staff role and etc'
	})

	Mode = StaffDetector:CreateDropdown({Name='Mode',List={'Uninject','Profile','Requeue','AutoConfig','Notify'},Function=function(val) if Profile.Object then Profile.Object.Visible = val=='Profile' end end})
	AlertDuration = StaffDetector:CreateSlider({Name='Alert Duration',Min=5,Max=120,Default=60,Suffix='s',})
	Clans = StaffDetector:CreateToggle({Name='Blacklist clans',Default=true})
	ClosetDetect = StaffDetector:CreateToggle({Name='Closet Cheaters',Default=true,Tooltip='tells u if a known closet cheater is in ur game so u know who to watch out for gng'})
	Party = StaffDetector:CreateToggle({Name='Leave party'})
	Profile = StaffDetector:CreateTextBox({Name='Profile',Default='default',Darker=true,Visible=false})
	Users = StaffDetector:CreateTextList({Name='Users',Placeholder='player (userid)',Function=function() end})
	task.defer(function() if Profile and Profile.Object then Profile.Object.Visible = (Mode.Value=='Profile') end end)
end)
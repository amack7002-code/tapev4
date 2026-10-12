run(function()
	local BedAlarm
	local Types
	local Distance
	local UpdateTick
	local HighlightEnemies
	local SoundVolume
	local ShowAlarm

	local function getBed()
		if not (entitylib.isAlive and lplr.Character) then return nil end
		local id = lplr.Character:GetAttribute('Team') or lplr.Character:GetAttribute('TeamId')
		for _, v in collectionService:GetTagged('bed') do
			if tonumber(id) == tonumber(v:GetAttribute('TeamID') or v:GetAttribute('Team') or v:GetAttribute('TeamId')) then
				return v
			end
		end
		return nil
	end

	local function createAlarm(bedpos)
		if not ShowAlarm.Enabled then return end
		if not bedpos then return end
		if store.BedAlarm[lplr] then return end

		if bedwars.BedAlarmController then
			local suc, res = pcall(function()
				local oldthread = 0
				if vape.ThreadFix then 
					oldthread = getthreadidentity()
					setthreadidentity(8) 
				end

				local myTeam = lplr.Character:GetAttribute('Team') or lplr.Character:GetAttribute('TeamId') or -1
				bedwars.BedAlarmController:getOrCreateBedAlarmModel(myTeam, bedpos)

				if vape.ThreadFix then 
					setthreadidentity(oldthread) 
				end
			end)

			if suc then
				store.BedAlarm[lplr] = true
			else
				vape:CreateNotification("BedAlarm", `Creating Alarm issue: {res}`, 16, 'alert')
			end
		end
	end

	local function AlarmAffects(bedpos)
		if not ShowAlarm.Enabled or not bedpos then return end
		if not store.BedAlarm[lplr] then return end

		local myTeam = lplr.Character:GetAttribute('Team') or lplr.Character:GetAttribute('TeamId') or -1
		pcall(function()
			bedwars.BedAlarmController:triggerBedAlarmModel({bedPosition = bedpos, teamId = myTeam})
		end)
	end

	local function removeAlarm()
		if not store.BedAlarm[lplr] then return end
		
		local myTeam = lplr.Character:GetAttribute('Team') or lplr.Character:GetAttribute('TeamId') or -1
		local alarm = bedwars.BedAlarmController.bedAlarmModelMap[myTeam]
		if alarm then
			alarm:Destroy()
			bedwars.BedAlarmController.bedAlarmModelMap[myTeam] = nil
		end
		store.BedAlarm[lplr] = nil
	end

	local function createHighlight(ent)
		if store.BedAlarmHighlightedEnimes[ent] then return end
		
		local character = ent.character or ent.Character
		if not character then return end

		local highlight = Instance.new("Highlight")
		highlight.Name = "BedAlarmHighlight"
		highlight.Adornee = character
		highlight.FillColor = Color3.fromRGB(255, 80, 80)
		highlight.OutlineColor = Color3.fromRGB(255, 100, 100)
		highlight.FillTransparency = 0.6
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = character
		
		store.BedAlarmHighlightedEnimes[ent] = highlight
	end

	local function clearAllHighlights()
		for _, highlight in pairs(store.BedAlarmHighlightedEnimes) do
			if highlight and highlight.Parent then highlight:Destroy() end
		end
		table.clear(store.BedAlarmHighlightedEnimes)
	end

	local function removeHighlight(ent)
		local hl = store.BedAlarmHighlightedEnimes[ent]
		if hl then
			hl:Destroy()
			store.BedAlarmHighlightedEnimes[ent] = nil
		end
	end

	BedAlarm = vape.Categories.Utility:CreateModule({
		Name = "BedAlarm",
		Function = function(callback)
			if callback then
				store.BedAlarmNotifyTick = 0
				store.BedAlarmSoundTick = 0
				store.BedAlarmIsTrigged = false

				local bed = getBed()
				local bedpos = bed and bed:GetPivot().Position or Vector3.zero

				if ShowAlarm.Enabled then
					createAlarm(bedpos)
				end

				local _bedAlarmSearch = {Origin = bedpos, Range = Distance.Value, Part = 'RootPart', Players = true, IgnoreLocal = true}
				repeat
					if bedpos then
						_bedAlarmSearch.Origin = bedpos
						_bedAlarmSearch.Range = Distance.Value
						local entity = entitylib.EntityPosition(_bedAlarmSearch)

						if entity then
							store.BedAlarmIsTrigged = true

							if ShowAlarm.Enabled then
								createAlarm(bedpos)
							end

							if os.time() >= store.BedAlarmNotifyTick then
								store.BedAlarmNotifyTick = os.time() + UpdateTick.Value

								AlarmAffects(bedpos)

								local msg = '[Bed Alarm]: An intruder is near your bed!'
								if Types.Value == 'Vape' then
									vape:CreateNotification("BedAlarm", msg, UpdateTick.Value + 1)
								else
									pcall(function()
										bedwars.NotificationController:sendInfoNotification({ message = msg })
									end)
								end
							end

							if os.time() >= store.BedAlarmSoundTick then
								store.BedAlarmSoundTick = os.time() + 1.2

								local distance = (bedpos - entity.RootPart.Position).Magnitude
								local soundId = distance >= 30 and bedwars.SoundList.BED_ALARM_TRIGGERED_FAR or bedwars.SoundList.BED_ALARM

								pcall(function()
									bedwars.SoundManager:playSound(soundId, {
										volumeMultiplier = SoundVolume.Value
									})
								end)
							end

							if HighlightEnemies.Enabled then
								createHighlight(entity)
							end
						else
							store.BedAlarmIsTrigged = false
						end
					end

					for ent, _ in pairs(store.BedAlarmHighlightedEnimes) do
						if not entity or ent ~= entity then
							removeHighlight(ent)
						end
					end

					task.wait(1/60)
				until not BedAlarm.Enabled

			else
				store.BedAlarmIsTrigged = false
				clearAllHighlights()
				removeAlarm()
			end
		end
	})

	Distance = BedAlarm:CreateSlider({Name = 'Distance', Min = 10, Max = 100, Default = 64, Suffix = " studs"})
	
	Types = BedAlarm:CreateDropdown({
		Name = 'Notification Type',
		List = {'Vape','Bedwars'},
		Default = 'Bedwars'
	})
	
	UpdateTick = BedAlarm:CreateSlider({
		Name = "Update Tick",
		Min = 0.5,
		Max = 8,
		Decimal = 5,
		Default = 3,
		Suffix = 's'
	})
	
	SoundVolume = BedAlarm:CreateSlider({
		Name = "Volume Multiplier",
		Min = 0.1,
		Max = 3,
		Default = 1.5,
		Decimal = 5,
	})
	
	HighlightEnemies = BedAlarm:CreateToggle({
		Name = 'Highlight Enemies',
		Default = true,
		Function = function(v)
			if not v then clearAllHighlights() end
		end
	})
	
	ShowAlarm = BedAlarm:CreateToggle({
		Name = "Show Alarm Model",
		Default = false,
		Function = function(v)
			local bed = getBed()
			local pos = bed and bed:GetPivot().Position or Vector3.zero
			if v then
				createAlarm(pos)
			else
				removeAlarm()
			end
		end
	})
end)
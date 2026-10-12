run(function()
	local ChestSteal
	local Range
	local Open
	local Skywars
	local DelayToggle
	local DelaySlider
	local TeamFilter
	local Delays = {}
	
	local function isTeamChest(chest)
		if not TeamFilter.Enabled then return false end
		local myTeam = tostring(lplr:GetAttribute('Team') or '')
		local myBed = nil
		for _, bed in collectionService:GetTagged('bed') do
			if not bed:IsA('BasePart') then continue end
			local bedTeam = tostring(bed:GetAttribute('Team') or bed:GetAttribute('TeamId') or '')
			if bedTeam == myTeam then myBed = bed break end
		end
		if not myBed then return false end
		local dist = (chest.Position - myBed.Position).Magnitude
		return dist <= 60
	end
	
	local function lootChest(chest)
		chest = chest and chest.Value or nil
		if not chest then return end
		
		local chestitems = chest and chest:GetChildren() or {}
		if #chestitems > 1 and (Delays[chest] or 0) < tick() then
			Delays[chest] = tick() + (DelayToggle.Enabled and DelaySlider.Value or 0.2)
			bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(chest)
	
			for _, v in chestitems do
				if v:IsA('Accessory') then
					if DelayToggle.Enabled then
						task.wait(DelaySlider.Value / #chestitems) 
					end
					
					task.spawn(function()
						pcall(function()
							bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(chest, v)
						end)
					end)
				end
			end
	
			bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(nil)
		end
	end
	
	ChestSteal = vape.Categories.World:CreateModule({
		Name = 'ChestSteal',
		Function = function(callback)
			if callback then
				local chests = collection('chest', ChestSteal)
				repeat task.wait() until store.queueType ~= 'bedwars_test'
				if (not Skywars.Enabled) or store.queueType:find('skywars') then
					repeat
						if entitylib.isAlive and store.matchState ~= 2 then
							if Open.Enabled then
								if bedwars.AppController:isAppOpen('ChestApp') then
									lootChest(lplr.Character:FindFirstChild('ObservedChestFolder'))
								end
							else
								local localPosition = entitylib.character.RootPart.Position
								for _, v in chests do
									if (localPosition - v.Position).Magnitude <= Range.Value then
										if isTeamChest(v) then continue end
										lootChest(v:FindFirstChild('ChestFolderValue'))
									end
								end
							end
						end
						task.wait(0.1)
					until not ChestSteal.Enabled
				end
			end
		end,
		Tooltip = 'takes items from near chests'
	})
	Range = ChestSteal:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 18,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Open = ChestSteal:CreateToggle({Name = 'GUI Check'})
	Skywars = ChestSteal:CreateToggle({
		Name = 'Only Skywars',
		Function = function()
			if ChestSteal.Enabled then
				ChestSteal:Toggle()
				ChestSteal:Toggle()
			end
		end,
		Default = true
	})
	TeamFilter = ChestSteal:CreateToggle({
		Name = 'Team Check',
		Default = false
	})
	DelayToggle = ChestSteal:CreateToggle({
		Name = 'Delay',
		Function = function(callback)
			DelaySlider.Object.Visible = callback
			if ChestSteal.Enabled then
				ChestSteal:Toggle()
				ChestSteal:Toggle()
			end
		end
	})
    DelaySlider = ChestSteal:CreateSlider({
        Name = 'Delay Time',
        Min = 0.1,
        Max = 5,
        Default = 1,
        Decimal = 10,
        Suffix = 's',
        Visible = false
    })

    task.defer(function()
        if DelaySlider and DelaySlider.Object then
            DelaySlider.Object.Visible = false  
        end
    end)
end)
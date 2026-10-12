run(function()
	local AutoWarrior
	local Targets
	local Range
	local Delay
	local useAbilityRemote

	local function getAbilityRemote()
		if not useAbilityRemote then
			pcall(function()
				useAbilityRemote = replicatedStorage:WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events"):WaitForChild("useAbility")
			end)
		end
		return useAbilityRemote
	end

	local function startLoop()
		task.spawn(function()
			repeat task.wait() until Targets and Range and Delay
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				local plr = entitylib.EntityPosition({
					Range = Range.Value,
					Part = 'RootPart',
					Players = Targets.Players.Enabled,
					NPCs = Targets.NPCs.Enabled,
					Wallcheck = Targets.Walls.Enabled,
					Sort = sortmethods.Distance
				})
				local grit = lplr:GetAttribute('Grit') or 0
				if plr and grit >= 100 then
					local remote = getAbilityRemote()
					if remote then
						pcall(function() remote:FireServer('warrior_strike') end)
					end
				end
				task.wait(Delay.Value)
			until not AutoWarrior.Enabled
		end)
	end

	AutoWarrior = vape.Categories.Kits:CreateModule({
		Name = 'AutoWarrior',
		Function = function(callback)
			if callback then startLoop() end
		end,
		Tooltip = 'auto strikes enemies when ur grit is full'
	})

	Targets = AutoWarrior:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	Range = AutoWarrior:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 40,
		Default = 20
	})
	Delay = AutoWarrior:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Suffix = 's'
	})
end)
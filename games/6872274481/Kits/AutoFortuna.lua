run(function()
	local AutoFortuna
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
				if bedwars.AbilityController:canUseAbility('CARD_THROW') then
					local plr = entitylib.EntityPosition({
						Range = Range.Value,
						Part = 'RootPart',
						Players = true,
						NPCs = false,
						Wallcheck = false,
						Sort = sortmethods.Distance
					})
					if plr and plr.Character then
						local remote = getAbilityRemote()
						if remote then
							pcall(function()
								remote:FireServer("CARD_THROW", { targetEntityInstance = plr.Character })
							end)
							task.wait(Delay.Value)
						end
					end
				end
				task.wait(0.1)
			until not AutoFortuna.Enabled
		end)
	end

	AutoFortuna = vape.Categories.Kits:CreateModule({
		Name = 'AutoFortuna',
		Function = function(callback)
			if callback then startLoop() end
		end,
		Tooltip = 'auto throws cards at enemies for u'
	})

	Targets = AutoFortuna:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	Range = AutoFortuna:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 12,
		Default = 12
	})
	Delay = AutoFortuna:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.5,
		Decimal = 10,
		Suffix = 's'
	})
end)
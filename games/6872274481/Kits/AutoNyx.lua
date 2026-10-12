run(function()
	local AutoNyx
	local Targets
	local Range
	local Delay

	local function startLoop()
		task.spawn(function()
			repeat task.wait() until Targets and Range and Delay
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				if bedwars.AbilityController:canUseAbility('midnight') then
					local plr = entitylib.EntityPosition({
						Range = Range.Value,
						Part = 'RootPart',
						Players = true,
						NPCs = false,
						Wallcheck = false,
						Sort = sortmethods.Distance
					})
					if plr then
						pcall(function() bedwars.AbilityController:useAbility('midnight') end)
						task.wait(Delay.Value)
					end
				end
				task.wait(0.1)
			until not AutoNyx.Enabled
		end)
	end

	AutoNyx = vape.Categories.Kits:CreateModule({
		Name = 'AutoNyx',
		Function = function(callback)
			if callback then startLoop() end
		end,
		Tooltip = 'auto pops nyx ability when a enemy is close'
	})

	Targets = AutoNyx:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	Range = AutoNyx:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 40,
		Default = 20
	})
	Delay = AutoNyx:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.5,
		Decimal = 10,
		Suffix = 's'
	})
end)
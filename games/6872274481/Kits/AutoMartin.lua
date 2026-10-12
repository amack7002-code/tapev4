run(function()
	local AutoMartin
	local Range

	local function startLoop()
		task.spawn(function()
			repeat task.wait() until Range
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				if bedwars.AbilityController:canUseAbility('cactus_fire') then
					local plr = entitylib.EntityPosition({
						Range = Range.Value,
						Part = 'RootPart',
						Players = true,
						NPCs = false,
						Wallcheck = false,
						Sort = sortmethods.Distance
					})
					if plr then
						pcall(function() bedwars.AbilityController:useAbility('cactus_fire') end)
						task.wait(0.5)
					end
				end
				task.wait(0.1)
			until not AutoMartin.Enabled
		end)
	end

	AutoMartin = vape.Categories.Kits:CreateModule({
		Name = 'AutoMartin',
		Function = function(callback)
			if callback then startLoop() end
		end,
		Tooltip = 'auto shoots cactus fire at enemies close to u'
	})
	Range = AutoMartin:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 40,
		Default = 18
	})
end)
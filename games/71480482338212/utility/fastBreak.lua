run(function()
	local FastBreak
	local Cooldown
	local old = {}

	local function apply(enabled)
		for name, data in bedfight.MiningData do
			if type(data) == 'table' and data.Cooldown and not table.isfrozen(data) then
				old[name] = old[name] or data.Cooldown
				data.Cooldown = enabled and Cooldown.Value or old[name]
			end
		end
	end

	FastBreak = vape.Categories.Utility:CreateModule({
		Name = 'FastBreak',
		Function = function(callback)
			apply(callback)
		end,
		Tooltip = 'Shortens the wait between your pickaxe and axe hits'
	})
	Cooldown = FastBreak:CreateSlider({
		Name = 'Cooldown',
		Min = 0,
		Max = 0.3,
		Default = 0.1,
		Decimal = 100,
		Suffix = 's',
		Function = function()
			if FastBreak.Enabled then
				apply(true)
			end
		end,
		Tooltip = 'The game\'s own is 0.3'
	})
end)

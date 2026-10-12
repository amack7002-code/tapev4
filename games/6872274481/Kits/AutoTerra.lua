run(function()
	local AutoTerra
	local BlockCount

	local function startLoop()
		task.spawn(function()
			repeat task.wait() until BlockCount
			repeat
				if entitylib.isAlive and bedwars.AbilityController then
					local character = lplr.Character
					local blocks = 0
					if character then
						blocks = character:GetAttribute('BlockKickerKit_BlockCount') or lplr:GetAttribute('BlockKickerKit_BlockCount') or 0
					else
						blocks = lplr:GetAttribute('BlockKickerKit_BlockCount') or 0
					end
					if blocks <= BlockCount.Value and bedwars.AbilityController:canUseAbility('BLOCK_STOMP') then
						pcall(function() bedwars.AbilityController:useAbility('BLOCK_STOMP') end)
						task.wait(0.8)
					end
				end
				task.wait(0.1)
			until not AutoTerra.Enabled
		end)
	end

	AutoTerra = vape.Categories.Kits:CreateModule({
		Name = 'AutoTerra',
		Function = function(callback)
			if callback then startLoop() end
		end,
		Tooltip = 'auto stomps to refill ur blocks'
	})

	BlockCount = AutoTerra:CreateSlider({
		Name = 'Block Count',
		Tooltip = 'stomps when ur blocks drop to this',
		Min = 0,
		Max = 10,
		Default = 0
	})
end)
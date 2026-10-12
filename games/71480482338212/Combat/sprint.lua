run(function()
	local Sprint

	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				-- the same switch the game's sprint key and mobile button use
				local sprint = bedfight.ButtonProperties.new('Sprint')
				repeat
					if entitylib.isAlive and entitylib.character.Humanoid.MoveDirection.Magnitude > 0 then
						if not sprint.Active.Value and sprint.Priority == 0 then
							sprint:Set(true, nil, true)
						end
					end
					task.wait(0.1)
				until not Sprint.Enabled
			end
		end,
		Tooltip = 'Keeps you sprinting whenever you move'
	})
end)

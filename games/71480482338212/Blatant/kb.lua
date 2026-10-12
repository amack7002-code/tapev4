run(function()
	local Knockback
	local Power
	local Duration
	local Direction

	Knockback = vape.Categories.Blatant:CreateModule({
		Name = 'Knockback',
		Function = function(callback)
			if not callback then return end
			if entitylib.isAlive then
				local root = entitylib.character.RootPart
				local look = gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
				look = look.Magnitude > 0.01 and look.Unit or root.CFrame.LookVector
				local dir = Direction.Value == 'Forward' and (look + Vector3.new(0, 0.3, 0)).Unit
					or Direction.Value == 'Up' and Vector3.yAxis
					or (-look + Vector3.new(0, 0.35, 0)).Unit
				-- the push the game gives you when you are hit, aimed by you
				bedfight.VelocityUtils.Create(root, dir * Power.Value, Duration.Value)
				task.wait(Duration.Value)
				if root.Parent then
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
			if Knockback.Enabled then
				Knockback:Toggle()
			end
		end,
		Tooltip = 'Launches you once with the game\'s own knockback, then switches off.\nBind it to a key.'
	})
	Direction = Knockback:CreateDropdown({
		Name = 'Direction',
		List = {'Backward', 'Forward', 'Up'}
	})
	Power = Knockback:CreateSlider({
		Name = 'Power',
		Min = 10,
		Max = 300,
		Default = 80
	})
	Duration = Knockback:CreateSlider({
		Name = 'Duration',
		Min = 0.05,
		Max = 1,
		Default = 0.15,
		Decimal = 100,
		Suffix = 's'
	})
end)

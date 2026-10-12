local Fly
local LongJump
run(function()
	local Keys
	local Value
	local VerticalValue
	local up = 0

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			if callback then
				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						local movedir = calculateMoveVector() * Value.Value
						local keys = Keys.Value:split('/')
						local focused = inputService:GetFocusedTextBox() ~= nil
						local keyboardUp = not focused and inputService:IsKeyDown(Enum.KeyCode[keys[1]]) and 1 or 0
						local keyboardDown = not focused and inputService:IsKeyDown(Enum.KeyCode[keys[2]]) and -1 or 0

						debug.setupvalue(arena.TickFunction, 6, Vector3.new(movedir.X, 1 + ((math.max(up, keyboardUp) + keyboardDown) * VerticalValue.Value), movedir.Z))
					end
				end))

				up = 0
				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
							up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
						end))
					end)
				end
			end
		end,
		Tooltip = 'Makes you go zoom.'
	})
	Keys = Fly:CreateDropdown({
		Name = 'Keys',
		List = {'Space/LeftControl', 'Space/LeftShift', 'E/Q', 'Space/Q'},
		Default = 'Space/LeftControl',
		Tooltip = 'Keys for flying upwards and downwards'
	})
	Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	VerticalValue = Fly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
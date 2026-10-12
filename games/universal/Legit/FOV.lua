run(function()
	local FOV
	local Value
	local oldfov
	local connection

	FOV = vape.Legit:CreateModule({
		Name = 'FOV',
		Function = function(callback)
			if callback then
				oldfov = gameCamera.FieldOfView

				gameCamera.FieldOfView = Value.Value

				connection = gameCamera:GetPropertyChangedSignal('FieldOfView'):Connect(function()
					if FOV.Enabled and gameCamera.FieldOfView ~= Value.Value then
						gameCamera.FieldOfView = Value.Value
					end
				end)
			else
				if connection then
					connection:Disconnect()
					connection = nil
				end

				if oldfov then
					gameCamera.FieldOfView = oldfov
				end
			end
		end,

		Tooltip = 'Adjusts camera vision'
	})

	Value = FOV:CreateSlider({
		Name = 'FOV',
		Min = 30,
		Max = 120
	})
end)
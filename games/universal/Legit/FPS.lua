run(function()
	local FPS
	local label
	
	FPS = vape.Categories.Legit:CreateModule({
		Name = 'FPS',
		Function = function(callback)
			if callback then
				local frames, elapsed = 0, 0
				FPS:Clean(runService.RenderStepped:Connect(function(dt)
					if not FPS.Enabled then return end
					frames += 1
					elapsed += dt
					if label and elapsed >= 1 then
						label.Text = math.round(frames / elapsed)..' FPS'
						frames, elapsed = 0, 0
					end
				end))
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'Shows the current framerate'
	})
	FPS:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			if label then label.FontFace = val end
		end
	})
	FPS:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			if label then
				label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				label.BackgroundTransparency = 1 - opacity
			end
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = 'inf FPS'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = FPS.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
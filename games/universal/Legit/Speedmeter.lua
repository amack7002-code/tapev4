run(function()
	local Speedmeter
	local label
	
	Speedmeter = vape.Categories.Legit:CreateModule({
		Name = 'Speedmeter',
		Function = function(callback)
			if callback then
				local lastRoot, lastPosition, elapsed
				elapsed = 0
				Speedmeter:Clean(runService.Heartbeat:Connect(function(dt)
					if not Speedmeter.Enabled or not label then return end
					local character = entitylib.isAlive and entitylib.character
					local root = character and character.RootPart
					if not root or not root.Parent then
						lastRoot, lastPosition, elapsed = nil, nil, 0
						label.Text = '0 sps'
						return
					end
					local position = root.Position * Vector3.new(1, 0, 1)
					if root ~= lastRoot then
						lastRoot, lastPosition, elapsed = root, position, 0
						label.Text = '0 sps'
						return
					end
					elapsed += dt
					if elapsed < 0.2 then return end
					label.Text = math.round((position - lastPosition).Magnitude / elapsed)..' sps'
					lastPosition, elapsed = position, 0
				end))
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'A label showing the average velocity in studs'
	})
	Speedmeter:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			if label then label.FontFace = val end
		end
	})
	Speedmeter:CreateColorSlider({
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
	label.Text = '0 sps'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Speedmeter.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
run(function()
	local Memory
	local label
	
	Memory = vape.Categories.Legit:CreateModule({
		Name = 'Memory',
		Function = function(callback)
			if callback then
				local elapsed = 1
				Memory:Clean(runService.Heartbeat:Connect(function(dt)
					elapsed += dt
					if not Memory.Enabled or not label or elapsed < 1 then return end
					elapsed = 0
					local ok, value = pcall(function()
						return game:GetService('Stats'):GetTotalMemoryUsageMb()
					end)
					label.Text = ok and type(value) == 'number' and value == value
						and value >= 0 and value < math.huge and (math.round(value)..' MB') or '-- MB'
				end))
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'A label showing the memory currently used by roblox'
	})
	Memory:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			if label then label.FontFace = val end
		end
	})
	Memory:CreateColorSlider({
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
	label.Size = UDim2.new(0, 100, 0, 41)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = '0 MB'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Memory.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
run(function()
	local Clock
	local TwentyFourHour
	local label
	
	Clock = vape.Categories.Legit:CreateModule({
		Name = 'Clock',
		Function = function(callback)
			if callback then
				local elapsed = 1
				Clock:Clean(runService.Heartbeat:Connect(function(dt)
					elapsed += dt
					if not Clock.Enabled or not label or not TwentyFourHour or elapsed < 1 then return end
					elapsed = 0
					local ok, text = pcall(function()
						return DateTime.now():FormatLocalTime('LT', TwentyFourHour.Enabled and 'zh-cn' or 'en-us')
					end)
					label.Text = ok and text or '--:--'
				end))
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'Shows the current local time'
	})
	Clock:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			if label then label.FontFace = val end
		end
	})
	Clock:CreateColorSlider({
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
	TwentyFourHour = Clock:CreateToggle({
		Name = '24 Hour Clock'
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.new(0, 100, 0, 41)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = '0:00 PM'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Clock.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
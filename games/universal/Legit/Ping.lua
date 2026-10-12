run(function()
	local Ping
	local label
	
	Ping = vape.Categories.Legit:CreateModule({
		Name = 'Ping',
		Function = function(callback)
			if callback then
				local elapsed = 1
				Ping:Clean(runService.Heartbeat:Connect(function(dt)
					elapsed += dt
					if not Ping.Enabled or not label or elapsed < 1 then return end
					elapsed = 0
					local ok, value = pcall(function() return lplr:GetNetworkPing() end)
					label.Text = ok and type(value) == 'number' and value == value
						and value >= 0 and value < math.huge and (math.round(value * 1000)..' ms') or '-- ms'
				end))
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'Shows the current connection speed to the roblox server'
	})
	Ping:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			if label then label.FontFace = val end
		end
	})
	Ping:CreateColorSlider({
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
	label.Text = '0 ms'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Ping.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
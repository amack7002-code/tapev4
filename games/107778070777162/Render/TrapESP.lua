run(function()
	local TrapESP
	local conn = nil
	local tracked = {}

	local function addTrap(trap)
		if tracked[trap] or trap.Name ~= 'PlayerTrap' then
			return
		end
		local billboard = Instance.new('BillboardGui')
		billboard.Name = 'TrapESPTag'
		billboard.Size = UDim2.new(0, 200, 0, 60)
		billboard.StudsOffset = Vector3.new(0, 2, 0)
		billboard.AlwaysOnTop = true
		billboard.Adornee = trap
		local label = Instance.new('TextLabel')
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextStrokeTransparency = 0
		label.Text = 'trap'
		label.TextColor3 = trap:GetAttribute('Owner') == lplr.Name and Color3.fromRGB(80, 160, 255) or Color3.fromRGB(255, 60, 60)
		label.Parent = billboard
		billboard.Parent = trap
		tracked[trap] = billboard
	end

	local function removeTrap(trap)
		local billboard = tracked[trap]
		if billboard then
			billboard:Destroy()
			tracked[trap] = nil
		end
	end

	TrapESP = vape.Categories.Render:CreateModule({
		Name = 'TrapESP',
		Function = function(callback)
			if callback then
				local debris = workspace:FindFirstChild('__DEBRIS')
				if debris then
					for _, v in debris:GetChildren() do
						addTrap(v)
					end
					conn = debris.ChildAdded:Connect(addTrap)
				end
			else
				for trap in tracked do
					removeTrap(trap)
				end
				if conn then
					conn:Disconnect()
					conn = nil
				end
			end
		end,
		Tooltip = 'shows every trap on the map, blue is urs red is everyone elses gng'
	})
end)
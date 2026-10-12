run(function()
	local BedESP
	local EnemyOnly
	local Fill
	local ShowName
	local ShowDistance
	local Reference = {}
	local folder = Instance.new('Folder')
	folder.Parent = vape.gui
	vape:Clean(folder)

	local function teamColor(name)
		local team = game:GetService('Teams'):FindFirstChild(tostring(name))
		return team and team.TeamColor.Color or Color3.fromRGB(220, 60, 60)
	end

	-- nothing may ever be parented into a bed, the game treats that as bed ESP
	local function added(bed)
		if Reference[bed] then return end
		local hitbox = bed:IsA('Model') and bed:WaitForChild('BedHitbox', 5)
		if not hitbox or Reference[bed] or not BedESP.Enabled then return end
		local color = teamColor(bed:GetAttribute('Team'))
		local box = Instance.new('BoxHandleAdornment')
		box.Adornee = hitbox
		box.Size = hitbox.Size + Vector3.new(0.2, 0.2, 0.2)
		box.AlwaysOnTop = true
		box.ZIndex = 0
		box.Color3 = color
		box.Transparency = 1 - Fill.Value
		box.Parent = folder
		local billboard = Instance.new('BillboardGui')
		billboard.Adornee = hitbox
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.fromOffset(160, 18)
		billboard.StudsOffset = Vector3.new(0, 4, 0)
		billboard.Parent = folder
		local label = Instance.new('TextLabel')
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 13
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.4
		label.Parent = billboard
		Reference[bed] = {Box = box, Billboard = billboard, Label = label, Hitbox = hitbox}
	end

	local function removed(bed)
		local ref = Reference[bed]
		if ref then
			Reference[bed] = nil
			ref.Box:Destroy()
			ref.Billboard:Destroy()
		end
	end

	BedESP = vape.Categories.Render:CreateModule({
		Name = 'BedESP',
		Function = function(callback)
			if callback then
				local function watch(container)
					BedESP:Clean(container.ChildAdded:Connect(function(bed)
						task.spawn(added, bed)
					end))
					BedESP:Clean(container.ChildRemoved:Connect(removed))
					for _, bed in container:GetChildren() do
						task.spawn(added, bed)
					end
				end
				BedESP:Clean(workspace.ChildAdded:Connect(function(v)
					if v.Name == 'BedsContainer' then
						watch(v)
					end
				end))
				if workspace:FindFirstChild('BedsContainer') then
					watch(workspace.BedsContainer)
				end

				repeat
					local mine = lplr.Team and lplr.Team.Name
					for bed, ref in Reference do
						local team = bed:GetAttribute('Team')
						local shown = not (EnemyOnly.Enabled and team == mine)
						ref.Box.Visible = shown
						ref.Box.Transparency = 1 - Fill.Value
						ref.Billboard.Enabled = shown and (ShowName.Enabled or ShowDistance.Enabled)
						if ref.Billboard.Enabled then
							local text = ShowName.Enabled and tostring(team)..' Bed' or ''
							if ShowDistance.Enabled and entitylib.isAlive then
								text ..= string.format(' [%d]', (ref.Hitbox.Position - entitylib.character.RootPart.Position).Magnitude)
							end
							ref.Label.Text = text
						end
					end
					task.wait(0.2)
				until not BedESP.Enabled
			else
				for bed in table.clone(Reference) do
					removed(bed)
				end
			end
		end,
		Tooltip = 'Shows beds through walls'
	})
	EnemyOnly = BedESP:CreateToggle({
		Name = 'Enemy only',
		Default = true
	})
	Fill = BedESP:CreateSlider({
		Name = 'Opacity',
		Min = 0.1,
		Max = 1,
		Default = 0.5,
		Decimal = 10
	})
	ShowName = BedESP:CreateToggle({
		Name = 'Team name',
		Default = true
	})
	ShowDistance = BedESP:CreateToggle({
		Name = 'Distance',
		Default = true
	})
end)

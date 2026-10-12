run(function()
	local AntiFall
	local Method
	local Mode
	local Material
	local Color
	local part
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

	local function getRoot()
		local character = entitylib.character
		if entitylib.isAlive and character and character.Character == lplr.Character
			and character.RootPart and character.RootPart.Parent then
			return character.RootPart, character.Humanoid
		end
	end
	
	AntiFall = vape.Categories.Blatant:CreateModule({
		Name = 'AntiFall',
		Function = function(callback)
			if callback then
				if Method.Value == 'Part' then
					local debounce = tick()
					local lastUpdate = 0
					part = Instance.new('Part')
					part.Size = Vector3.new(10000, 1, 10000)
					part.Transparency = 1 - Color.Opacity
					part.Material = Enum.Material[Material.Value]
					part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					part.Position = Vector3.new(0, workspace.FallenPartsDestroyHeight + 10, 0)
					part.CanCollide = Mode.Value == 'Collide'
					part.Anchored = true
					part.CanQuery = false
					part.Parent = workspace
					AntiFall:Clean(part)
					AntiFall:Clean(part.Touched:Connect(function(touchedpart)
						local root = getRoot()
						if root and touchedpart.Parent == lplr.Character and debounce < tick() then
							debounce = tick() + 0.1
							local velocity = root.AssemblyLinearVelocity
							if Mode.Value == 'Velocity' then
								root.AssemblyLinearVelocity = Vector3.new(velocity.X, 100, velocity.Z)
							elseif Mode.Value == 'Impulse' then
								root:ApplyImpulse(Vector3.new(0, 100 - velocity.Y, 0) * root.AssemblyMass)
							end
						end
					end))
					local function updatePart()
						local root = getRoot()
						if not root or not part then return end
						rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character, part}
						rayCheck.CollisionGroup = root.CollisionGroup
						local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
						local height = ray and math.max(ray.Position.Y - 15, workspace.FallenPartsDestroyHeight + 10) or part.Position.Y
						part.Position = Vector3.new(root.Position.X, height, root.Position.Z)
					end
					updatePart()
					AntiFall:Clean(runService.PreSimulation:Connect(function()
						if tick() - lastUpdate >= 0.1 then
							lastUpdate = tick()
							updatePart()
						end
					end))
				else
					local lastpos, lastCharacter
					AntiFall:Clean(runService.PreSimulation:Connect(function(dt)
						local root, humanoid = getRoot()
						if not root or not humanoid then return end
						if lastCharacter ~= lplr.Character then
							lastCharacter = lplr.Character
							lastpos = nil
						end
						local threshold = workspace.FallenPartsDestroyHeight + 10
						if humanoid.FloorMaterial ~= Enum.Material.Air and root.Position.Y > threshold then
							lastpos = root.Position
						end
						local velocity = root.AssemblyLinearVelocity
						if root.Position.Y + math.min(velocity.Y, 0) * math.clamp(dt or 0.016, 0, 0.1) <= threshold then
							local destination = lastpos or Vector3.new(root.Position.X, threshold + 10, root.Position.Z)
							root.CFrame += destination - root.Position
							root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
						end
					end))
				end
			else
				part = nil
			end
		end,
		Tooltip = 'Prevents falling into the void using a safety platform or a last-ground teleport.'
	})
	Method = AntiFall:CreateDropdown({
		Name = 'Method',
		List = {'Part', 'Teleport'},
		Default = 'Part',
		Function = function(val)
			for _, option in {Mode, Material, Color} do
				if option and option.Object then option.Object.Visible = val == 'Part' end
			end
			if AntiFall.Enabled then
				AntiFall:Toggle()
				AntiFall:Toggle()
			end
		end
	})
	Mode = AntiFall:CreateDropdown({
		Name = 'Move Mode',
		List = {'Velocity', 'Impulse', 'Collide'},
		Default = 'Velocity',
		Function = function(val)
			if part then
				part.CanCollide = val == 'Collide'
			end
		end,
		Tooltip = 'Velocity / Impulse - Launch upward on contact\nCollide - Walk on the safety platform'
	})
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = AntiFall:CreateDropdown({
		Name = 'Material',
		List = materials,
		Function = function(val)
			if part then 
				part.Material = Enum.Material[val] 
			end
		end
	})
	Color = AntiFall:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.5,
		Function = function(h, s, v, o)
			if part then
				part.Color = Color3.fromHSV(h, s, v)
				part.Transparency = 1 - o
			end
		end
	})
end)
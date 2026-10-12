run(function()
	local Speed
	local Mode
	local Value
	local AutoJump
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			if callback then
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					if not entitylib.isAlive or store.flyOn or store.dashOn then return end
					local hum, root = entitylib.character.Humanoid, entitylib.character.RootPart
					local dir = hum.MoveDirection
					if dir.Magnitude < 0.05 or hum:GetState() == Enum.HumanoidStateType.Climbing then return end

					if Mode.Value == 'CFrame' then
						-- the walk covers WalkSpeed, the rest is added on top
						local extra = dir * math.max(Value.Value - hum.WalkSpeed, 0) * dt
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
						if not workspace:Raycast(root.Position, extra + dir * 1.5, rayCheck) then
							root.CFrame += extra
						end
					else
						root.AssemblyLinearVelocity = Vector3.new(dir.X * Value.Value, root.AssemblyLinearVelocity.Y, dir.Z * Value.Value)
					end

					if AutoJump.Enabled and hum.FloorMaterial ~= Enum.Material.Air then
						hum:ChangeState(Enum.HumanoidStateType.Jumping)
					end
				end))
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Moves you faster. WalkSpeed is never changed, the game checks it.'
	})
	Mode = Speed:CreateDropdown({
		Name = 'Mode',
		List = {'Velocity', 'CFrame'},
		Tooltip = 'Velocity - sets your speed\nCFrame - moves the root on top of walking'
	})
	Value = Speed:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 30,
		Default = 24,
		Suffix = 'studs',
		Tooltip = '24 ran without the server stepping in. At 32 it pulled the character back after five seconds, and at 45 after less than two.'
	})
	AutoJump = Speed:CreateToggle({Name = 'AutoJump'})
end)

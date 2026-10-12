run(function()
	local Speed
	local Mode
	local Value
	local WallCheck
	local AutoJump
	local wallParams = RaycastParams.new()
	wallParams.FilterType = Enum.RaycastFilterType.Exclude
	wallParams.RespectCanCollide = true

	local function setWalk(speed)
		local ok = pcall(function()
			bedwars.SprintController:setSpeed(speed)
		end)
		if not ok and entitylib.isAlive then
			entitylib.character.Humanoid.WalkSpeed = speed
		end
	end

	local function resetWalk()
		local sprinting = false
		pcall(function()
			sprinting = bedwars.SprintController:isSprinting()
		end)
		setWalk(sprinting and 20 or 16)
	end

	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			if callback then
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					if not entitylib.isAlive then return end
					local hum = entitylib.character.Humanoid
					local root = entitylib.character.RootPart
					local state = hum:GetState()
					if state == Enum.HumanoidStateType.Climbing then return end
					local dir = hum.MoveDirection

					if Mode.Value == 'CFrame' then
						local vel = root.AssemblyLinearVelocity
						local flat = Vector3.new(vel.X, 0, vel.Z).Magnitude
						local step = dir * math.max(Value.Value - flat, 0) * dt
						if WallCheck.Enabled and step.Magnitude > 0 then
							wallParams.FilterDescendantsInstances = {lplr.Character, workspace.CurrentCamera}
							wallParams.CollisionGroup = root.CollisionGroup
							local hit = workspace:Raycast(root.Position, step, wallParams)
							if hit then
								step = (hit.Position + hit.Normal) - root.Position
							end
						end
						root.CFrame += step
					else
						setWalk(Value.Value)
					end

					if AutoJump.Enabled and dir ~= Vector3.zero and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) then
						hum:ChangeState(Enum.HumanoidStateType.Jumping)
					end
				end))
			else
				resetWalk()
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'makes u walk faster in the lobby'
	})
	Mode = Speed:CreateDropdown({
		Name = 'Method',
		List = {'Bedwars', 'CFrame'},
		Default = 'CFrame'
	})
	Value = Speed:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	WallCheck = Speed:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
	AutoJump = Speed:CreateToggle({
		Name = 'AutoJump',
		Tooltip = 'jumps for u while ur moving'
	})
end)
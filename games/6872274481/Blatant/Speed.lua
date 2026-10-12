run(function()
	local Speed
	local Mode
	local Value
	local WallCheck
	local AutoJump
	local AlwaysJump
	local savedImpulseTime
	local rayCheck = cloneRaycast()
	rayCheck.RespectCanCollide = true
	rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
	
	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			frictionTable.Speed = callback or nil
			updateVelocity()
			pcall(function()
				debug.setconstant(bedwars.WindWalkerController.updateSpeed, 7, callback and 'constantSpeedMultiplier' or 'moveSpeedMultiplier')
			end)
	
			if callback then
				if savedImpulseTime == nil then
					savedImpulseTime = bedwars.StatefulEntityKnockbackController.lastImpulseTime
				end
				Speed:Clean(function()
					pcall(function()
						bedwars.StatefulEntityKnockbackController.lastImpulseTime = (savedImpulseTime ~= nil and savedImpulseTime ~= math.huge) and savedImpulseTime or time()
					end)
					savedImpulseTime = nil
					pcall(function()
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
						end
					end)
					pcall(function()
						bedwars.SprintController:setSpeed(bedwars.SprintController:isSprinting() and 20 or 14)
					end)
				end)
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					if not Speed.Enabled then return end
					bedwars.StatefulEntityKnockbackController.lastImpulseTime = math.huge
					if entitylib.isAlive then
						if not (Fly and Fly.Enabled) and not (LongJump and LongJump.Enabled) then
							bedwars.SprintController:setSpeed(Mode.Value == 'CFrame' and 20 or Value.Value)
							if Mode.Value == 'CFrame' then
								local state = entitylib.character.Humanoid:GetState()
								if state == Enum.HumanoidStateType.Climbing then return end
			
								local root, velo = entitylib.character.RootPart, getSpeed()
								local moveDirection = AntiFallDirection or entitylib.character.Humanoid.MoveDirection
								local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
			
								if WallCheck.Enabled then
									rayCheck.CollisionGroup = root.CollisionGroup
									local ray = workspace:Raycast(root.Position, destination, rayCheck)
									if ray then
										destination = ((ray.Position + ray.Normal) - root.Position)
									end
								end
			
								root.CFrame += destination
								root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
								if AutoJump.Enabled and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and moveDirection ~= Vector3.zero and (Attacking or AlwaysJump.Enabled) then
									entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
								end
							end
						end
					end
				end))
			else
				pcall(function()
					bedwars.StatefulEntityKnockbackController.lastImpulseTime = (savedImpulseTime ~= nil and savedImpulseTime ~= math.huge) and savedImpulseTime or time()
				end)
				savedImpulseTime = nil
				pcall(function()
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
					end
				end)
				pcall(function()
					bedwars.SprintController:setSpeed(bedwars.SprintController:isSprinting() and 20 or 14)
				end)
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'increases your movement with various methods.'
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
		Function = function(callback)
			AlwaysJump.Object.Visible = callback
		end
	})
	AlwaysJump = Speed:CreateToggle({
		Name = 'Always Jump',
		Visible = false,
		Darker = true
	})
end)
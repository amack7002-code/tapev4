run(function()
	local TargetStrafe
	local Targets
	local SearchRange
	local StrafeRange
	local YFactor
	local MovementType
	local JumpMode
	local JumpHeight
	local AirStrafing
	local StrafeSpeed
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local module, old
	
	local movementTypes = {
		"Original",
		"Aggressive",
		"Defensive",
		"ZigZag",
		"SpinThisBitchHoe",
		"RandomShit"
	}
	
	local jumpModes = {
		"None",
		"Normal",
		"Spam",
		"Timed",
		"RandomSHi",
		"CantCatchMeBih"
	}
	
	local strafeState = {
		lastJumpTime = 0,
		jumpCooldown = 0,
		movementAngle = 0,
		zigzagDirection = 1,
		lastZigzagTime = 0,
		randomSeed = math.random(1, 1000),
		orbitDirection = 1,
		inAir = false,
		lastGroundTime = 0
	}

	local function calculateMovement(ent, root, targetPos, flymodEnabled, wallcheck)
		local movementType = MovementType.Value
		local jumpMode = JumpMode.Value
		local localPosition = root.Position
		local entityPos = Vector3.new(targetPos.X, localPosition.Y, targetPos.Z)
		local vec = Vector3.zero
		local shouldJump = false
		local jumpPower = JumpHeight.Value / 100
		
		if movementType == "Original" then
			local yFactor = math.abs(localPosition.Y - targetPos.Y) * (YFactor.Value / 100)
			local newPos = entityPos + (CFrame.Angles(0, math.rad(strafeState.movementAngle), 0).LookVector * (StrafeRange.Value - yFactor))
			vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
			strafeState.movementAngle = (strafeState.movementAngle + (StrafeSpeed.Value * 0.5)) % 360
			
		elseif movementType == "Aggressive" then
			local closeRange = StrafeRange.Value * 0.7
			local angleIncrement = StrafeSpeed.Value * 0.8
			local newPos = entityPos + (CFrame.Angles(0, math.rad(strafeState.movementAngle), 0).LookVector * closeRange)
			vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
			strafeState.movementAngle = (strafeState.movementAngle + angleIncrement) % 360
			
		elseif movementType == "Defensive" then
			local wideRange = StrafeRange.Value * 1.3
			local angleIncrement = StrafeSpeed.Value * 0.3
			local newPos = entityPos + (CFrame.Angles(0, math.rad(strafeState.movementAngle), 0).LookVector * wideRange)
			vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
			strafeState.movementAngle = (strafeState.movementAngle + angleIncrement) % 360
			
		elseif movementType == "ZigZag" then
			if tick() - strafeState.lastZigzagTime > 0.3 then
				strafeState.zigzagDirection = -strafeState.zigzagDirection
				strafeState.lastZigzagTime = tick()
			end
			
			local sideOffset = strafeState.zigzagDirection * (StrafeRange.Value * 0.5)
			local rightVector = CFrame.lookAt(localPosition, entityPos).RightVector
			local newPos = entityPos + (rightVector * sideOffset)
			vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
			
		elseif movementType == "Orbital" then
			local orbitSpeed = StrafeSpeed.Value * 0.4
			strafeState.orbitDirection = (localPosition - entityPos).Magnitude > StrafeRange.Value * 1.2 and 1 or strafeState.orbitDirection
			strafeState.orbitDirection = (localPosition - entityPos).Magnitude < StrafeRange.Value * 0.8 and -1 or strafeState.orbitDirection
			
			local newPos = entityPos + (CFrame.Angles(0, math.rad(strafeState.movementAngle), 0).LookVector * StrafeRange.Value)
			vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
			strafeState.movementAngle = (strafeState.movementAngle + (orbitSpeed * strafeState.orbitDirection)) % 360
			
		elseif movementType == "Random" then
			math.randomseed(strafeState.randomSeed + math.floor(tick()))
			local randomAngle = math.random(0, 360)
			local randomRange = math.random(StrafeRange.Value * 0.7, StrafeRange.Value * 1.3)
			local newPos = entityPos + (CFrame.Angles(0, math.rad(randomAngle), 0).LookVector * randomRange)
			vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
			
			if math.random(1, 20) == 1 then
				strafeState.randomSeed = math.random(1, 1000)
			end
		end
		
		local currentTime = tick()
		local distanceToTarget = (localPosition - targetPos).Magnitude
		
		if jumpMode == "Normal" then
			if not strafeState.inAir and currentTime - strafeState.lastJumpTime > 1.5 then
				shouldJump = math.random(1, 4) == 1
			end
			
		elseif jumpMode == "Spam" then
			if currentTime - strafeState.lastJumpTime > 0.4 then
				shouldJump = true
			end
			
		elseif jumpMode == "Timed" then
			if currentTime - strafeState.lastJumpTime > 1.0 then
				shouldJump = true
			end
			
		elseif jumpMode == "Combat" then
			if distanceToTarget < StrafeRange.Value * 1.2 and currentTime - strafeState.lastJumpTime > 0.8 then
				shouldJump = true
			end
			
		elseif jumpMode == "AntiAim" then
			if math.random(1, 15) == 1 and currentTime - strafeState.lastJumpTime > 0.5 then
				shouldJump = true
			end
		end
		
		if AirStrafing.Enabled and strafeState.inAir then
			vec = vec * 0.7
			
			if jumpMode ~= "None" then
				vec = vec + Vector3.new(0, 0.1 * jumpPower, 0)
			end
		end
		
		return vec, shouldJump
	end

	local function performJump(shouldJump, humanoid)
		if shouldJump and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			strafeState.lastJumpTime = tick()
			strafeState.inAir = true
			strafeState.lastGroundTime = tick()
		end
	end

	local function updateAirState(humanoid)
		if humanoid then
			strafeState.inAir = humanoid.FloorMaterial == Enum.Material.Air
			if not strafeState.inAir then
				strafeState.lastGroundTime = tick()
			end
		end
	end

	TargetStrafe = vape.Categories.Blatant:CreateModule({
		Name = 'TargetStrafe',
		Function = function(callback)
			if callback then
				if not module then
					local suc = pcall(function() module = require(lplr.PlayerScripts.PlayerModule).controls end)
					if not suc then
						module = {}
					end
				end
				
				old = module.moveFunction
				local flymod, ang, oldent = vape.Modules.Fly or {Enabled = false}
				
				module.moveFunction = function(self, vec, face)
					local wallcheck = Targets.Walls.Enabled
					local ent = not inputService:IsKeyDown(Enum.KeyCode.S) and entitylib.EntityPosition({
						Range = SearchRange.Value,
						Wallcheck = wallcheck,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled
					})
	
					if ent then
						local root, targetPos = entitylib.character.RootPart, ent.RootPart.Position
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, ent.Character}
						rayCheck.CollisionGroup = root.CollisionGroup
	
						if flymod.Enabled or workspace:Raycast(targetPos, Vector3.new(0, -70, 0), rayCheck) then
							local factor, localPosition = 0, root.Position
							if ent ~= oldent then
								ang = math.deg(select(2, CFrame.lookAt(targetPos, localPosition):ToEulerAnglesYXZ()))
								strafeState.movementAngle = ang
							end
							
							updateAirState(entitylib.character.Humanoid)
							
							local newVec, shouldJump = calculateMovement(ent, root, targetPos, flymod.Enabled, wallcheck)
							vec = newVec
							
							performJump(shouldJump, entitylib.character.Humanoid)
							
							local yFactor = math.abs(localPosition.Y - targetPos.Y) * (YFactor.Value / 100)
							local entityPos = Vector3.new(targetPos.X, localPosition.Y, targetPos.Z)
							local newPos = entityPos + (CFrame.Angles(0, math.rad(ang), 0).LookVector * (StrafeRange.Value - yFactor))
							local startRay, endRay = entityPos, newPos
	
							if not wallcheck and workspace:Raycast(targetPos, (localPosition - targetPos), rayCheck) then
								startRay, endRay = entityPos + (CFrame.Angles(0, math.rad(ang), 0).LookVector * (entityPos - localPosition).Magnitude), entityPos
							end
	
							local ray = workspace:Blockcast(CFrame.new(startRay), Vector3.new(1, entitylib.character.HipHeight + (root.Size.Y / 2), 1), (endRay - startRay), rayCheck)
							if (localPosition - newPos).Magnitude < 3 or ray then
								factor = (8 - math.min((localPosition - newPos).Magnitude, 3))
								if ray then
									newPos = ray.Position + (ray.Normal * 1.5)
									factor = (localPosition - newPos).Magnitude > 3 and 0 or factor
								end
							end
	
							if not flymod.Enabled and not workspace:Raycast(newPos, Vector3.new(0, -70, 0), rayCheck) then
								newPos = entityPos
								factor = 40
							end
	
							ang += factor % 360
							vec = vec == vec and vec or Vector3.zero
							TargetStrafeVector = vec
						else
							ent = nil
						end
					end
	
					TargetStrafeVector = ent and vec or nil
					oldent = ent
					return old(self, vec, face)
				end
			else
				if module and old then
					module.moveFunction = old
				end
				TargetStrafeVector = nil
				strafeState = {
					lastJumpTime = 0,
					jumpCooldown = 0,
					movementAngle = 0,
					zigzagDirection = 1,
					lastZigzagTime = 0,
					randomSeed = math.random(1, 1000),
					orbitDirection = 1,
					inAir = false,
					lastGroundTime = 0
				}
			end
		end,
		Tooltip = 'Automatically strafes around the opponent with multiple movement types'
	})
	
	Targets = TargetStrafe:CreateTargets({
		Players = true,
		Walls = true
	})
	
	SearchRange = TargetStrafe:CreateSlider({
		Name = 'Search Range',
		Min = 1,
		Max = 30,
		Default = 24,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	
	StrafeRange = TargetStrafe:CreateSlider({
		Name = 'Strafe Range',
		Min = 1,
		Max = 30,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	
	YFactor = TargetStrafe:CreateSlider({
		Name = 'Y Factor',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	
	StrafeSpeed = TargetStrafe:CreateSlider({
		Name = 'Strafe Speed',
		Min = 1,
		Max = 10,
		Default = 5,
		Function = function(val)
		end
	})
	
	MovementType = TargetStrafe:CreateDropdown({
		Name = 'Movement Type',
		List = movementTypes,
		Function = function(val)
			strafeState.movementAngle = 0
			strafeState.zigzagDirection = 1
			strafeState.lastZigzagTime = 0
		end
	})
	
	JumpMode = TargetStrafe:CreateDropdown({
		Name = 'Jump Mode',
		List = jumpModes,
		Function = function(val)
			strafeState.lastJumpTime = 0
		end
	})
	
	JumpHeight = TargetStrafe:CreateSlider({
		Name = 'Jump Power',
		Min = 50,
		Max = 150,
		Default = 100,
		Suffix = '%',
		Tooltip = 'Adjusts jump intensity for air strafing'
	})
	
	AirStrafing = TargetStrafe:CreateToggle({
		Name = 'Air Strafing',
		Function = function(callback)
		end,
		Default = true,
		Tooltip = 'Adjust movement when in air for better control'
	})
end)
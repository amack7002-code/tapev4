run(function()
	local AimAssist
	local Targets
	local Sort
	local AimSpeed
	local Smoothness
	local SmoothnessToggle
	local Distance
	local AngleSlider
	local KillauraTarget
	local ClickAim
	local ShopCheck
	local AimPart
	local ViewMode
	local PriorityMode
	local ShakeToggle
	local ShakeAmount
	local WorkWithProjectiles
	local projRayCheck = RaycastParams.new()
	projRayCheck.FilterType = Enum.RaycastFilterType.Include

	local function getHeldProjectileMeta()
		local tool = store.hand and store.hand.tool
		local itemMeta = tool and bedwars.ItemMeta[tool.Name]
		local source = itemMeta and itemMeta.projectileSource
		if not source or not source.projectileType then return nil end
		local ammo = tool.Name
		if source.ammoItemTypes and #source.ammoItemTypes > 0 then
			ammo = nil
			for _, item in store.inventory.inventory.items do
				if table.find(source.ammoItemTypes, item.itemType) then
					ammo = item.itemType
					break
				end
			end
		end
		if not ammo then return nil end
		local projType = source.projectileType
		local ok = true
		if type(projType) == 'function' then
			ok, projType = pcall(projType, ammo)
		end
		local projMeta = ok and projType and bedwars.ProjectileMeta[projType]
		if projMeta and type(projMeta.launchVelocity) == 'number' then
			return projMeta
		end
		return nil
	end
	local lockedTarget = nil
	local lastValidTarget = nil
	local lastValidTime = 0
	local GRACE_PERIOD = 0.15
	local rng = Random.new()
	local shakeTime = 0
	local shakeSeed = rng:NextNumber() * 1000

	local function getAimAlpha(speedVal, smoothVal, dt)
		local baseAlpha = math.clamp(speedVal * 0.025, 0.005, 0.98)
		if smoothVal then
			local smoothFactor = math.max(1 - ((smoothVal - 1) / 9) * 0.85, 0.05)
			baseAlpha = baseAlpha * smoothFactor
		end
		return 1 - (1 - baseAlpha) ^ (dt * 60)
	end

	local function getClosestPartToCursor(character)
		local mousePos = inputService.TouchEnabled and (gameCamera.ViewportSize / 2) or inputService:GetMouseLocation()
		local mouseRay = gameCamera:ViewportPointToRay(mousePos.X, mousePos.Y, 0)
		local bestAngle = math.huge
		local bestPart = nil
		local partNames = {
			'Head', 'UpperTorso', 'LowerTorso', 'HumanoidRootPart',
			'LeftUpperArm', 'RightUpperArm', 'LeftLowerArm', 'RightLowerArm',
			'LeftUpperLeg', 'RightUpperLeg', 'LeftLowerLeg', 'RightLowerLeg',
			'LeftFoot', 'RightFoot', 'LeftHand', 'RightHand'
		}
		for _, partName in partNames do
			local part = character:FindFirstChild(partName)
			if part then
				local dirToPart = (part.Position - mouseRay.Origin).Unit
				local angle = math.acos(math.clamp(mouseRay.Direction:Dot(dirToPart), -1, 1))
				if angle < bestAngle then
					bestAngle = angle
					bestPart = part
				end
			end
		end
		return bestPart
	end

	local function isEntValid(ent)
		if not ent or not ent.RootPart or not ent.Character or not ent.Character.Parent then return false end
		if not entitylib.isAlive or not entitylib.character or not entitylib.character.RootPart then return false end
		local hum = ent.Character:FindFirstChildOfClass('Humanoid')
		if not hum or hum.Health <= 0 then return false end
		local dist = (ent.RootPart.Position - entitylib.character.RootPart.Position).Magnitude
		if dist > Distance.Value then return false end
		if not isEnemy(ent) then return false end
		return true
	end

	local function isInAngle(ent)
		if not ent or not ent.RootPart then return false end
		if not entitylib.character or not entitylib.character.RootPart then return false end
		local delta = (ent.RootPart.Position - entitylib.character.RootPart.Position)
		local localFacing = ((getgenv().ViewMode and getgenv().ViewMode.Value == 'Third Person') and gameCamera.CFrame.LookVector or entitylib.character.RootPart.CFrame.LookVector) * Vector3.new(1, 0, 1)
		local flatDelta = delta * Vector3.new(1, 0, 1)
		if flatDelta.Magnitude <= 0.001 then return false end
		local angle = math.acos(math.clamp(localFacing:Dot(flatDelta.Unit), -1, 1))
		return angle < math.rad(AngleSlider.Value / 2)
	end

	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if callback then
				lockedTarget = nil
				lastValidTarget = nil
				lastValidTime = 0
				shakeTime = 0
				local aimBindName = 'vapeAimAssist'
				AimAssist:Clean(function()
					pcall(function() runService:UnbindFromRenderStep(aimBindName) end)
				end)
				runService:BindToRenderStep(aimBindName, Enum.RenderPriority.Camera.Value + 1, (function(dt)

					if not entitylib.isAlive or not entitylib.character or not entitylib.character.RootPart then
						lockedTarget = nil
						return
					end

					local projMeta
					local validWeapon = store.hand.toolType == 'sword'
					if WorkWithProjectiles and WorkWithProjectiles.Enabled and not validWeapon then
						projMeta = getHeldProjectileMeta()
						validWeapon = projMeta ~= nil
					end
					if not validWeapon then
						lockedTarget = nil
						return
					end

					if ClickAim and ClickAim.Enabled and projMeta then
						if not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
							return
						end
					elseif ClickAim and ClickAim.Enabled then
						local sc = bedwars.SwordController
						local lastAttack = sc and rawget(sc, 'lastAttack')
						if not lastAttack or (workspace:GetServerTimeNow() - lastAttack) >= 0.4 then
							return
						end
					end

					local inFirstPerson = isFirstPerson()
					if ViewMode.Value == 'First Person' and not inFirstPerson then return end
					if ViewMode.Value == 'Third Person' and inFirstPerson then return end

					if ShopCheck and ShopCheck.Enabled then
						if isGUIOpen() then
							lockedTarget = nil
							return
						end
					end

					local ent = nil

					if KillauraTarget and KillauraTarget.Enabled then
						local ka = store.KillauraTarget
						if ka and ka.RootPart and ka.Character and ka.Character.Parent then
							local hum = ka.Character:FindFirstChildOfClass('Humanoid')
							local dist = ka.RootPart and entitylib.character and entitylib.character.RootPart and (ka.RootPart.Position - entitylib.character.RootPart.Position).Magnitude
							if hum and hum.Health > 0 and dist and dist <= Distance.Value then
								ent = ka
							end
						end
					else
						if PriorityMode and PriorityMode.Enabled and lockedTarget then
							if isEntValid(lockedTarget) and isInAngle(lockedTarget) then
								ent = lockedTarget
							else
								lockedTarget = nil
							end
						end

						if not ent then
							local found = entitylib.EntityPosition({
								Range = Distance.Value,
								Part = 'RootPart',
								Wallcheck = Targets.Walls.Enabled,
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Sort = sortmethods[Sort.Value]
							})

							if found then
								lastValidTarget = found
								lastValidTime = tick()
								ent = found
							elseif lastValidTarget and (tick() - lastValidTime) < GRACE_PERIOD then
								local hum = lastValidTarget.Character and lastValidTarget.Character:FindFirstChildOfClass('Humanoid')
								if hum and hum.Health > 0 and lastValidTarget.Character.Parent and isInAngle(lastValidTarget) then
									ent = lastValidTarget
								else
									lastValidTarget = nil
								end
							end

							if ent and PriorityMode and PriorityMode.Enabled then
								lockedTarget = ent
							end
						end
					end	

					if not ent then return end

					if not (KillauraTarget and KillauraTarget.Enabled) then
						if not isEntValid(ent) then
							if PriorityMode and PriorityMode.Enabled then lockedTarget = nil end
							lastValidTarget = nil
							return
						end
						if not isInAngle(ent) then
							if PriorityMode and PriorityMode.Enabled then lockedTarget = nil end
							return
						end
					end

					targetinfo.Targets[ent] = tick() + 1

					local aimPosition
					if AimPart.Value == 'Head' then
						local head = ent.Character and ent.Character:FindFirstChild('Head')
						aimPosition = head and head.Position or ent.RootPart.Position
					elseif AimPart.Value == 'Torso' then
						local torso = ent.Character and (ent.Character:FindFirstChild('UpperTorso') or ent.Character:FindFirstChild('Torso'))
						aimPosition = torso and torso.Position or ent.RootPart.Position
					elseif AimPart.Value == 'Closest' then
						local closest = ent.Character and getClosestPartToCursor(ent.Character)
						aimPosition = closest and closest.Position or ent.RootPart.Position
					else
						aimPosition = ent.RootPart.Position
					end

					if projMeta then
						local projSpeed = projMeta.launchVelocity
						local gravity = tonumber(projMeta.gravitationalAcceleration) or 196.2
						if gravity < 1 then gravity = 0 end
						local playerGravity = workspace.Gravity
						local balloons = ent.Character and ent.Character:GetAttribute('InflatedBalloons')
						if balloons and balloons > 0 then
							playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
						end
						local rawVel = ent.RootPart.AssemblyLinearVelocity
						local tHum = ent.Character and ent.Character:FindFirstChildOfClass('Humanoid')
						local airborne = (tHum and tHum.FloorMaterial == Enum.Material.Air) or math.abs(rawVel.Y) > 3
						local map = workspace:FindFirstChild('Map')
						if map then projRayCheck.FilterDescendantsInstances = {map} end
						local origin = entitylib.character.RootPart.Position
						local spawnPos = prediction.GetSpawnPosition(origin, aimPosition, bedwars.BowConstantsTable.RelX, bedwars.BowConstantsTable.RelY, bedwars.BowConstantsTable.RelZ)
						local calc = prediction.SolveTrajectory(spawnPos, projSpeed, gravity, aimPosition, rawVel, playerGravity, ent.HipHeight, ent.Jumping and 42.6 or nil, projRayCheck, airborne, ent.RootPart.Position, ent.RootPart, nil, true)
						if calc then
							aimPosition = calc
						end
					end

					if ShakeToggle and ShakeToggle.Enabled and ShakeAmount.Value > 0 then
						shakeTime = shakeTime + dt
						local camCF = gameCamera.CFrame
						local dist = (aimPosition - camCF.Position).Magnitude
						local intensity = ShakeAmount.Value * 0.0035 * math.max(dist, 1)
						local driftX = math.noise(shakeTime * 0.8, 0, shakeSeed) * 2
						local driftY = math.noise(0, shakeTime * 0.7, shakeSeed) * 2
						local microX = math.noise(shakeTime * 9.5, shakeSeed, 0) * 2
						local microY = math.noise(shakeSeed, shakeTime * 10.7, 0) * 2
						local sx = (driftX * 0.7 + microX * 0.3) * intensity
						local sy = (driftY * 0.55 + microY * 0.25) * intensity
						aimPosition = aimPosition + camCF.RightVector * sx + camCF.UpVector * sy
					end

					local targetCFrame = CFrame.lookAt(gameCamera.CFrame.p, aimPosition)
					local smoothVal = (SmoothnessToggle and SmoothnessToggle.Enabled and Smoothness) and Smoothness.Value or nil
					local alpha = getAimAlpha(AimSpeed.Value, smoothVal, dt)
					gameCamera.CFrame = gameCamera.CFrame:Lerp(targetCFrame, alpha)
				end))
			else
				lockedTarget = nil
				lastValidTarget = nil
				shakeTime = 0
			end
		end,
		Tooltip = 'aa with smooth tracking'
	})

	Targets = AimAssist:CreateTargets({
		Players = true,
		Walls = true
	})

	Sort = AimAssist:CreateDropdown({
		Name = 'Target Mode',
		List = getSortList({'Damage', 'Distance'}),
		Tooltip = 'prioritize targets'
	})

	AimPart = AimAssist:CreateDropdown({
		Name = 'Aim Part',
		List = {'Torso', 'Head', 'Closest'},
		Default = 'Torso'
	})

	ViewMode = AimAssist:CreateDropdown({
		Name = 'View Mode',
		List = {'First Person', 'Third Person', 'Both'},
		Default = 'Both',
		Tooltip = 'either only aim in first person or third person, or both'
	})
	getgenv().ViewMode = ViewMode

	AimSpeed = AimAssist:CreateSlider({
		Name = 'Aim Speed',
		Min = 1,
		Max = 20,
		Default = 6,
		Tooltip = 'how fast aim assist moves toward the target'
	})

	Distance = AimAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 30,
		Default = 25,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	AngleSlider = AimAssist:CreateSlider({
		Name = 'Max Angle',
		Min = 1,
		Max = 360,
		Default = 60,
	})

	SmoothnessToggle = AimAssist:CreateToggle({
		Name = 'Smoothness',
		Default = false,
		Tooltip = 'makes aim assist feels more legit',
		Function = function(callback)
			if Smoothness then Smoothness.Object.Visible = callback end
		end
	})

	Smoothness = AimAssist:CreateSlider({
		Name = 'Smoothness Amount',
		Min = 1,
		Max = 10,
		Default = 5,
		Visible = false
	})

	PriorityMode = AimAssist:CreateToggle({
		Name = 'Priority Mode',
		Default = false,
		Tooltip = 'stays on one target until target is lost'
	})

	ClickAim = AimAssist:CreateToggle({
		Name = 'Click Aim',
		Default = true,
		Tooltip = 'only aims when clicking'
	})

	KillauraTarget = AimAssist:CreateToggle({
		Name = 'Use Killaura Target',
	})

	ShakeToggle = AimAssist:CreateToggle({
		Name = 'Shake',
		Default = false,
		Tooltip = 'shakes your screen for more legitness',
		Function = function(callback)
			if ShakeAmount then ShakeAmount.Object.Visible = callback end
		end
	})

	ShakeAmount = AimAssist:CreateSlider({
		Name = 'Shake Amount',
		Min = 1,
		Max = 10,
		Default = 3,
		Visible = false
	})

	ShopCheck = AimAssist:CreateToggle({
		Name = 'Shop Check',
		Default = false,
	})

	WorkWithProjectiles = AimAssist:CreateToggle({
		Name = 'Work With Projectiles',
		Default = false,
		Tooltip = 'aims where they gonna be when ur holdin a bow or any projectile'
	})

	task.defer(function()
		if Smoothness and Smoothness.Object then
			Smoothness.Object.Visible = SmoothnessToggle and SmoothnessToggle.Enabled or false
		end
		if ShakeAmount and ShakeAmount.Object then
			ShakeAmount.Object.Visible = false
		end
	end)
end)
run(function()
	local ProjectileAimbot
	local TargetPart
	local Targets
	local FOV
	local Range
	local OtherProjectiles
	local Blacklist
	local SortMethod
	local skidPAChargePercent
	local RandomHeadPercent
	local RandomTorsoPercent
	local DesirePAWorkMode
	local DesirePAHideCursor
	local DesirePACursorViewMode
	local DesirePACursorLimitBow
	local DesirePACursorShowGUI
	local cursorRenderConnection
	local lastGUIState = false
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	local _rayMap = nil
	local function refreshRayCheck()
		local map = workspace:FindFirstChild('Map')
		if map ~= _rayMap or not map or not map.Parent then
			_rayMap = map
			if map and map.Parent then
				rayCheck.FilterDescendantsInstances = {map}
			else
				rayCheck.FilterType = Enum.RaycastFilterType.Exclude
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
				return
			end
			rayCheck.FilterType = Enum.RaycastFilterType.Include
		end
	end
	refreshRayCheck()
	local old
	local math_sqrt = math.sqrt
	local math_rad = math.rad
	local math_cos = math.cos
	local math_clamp = math.clamp
	local math_min = math.min
	local math_max = math.max
	local lockedRandomPart = nil
	local wasHovering = false
	local _paVelHistory = {}
	local CustomPredictions
	local PredictHorizontal
	local PredictVertical
	local PAFOVCircle
	local paFOVCircleDrawing = nil
	local AutoCharge
	local paFOVCircleConnection = nil

	local paFOVCircleDrawing = nil 
	local paFOVCircleConnection = nil

	local function runPAFOVCircle(call)
		if paFOVCircleConnection then
			paFOVCircleConnection:Disconnect()
			paFOVCircleConnection = nil
		end
		if paFOVCircleDrawing then
			paFOVCircleDrawing:Destroy()
			paFOVCircleDrawing = nil
		end
		if not call then return end

		paFOVCircleDrawing = Instance.new('Frame')
		paFOVCircleDrawing.Name = 'PAFOVCircle'
		paFOVCircleDrawing.BackgroundTransparency = 1
		paFOVCircleDrawing.AnchorPoint = Vector2.new(0.5, 0.5)
		paFOVCircleDrawing.Visible = false
		local stroke = Instance.new('UIStroke')
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Parent = paFOVCircleDrawing
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = paFOVCircleDrawing
		paFOVCircleDrawing.Parent = vape.gui

		paFOVCircleConnection = runService.RenderStepped:Connect(function()
			if not paFOVCircleDrawing or not FOV or not FOV.Value then
				paFOVCircleDrawing.Visible = false
				return
			end

			local shouldShow = false
			if PAFOVCircle and PAFOVCircle.Enabled and ProjectileAimbot and ProjectileAimbot.Enabled then
				local tool = store.hand and store.hand.tool
				local itemType = tool and tool.Name or ""
				local itemMeta = bedwars.ItemMeta and bedwars.ItemMeta[itemType]
				if itemMeta and itemMeta.projectileSource then
					local src = itemMeta.projectileSource
					local isArrow = src.ammoItemTypes and table.find(src.ammoItemTypes, 'arrow')
					local isHeadhunter = itemType:find('headhunter')
					if isArrow or isHeadhunter then
						shouldShow = true
					elseif OtherProjectiles and OtherProjectiles.Enabled then
						local projectileType = src.projectileType and (type(src.projectileType) == 'function' and src.projectileType('arrow') or src.projectileType) or ""
						local blacklisted = false
						for _, black in ipairs(Blacklist and Blacklist.ListEnabled or {}) do
							if tostring(projectileType):find(black) then
								blacklisted = true
								break
							end
						end
						if not blacklisted then
							shouldShow = true
						end
					end
				end
			end

			paFOVCircleDrawing.Visible = shouldShow

			if shouldShow then
				local mousePos
				if inputService.TouchEnabled then
					mousePos = gameCamera.ViewportSize / 2
				else
					local mp = inputService:GetMouseLocation()
					mousePos = Vector2.new(mp.X, mp.Y)
				end
				paFOVCircleDrawing.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
				paFOVCircleDrawing.Size = UDim2.fromOffset(FOV.Value * 2, FOV.Value * 2)
			end
		end)
	end

	local function hasBowEquipped()
		if not store.hand or not store.hand.toolType then return false end
		return store.hand.toolType == 'bow' or store.hand.toolType == 'crossbow'
	end

	local function shouldHideCursor()
		if not DesirePAHideCursor or not DesirePAHideCursor.Enabled then return false end
		if DesirePACursorShowGUI and DesirePACursorShowGUI.Enabled and isGUIOpen() then return false end
		if DesirePACursorLimitBow and DesirePACursorLimitBow.Enabled and not hasBowEquipped() then return false end
		local inFirstPerson = isFirstPerson()
		if DesirePACursorViewMode then
			if DesirePACursorViewMode.Value == 'First Person' then return inFirstPerson
			elseif DesirePACursorViewMode.Value == 'Third Person' then return not inFirstPerson
			end
		end
		return true
	end

	local function updateCursor()
		pcall(function() inputService.MouseIconEnabled = not shouldHideCursor() end)
	end

	local function checkGUIState()
		local currentGUIState = isGUIOpen()
		if lastGUIState ~= currentGUIState then
			updateCursor()
			lastGUIState = currentGUIState
		end
	end

	local paLockedTarget = nil
	local paLockTime = 0
	local paLeadStart = 0
	local paVelSmooth = setmetatable({}, {__mode = 'k'})

	local function paValidLock(originPos)
		local t = paLockedTarget
		if not t then return nil end
		if tick() - paLockTime > 2 then return nil end
		if not t.Character or not t.Character.Parent then return nil end
		if not t.RootPart or not t.RootPart.Parent then return nil end
		local hp = t.Humanoid and t.Humanoid.Health or t.Health
		if type(hp) == 'number' and hp <= 0 then return nil end
		if (t.RootPart.Position - originPos).Magnitude > Range.Value then return nil end
		local _, visible = gameCamera:WorldToViewportPoint(t.RootPart.Position)
		if not visible then return nil end
		return t
	end

	local function shouldPAWork()
		if not DesirePAWorkMode then return true end
		local inFirstPerson = isFirstPerson()
		if DesirePAWorkMode.Value == 'First Person' then return inFirstPerson
		elseif DesirePAWorkMode.Value == 'Third Person' then return not inFirstPerson
		end
		return true
	end

	local function isBlacklisted(projectileName)
		if not OtherProjectiles or not OtherProjectiles.Enabled then
			local isTurret = projectileName:find('turret') ~= nil or projectileName:find('vulcan') ~= nil
			return not projectileName:find('arrow') and not isTurret
		end
		for _, black in ipairs(Blacklist and Blacklist.ListEnabled or {}) do
			if projectileName:find(black) then
				return true
			end
		end
		return false
	end

	local function pickRandomPart(character)
		local roll = math.random(1, 100)
		local headChance = RandomHeadPercent.Value
		local torsoChance = RandomTorsoPercent.Value
		if roll <= headChance then
			return character:FindFirstChild('Head') or character:FindFirstChild('HumanoidRootPart')
		elseif roll <= headChance + torsoChance then
			return character:FindFirstChild('UpperTorso') or character:FindFirstChild('HumanoidRootPart')
		else
			return character:FindFirstChild('HumanoidRootPart')
		end
	end

	local function getClosestPart(character, mousePos)
		local parts = {
			'HumanoidRootPart', 'Head', 'LeftHand', 'RightHand',
			'LeftLowerArm', 'RightLowerArm', 'LeftUpperArm', 'RightUpperArm',
			'LeftFoot', 'RightFoot', 'LeftLowerLeg', 'RightLowerLeg',
			'LeftUpperLeg', 'RightUpperLeg', 'LowerTorso', 'UpperTorso'
		}
		local camera = gameCamera
		local rayOrigin = camera.CFrame.Position
		local rayDir = camera:ScreenPointToRay(mousePos.X, mousePos.Y, 0).Direction
		local bestAngle = math.huge
		local bestPart = nil

		for _, partName in ipairs(parts) do
			local part = character:FindFirstChild(partName)
			if part then
				local dirToPart = (part.Position - rayOrigin).Unit
				local angle = math.acos(math_clamp(rayDir:Dot(dirToPart), -1, 1))
				if angle < bestAngle then
					bestAngle = angle
					bestPart = part
				end
			end
		end
		return bestPart or character:FindFirstChild('HumanoidRootPart')
	end

	ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		Function = function(callback)
			if callback then
				if SilentAim and SilentAim.Enabled then
					SilentAim:Toggle(false)
					notif('ProjectileAimbot', 'turned off SilentAim, they cant both run at once gng', 4)
				end
				if PAFOVCircle then
					runPAFOVCircle(PAFOVCircle.Enabled)
				end
				if DesirePAHideCursor and DesirePAHideCursor.Enabled and not cursorRenderConnection then
					cursorRenderConnection = runService.RenderStepped:Connect(function()
						checkGUIState()
						updateCursor()
					end)
					ProjectileAimbot:Clean(cursorRenderConnection)
				end

				old = bedwars.ProjectileController.calculateImportantLaunchValues
				bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
					local self, projmeta, worldmeta, origin, shootpos = ...
					local originPos = entitylib.isAlive and (shootpos or (entitylib.character and entitylib.character.RootPart and entitylib.character.RootPart.Position)) or Vector3.zero
					if not originPos then return old(...) end

					local plr = paValidLock(originPos)
					if not plr then
						plr = entitylib.EntityMouse({
							Part = 'RootPart',
							Range = FOV.Value,
							Players = Targets.Players.Enabled,
							NPCs = (Targets.NPCs and Targets.NPCs.Enabled) or false,
							Wallcheck = Targets.Walls.Enabled,
							Sort = sortmethods[SortMethod.Value or 'Cursor'],
							Origin = originPos
						})
						if plr then
							paLockedTarget = plr
							paLockTime = tick()
							paLeadStart = tick()
						end
					end

					if not plr then
						paLockedTarget = nil
						paLeadStart = 0
						wasHovering = false
						return old(...)
					end
					
					if not shouldPAWork() then
						wasHovering = false
						return old(...)
					end

					local targetBodyPart = nil
					if TargetPart.Value == 'Dynamic' then
						local tool = store.hand and store.hand.tool
						local itemType = tostring(tool and tool.Name or ""):lower()
						local isHH = itemType:find("headhunter")
						targetBodyPart = (isHH and plr.Character and plr.Character:FindFirstChild("Head")) or plr.RootPart
					elseif TargetPart.Value == 'RootPart' then
						targetBodyPart = plr.RootPart
					elseif TargetPart.Value == 'Head' then
						targetBodyPart = (plr.Character and plr.Character:FindFirstChild('Head')) or plr.RootPart
					elseif TargetPart.Value == 'Closest' then
						local mousePos = inputService.TouchEnabled and (gameCamera.ViewportSize / 2) or inputService:GetMouseLocation()
						targetBodyPart = plr.Character and getClosestPart(plr.Character, mousePos) or plr.RootPart
					elseif TargetPart.Value == 'Randomize' then
						if lockedRandomPart and lockedRandomPart.Parent ~= plr.Character then
							lockedRandomPart = nil
						end
						if plr.Character and (not lockedRandomPart or not lockedRandomPart.Parent) then
							lockedRandomPart = pickRandomPart(plr.Character)
						end
						targetBodyPart = lockedRandomPart or plr.RootPart
					else
						targetBodyPart = plr.RootPart
					end
					if not targetBodyPart then
						wasHovering = false
						return old(...)
					end
					local dist = (targetBodyPart.Position - originPos).Magnitude
					if dist > Range.Value then
						wasHovering = false
						return old(...)
					end
					local pos = shootpos or self:getLaunchPosition(origin)
					if not pos then
						wasHovering = false
						return old(...)
					end
					local projectileName = projmeta.projectile or ""
					if isBlacklisted(projectileName) then
						wasHovering = false
						return old(...)
					end
					refreshRayCheck()
					local meta = projmeta:getProjectileMeta()
					local overrides

					if meta.getProjectileOverridesFunction then
						pcall(function()
							overrides = meta.getProjectileOverridesFunction(lplr)
						end)
					end

					overrides = type(overrides) == 'table' and overrides or {}

					local predictionLifetime = tonumber(overrides.predictionLifetimeOverride) or tonumber(meta.predictionLifetimeSec)
					local normalLifetime = tonumber(overrides.lifetimeOverride) or tonumber(meta.lifetimeSec) or 3
					local lifetime = worldmeta and (predictionLifetime or normalLifetime) or normalLifetime
					local gravityMultiplier = tonumber(projmeta.gravityMultiplier) or 1
					local gravity = (tonumber(meta.gravitationalAcceleration) or 196.2) * gravityMultiplier

					local toolMeta = origin and bedwars.ItemMeta[origin.Name]
					local sourceMeta = toolMeta and toolMeta.projectileSource
					local maxDraw = tonumber(sourceMeta and sourceMeta.maxStrengthChargeSec)
						or tonumber(sourceMeta and sourceMeta.maxDrawDurationSeconds)
						or (tostring(projmeta.projectile):find('arrow') and 0.65 or 0.8)

					local paMinScalar = tonumber(sourceMeta and sourceMeta.minStrengthScalar) or 1
					local baseSpeed = tonumber(overrides.launchVelocityOverride) or tonumber(meta.launchVelocity) or 100
					local nativeValues = old(...)
					local projSpeed
					local customDrawDuration
					local offsetpos

					if nativeValues and typeof(nativeValues.positionFrom) == 'Vector3' then
						offsetpos = nativeValues.positionFrom
					else
						local safeOffset = projmeta.fromPositionOffset

						if typeof(safeOffset) ~= 'Vector3' then
							safeOffset = Vector3.new(0, 2, 0)
						end

						offsetpos = pos + safeOffset
					end

					if nativeValues and type(nativeValues.gravitationalAcceleration) == 'number' then
						gravity = nativeValues.gravitationalAcceleration
					end

					if AutoCharge.Enabled then
						local drawPct = math.clamp(skidPAChargePercent.Value / 100, 0, 1)

						projSpeed = baseSpeed * (paMinScalar + (1 - paMinScalar) * drawPct)
						customDrawDuration = maxDraw * drawPct
					else
						if nativeValues
							and typeof(nativeValues.initialVelocity) == 'Vector3'
							and nativeValues.initialVelocity.Magnitude > 0 then

							projSpeed = nativeValues.initialVelocity.Magnitude
						else
							local liveDraw = tonumber(projmeta.drawDurationSeconds) or 0
							local livePct = maxDraw > 0 and math.clamp(liveDraw / maxDraw, 0, 1) or 0

							projSpeed = baseSpeed * (paMinScalar + (1 - paMinScalar) * livePct)
						end

						customDrawDuration = nativeValues
							and tonumber(nativeValues.drawDurationSeconds)
							or tonumber(projmeta.drawDurationSeconds)
							or 0
					end
					local balloons = plr.Character and plr.Character:GetAttribute('InflatedBalloons')
					local playerGravity = workspace.Gravity
					if balloons and balloons > 0 then
						playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
					end
					if plr.Character and plr.Character.PrimaryPart and plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
						playerGravity = 6
					end
					if plr.Player and plr.Player:GetAttribute('IsOwlTarget') then
						for _, owl in ipairs(collectionService:GetTagged('Owl')) do
							if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then
								playerGravity = 0
								break
							end
						end
					end
					local rawVel = plr.RootPart.AssemblyLinearVelocity or plr.RootPart.Velocity or Vector3.zero
					local aimTarget = targetBodyPart.Position
		if targetBodyPart.Name ~= 'Head' and plr.RootPart then
			local rootY = plr.RootPart.Position.Y
			aimTarget = Vector3.new(aimTarget.X, math.clamp(aimTarget.Y, rootY - 1, rootY + 1), aimTarget.Z)
		end
					if targetBodyPart.Name ~= 'Head' and plr.RootPart then
						local rootY = plr.RootPart.Position.Y
						aimTarget = Vector3.new(aimTarget.X, math.clamp(aimTarget.Y, rootY - 1, rootY + 1), aimTarget.Z)
					end
					local solverVelocity = projmeta.projectile == 'telepearl' and Vector3.zero or rawVel
					local tHum = plr.Character and plr.Character:FindFirstChildOfClass('Humanoid')
					local tAirborne = false
					if tHum then
						tAirborne = tHum.FloorMaterial == Enum.Material.Air
						if not tAirborne then
							local st = tHum:GetState()
							tAirborne = st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall
						end
					end
					if not tAirborne and math.abs(rawVel.Y) > 3 then
						tAirborne = true
					end
					local tJumpPower = 42.6
					if tHum and tHum.UseJumpPower and tHum.JumpPower and tHum.JumpPower > 0 then
						tJumpPower = tHum.JumpPower
					end
					local tJump = (tAirborne or plr.Jumping) and tJumpPower or nil
					local horizLead = 1
					local vertLead = 1
					if CustomPredictions and CustomPredictions.Enabled and projmeta.projectile ~= 'telepearl' then
						horizLead = PredictHorizontal.Value / 100
						vertLead = PredictVertical.Value / 100
					end
					if horizLead ~= 1 or vertLead ~= 1 then
						solverVelocity = Vector3.new(
							solverVelocity.X * horizLead,
							solverVelocity.Y * vertLead,
							solverVelocity.Z * horizLead
						)
					end

					if projSpeed < 230 and projmeta.projectile ~= 'telepearl' then
						local prev = paVelSmooth[plr.RootPart]
						if prev then
							solverVelocity = prev:Lerp(solverVelocity, 0.3)
						end
						paVelSmooth[plr.RootPart] = solverVelocity
					end
					local leadAlpha = math.clamp((tick() - paLeadStart) / 0.2, 0, 1)
					leadAlpha = leadAlpha * leadAlpha * (3 - 2 * leadAlpha)
					local launchOrigin = offsetpos
					local solveOrigin = offsetpos
					local calc, _, flightTime = prediction.SolveTrajectory(
						solveOrigin, projSpeed, gravity,
						aimTarget,
						solverVelocity,
						playerGravity, plr.HipHeight,
						tJump,
						rayCheck,
						tAirborne,
						plr.RootPart.Position,
						plr.RootPart,
						nil,
						true,
						leadAlpha
					)

					if calc then
						local bow = bedwars.BowConstantsTable or {}
						local rel = sourceMeta and sourceMeta.relativeOverride
						local rx, ry, rz = bow.RelX or 0.8, bow.RelY or -0.6, bow.RelZ or 0
						if type(rel) == 'table' then
							rx, ry, rz = rel.relX or 0, rel.relY or 0, rel.relZ or 0
						end
						local function aimFrom(offset)
							local point = aimTarget + Vector3.new(0, offset, 0)
							local c1, _, f1 = prediction.SolveTrajectory(solveOrigin, projSpeed, gravity, point, solverVelocity, playerGravity, plr.HipHeight, tJump, rayCheck, tAirborne, plr.RootPart.Position, plr.RootPart, nil, true, leadAlpha)
							if not c1 then return nil end
							local s1 = prediction.GetSpawnPosition(solveOrigin, c1, rx, ry, rz)
							local c2, _, f2 = prediction.SolveTrajectory(s1, projSpeed, gravity, point, solverVelocity, playerGravity, plr.HipHeight, tJump, rayCheck, tAirborne, plr.RootPart.Position, plr.RootPart, nil, true, leadAlpha)
							if c2 and f2 then
								c1 = solveOrigin + (c2 - s1)
								f1 = f2
								s1 = prediction.GetSpawnPosition(solveOrigin, c1, rx, ry, rz)
							end
							return c1, f1, s1
						end
						local c0, f0, s0 = aimFrom(0)
						if c0 and f0 then
							calc, flightTime = c0, f0
							if not worldmeta and not prediction.IsTrajectoryClear(s0, (c0 - solveOrigin).Unit * projSpeed, gravity, f0 * 0.97, rayCheck) then
								for _, dy in {0.8, -0.8, 1.6, -1.6} do
									local c3, f3, s3 = aimFrom(dy)
									if c3 and f3 and prediction.IsTrajectoryClear(s3, (c3 - solveOrigin).Unit * projSpeed, gravity, f3 * 0.97, rayCheck) then
										calc, flightTime = c3, f3
										break
									end
								end
							end
						end
					end
					local returnDist = tonumber(overrides.returnDistanceOverride) or tonumber(meta.returnDistance)
					if calc and flightTime and flightTime <= lifetime and (not returnDist or projSpeed * flightTime <= returnDist - 2) then
						paLockedTarget = plr
						paLockTime = tick()

						if targetinfo and targetinfo.Targets then
							targetinfo.Targets[plr] = tick() + 1
						end

						wasHovering = false
						return {
							initialVelocity = CFrame.lookAt(solveOrigin, calc).LookVector * projSpeed,
							positionFrom = launchOrigin,
							deltaT = lifetime,
							gravitationalAcceleration = gravity,
							drawDurationSeconds = customDrawDuration
						}
					end
					wasHovering = false
					return old(...)
				end
			else
				bedwars.ProjectileController.calculateImportantLaunchValues = old
				paLockedTarget = nil
				paLeadStart = 0
				wasHovering = false
				lockedRandomPart = nil
				table.clear(_paVelHistory)
				if cursorRenderConnection then
					cursorRenderConnection:Disconnect()
					cursorRenderConnection = nil
				end
				runPAFOVCircle(false)
				pcall(function() inputService.MouseIconEnabled = true end)
				task.defer(function()
					pcall(function() inputService.MouseIconEnabled = true end)
					pcall(function() game:GetService('UserInputService').MouseIconEnabled = true end)
				end)
			end
		end,
		Tooltip = 'helps your shitty ass aim'
	})

	Targets = ProjectileAimbot:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})

	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'Dynamic', 'RootPart', 'Head', 'Closest', 'Randomize'},
		Default = 'RootPart',
		Function = function()
			lockedRandomPart = nil
			wasHovering = false
		end
	})

	SortMethod = ProjectileAimbot:CreateDropdown({
		Name = 'Sort Method',
		List = getSortList({'Distance', 'Damage', 'Cursor'}),
		Default = 'Cursor',
	})

	DesirePAWorkMode = ProjectileAimbot:CreateDropdown({
		Name = 'PA Work Mode',
		List = {'First Person', 'Third Person', 'Both'},
		Default = 'Both',
	})

	Range = ProjectileAimbot:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 500,
		Default = 100,
	})

	FOV = ProjectileAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 300,
	})

	PAFOVCircle = ProjectileAimbot:CreateToggle({
		Name = 'FOV Circle',
		Function = function(call)
			runPAFOVCircle(call)
		end
	})

	RandomHeadPercent = ProjectileAimbot:CreateSlider({
		Name = 'Head Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Darker = true,
		Visible = false
	})

	RandomTorsoPercent = ProjectileAimbot:CreateSlider({
		Name = 'Torso Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Darker = true,
		Visible = false,
		Function = function(val)
			if RandomHeadPercent and (RandomHeadPercent.Value + val) > 100 then
				notif('ProjectileAimbot', 'head or torso chance is more than 100% so root part will never be picked..', 3)
			end
		end
	})

	local function updateRandomizeVisibility()
		local vis = (TargetPart.Value == 'Randomize')
		RandomHeadPercent.Object.Visible = vis
		RandomTorsoPercent.Object.Visible = vis
	end
	if TargetPart.AddHook then
		TargetPart:AddHook(updateRandomizeVisibility)
	end
	updateRandomizeVisibility()

	DesirePAHideCursor = ProjectileAimbot:CreateToggle({
		Name = 'Hide Cursor',
		Default = false,
		Tooltip = 'Hides the cursor while aiming',
		Function = function(callback)
			if DesirePACursorViewMode then DesirePACursorViewMode.Object.Visible = callback end
			if DesirePACursorLimitBow then DesirePACursorLimitBow.Object.Visible = callback end
			if DesirePACursorShowGUI then DesirePACursorShowGUI.Object.Visible = callback end
			if callback and ProjectileAimbot.Enabled then
				if not cursorRenderConnection then
					cursorRenderConnection = runService.RenderStepped:Connect(function()
						checkGUIState()
						updateCursor()
					end)
				end
				updateCursor()
			else
				if cursorRenderConnection then
					cursorRenderConnection:Disconnect()
					cursorRenderConnection = nil
				end
				pcall(function() inputService.MouseIconEnabled = true end)
				task.defer(function()
					pcall(function() inputService.MouseIconEnabled = true end)
					pcall(function() game:GetService('UserInputService').MouseIconEnabled = true end)
				end)
			end
		end
	})

	DesirePACursorViewMode = ProjectileAimbot:CreateDropdown({
		Name = 'Cursor View Mode',
		List = {'First Person', 'Third Person', 'Both'},
		Default = 'First Person',
		Darker = true,
		Visible = false,
		Function = function()
			if ProjectileAimbot.Enabled and DesirePAHideCursor.Enabled then
				updateCursor()
			end
		end
	})

	DesirePACursorLimitBow = ProjectileAimbot:CreateToggle({
		Name = 'Limit to Bow',
		Darker = true,
		Visible = false,
		Function = function()
			if ProjectileAimbot.Enabled and DesirePAHideCursor.Enabled then
				updateCursor()
			end
		end
	})

	DesirePACursorShowGUI = ProjectileAimbot:CreateToggle({
		Name = 'Show on GUI',
		Darker = true,
		Visible = false,
		Function = function()
			if ProjectileAimbot.Enabled and DesirePAHideCursor.Enabled then
				updateCursor()
			end
		end
	})

	OtherProjectiles = ProjectileAimbot:CreateToggle({
		Name = 'Other Projectiles',
		Default = true,
		Function = function(call)
			if Blacklist then Blacklist.Object.Visible = call end
		end
	})

	Blacklist = ProjectileAimbot:CreateTextList({
		Name = 'Blacklist',
		Darker = true,
		Default = {'telepearl'},
		Visible = OtherProjectiles.Enabled
	})

	CustomPredictions = ProjectileAimbot:CreateToggle({
		Name = 'Custom Predictions',
		Default = false,
		Tooltip = 'lets u control how much it leads the target urself',
		Function = function(callback)
			if PredictHorizontal then PredictHorizontal.Object.Visible = callback end
			if PredictVertical then PredictVertical.Object.Visible = callback end
		end
	})
	PredictHorizontal = ProjectileAimbot:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 300,
		Default = 100,
		Suffix = '%',
		Darker = true,
		Visible = false
	})
	PredictVertical = ProjectileAimbot:CreateSlider({
		Name = 'Vertical',
		Min = 0,
		Max = 300,
		Default = 100,
		Suffix = '%',
		Darker = true,
		Visible = false
	})
	AutoCharge = ProjectileAimbot:CreateToggle({
		Name = "AutoCharge",
		Default = true,
		Function = function(v)
			if skidPAChargePercent and skidPAChargePercent.Object then skidPAChargePercent.Object.Visible = v end
		end
	})
	skidPAChargePercent = ProjectileAimbot:CreateSlider({
		Name = 'Charge Percent',
		Min = 1,
		Max = 100,
		Default = 100,
	})
end)
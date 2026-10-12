run(function()
	local SilentAim
	local Targets
	local TargetPart
	local SortMethod
	local Range
	local FOV
	local SAFOVCircle
	local RandomHeadPercent
	local RandomTorsoPercent
	local OtherProjectiles
	local Blacklist
	local AutoCharge
	local skidChargePercent

	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}

	local namecall
	local namecallHooked = false
	local lockedRandomPart
	local _saVelHistory = {}
	local _saVelStamp = {}
	local fovConn

	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
		return inputService:GetMouseLocation()
	end

	local function getClosestPart(char, mousePos)
		local magnitude, part = 9e9, nil
		for _, v in char:GetChildren() do
			if v:IsA('BasePart') then
				local position, vis = gameCamera:WorldToViewportPoint(v.Position)
				if vis then
					local mag = (mousePos - Vector2.new(position.X, position.Y)).Magnitude
					if mag < magnitude then
						magnitude = mag
						part = v
					end
				end
			end
		end
		return part
	end

	local function pickRandomPart(char)
		local roll = math.random(1, 100)
		local head = char:FindFirstChild('Head')
		local torso = char:FindFirstChild('HumanoidRootPart') or char.PrimaryPart
		if head and roll <= RandomHeadPercent.Value then
			return head
		elseif torso and roll <= (RandomHeadPercent.Value + RandomTorsoPercent.Value) then
			return torso
		end
		return torso or head
	end

	local function getTargetPart(plr)
		local val = TargetPart.Value
		if val == 'Dynamic' then
			local tool = store.hand and store.hand.tool
			local itemType = tostring(tool and tool.Name or ''):lower()
			if itemType:find('headhunter') and plr.Character and plr.Character:FindFirstChild('Head') then
				return plr.Character.Head
			end
			return plr.RootPart
		elseif val == 'Head' then
			return (plr.Character and plr.Character:FindFirstChild('Head')) or plr.RootPart
		elseif val == 'Closest' then
			return (plr.Character and getClosestPart(plr.Character, getMousePosition())) or plr.RootPart
		elseif val == 'Randomize' then
			if lockedRandomPart and lockedRandomPart.Parent ~= plr.Character then
				lockedRandomPart = nil
			end
			if plr.Character and (not lockedRandomPart or not lockedRandomPart.Parent) then
				lockedRandomPart = pickRandomPart(plr.Character)
			end
			return lockedRandomPart or plr.RootPart
		end
		return plr.RootPart
	end

	local function isBlacklisted(projType)
		local key = (projType == 'glue_trap' or projType == 'glue_projectile') and 'gloop' or projType
		if Blacklist and table.find(Blacklist.ListEnabled or Blacklist.Value or {}, key) then
			return true
		end
		return false
	end

	local fovDrawing
	local function isHoldingProjectile()
		local tool = store.hand and store.hand.tool
		local itemType = tool and tool.Name or ''
		local itemMeta = bedwars.ItemMeta and bedwars.ItemMeta[itemType]
		if not (itemMeta and itemMeta.projectileSource) then return false end
		local src = itemMeta.projectileSource
		local isArrow = src.ammoItemTypes and table.find(src.ammoItemTypes, 'arrow')
		local isHeadhunter = itemType:find('headhunter')
		if isArrow or isHeadhunter then return true end
		if OtherProjectiles and OtherProjectiles.Enabled then
			local projectileType = src.projectileType and (type(src.projectileType) == 'function' and src.projectileType('arrow') or src.projectileType) or ''
			for _, black in ipairs(Blacklist and Blacklist.ListEnabled or {}) do
				if tostring(projectileType):find(black) then return false end
			end
			return true
		end
		return false
	end
	local function runFOVCircle(state)
		if fovConn then fovConn:Disconnect() fovConn = nil end
		if fovDrawing then fovDrawing:Destroy() fovDrawing = nil end
		if not state then return end
		fovDrawing = Instance.new('Frame')
		fovDrawing.Name = 'SAFOVCircle'
		fovDrawing.BackgroundTransparency = 1
		fovDrawing.AnchorPoint = Vector2.new(0.5, 0.5)
		fovDrawing.Visible = false
		local stroke = Instance.new('UIStroke')
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Parent = fovDrawing
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = fovDrawing
		fovDrawing.Parent = vape.gui
		fovConn = runService.RenderStepped:Connect(function()
			if not fovDrawing or not FOV or not FOV.Value then return end
			local shouldShow = SilentAim and SilentAim.Enabled and SAFOVCircle and SAFOVCircle.Enabled and isHoldingProjectile()
			fovDrawing.Visible = shouldShow
			if shouldShow then
				local mousePos
				if inputService.TouchEnabled then
					mousePos = gameCamera.ViewportSize / 2
				else
					local mp = inputService:GetMouseLocation()
					mousePos = Vector2.new(mp.X, mp.Y)
				end
				fovDrawing.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
				fovDrawing.Size = UDim2.fromOffset(FOV.Value * 2, FOV.Value * 2)
			end
		end)
	end

	local function solveSilent(args)
		local origin, velocity, projType = args[4], args[6], args[3]
		if typeof(origin) ~= 'Vector3' then
			origin = args[5]
		end
		if typeof(origin) ~= 'Vector3' or typeof(velocity) ~= 'Vector3' or type(projType) ~= 'string' then
			return
		end

		if (not OtherProjectiles.Enabled) and not projType:find('arrow') then
			return
		end
		if isBlacklisted(projType) then return end

		local meta = bedwars.ProjectileMeta[projType]
		if not meta then return end

		local projSpeed = velocity.Magnitude
		if projSpeed <= 0 then return end

		if AutoCharge and AutoCharge.Enabled then
			local sourceTool = args[1]
			local itemMeta = sourceTool and bedwars.ItemMeta[sourceTool.Name]
			local sourceMeta = itemMeta and itemMeta.projectileSource
			local overrides

			if meta.getProjectileOverridesFunction then
				pcall(function()
					overrides = meta.getProjectileOverridesFunction(lplr)
				end)
			end

			overrides = type(overrides) == 'table' and overrides or {}

			local baseSpeed = tonumber(overrides.launchVelocityOverride) or tonumber(meta.launchVelocity) or projSpeed
			local minScalar = tonumber(sourceMeta and sourceMeta.minStrengthScalar) or 1
			local chargeRatio = math.clamp(skidChargePercent.Value / 100, 0, 1)

			projSpeed = baseSpeed * (minScalar + (1 - minScalar) * chargeRatio)
		end

		local gravity = tonumber(meta.gravitationalAcceleration)
		if gravity == nil then gravity = 196.2 end
		if gravity < 1 then gravity = 0 end

		local plr = entitylib.EntityMouse({
			Part = 'RootPart',
			Range = FOV.Value,
			Players = Targets.Players.Enabled,
			NPCs = (Targets.NPCs and Targets.NPCs.Enabled) or false,
			Wallcheck = Targets.Walls.Enabled,
			Sort = sortmethods[SortMethod.Value or 'Cursor'],
			Origin = origin,
		})
		if not plr then return end

		local targetBodyPart = getTargetPart(plr)
		if not targetBodyPart then return end

		local dist = (targetBodyPart.Position - origin).Magnitude
		if dist > Range.Value then return end

		local playerGravity = workspace.Gravity
		local balloons = plr.Character and plr.Character:GetAttribute('InflatedBalloons')
		if balloons and balloons > 0 then
			playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
		end
		if plr.Character and plr.Character.PrimaryPart and plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
			playerGravity = 6
		end

		local pearl = projType == 'telepearl'
		local rawVel = pearl and Vector3.zero or (plr.RootPart.AssemblyLinearVelocity or plr.RootPart.Velocity or Vector3.zero)
		local _velKey = tostring(plr)
		local _velNow = tick()
		if not _saVelHistory[_velKey] or (_velNow - (_saVelStamp[_velKey] or 0)) > 0.15 then
			_saVelHistory[_velKey] = rawVel
		else
			_saVelHistory[_velKey] = _saVelHistory[_velKey]:Lerp(rawVel, 0.35)
		end
		_saVelStamp[_velKey] = _velNow

		local aimTarget = targetBodyPart.Position
		if targetBodyPart.Name ~= 'Head' and plr.RootPart then
			local rootY = plr.RootPart.Position.Y
			aimTarget = Vector3.new(aimTarget.X, math.clamp(aimTarget.Y, rootY - 1, rootY + 1), aimTarget.Z)
		end
		local _map = workspace:FindFirstChild('Map')
		if _map then rayCheck.FilterDescendantsInstances = {_map} end
		local lifetime = tonumber(meta.predictionLifetimeSec) or tonumber(meta.lifetimeSec) or (projSpeed > 0 and math.min(3, 120 / projSpeed) or 3)
		local spawnPos = origin
		local calc, _, flightTime = prediction.SolveTrajectory(
			spawnPos, projSpeed, gravity,
			aimTarget, _saVelHistory[_velKey] or rawVel,
			playerGravity, plr.HipHeight,
			plr.Jumping and 42.6 or nil,
			rayCheck,
			(plr.Humanoid and plr.Humanoid.FloorMaterial == Enum.Material.Air) or math.abs(rawVel.Y) > 0.01,
			plr.RootPart.Position,
			plr.RootPart,
			nil,
			true
		)

		if calc then
			local bow = bedwars.BowConstantsTable or {}
			local spawn = prediction.GetSpawnPosition(spawnPos, calc, bow.RelX or 0.8, bow.RelY or -0.6, bow.RelZ or 0)
			local calc2, _, flight2 = prediction.SolveTrajectory(spawn, projSpeed, gravity, aimTarget, _saVelHistory[_velKey] or rawVel, playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, rayCheck, (plr.Humanoid and plr.Humanoid.FloorMaterial == Enum.Material.Air) or math.abs(rawVel.Y) > 0.01, plr.RootPart.Position, plr.RootPart, nil, true)
			if calc2 and flight2 then
				calc = spawnPos + (calc2 - spawn)
				flightTime = flight2
			end
		end
		if not calc or not flightTime or flightTime > lifetime then return end

		if targetinfo and targetinfo.Targets then
			targetinfo.Targets[plr] = tick() + 1
		end

		return (calc - spawnPos).Unit * projSpeed
	end

	SilentAim = vape.Categories.Blatant:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if callback then
				if ProjectileAimbot and ProjectileAimbot.Enabled then
					ProjectileAimbot:Toggle(false)
					notif('SilentAim', 'turned off ProjectileAimbot, they cant both run at once gng', 4)
				end
				if SAFOVCircle and SAFOVCircle.Enabled then
					runFOVCircle(true)
				end
				if not namecallHooked then
					namecallHooked = true
					namecall = hookmetamethod(game, '__namecall', newcclosure(function(...)
						if not SilentAim.Enabled or checkcaller() or getnamecallmethod() ~= 'InvokeServer' then
							return namecall(...)
						end
						local remote = ...
						if typeof(remote) == 'Instance' and remote.Name == 'ProjectileFire' then
							local args = table.pack(select(2, ...))
							local ok, newVelocity = pcall(solveSilent, args)
							if ok and typeof(newVelocity) == 'Vector3' then
								args[6] = newVelocity
								if AutoCharge.Enabled and typeof(args[8]) == 'table' then
									local sourceTool = args[1]
									local itemMeta = sourceTool and bedwars.ItemMeta[sourceTool.Name]
									local sourceMeta = itemMeta and itemMeta.projectileSource
									local maxCharge = tonumber(sourceMeta and sourceMeta.maxStrengthChargeSec)
										or tonumber(sourceMeta and sourceMeta.maxDrawDurationSeconds)

									if maxCharge then
										args[8].drawDurationSec = maxCharge * math.clamp(skidChargePercent.Value / 100, 0, 1)
									end
								end
							end
							local self = ...
							return self.InvokeServer(self, table.unpack(args, 1, args.n))
						end
						return namecall(...)
					end))
				end
			else
				lockedRandomPart = nil
				table.clear(_saVelHistory)
				table.clear(_saVelStamp)
				runFOVCircle(false)
			end
		end,
		Tooltip = 'hooks the projectile remote n sends diff args so it hits em where u aim on ur screen'
	})

	Targets = SilentAim:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})

	TargetPart = SilentAim:CreateDropdown({
		Name = 'Part',
		List = {'Dynamic', 'RootPart', 'Head', 'Closest', 'Randomize'},
		Default = 'RootPart',
		Function = function()
			lockedRandomPart = nil
		end
	})

	SortMethod = SilentAim:CreateDropdown({
		Name = 'Sort Method',
		List = getSortList({'Distance', 'Damage', 'Cursor'}),
		Default = 'Cursor',
	})

	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 500,
		Default = 100,
	})

	FOV = SilentAim:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 300,
	})

	SAFOVCircle = SilentAim:CreateToggle({
		Name = 'FOV Circle',
		Function = function(call)
			if SilentAim.Enabled then
				runFOVCircle(call)
			end
		end
	})

	RandomHeadPercent = SilentAim:CreateSlider({
		Name = 'Head Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Darker = true,
		Visible = false
	})

	RandomTorsoPercent = SilentAim:CreateSlider({
		Name = 'Torso Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Darker = true,
		Visible = false,
		Function = function(val)
			if RandomHeadPercent and (RandomHeadPercent.Value + val) > 100 then
				notif('SilentAim', 'head or torso chance is more than 100% so root part will never be picked..', 3)
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

	OtherProjectiles = SilentAim:CreateToggle({
		Name = 'Other Projectiles',
		Default = true,
		Function = function(call)
			if Blacklist then Blacklist.Object.Visible = call end
		end
	})
	Blacklist = SilentAim:CreateTextList({
		Name = 'Blacklist',
		Darker = true,
		Default = {'telepearl'},
		Visible = OtherProjectiles.Enabled
	})
	AutoCharge = SilentAim:CreateToggle({
		Name = 'AutoCharge',
		Default = true,
		Function = function(v)
			if skidChargePercent and skidChargePercent.Object then skidChargePercent.Object.Visible = v end
		end
	})
	skidChargePercent = SilentAim:CreateSlider({
		Name = 'Charge Percent',
		Min = 1,
		Max = 100,
		Default = 100,
	})
end)
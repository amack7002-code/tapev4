run(function()
	local AutoVulcan
	local Targets
	local ArrowCharge
	local turretfiretime = {}
	local netman = game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out._NetManaged
	local turretTargets = {}
	local Sort
	local AimTurretRemote = netman:FindFirstChild("AimTurret")
	local PFR = netman:FindFirstChild("ProjectileFire")
	local turretthread = {}
	local Distance
	local PHR = netman:FindFirstChild("ProjectileHit")
	local RTR = netman:FindFirstChild("RaycastTurret")
	local LimitTablet

	local function tableFind(tab, val)
		for _, v in ipairs(tab) do
			if v == val then return true end
		end
		return false
	end

	local function isHoldingTablet()
		local hand = store.hand
		return hand and hand.tool and hand.tool.Name and hand.tool.Name:find('tablet') ~= nil
	end

	local function getOwnedTurrets()
		local turrets = {}
		for _, block in ipairs(store.blocks or {}) do
			if block.Name == "camera_turret"
				and block:GetAttribute("PlacedByUserId") == lplr.UserId
				and block.Parent
			then
				table.insert(turrets, block)
			end
		end
		return turrets
	end

	local function isTargetValid(ent, turretPos)
		if not ent or not ent.Character then return false end
		if not ent.RootPart or not ent.RootPart.Parent then return false end
		if (ent.Character:GetAttribute("Health") or 0) <= 0 then return false end
		if (turretPos - ent.RootPart.Position).Magnitude > (Distance and Distance.Value or 1000) then return false end
		return true
	end

	local function getTarget(turret)
		local turretPos = turret.Position
		local locked = turretTargets[turret]
		if isTargetValid(locked, turretPos) then
			return locked
		end

		local ent = entitylib.EntityPosition({
			Origin = turretPos,
			Range = Distance and Distance.Value or 1000,
			Part = "RootPart",
			Players = Targets and Targets.Players.Enabled or true,
			NPCs = Targets and Targets.NPCs.Enabled or true,
			Sort = sortmethods and Sort and sortmethods[Sort.Value] or nil
		})

		turretTargets[turret] = ent
		return ent
	end

	local turretBlockPosCache = {}

	local function fireTurret(turret)
		if not turret or not turret.Parent then return end
		if LimitTablet and LimitTablet.Enabled and not isHoldingTablet() then return end

		local turretPos = turret.Position
		local blockPos = turretBlockPosCache[turret]
		if not blockPos then
			blockPos = bedwars.BlockController:getBlockPosition(turretPos)
			turretBlockPosCache[turret] = blockPos
		end
		local ent = getTarget(turret)
		if not ent or not ent.RootPart then return end

		local char = ent.Character
		local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or ent.RootPart
		local targetVel = ent.RootPart.AssemblyLinearVelocity or Vector3.zero
		local travel = (torso.Position - turretPos).Magnitude / 300
		local targetPos = torso.Position + targetVel * travel

		local lookDir = targetPos - turretPos
		if lookDir.Magnitude < 0.1 then return end
		lookDir = lookDir.Unit

		local flatMag = Vector3.new(lookDir.X, 0, lookDir.Z).Magnitude
		local yaw = math.atan2(-lookDir.X, -lookDir.Z)
		local pitch = math.atan2(lookDir.Y, flatMag > 0 and flatMag or 0.001)

		if AimTurretRemote then
			pcall(function()
				AimTurretRemote:FireServer({
					angleX = math.deg(yaw),
					angleY = math.deg(pitch),
					turretBlockPos = blockPos,
				})
			end)
		end

		local now = tick()
		if (now - (turretfiretime[turret] or 0)) < (FireRate and FireRate.Value or 0.05) then return end
		turretfiretime[turret] = now

		local fireId = httpService:GenerateGUID(false):sub(1, 8)
		local shotId = httpService:GenerateGUID(false):sub(1, 8)
		local targetChar = ent.Character
		local shootOrigin = turretPos + lookDir * 2 + Vector3.new(0, 1, 0)
		local velocity = lookDir * 300

		task.spawn(function()
			local firedId
			local myKit = lplr.Character and lplr.Character:GetAttribute('Kit')
			if PFR and myKit ~= 'block-kicker' then
				pcall(function()
					firedId = PFR:InvokeServer(
						turret, nil, "turretBullet",
						shootOrigin, turretPos, velocity,
						fireId,
						{ shotId = shotId, drawDurationSec = 0 },
						workspace:GetServerTimeNow() - 0.045 - 0.045
					)
				end)
			elseif RTR then
				pcall(function()
					local targetDir = (targetPos - turretPos).Unit * 500
					RTR:FireServer(turret, turretPos + Vector3.new(0, 1, 0), targetDir, blockPos)
				end)
			end

			if not firedId then
				turretTargets[turret] = nil
				return
			end

			task.wait(0.05)
			if not targetChar or not targetChar.Parent then return end
			if (targetChar:GetAttribute("Health") or 0) <= 0 then return end

			if PHR then
				pcall(function() PHR:FireServer(firedId, targetChar) end)
				task.wait(0.02)
				if targetChar and targetChar.Parent and (targetChar:GetAttribute("Health") or 0) > 0 then
					pcall(function() PHR:FireServer(firedId, targetChar) end)
				end
			end
		end)
	end

	local function startTurretLoop(turret)
		if turretthread[turret] then return end

		turretthread[turret] = task.spawn(function()
			while AutoVulcan.Enabled and turret and turret.Parent do
				if entitylib.isAlive then
					pcall(fireTurret, turret)
				end
				task.wait(0.05)
			end
			turretthread[turret] = nil
			turretTargets[turret] = nil
			turretfiretime[turret] = nil
		end)
	end

	local function stopAllLoops()
		for _, thread in pairs(turretthread) do
			pcall(task.cancel, thread)
		end
		table.clear(turretthread)
		table.clear(turretTargets)
		table.clear(turretfiretime)
		table.clear(turretBlockPosCache)
	end

	AutoVulcan = vape.Categories.Kits:CreateModule({
		Name = 'AutoVulcan',
		Function = function(callback)
			if callback then
				cleanThread(AutoVulcan, task.spawn(function()
					while AutoVulcan.Enabled do
						local turrets = getOwnedTurrets()
						for _, turret in ipairs(turrets) do
							startTurretLoop(turret)
						end
						for turret, thread in pairs(turretthread) do
							if not turret.Parent then
								pcall(task.cancel, thread)
								turretthread[turret] = nil
								turretTargets[turret] = nil
								turretfiretime[turret] = nil
							end
						end
						task.wait(1)
					end
				end))
				AutoVulcan:Clean(stopAllLoops)
			else
				stopAllLoops()
			end
		end,
	})

	Targets = AutoVulcan:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = false,
	})

	FireRate = AutoVulcan:CreateSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 3,
		Default = 0,
		Tooltip = 'Shots per second',
	})

	Distance = AutoVulcan:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 1000,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
	})

	Sort = AutoVulcan:CreateDropdown({
		Name = 'Target mode',
		List = getSortList({'Distance', 'Health', 'Cursor'}),
		Default = 'Distance',
	})

	LimitTablet = AutoVulcan:CreateToggle({
		Name = 'Limit to tablet',
		Default = false,
		Tooltip = 'only works when u holdin the tablet'
	})
end)
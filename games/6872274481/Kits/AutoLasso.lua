run(function()
	local AutoLasso
	local Targets
	local Range
	local Angle
	local LimitToLasso
	local ArrowCharge

	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		projectileRemote = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('ProjectileFire')
	end)
	local handGunRemote = {InvokeServer = function() end}
	task.spawn(function()
		handGunRemote = game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("HandGunFireRequest")
	end)

	local rayCheck = RaycastParams.new()
	local lastShot = 0
	local autoLassoLoop

	local function doLasso()
		if not entitylib.isAlive then return false end
		if LimitToLasso.Enabled then
			if not store.hand or not store.hand.tool or store.hand.tool.Name ~= 'lasso' then
				return false
			end
		end

		local lasso = getItem('lasso')
		if not lasso then return false end

		local ent = entitylib.EntityPosition({
			Range = Range.Value,
			Part = 'RootPart',
			Wallcheck = Targets.Walls.Enabled,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Sort = sortmethods.Distance
		})
		if not ent or not ent.RootPart then return false end

		local selfpos = entitylib.character.RootPart.Position
		local localfacing = gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
		local delta = (ent.RootPart.Position - selfpos) * Vector3.new(1, 0, 1)
		if delta.Magnitude <= 0.001 then return false end
		if math.acos(math.clamp(localfacing:Dot(delta.Unit), -1, 1)) > (math.rad(Angle.Value) / 2) then return false end
		local meta = bedwars.ProjectileMeta['lasso']
		local projSpeed = (meta and tonumber(meta.launchVelocity)) or 200
		local gravity = (meta and tonumber(meta.gravitationalAcceleration)) or 135
		local hip = ent.HipHeight or (ent.Humanoid and ent.Humanoid.HipHeight) or 2
		local leadPos = ent.RootPart.Position + Vector3.new(0, hip * 0.15, 0)
		local vel = ent.RootPart.AssemblyLinearVelocity or ent.RootPart.Velocity
		local calc = prediction.SolveTrajectory(selfpos, projSpeed, gravity, leadPos, vel, workspace.Gravity, hip, ent.Jumping and 42.6 or nil, rayCheck, nil, ent.RootPart.Position, ent.RootPart, nil, true)
		if not calc then return false end
		local originalSlot = store.inventory.hotbarSlot
		local lassoSlot
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType == 'lasso' then
				lassoSlot = i - 1
				break
			end
		end

		local swapped = false
		if lassoSlot and lassoSlot ~= originalSlot and not LimitToLasso.Enabled then
			hotbarSwitch(lassoSlot)
			task.wait(0.03)
			swapped = true
		end

		local res = projectileRemote:InvokeServer(
			lasso.tool,
			'lasso',
			'lasso',
			selfpos,
			selfpos,
			CFrame.lookAt(selfpos, calc).LookVector * projSpeed,
			httpService:GenerateGUID(true),
			{
				drawDurationSeconds = 1,
				shotId = httpService:GenerateGUID(false)
			},
			workspace:GetServerTimeNow() - 0.045
		)

		if swapped then
			hotbarSwitch(originalSlot)
		end

		return res and true or false
	end

	local function startAutoLassoLoop()
		if autoLassoLoop then return end
		autoLassoLoop = task.spawn(function()
			while AutoLasso and AutoLasso.Enabled do
				local ok, fired = pcall(doLasso)
				task.wait((ok and fired) and 0.5 or 0.1)
			end
			autoLassoLoop = nil
		end)
	end

	local function stopAutoLassoLoop()
		if autoLassoLoop then
			task.cancel(autoLassoLoop)
			autoLassoLoop = nil
		end
	end

	AutoLasso = vape.Categories.Kits:CreateModule({
		Name = 'AutoLasso',
		Function = function(callback)
			if callback then
				startAutoLassoLoop()
			else
				stopAutoLassoLoop()
			end
		end
	})

	Targets = AutoLasso:CreateTargets({Players = true})
	Range = AutoLasso:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 60,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Angle = AutoLasso:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 120
	})
	LimitToLasso = AutoLasso:CreateToggle({
		Name = 'Limit to Lasso',
		Default = false,
	})
end)
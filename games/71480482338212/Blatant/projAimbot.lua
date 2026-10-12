run(function()
	local ProjectileAimbot
	local Targets
	local Sort
	local TargetPart
	local FOV
	local Range
	local Horizontal
	local Vertical
	local AutoCharge
	local OtherProjectiles
	local Blacklist
	local ring
	local old, wrapper
	local oldFire, fireWrapper

	-- bows and crossbows always, the rest only when asked for and not on the blacklist
	local function wanted(name)
		for _, v in Blacklist.ListEnabled do
			if v:lower() == name:lower() then
				return false
			end
		end
		return OtherProjectiles.Enabled or name == 'Bow' or name == 'Crossbow'
	end

	local function solve(self, root, projData)
		if not (entitylib.isAlive and projData and projData.Speed and self.Charge and wanted(self.Name)) then return end
		local origin = bedfight.Ranged.GetFireOrigin(root, self.Data.Offset)
		local ent = store.targets({
			Origin = origin,
			Range = Range.Value,
			FOV = FOV.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Walls = Targets.Walls.Enabled,
			Sort = Sort.Value
		})[1]
		if not ent then return end

		-- a full draw flies at the top of the weapon's speed range
		local charge = AutoCharge.Enabled and 1 or self.Charge.Value
		local speed = math.map(charge, 0, 1, projData.Speed.Min, projData.Speed.Max)
		local part = ent[TargetPart.Value] or ent.RootPart
		local scale = {Horizontal = Horizontal.Value, Vertical = Vertical.Value}
		local point = store.aimPoint(origin, speed, math.abs(projData.Gravity.Y), ent, part, scale)
		if not point or (point - origin).Magnitude < 0.1 then return end
		-- firing turns the camera onto the shot, which moves the point it leaves from a little
		origin = root.Position + CFrame.lookAlong(gameCamera.CFrame.Position, (point - origin).Unit):VectorToWorldSpace(self.Data.Offset)
		point = store.aimPoint(origin, speed, math.abs(projData.Gravity.Y), ent, part, scale)
		if not point or (point - origin).Magnitude < 0.1 then return end
		targetinfo.Targets[ent] = tick() + 1
		return (point - origin).Unit * speed
	end

	ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		Function = function(callback)
			ring.Update(callback)
			if callback then
				if wrapper then return end
				old = bedfight.Ranged.UpdateBeam
				-- the game aims from the cursor here every frame while a shot is drawn
				wrapper = function(self, root, projData, ...)
					local data = self.TrajectoryData
					-- a failed solve must never stop the game drawing its own line
					local ok, velocity = pcall(function()
						return ProjectileAimbot.Enabled and data and solve(self, root, projData)
					end)
					if not (ok and velocity) then
						if data then
							rawset(data, 'Aimed', nil)
						end
						return old(self, root, projData, ...)
					end

					-- the game sets the cursor's direction and then draws, so the bent shot is put in between
					local curve = data.CurveBeam
					rawset(data, 'CurveBeam', function(traj, ...)
						traj.Velocity = velocity
						return curve(traj, ...)
					end)
					local results = table.pack(pcall(old, self, root, projData, ...))
					rawset(data, 'CurveBeam', nil)
					if not results[1] then
						error(results[2], 0)
					end
					data.Velocity = velocity
					rawset(data, 'Aimed', velocity)
					return table.unpack(results, 2, results.n)
				end
				bedfight.Ranged.UpdateBeam = wrapper

				oldFire = bedfight.Ranged.Fire
				-- the shot leaves from a point that turns with the camera, and the camera is sent along with it.
				-- so for the instant of firing the camera looks where the shot goes
				fireWrapper = function(self, ...)
					local data = self.TrajectoryData
					local velocity = ProjectileAimbot.Enabled and self.Activated and data and data.Aimed
					if not velocity then
						return oldFire(self, ...)
					end
					local real = gameCamera.CFrame
					gameCamera.CFrame = CFrame.lookAlong(real.Position, velocity.Unit)
					local results = table.pack(pcall(oldFire, self, ...))
					gameCamera.CFrame = real
					if not results[1] then
						error(results[2], 0)
					end
					return table.unpack(results, 2, results.n)
				end
				bedfight.Ranged.Fire = fireWrapper
			else
				if wrapper and bedfight.Ranged.UpdateBeam == wrapper then
					bedfight.Ranged.UpdateBeam = old
					old, wrapper = nil, nil
				end
				if fireWrapper and bedfight.Ranged.Fire == fireWrapper then
					bedfight.Ranged.Fire = oldFire
					oldFire, fireWrapper = nil, nil
				end
			end
		end,
		Tooltip = 'Bends your bow, crossbow and fireball shots onto a player inside the FOV.\nThe aim line shows where the shot will really go.'
	})
	Targets = ProjectileAimbot:CreateTargets({
		Players = true,
		Walls = true
	})
	Sort = ProjectileAimbot:CreateDropdown({
		Name = 'Target mode',
		List = store.sortList,
		Default = 'Cursor',
		Tooltip = 'Distance - the nearest\nCursor - nearest your cursor on screen\nAngle - nearest to where your camera looks\nLowest Health / Highest Health'
	})
	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = ProjectileAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 250,
		Tooltip = 'How far from your cursor a player can be, in pixels'
	})
	Range = ProjectileAimbot:CreateSlider({
		Name = 'Range',
		Min = 30,
		Max = 500,
		Default = 500,
		Suffix = 'studs',
		Tooltip = 'Only targets players within this distance'
	})
	ring = store.ring(ProjectileAimbot, 'BFPAFOVCircle', 'Draws the range a target is caught at, centred on the cursor')
	ring.Radius = function()
		return FOV.Value
	end
	Horizontal = ProjectileAimbot:CreateSlider({
		Name = 'Horizontal prediction',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 100,
		Tooltip = 'Scales how far ahead of the target you aim sideways'
	})
	Vertical = ProjectileAimbot:CreateSlider({
		Name = 'Vertical prediction',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 100,
		Tooltip = 'Scales how far ahead of the target you aim while it rises or falls'
	})
	AutoCharge = ProjectileAimbot:CreateToggle({
		Name = 'Auto Charge',
		Tooltip = 'Aims and fires a bow at its full speed however long you drew it.\nWhether the server accepts a full speed shot from a short draw has not been checked'
	})
	OtherProjectiles = ProjectileAimbot:CreateToggle({
		Name = 'Other Projectiles',
		Default = true,
		Function = function(callback)
			if Blacklist then
				Blacklist.Object.Visible = callback
			end
		end,
		Tooltip = 'Also bends fireballs, hotdogs and anything else that is not a bow or a crossbow'
	})
	Blacklist = ProjectileAimbot:CreateTextList({
		Name = 'Blacklist',
		Darker = true,
		Default = {'Teleorb'},
		Placeholder = 'weapon name',
		Tooltip = 'Weapons that are never bent'
	})
end)

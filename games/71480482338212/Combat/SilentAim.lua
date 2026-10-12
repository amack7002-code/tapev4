run(function()
	local SilentAim
	local Targets
	local TargetPart
	local Sort
	local Prediction
	local FOV
	local Range
	local HeadChance
	local TorsoChance
	local OtherProjectiles
	local Blacklist
	local AutoCharge
	local ChargePercent
	local Debug
	local ring
	local oldFire, wrapper
	local rng = Random.new()
	-- the game's own Fire, before any module wraps it. it reaches the remote through one of its upvalues
	local gameFire = bedfight.Ranged.Fire
	local slot

	local function upvalues(fn)
		if debug.getupvalues then
			local ok, list = pcall(debug.getupvalues, fn)
			if ok and type(list) == 'table' then
				return list
			end
		end
		local list = {}
		for i = 1, 40 do
			local ok, value = pcall(debug.getupvalue, fn, i)
			if not ok then break end
			list[i] = value
		end
		return list
	end

	-- the slot is found by what it holds. a Fire that something already wrapped is looked through
	local function findSlot(fn, depth)
		local folder = remotes.ShootProjectile and remotes.ShootProjectile.Parent
		if not (folder and debug.setupvalue and debug.getupvalue and type(fn) == 'function') then return nil end
		local list = upvalues(fn)
		for i, v in list do
			if v == folder then
				gameFire = fn
				return i
			end
		end
		if depth < 3 then
			for _, v in list do
				if type(v) == 'function' then
					local found = findSlot(v, depth + 1)
					if found then
						return found
					end
				end
			end
		end
		return nil
	end

	local function report(text)
		if Debug.Enabled then
			notif('SilentAim', text, 4)
		end
	end

	local function wanted(name)
		if name == 'Bow' or name == 'Crossbow' then return true end
		if not OtherProjectiles.Enabled then return false end
		for _, v in Blacklist.ListEnabled do
			if v:lower() == name:lower() then
				return false
			end
		end
		return true
	end

	local function pickPart(ent)
		local mode = TargetPart.Value
		if mode == 'Head' then
			return ent.Head or ent.RootPart
		elseif mode == 'Closest' then
			-- whichever of the two is nearer your cursor
			local fov = vape.Libraries.fovcircle
			local head = ent.Head
			if fov and head then
				local _, toHead = fov.ContainsPoint(head.Position, math.huge)
				local _, toRoot = fov.ContainsPoint(ent.RootPart.Position, math.huge)
				return toHead < toRoot and head or ent.RootPart
			end
		elseif mode == 'Randomize' then
			local roll = rng:NextNumber(0, 100)
			if roll < HeadChance.Value then
				return ent.Head or ent.RootPart
			elseif roll < HeadChance.Value + TorsoChance.Value then
				return ent.Character:FindFirstChild('UpperTorso') or ent.RootPart
			end
		end
		return ent.RootPart
	end

	-- what the server is told instead: a shot from the same place that meets the target
	local function plan(self)
		local data = self.TrajectoryData
		if not (entitylib.isAlive and self.Activated and data and data.Velocity) then return nil end
		if rawget(data, 'Aimed') then return nil end
		if not wanted(self.Name) then
			report(self.Name..' is not a weapon SilentAim bends')
			return nil
		end
		local meta = bedfight.ProjectilesData[data.ProjectileName] or data.ProjectileData
		if not (meta and meta.Speed and meta.Gravity) then return nil end

		-- the server launches from the root it follows
		local root = realRoot()
		local offset = self.Data.Offset
		local eye = gameCamera.CFrame.Position
		local origin = root.Position + gameCamera.CFrame:VectorToWorldSpace(offset)
		local ent = store.targets({
			Origin = origin,
			Range = Range.Value,
			FOV = FOV.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Walls = Targets.Walls.Enabled,
			Sort = Sort.Value
		})[1]
		if not ent then
			report('Nobody inside the FOV, the shot went where you aimed')
			return nil
		end

		local speed = data.Velocity.Magnitude
		if AutoCharge.Enabled then
			local range = self.Data.ChargeRange
			local charge = math.clamp(ChargePercent.Value / 100, range and range.Min or 0, range and range.Max or 1)
			speed = math.map(charge, 0, 1, meta.Speed.Min, meta.Speed.Max)
		end
		if speed < 1 then return nil end

		local part = pickPart(ent)
		local gravity = math.abs(meta.Gravity.Y)
		local scale = {Horizontal = Prediction.Value, Vertical = Prediction.Value}
		local point = store.aimPoint(origin, speed, gravity, ent, part, scale)
		if not point or (point - origin).Magnitude < 0.1 then return nil end
		-- the camera is sent along and the shot leaves from a point that turns with it
		origin = root.Position + CFrame.lookAlong(eye, (point - origin).Unit):VectorToWorldSpace(offset)
		point = store.aimPoint(origin, speed, gravity, ent, part, scale)
		if not point or (point - origin).Magnitude < 0.1 then return nil end

		local velocity = (point - origin).Unit * speed
		targetinfo.Targets[ent] = tick() + 1
		report('Sent to '..(ent.Player and ent.Player.Name or ent.Character.Name)..' ('..part.Name..', '..math.floor((point - origin).Magnitude)..' studs)')
		return velocity, CFrame.lookAlong(eye, velocity.Unit)
	end

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			ring.Update(callback)
			if callback then
				slot = slot or findSlot(gameFire, 0)
				if not slot then
					notif('SilentAim', 'Your executor cannot reach the game\'s shoot call (no debug.setupvalue), so SilentAim cannot work here. ProjectileAimbot still does.', 10, 'alert')
					task.defer(function()
						if SilentAim.Enabled then
							SilentAim:Toggle()
						end
					end)
					return
				end
				if wrapper then return end
				oldFire = bedfight.Ranged.Fire
				wrapper = function(self, ...)
					local ok, velocity, camera
					if SilentAim.Enabled then
						ok, velocity, camera = pcall(plan, self)
					end
					if not (ok and velocity) then
						return oldFire(self, ...)
					end

					-- only the values in the request change. the arrow on your screen flies where you aimed
					local folder = remotes.ShootProjectile.Parent
					local shoot = remotes.ShootProjectile
					local restored = false
					local function restore()
						if not restored then
							restored = true
							debug.setupvalue(gameFire, slot, folder)
						end
					end
					debug.setupvalue(gameFire, slot, setmetatable({
						ShootProjectile = {
							FireServer = function(_, id, name)
								restore()
								shoot:FireServer(id, name, velocity.Unit, velocity, camera)
							end
						}
					}, {
						__index = function(_, key)
							return folder[key]
						end
					}))
					local results = table.pack(pcall(oldFire, self, ...))
					restore()
					if not results[1] then
						error(results[2], 0)
					end
					return table.unpack(results, 2, results.n)
				end
				bedfight.Ranged.Fire = wrapper
			elseif wrapper and bedfight.Ranged.Fire == wrapper then
				bedfight.Ranged.Fire = oldFire
				oldFire, wrapper = nil, nil
			end
		end,
		Tooltip = 'Redirects only the shot values sent to the server, so enemies get hit while your shot flies exactly where you aimed on your own screen'
	})
	Targets = SilentAim:CreateTargets({
		Players = true,
		Walls = true
	})
	TargetPart = SilentAim:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head', 'Closest', 'Randomize'},
		Default = 'RootPart',
		Tooltip = 'Where on the body the shot is aimed\nClosest - the head or the body, whichever is nearer your cursor\nRandomize - picked per shot from the chances below'
	})
	HeadChance = SilentAim:CreateSlider({
		Name = 'Head Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Suffix = '%',
		Darker = true,
		Visible = function()
			return TargetPart.Value == 'Randomize'
		end
	})
	TorsoChance = SilentAim:CreateSlider({
		Name = 'Torso Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Suffix = '%',
		Darker = true,
		Visible = function()
			return TargetPart.Value == 'Randomize'
		end,
		Tooltip = 'What is left after the head and the torso goes to the root part'
	})
	Sort = SilentAim:CreateDropdown({
		Name = 'Sort Method',
		List = store.sortList,
		Default = 'Cursor',
		Tooltip = 'Distance - the nearest\nCursor - nearest your cursor on screen\nAngle - nearest to where your camera looks\nLowest Health / Highest Health'
	})
	Prediction = SilentAim:CreateSlider({
		Name = 'Prediction',
		Min = 0.1,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Tooltip = 'Scales how far ahead of a moving target the shot is sent'
	})
	FOV = SilentAim:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 300,
		Tooltip = 'How far from your cursor a player can be, in pixels'
	})
	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 30,
		Max = 500,
		Default = 500,
		Suffix = 'studs',
		Tooltip = 'Only targets players within this distance'
	})
	ring = store.ring(SilentAim, 'BFSAFOVCircle', 'Draws the range a target is caught at, centred on the cursor')
	ring.Radius = function()
		return FOV.Value
	end
	OtherProjectiles = SilentAim:CreateToggle({
		Name = 'Other Projectiles',
		Default = true,
		Function = function(callback)
			if Blacklist then
				Blacklist.Object.Visible = callback
			end
		end,
		Tooltip = 'Also redirects fireballs, hotdogs and anything else that is not a bow or a crossbow'
	})
	Blacklist = SilentAim:CreateTextList({
		Name = 'Blacklist',
		Darker = true,
		Default = {'Teleorb'},
		Placeholder = 'weapon name'
	})
	AutoCharge = SilentAim:CreateToggle({
		Name = 'AutoCharge',
		Function = function(callback)
			if ChargePercent then
				ChargePercent.Object.Visible = callback
			end
		end,
		Tooltip = 'Sends the shot at the charge below however long you drew it.\nWhether the server accepts a stronger shot than you drew has not been checked'
	})
	ChargePercent = SilentAim:CreateSlider({
		Name = 'Charge Percent',
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%',
		Darker = true,
		Visible = false
	})
	Debug = SilentAim:CreateToggle({
		Name = 'Debug',
		Tooltip = 'Reports what each shot did - which target it was sent to, or why it was left alone'
	})
end)

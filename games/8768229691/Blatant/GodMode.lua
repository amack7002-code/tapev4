run(function()
	local GodMode
	local Range
	local Safe
	local Dodge
	local idleSince = 0
	local dodgeUntil = 0

	local function threats(origin)
		local list = {}
		for _, ent in entitylib.List do
			if ent.Targetable and ent.RootPart and ent.RootPart.Parent and ent.Health > 0 and not fallen(ent) then
				local distance = (ent.RootPart.Position - origin).Magnitude
				if distance <= Range.Value then
					table.insert(list, {Entity = ent, Distance = distance})
				end
			end
		end
		table.sort(list, function(a, b)
			return a.Distance < b.Distance
		end)
		return list
	end

	-- over the closest enemy, raised until nobody is nearer than the safe distance
	local function safeSpot(list)
		local goal = attachPosition(list[1].Entity, Safe.Value)
		for _ = 1, 4 do
			local lift = 0
			for _, threat in list do
				local position = threat.Entity.RootPart.Position
				local delta = goal - position
				if delta.Magnitude < Safe.Value - 0.25 then
					local flat = Vector3.new(delta.X, 0, delta.Z).Magnitude
					local need = math.sqrt(math.max(Safe.Value ^ 2 - flat ^ 2, 0))
					lift = math.max(lift, position.Y + need - goal.Y)
				end
			end
			if lift <= 0 then break end
			goal += Vector3.new(0, lift, 0)
		end
		return goal
	end

	local function release()
		if store.godMode then
			store.attached = nil
		end
		store.godMode = nil
		mergeRoot('GodMode')
	end

	-- lifts the root out of the way of a shot that would pass close to it
	local function projectile(shooter, kind, origin, direction, speed)
		if not (Dodge.Enabled and entitylib.isAlive) then return end
		if not (typeof(shooter) == 'Instance' and shooter:IsA('Player') and shooter ~= lplr) then return end
		if not (type(kind) == 'string' and typeof(origin) == 'Vector3' and typeof(direction) == 'Vector3' and type(speed) == 'number') then return end
		if shooter:GetAttribute('TeamId') ~= nil and shooter:GetAttribute('TeamId') == lplr:GetAttribute('TeamId') then return end
		local meta = skywars.ItemMeta[kind]
		local acceleration = meta and meta.Projectile and meta.Projectile.Acceleration or Vector3.new(0, skywars.Gravity, 0)
		local velocity = direction.Unit * speed
		local mine = realRoot().Position
		for step = 1, 50 do
			local t = step * 0.05
			if (origin + velocity * t + acceleration * (t * t / 2) - mine).Magnitude < 10 then
				dodgeUntil = math.max(dodgeUntil, tick() + t + 0.5)
				return
			end
		end
	end

	GodMode = vape.Categories.Blatant:CreateModule({
		Name = 'GodMode',
		Function = function(callback)
			if callback then
				for _, id in (remotes.projectileEvents or {}) do
					local event = skywars.Remotes[id]
					if event then
						GodMode:Clean(event:connect(projectile))
					end
				end
				GodMode:Clean(runService.Heartbeat:Connect(function()
					if not entitylib.isAlive or outranked('godMode') then
						release()
						return
					end
					local body = bodyRoot().Position
					local list = threats(body)
					local dodging = dodgeUntil > tick()
					if #list == 0 and not dodging then
						if store.godMode then
							store.attached = nil
						end
						store.godMode = nil
						if tick() - idleSince > 1 then
							mergeRoot('GodMode')
						end
						return
					end

					if not splitRoot('GodMode') then return end
					store.godMode = true
					store.attached = list[1] and list[1].Entity or nil
					idleSince = tick()
					local goal = #list > 0 and safeSpot(list) or body
					if dodging then
						goal += Vector3.new(0, 40, 0)
					end
					sendRoot(goal)
				end))
			else
				release()
			end
		end,
		Tooltip = 'Keeps the hitbox the server uses out of every enemy\'s reach while they are close.\nYour character and camera stay where you put them, only on your screen.'
	})
	Range = GodMode:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 60,
		Default = 22,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How close an enemy has to come before your hitbox leaves the ground'
	})
	Safe = GodMode:CreateSlider({
		Name = 'Distance',
		Min = 14,
		Max = 25,
		Default = 15,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far your hitbox stays from every enemy. They reach 13.5 studs, your own hits land from up to 17.'
	})
	Dodge = GodMode:CreateToggle({
		Name = 'Dodge projectiles',
		Default = true,
		Tooltip = 'Lifts your hitbox another 40 studs when a shot is heading for it'
	})
end)

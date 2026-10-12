run(function()
	local InfiniteFly
	local Value
	local Vertical
	local Safe
	local Leash
	local Notify
	local state
	local landing = false
	local active = false
	local filtered
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	-- measured 2026-10-12 with the root hidden. along the ground at 22 studs a second it went 50 seconds
	-- and 1,089 studs without the server stepping in; at 30 it was pulled back after 31 seconds.
	-- one jump of 100 studs in a third of a second is let through when the root stood still for two
	-- seconds before and after it. a second jump sooner, or one that takes longer than 0.4s, is put back.
	-- 128 studs at 450 a second got through three times out of three after six seconds of standing,
	-- and failed straight after other jumps
	local WALK = 22
	local HOP, HOP_SPEED, REST = 100, 300, 2
	local FAR, FAR_SPEED, FAR_REST = 136, 450, 6
	-- with Safe on, how far from the root a landing may be: one of the jumps that went through 16 times out of 17
	local SAFE = HOP - 4
	-- coming down more than 20 studs costs health
	local FREE_DROP = 18
	local STEP_UP = 4
	-- standing on the last three studs of the lobby's stone ledge got the root taken and dropped
	local EDGE = 3
	local SIDES = {Vector3.zero, Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1)}

	local function tell(text, kind)
		if Notify.Enabled then
			notif('InfiniteFly', text, 6, kind)
		end
	end

	-- the longest jump the root may try
	local function furthest()
		return Safe.Enabled and HOP or FAR
	end

	local function aim()
		local container = workspace:FindFirstChild('PlayersContainer') or lplr.Character
		if filtered ~= container then
			filtered = container
			rayCheck.FilterDescendantsInstances = {container, gameCamera}
		end
	end

	local function floor(position, depth)
		return workspace:Raycast(position, Vector3.new(0, -depth, 0), rayCheck)
	end

	-- the ground one step ahead, when the root can simply walk onto it. it goes through walls,
	-- up a block and down any drop that is free
	local function walkable(st, point)
		local feet = st.Root.Position.Y - st.Hip
		local hit = floor(Vector3.new(point.X, feet + STEP_UP, point.Z), STEP_UP + FREE_DROP)
		if not hit or hit.Instance.Transparency >= 1 then return nil end
		return hit.Position.Y + st.Hip
	end

	-- real ground under a point, looked for from a height. invisible walls and thin edges do not count
	local function ground(point, top, depth)
		local y
		for i, side in SIDES do
			local hit = floor(Vector3.new(point.X, top, point.Z) + side, depth)
			if not hit or hit.Instance.Transparency >= 1 then return nil end
			if i == 1 then
				y = hit.Position.Y
			elseif math.abs(hit.Position.Y - y) > 3 then
				return nil
			end
		end
		return y
	end

	-- where the root could stand at a point and get to in one jump
	local function standing(point, st, bodyY, final)
		local from = st.Root.Position
		-- the highest ground under your flight, or failing that the ground on the root's own level
		for _, top in {math.max(from.Y, bodyY) + 6, from.Y + 6} do
			local y = ground(point, top, top - from.Y + st.Hip + (final and 4 * FREE_DROP or FREE_DROP) + 1)
			if y then
				local spot = Vector3.new(point.X, y + st.Hip, point.Z)
				if (spot - from).Magnitude <= furthest() + 0.5 then
					return spot
				end
			end
		end
		return nil
	end

	-- a long jump needs a longer stand first. true once the root is on its way
	local function hop(st, to, final, now)
		local from = st.Root.Position
		local length = (to - from).Magnitude
		local far = length > HOP + 0.5
		if now - st.Still < (far and FAR_REST or REST) then return false end
		st.Leg = {From = from, To = to, Time = math.max(length, 25) / (far and FAR_SPEED or HOP_SPEED), Alpha = 0, Final = final}
		st.Still, st.Blocked = nil, nil
		return true
	end

	-- moves the root one frame towards the target: a step along the ground, a frame of a jump, or a wait
	local function advance(st, dt, target, final)
		local real = realRoot()
		local now = tick()
		if not isnetworkowner(real) then
			-- the server has it. whatever it does with it, carry on from there afterwards
			st.HeldAt = st.HeldAt or now
			st.Leg = nil
			return
		elseif st.HeldAt then
			st.HeldAt = nil
			st.Root = CFrame.new(real.Position) * st.Root.Rotation
			st.Still = now
			st.Pulls = (st.Pulls or 0) + 1
			tell('The server moved your hitbox back. It carries on from there.', 'warning')
		end

		local leg = st.Leg
		if leg then
			leg.Alpha = math.min(leg.Alpha + dt / leg.Time, 1)
			st.Root = CFrame.new(leg.From:Lerp(leg.To, leg.Alpha)) * st.Root.Rotation
			if leg.Alpha >= 1 then
				st.Leg = nil
				st.Arrived = leg.Final or nil
				st.Still = now
				st.RestUntil = now + REST
			end
			return
		end

		local from = st.Root.Position
		local offset = target - from
		local flat = offset * Vector3.new(1, 0, 1)
		local distance = flat.Magnitude
		if final and offset.Magnitude < 0.5 then
			st.Arrived = true
			return
		end
		if now < (st.RestUntil or 0) then return end
		aim()

		if distance > (final and 0.05 or 2) then
			local unit = flat.Unit
			local step = math.min(WALK * dt, distance)
			local point = from + unit * step
			local y
			if final and step >= distance - 0.01 and math.abs(target.Y - from.Y) <= STEP_UP then
				y = target.Y
			elseif (final and distance <= EDGE) or walkable(st, point + unit * EDGE) then
				-- it stops short of an edge it is walking towards
				y = walkable(st, point)
			end
			if y then
				st.Root = CFrame.new(point.X, y, point.Z) * st.Root.Rotation
				st.Still, st.Blocked = nil, nil
				return
			end
		elseif not final then
			-- under you
			st.Still = st.Still or now
			st.Blocked = nil
			return
		end

		-- nothing to walk on ahead: a gap, a drop, or the landing spot is on another level
		st.Still = st.Still or now
		st.Blocked = st.Blocked or now
		if now - st.Still < REST or now - (st.Thought or 0) < 0.3 then return end
		st.Thought = now
		if final and offset.Magnitude <= furthest() + 0.5 then
			hop(st, target, true, now)
			return
		end
		if distance > 1 then
			-- as far across as one jump goes and the ground lets it
			local unit = flat.Unit
			local length = math.min(distance, furthest())
			while length >= 5 do
				local spot = standing(from + unit * length, st, target.Y, final)
				if spot then
					hop(st, spot, false, now)
					return
				end
				length -= 5
			end
		end
		if final and now - st.Blocked > (Safe.Enabled and REST or FAR_REST) + 1.5 then
			st.Failed = true
		end
	end

	-- how far off the next ground on the way to you is, for the notice
	local function gap(st, target)
		local from = st.Root.Position
		local flat = (target - from) * Vector3.new(1, 0, 1)
		if flat.Magnitude < 1 then return nil end
		aim()
		local top = math.max(from.Y, target.Y) + 6
		for length = 10, math.min(flat.Magnitude, 600), 5 do
			if ground(from + flat.Unit * length, top, top - from.Y + 400) then
				return length
			end
		end
		return nil
	end

	-- the body waits where you want to be while the root finishes its way there
	local function land(st)
		landing = true
		aim()
		local body = bodyRoot()
		local under = floor(body.Position, 700)
		local goal
		if under then
			goal = Vector3.new(body.Position.X, under.Position.Y + st.Hip, body.Position.Z)
			if st.Root.Position.Y - goal.Y > FREE_DROP + 2 then
				tell(string.format('Landing %d studs lower than your hitbox stands. The server counts that as a fall.', st.Root.Position.Y - goal.Y), 'warning')
			end
		else
			goal = st.Root.Position
			tell('Nothing to land on under you, so you are back where your hitbox stands.', 'warning')
		end
		local away = ((goal - st.Root.Position) * Vector3.new(1, 0, 1)).Magnitude
		if away > WALK * 3 then
			tell(string.format('Your hitbox is still on its way, about %d seconds.', away / WALK + 1))
		end

		local hover = CFrame.new(goal) * body.CFrame.Rotation
		local done, standUntil, back = false, nil, false
		local started = tick()
		st.Landing = true
		st.Blocked = nil
		local conn
		conn = runService.Heartbeat:Connect(function(dt)
			if not (entitylib.isAlive and store.split) then
				done = true
				return
			end
			local clone = bodyRoot()
			clone.CFrame = hover
			clone.AssemblyLinearVelocity = Vector3.zero
			store.antiHitAt = tick()
			advance(st, dt, goal, true)
			sendRoot(st.Root)
			if st.Arrived and not st.Leg then
				-- stands there for a moment before the two are one again
				standUntil = standUntil or tick() + 0.3
				if tick() >= standUntil then
					done = true
				end
			elseif st.Failed then
				local wide = gap(st, goal)
				tell(wide and string.format('The next ground on the way is %d studs off and the hitbox can only jump %d, so you are back where it stands.', wide, furthest()) or 'The hitbox has no way to that spot, so you are back where it stands.', 'warning')
				done, back = true, true
			elseif (st.HeldAt and tick() - st.HeldAt > 8) or (st.Pulls or 0) >= 3 or tick() - started > 90 then
				tell('The server keeps hold of your hitbox, so you are back where it stands.', 'warning')
				done, back = true, true
			end
		end)
		repeat task.wait() until done
		conn:Disconnect()
		if back and store.split and entitylib.isAlive then
			-- you go to the hitbox. the hitbox is never thrown across to you
			local real = realRoot()
			local clone = bodyRoot()
			clone.CFrame = isnetworkowner(real) and st.Root or real.CFrame
			clone.AssemblyLinearVelocity = Vector3.zero
		end
		mergeRoot('InfiniteFly')
		store.flyOn = nil
		active = false
		landing = false
		state = nil
	end

	InfiniteFly = vape.Categories.Blatant:CreateModule({
		Name = 'InfiniteFly',
		Function = function(callback)
			if callback then
				if landing or not entitylib.isAlive or store.flyOn or store.dashOn then
					task.defer(function()
						if InfiniteFly.Enabled then
							InfiniteFly:Toggle()
						end
					end)
					return
				end
				aim()
				local body = bodyRoot()
				local hip = entitylib.character.HipHeight
				local under = floor(body.Position, FREE_DROP + hip + 2)
				local real = under and splitRoot('InfiniteFly')
				if not real then
					tell(under and 'Could not take off right now.' or 'Take off from the ground, or from less than 18 studs above it.', 'warning')
					task.defer(function()
						if InfiniteFly.Enabled then
							InfiniteFly:Toggle()
						end
					end)
					return
				end

				-- the server only ever sees the root on the ground. where you fly is up to you
				local st = {
					Root = CFrame.new(body.Position.X, under.Position.Y + hip, body.Position.Z) * body.CFrame.Rotation,
					Hip = hip,
					Still = tick()
				}
				state = st
				store.flyOn = true
				active = true
				InfiniteFly:Clean(runService.PreSimulation:Connect(function(dt)
					if not (entitylib.isAlive and store.split) then
						if state == st then
							state = nil
						end
						InfiniteFly:Toggle()
						return
					end
					-- Prevent lagback and AntiHit leave the root alone while this is fresh
					store.antiHitAt = tick()
					local hum, clone = entitylib.character.Humanoid, bodyRoot()
					advance(st, dt, clone.Position, false)
					sendRoot(st.Root)
					if not st.Blocked then
						st.Told = nil
					elseif not st.Told and tick() - st.Blocked > 4 then
						st.Told = true
						local wide = gap(st, clone.Position)
						tell(wide and wide > furthest() and string.format('Your hitbox waits at an edge. The next ground on your way is %d studs off and it can only jump %d, so land on this side.', wide, furthest()) or 'Your hitbox waits at an edge until there is ground under your way again.', 'warning')
					end

					local vertical = 0
					if not inputService:GetFocusedTextBox() then
						vertical = (inputService:IsKeyDown(Enum.KeyCode.Space) and Vertical.Value or 0) - (inputService:IsKeyDown(Enum.KeyCode.LeftShift) and Vertical.Value or 0)
					end
					local move = hum.MoveDirection * Value.Value
					-- how fast you may still move away from the hitbox. it eases off, so nothing stutters at a limit
					local ahead = (clone.Position - st.Root.Position) * Vector3.new(1, 0, 1)
					local gone = ahead.Magnitude
					if gone > 0.1 then
						local out = ahead.Unit
						local along = move:Dot(out)
						local pace = math.huge
						if Leash.Value < 500 then
							-- down to the hitbox's own pace at the leash, so a landing never waits long
							pace = WALK * 0.95 + math.max(Leash.Value - gone, 0) * 4
						end
						if Safe.Enabled then
							-- and to a stop one sure jump out, measured to where you would land
							aim()
							local below = floor(clone.Position, 500)
							local level = below and below.Position.Y + st.Hip - st.Root.Position.Y or 0
							local room = math.sqrt(math.max(SAFE * SAFE - level * level, 0)) - gone
							local safe = math.max(room, 0) * 4
							if safe < pace then
								pace = safe
								if room < 3 and along > pace then
									local now = tick()
									st.Capped = now
									st.CappedSince = st.CappedSince or now
									if not st.SafeTold and now - st.CappedSince > 1.5 then
										st.SafeTold = true
										tell(string.format('Safe keeps you within one %d stud jump of your hitbox. Wait for it to catch up, or switch Safe off to fly further ahead.', HOP))
									end
								else
									st.CappedSince = nil
								end
							else
								st.CappedSince = nil
							end
						end
						if along > pace then
							move -= out * (along - pace)
						end
					end
					-- half a frame of gravity keeps the hover level
					clone.AssemblyLinearVelocity = Vector3.new(move.X, vertical + workspace.Gravity * dt / 2, move.Z)
				end))
			else
				local st = state
				if st and not st.Landing and store.split and entitylib.isAlive then
					task.spawn(land, st)
				elseif active and not landing then
					mergeRoot('InfiniteFly')
					store.flyOn = nil
					active = false
					state = nil
				end
			end
		end,
		ExtraText = function()
			local st = state
			if not (st and store.split and entitylib.isAlive) then return '' end
			local behind = ((bodyRoot().Position - st.Root.Position) * Vector3.new(1, 0, 1)).Magnitude
			if st.Landing then
				return string.format('landing %ds', behind / WALK + 1)
			end
			if st.Capped and tick() - st.Capped < 0.3 then
				return string.format('%d behind, safe limit', behind)
			end
			return string.format(st.Blocked and '%d behind, waiting' or '%d behind', behind)
		end,
		Tooltip = 'Flies for as long as you like, with Space and Shift for up and down.\nYour hitbox follows on the ground below at 22 studs a second, the fastest the server lets a character go for long,\nand jumps a gap once there is ground on your way again: up to 100 studs after standing for two seconds, and with Safe off up to 136 after six.\nSwitch it off over ground to land. A landing waits until the hitbox is there.\nWhile you fly, players can hit you where the hitbox is, and you cannot hit, mine or pick anything up.'
	})
	Value = InfiniteFly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 40,
		Suffix = 'studs',
		Tooltip = 'How fast you fly. The hitbox follows at 22, so anything faster only gets you as far ahead as the leash.'
	})
	Vertical = InfiniteFly:CreateSlider({
		Name = 'Vertical speed',
		Min = 1,
		Max = 150,
		Default = 40,
		Suffix = 'studs'
	})
	Safe = InfiniteFly:CreateToggle({
		Name = 'Safe',
		Tooltip = 'Keeps to what the server let through 16 times out of 17. You cannot get further from your hitbox than one 100 stud jump, measured to where you would land,\nand the hitbox does not try the longer jump of up to 136 studs, which was put back two times in five in the lobby.\nWith it on, a gap wider than about 95 studs cannot be crossed.'
	})
	Leash = InfiniteFly:CreateSlider({
		Name = 'Leash',
		Min = 20,
		Max = 500,
		Default = 80,
		Suffix = 'studs',
		Tooltip = 'How far ahead of the hitbox you may get. Past it you fly at its pace, so a landing waits a few seconds at most.\n500 switches the leash off: you fly at full speed and the landing waits for as long as the hitbox needs.'
	})
	Notify = InfiniteFly:CreateToggle({
		Name = 'Notify',
		Default = true,
		Tooltip = 'Tells you when the hitbox waits at a gap, when a landing has to wait for it and when the server moved it back'
	})
end)

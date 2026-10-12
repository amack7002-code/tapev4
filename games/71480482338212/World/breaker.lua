run(function()
	local Breaker
	local BreakerType
	local BreakChance
	local CombatOnly
	local Angle
	local Range
	local UpdateRate
	local Custom
	local Bed
	local SelfBreak
	local AutoTool
	local LimitItem
	local Animation
	local box
	local lock, lostAt
	local lastHit, jitter = 0, 0
	local confirmed, warned = false, false
	local rng = Random.new()
	local tracks, viewTracks = {}, {}
	local skip = setmetatable({}, {__mode = 'k'})
	local left = setmetatable({}, {__mode = 'k'})
	local full = {}
	-- how far around a bed its cover is read, in blocks: sideways, down and up
	local SIDE, DOWN, UP = 5, 2, 4
	local NEIGHBOURS = {
		{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}
	}
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	local routeAt = 0
	local FACES = {
		Vector3.zero,
		Vector3.new(1.35, 0, 0), Vector3.new(-1.35, 0, 0),
		Vector3.new(0, 1.35, 0), Vector3.new(0, -1.35, 0),
		Vector3.new(0, 0, 1.35), Vector3.new(0, 0, -1.35)
	}

	local function isLegit()
		return BreakerType.Value == 'Legit'
	end

	local function unlock()
		lock, lostAt = nil, nil
	end

	-- a block somebody placed, with the name the game keeps its kind under
	local function placedBlock(part)
		local placed = workspace:FindFirstChild('PlayersBlocksContainer')
		if not (placed and part:IsDescendantOf(placed)) then return nil end
		local object = part.Parent:IsA('Model') and part.Parent or part
		return object, object.Parent.Name
	end

	local function toolFor(kind)
		local held = heldName()
		local data = held and bedfight.MiningData[held]
		local holding = type(data) == 'table' and data.Cooldown ~= nil
		if (LimitItem.Enabled or not AutoTool.Enabled) and not holding then return nil end
		if AutoTool.Enabled then
			return getTool(kind)
		end
		return held, data.Damages and data.Damages[kind] or data.DefaultDamage or 0
	end

	local function hitsFor(object, kind)
		local tool, damage = toolFor(kind)
		if not tool or (damage or 0) <= 0 then return math.huge end
		return math.ceil((left[object] or full[kind] or 30) / damage)
	end

	-- the middle of the bed, each of its halves and the spot on it nearest you
	local function probes(hitbox, from)
		local cf, size = hitbox.CFrame, hitbox.Size
		local long = size.X > size.Z and Vector3.new(size.X / 4, 0, 0) or Vector3.new(0, 0, size.Z / 4)
		local half = size / 2 - Vector3.new(0.3, 0.3, 0.3)
		local near = cf:PointToObjectSpace(from)
		return {
			cf * Vector3.new(math.clamp(near.X, -half.X, half.X), math.clamp(near.Y, -half.Y, half.Y), math.clamp(near.Z, -half.Z, half.Z)),
			hitbox.Position,
			cf * long,
			cf * -long
		}
	end

	-- every placed block on the line to a point of the bed, nearest first.
	-- nothing comes back when a map block is in the way, those cannot be mined
	local function trace(from, point, bed, params)
		local list = {}
		local origin = from
		for _ = 1, 10 do
			local ray = point - origin
			if ray.Magnitude < 0.05 then
				return list
			end
			local hit = workspace:Raycast(origin, ray, params)
			if not hit then
				return list
			end
			if hit.Instance:IsDescendantOf(bed) then
				return list, hit
			end
			local object, kind = placedBlock(hit.Instance)
			if not object then return nil end
			table.insert(list, {Object = object, Part = hit.Instance, Kind = kind})
			origin = hit.Position + ray.Unit * 0.1
		end
		return nil
	end

	-- the first thing a ray from you meets, the way the game's own pickaxe looks for a block
	local function visible(from, part, params)
		for _, offset in FACES do
			local point = part.Position + offset
			local hit = workspace:Raycast(from, point - from, params)
			if hit and hit.Instance == part then
				return hit, point
			end
		end
	end

	local function cellId(x, y, z)
		return (x + 8) * 256 + (y + 8) * 16 + (z + 8)
	end

	-- the cheapest way from open air to the bed, counted in hits and looked for from every side.
	-- comes back as the bed itself when a side of it is already open, else as the outermost block
	-- of that way, with the open spot it can be hit from
	local function route(bed, hitbox, body, reach)
		local placed = workspace:FindFirstChild('PlayersBlocksContainer')
		local centre = snap(hitbox.Position)
		local list = {}
		if placed then
			table.insert(list, placed)
		end
		local map = mapBlocks()
		if map then
			table.insert(list, map)
		end
		overlap.FilterDescendantsInstances = list

		-- false is a map block, a table is a block somebody placed
		local grid = {}
		local size = Vector3.new(SIDE * 2 + 1, DOWN + UP + 1, SIDE * 2 + 1) * 3
		local middle = centre + Vector3.new(0, (UP - DOWN) * 1.5, 0)
		for _, part in workspace:GetPartBoundsInBox(CFrame.new(middle), size, overlap) do
			if not part.CanCollide then continue end
			local offset = part.Position - centre
			if placed and part:IsDescendantOf(placed) then
				local object, kind = placedBlock(part)
				local x, y, z = math.round(offset.X / 3), math.round(offset.Y / 3), math.round(offset.Z / 3)
				if object and math.abs(x) <= SIDE and math.abs(z) <= SIDE and y >= -DOWN and y <= UP then
					grid[cellId(x, y, z)] = {Object = object, Part = part, Kind = kind}
				end
			else
				-- a piece of the map fills every cell its middle reaches
				local cf, half = part.CFrame, part.Size / 2
				local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
				local ex = math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(l.X) * half.Z - 1
				local ey = math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(l.Y) * half.Z - 1
				local ez = math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(l.Z) * half.Z - 1
				for x = math.max(-SIDE, math.ceil((offset.X - ex) / 3)), math.min(SIDE, math.floor((offset.X + ex) / 3)) do
					for y = math.max(-DOWN, math.ceil((offset.Y - ey) / 3)), math.min(UP, math.floor((offset.Y + ey) / 3)) do
						for z = math.max(-SIDE, math.ceil((offset.Z - ez) / 3)), math.min(SIDE, math.floor((offset.Z + ez) / 3)) do
							grid[cellId(x, y, z)] = false
						end
					end
				end
			end
		end

		-- the two halves of the bed
		local long = hitbox.Size.X > hitbox.Size.Z and Vector3.new(hitbox.Size.X / 4, 0, 0) or Vector3.new(0, 0, hitbox.Size.Z / 4)
		local dist, prev, where, isBed = {}, {}, {}, {}
		local buckets = {[0] = {}}
		for _, point in {hitbox.CFrame * long, hitbox.CFrame * -long} do
			local offset = snap(point) - centre
			local x, y, z = math.round(offset.X / 3), math.round(offset.Y / 3), math.round(offset.Z / 3)
			local id = cellId(x, y, z)
			if not isBed[id] then
				isBed[id] = true
				dist[id] = 0
				where[id] = {x, y, z}
				table.insert(buckets[0], id)
			end
		end

		local goal
		local cost, highest = 0, 0
		while cost <= highest and not goal do
			local bucket = buckets[cost]
			local index = 1
			while bucket and index <= #bucket do
				local id = bucket[index]
				index += 1
				if dist[id] ~= cost then continue end
				local at = where[id]
				local x, y, z = at[1], at[2], at[3]
				if not isBed[id] and not grid[id] and (math.abs(x) == SIDE or math.abs(z) == SIDE or y == UP) then
					-- open air at the edge of what was read: this is outside
					goal = id
					break
				end
				for _, step in NEIGHBOURS do
					local nx, ny, nz = x + step[1], y + step[2], z + step[3]
					if math.abs(nx) > SIDE or math.abs(nz) > SIDE or ny < -DOWN or ny > UP then continue end
					local nid = cellId(nx, ny, nz)
					if isBed[nid] then continue end
					local cell = grid[nid]
					local extra = 0
					if cell == false then
						continue
					elseif cell then
						if (cell.Part.Position - body).Magnitude > reach or (skip[cell.Object] or 0) > tick() then continue end
						extra = hitsFor(cell.Object, cell.Kind)
						if extra == math.huge then continue end
					end
					local total = cost + extra
					if total < (dist[nid] or math.huge) then
						dist[nid] = total
						prev[nid] = id
						where[nid] = {nx, ny, nz}
						buckets[total] = buckets[total] or {}
						table.insert(buckets[total], nid)
						highest = math.max(highest, total)
					end
				end
			end
			cost += 1
		end
		if not goal then return nil end

		local function world(id)
			local at = where[id]
			return centre + Vector3.new(at[1], at[2], at[3]) * 3
		end
		-- walked from outside in, the first block met is the one to start on
		local open, id = goal, prev[goal]
		while id do
			if isBed[id] then
				local from, to = world(open), world(id)
				-- a side of the bed is open, just not the one facing you
				return dist[goal], {Object = bed, Part = hitbox, Kind = 'Bed', Bed = bed, Cell = to, From = from, Direction = (to - from).Unit, Routed = true, BedCell = to}
			end
			local cell = grid[id]
			if cell then
				local from = world(open)
				return dist[goal], {Object = cell.Object, Part = cell.Part, Kind = cell.Kind, Bed = bed, Cell = snap(cell.Part.Position), From = from, Direction = (cell.Part.Position - from).Unit, Routed = true}
			end
			open, id = id, prev[id]
		end
		return nil
	end

	local function play(cache, animator, anim)
		if not (anim and animator) then return end
		if cache.Animator ~= animator then
			table.clear(cache)
			cache.Animator = animator
		end
		cache[anim] = cache[anim] or animator:LoadAnimation(anim)
		cache[anim]:Play()
	end

	local function swing(tool)
		local data = bedfight.MiningData[tool]
		local anims = data.Animations or bedfight.MiningData.DefaultAnimation
		local anim = anims and anims.Mine
		if not anim then return end
		play(tracks, entitylib.character.Humanoid:FindFirstChildOfClass('Animator'), anim.Animation)
		if heldName() == tool then
			play(viewTracks, bedfight.ViewModelHandler.ViewModelAnimator, anim.ViewModel)
		end
	end

	-- one hit, no sooner than the tool allows. the server only has to hold the tool
	local function strike(target)
		local tool = toolFor(target.Kind)
		if not tool then return end
		local now = tick()
		local legit = isLegit()
		local cooldown = bedfight.MiningData[tool].Cooldown or 0.3
		if now - lastHit < cooldown + (legit and jitter or 0) then return end
		if not (equipServer(tool, 'Breaker') or (store.sentAt and now - store.sentAt > 0.6)) then return end
		lastHit, jitter = now, rng:NextNumber(0, 0.05)
		if legit and BreakChance.Value < 100 and (not CombatOnly.Enabled or store.inCombat()) and rng:NextNumber(0, 100) >= BreakChance.Value then return end
		target.Sent = (target.Sent or 0) + 1
		fireRemote('MineBlock', tool, target.Object, target.Cell, target.From, target.Direction)
		if Animation.Enabled then
			pcall(swing, tool)
		end
	end

	local function step()
		local legit = isLegit()
		local body = entitylib.character.RootPart.Position
		-- a pickaxe in your hand is aimed from the camera, the blatant one from your chest
		local from = legit and gameCamera.CFrame.Position or body + Vector3.new(0, 1.5, 0)
		local look = gameCamera.CFrame.LookVector
		local reach = Range.Value
		local params = blockParams()
		local team = lplr.Team.Name

		local function allowed(position)
			if (position - body).Magnitude > reach then return false end
			if legit and Angle.Value < 360 then
				local dir = position - from
				if dir.Magnitude > 0.5 and math.deg(math.acos(math.clamp(look:Dot(dir.Unit), -1, 1))) > Angle.Value / 2 then return false end
			end
			return true
		end

		local target, candidate, score = nil, nil, math.huge
		local reachable = {}
		local beds = Bed.Enabled and workspace:FindFirstChild('BedsContainer')
		for _, bed in beds and beds:GetChildren() or {} do
			local hitbox = bed:FindFirstChild('BedHitbox')
			if not hitbox or bed:GetAttribute('Team') == team or (hitbox.Position - body).Magnitude > reach + 4 then continue end
			table.insert(reachable, {bed, hitbox})
			for _, point in probes(hitbox, from) do
				local list, hit = trace(from, point, bed, params)
				if not list then continue end
				if #list == 0 then
					-- an open line to the bed always wins over anything in front of it
					local cell = hit and snap(hit.Position - hit.Normal * 1.5) or snap(point)
					if allowed(cell) and toolFor('Bed') then
						target = {Object = bed, Part = hitbox, Kind = 'Bed', Cell = cell, From = from, Direction = (point - from).Unit}
						break
					end
				elseif legit and not lock then
					local first = list[1]
					if not allowed(first.Part.Position) or (skip[first.Object] or 0) > tick() then continue end
					-- nearest first, and fewer blocks behind it is better
					local cost = (first.Part.Position - body).Magnitude + #list * 3
					if cost < score then
						first.Bed = bed
						candidate, score = first, cost
					end
				end
			end
			if target then break end
		end

		if target then
			unlock()
		else
			if lock then
				local gone = not lock.Object.Parent or not lock.Part.Parent or (lock.Bed and not (lock.Bed.Parent and Bed.Enabled))
				if gone or (lock.Part.Position - body).Magnitude > reach or not toolFor(lock.Kind) then
					unlock()
				elseif confirmed and (lock.Sent or 0) >= 6 and tick() - (lock.Progress or lock.Since) > 2.5 then
					-- hits that change nothing are not reaching it
					skip[lock.Object] = tick() + 4
					unlock()
				end
			end

			if not legit and not lock and tick() - routeAt > 0.2 then
				-- the fewest hits to any bed in reach, whichever side that is and however far the block is from you
				routeAt = tick()
				local best = math.huge
				for _, v in reachable do
					local cost, found = route(v[1], v[2], body, reach)
					if cost and cost < best and toolFor(found.Kind) then
						best, candidate = cost, found
					end
				end
			end
			if not lock and candidate then
				lock = candidate
				lock.Since = tick()
			end

			if not lock and #Custom.ListEnabled > 0 then
				local placed = workspace:FindFirstChild('PlayersBlocksContainer')
				local own = team..' Wool'
				local found = {}
				for _, folder in placed and placed:GetChildren() or {} do
					local wanted = false
					for _, name in Custom.ListEnabled do
						if name:lower() == folder.Name:lower() then
							wanted = true
							break
						end
					end
					if not wanted then continue end
					for _, object in folder:GetChildren() do
						local part = object:IsA('BasePart') and object or object:FindFirstChildWhichIsA('BasePart', true)
						if part and (SelfBreak.Enabled or object.Name ~= own) and (skip[object] or 0) <= tick() and allowed(part.Position) then
							table.insert(found, {Object = object, Part = part, Kind = folder.Name, Distance = (part.Position - body).Magnitude})
						end
					end
				end
				table.sort(found, function(a, b)
					return a.Distance < b.Distance
				end)
				for i = 1, math.min(#found, 6) do
					if toolFor(found[i].Kind) and (not legit or visible(from, found[i].Part, params)) then
						lock = found[i]
						lock.Since = tick()
						break
					end
				end
			end

			if lock and not target then
				local hit, point = visible(from, lock.Part, params)
				if legit and not (hit and allowed(lock.Part.Position)) then
					-- out of sight or out of your view for a moment is not a reason to start on another block
					lostAt = lostAt or tick()
					if tick() - lostAt > 1.5 then
						unlock()
					end
				elseif lock.Routed and not hit then
					-- not in your line of sight, so the hit comes from the open side the route found.
					-- every other three hits it is tried straight from you, whichever the server takes
					lostAt = nil
					lock.Side = lock.Side or {lock.From, lock.Direction}
					if (lock.Sent or 0) % 6 < 3 then
						lock.From, lock.Direction = lock.Side[1], lock.Side[2]
					else
						lock.From, lock.Direction = from, (lock.Part.Position - from).Unit
					end
					lock.Cell = lock.BedCell or snap(lock.Part.Position)
					target = lock
				else
					lostAt = nil
					point = point or lock.Part.Position
					lock.Cell = hit and snap(hit.Position - hit.Normal * 1.5) or snap(lock.Part.Position)
					lock.From, lock.Direction = from, (point - from).Unit
					target = lock
				end
			end
		end

		if target then
			strike(target)
		end
		return target, lock ~= nil
	end

	Breaker = vape.Categories.World:CreateModule({
		Name = 'Breaker',
		Function = function(callback)
			if callback then
				local display = replicatedStorage:FindFirstChild('Remotes') and replicatedStorage.Remotes:FindFirstChild('DisplayBlockHealth')
				if display then
					-- the server tells you what a block has left every time one is hit
					Breaker:Clean(display.OnClientEvent:Connect(function(object, _, health, max)
						if typeof(object) ~= 'Instance' or type(health) ~= 'number' then return end
						left[object] = health
						if type(max) == 'number' and object.Parent and object.Parent.Parent == workspace:FindFirstChild('PlayersBlocksContainer') then
							full[object.Parent.Name] = max
						end
						if lock and lock.Object == object then
							lock.Progress = tick()
							confirmed = true
						end
					end))
				end

				local switched = false
				repeat
					local target, busy
					if canFight() and inMatch() then
						local ok, a, b = pcall(step)
						if ok then
							target, busy = a, b
						elseif not warned then
							warned = true
							warn('[AetherV2] Breaker: '..tostring(a))
						end
					else
						unlock()
					end

					if target then
						switched = true
					elseif switched and not busy then
						switched = false
						syncTool('Breaker')
					end
					if box then
						box.Adornee = target and target.Part or nil
						if target then
							box.Size = target.Part.Size + Vector3.new(0.1, 0.1, 0.1)
						end
					end
					task.wait(1 / UpdateRate.Value)
				until not Breaker.Enabled
			else
				unlock()
				syncTool('Breaker')
				if box then
					box.Adornee = nil
				end
			end
		end,
		ExtraText = function()
			return BreakerType.Value
		end,
		Tooltip = 'Mines enemy beds near you with your pickaxe or axe.\nYour hotbar is not touched.'
	})
	BreakerType = Breaker:CreateDropdown({
		Name = 'Breaker Type',
		List = {'Blatant', 'Legit'},
		Default = 'Blatant',
		Tooltip = 'Blatant - the way to the bed that takes the fewest hits, from whichever side that is, through walls and at any angle\nLegit - only blocks you could really mine: in view of your camera, the nearest one first, and it stays on a block until it is gone',
		Function = function()
			unlock()
		end
	})
	BreakChance = Breaker:CreateSlider({
		Name = 'Break Chance',
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%',
		Darker = true,
		Visible = function()
			return BreakerType.Value == 'Legit'
		end,
		Tooltip = 'How many of your mining hits are actually sent. The rest are skipped like a missed swing'
	})
	CombatOnly = Breaker:CreateToggle({
		Name = 'Only while in combat',
		Darker = true,
		Visible = function()
			return BreakerType.Value == 'Legit'
		end,
		Tooltip = 'Break Chance only applies while you are in a fight. Out of combat every hit is sent'
	})
	Angle = Breaker:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 120,
		Darker = true,
		Visible = function()
			return BreakerType.Value == 'Legit'
		end,
		Tooltip = 'How far from where your camera is facing a block can be'
	})
	Range = Breaker:CreateSlider({
		Name = 'Break range',
		Min = 1,
		Max = 18,
		Default = 18,
		Suffix = 'studs',
		Tooltip = 'The game\'s own mining range is 18'
	})
	UpdateRate = Breaker:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	Custom = Breaker:CreateTextList({
		Name = 'Custom',
		Placeholder = 'block name',
		Tooltip = 'Placed blocks to mine wherever they are in range, for example Wool, Wood Plank, Stone Brick or Obsidian'
	})
	Bed = Breaker:CreateToggle({
		Name = 'Break Bed',
		Default = true
	})
	Animation = Breaker:CreateToggle({
		Name = 'Animation',
		Tooltip = 'Plays the mining swing for every hit'
	})
	SelfBreak = Breaker:CreateToggle({
		Name = 'Self Break',
		Tooltip = 'Lets the Custom list mine your own team\'s wool. Other blocks do not say who placed them'
	})
	AutoTool = Breaker:CreateToggle({
		Name = 'Auto Tool',
		Default = true,
		Tooltip = 'Has the server hold the best tool you own for the block, an axe for a bed. Off, only the tool in your hand is used'
	})
	LimitItem = Breaker:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only mines while you hold a pickaxe or an axe'
	})
	Breaker:CreateToggle({
		Name = 'Show target',
		Default = true,
		Function = function(callback)
			if callback then
				box = Instance.new('BoxHandleAdornment')
				box.AlwaysOnTop = true
				box.ZIndex = 0
				box.Color3 = Color3.fromRGB(255, 80, 80)
				box.Transparency = 0.6
				box.Parent = vape.gui
			elseif box then
				box:Destroy()
				box = nil
			end
		end
	})
end)

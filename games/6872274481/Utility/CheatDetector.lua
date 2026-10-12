run(function()
	local CheatDetector
	local SelfTest
	local toggles = {}

	local SAMPLE_STEP = 0.05
	local HISTORY_TIME = 2
	local FLAG_SCORE = 70
	local SCORE_DECAY = 1.2
	local REASON_LIFE = 25
	local REASON_COOLDOWN = 6
	local TELEPORT_GRACE = 1.5

	local tips = {
		Speed = 'catches ppl movin way too fast',
		Reach = 'catches ppl hittin u from too far away',
		Killaura = 'catches ppl hittin mad fast or behind them',
		Fly = 'catches ppl floatin in the air'
	}

	local history = {}
	local meta = {}
	local score = {}
	local flagged = {}
	local reachStreak = {}
	local airTime = {}
	local speedTime = {}
	local kaData = {}

	local function resetPlayer(plr)
		history[plr] = nil
		meta[plr] = nil
		score[plr] = nil
		reachStreak[plr] = nil
		airTime[plr] = nil
		speedTime[plr] = nil
		kaData[plr] = nil
	end

	local function resetAll()
		table.clear(history)
		table.clear(meta)
		table.clear(score)
		table.clear(flagged)
		table.clear(reachStreak)
		table.clear(airTime)
		table.clear(speedTime)
		table.clear(kaData)
	end

	local function isOn(name)
		local t = toggles[name]
		return t and t.Enabled
	end

	local function notSelf(plr)
		return plr ~= lplr or (SelfTest and SelfTest.Enabled)
	end

	local function getEntities()
		if SelfTest and SelfTest.Enabled and entitylib.character then
			local list = table.clone(entitylib.List)
			table.insert(list, entitylib.character)
			return list
		end
		return entitylib.List
	end

	local function flagPlayer(plr, reasons)
		local key = tostring(plr)
		local now = os.clock()
		if flagged[key] and now < flagged[key] then return end
		flagged[key] = now + 20
		notif('CheatDetector', 'yo '..(plr.DisplayName or plr.Name)..' is prob cheatin -> '..reasons, 12, 'alert')
	end

	local function addScore(plr, amount, reason, label)
		if not plr then return end
		local now = os.clock()
		local s = score[plr]
		if not s then
			s = {value = 0, seen = {}, labels = {}, last = now}
			score[plr] = s
		end
		if s.seen[reason] and now - s.seen[reason] < REASON_COOLDOWN then return end
		s.seen[reason] = now
		s.labels[reason] = label
		s.value = s.value + amount
		if s.value >= FLAG_SCORE then
			local list = {}
			for r in s.labels do
				list[#list + 1] = s.labels[r]
			end
			table.sort(list)
			flagPlayer(plr, table.concat(list, ' + '))
			s.value = 0
			table.clear(s.seen)
			table.clear(s.labels)
		end
	end

	local function pushSample(plr, ent)
		local root = ent.RootPart
		if not root then return end
		local h = history[plr]
		if not h then
			h = {}
			history[plr] = h
		end
		local now = os.clock()
		local cf = root.CFrame
		h[#h + 1] = {t = now, pos = cf.Position, look = cf.LookVector, vel = root.AssemblyLinearVelocity}
		while h[1] and now - h[1].t > HISTORY_TIME do
			table.remove(h, 1)
		end
	end

	local function recentlyTeleported(plr)
		local m = meta[plr]
		if m and os.clock() < (m.teleportUntil or 0) then return true end
		local lastTeleported = plr:GetAttribute('LastTeleported') or 0
		return workspace:GetServerTimeNow() - lastTeleported < TELEPORT_GRACE
	end

	local function trackMeta(plr, ent)
		local now = os.clock()
		local m = meta[plr]
		local teleportStamp = plr:GetAttribute('LastTeleported') or 0
		if not m then
			m = {spawn = now, lastMove = now, lastDamaged = 0, char = ent.Character, lastTeleport = teleportStamp}
			meta[plr] = m
		end
		if m.lastTeleport ~= teleportStamp then
			m.lastTeleport = teleportStamp
			m.teleportUntil = now + TELEPORT_GRACE
			history[plr] = nil
			reachStreak[plr] = nil
			airTime[plr] = nil
			speedTime[plr] = nil
			kaData[plr] = nil
		end
		if m.char ~= ent.Character then
			m.char = ent.Character
			m.spawn = now
			m.lastMove = now
			m.lastPos = nil
			m.lastDamaged = 0
			history[plr] = nil
			score[plr] = nil
			kaData[plr] = nil
			reachStreak[plr] = nil
			airTime[plr] = nil
			speedTime[plr] = nil
		end
		local root = ent.RootPart
		if root then
			if not m.lastPos or (root.Position - m.lastPos).Magnitude > 0.05 then
				m.lastMove = now
			end
			m.lastPos = root.Position
		end
		return m
	end

	local function getHumanoid(ent)
		if ent.Humanoid then return ent.Humanoid end
		return ent.Character and ent.Character:FindFirstChildOfClass('Humanoid')
	end

	local function trusted(plr, ent)
		if not plr or not ent then return false end
		local char = ent.Character
		local root = ent.RootPart
		if not char or not root or not char.Parent or not root.Parent then return false end
		local m = meta[plr]
		if not m then return false end
		local now = os.clock()
		if now - m.spawn < 3 then return false end
		local hum = getHumanoid(ent)
		if not hum or hum.Health <= 0 then return false end
		if (char:GetAttribute('InflatedBalloons') or 0) > 0 then return false end
		if recentlyTeleported(plr) then return false end
		local serverNow = workspace:GetServerTimeNow()
		local stun = char:GetAttribute('StunnedUntilTime')
		if stun and stun > serverNow - 1 then return false end
		if lplr:GetNetworkPing() > 0.15 then return false end
		local h = history[plr]
		if not h or #h < 8 then return false end
		return true
	end

	local function movementTrusted(plr, ent)
		if not trusted(plr, ent) then return false end
		local m = meta[plr]
		return m and os.clock() - m.lastMove <= 0.35
	end

	local function minDistanceTo(plr, point, window)
		local h = history[plr]
		if not h or #h == 0 then return nil end
		local now = os.clock()
		local best
		for i = #h, 1, -1 do
			local s = h[i]
			if now - s.t > window then break end
			local d = (s.pos - point).Magnitude
			if not best or d < best then best = d end
		end
		return best
	end

	local function minPairDistance(a, b, window)
		local ha, hb = history[a], history[b]
		if not ha or not hb then return nil end
		local now = os.clock()
		local best
		for i = #ha, 1, -1 do
			if now - ha[i].t > window then break end
			for j = #hb, 1, -1 do
				if now - hb[j].t > window then break end
				if math.abs(ha[i].t - hb[j].t) <= 0.12 then
					local d = (ha[i].pos - hb[j].pos).Magnitude
					if not best or d < best then best = d end
				end
			end
		end
		return best
	end

	local function recentSample(plr)
		local h = history[plr]
		if not h or #h == 0 then return nil end
		local ping = math.clamp(lplr:GetNetworkPing() * 0.5, 0, 0.3)
		local target = os.clock() - ping
		local best, bestDiff
		for i = #h, 1, -1 do
			local diff = math.abs(h[i].t - target)
			if not bestDiff or diff < bestDiff then
				best = h[i]
				bestDiff = diff
			end
		end
		return best
	end

	local function getAttackRange(plr)
		local inv = store.inventories[plr]
		local hand = inv and inv.hand
		local name = hand and (hand.itemType or (hand.tool and hand.tool.Name))
		if not name then return nil end
		local itemMeta = bedwars.ItemMeta[name]
		local swordMeta = itemMeta and itemMeta.sword
		if not swordMeta then return nil end
		return swordMeta.attackRange or 14.4
	end

	local function blockedByMap(fromPos, toPos)
		local dir = toPos - fromPos
		local dist = dir.Magnitude
		if dist < 3 then return false end
		local params = cloneRaycast()
		local hit = workspace:Raycast(fromPos, dir.Unit * (dist - 1.5), params)
		if not hit then return false end
		return (hit.Position - fromPos).Magnitude < dist - 2
	end

	local function kaState(plr)
		local d = kaData[plr]
		if not d then
			d = {targets = {}, intervals = {}, lastHit = 0, angleHits = {}, wallHits = {}}
			kaData[plr] = d
		end
		return d
	end

	local function pruneStamps(list, life)
		local now = os.clock()
		for i = #list, 1, -1 do
			if now - list[i] > life then table.remove(list, i) end
		end
		return #list
	end

	local function checkReach(attacker, victimPlr, victimPos, fromPosition)
		if not isOn('Reach') then return end
		local range = getAttackRange(attacker)
		if not range then return end

		local best
		if typeof(fromPosition) == 'Vector3' then
			if victimPlr then
				best = minDistanceTo(victimPlr, fromPosition, 0.8)
			elseif victimPos then
				best = (victimPos - fromPosition).Magnitude
			end
		end
		if victimPlr then
			local paired = minPairDistance(attacker, victimPlr, 0.8)
			if paired and (not best or paired < best) then best = paired end
		end
		if not best then return end

		local allowance = range + 2.5 + math.min(lplr:GetNetworkPing(), 0.2) * 30
		if best > allowance then
			local now = os.clock()
			local streak = reachStreak[attacker] or {count = 0, last = 0}
			if now - streak.last > 2 then streak.count = 0 end
			streak.count += 1
			streak.last = now
			reachStreak[attacker] = streak
			if streak.count >= 3 then
				reachStreak[attacker] = nil
				addScore(attacker, 45, 'reach', 'reach ('..string.format('%.1f', best)..' studs, max is '..string.format('%.1f', allowance)..')')
			end
		else
			reachStreak[attacker] = nil
		end
	end

	local function checkKillaura(attacker, victimInstance, victimPlr, victimPos, fromPosition)
		if not isOn('Killaura') then return end
		local d = kaState(attacker)
		local now = os.clock()

		d.targets[victimInstance] = now
		local distinct = 0
		for inst, t in d.targets do
			if now - t <= 0.15 then
				distinct = distinct + 1
			else
				d.targets[inst] = nil
			end
		end
		if distinct >= 3 then
			addScore(attacker, 40, 'multi', 'killaura (hit '..distinct..' ppl within 0.15s)')
		end

		if d.lastHit > 0 then
			local gap = now - d.lastHit
			if gap > 0.04 and gap < 1.2 then
				d.intervals[#d.intervals + 1] = gap
				while #d.intervals > 16 do
					table.remove(d.intervals, 1)
				end
				if #d.intervals >= 16 then
					local sum = 0
					for _, g in d.intervals do sum = sum + g end
					local mean = sum / #d.intervals
					local varSum = 0
					for _, g in d.intervals do varSum = varSum + (g - mean) ^ 2 end
					local sd = math.sqrt(varSum / #d.intervals)
					if mean > 0.05 and mean < 0.25 and sd / mean < 0.04 then
						addScore(attacker, 45, 'timing', 'killaura (hits perfectly on beat, no human jitter)')
						table.clear(d.intervals)
					end
				end
			end
		end
		d.lastHit = now

		local attackerSample = recentSample(attacker)
		local origin = typeof(fromPosition) == 'Vector3' and fromPosition or attackerSample and attackerSample.pos
		local look = attackerSample and attackerSample.look
		local targetPos = victimPos
		if victimPlr then
			local vs = recentSample(victimPlr)
			if vs then targetPos = vs.pos end
		end

		if origin and look and targetPos then
			local flatLook = look * Vector3.new(1, 0, 1)
			local flatDir = (targetPos - origin) * Vector3.new(1, 0, 1)
			if flatLook.Magnitude > 0.001 and flatDir.Magnitude > 0.001 then
				local angle = math.deg(math.acos(math.clamp(flatLook.Unit:Dot(flatDir.Unit), -1, 1)))
				if angle > 75 then
					d.angleHits[#d.angleHits + 1] = now
					if pruneStamps(d.angleHits, 15) >= 4 then
						table.clear(d.angleHits)
						addScore(attacker, 35, 'angle', 'killaura (swingin at ppl behind them)')
					end
				end
			end

			if blockedByMap(origin, targetPos) then
				d.wallHits[#d.wallHits + 1] = now
				if pruneStamps(d.wallHits, 15) >= 3 then
					table.clear(d.wallHits)
					addScore(attacker, 40, 'wall', 'killaura (hittin straight thru blocks)')
				end
			end
		end
	end

	local function onMeleeDamage(dmg)
		if not CheatDetector.Enabled then return end
		if typeof(dmg.entityInstance) ~= 'Instance' or not dmg.entityInstance:IsA('Model') then return end
		local victimPlr = playersService:GetPlayerFromCharacter(dmg.entityInstance)
		if victimPlr then
			local vm = meta[victimPlr]
			if vm then vm.lastDamaged = os.clock() end
		end
		if dmg.damageType ~= 0 then return end
		if typeof(dmg.fromEntity) ~= 'Instance' then return end
		local attacker = dmg.fromEntity:IsA('Player') and dmg.fromEntity
			or (dmg.fromEntity:IsA('Model') and playersService:GetPlayerFromCharacter(dmg.fromEntity))
		if not attacker or not notSelf(attacker) then return end

		local victimRoot = dmg.entityInstance.PrimaryPart or dmg.entityInstance:FindFirstChild('HumanoidRootPart')
		local victimPos = victimRoot and victimRoot.Position

		local am = meta[attacker]
		if not am or os.clock() - am.spawn < 3 then return end
		if lplr:GetNetworkPing() > 0.15 then return end
		if recentlyTeleported(attacker) or (victimPlr and recentlyTeleported(victimPlr)) then
			reachStreak[attacker] = nil
			kaData[attacker] = nil
			return
		end

		checkReach(attacker, victimPlr, victimPos, dmg.fromPosition)
		checkKillaura(attacker, dmg.entityInstance, victimPlr, victimPos, dmg.fromPosition)
	end

	local function checkFly(plr, ent, dt, rayParams)
		if not isOn('Fly') then
			airTime[plr] = 0
			return
		end
		local root = ent.RootPart
		rayParams.FilterDescendantsInstances = {ent.Character, lplr.Character, gameCamera}
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -250, 0), rayParams)
		if not hit then
			airTime[plr] = 0
			return
		end
		local groundDist = root.Position.Y - hit.Position.Y
		local vel = root.AssemblyLinearVelocity
		local m = meta[plr]
		if m and os.clock() - (m.lastDamaged or 0) < 1.5 then
			airTime[plr] = 0
			return
		end

		local hovering = math.abs(vel.Y) < 3
		local rising = vel.Y > 3
		if groundDist > 10 and (hovering or rising) then
			airTime[plr] = (airTime[plr] or 0) + dt
			if airTime[plr] >= 2.25 then
				airTime[plr] = 0
				addScore(plr, 50, 'fly', 'fly (sustained airborne movement, '..math.floor(groundDist)..' studs above ground)')
			end
		else
			airTime[plr] = 0
		end
	end

	local function checkSpeed(plr, ent, dt)
		if not isOn('Speed') then
			speedTime[plr] = 0
			return
		end
		local m = meta[plr]
		if m and os.clock() - (m.lastDamaged or 0) < 1.5 then
			speedTime[plr] = 0
			return
		end
		local h = history[plr]
		if not h or #h < 8 then
			speedTime[plr] = 0
			return
		end

		local now = os.clock()
		local newest, oldest, prev
		local maxStep = 0
		local travelled = 0
		for i = #h, 1, -1 do
			local s = h[i]
			if now - s.t > 0.5 then break end
			if not newest then newest = s end
			if prev then
				local step = ((prev.pos - s.pos) * Vector3.new(1, 0, 1)).Magnitude
				if step > maxStep then maxStep = step end
				travelled += step
			end
			prev = s
			oldest = s
		end

		if not newest or not oldest then
			speedTime[plr] = 0
			return
		end
		local span = newest.t - oldest.t
		if span < 0.3 or maxStep > 8 then
			speedTime[plr] = 0
			return
		end

		local speed = travelled / span
		if speed > 34 then
			speedTime[plr] = (speedTime[plr] or 0) + dt
			if speedTime[plr] >= 1.2 then
				speedTime[plr] = 0
				addScore(plr, 45, 'speed', 'speed ('..math.floor(speed)..' studs a sec)')
			end
		else
			speedTime[plr] = 0
		end
	end

	local function decayScores(dt)
		local now = os.clock()
		for plr, s in score do
			s.last = now
			s.value = math.max(0, s.value - SCORE_DECAY * dt)
			for reason, t in s.seen do
				if now - t > REASON_LIFE then
					s.seen[reason] = nil
					s.labels[reason] = nil
				end
			end
			if s.value <= 0 and not next(s.seen) then
				score[plr] = nil
			end
		end
	end

	CheatDetector = vape.Categories.Utility:CreateModule({
		Name = 'CheatDetector',
		Function = function(callback)
			if callback then
				resetAll()

				CheatDetector:Clean(playersService.PlayerRemoving:Connect(function(plr)
					resetPlayer(plr)
					flagged[tostring(plr)] = nil
				end))

				CheatDetector:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(dmg)
					pcall(onMeleeDamage, dmg)
				end))

				cleanThread(CheatDetector, task.spawn(function()
					local rayParams = RaycastParams.new()
					rayParams.FilterType = Enum.RaycastFilterType.Exclude
					local last = os.clock()
					local decayAccum = 0
					repeat
						local now = os.clock()
						local dt = now - last
						last = now
						decayAccum = decayAccum + dt

						for _, ent in getEntities() do
							local plr = ent.Player
							if plr and notSelf(plr) and ent.RootPart and ent.Character then
								trackMeta(plr, ent)
								pushSample(plr, ent)
								if dt <= 0.25 and trusted(plr, ent) then
									checkFly(plr, ent, dt, rayParams)
									if movementTrusted(plr, ent) then
										checkSpeed(plr, ent, dt)
									else
										speedTime[plr] = 0
									end
								else
									airTime[plr] = 0
									speedTime[plr] = 0
								end
							end
						end

						if decayAccum >= 1 then
							decayScores(decayAccum)
							decayAccum = 0
						end

						task.wait(SAMPLE_STEP)
					until not CheatDetector.Enabled
					resetAll()
				end))
			else
				resetAll()
			end
		end,
		Tooltip = 'tells u if sum1 in ur game is prob cheatin'
	})

	SelfTest = CheatDetector:CreateToggle({
		Name = 'Self',
		Default = false,
		Tooltip = 'lets it flag u too so u can test it on urself'
	})

	for _, name in {'Speed', 'Reach', 'Killaura', 'Fly'} do
		toggles[name] = CheatDetector:CreateToggle({
			Name = name,
			Default = true,
			Tooltip = tips[name]
		})
	end
end)
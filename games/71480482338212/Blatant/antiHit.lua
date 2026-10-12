run(function()
	local AntiHit
	local Range
	local Height
	local Hits
	local Dodge
	local filtered
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	-- measured 2026-10-12: a root that has been off the ground for a second is taken by the server and
	-- left on the ground for four. 0.9s up with 0.1s on the ground held every time, 1.1s up never did
	local UP, DOWN, EARLY = 0.75, 0.13, 0.35
	-- coming down from more than 20 studs costs health
	local MAX_DROP = 18
	-- the game's own swing box ends 13.75 studs from the swinger, and no hit sent from 17 or more ever counted
	local SWING, CLEAR = 14.5, 17.5
	-- the root is back in reach this long before your hit is sent, and stays this long after
	local LEAD, HOLD = 0.12, 0.05
	local FLAT = Vector3.new(1, 0, 1)

	local idle, lastDraw = 0, 0
	local groundAt, downUntil, standing = 0, 0, false
	local peak, lastSpot, stepped
	local managedAt, gateSince, gateAt = 0, nil, 0
	local reachOf, reachSince
	local struckAt, seenStruck = 0, nil
	local dangers = {}

	local function release()
		if store.antiHit then
			store.antiHit = nil
			mergeRoot('AntiHit')
		end
		reachOf, reachSince, peak, lastSpot, stepped = nil, nil, nil, nil, nil
	end

	local function reach()
		return math.min(store.meleeRange or 14, 14)
	end

	local function cooldown()
		local data = store.tools.sword and bedfight.SwordsData and bedfight.SwordsData[store.tools.sword]
		return type(data) == 'table' and data.DamageCooldown or 0.3
	end

	-- the shot that is about to pass, if any
	local function incoming(now)
		for i = #dangers, 1, -1 do
			if dangers[i].To < now then
				table.remove(dangers, i)
			end
		end
		return dangers[1]
	end

	-- how much room a hitbox at this height has from every shot passing right now. below zero is a hit
	local function room(y, now)
		local least = math.huge
		for _, shot in dangers do
			if now >= shot.From then
				least = math.min(least, math.abs(shot.Y - y) - shot.Need)
			end
		end
		return least
	end

	AntiHit = vape.Categories.Blatant:CreateModule({
		Name = 'AntiHit',
		Function = function(callback)
			if callback then
				-- Killaura asks before each hit. the root is only brought into reach for the hit itself
				store.strikeGate = function(ent)
					local now = tick()
					if not Hits.Enabled or now - managedAt > 0.1 then return true end
					gateAt = now
					gateSince = gateSince or now
					-- never holds a hit back for long
					if now - gateSince > 0.45 then return true end
					if now - struckAt < cooldown() - 0.02 then return false end
					return reachOf == ent and reachSince ~= nil and now - reachSince >= LEAD
				end

				AntiHit:Clean(entitylib.Events.LocalRemoved:Connect(function()
					store.antiHit = nil
					table.clear(dangers)
				end))

				local remote = replicatedStorage:FindFirstChild('Remotes')
				remote = remote and remote:FindFirstChild('ReplicateProjectile')
				if remote then
					AntiHit:Clean(remote.OnClientEvent:Connect(function(userId, _, name, origin, speed, unit)
						if not Dodge.Enabled or userId == lplr.UserId or not entitylib.isAlive then return end
						if typeof(origin) ~= 'Vector3' or typeof(unit) ~= 'Vector3' or type(speed) ~= 'number' then return end
						local data = bedfight.ProjectilesData and bedfight.ProjectilesData[name]
						if type(data) ~= 'table' then return end
						local shooter = playersService:GetPlayerByUserId(userId)
						if shooter and lplr.Team and shooter.Team == lplr.Team and lplr.Team.Name ~= 'Spectators' then return end
						-- the game flies it as origin + velocity * t + gravity * t * t / 2
						local body = bodyRoot().Position
						local velocity = unit * speed
						local across = velocity * FLAT
						if across.Magnitude < 1 then return end
						local t = ((body - origin) * FLAT):Dot(across) / across.Magnitude ^ 2
						if t <= 0 or t > math.min(data.LifeTime or 5, 4) then return end
						local gravity = typeof(data.Gravity) == 'Vector3' and data.Gravity or Vector3.zero
						local at = origin + velocity * t + gravity * (t * t / 2)
						local blast = data.BlastRadius or 0
						if ((at - body) * FLAT).Magnitude > blast + 8 then return end
						-- it left a ping ago by the time the root can be somewhere else for the server
						local arrive = tick() + t - math.min(lplr:GetNetworkPing() * 2, 0.6)
						if arrive + 0.3 < tick() or #dangers >= 24 then return end
						-- the hitbox is 6.5 tall
						table.insert(dangers, {From = arrive - 0.25, To = arrive + 0.3, Y = at.Y, Need = math.max(5, blast + 3)})
					end))
				end

				AntiHit:Clean(runService.Heartbeat:Connect(function()
					if not entitylib.isAlive or store.flyOn or store.dashOn then
						release()
						return
					end
					local now = tick()
					local danger = incoming(now)
					local threat = canFight() and store.targets({Range = Range.Value, Players = true, NPCs = true, Limit = 1})[1]
					if threat or danger then
						idle = now
					elseif now - idle > 0.6 then
						release()
						return
					end
					if not store.antiHit then
						if not ((threat or danger) and splitRoot('AntiHit')) then return end
						store.antiHit = true
						groundAt, downUntil, standing = now, 0, false
					end
					if store.struckAt ~= seenStruck then
						seenStruck = store.struckAt
						struckAt = now
						gateSince = nil
					elseif gateSince and now - gateAt > 0.15 then
						gateSince = nil
					end

					local fighting = now - (store.melee or 0) < 0.4
					local held = inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and heldName()
					if held then
						-- your own shots leave from the root, and a swing by hand is measured from it
						if bedfight.RangedData and bedfight.RangedData[held] then
							lastDraw = now
						elseif Hits.Enabled and not fighting and threat and bedfight.SwordsData and bedfight.SwordsData[held] and (threat.RootPart.Position - bodyRoot().Position).Magnitude < SWING + 2 then
							lastDraw = now
						end
					end
					local body = bodyRoot()
					local hip = entitylib.character.HipHeight
					local container = workspace:FindFirstChild('PlayersContainer') or lplr.Character
					if filtered ~= container then
						filtered = container
						rayCheck.FilterDescendantsInstances = {container, gameCamera}
					end
					local under = now - lastDraw >= 0.3 and workspace:Raycast(body.Position, Vector3.new(0, -(MAX_DROP + hip + 2), 0), rayCheck)
					if not under then
						-- drawing a shot, or nothing to stand on within a free drop: the root stays in the body
						if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
							groundAt, peak = now, nil
						end
						standing, downUntil = false, 0
						reachOf, reachSince = nil, nil
						return
					end
					local spot = Vector3.new(body.Position.X, under.Position.Y + hip, body.Position.Z)
					store.antiHitAt = now
					managedAt = now

					-- the server counts a fall from the highest point since the root last stood. when the ground
					-- under you drops, it stands on the old ground once more before it follows you down
					local stand = spot
					if peak and peak - spot.Y > MAX_DROP + 1.5 then
						if lastSpot and not stepped and ((lastSpot - spot) * FLAT).Magnitude < 12 then
							stand = lastSpot
						end
					else
						lastSpot, stepped = spot, nil
					end

					if standing and now >= downUntil then
						standing = false
						groundAt = now
						peak = stand.Y
						if stand ~= spot then
							stepped = true
							stand = spot
						end
					end

					local top = spot.Y + Height.Value
					local target = Hits.Enabled and fighting and store.meleeTarget or nil
					if target and not (target.RootPart and target.RootPart.Parent) then
						target = nil
					end
					local strikeY, grounded
					if target then
						-- as high as still reaches who you are hitting
						local far = reach() - 0.75
						local aimed = target.RootPart.Position
						local flat = ((aimed - spot) * FLAT).Magnitude
						strikeY = math.clamp(aimed.Y + (far > flat and math.sqrt(far * far - flat * flat) or 0), spot.Y, top)
						grounded = (aimed - spot).Magnitude <= far
					end
					local due = target and math.max(store.meleeDue or now, struckAt + cooldown()) or nil
					-- a hit that does not go out within a moment is not waited for down there
					local strike = due and ((due - now <= LEAD and now - due < 0.3) or now - struckAt < HOLD)
					local since = now - groundAt
					local clear = not threat or (threat.RootPart.Position - spot).Magnitude > CLEAR

					local y
					if standing then
						y = stand.Y
					elseif stand ~= spot or since >= UP then
						standing, downUntil = true, now + DOWN
						y = stand.Y
					elseif since >= EARLY and clear and (not danger or room(stand.Y, now) >= 0) then
						-- it has to stand once in a while, and does while nothing can reach the spot
						standing, downUntil = true, now + DOWN
						y = stand.Y
					elseif strike then
						y = strikeY
					else
						y = top
					end
					if danger and not standing and room(y, now) < 0 then
						-- a shot passes at that height. the hitbox waits at the height furthest from every shot instead
						local best, most = y, room(y, now)
						local try = top
						while try >= spot.Y + 3 do
							local space = room(try, now)
							if space > most + 0.5 then
								best, most = try, space
							end
							try -= 3
						end
						y = best
					end
					if standing and strike and grounded and now + HOLD > downUntil then
						-- your hit goes out from down here
						downUntil = now + HOLD
					end

					local at = Vector3.new(stand.X, y, stand.Z)
					peak = math.max(peak or y, y)
					if target and (at - target.RootPart.Position).Magnitude <= reach() - 0.25 then
						if reachOf ~= target or not reachSince then
							reachOf, reachSince = target, now
						end
					else
						reachOf, reachSince = nil, nil
					end
					sendRoot(CFrame.new(at) * body.CFrame.Rotation)
				end))
			else
				store.strikeGate = nil
				table.clear(dangers)
				release()
			end
		end,
		Tooltip = 'While an enemy is close, keeps the hitbox the server hits high above you, out of reach of any sword.\nYour character and camera stay where they are. The hitbox touches the ground for an eighth of a second\nevery three quarters of a second, because the server takes back one that floats for a whole second, and sooner whenever nobody can reach it.'
	})
	Range = AntiHit:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 40,
		Default = 22,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How close an enemy has to be before the hitbox lifts'
	})
	Height = AntiHit:CreateSlider({
		Name = 'Hover height',
		Min = 12,
		Max = 18,
		Default = 17,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far above the ground under you the hitbox waits. A swing ends 13.75 studs from the swinger, and coming down from more than 20 costs health.'
	})
	Hits = AntiHit:CreateToggle({
		Name = 'Keep your hits',
		Default = true,
		Tooltip = 'Your own hits are measured from the hitbox. With Killaura it drops into reach for a moment before each hit and goes straight back up.\nSwinging by hand or drawing a bow brings it back to you for as long as you hold the button.'
	})
	Dodge = AntiHit:CreateToggle({
		Name = 'Dodge projectiles',
		Default = true,
		Tooltip = 'Works out where an arrow or fireball passes you and has the hitbox at a height it misses when it does.\nA shot that takes less than your ping to arrive cannot be dodged, and neither can one that comes while the hitbox has to touch the ground.'
	})
end)

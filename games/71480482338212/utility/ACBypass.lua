run(function()
	local AntiCheatBypass
	local Notify
	local Lagback
	local warned = {}
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	-- drops up to 20 studs are free, and the root may be off the ground for a second (0.9 held, 1.1 did not)
	local MAX_DROP, AIR, STAND = 18, 0.75, 0.13

	local function uncover()
		store.floatCover = nil
		mergeRoot('Lagback')
	end
	local userOff = false

	AntiCheatBypass = vape.Categories.Utility:CreateModule({
		Name = 'AntiCheatBypass',
		Function = function(callback)
			if callback then
				userOff = false
				local found = disarmAnticheat(true)
				if found == nil then
					notif('AntiCheatBypass', 'Your executor cannot reach the game\'s anticheat (no getloadedmodules). Capes, bed visuals and speed changes can get this session flagged.', 15, 'alert')
				elseif store.anticheat.Tripped then
					notif('AntiCheatBypass', 'The anticheat already went off this session, so your actions no longer reach the server. Rejoin to fix it.', 15, 'alert')
				elseif found == 0 and vape.Loaded then
					notif('AntiCheatBypass', 'The anticheat was not found yet. It is checked again whenever the game sends a new copy.', 8, 'warning')
				end

				-- the server pulls back a root that has been off the ground too long, and it only follows
				-- the real root. so that one stands on the ground below for a moment while you stay up
				local air, standUntil = 0, nil
				AntiCheatBypass:Clean(runService.Heartbeat:Connect(function(dt)
					if not (Lagback.Enabled and entitylib.isAlive) or store.dashOn then
						air, standUntil = 0, nil
						uncover()
						return
					end
					-- AntiHit is moving the root and stands it on the ground itself
					if store.antiHitAt and tick() - store.antiHitAt < 0.2 then
						air, standUntil = 0, nil
						store.floatCover = tick()
						mergeRoot('Lagback')
						return
					end
					local body = bodyRoot()
					if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
						air, standUntil = 0, nil
						store.floatCover = tick()
						mergeRoot('Lagback')
						return
					end
					rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('PlayersContainer') or lplr.Character, gameCamera}
					local ground = workspace:Raycast(body.Position, Vector3.new(0, -60, 0), rayCheck)
					local height = entitylib.character.HipHeight
					local drop = ground and ground.Distance - height
					if not drop or drop > MAX_DROP then
						-- too high to come down for free, or nothing below
						air, standUntil = air + dt, nil
						uncover()
						return
					end
					store.floatCover = tick()
					if standUntil then
						if tick() < standUntil then
							sendRoot(CFrame.new(body.Position.X, ground.Position.Y + height, body.Position.Z) * body.CFrame.Rotation)
						else
							air, standUntil = 0, nil
						end
						return
					end
					air += dt
					if air >= AIR and drop > 0.5 and splitRoot('Lagback') then
						standUntil = tick() + STAND
					end
				end))
				AntiCheatBypass:Clean(uncover)

				AntiCheatBypass:Clean(vapeEvents.AnticheatBlocked.Event:Connect(function(reason)
					if Notify.Enabled and not warned[reason] then
						warned[reason] = true
						notif('AntiCheatBypass', 'Stopped a detection: '..reason, 8, 'warning')
					end
				end))
			else
				table.clear(warned)
				if vape.Loaded then
					userOff = true
					disarmAnticheat(false)
					notif('AntiCheatBypass', 'The anticheat is live again. One detection now cuts you off from the server until you rejoin.', 10, 'alert')
				end
			end
		end,
		ExtraText = function()
			local total = 0
			for _, v in store.anticheat.Blocked do
				total += v
			end
			return total > 0 and total..' stopped' or ''
		end,
		Tooltip = 'Switches off the hidden client check that swaps every remote for a dead copy and reports you.\nIt watches hitbox size, an anchored root, WalkSpeed of 25 or more, unknown capes,\nanything added to a bed and the knockback script.\nTurns itself on each launch.'
	})
	Lagback = AntiCheatBypass:CreateToggle({
		Name = 'Prevent lagback',
		Default = true,
		Function = function(callback)
			if not callback then
				uncover()
			end
		end,
		Tooltip = 'Stops the pull back for being off the ground too long, while the ground is within 18 studs below you.\nOnly the hitbox the server follows touches down, every three quarters of a second. You and your camera stay up.\nIt cannot cover moving faster than the server allows, or heights above 18 studs.'
	})
	Notify = AntiCheatBypass:CreateToggle({
		Name = 'Notify',
		Default = true,
		Tooltip = 'Says once per reason what the anticheat tried to flag'
	})

	-- on unless the player switched it off this session
	task.spawn(function()
		repeat task.wait(0.5) until vape.Loaded ~= false
		task.wait(1)
		if vape.Loaded and not userOff and not AntiCheatBypass.Enabled then
			AntiCheatBypass:Toggle()
		end
	end)
end)

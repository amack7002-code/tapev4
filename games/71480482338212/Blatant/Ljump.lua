run(function()
	local LongJump
	local Value
	local Duration
	local Slope
	local VoidCheck
	local readyAt = 0
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	-- a landing may be this far under the path. falling further than 20 studs costs health
	local MAX_FALL = 30

	local function ground(point)
		return workspace:Raycast(point + Vector3.new(0, 3, 0), Vector3.new(0, -(MAX_FALL + 3), 0), rayCheck) ~= nil
	end

	-- how far the dash may go: up to the first wall, and with Void check only as far as the last
	-- spot on the way that has ground under it and under the two studs before it
	local function plan(start, dir, flat, distance)
		local wall = workspace:Raycast(start, dir * (distance + 2), rayCheck)
		if wall then
			distance = math.max(wall.Distance - 2, 0)
		end
		if not VoidCheck.Enabled then
			return distance, wall ~= nil
		end
		local travelled = distance
		while travelled >= 4 do
			local point = start + dir * travelled
			if ground(point) and ground(point - flat * 2) then
				return travelled, wall ~= nil, travelled < distance - 0.5
			end
			travelled -= 2
		end
		return nil
	end

	LongJump = vape.Categories.Blatant:CreateModule({
		Name = 'LongJump',
		Function = function(callback)
			if callback then
				if tick() < readyAt then
					notif('LongJump', string.format('Ready in %.1fs.', readyAt - tick()), 2)
					LongJump:Toggle()
					return
				end
				if not entitylib.isAlive then
					LongJump:Toggle()
					return
				end

				local look = gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
				if look.Magnitude < 0.01 then
					look = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
				end
				local flat = look.Unit
				local angle = math.rad(Slope.Value)
				local dir = flat * math.cos(angle) + Vector3.new(0, math.sin(angle), 0)
				local startPos = entitylib.character.RootPart.Position
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, workspace:FindFirstChild('PlayersContainer')}

				-- decided once, before moving. checking on the way only saw the void when it was already underneath
				local distance, walled, shortened = plan(startPos, dir, flat, Value.Value * Duration.Value)
				if not distance or distance < 1 then
					notif('LongJump', distance and 'A wall is in the way.' or 'Nothing to land on that way.', 3, 'warning')
					LongJump:Toggle()
					return
				end
				local reason = shortened and 'Stopped over the last ground' or walled and 'Stopped at a wall' or 'Ended'
				local travelled = 0
				store.dashOn = true

				LongJump:Clean(runService.PreSimulation:Connect(function(dt)
					if not entitylib.isAlive then
						LongJump:Toggle()
						return
					end
					local root = entitylib.character.RootPart
					local length = math.min(Value.Value * dt, distance - travelled)
					local step = dir * length
					-- something that moved into the way since the plan was made
					if workspace:Raycast(root.Position, step + dir * 2, rayCheck) then
						reason = 'Hit a wall'
						LongJump:Toggle()
						return
					end
					travelled += length
					root.CFrame += step
					-- the step is the whole move, carried as velocity too it went twice as far
					root.AssemblyLinearVelocity = Vector3.zero
					if travelled >= distance - 0.01 then
						LongJump:Toggle()
					end
				end))

				LongJump:Clean(function()
					store.dashOn = nil
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						root.AssemblyLinearVelocity = Vector3.zero
						-- further flights wait longer before the next one
						local dist = ((root.Position - startPos) * Vector3.new(1, 0, 1)).Magnitude
						readyAt = tick() + math.clamp((dist / 50) ^ 2.5, 1, 3)
					end
					notif('LongJump', reason..'.', 2)
				end)
			end
		end,
		Tooltip = 'One fast dash the way your camera faces, exactly Speed x Duration long.\nSwitches itself off when the dash is over.'
	})
	Value = LongJump:CreateSlider({
		Name = 'Speed',
		Min = 20,
		Max = 300,
		Default = 300,
		Suffix = 'studs'
	})
	Duration = LongJump:CreateSlider({
		Name = 'Duration',
		Min = 0.1,
		Max = 2,
		Default = 0.2,
		Decimal = 100,
		Suffix = 's'
	})
	Slope = LongJump:CreateSlider({
		Name = 'Slope angle',
		Min = 0,
		Max = 10,
		Default = 5,
		Suffix = 'deg'
	})
	VoidCheck = LongJump:CreateToggle({
		Name = 'Void check',
		Tooltip = 'Ends the dash over the last ground on the way, and does not start when there is none.\nA landing counts when there is ground within 30 studs under it.'
	})
end)

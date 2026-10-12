run(function()
	local PearlTP
	local Limit
	local ITEM = 'Teleorb'
	local lastThrow = 0

	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	rayCheck.RespectCanCollide = true

	local function getMouseTarget(mousePosition)
		rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, workspace:FindFirstChild('PlayersContainer'), workspace:FindFirstChild('ProjectilesContainer')}
		local ray = gameCamera:ViewportPointToRay(mousePosition.X, mousePosition.Y)
		local result = workspace:Raycast(ray.Origin, ray.Direction * 2048, rayCheck)
		return result and result.Position
	end

	-- the flattest throw at full speed that passes through the target. the game flies its
	-- projectiles as origin + velocity * t + gravity * t * t / 2
	local function solve(origin, target, speed, gravity)
		local delta = target - origin
		local flat = Vector3.new(delta.X, 0, delta.Z)
		local distance = flat.Magnitude
		if distance < 0.5 then
			return Vector3.new(0, delta.Y >= 0 and speed or -speed, 0)
		end
		if gravity <= 0 then
			return delta.Unit * speed
		end
		local root = speed ^ 4 - gravity * (gravity * distance * distance + 2 * delta.Y * speed * speed)
		if root < 0 then return nil end
		local angle = math.atan((speed * speed - math.sqrt(root)) / (gravity * distance))
		return flat.Unit * (math.cos(angle) * speed) + Vector3.new(0, math.sin(angle) * speed, 0)
	end

	-- walks the orb's own arc and reports the first thing it would hit before the target
	local function getPathObstacle(origin, velocity, gravity, target)
		local flight = ((target - origin) * Vector3.new(1, 0, 1)).Magnitude / math.max((velocity * Vector3.new(1, 0, 1)).Magnitude, 1)
		local steps = math.clamp(math.ceil(flight / 0.05), 1, 120)
		local previous = origin
		for i = 1, steps do
			local t = flight * i / steps
			local point = origin + velocity * t + Vector3.new(0, -gravity * t * t / 2, 0)
			if (point - target).Magnitude <= 1.5 then break end
			local segment = point - previous
			if segment.Magnitude > 0 then
				local hit = workspace:Raycast(previous, segment, rayCheck)
				if hit and (hit.Position - target).Magnitude > 1.5 then
					return hit
				end
			end
			previous = point
		end
		return nil
	end

	local function throwPearl(target)
		if not entitylib.isAlive then notif('PearlTP', 'Character missing.', 3, 'warning') return false end
		if (store.inventory[ITEM] or 0) <= 0 then notif('PearlTP', 'No teleorb available.', 3, 'warning') return false end
		if Limit.Enabled and heldName() ~= ITEM then
			notif('PearlTP', 'Hold a teleorb first.', 3, 'warning')
			return false
		end
		local data = bedfight.RangedData[ITEM]
		local meta = data and bedfight.ProjectilesData[data.Projectile or ITEM]
		if not (meta and meta.Speed) then
			notif('PearlTP', 'Teleorb projectile data unavailable.', 3, 'warning')
			return false
		end
		-- the game itself will not throw one while abilities are switched off
		local ok, abilities = pcall(function()
			return require(replicatedStorage.Modules.AbilitiesManager)
		end)
		if ok and type(abilities) == 'table' and abilities.Enabled == false then
			notif('PearlTP', 'Abilities are switched off right now.', 3, 'warning')
			return false
		end
		if tick() - lastThrow < (data.Cooldown or 0.2) then return false end

		local speed, gravity = meta.Speed.Max, math.abs(meta.Gravity.Y)
		-- the server launches from the root it follows, offset the way the camera that is sent faces
		local root = realRoot()
		local camera = CFrame.lookAt(gameCamera.CFrame.Position, target)
		local origin, velocity
		for _ = 1, 2 do
			origin = root.Position + camera:VectorToWorldSpace(data.Offset)
			velocity = solve(origin, target, speed, gravity)
			if not velocity then
				notif('PearlTP', 'Target is too far away for the teleorb.', 4, 'warning')
				return false
			end
			camera = CFrame.lookAlong(gameCamera.CFrame.Position, velocity.Unit)
		end

		local obstacle = getPathObstacle(origin, velocity, gravity, target)
		if obstacle and obstacle.Instance then
			notif('PearlTP', 'Obstacle in the way of the teleorb ('..obstacle.Instance.Name..')', 4, 'warning')
			return false
		end

		local container = workspace:FindFirstChild('ProjectilesContainer')
		if not container then return false end
		-- the same local projectile the game makes for a shot. its id pairs the shot with the server's
		local made, id = pcall(function()
			local shot = bedfight.ProjectilesController.new(nil, velocity, meta)
			shot:AddProjectile(meta.Projectile or data.Projectile or ITEM)
			shot.ProjectileRoot.CFrame = CFrame.lookAlong(origin, velocity.Unit)
			shot.UpdatedVelocity = velocity
			shot.Projectile.Parent = container
			return shot:Play()
		end)
		if not (made and id) then return false end

		lastThrow = tick()
		-- the server takes the switch and the throw in the order they are sent, the hotbar is left alone
		equipServer(ITEM, 'PearlTP')
		fireRemote('ShootProjectile', id, ITEM, velocity.Unit, velocity, camera)
		task.delay(0.4, syncTool, 'PearlTP')
		return true
	end

	PearlTP = vape.Categories.Utility:CreateModule({
		Name = 'PearlTP',
		Function = function(callback)
			if not callback then return end
			local target = entitylib.isAlive and getMouseTarget(inputService:GetMouseLocation())
			if not target then
				notif('PearlTP', 'No valid position under the mouse.', 3, 'warning')
				PearlTP:Toggle()
				return
			end
			throwPearl(target)
			PearlTP:Toggle()
		end,
		Tooltip = 'Throws a teleorb to the position under your mouse on the fastest arc that reaches it.\nYour hotbar is not touched.'
	})

	Limit = PearlTP:CreateToggle({Name = 'Limit to item', Tooltip = 'Only activates when you are already holding a teleorb'})
end)

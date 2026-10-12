run(function()
	local PlayerAttachModule
	local RangeSlider
	local HeightSlider
	local attachRay = RaycastParams.new()
	local lastGroundTime = tick()

	local function isValidTarget(ent)
		if not ent or not ent.Targetable or not ent.RootPart or not ent.Humanoid then
			return false
		end
		if ent.Humanoid.Health <= 0 then
			return false
		end
		if ent.Player then
			if entitylib.isFriend and entitylib.isFriend(ent.Player) then
				return false
			end
			local myPlayer = game:GetService("Players").LocalPlayer
			if myPlayer and myPlayer.Team and ent.Player.Team and myPlayer.Team == ent.Player.Team then
				return false
			end
		end
		return true
	end

	local function getTarget(myRoot)
		local closestTarget = nil
		local closestDist = RangeSlider.Value
		for _, ent in ipairs(entitylib.List) do
			if isValidTarget(ent) then
				local dist = (ent.RootPart.Position - myRoot.Position).Magnitude
				if dist <= closestDist then
					closestDist = dist
					closestTarget = ent
				end
			end
		end
		return closestTarget
	end

	PlayerAttachModule = vape.Categories.Blatant:CreateModule({
		Name = 'PlayerAttach',
		Function = function(callback)
			frictionTable.PlayerAttach = callback or nil
			if callback then
				local tpTick, tpToggle, oldy = tick(), true
				lastGroundTime = tick()

				PlayerAttachModule:Clean(runService.PreSimulation:Connect(function(dt)
					if not entitylib.isAlive then return end
					local root = entitylib.character.RootPart
					if not root or not isnetworkowner(root) then return end

					local target = getTarget(root)
					if not target then
						lastGroundTime = tick()
						tpToggle = true
						oldy = nil
						return
					end

					local now = tick()
					local humanoid = entitylib.character.Humanoid
					if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
						lastGroundTime = now
					end
					local airTime = now - lastGroundTime

					local oscillation = (now % 0.4 < 0.2) and -1 or 1
					local mass = 1.95 + (6 * oscillation)

					local goalPos = target.RootPart.Position + Vector3.new(0, HeightSlider.Value, 0)

					if tpToggle then
						if airTime > 2 and not oldy then
							attachRay.FilterDescendantsInstances = {lplr.Character, gameCamera}
							attachRay.CollisionGroup = root.CollisionGroup
							local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), attachRay)
							if ray then
								tpToggle = false
								oldy = HeightSlider.Value
								tpTick = now + 0.11
								root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
								root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
								return
							end
						end
						root.CFrame = CFrame.lookAlong(goalPos, root.CFrame.LookVector)
					else
						if oldy then
							if tpTick < now then
								root.CFrame = CFrame.lookAlong(goalPos, root.CFrame.LookVector)
								tpToggle = true
								oldy = nil
								lastGroundTime = now
							else
								return
							end
						end
					end

					root.AssemblyLinearVelocity = Vector3.new(0, mass, 0)
				end))
			else
				if entitylib.isAlive and entitylib.character and entitylib.character.RootPart then
					entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.zero
					entitylib.character.RootPart.AssemblyAngularVelocity = Vector3.zero
				end
			end
		end,
		Tooltip = 'sticks u right above whoever u fightin so u can stay on em the whole time gng'
	})

	RangeSlider = PlayerAttachModule:CreateSlider({
		Name = 'Range',
		Min = 5,
		Max = 30,
		Default = 20,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end
	})

	HeightSlider = PlayerAttachModule:CreateSlider({
		Name = 'Height',
		Min = 0,
		Max = 20,
		Default = 10,
		Decimal = 10,
		Suffix = 'studs',
		Tooltip = 'how high above em u sit'
	})
end)
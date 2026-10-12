run(function()
	local Clutch
	local LimitItem

	local function getScaffoldBlock()
		return getScaffoldBlockForModule(LimitItem)
	end

	local lastPlace = 0
	local attempts = {}
	local offsets = {
		Vector3.zero,
		Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0),
		Vector3.new(0, 0, 3), Vector3.new(0, 0, -3),
		Vector3.new(3, 0, 3), Vector3.new(3, 0, -3),
		Vector3.new(-3, 0, 3), Vector3.new(-3, 0, -3)
	}

	local function findPlacement(root, character, now)
		local velocity = root.AssemblyLinearVelocity
		local lead = math.clamp(lplr:GetNetworkPing() + 0.05, 0.05, 0.15)
		local horizontal = velocity * Vector3.new(1, 0, 1) * lead
		if horizontal.Magnitude > 3 then horizontal = horizontal.Unit * 3 end
		local feet = root.Position - Vector3.new(0, character.HipHeight + 1.5, 0)
		local predicted = roundPos(feet + horizontal)
		local current = roundPos(feet)
		local best, bestDistance
		for _, center in {predicted, current} do
			for _, offset in offsets do
				local target = center + offset
				local key = tostring(target)
				local distance = (target - (feet + horizontal)).Magnitude
				if (target - root.Position).Magnitude <= 12
					and not getPlacedBlock(target)
					and (not attempts[key] or now - attempts[key] >= 0.15)
					and checkFaceAdjacent(target)
					and (not bestDistance or distance < bestDistance) then
					best, bestDistance = target, distance
				end
			end
		end
		return best
	end

	Clutch = vape.Categories.World:CreateModule({
		Name = 'Clutch',
		Tooltip = 'Places nearby supported blocks along your fall path to catch you',
		Function = function(callback)
			if callback then
				lastPlace = 0
				table.clear(attempts)
				Clutch:Clean(entitylib.Events.LocalAdded:Connect(function()
					lastPlace = 0
					table.clear(attempts)
				end))
				Clutch:Clean(runService.Heartbeat:Connect(function()
					if not Clutch.Enabled or not entitylib.isAlive then return end
					local character = entitylib.character
					local root = character and character.RootPart
					local humanoid = character and character.Humanoid
					if not root or not root.Parent or not humanoid or humanoid.Health <= 0 then return end
					if root.AssemblyLinearVelocity.Y >= -15 or humanoid.FloorMaterial ~= Enum.Material.Air then return end
					local wool = getScaffoldBlock()
					if not wool then return end
					local now = os.clock()
					if now - lastPlace < 0.05 then return end
					for key, stamp in attempts do
						if now - stamp > 1 then attempts[key] = nil end
					end
					local target = findPlacement(root, character, now)
					if target then
						lastPlace = now
						attempts[tostring(target)] = now
						bedwars.placeBlock(target, wool, false)
					end
				end))
			else
				lastPlace = 0
				table.clear(attempts)
			end
		end,
	})

	LimitItem = Clutch:CreateToggle({
		Name = 'Limit to items',
		Default = false,
	})
end)
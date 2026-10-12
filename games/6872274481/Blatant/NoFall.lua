run(function()
	local NoFall
	local Chance
	local voidParams = RaycastParams.new()
	voidParams.FilterType = Enum.RaycastFilterType.Exclude
	voidParams.IgnoreWater = true
	local lastVoidCheck = 0
	local cachedVoid = false

	local voidOffsets = {
		Vector3.new(0, 0, 0),
		Vector3.new(2, 0, 0),
		Vector3.new(-2, 0, 0),
		Vector3.new(0, 0, 2),
		Vector3.new(0, 0, -2)
	}

	local function nearVoid(position)
		if not entitylib.isAlive then return false end
		local now = tick()
		if (now - lastVoidCheck) < 0.1 then
			return cachedVoid
		end
		lastVoidCheck = now
		voidParams.FilterDescendantsInstances = {entitylib.character.Character, gameCamera}

		local down = Vector3.new(0, -600, 0)
		for _, off in voidOffsets do
			if workspace:Raycast(position + off, down, voidParams) then
				cachedVoid = false
				return false
			end
		end

		cachedVoid = true
		return true
	end

	NoFall = vape.Categories.Blatant:CreateModule({
		Name = 'NoFall',
		Function = function(callback)
			if callback then
				NoFall:Clean(runService.Heartbeat:Connect(function(dt)
					if entitylib.isAlive and store.matchState == 1 then
						local root = entitylib.character.RootPart
						local v = root.Velocity

						if root.Velocity.Y < -35 and not nearVoid(root.Position) then
							if math.random(1, 100) <= Chance.Value then
								root.Velocity = Vector3.new(0,2.5,0)
								entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
								runService.PreRender:Wait()
								root.Velocity = v
							end
						end
					end
				end))

				NoFall:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					local animator = char.Humanoid:WaitForChild('Animator', 1)
					if animator and NoFall.Enabled then
						task.wait(.5)
						NoFall:Toggle()
						NoFall:Toggle()
					end
				end))
			end
		end,
		Tooltip = 'Take no fall damage.'
	})

	Chance = NoFall:CreateSlider({
		Name = 'Chance',
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)
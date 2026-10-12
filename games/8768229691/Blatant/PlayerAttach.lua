run(function()
	local PlayerAttach
	local Targets
	local Range
	local Height
	local lastGround
	local attached = false
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	local blockCheck = RaycastParams.new()
	blockCheck.FilterType = Enum.RaycastFilterType.Include

	local function onBlock(position, distance)
		local container = workspace:FindFirstChild('BlockContainer')
		if not container then return nil end
		blockCheck.FilterDescendantsInstances = {container}
		return workspace:Raycast(position, Vector3.new(0, -distance, 0), blockCheck)
	end

	-- puts you back on something solid once there is nobody to stick to
	local function release()
		if not attached then return end
		attached = false
		store.playerAttach = nil
		store.attached = nil
		if not entitylib.isAlive or store.split or outranked('playerAttach') then return end
		local hit = onBlock(realRoot().Position, 80)
		local position = hit and hit.Position + Vector3.new(0, entitylib.character.HipHeight + 0.2, 0) or lastGround
		if position then
			sendRoot(position)
		end
	end

	PlayerAttach = vape.Categories.Blatant:CreateModule({
		Name = 'PlayerAttach',
		Tooltip = 'Attaches you to the nearest target',
		Function = function(call)
			if call then
				PlayerAttach:Clean(entitylib.Events.LocalRemoved:Connect(function()
					attached = false
					store.playerAttach = nil
					lastGround = nil
				end))
				local plr, nextScan = nil, 0
				local function sortHealth(a, b)
					return a.Entity.Health < b.Entity.Health
				end
				repeat
					if entitylib.isAlive and not outranked('playerAttach') then
						local root = bodyRoot()
						if not attached and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and onBlock(root.Position, entitylib.character.HipHeight + 3) then
							lastGround = root.Position
						end
						if tick() >= nextScan then
							nextScan = tick() + 0.1
							plr = entitylib.AllPosition({
								Range = attached and Range.Value + Height.Value or Range.Value,
								Wallcheck = Targets.Walls.Enabled or nil,
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								Priority = Targets.Priority and Targets.Priority.Value,
								NPCs = Targets.NPCs.Enabled,
								Limit = 1,
								Sort = sortHealth
							})[1]
						end
						if plr and plr.RootPart and plr.RootPart.Parent and isnetworkowner(realRoot()) then
							attached = true
							store.playerAttach = true
							store.attached = plr
							if Height.Value > 0 then
								sendRoot(attachPosition(plr, Height.Value))
							else
								rayCheck.FilterDescendantsInstances = {plr.RootPart.Parent, lplr.Character}
								sendRoot(attachPosition(plr, 0) + (not workspace:Raycast(plr.RootPart.Position, plr.RootPart.CFrame.LookVector, rayCheck) and (plr.RootPart.CFrame.LookVector * 1.4) or Vector3.zero))
							end
						else
							release()
						end
					else
						plr = nil
						if attached then
							store.attached = nil
						end
						attached = false
						store.playerAttach = nil
					end
					task.wait()
				until not PlayerAttach.Enabled
			else
				release()
			end
		end
	})

	Targets = PlayerAttach:CreateTargets({
		Players = true,
		NPCs = true
	})

	Range = PlayerAttach:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 100,
		Default = 23,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	Height = PlayerAttach:CreateSlider({
		Name = 'Height',
		Min = 0,
		Max = 17,
		Default = 0,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far above the target you stay. Their hits stop reaching at 14, yours land from up to 17.'
	})
end)

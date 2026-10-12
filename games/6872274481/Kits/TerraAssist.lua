run(function()
	local TerraAssist
	local TATargets
	local TAFOV
	local TARange
	local TASort
	local terraOldNC

	TerraAssist = vape.Categories.Kits:CreateModule({
		Name = 'TerraAssist',
		Tooltip = 'pa for terra',
		Function = function(callback)
			if callback then
				local tryBlockKick
				pcall(function()
					tryBlockKick = replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged:FindFirstChild('TryBlockKick')
				end)
				if not tryBlockKick then
					notif('TerraAssist', 'terra kick remote not found', 3, 'warning')
					if TerraAssist.Enabled then TerraAssist:Toggle() end
					return
				end

				local terraAim = nil

				local targetThread = task.spawn(function()
					while TerraAssist.Enabled do
						local aim = nil
						local root = entitylib.isAlive and entitylib.character and entitylib.character.RootPart
						if root then
							local origin = root.Position
							local ent = entitylib.EntityMouse({
								Part = 'RootPart',
								Range = TAFOV.Value,
								Players = TATargets.Players.Enabled,
								NPCs = TATargets.NPCs and TATargets.NPCs.Enabled or false,
								Wallcheck = TATargets.Walls.Enabled,
								Origin = origin,
							}) or entitylib.EntityPosition({
								Origin = origin,
								Range = TARange.Value,
								Part = 'RootPart',
								Players = TATargets.Players.Enabled,
								NPCs = TATargets.NPCs and TATargets.NPCs.Enabled or false,
								Wallcheck = TATargets.Walls.Enabled,
								Sort = sortmethods[TASort.Value],
							})
							if ent and ent.RootPart then
								local targetPos = ent.RootPart.Position
								local targetVel = ent.RootPart.AssemblyLinearVelocity or ent.RootPart.Velocity or Vector3.zero
								local dist = (targetPos - origin).Magnitude
								local travelTime = math.clamp(dist / 40, 0, 0.4)
								local predictedPos = targetPos + targetVel * travelTime
								local aimPoint = predictedPos + Vector3.new(0, 3, 0)
								local dir = aimPoint - origin
								if dir.Magnitude > 0 then
									dir = dir.Unit
									aim = {
										direction = dir,
										originPosition = origin + Vector3.new(0, 2, 0) + dir * 2,
									}
								end
							end
						end
						terraAim = aim
						task.wait()
					end
				end)

				terraOldNC = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
					if self == tryBlockKick and getnamecallmethod() == 'FireServer' then
						if TerraAssist.Enabled and terraAim then
							local argsTable = ...
							if type(argsTable) == 'table' then
								argsTable.direction = terraAim.direction
								argsTable.originPosition = terraAim.originPosition
							end
						end
					end
					return terraOldNC(self, ...)
				end))

				TerraAssist:Clean(function()
					if terraOldNC then
						hookmetamethod(game, '__namecall', terraOldNC)
						terraOldNC = nil
					end
				end)
				TerraAssist:Clean(function()
					if targetThread then
						task.cancel(targetThread)
						targetThread = nil
					end
				end)
			end
		end,
	})

	TATargets = TerraAssist:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = false,
	})

	TAFOV = TerraAssist:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 800,
		Default = 200,
	})

	TARange = TerraAssist:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 100,
		Default = 60,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
	})

	TASort = TerraAssist:CreateDropdown({
		Name = 'Sort',
		List = getSortList({'Distance', 'Cursor'}),
	})
end)
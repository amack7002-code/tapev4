run(function()
	local AutoEldric
	local Targets
	local Range

	local function startLoop()
		task.spawn(function()
			repeat task.wait() until Range and Targets
			local lastTarget = nil
			repeat
				if not entitylib.isAlive then
					lastTarget = nil
					task.wait(0.1)
					continue
				end
				local range = Range.Value
				if store.hand.tool and store.hand.tool.Name == 'warlock_staff' then
					if lastTarget then
						local hum = lastTarget:FindFirstChildOfClass('Humanoid')
						local root = lastTarget:FindFirstChild('HumanoidRootPart')
						local inRange = root and (root.Position - entitylib.character.RootPart.Position).Magnitude <= range
						if not hum or hum.Health <= 0 or not lastTarget.Parent or not inRange then
							lastTarget = nil
						end
					end
					if not lastTarget then
						local plr = entitylib.EntityPosition({
							Range = range,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled,
							Sort = sortmethods.Distance
						})
						if plr and plr.Character then
							lastTarget = plr.Character
							pcall(function() bedwars.AbilityController:useAbility("WARLOCK_LINK") end)
							task.wait(0.1)
							pcall(function()
								bedwars.Client:Get(remotes.WarlockTarget):CallServer({ target = lastTarget })
							end)
						end
					end
				else
					lastTarget = nil
				end
				task.wait(0.3)
			until not AutoEldric.Enabled
		end)
	end

	AutoEldric = vape.Categories.Kits:CreateModule({
		Name = 'AutoEldric',
		Function = function(callback)
			if callback then startLoop() end
		end,
		Tooltip = 'auto links enemies with the warlock staff'
	})

	Targets = AutoEldric:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	Range = AutoEldric:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 10
	})
end)
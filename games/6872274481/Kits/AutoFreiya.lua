run(function()
	local AutoFreiya
	local Targets
	local Range

	local useAbilityRemote = replicatedStorage:WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events"):WaitForChild("useAbility")

	local function startLoop()
		task.spawn(function()
			repeat task.wait() until Range
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				local root = entitylib.character.RootPart.Position
				for _, ent in entitylib.List do
					if not AutoFreiya.Enabled then break end
					if ent.Targetable and ent.Character and ent.RootPart then
						local isPlayer = ent.Player ~= nil
						if (isPlayer and Targets.Players.Enabled) or (not isPlayer and Targets.NPCs.Enabled) then
							if (ent.RootPart.Position - root).Magnitude <= Range.Value then
								local stacks = ent.Character:GetAttribute('IceQueenStacks') or 0
								if stacks >= 4 then
									pcall(function() useAbilityRemote:FireServer("ice_queen") end)
									task.wait(0.5)
									break
								end
							end
						end
					end
				end
				task.wait(0.1)
			until not AutoFreiya.Enabled
		end)
	end

	AutoFreiya = vape.Categories.Kits:CreateModule({
		Name = 'AutoFreiya',
		Function = function(callback)
			if callback then startLoop() end
		end,
		Tooltip = 'auto pops freiya ability when a enemy hits 4 stacks'
	})

	Targets = AutoFreiya:CreateTargets({
		Players = true,
		NPCs = true
	})
	Range = AutoFreiya:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30
	})
end)
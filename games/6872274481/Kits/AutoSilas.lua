run(function()
	local AutoSilas
	local Damage
	local Targets
	local DamageRange
	local Heal
	local HealThreshold

	local useAbilityRemote = replicatedStorage:WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events"):WaitForChild("useAbility")

	local function getCurrentAura()
		return lplr:GetAttribute("LeaderAuraType")
	end

	local function startLoop()
		task.spawn(function()
			repeat task.wait() until Damage and Heal and DamageRange and HealThreshold and Targets
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				local hum = entitylib.character.Humanoid
				if Heal.Enabled and hum and hum.MaxHealth > 0 then
					local pct = (hum.Health / hum.MaxHealth) * 100
					if pct <= HealThreshold.Value then
						useAbilityRemote:FireServer("rebellion_shield")
						if getCurrentAura() ~= "healing" then
							useAbilityRemote:FireServer("rebellion_aura_swap")
						end
						task.wait(0.1)
						continue
					end
				end
				if Damage.Enabled then
					local plr = entitylib.EntityPosition({
						Range = DamageRange.Value,
						Part = "RootPart",
						Players = true,
						NPCs = false,
						Wallcheck = false,
						Sort = sortmethods.Distance
					})
					if plr and getCurrentAura() ~= "damage" then
						useAbilityRemote:FireServer("rebellion_aura_swap")
						task.wait(0.1)
					end
				end
				task.wait(0.1)
			until not AutoSilas.Enabled
		end)
	end

	AutoSilas = vape.Categories.Kits:CreateModule({
		Name = 'AutoSilas',
		Function = function(callback)
			if callback then
				startLoop()
			end
		end,
		Tooltip = 'auto uses silas auras for u'
	})

	Damage = AutoSilas:CreateToggle({
		Name = 'Damage',
		Tooltip = 'swaps to damage aura when a enemy is close',
		Function = function(callback)
			if DamageRange and DamageRange.Object then DamageRange.Object.Visible = callback end
			if Targets and Targets.Object then Targets.Object.Visible = callback end
		end
	})
	Targets = AutoSilas:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	DamageRange = AutoSilas:CreateSlider({
		Name = 'Range',
		Tooltip = 'how close a enemy gotta be gng',
		Min = 1,
		Max = 50,
		Default = 14,
		Visible = false
	})

	Heal = AutoSilas:CreateToggle({
		Name = 'Heal',
		Tooltip = 'shields + heal aura when ur hp gets low',
		Function = function(callback)
			if HealThreshold and HealThreshold.Object then HealThreshold.Object.Visible = callback end
		end
	})
	HealThreshold = AutoSilas:CreateSlider({
		Name = 'HP Threshold',
		Tooltip = 'heals when ur hp drops under this',
		Min = 1,
		Max = 100,
		Default = 40,
		Suffix = '%',
		Visible = false
	})

	task.defer(function()
		if Targets and Targets.Object then Targets.Object.Visible = Damage and Damage.Enabled end
		if DamageRange and DamageRange.Object then DamageRange.Object.Visible = Damage and Damage.Enabled end
		if HealThreshold and HealThreshold.Object then HealThreshold.Object.Visible = Heal and Heal.Enabled end
	end)
end)
run(function()
	local AutoZarrah
	local Targets
	local Range
	local gunRemote

	local function getGunRemote()
		if not gunRemote then
			pcall(function()
				gunRemote = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('HandGunFireRequest')
			end)
		end
		return gunRemote
	end

	local function fireGun(dir)
		local remote = getGunRemote()
		if not remote then return end
		pcall(function()
			remote:InvokeServer({ lookVector = dir })
			replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('hand_gun')
		end)
	end

	AutoZarrah = vape.Categories.Kits:CreateModule({
		Name = 'AutoZarrah',
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat task.wait() until Targets and Range
					repeat
						if not entitylib.isAlive then task.wait(0.1); continue end
						local plr = entitylib.EntityPosition({
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled,
							Sort = sortmethods.Distance
						})
						if plr and plr.RootPart and entitylib.character.RootPart then
							local dir = (plr.RootPart.Position - entitylib.character.RootPart.Position).Unit
							fireGun(dir)
						end
						task.wait()
					until not AutoZarrah.Enabled
				end)
			end
		end,
		Tooltip = 'auto gunblade for zarrah, shoots ur nearest target'
	})

	Targets = AutoZarrah:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})

	Range = AutoZarrah:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 40,
		Default = 10
	})
end)
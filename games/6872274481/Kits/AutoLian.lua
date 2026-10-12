run(function()
	local AutoLian
	local Targets
	local Range
	local Delay

	local dragonSwordFire = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('DragonSwordFire')

	local function startLoop()
		task.spawn(function()
			repeat task.wait() until Targets and Range and Delay
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
				if plr and plr.Character then
					pcall(function()
						dragonSwordFire:FireServer({ target = plr.Character })
					end)
					task.wait(Delay.Value)
				end
				task.wait(0.1)
			until not AutoLian.Enabled
		end)
	end

	AutoLian = vape.Categories.Kits:CreateModule({
		Name = 'AutoLian',
		Function = function(callback)
			if callback then startLoop() end
		end,
		Tooltip = 'auto swings lian dragon sword at enemies'
	})

	Targets = AutoLian:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	Range = AutoLian:CreateSlider({
		Name = 'Range',
		Tooltip = 'how close a enemy gotta be',
		Min = 1,
		Max = 18,
		Default = 14
	})
	Delay = AutoLian:CreateSlider({
		Name = 'Delay',
		Tooltip = 'wait time between swings',
		Min = 0,
		Max = 2,
		Default = 0.5,
		Decimal = 10,
		Suffix = 's'
	})
end)
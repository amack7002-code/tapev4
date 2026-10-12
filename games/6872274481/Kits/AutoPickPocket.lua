run(function()
	local AutoPickPocket
	local Targets
	local Range
	local Delay

	local function startLoop()
		task.spawn(function()
			repeat task.wait() until Targets and Range and Delay
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				local localPosition = entitylib.character.RootPart.Position
				for _, v in entitylib.List do
					if not AutoPickPocket.Enabled then break end
					if v.Targetable and v.Character and v.Player and v.RootPart then
						if Targets.Players.Enabled then
							if (v.RootPart.Position - localPosition).Magnitude <= Range.Value then
								if collectionService:HasTag(v.Character, "MimicBLockPickPocketPlayer") then
									pcall(function()
										bedwars.Client:Get(remotes.MimicBlockPickPocketPlayer).instance:InvokeServer(v.Player)
									end)
									task.wait(Delay.Value)
								end
							end
						end
					end
				end
				task.wait(0.1)
			until not AutoPickPocket.Enabled
		end)
	end

	AutoPickPocket = vape.Categories.Kits:CreateModule({
		Name = 'AutoPickPocket',
		Function = function(callback)
			if callback then startLoop() end
		end,
		Tooltip = 'auto robs players close to u'
	})

	Targets = AutoPickPocket:CreateTargets({
		Players = true
	})
	Range = AutoPickPocket:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 18,
		Default = 18
	})
	Delay = AutoPickPocket:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.5,
		Decimal = 10,
		Suffix = 's'
	})
end)
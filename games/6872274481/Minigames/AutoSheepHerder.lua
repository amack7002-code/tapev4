run(function()
	local AutoSheep
	local Delay
	local Range
	local Infinite
	
	AutoSheep = vape.Categories.Minigames:CreateModule({
		Name = 'AutoSheepHerder',
		Function = function(callback)
			if callback then
				local tameSheep = bedwars.Client:GetNamespace('SheepHerder'):Get('TameSheep')
	
				repeat
					local model = workspace:FindFirstChild('SheepModel')
					if entitylib.isAlive and model then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in model:GetChildren() do
							if v.PrimaryPart and (Infinite.Enabled or (localPosition - v.PrimaryPart.Position).Magnitude <= Range.Value) then
								if Delay.Value > 0 then
									task.wait(Delay.Value)
								end
								tameSheep:SendToServer(v.SheepData.Value)
							end
						end
					end
					task.wait(0.1)
				until not AutoSheep.Enabled
			end
		end,
		Tooltip = 'auto tames sheep'
	})
	Range = AutoSheep:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 200,
		Default = 20,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoSheep:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100
	})
end)
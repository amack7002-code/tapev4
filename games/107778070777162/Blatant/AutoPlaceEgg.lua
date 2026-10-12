run(function()
	local AutoPlaceEgg

	AutoPlaceEgg = vape.Categories.Blatant:CreateModule({
		Name = 'AutoPlaceEgg',
		Function = function(callback)
			if callback then
				repeat
					task.wait(1)
					local char = lplr.Character
					local hum = char and char:FindFirstChildOfClass('Humanoid')
					local backpack = lplr:FindFirstChildOfClass('Backpack')
					local plot = PlotState.ResolvePlot()
					if hum and backpack and plot then
						local eggTool = nil
						for _, tool in char:GetChildren() do
							if tool:IsA('Tool') and EggToolDisplay.IsEggTool(tool) then
								eggTool = tool
								break
							end
						end
						if not eggTool then
							for _, tool in backpack:GetChildren() do
								if EggToolDisplay.IsEggTool(tool) then
									eggTool = tool
									hum:EquipTool(tool)
									break
								end
							end
						end
						if eggTool then
							local uid = EggToolDisplay.GetToolUid(eggTool)
							if uid then
								EggState.PlantEgg(uid, CFrame.new())
							end
						end
					end
				until not AutoPlaceEgg.Enabled
			end
		end,
		Tooltip = 'auto places an egg from ur backpack onto ur plot '
	})
end)
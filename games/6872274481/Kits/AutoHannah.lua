run(function()
	local AutoHannah
	local Sort
	local Distance
	local Void
	local KATarget 

	AutoHannah = vape.Categories.Kits:CreateModule({
		Name = "AutoHannah",
		Tooltip = 'autokit with more features!!',
		Function = function(callback)
			if callback then
				task.spawn(function()
					local objs = collection('HannahExecuteInteraction', AutoHannah)

					while AutoHannah.Enabled do
						task.wait(0.1)
						if not entitylib.isAlive then continue end

						local localPosition = entitylib.character.RootPart.Position

						for _, v in objs do
							if not AutoHannah.Enabled then break end
							local part = not v:IsA('Model') and v or v.PrimaryPart
							if not part then continue end
							if (part.Position - localPosition).Magnitude > Distance.Value then continue end
							if Void.Enabled and isAboveVoid(part.Position) then continue end
							local success = bedwars.Client:Get(remotes.HannahPromptTrigger).instance:InvokeServer({
								user = lplr,
								victimEntity = v
							})
							if success then
								local icon = v:FindFirstChild('Hannah Execution Icon')
								if icon then icon:Destroy() end
							end
							task.wait(0.05)
						end
					end
				end)
			end
		end
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sort = AutoHannah:CreateDropdown({Name = 'Sort', List = methods})
	Distance = AutoHannah:CreateSlider({
		Name = "Distance",
		Min = 0,
		Max = 16,
		Default = 12,
		Suffix = 'studs'
	})
	Void = AutoHannah:CreateToggle({
		Name = 'Void',
		Tooltip = 'doesnt use ability if player is falling in the void',
		Default = true,
	})
	KATarget = AutoHannah:CreateToggle({
		Name = 'Use KA Target',
		Default = false,
	})
end)
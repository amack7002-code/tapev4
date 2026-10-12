run(function()
	local AutoUmbra
	local Delay

	AutoUmbra = vape.Categories.Kits:CreateModule({
		Name = 'AutoUmbra',
		Function = function(callback)
			if callback then
				repeat task.wait() until Delay
				task.spawn(function()
					local notifApp = lplr.PlayerGui:WaitForChild('NotificationApp', 10)
					if not notifApp then return end
					AutoUmbra:Clean(notifApp.DescendantAdded:Connect(function(desc)
						if not AutoUmbra.Enabled then return end
						if desc:IsA("TextLabel") then
							local txt = string.lower(desc.Text)
							if string.find(txt, "teleport") then
								task.spawn(function()
									if Delay.Value > 0 then task.wait(Delay.Value) end
									for _ = 1, 10 do
										if not AutoUmbra.Enabled then break end
										if bedwars.AbilityController:canUseAbility('HATTER_TELEPORT') then
											bedwars.AbilityController:useAbility('HATTER_TELEPORT')
											break
										end
										task.wait(0.05)
									end
								end)
							end
						end
					end))
				end)
			end
		end,
		Tooltip = 'auto teleports for umbra when the game says so'
	})

	Delay = AutoUmbra:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.05,
		Decimal = 100,
		Suffix = 's'
	})
end)
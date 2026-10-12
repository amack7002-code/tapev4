run(function()
	local FastPickup
	local FastPickupDelay
	local PickupRemote = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('PickupItemDrop')

	FastPickup = vape.Categories.Blatant:CreateModule({
		Name = 'FastPickup',
		Tooltip = 'picks up items fast asl',
		Function = function(callback)
			if callback then
				cleanThread(FastPickup, task.spawn(function()
					while FastPickup.Enabled do
						if entitylib.isAlive then
							for _, drop in pairs(workspace:WaitForChild('ItemDropsCache'):GetChildren()) do
								task.spawn(function()
									task.wait(FastPickupDelay.Value)
									pcall(function()
										PickupRemote:InvokeServer({ itemDrop = drop })
									end)
								end)
							end
						end
						task.wait(0.05)
					end
				end))
			end
		end,
	})

	FastPickupDelay = FastPickup:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 0.5,
		Default = 0,
		Decimal = 100,
		Suffix = 's',
	})
end)
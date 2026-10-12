run(function()
	local InfiniteSigrid
	local Kit = 'elk_master'
	local running = false

	InfiniteSigrid = vape.Categories.Kits:CreateModule({
		Name = 'InfiniteSigrid',
		Tooltip = 'ride yo shitty ass elk forever',
		Function = function(call)
			if call then
				if running then return end
				running = true
				task.spawn(function()
					repeat
						if entitylib.isAlive then
							if store.equippedKit == Kit then
								local Mount = bedwars.Client:Get('ElkKitMounted')
								if Mount then
									Mount:SendToServer()
								end
							end
						end
						task.wait(0.1)
					until not InfiniteSigrid.Enabled or not running
					running = false
				end)
			else
				running = false
			end
		end
	})
end)
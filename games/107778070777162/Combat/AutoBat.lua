run(function()
	local AutoBat
	local conn = nil
	local AutoBat
	AutoBat = vape.Categories.Combat:CreateModule({
		Name = 'AutoBat',
		Function = function(callback)
			if callback then
				local last = tick()
				conn = runService.Heartbeat:Connect(function()
					local target = getClosestPlayer()
					if target and tick() - last >= 0.1 and canUseTool() then
						if batSwingRemote then
							batSwingRemote:FireServer(target, createSeed())
						end
						last = tick()
					end
				end)
			else
				if conn then
					conn:Disconnect()
					conn = nil
				end
			end
		end,
		Tooltip = 'auto swings the bat on the closest player near u '
	})
end)
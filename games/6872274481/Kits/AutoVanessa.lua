run(function()
	local AutoVanessa
	local oldGetChargeTime
	local lastChargeTime = 0
	
	AutoVanessa = vape.Categories.Kits:CreateModule({
		Name = 'AutoVanessa',
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat task.wait() until bedwars.TripleShotProjectileController
					
					if bedwars.TripleShotProjectileController then
						oldGetChargeTime = bedwars.TripleShotProjectileController.getChargeTime
						
						bedwars.TripleShotProjectileController.getChargeTime = function(self)
							return 0
						end
						
						bedwars.TripleShotProjectileController.overchargeStartTime = tick()
					end
				end)
			else
				if oldGetChargeTime and bedwars.TripleShotProjectileController then
					bedwars.TripleShotProjectileController.getChargeTime = oldGetChargeTime
				end
				lastChargeTime = 0
			end
		end,
		Tooltip = 'auto charges Vanessa triple shot'
	})
end)
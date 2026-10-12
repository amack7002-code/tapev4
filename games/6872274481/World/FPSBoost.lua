run(function()
	local FPSBoost
	local Kill
	local Visualizer
	local effects, util = {}, {}
	local originalAddGameNametag
	local nametagHooked = false
	
	FPSBoost = vape.Categories.World:CreateModule({
		Name = 'FPSBoost',
		Function = function(callback)
			if callback then
				if Kill.Enabled then
					for i, v in bedwars.KillEffectController.killEffects do
						if not i:find('Custom') then
							effects[i] = v
							bedwars.KillEffectController.killEffects[i] = {
								new = function() 
									return {
										onKill = function() end, 
										isPlayDefaultKillEffect = function() 
											return true 
										end
									} 
								end
							}
						end
					end
				end

			if Visualizer.Enabled then
				local keepKeys = {'beam', 'Beam', 'projectile', 'Projectile', 'draw', 'Draw', 'line', 'Line', 'ray', 'Ray', 'arc', 'Arc'}
				for i, v in bedwars.VisualizerUtils do
					local keep = false
					for _, k in keepKeys do
						if tostring(i):lower():find(k:lower()) then
							keep = true
							break
						end
					end
					if not keep then
						util[i] = v
						bedwars.VisualizerUtils[i] = function() end
					end
				end
			end

			else
				for i, v in effects do 
					bedwars.KillEffectController.killEffects[i] = v 
				end
				
				for i, v in util do 
					bedwars.VisualizerUtils[i] = v 
				end
				
				if nametagHooked and originalAddGameNametag then
					bedwars.NametagController.addGameNametag = originalAddGameNametag
					nametagHooked = false
				end
				
				table.clear(effects)
				table.clear(util)
			end
		end,
		Tooltip = 'improves fps - well tries'
	})
	
	Kill = FPSBoost:CreateToggle({
		Name = 'Kill Effects',
		Function = function()
			if FPSBoost.Enabled then
				FPSBoost:Toggle()
				FPSBoost:Toggle()
			end
		end,
		Default = true
	})
	
	Visualizer = FPSBoost:CreateToggle({
		Name = 'Visualizer',
		Function = function()
			if FPSBoost.Enabled then
				FPSBoost:Toggle()
				FPSBoost:Toggle()
			end
		end,
		Default = true
	})
end)
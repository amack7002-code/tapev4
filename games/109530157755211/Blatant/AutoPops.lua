run(function()
	AutoPops = vape.Categories.Blatant:CreateModule({
		Name = 'AutoPops',
		Function = function(callback)
			if callback then
				repeat
					task.wait(0.2)
					local ctrl = getControllers()
					if ctrl and ctrl.Pops and ctrl.Pops.live then
						for popId in ctrl.Pops.live do
							if type(popId) == 'number' then
								ctrl.Pops:_Claim(popId)
								task.wait(0.05)
							end
						end
					end
				until not AutoPops.Enabled
			end
		end,
		Tooltip = 'auto claims those pop multipliers for u'
	})
end)
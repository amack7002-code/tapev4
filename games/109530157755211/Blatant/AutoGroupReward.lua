run(function()
	AutoGroupReward = vape.Categories.Blatant:CreateModule({
		Name = 'AutoGroupReward',
		Function = function(callback)
			if callback then
				repeat
					task.wait(20)
					local ctrl = getControllers()
					if ctrl and ctrl.GroupReward and not ctrl.GroupReward:IsClaimed() then
						bridges.GroupReward:Fire({Function = 'RequestClaim', Args = {}})
					end
				until not AutoGroupReward.Enabled
			end
		end,
		Tooltip = 'auto claims the group reward for u'
	})
end)
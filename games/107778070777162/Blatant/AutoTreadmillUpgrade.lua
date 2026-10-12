run(function()
	local AutoTreadmillUpgrade

	AutoTreadmillUpgrade = vape.Categories.Blatant:CreateModule({
		Name = 'AutoTreadmillUpgrade',
		Function = function(callback)
			if callback then
				repeat
					task.wait(1)
					local save = Save.Get()
					if save then
						local nextLevel = save.TreadmillUpgradeLevel + 1
						local config = Treadmills.GetByUpgradeLevel(nextLevel)
						if config and save.Money >= config.Price then
							Remotes.Treadmill.AskTierRaise:InvokeServer(config._id)
						end
					end
				until not AutoTreadmillUpgrade.Enabled
			end
		end,
		Tooltip = 'auto buys the next treadmill speed upgrade when u can afford it '
	})
end)
run(function()
	local InfJetpack

	InfJetpack = vape.Categories.Utility:CreateModule({
		Name = 'InfJetpack',
		Function = function(callback)
			if callback then
				-- the Booster kit burns this down on your side only
				InfJetpack:Clean(runService.Heartbeat:Connect(function()
					bedfight.JetpackState.Fuel = 1
				end))
			end
		end,
		Tooltip = 'Keeps the Booster kit\'s jetpack fuel full'
	})
end)

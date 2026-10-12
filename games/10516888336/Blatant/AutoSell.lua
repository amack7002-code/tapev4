run(function()
	local AutoSell

	AutoSell = vape.Categories.Blatant:CreateModule({
		Name = 'AutoSell',
		Function = function(callback)
			if callback then
				repeat
					task.wait(1.5)
					if Network and Network.Invoke then
						Network.Invoke('DuckController_Sell', nil)
					end
				until not AutoSell.Enabled
			end
		end,
		Tooltip = 'auto sells ur ducks'
	})
end)
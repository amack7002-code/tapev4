run(function()
	local AutoEquipBest

	AutoEquipBest = vape.Categories.Blatant:CreateModule({
		Name = 'AutoEquipBest',
		Function = function(callback)
			if callback then
				repeat
					task.wait(5.1)
					Remotes.Haul.WearBest:InvokeServer()
				until not AutoEquipBest.Enabled
			end
		end,
		Tooltip = 'auto equips ur best pets for u'
	})
end)
run(function()
	vape.Categories.Blatant:CreateModule({
		Name = 'KeepSprint',
		Function = function(callback)
			debug.setconstant(bedwars.SprintController.startSprinting, 5, callback and 'blockSprinting' or 'blockSprint')
			bedwars.SprintController:stopSprinting()
		end,
		Tooltip = 'allows you to sprint with potions'
	})
end)
run(function()
	AutoTrain = vape.Categories.Blatant:CreateModule({
		Name = 'AutoTrain',
		Function = function(callback)
			if callback then
				repeat
					task.wait(0.105)
					local equipped = ensureTrainToolEquipped()
					if equipped then
						bridges.Training:Fire({Function = 'CompletePushup', Args = {1}})
					end
				until not AutoTrain.Enabled
				local ctrl = getControllers()
				if ctrl and ctrl.Training then
					ctrl.Training:SetLocked(false)
				end
				local char = lplr.Character
				local hum = char and char:FindFirstChildOfClass('Humanoid')
				if hum then
					hum:UnequipTools()
				end
			end
		end,
		Tooltip = 'auto trains for u so ur strength keeps going up gng'
	})
end)
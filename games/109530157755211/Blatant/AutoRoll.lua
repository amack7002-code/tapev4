run(function()
	local function getBestUpgrade(ctrl)
		local currentMult = 0
		if ctrl.Roll.equipped and materialsSchematic[ctrl.Roll.equipped] then
			currentMult = materialsSchematic[ctrl.Roll.equipped].StrengthMultiplier
		end
		local currentCash = getCash()
		local owned = ctrl.Roll.owned or {}
		local best = nil
		local bestMult = currentMult
		for name, data in materialsSchematic do
			if data.StrengthMultiplier > bestMult and (owned[name] or currentCash >= data.Price) then
				best = name
				bestMult = data.StrengthMultiplier
			end
		end
		return best
	end
	AutoRoll = vape.Categories.Blatant:CreateModule({
		Name = 'AutoRoll',
		Function = function(callback)
			if callback then
				repeat
					task.wait(0.5)
					local ctrl = getControllers()
					if ctrl and ctrl.Roll and not ctrl.Roll.rolling and not ctrl.Roll.buying then
						local targetMat = getBestUpgrade(ctrl)
						if targetMat then
							local chestData = nil
							for _, data in pairs(ctrl.Roll.chests) do
								if data.ready and ctrl.Roll:_Unlocked(data) then
									chestData = data
									break
								end
							end
							if chestData then
								ctrl.Roll:ForceNext(targetMat)
								ctrl.Roll:Play(chestData)
								local started = os.clock()
								repeat
									task.wait(0.1)
								until not ctrl.Roll.rolling or os.clock() - started > 5
								if ctrl.Roll.pending then
									ctrl.Roll:Buy()
								end
							end
						end
					end
				until not AutoRoll.Enabled
			end
		end,
		Tooltip = 'only buys materials stronger than what u already got equipped'
	})
end)
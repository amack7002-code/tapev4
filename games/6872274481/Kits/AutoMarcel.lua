run(function()
	local AutoMarcel
	local Delay

	local function startLoop()
		task.spawn(function()
			repeat task.wait() until Delay
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				local DefenderController = bedwars.Knit.Controllers.DefenderKitController
				if not DefenderController then task.wait(0.1); continue end
				for blockPos in DefenderController.currentSchematic do
					if not AutoMarcel.Enabled then break end
					if not entitylib.isAlive then break end
					pcall(function()
						local activeMode = bedwars.Store:getState().Kit.defenderScannerMode
						local blockType = DefenderController.currentSchematic[blockPos]
						if activeMode == 'upgrade' then
							DefenderController:requestScannerAction(blockPos, 'upgrade', blockType)
						elseif activeMode == 'refund' then
							DefenderController:requestScannerAction(blockPos, 'refund')
						else
							DefenderController:requestPlaceDefenderBlock(blockPos)
						end
					end)
					task.wait(Delay.Value)
				end
				task.wait(0.1)
			until not AutoMarcel.Enabled
		end)
	end

	AutoMarcel = vape.Categories.Kits:CreateModule({
		Name = 'AutoMarcel',
		Function = function(callback)
			if callback then startLoop() end
		end,
		Tooltip = 'auto builds ur whole defender layout'
	})

	Delay = AutoMarcel:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.05,
		Decimal = 100,
		Suffix = 's'
	})
end)
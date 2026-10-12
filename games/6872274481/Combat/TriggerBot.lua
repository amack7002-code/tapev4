run(function()
	local TriggerBot
	local CPS

	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				repeat
					local swung = false
					local hand = store.hand
					if entitylib.isAlive
						and hand and hand.tool and hand.toolType == 'sword'
						and not (bedwars.DaoController and bedwars.DaoController.chargingMaid)
						and not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
						local meta = bedwars.ItemMeta[hand.tool.Name]
						local range = meta and meta.sword and meta.sword.attackRange or 14.4
						local near = entitylib.EntityPosition({
							Range = range,
							Part = 'RootPart',
							Players = true,
							NPCs = true
						})
						if near then
							bedwars.SwordController:swingSwordAtMouse()
							swung = true
						end
					end
					task.wait(swung and 1 / CPS.GetRandomValue() or 0.05)
				until not TriggerBot.Enabled
			end
		end,
		Tooltip = 'swings ur sword on its own when someone is close'
	})

	CPS = TriggerBot:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
	})
end)
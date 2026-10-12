run(function()
	local FishermanESP
	local FishNames = {
		fish_iron = "Iron Fish",
		fish_diamond = "Diamond Fish",
		fish_emerald = "Emerald Fish",
		fish_special = "Special Fish",
		fish_gold = "Gold Fish",
	}
	
	FishermanESP = vape.Categories.Kits:CreateModule({
		Name = "FishermanESP",
		Tooltip = 'shows what fish you are catching before the minigame starts',
		Function = function(callback)		
			if callback then		
				local exp = bedwars.Client:WaitFor(remotes.FishFound):expect()
				FishermanESP:Clean(exp:Connect(function(p24)
					local scl = p24.dropData
					if scl and scl.fishModel then
						local ftype = tostring(scl.fishModel) or 'fish_iron'
						local allDrops = scl.drops
						local lootParts = {}
						if allDrops then
							local totals = {}
							local order = {}
							for _, drop in ipairs(allDrops) do
								local item = tostring(drop.itemType) or 'unknown'
								local amount = tonumber(drop.amount) or 0
								if not totals[item] then
									totals[item] = 0
									table.insert(order, item)
								end
								totals[item] = totals[item] + amount
							end
							for _, item in ipairs(order) do
								table.insert(lootParts, item .. ' x' .. math.ceil(totals[item] * 1.4))
							end
						end
						local lootText = #lootParts > 0 and table.concat(lootParts, ', ') or 'unknown'
						notif('FishermanESP', 'Your fish will be ' .. FishNames[ftype] .. ' | Loot: ' .. lootText, 12)
					end
				end))
			end
		end
	})
end)
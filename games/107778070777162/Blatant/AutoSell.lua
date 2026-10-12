run(function()
	local AutoSell

	AutoSell = vape.Categories.Blatant:CreateModule({
		Name = 'AutoSell',
		Function = function(callback)
			if callback then
				repeat
					task.wait(3)
					if KeepGoodPets.Enabled then
						local save = Save.Get(lplr, false)
						if save then
							local toSell = {}
							for uid, itemData in save.Inventory do
								local decoded = AssetItems.Decode(itemData)
								local assetInfo = Assets.Directory[decoded.Category]
								if assetInfo then
									local isGood
									if FilterMethod.Value == 'Rarity' then
										isGood = assetInfo.Rarity.RarityNumber > 2
									else
										local rate = AssetEarnings.LiveRatePerSecond(decoded, save.Gamepasses, save.Products, lplr)
										isGood = rate > 5
									end
									if not isGood then
										table.insert(toSell, uid)
									end
								end
							end
							if #toSell > 0 then
								Remotes.PetSatchel.SellSelection:FireServer({Assets = toSell, Eggs = {}})
							end
						end
					else
						Remotes.PetSatchel.SellEveryPet:FireServer()
					end
				until not AutoSell.Enabled
			end
		end,
		Tooltip = 'auto sells ur pets, turn on keep good pets to only sell junk '
	})
	KeepGoodPets = AutoSell:CreateToggle({
		Name = 'Keep Good Pets'
	})
	FilterMethod = AutoSell:CreateDropdown({
		Name = 'Filter Method',
		List = {'Rarity', 'Rate'},
		Tooltip = 'rarity - keeps stuff based on the games rarity tier\nrate - keeps stuff based on real cash per second value'
	})
end)
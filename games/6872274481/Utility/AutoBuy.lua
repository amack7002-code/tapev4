run(function()
	local AutoBuy
	local ItemShop
	local TeamUpgrade
	local WrenShop
	local GUICheck
	local ShopUICheck
	local TierCheck
	local SmartCheck
	local BedwarsCheck
	local BuySwordToggle
	local BuyArmorToggle
	local BuyAxeToggle
	local BuyPickaxeToggle
	local BuyProjectileToggle
	local BuySerpentToggle
	local BuyJumpToggle
	local BuyShieldToggle
	local BreakSpeedToggle
	local ArmorUpgradeToggle
	local DamageToggle
	local DiamondGenToggle
	local TeamGenToggle
	local BedBarrierToggle
	local PurchaseDelay
	local PurchaseLimit
	local GearPriority
	local Notifications
	local Reserves = {}
	local purchaseCooldowns = {}
	local currencySnapshots = {}
	local cyclePurchases = 0
	local Custom = {}
	local CustomPost = {}
	local ExtraUpgrades = {}
	local id

	local armors = {
		'none',
		'leather_chestplate',
		'iron_chestplate',
		'diamond_chestplate',
		'emerald_chestplate'
	}

	local axes = {
		'none',
		'wood_axe',
		'stone_axe',
		'iron_axe',
		'diamond_axe',
		'emerald_axe'
	}

	local pickaxes = {
		'none',
		'wood_pickaxe',
		'stone_pickaxe',
		'iron_pickaxe',
		'diamond_pickaxe',
		'emerald_pickaxe'
	}

	local function getSwordList()
		local list = {'wood_sword', 'stone_sword', 'iron_sword', 'diamond_sword', 'emerald_sword'}
		if store.equippedKit == 'dasher' then
			list = {'wood_dao', 'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'}
		elseif store.equippedKit == 'ice_queen' then
			list[5] = 'ice_sword'
		elseif store.equippedKit == 'ember' then
			list[5] = 'infernal_saber'
		elseif store.equippedKit == 'lumen' then
			list[5] = 'light_sword'
		end
		return list
	end

	local upgradeRemote = replicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("RequestPurchaseTeamUpgrade")
	local bedUpgradeRemote = replicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("RequestPurchaseBedTeamUpgrade")

	local function getPurchaseInventory()
		local character = entitylib.character
		if not entitylib.isAlive or not character or character.Character ~= lplr.Character
			or not character.RootPart or not character.RootPart.Parent then return nil end
		local inventory = store.inventory and store.inventory.inventory
		if not inventory or not inventory.items or not store.tools then return nil end
		return inventory
	end

	local function getCurrentArmor()
		local inventory = getPurchaseInventory()
		local armor = inventory and inventory.armor
		local chestplate = armor and armor[2]
		return type(chestplate) == 'table' and chestplate or getBestArmor(1)
	end

	local function playerOwns(itemType)
		for _, item in store.inventory.inventory.items do
			if item.itemType == itemType then return true end
		end
		if store.inventory.inventory.armor then
			for _, v in pairs(store.inventory.inventory.armor) do
				if type(v) == 'table' and v.itemType == itemType then return true end
			end
		end
		return false
	end

	local function canBuy(item, currencytable, amount)
		if not item or type(item.currency) ~= 'string' or type(item.price) ~= 'number'
			or item.price < 0 or item.price ~= item.price or item.price == math.huge then return false end
		amount = amount or 1
		if amount <= 0 or amount ~= amount or amount == math.huge then return false end
		if currencytable[item.currency] == nil then
			local currency = getItem(item.currency)
			local balance = currency and currency.amount or 0
			local snapshot = currencySnapshots[item.currency]
			if snapshot and snapshot.character == lplr.Character and snapshot.balance == balance and tick() < snapshot.expires then
				balance = math.min(balance, snapshot.remaining)
			else
				currencySnapshots[item.currency] = nil
			end
			local reserve = Reserves[item.currency]
			currencytable[item.currency] = math.max(balance - (reserve and reserve.Value or 0), 0)
		end
		if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
		if item.lockedByForge or item.disabled then return false end
		if item.disabledInQueue and table.find(item.disabledInQueue, store.queueType) then return false end
		if item.require and item.require.teamUpgrade then
			local upgrades = bedwars.Store:getState().Bedwars.teamUpgrades[lplr:GetAttribute('Team')] or {}
			if (upgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
				return false
			end
		end
		return currencytable[item.currency] >= (item.price * amount)
	end

	local function recordSpend(currency, price, currencytable)
		currencytable[currency] -= price
		local balance = getItem(currency)
		local reserve = Reserves[currency]
		currencySnapshots[currency] = {
			balance = balance and balance.amount or 0,
			remaining = currencytable[currency] + (reserve and reserve.Value or 0),
			character = lplr.Character,
			expires = tick() + 3
		}
	end

	local function buyItem(item, currencytable, shopId)
		shopId = shopId or id
		if not AutoBuy.Enabled or not getPurchaseInventory() or not shopId then return false end
		if cyclePurchases >= PurchaseLimit.Value or not canBuy(item, currencytable) then return false end
		local cooldown = purchaseCooldowns[item.itemType]
		if cooldown and cooldown.character == lplr.Character and tick() < cooldown.expires then return false end
		local character = lplr.Character
		cyclePurchases += 1
		purchaseCooldowns[item.itemType] = {character = character, expires = tick() + 5}
		-- Reserve before yielding so disabling the module cannot lose an in-flight purchase.
		recordSpend(item.currency, item.price, currencytable)
		local ok, resolved, purchased = pcall(function()
			return bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({
				shopItem = item,
				shopId = shopId
			}):timeout(3):await()
		end)
		purchaseCooldowns[item.itemType] = {character = character, expires = tick() + 2}
		local snapshot = currencySnapshots[item.currency]
		if snapshot and snapshot.character == character then snapshot.expires = tick() + 3 end
		if not ok or not resolved then
			-- Keep the reservation briefly: a timeout may still have reached the server.
			warn('[AutoBuy] purchase failed: '..tostring(ok and purchased or resolved))
			return false
		end
		if not purchased then
			if character == lplr.Character then recordSpend(item.currency, -item.price, currencytable) end
			return false
		end
		if character ~= lplr.Character then return true end
		local meta = bedwars.ItemMeta[item.itemType]
		if Notifications.Enabled then
			notif('AutoBuy', 'Bought '..(meta and meta.displayName or item.itemType), 3)
		end
		local soundManager = bedwars.SoundManager
		local purchaseSound = bedwars.SoundList and bedwars.SoundList.BEDWARS_PURCHASE_ITEM
		if soundManager and type(soundManager.playSound) == 'function' and purchaseSound then
			pcall(soundManager.playSound, soundManager, purchaseSound)
		end
		bedwars.Store:dispatch({type = 'BedwarsAddItemPurchased', itemType = item.itemType})
		if item.tiered then
			bedwars.BedwarsShopController.alreadyPurchasedMap[item.itemType] = true
		end
		return true
	end

	local function buyTool(tool, tools, currencytable)
		local buyable
		local start = 1
		if tool and tool.itemType and tool.itemType ~= 'none' then
			local ind = table.find(tools, tool.itemType)
			if not ind then return end
			start = ind + 1
		elseif tools[1] == 'none' then
			start = 2
		end

		for i = start, #tools do
			local v = bedwars.Shop.getShopItem(tools[i], lplr, {shopId = id})
			if v then
				if canBuy(v, currencytable) then
					if SmartCheck.Enabled and (bedwars.ItemMeta[tools[i]] or {}).breakBlock and i > 2 then
						if BuyArmorToggle.Enabled then
							local currentarmor = getCurrentArmor()
							currentarmor = currentarmor and currentarmor.itemType or 'none'
							if (table.find(armors, currentarmor) or 3) < 3 then break end
						end
						if BuySwordToggle.Enabled then
							if store.tools.sword and (table.find(getSwordList(), store.tools.sword.itemType) or 2) < 2 then break end
						end
					end
					buyable = v
				end
				if TierCheck.Enabled and v.nextTier then break end
			end
		end

		if buyable then
			buyItem(buyable, currencytable)
		end
	end

	local function buyUpgrade(upgradeType, currencytable)
		local upgrade = bedwars.TeamUpgradeMeta[upgradeType]
		if not upgrade or not upgrade.tiers then return end
		if upgrade.disabledInQueue and table.find(upgrade.disabledInQueue, store.queueType) then return end
		local currentUpgrades = bedwars.Store:getState().Bedwars.teamUpgrades[lplr:GetAttribute('Team')] or {}
		local currentTier = (currentUpgrades[upgradeType] or 0) + 1
		local key = 'upgrade:'..upgradeType
		local cooldown = purchaseCooldowns[key]
		if cooldown and cooldown.character == lplr.Character and tick() < cooldown.expires then return end

		for i = currentTier, #upgrade.tiers do
			if not AutoBuy.Enabled or not getPurchaseInventory() or cyclePurchases >= PurchaseLimit.Value then break end
			local tier = upgrade.tiers[i]
			if tier.availableOnlyInQueue and not table.find(tier.availableOnlyInQueue, store.queueType) then break end

			if canBuy({currency = 'diamond', price = tier.cost}, currencytable) then
				cyclePurchases += 1
				local character = lplr.Character
				purchaseCooldowns[key] = {character = character, expires = tick() + 5}
				recordSpend('diamond', tier.cost, currencytable)
				local ok, purchased = pcall(function()
					return upgradeRemote:InvokeServer(upgradeType)
				end)
				purchaseCooldowns[key] = {character = character, expires = tick() + 2}
				local snapshot = currencySnapshots.diamond
				if snapshot and snapshot.character == character then snapshot.expires = tick() + 3 end
				if not ok then
					warn('[AutoBuy] upgrade failed: '..tostring(purchased))
					break
				end
				if character ~= lplr.Character then break end
				if not purchased then
					recordSpend('diamond', -tier.cost, currencytable)
					break
				end
				if Notifications.Enabled then
					notif('AutoBuy', 'Bought '..(upgrade.name == 'Armor' and 'Protection' or upgrade.name)..' '..i, 3)
				end
			else
				break
			end
		end
	end

	local function buyProjectile(currencytable)
		if playerOwns('headhunter') or playerOwns('wood_crossbow') or playerOwns('wood_bow') then return end

		for _, itemType in {'headhunter', 'wood_crossbow', 'wood_bow'} do
			local v = bedwars.Shop.getShopItem(itemType, lplr, {shopId = id})
			if canBuy(v, currencytable) then
				buyItem(v, currencytable)
				return
			end
		end
	end

	local function getNearestShopId()
		if not entitylib.isAlive then return nil end
		if not getPurchaseInventory() then return nil end
		local localPosition = entitylib.character.RootPart.Position
		local shopId
		local nearest = 20
		for _, v in (store.shop or {}) do
			local distance = v.RootPart and v.RootPart.Parent and (v.RootPart.Position - localPosition).Magnitude
			if v.Shop and distance and distance <= nearest then
				nearest = distance
				shopId = v.Id
			end
		end
		return shopId
	end

	local function buyPotion(itemType, currencytable)
		local shopId = getNearestShopId()
		if not shopId then return end
		local ok, item = pcall(function()
			return bedwars.Shop.getShopItem(itemType, lplr, {shopId = shopId})
		end)
		if not ok then
			warn('[AutoBuy] potion lookup failed: '..tostring(item))
			return
		end
		if item and canBuy(item, currencytable) then
			buyItem(item, currencytable, shopId)
		end
	end

	local lastBedBarrierBuy = 0
	local BED_BARRIER_DURATION = 180

	local function buyBedBarrier()
		-- This remote exposes no price metadata here; do not risk spending reserved diamonds.
		if Reserves.diamond.Value > 0 then return end
		local now = tick()
		if now - lastBedBarrierBuy < BED_BARRIER_DURATION then return end
		lastBedBarrierBuy = now - BED_BARRIER_DURATION + 5
		local purchased = false
		for _, upgrade in {'bed_shield', 'bed_alarm'} do
			if not AutoBuy.Enabled or not getPurchaseInventory() or cyclePurchases >= PurchaseLimit.Value then break end
			cyclePurchases += 1
			local ok, result = pcall(function()
				return bedUpgradeRemote:InvokeServer(upgrade)
			end)
			if ok and result then purchased = true end
			if not ok then warn('[AutoBuy] bed upgrade failed: '..tostring(result)) end
		end
		if purchased then
			lastBedBarrierBuy = now
		end
	end

	local function runCustom(tab, currencytable)
		for _, entry in tab do
			if not AutoBuy.Enabled or cyclePurchases >= PurchaseLimit.Value then break end
			entry.buy(currencytable)
		end
	end

	local upgradeIds = {
		BreakSpeed = 'BREAK_SPEED',
		Armor      = 'ARMOR',
		Damage     = 'DAMAGE',
		DiamondGen = 'DIAMOND_GENERATOR',
		TeamGen    = 'TEAM_GENERATOR',
	}

	AutoBuy = vape.Categories.Utility:CreateModule({
		Name = 'AutoBuy',
		Function = function(callback)
			if callback then
				cleanThread(AutoBuy, task.spawn(function()
					repeat task.wait() until store.shopLoaded or not AutoBuy.Enabled
					if not AutoBuy.Enabled then return end
					repeat
						task.wait(PurchaseDelay.Value / 1000)
						if not AutoBuy.Enabled then break end
						if not getPurchaseInventory() then continue end
						if store.matchState == 2 then continue end
						if not store.shopLoaded then continue end
						if BedwarsCheck.Enabled and not tostring(store.queueType):find('bedwars') then continue end
						if ShopUICheck.Enabled and not (bedwars.AppController:isAppOpen('BedwarsItemShopApp') or bedwars.AppController:isAppOpen('TeamUpgradeApp')) then continue end

						local _, items, upgrades, newid = getShopNPC()
						id = newid or (not GUICheck.Enabled and '1_item_shop' or nil)
						local canItems = items or not GUICheck.Enabled
						local canUpgrades = upgrades or not GUICheck.Enabled
						local currencytable = {}
						cyclePurchases = 0

						if canItems then
							runCustom(Custom, currencytable)
						end

						if ItemShop.Enabled and canItems then
							local function buyArmor()
								if BuyArmorToggle.Enabled then buyTool(getCurrentArmor(), armors, currencytable) end
							end
							local function buySword()
								if BuySwordToggle.Enabled then buyTool(store.tools.sword, getSwordList(), currencytable) end
							end
							if GearPriority.Value == 'Sword First' then
								buySword()
								buyArmor()
							else
								buyArmor()
								buySword()
							end
							if BuyAxeToggle.Enabled then
								buyTool(store.tools.wood or {itemType = 'none'}, axes, currencytable)
							end
							if BuyPickaxeToggle.Enabled then
								buyTool(store.tools.stone, pickaxes, currencytable)
							end
							if BuyProjectileToggle.Enabled then
								buyProjectile(currencytable)
							end
						end

						if TeamUpgrade.Enabled and canUpgrades then
							if BreakSpeedToggle.Enabled   then buyUpgrade(upgradeIds.BreakSpeed, currencytable) end
							if ArmorUpgradeToggle.Enabled then buyUpgrade(upgradeIds.Armor, currencytable) end
							if DamageToggle.Enabled        then buyUpgrade(upgradeIds.Damage, currencytable) end
							if DiamondGenToggle.Enabled    then buyUpgrade(upgradeIds.DiamondGen, currencytable) end
							if TeamGenToggle.Enabled       then buyUpgrade(upgradeIds.TeamGen, currencytable) end
							for _, v in ExtraUpgrades do
								if v.toggle.Enabled then buyUpgrade(v.id, currencytable) end
							end
							if BedBarrierToggle.Enabled then buyBedBarrier() end
						end

						if WrenShop.Enabled then
							if BuySerpentToggle.Enabled then buyPotion('serpents_touch_potion', currencytable) end
							if BuyJumpToggle.Enabled then buyPotion('jump_potion', currencytable) end
							if BuyShieldToggle.Enabled then buyPotion('mini_shield', currencytable) end
						end

						if canItems then
							runCustom(CustomPost, currencytable)
						end
					until not AutoBuy.Enabled
				end))
			end
		end,
		Tooltip = 'auto buys from the shops u turn on when ur near them'
	})

	PurchaseDelay = AutoBuy:CreateSlider({
		Name = 'Purchase Delay', Min = 200, Max = 2000, Default = 500, Suffix = 'ms',
		Tooltip = 'time between purchase cycles'
	})
	PurchaseLimit = AutoBuy:CreateSlider({
		Name = 'Purchases Per Cycle', Min = 1, Max = 10, Default = 4,
		Tooltip = 'maximum purchase requests per cycle, including failed attempts'
	})
	GearPriority = AutoBuy:CreateDropdown({
		Name = 'Gear Priority', List = {'Armor First', 'Sword First'}, Default = 'Armor First'
	})
	Notifications = AutoBuy:CreateToggle({Name = 'Purchase Notifications', Default = true})
	for _, currency in {'iron', 'diamond', 'emerald'} do
		Reserves[currency] = AutoBuy:CreateSlider({
			Name = currency:sub(1, 1):upper()..currency:sub(2)..' Reserve',
			Min = 0, Max = currency == 'iron' and 200 or 40, Default = 0,
			Tooltip = 'keep this much '..currency..'; a diamond reserve also pauses bed barrier purchases'
		})
	end

	ItemShop = AutoBuy:CreateToggle({
		Name = 'Item Shop',
		Default = true,
		Tooltip = 'buys gear from the item shop when ur near it',
		Function = function(v)
			if BuySwordToggle       then BuySwordToggle.Object.Visible       = v end
			if BuyArmorToggle       then BuyArmorToggle.Object.Visible       = v end
			if BuyAxeToggle         then BuyAxeToggle.Object.Visible         = v end
			if BuyPickaxeToggle     then BuyPickaxeToggle.Object.Visible     = v end
			if BuyProjectileToggle  then BuyProjectileToggle.Object.Visible  = v end
		end
	})

	TeamUpgrade = AutoBuy:CreateToggle({
		Name = 'Team Upgrade',
		Default = false,
		Tooltip = 'buys team upgrades when ur near the upgrade shop',
		Function = function(v)
			if BreakSpeedToggle   then BreakSpeedToggle.Object.Visible   = v end
			if ArmorUpgradeToggle then ArmorUpgradeToggle.Object.Visible = v end
			if DamageToggle       then DamageToggle.Object.Visible       = v end
			if DiamondGenToggle   then DiamondGenToggle.Object.Visible   = v end
			if TeamGenToggle      then TeamGenToggle.Object.Visible      = v end
			if BedBarrierToggle   then BedBarrierToggle.Object.Visible   = v end
			for _, t in ExtraUpgrades do
				if t.toggle.Object then t.toggle.Object.Visible = v end
			end
		end
	})

	WrenShop = AutoBuy:CreateToggle({
		Name = 'Wren Shop',
		Default = false,
		Tooltip = 'buys potions from the wren shop gng',
		Function = function(v)
			if BuySerpentToggle then BuySerpentToggle.Object.Visible = v end
			if BuyJumpToggle    then BuyJumpToggle.Object.Visible    = v end
			if BuyShieldToggle  then BuyShieldToggle.Object.Visible  = v end
		end
	})

	GUICheck = AutoBuy:CreateToggle({
		Name = 'GUI Check',
		Default = true,
		Tooltip = 'only buys when ur near the shop'
	})

	ShopUICheck = AutoBuy:CreateToggle({
		Name = 'Shop UI Check',
		Tooltip = 'only buys while the shop menu is open'
	})

	TierCheck = AutoBuy:CreateToggle({
		Name = 'Tier Check',
		Tooltip = 'only buys one tool tier at a time'
	})

	SmartCheck = AutoBuy:CreateToggle({
		Name = 'Smart Check',
		Default = true,
		Tooltip = 'Buys iron armor before iron axe'
	})

	BedwarsCheck = AutoBuy:CreateToggle({
		Name = 'Only Bedwars',
		Default = true,
		Tooltip = 'only buys in bedwars queues'
	})

	BuySwordToggle       = AutoBuy:CreateToggle({Name = 'Buy Sword',        Default = false, Darker = true})
	BuyArmorToggle       = AutoBuy:CreateToggle({Name = 'Buy Armor',        Default = true,  Darker = true})
	BuyAxeToggle         = AutoBuy:CreateToggle({Name = 'Buy Axe',          Default = false, Darker = true})
	BuyPickaxeToggle     = AutoBuy:CreateToggle({Name = 'Buy Pickaxe',      Default = false, Darker = true})
	BuyProjectileToggle  = AutoBuy:CreateToggle({Name = 'Buy Projectile',   Default = false, Darker = true})
	BuySerpentToggle     = AutoBuy:CreateToggle({Name = 'Buy Serpent Potion', Default = false, Darker = true})
	BuyJumpToggle        = AutoBuy:CreateToggle({Name = 'Buy Jump Potion',  Default = false, Darker = true})
	BuyShieldToggle      = AutoBuy:CreateToggle({Name = 'Buy Shield Potion', Default = false, Darker = true})
	BreakSpeedToggle     = AutoBuy:CreateToggle({Name = 'Break Speed',      Default = false, Darker = true})
	ArmorUpgradeToggle   = AutoBuy:CreateToggle({Name = 'Armor',            Default = false, Darker = true})
	DamageToggle         = AutoBuy:CreateToggle({Name = 'Damage',           Default = false, Darker = true})
	DiamondGenToggle     = AutoBuy:CreateToggle({Name = 'Diamond Gen',      Default = false, Darker = true})
	TeamGenToggle        = AutoBuy:CreateToggle({Name = 'Team Gen',         Default = false, Darker = true})
	BedBarrierToggle     = AutoBuy:CreateToggle({Name = 'Bed Barrier',      Default = false, Darker = true})

	local coveredUpgrades = {}
	for _, v in upgradeIds do
		coveredUpgrades[v] = true
	end
	for i, v in bedwars.TeamUpgradeMeta do
		if not coveredUpgrades[i] then
			table.insert(ExtraUpgrades, {
				id = i,
				toggle = AutoBuy:CreateToggle({
					Name = 'Buy '..(v.name == 'Armor' and 'Protection' or v.name),
					Darker = true
				})
			})
		end
	end

	AutoBuy:CreateTextList({
		Name = 'Item',
		Placeholder = 'priority/item/amount/after',
		Function = function(list)
			table.clear(Custom)
			table.clear(CustomPost)
			for _, entry in list do
				local tab = entry:split('/')
				local ind = tonumber(tab[1])
				if ind and ind == ind and math.abs(ind) ~= math.huge and tab[2] and tab[2] ~= '' then
					local target = tab[4] and tab[4] ~= '' and CustomPost or Custom
					table.insert(target, {priority = ind, order = #target + 1, buy = function(currencytable)
						local v = bedwars.Shop.getShopItem(tab[2], lplr, {shopId = id})
						if not v then return end
						local amount = tonumber(tab[3]) or 1
						local woolName = (tab[2] == 'wool_white' and bedwars.Shop.getTeamWool) and bedwars.Shop.getTeamWool(lplr:GetAttribute('Team')) or tab[2]
						local item = getItem(woolName or tab[2])
						local bundle = v.amount or 1
						if type(bundle) ~= 'number' or bundle <= 0 or bundle ~= bundle or bundle == math.huge
							or amount <= 0 or amount ~= amount or amount == math.huge then return end
						local count = math.ceil(math.max(amount - (item and item.amount or 0), 0) / bundle)
						if count > 0 and canBuy(v, currencytable) then
							-- Refill incrementally; wait for inventory replication before buying this item again.
							buyItem(v, currencytable)
						end
					end})
				end
			end
			for _, target in {Custom, CustomPost} do
				table.sort(target, function(a, b)
					return a.priority < b.priority or (a.priority == b.priority and a.order < b.order)
				end)
			end
		end
	})

	task.defer(function()
		if BuySwordToggle       and BuySwordToggle.Object       then BuySwordToggle.Object.Visible       = ItemShop.Enabled end
		if BuyArmorToggle       and BuyArmorToggle.Object       then BuyArmorToggle.Object.Visible       = ItemShop.Enabled end
		if BuyAxeToggle         and BuyAxeToggle.Object         then BuyAxeToggle.Object.Visible         = ItemShop.Enabled end
		if BuyPickaxeToggle     and BuyPickaxeToggle.Object     then BuyPickaxeToggle.Object.Visible     = ItemShop.Enabled end
		if BuyProjectileToggle  and BuyProjectileToggle.Object  then BuyProjectileToggle.Object.Visible  = ItemShop.Enabled end
		if BuySerpentToggle     and BuySerpentToggle.Object     then BuySerpentToggle.Object.Visible     = WrenShop.Enabled end
		if BuyJumpToggle        and BuyJumpToggle.Object        then BuyJumpToggle.Object.Visible        = WrenShop.Enabled end
		if BuyShieldToggle      and BuyShieldToggle.Object      then BuyShieldToggle.Object.Visible      = WrenShop.Enabled end
		if BreakSpeedToggle     and BreakSpeedToggle.Object     then BreakSpeedToggle.Object.Visible     = TeamUpgrade.Enabled end
		if ArmorUpgradeToggle   and ArmorUpgradeToggle.Object   then ArmorUpgradeToggle.Object.Visible   = TeamUpgrade.Enabled end
		if DamageToggle         and DamageToggle.Object         then DamageToggle.Object.Visible         = TeamUpgrade.Enabled end
		if DiamondGenToggle     and DiamondGenToggle.Object     then DiamondGenToggle.Object.Visible     = TeamUpgrade.Enabled end
		if TeamGenToggle        and TeamGenToggle.Object        then TeamGenToggle.Object.Visible        = TeamUpgrade.Enabled end
		if BedBarrierToggle     and BedBarrierToggle.Object     then BedBarrierToggle.Object.Visible     = TeamUpgrade.Enabled end
		for _, v in ExtraUpgrades do
			if v.toggle.Object then v.toggle.Object.Visible = TeamUpgrade.Enabled end
		end
	end)
end)
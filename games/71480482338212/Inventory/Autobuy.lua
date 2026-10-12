run(function()
	local AutoBuy
	local Swords
	local Armor
	local Pickaxes
	local Ranged
	local Blocks
	local BlockAmount
	local Arrows
	local ArrowAmount
	local Crossbow
	local GUI
	local SmartCheck
	local Upgrades = {}
	local Custom, CustomPost = {}, {}

	-- nearest shop or upgrade stand within range
	local function prompt(tag)
		-- the shop screen closes at 10 studs, a purchase from 21 was turned down
		local best, dist = nil, 10
		for _, v in collectionService:GetTagged(tag) do
			if v:IsA('BasePart') and v:IsDescendantOf(workspace) then
				local mag = (v.Position - entitylib.character.RootPart.Position).Magnitude
				if mag <= dist then
					best, dist = v, mag
				end
			end
		end
		return best
	end

	-- the game's own "can I buy this" answer, from the shop screen's module
	local function buyResult(name, data)
		local gui = lplr.PlayerGui:FindFirstChild('ItemShopGui')
		local module = gui and gui:FindFirstChild('ItemShopHandler')
		if not module then return nil end
		local ok, handler = pcall(require, module)
		if not ok then return nil end
		local okr, result = pcall(handler.GetBuyResult, name, data)
		return okr and result or nil
	end

	local function count(pattern)
		local total = 0
		for name, amount in store.inventory do
			if name:find(pattern) then
				total += amount
			end
		end
		return total
	end

	local function screenOpen(name)
		local gui = lplr.PlayerGui:FindFirstChild(name)
		return gui ~= nil and gui:IsA('LayerCollector') and gui.Enabled
	end

	-- one purchase a pass, the best thing first
	local function shop(stand)
		local kit = lplr:FindFirstChild('Kit')
		local list = bedfight.ItemShopData.GetItemShop(false, kit and kit.Value or '')
		local function try(category, name, data)
			if buyResult(name, data) == 'Buy' then
				fireRemote('PurchaseItemShopItem', stand, category, name)
				return true
			end
		end

		-- what the Item list asks for, in the order of its numbers
		local function extras(entries)
			for _, want in entries do
				for _, entry in list do
					for _, data in entry.List do
						if data.Name:lower() == want.Name then
							local have = data.ReplaceName and count(data.Name..'$') or getItem(data.Name) or 0
							if have < want.Amount and try(entry.Category, data.Name, data) then return true end
						end
					end
				end
			end
			return false
		end
		if extras(Custom) then return true end

		-- the next sword or armour you are still saving for, and what it is paid in
		local saving = {}
		if SmartCheck.Enabled then
			for _, entry in list do
				if (entry.Category == 'Swords' and Swords.Enabled) or (entry.Category == 'Armor' and Armor.Enabled) then
					for _, data in entry.List do
						if data.Max == 1 and buyResult(data.Name, data) == 'Not Enough' then
							for currency in data.Price do
								saving[currency] = true
							end
							break
						end
					end
				end
			end
		end

		for _, entry in list do
			local category = entry.Category
			local upgrade = (category == 'Swords' and Swords.Enabled) or (category == 'Armor' and Armor.Enabled)
				or (category == 'Pickaxes' and Pickaxes.Enabled) or (category == 'Ranged' and Ranged.Enabled)
			for i = #entry.List, 1, -1 do
				local data = entry.List[i]
				local wanted = upgrade and data.Max == 1 and not (data.Name == 'Crossbow' and not Crossbow.Enabled)
				if wanted and category == 'Pickaxes' then
					for currency in data.Price do
						if saving[currency] then
							wanted = false
						end
					end
				end
				if wanted and try(category, data.Name, data) then return true end
				if data.Name == 'Wool' and Blocks.Enabled and count('Wool$') < BlockAmount.Value and try(category, data.Name, data) then return true end
				if data.Name == 'Arrow' and Arrows.Enabled and (getItem('Bow') or getItem('Crossbow')) and count('^Arrow$') < ArrowAmount.Value and try(category, data.Name, data) then return true end
			end
		end
		return extras(CustomPost)
	end

	local function upgrade(stand)
		local folder = bedfight.TeamUpgrades:FindFirstChild(lplr.Team.Name)
		if not folder then return end
		for index, name in bedfight.TeamUpgradesData.UpgradesOrder do
			local toggle, value, meta = Upgrades[name], folder:FindFirstChild(name), bedfight.TeamUpgradesData.Upgrades[name]
			local price = toggle and toggle.Enabled and value and meta and meta.Prices[value.Value + 1]
			if price then
				local afford = true
				for currency, amount in price do
					if (getItem(currency) or 0) < amount then
						afford = false
					end
				end
				if afford then
					fireRemote('TeamUpgrade', stand, index)
					return
				end
			end
		end
	end

	AutoBuy = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBuy',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and inMatch() then
						local stand = prompt('ItemShopPrompt')
						if stand and (not GUI.Enabled or screenOpen('ItemShopGui')) then
							shop(stand)
						end
						stand = prompt('TeamUpgradePrompt')
						if stand and (not GUI.Enabled or screenOpen('TeamUpgradesGui')) then
							upgrade(stand)
						end
					end
					task.wait(0.35)
				until not AutoBuy.Enabled
			end
		end,
		Tooltip = 'Buys gear and team upgrades as soon as you can afford them.\nYou have to be within 10 studs of the shopkeeper, the same as opening the shop.'
	})
	Swords = AutoBuy:CreateToggle({Name = 'Swords', Default = true, Tooltip = 'The best weapon your kit can buy'})
	Armor = AutoBuy:CreateToggle({Name = 'Armor', Default = true})
	Pickaxes = AutoBuy:CreateToggle({Name = 'Pickaxes'})
	Ranged = AutoBuy:CreateToggle({
		Name = 'Bow and crossbow',
		Function = function(callback)
			if Crossbow then
				Crossbow.Object.Visible = callback
			end
		end
	})
	Crossbow = AutoBuy:CreateToggle({
		Name = 'Buy Crossbow',
		Default = true,
		Darker = true,
		Visible = false,
		Tooltip = 'Off, only the bow is bought'
	})
	Arrows = AutoBuy:CreateToggle({
		Name = 'Arrows',
		Function = function(callback)
			ArrowAmount.Object.Visible = callback
		end
	})
	ArrowAmount = AutoBuy:CreateSlider({
		Name = 'Keep arrows',
		Min = 8,
		Max = 64,
		Default = 16,
		Darker = true,
		Visible = false
	})
	Blocks = AutoBuy:CreateToggle({
		Name = 'Wool',
		Function = function(callback)
			BlockAmount.Object.Visible = callback
		end
	})
	BlockAmount = AutoBuy:CreateSlider({
		Name = 'Keep wool',
		Min = 8,
		Max = 128,
		Default = 32,
		Darker = true,
		Visible = false
	})
	GUI = AutoBuy:CreateToggle({
		Name = 'GUI check',
		Tooltip = 'Only buys while the shop or the team upgrade screen is open'
	})
	SmartCheck = AutoBuy:CreateToggle({
		Name = 'Smart check',
		Default = true,
		Tooltip = 'Holds off on pickaxes while you are still saving the same resource for your next sword or armour'
	})
	AutoBuy:CreateTextList({
		Name = 'Item',
		Placeholder = 'priority/item/amount/after',
		Tooltip = 'Extra items to keep in stock, for example 1/Fireball/2 or 2/Obsidian/8.\nA fourth part (1/TNT/1/after) buys it after your gear, not before',
		Function = function(list)
			table.clear(Custom)
			table.clear(CustomPost)
			for _, entry in list do
				local tab = entry:split('/')
				local priority, amount = tonumber(tab[1]), tonumber(tab[3])
				if priority and tab[2] and amount then
					table.insert(tab[4] and CustomPost or Custom, {Priority = priority, Name = tab[2]:lower(), Amount = amount})
				end
			end
			for _, tab in {Custom, CustomPost} do
				table.sort(tab, function(a, b)
					return a.Priority < b.Priority
				end)
			end
		end
	})
	for _, name in bedfight.TeamUpgradesData.UpgradesOrder do
		Upgrades[name] = AutoBuy:CreateToggle({
			Name = name,
			Default = name == 'Team Generator',
			Tooltip = 'Team upgrade, paid in diamonds'
		})
	end
end)

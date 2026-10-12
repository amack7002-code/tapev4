run(function()
	local ShopTierBypass
	local tiered, nexttier = {}, {}
	local originalGetShop
	local originalClientGet
	local originalControllerShop
	local hookedController
	local shopItemsTracked = {}
	local tierChains = {}
	local knownTiers = {
		{'wood_pickaxe', 'stone_pickaxe', 'iron_pickaxe', 'diamond_pickaxe'},
		{'wood_axe', 'stone_axe', 'iron_axe', 'diamond_axe'},
		{'leather_chestplate', 'iron_chestplate', 'diamond_chestplate', 'emerald_chestplate'},
	}
	
	local function applyBypassToItem(item)
		if item and type(item) == "table" then
			if not tiered[item] then 
				tiered[item] = item.tiered 
			end
			if not nexttier[item] then 
				nexttier[item] = item.nextTier 
			end
			item.nextTier = nil
			item.tiered = nil
			shopItemsTracked[item] = true
		end
	end
	
	local function applyBypassToTable(tbl)
		if tbl and type(tbl) == "table" then
			for _, item in pairs(tbl) do
				if type(item) == "table" then
					applyBypassToItem(item)
				end
			end
		end
	end
	
	local function hasItemOwned(itemType)
		if getItem(itemType) then return true end
		local armor = store.inventory.inventory.armor
		if armor then
			for _, a in armor do
				if type(a) == 'table' and a.itemType == itemType then
					return true
				end
			end
		end
		return false
	end

	local function isDowngrade(itemType)
		local chain = tierChains[itemType]
		if not chain then return false end
		local myIndex = chain.index[itemType]
		for i = myIndex + 1, #chain.items do
			if hasItemOwned(chain.items[i]) then return true end
		end
		return false
	end

	local function shouldBlock(itemType)
		if not tierChains[itemType] then return false end
		if hasItemOwned(itemType) then return true end
		if isDowngrade(itemType) then return true end
		return false
	end

	local function getShopController()
		local success, result = pcall(function()
			local RuntimeLib = require(game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))
			if RuntimeLib then
				return RuntimeLib.import(script, game:GetService("ReplicatedStorage"), "TS", "games", "bedwars", "shop", "bedwars-shop")
			end
		end)
		
		if success then
			return result
		end
		
		local shopModule = game:GetService("ReplicatedStorage"):FindFirstChild("TS"):FindFirstChild("games"):FindFirstChild("bedwars"):FindFirstChild("shop"):FindFirstChild("bedwars-shop")
		if shopModule and shopModule:IsA("ModuleScript") then
			return require(shopModule)
		end
		
		return nil
	end
	
	ShopTierBypass = vape.Categories.Utility:CreateModule({
		Name = 'ShopTierBypass',
		Function = function(callback)
			if callback then
				local function collectAndBypass()
					local itemsSeen = {}
					if bedwars.Shop and bedwars.Shop.ShopItems then
						for _, v in pairs(bedwars.Shop.ShopItems) do
							itemsSeen[v] = true
						end
					end
					if bedwars.ShopItems then
						for _, v in pairs(bedwars.ShopItems) do
							itemsSeen[v] = true
						end
					end
					
					local shopController = getShopController()
					if shopController and shopController.BedwarsShop and shopController.BedwarsShop.getShop then
						local shopTable = shopController.BedwarsShop.getShop()
						if type(shopTable) == "table" then
							for _, v in pairs(shopTable) do
								itemsSeen[v] = true
							end
						end
					end
					for item, _ in pairs(itemsSeen) do
						applyBypassToItem(item)
					end

					local itemsByType = {}
					for item, _ in pairs(itemsSeen) do
						if item.itemType then
							itemsByType[item.itemType] = item
						end
					end
					for _, group in knownTiers do
						local chain = {items = {}, index = {}}
						for _, it in group do
							if itemsByType[it] then
								table.insert(chain.items, it)
								chain.index[it] = #chain.items
							end
						end
						if #chain.items > 1 then
							for _, it in chain.items do
								tierChains[it] = chain
							end
						end
					end
				end
				collectAndBypass()
				if bedwars.Shop and bedwars.Shop.getShop and not originalGetShop then
					originalGetShop = bedwars.Shop.getShop
					bedwars.Shop.getShop = function(...)
						local result = originalGetShop(...)
						if type(result) == "table" then
							applyBypassToTable(result)
						end
						return result
					end
				end
				
				if not originalClientGet then
					originalClientGet = bedwars.Client.Get
					local wrapperCache = setmetatable({}, {__mode = 'kv'})
					bedwars.Client.Get = function(self, name, ...)
						local remote = originalClientGet(self, name, ...)
						if name == 'BedwarsPurchaseItem' then
							local cached = wrapperCache[remote]
							if cached then return cached end
							local wrapper = {}
							wrapperCache[remote] = wrapper
							setmetatable(wrapper, {
								__index = function(_, key)
									if key == 'CallServerAsync' then
										return function(_, data, ...)
											if data and data.shopItem and data.shopItem.itemType then
												local itemType = data.shopItem.itemType
												if shouldBlock(itemType) then
													local displayName = bedwars.ItemMeta[itemType] and bedwars.ItemMeta[itemType].displayName or itemType
													if isDowngrade(itemType) then
														notif('ShopTierBypass', 'prevented yo ass from downgrading to '..displayName, 3, 'alert')
													else
														notif('ShopTierBypass', 'u alr got this item lmao: ', 3, 'alert')
													end
													return {andThen = function() end}
												end
											end
											return remote:CallServerAsync(data, ...)
										end
									end
									local value = remote[key]
									if type(value) == 'function' then
										return function(_, ...)
											return value(remote, ...)
										end
									end
									return value
								end
							})
							return wrapper
						end
						return remote
					end
				end

				local shopController = getShopController()
				if shopController and shopController.BedwarsShop and shopController.BedwarsShop.getShop then
					if not originalControllerShop then
						hookedController = shopController.BedwarsShop
						originalControllerShop = hookedController.getShop
						local base = originalControllerShop
						hookedController.getShop = function(...)
							local result = base(...)
							if type(result) == "table" then
								applyBypassToTable(result)
							end
							return result
						end
					end
				end
			else
				for item, _ in pairs(shopItemsTracked) do
					if item and type(item) == "table" then
						if tiered[item] ~= nil then
							item.tiered = tiered[item]
						end
						if nexttier[item] ~= nil then
							item.nextTier = nexttier[item]
						end
					end
				end
				
				if hookedController and originalControllerShop then
					hookedController.getShop = originalControllerShop
					originalControllerShop = nil
					hookedController = nil
				end
				
				if originalGetShop then
					bedwars.Shop.getShop = originalGetShop
					originalGetShop = nil
				end

				if originalClientGet then
					bedwars.Client.Get = originalClientGet
					originalClientGet = nil
				end
				
				table.clear(tiered)
				table.clear(nexttier)
				table.clear(shopItemsTracked)
				table.clear(tierChains)
			end
		end,
		Tooltip = 'lets u buy shit without buying the other tiers'
	})

	vape:Clean(function()
		if originalGetShop then
			pcall(function() bedwars.Shop.getShop = originalGetShop end)
			originalGetShop = nil
		end
		if originalClientGet then
			pcall(function() bedwars.Client.Get = originalClientGet end)
			originalClientGet = nil
		end
	end)
end)
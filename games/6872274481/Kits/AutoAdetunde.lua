run(function()
	local AutoAdetunde
	local PriorityList
	local UpgradeToMax
	local DelaySlider
	local BeforeDeath
	local DeathHealth
	local upgradeNames = {
		'Strength',
		'Speed',
		'Shield',
		'Strength > Speed > Shield',
		'Strength > Shield > Speed',
		'Speed > Strength > Shield',
		'Speed > Shield > Strength',
		'Shield > Strength > Speed',
		'Shield > Speed > Strength'
	}
	local upgradeKeys = {Strength = 'strength', Speed = 'speed', Shield = 'shield'}
	local upgradeIndex = 1
	local upgradeRemote
	local upgradeMeta
	local crystalType

	task.spawn(function()
		upgradeRemote = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('UpgradeFrostyHammer')
	end)

	task.spawn(function()
		pcall(function()
			upgradeMeta = require(replicatedStorage.TS.games.bedwars.items['frosty-hammer']['frosty-hammer-upgrades']).FrostyHammerUpgradeMeta
		end)
		pcall(function()
			crystalType = require(replicatedStorage.TS.item['item-type']).ItemType.FROST_CRYSTAL
		end)
	end)

	local function getLevels()
		return {
			strength = lplr:GetAttribute('strength') or 0,
			speed = lplr:GetAttribute('speed') or 0,
			shield = lplr:GetAttribute('shield') or 0
		}
	end

	local function getMaxLevel(key, levels)
		local tiers = upgradeMeta and upgradeMeta[key] and upgradeMeta[key].tiers
		local max = tiers and #tiers or 3
		for k, v in levels do
			if k ~= key and v >= max then
				return max - 1
			end
		end
		return max
	end

	local function getPrice(key, level)
		local tiers = upgradeMeta and upgradeMeta[key] and upgradeMeta[key].tiers
		local tier = tiers and tiers[level + 1]
		return tier and tier.price or 0
	end

	local function getCrystals()
		if not crystalType then return math.huge end
		local item = getItem(crystalType)
		return item and item.amount or 0
	end

	local function canBuy(key, levels, crystals)
		local level = levels[key]
		if level >= getMaxLevel(key, levels) then return false end
		return crystals >= getPrice(key, level)
	end

	local function sendUpgrade(key)
		pcall(function()
			upgradeRemote:InvokeServer(key)
		end)
	end

	local function lowHealth()
		local char = lplr.Character
		local hp = char and char:GetAttribute('Health')
		local maxHp = char and char:GetAttribute('MaxHealth')
		if not hp or not maxHp or maxHp <= 0 then return false end
		return (hp / maxHp) * 100 <= DeathHealth.Value
	end

	local function pickNext(order, levels, crystals, dump)
		if dump then
			for i = 0, #order - 1 do
				local idx = (upgradeIndex + i - 1) % #order + 1
				if canBuy(order[idx], levels, crystals) then
					upgradeIndex = idx % #order + 1
					return order[idx]
				end
			end
			return nil
		end

		if UpgradeToMax.Enabled or #order == 1 then
			for _, k in order do
				if levels[k] < getMaxLevel(k, levels) then
					return canBuy(k, levels, crystals) and k or nil
				end
			end
			return nil
		end

		if upgradeIndex > #order then upgradeIndex = 1 end
		for i = 0, #order - 1 do
			local idx = (upgradeIndex + i - 1) % #order + 1
			local k = order[idx]
			if levels[k] < getMaxLevel(k, levels) then
				if canBuy(k, levels, crystals) then
					upgradeIndex = idx % #order + 1
					return k
				end
				return nil
			end
		end
		return nil
	end

	local function getOrder()
		local order = {}
		for part in tostring(PriorityList.Value):gmatch('[^>]+') do
			local trimmed = part:match('^%s*(.-)%s*$')
			if upgradeKeys[trimmed] then
				table.insert(order, upgradeKeys[trimmed])
			end
		end
		return order
	end

	AutoAdetunde = vape.Categories.Kits:CreateModule({
		Name = 'AutoAdetunde',
		Function = function(callback)
			if callback then
				upgradeIndex = 1
				cleanThread(AutoAdetunde, task.spawn(function()
					repeat
						local dump = false
						if upgradeRemote and entitylib.isAlive and store.hand and store.hand.tool and store.hand.tool.Name == 'frosty_hammer' then
							local order = getOrder()
							if #order > 0 then
								dump = BeforeDeath.Enabled and lowHealth()
								local key = (dump or not BeforeDeath.Enabled) and pickNext(order, getLevels(), getCrystals(), dump) or nil
								if key then
									sendUpgrade(key)
								else
									dump = false
								end
							end
						end
						task.wait(dump and 0.1 or math.max(DelaySlider.Value, 0.3))
					until not AutoAdetunde.Enabled
				end))
			end
		end,
		Tooltip = 'auto upgrades the pick u chose when u got the crystals'
	})

	PriorityList = AutoAdetunde:CreateDropdown({
		Name = 'Priority',
		List = upgradeNames,
		Default = 'Strength',
		Function = function(val)
			upgradeIndex = 1
			if UpgradeToMax and UpgradeToMax.Object then
				UpgradeToMax.Object.Visible = tostring(val):find('>', 1, true) ~= nil
			end
		end
	})

	UpgradeToMax = AutoAdetunde:CreateToggle({
		Name = 'Upgrade to Max',
		Default = false,
		Visible = false,
		Darker = true,
		Tooltip = 'dumps every crystal into the first upgrade in ur path til its capped, then moves to the next one instead of switchin every time'
	})

	DelaySlider = AutoAdetunde:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.3,
		Decimal = 10,
		Suffix = 's'
	})

	BeforeDeath = AutoAdetunde:CreateToggle({
		Name = 'upgrade before death',
		Default = false,
		Tooltip = 'saves ur crystals and only upgrades when u bout to die so they aint wasted gng',
		Function = function(callback)
			if DeathHealth and DeathHealth.Object then
				DeathHealth.Object.Visible = callback
			end
		end
	})

	DeathHealth = AutoAdetunde:CreateSlider({
		Name = 'death hp',
		Min = 1,
		Max = 100,
		Default = 20,
		Suffix = '%',
		Darker = true,
		Visible = false,
		Tooltip = 'how low ur hp gotta be before it dumps everything'
	})

	task.defer(function()
		if UpgradeToMax and UpgradeToMax.Object then
			UpgradeToMax.Object.Visible = tostring(PriorityList.Value):find('>', 1, true) ~= nil
		end
		if DeathHealth and DeathHealth.Object and BeforeDeath then
			DeathHealth.Object.Visible = BeforeDeath.Enabled
		end
	end)
end)
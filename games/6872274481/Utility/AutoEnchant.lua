run(function()
	local AutoEnchant
	local EnchantPick
	local UnlockTable
	local EnchantRange
	local netFolder
	local enchantInfo = {}
	local tableCost
	local diamondType
	local anyTeamTable = false

	local researchRemotes = {
		EnchantMeta = 'ResearchEnchant',
		ArmorEnchantMeta = 'ResearchArmorEnchant',
		ToolEnchantMeta = 'ResearchToolEnchant'
	}

	task.spawn(function()
		netFolder = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged')
	end)

	task.spawn(function()
		pcall(function()
			local meta = require(replicatedStorage.TS.enchant['enchant-meta'])
			for group, remoteName in researchRemotes do
				for _, v in meta[group] or {} do
					if type(v) == 'table' and type(v.name) == 'string' and v.statusEffect then
						local lower = v.name:lower()
						for _, want in {'static', 'forest'} do
							if lower:find(want) and not enchantInfo[want] then
								enchantInfo[want] = {effect = v.statusEffect, remote = remoteName}
							end
						end
					end
				end
			end
		end)
		pcall(function()
			tableCost = require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-util']).TeamUpgradeUtil.ENCHANT_TABLE_COST
		end)
		pcall(function()
			diamondType = require(replicatedStorage.TS.item['item-type']).ItemType.DIAMOND
		end)
		pcall(function()
			anyTeamTable = require(replicatedStorage.TS.enchant['enchant-util']).EnchantBalance.USE_ENCHANT_TABLE_ANY_TEAM == true
		end)
	end)

	local function hasEnchant(info)
		local char = lplr.Character
		local val = char and char:GetAttribute('StatusEffect_' .. tostring(info.effect))
		return type(val) == 'number' and val < 0
	end

	local function closestTable(tag, needTeam)
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return nil end
		local myTeam = lplr:GetAttribute('Team')
		local best, bestDist = nil, EnchantRange.Value
		for _, v in collectionService:GetTagged(tag) do
			if v:IsA('BasePart') and (not needTeam or v:GetAttribute('Team') == myTeam) then
				local dist = (v.Position - root.Position).Magnitude
				if dist <= bestDist then
					best, bestDist = v, dist
				end
			end
		end
		return best
	end

	local function invoke(name, ...)
		local remote = netFolder and netFolder:FindFirstChild(name)
		if not remote then return end
		local args = table.pack(...)
		pcall(function()
			remote:InvokeServer(table.unpack(args, 1, args.n))
		end)
	end

	AutoEnchant = vape.Categories.Utility:CreateModule({
		Name = 'AutoEnchant',
		Function = function(callback)
			if callback then
				repeat
					local waitTime = 0.5
					if entitylib.isAlive and netFolder then
						local broken = UnlockTable.Enabled and closestTable('broken-enchant-table', true)
						local diamonds = diamondType and getItem(diamondType)
						if broken and (not tableCost or (diamonds and diamonds.amount >= tableCost)) then
							invoke('RepairEnchantTable', broken)
							waitTime = 2
						else
							local info = enchantInfo[EnchantPick.Value]
							if info and not hasEnchant(info) then
								local enchantTable = closestTable('enchant-table', not anyTeamTable)
								if enchantTable then
									invoke(info.remote, {enchantTable = enchantTable})
									waitTime = 1.5
								end
							end
						end
					end
					task.wait(waitTime)
				until not AutoEnchant.Enabled
			end
		end,
		Tooltip = 'auto rolls the enchant table till u get the enchant u picked'
	})

	EnchantPick = AutoEnchant:CreateDropdown({
		Name = 'enchant',
		List = {'static', 'forest'},
		Tooltip = 'which enchant u tryna get gng'
	})

	UnlockTable = AutoEnchant:CreateToggle({
		Name = 'Unlock Enchant Table',
		Default = true,
		Tooltip = 'fixes ur team enchant table for u when u got the diamonds'
	})

	EnchantRange = AutoEnchant:CreateSlider({
		Name = 'range',
		Min = 1,
		Max = 20,
		Default = 6,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
		Tooltip = 'how close u gotta be to the table for it to work'
	})
end)
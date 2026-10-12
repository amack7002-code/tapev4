run(function()
	local Protect
	local Target
	local LimitItem
	local protectOffsets = {
		Vector3.new(3, 0, 0),
		Vector3.new(-3, 0, 0),
		Vector3.new(0, 0, 3),
		Vector3.new(0, 0, -3),
		Vector3.new(0, 3, 0),
		Vector3.new(0, -3, 0),
	}

	local function getMyBeehive()
		for _, v in collectionService:GetTagged('beehive') do
			if v:GetAttribute('PlacedByUserId') == lplr.UserId then
				return v
			end
		end
	end

	local function getTargetItem()
		if Target.Value == 'Beehive' then
			return getMyBeehive()
		end
	end

	local function getProtectBlock()
		if LimitItem.Enabled then
			if store.hand.toolType == 'block' then
				return store.hand.tool.Name
			end
			return nil
		end
		if StrongestBlock.Enabled then
			local best, bestHealth
			for _, item in store.inventory.inventory.items do
				local meta = bedwars.ItemMeta[item.itemType]
				if meta and meta.block and (item.amount or 0) > 0 then
					local health = meta.block.health or 0
					if not bestHealth or health > bestHealth then
						best = item.itemType
						bestHealth = health
					end
				end
			end
			return best
		end
		return getScaffoldBlockForModule(LimitItem)
	end

	Protect = vape.Categories.World:CreateModule({
		Name = 'Protect',
		Function = function(callback)
			if callback then
				repeat
					local item = getTargetItem()
					if item then
						local basePos = bedwars.BlockController:getBlockPosition(item.Position) * 3
						for _, offset in protectOffsets do
							if not Protect.Enabled then break end
							local pos = basePos + offset
							if not getPlacedBlock(pos) then
								local block = getProtectBlock()
								if block then
									task.spawn(bedwars.placeBlock, pos, block, false)
									task.wait(0.05)
								end
							end
						end
					end
					task.wait(0.5)
				until not Protect.Enabled
			end
		end,
		Tooltip = 'boxes ur hive in so nobody can break it gng - more coming soon ig'
	})

	Target = Protect:CreateDropdown({
		Name = 'Target',
		List = {'Beehive'},
		Default = 'Beehive'
	})
	LimitItem = Protect:CreateToggle({Name = 'Limit to items'})
	StrongestBlock = Protect:CreateToggle({Name = 'Use Strongest Block'})
end)
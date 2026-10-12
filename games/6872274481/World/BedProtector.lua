run(function()
	local BedProtector
	local LimitItem
	local AutoSwitch
	local RangeSlider
	local LayerSlider
	local currentLayer = 0
	local buildingComplete = false
	local heldBlockType = nil
	local previousSlot = nil
	local lastPlaceTime = 0

	local ALLOWED_BLOCKS = {
		obsidian = true,
		wood_plank_oak = true,
		wood_oak_plank = true,
		ceramic = true,
		stone_brick = true
	}

	local function isAllowedBlock(itemType)
		if ALLOWED_BLOCKS[itemType] then return true end
		return itemType:find('wool') ~= nil
	end

	local function getPyramid(size, grid)
		local positions = {}
		for h = size, 0, -1 do
			for w = h, 0, -1 do
				table.insert(positions, Vector3.new(w, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w, (size - h), (h - w) * -1) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), (h - w) * -1) * grid)
			end
		end
		return positions
	end

	local function getMyBed()
		local myTeam = lplr:GetAttribute('Team')
		if not myTeam then return nil end
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return nil end
		for _, bed in collectionService:GetTagged('bed') do
			if bed and bed.Parent and bed:GetAttribute('Team'..myTeam..'NoBreak') then
				local bedPos = bed:IsA('BasePart') and bed.Position or (bed.PrimaryPart and bed.PrimaryPart.Position or bed:GetPivot().Position)
				if (root.Position - bedPos).Magnitude < 40 then
					return bed
				end
			end
		end
		return nil
	end

	local function getBlocks()
		local blocks = {}
		for _, item in store.inventory.inventory.items do
			local meta = bedwars.ItemMeta[item.itemType]
			if meta and meta.block and not meta.block.seeThrough and (item.amount or 0) > 0 and isAllowedBlock(item.itemType) then
				table.insert(blocks, {itemType = item.itemType, tool = item.tool, health = meta.block.health or 0})
			end
		end
		table.sort(blocks, function(a, b) return a.health > b.health end)
		return blocks
	end

	local function getBlockTypeForLayer(_, blocks)
		if #blocks == 0 then return nil end
		return blocks[1]
	end

	local function getSlotFor(itemType)
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType == itemType then
				return i - 1
			end
		end
		return nil
	end

	local function restorePreviousSlot()
		if heldBlockType then
			if previousSlot then hotbarSwitch(previousSlot) end
			heldBlockType = nil
			previousSlot = nil
		end
	end

	local function switchToBlock(itemType)
		if LimitItem.Enabled then return end
		if not AutoSwitch.Enabled then return end
		if heldBlockType == itemType then return end
		local slot = getSlotFor(itemType)
		if slot then
			previousSlot = previousSlot or store.inventory.hotbarSlot
			hotbarSwitch(slot)
			heldBlockType = itemType
		end
	end

	local function isPositionInRange(worldPos)
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return false end
		return (root.Position - worldPos).Magnitude <= RangeSlider.Value
	end

	local function repairAll(bedCFrame, blocks, upto)
		if upto <= 0 then return end

		local block = getBlockTypeForLayer(0, blocks) or blocks[1]
		if LimitItem.Enabled then
			if store.hand.toolType ~= 'block' then return end
			if not isAllowedBlock(store.hand.tool.Name) then return end
			block = {itemType = store.hand.tool.Name}
		end
		if not block then return end

		local switched = false
		for layer = 0, upto - 1 do
			local positions = getPyramid(layer + 1, 3)
			for _, pos in positions do
				if not BedProtector.Enabled then return end
				local worldPos = (bedCFrame * CFrame.new(pos)).Position
				if isPositionInRange(worldPos) and not getPlacedBlock(worldPos) then
					if not switched then
						switchToBlock(block.itemType)
						switched = true
					end
					task.spawn(bedwars.placeBlock, worldPos, block.itemType, false)
				end
			end
		end
	end

	local function buildLayer(bedCFrame, blocks)
		if buildingComplete then return false end

		local block = getBlockTypeForLayer(currentLayer, blocks) or blocks[1]
		if not block then return false end

		if LimitItem.Enabled then
			if store.hand.toolType ~= 'block' then return false end
			if not isAllowedBlock(store.hand.tool.Name) then return false end
			block = {itemType = store.hand.tool.Name}
		end

		local positions = getPyramid(currentLayer + 1, 3)
		local allPlaced = true
		local hasMissingInRange = false

		for _, pos in positions do
			local worldPos = (bedCFrame * CFrame.new(pos)).Position
			if not getPlacedBlock(worldPos) then
				allPlaced = false
				if isPositionInRange(worldPos) then
					hasMissingInRange = true
				end
			end
		end

		if allPlaced then
			currentLayer += 1
			if currentLayer >= LayerSlider.Value then
				buildingComplete = true
				restorePreviousSlot()
				notif('BedProtector', 'bed is fully walled gng ur good', 4)
			end
			return false
		end

		if not hasMissingInRange then return false end

		for _, pos in positions do
			if not BedProtector.Enabled then break end
			local worldPos = (bedCFrame * CFrame.new(pos)).Position
			if isPositionInRange(worldPos) and not getPlacedBlock(worldPos) then
				if tick() - lastPlaceTime >= 0.05 then
					switchToBlock(block.itemType)
					task.spawn(bedwars.placeBlock, worldPos, block.itemType, false)
					lastPlaceTime = tick()
					task.wait(0.05)
				end
			end
		end
		return true
	end

	BedProtector = vape.Categories.World:CreateModule({
		Name = 'BedProtector',
		Function = function(callback)
			if callback then
				currentLayer = 0
				buildingComplete = false
				heldBlockType = nil
				previousSlot = nil
				repeat
					pcall(function()
						if not entitylib.isAlive then return end
						local bed = getMyBed()
						if not bed then
							restorePreviousSlot()
							return
						end
						local bedCFrame = bed:IsA('BasePart') and bed.CFrame or (bed.PrimaryPart and bed.PrimaryPart.CFrame or bed:GetPivot())
						local blocks = getBlocks()
						if #blocks == 0 and not LimitItem.Enabled then return end
						repairAll(bedCFrame, blocks, currentLayer)
						if not buildingComplete then
							buildLayer(bedCFrame, blocks)
						end
					end)
					task.wait(0.05)
				until not BedProtector.Enabled
				restorePreviousSlot()
			end
		end,
		Tooltip = 'stacks a pyramid over ur bed w ur strongest block'
	})

	LimitItem = BedProtector:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'only builds while ur already holdin a block'
	})
	AutoSwitch = BedProtector:CreateToggle({
		Name = 'Auto Switch',
		Default = true,
		Tooltip = 'swaps ur hotbar to the block by itself then swaps back after. ignored if limit to items is on'
	})
	RangeSlider = BedProtector:CreateSlider({
		Name = 'Place Range',
		Min = 1,
		Max = 30,
		Default = 15,
		Suffix = ' studs'
	})
	LayerSlider = BedProtector:CreateSlider({
		Name = 'Layers',
		Min = 1,
		Max = 10,
		Default = 3,
		Suffix = ' layers'
	})
end)
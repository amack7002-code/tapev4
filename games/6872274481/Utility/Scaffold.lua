run(function()
	local Scaffold
	local Expand
	local Tower
	local Downwards
	local Diagonal
	local LimitItem
	local Mouse
	local PlaceDelay
	local adjacent, lastpos = {}, Vector3.zero
	local lastPlaceTime = 0
	
	for x = -3, 3, 3 do
		for y = -3, 3, 3 do
			for z = -3, 3, 3 do
				local vec = Vector3.new(x, y, z)
				if vec ~= Vector3.zero then
					table.insert(adjacent, vec)
				end
			end
		end
	end
	
	local function checkAdjacent(pos)
		for _, v in adjacent do
			if getPlacedBlock(pos + v) then
				return true
			end
		end
		return false
	end
	
	local function getScaffoldBlock()
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name, store.hand.amount
		elseif (not LimitItem.Enabled) then
			local isHoldingSwordOrTool = store.hand.toolType == 'sword' or (store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name].sword)
			if not isHoldingSwordOrTool then
				local wool, amount = getWool()
				if wool then
					return wool, amount
				else
					for _, item in store.inventory.inventory.items do
						if bedwars.ItemMeta[item.itemType].block then
							return item.itemType, item.amount
						end
					end
				end
			end
		end
	
		return nil, 0
	end
	
	Scaffold = vape.Categories.Utility:CreateModule({
		Name = 'Scaffold',
		Function = function(callback)
			if callback then
				lastPlaceTime = 0
				repeat
					if entitylib.isAlive then
						local wool, amount = getScaffoldBlock()

						if Mouse.Enabled then
							if not inputService:IsMouseButtonPressed(0) then
								wool = nil
							end
						end

						if wool then
							local root = entitylib.character.RootPart
							if Tower.Enabled and inputService:IsKeyDown(Enum.KeyCode.Space) and (not inputService:GetFocusedTextBox()) then
								root.Velocity = Vector3.new(root.Velocity.X, 38, root.Velocity.Z)
							end

							for i = Expand.Value, 1, -1 do
								local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + (Downwards.Enabled and inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4.5 or 1.5), 0) + entitylib.character.Humanoid.MoveDirection * (i * 3))
								if Diagonal.Enabled then
									if math.abs(math.round(math.deg(math.atan2(-entitylib.character.Humanoid.MoveDirection.X, -entitylib.character.Humanoid.MoveDirection.Z)) / 45) * 45) % 90 == 45 then
										local dt = (lastpos - currentpos)
										if ((dt.X == 0 and dt.Z ~= 0) or (dt.X ~= 0 and dt.Z == 0)) and ((lastpos - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 then
											currentpos = lastpos
										end
									end
								end

								local block, blockpos = getPlacedBlock(currentpos)
								if not block then
									if tick() - lastPlaceTime >= (PlaceDelay.Value / 1000) then
										blockpos = checkAdjacent(blockpos * 3) and blockpos * 3 or blockProximity(currentpos)
										if blockpos then
											task.spawn(bedwars.placeBlock, blockpos, wool, false)
											lastPlaceTime = tick()
										end
									end
								end
								lastpos = currentpos
							end
						end
					end

					task.wait(0.03)
				until not Scaffold.Enabled
			else
				lastPlaceTime = 0
			end
		end,
		Tooltip = 'Helps you make bridges/scaffold walk.'
	})
	Expand = Scaffold:CreateSlider({
		Name = 'Expand',
		Min = 1,
		Max = 6
	})
	Tower = Scaffold:CreateToggle({
		Name = 'Tower',
		Default = true
	})
	Downwards = Scaffold:CreateToggle({
		Name = 'Downwards',
		Default = true
	})
	Diagonal = Scaffold:CreateToggle({
		Name = 'Diagonal',
		Default = true
	})
	LimitItem = Scaffold:CreateToggle({Name = 'Limit to items'})
	Mouse = Scaffold:CreateToggle({Name = 'Require mouse down'})
	PlaceDelay = Scaffold:CreateSlider({
		Name = 'Place Delay',
		Min = 0,
		Max = 200,
		Default = 0,
		Suffix = "ms"
	})
end)
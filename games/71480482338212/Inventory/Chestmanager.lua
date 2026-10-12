run(function()
	local ChestManager
	local Loot
	local Chests
	local KeepInv
	local Health
	local Void
	local GameEnd
	local saved = {}
	local saveAt = 0

	local function teamName()
		return inMatch() and lplr.Team.Name or nil
	end

	-- the chest model of a team, when it stands within range
	local function chestInRange(team)
		if not entitylib.isAlive then return false end
		for _, v in collectionService:GetTagged('TeamChest') do
			if v.Name == team and v:IsDescendantOf(workspace) then
				-- the game closes a chest once you are 24 studs away
				return (v:GetPivot().Position - entitylib.character.RootPart.Position).Magnitude <= 24
			end
		end
		return false
	end

	local function lootChests()
		local mine = teamName()
		if not mine then return end
		for _, storage in bedfight.TeamChests:GetChildren() do
			local own = storage.Name == mine
			if (Chests.Value == 'Own team' and not own) or (Chests.Value == 'Enemy teams' and own) then continue end
			if not chestInRange(storage.Name) then continue end
			for _, slot in storage:GetChildren() do
				local index, item = tonumber(slot.Name), slot:GetAttribute('Name')
				-- what KeepInv parked in your own chest stays there until you are back
				if index and item and item ~= '' and not (own and saved[index]) then
					fireRemote('TakeItemFromChest', storage.Name, index, item)
					task.wait(0.1)
					if not ChestManager.Enabled then return end
				end
			end
		end
	end

	local function save()
		local team = teamName()
		local storage = team and bedfight.TeamChests:FindFirstChild(team)
		if not storage or saveAt > tick() or not chestInRange(team) then return end
		saveAt = tick() + 5
		local index = 0
		for name in store.inventory do
			local data = bedfight.ItemsData[name]
			if data and data.CanStoreInChest then
				repeat index += 1 until index > 20 or not storage:FindFirstChild(tostring(index))
				if index > 20 then break end
				saved[index] = name
				fireRemote('PutItemInChest', name, team, index)
			end
		end
	end

	local function restore()
		local team = teamName()
		if not team or not next(saved) then return end
		local list = table.clone(saved)
		table.clear(saved)
		for index, name in list do
			fireRemote('TakeItemFromChest', team, index, name)
			task.wait(0.25)
		end
	end

	ChestManager = vape.Categories.Inventory:CreateModule({
		Name = 'ChestManager',
		Function = function(callback)
			if callback then
				ChestManager:Clean(entitylib.Events.LocalAdded:Connect(function()
					task.wait(1)
					if KeepInv.Enabled then
						restore()
					end
				end))
				ChestManager:Clean(bedfight.Signals.EndGame:Connect(function()
					if KeepInv.Enabled and GameEnd.Enabled then
						saveAt = 0
						save()
					end
				end))

				local floor
				repeat
					if entitylib.isAlive and inMatch() then
						if KeepInv.Enabled then
							local hum, root = entitylib.character.Humanoid, entitylib.character.RootPart
							if hum.Health > 0 and hum.Health / hum.MaxHealth * 100 <= Health.Value then
								save()
							elseif Void.Enabled then
								-- lowest block of the map, looked up once a match
								local map = mapBlocks()
								if map and (not floor or floor.Map ~= map) then
									local low = math.huge
									for _, v in map:GetDescendants() do
										if v:IsA('BasePart') and v.Position.Y < low then
											low = v.Position.Y
										end
									end
									floor = {Map = map, Y = low}
								end
								if floor and root.Position.Y < floor.Y - 15 then
									save()
								end
							end
						end
						if Loot.Enabled then
							lootChests()
						end
					end
					task.wait(0.3)
				until not ChestManager.Enabled
			end
		end,
		Tooltip = 'Empties team chests into your inventory and can park your items in your own chest before you die.\nWorks within 24 studs of a chest, the distance the game keeps one open.'
	})
	Loot = ChestManager:CreateToggle({
		Name = 'Loot chests',
		Default = true,
		Function = function(callback)
			if Chests then
				Chests.Object.Visible = callback
			end
		end
	})
	Chests = ChestManager:CreateDropdown({
		Name = 'Chests',
		List = {'All teams', 'Enemy teams', 'Own team'},
		Darker = true
	})
	KeepInv = ChestManager:CreateToggle({
		Name = 'Keep inventory',
		Function = function(callback)
			Health.Object.Visible = callback
			Void.Object.Visible = callback
			GameEnd.Object.Visible = callback
		end,
		Tooltip = 'Puts everything storable into your team chest when you are about to die and takes it back after you respawn'
	})
	Health = ChestManager:CreateSlider({
		Name = 'Health',
		Min = 5,
		Max = 60,
		Default = 25,
		Suffix = '%',
		Darker = true,
		Visible = false
	})
	Void = ChestManager:CreateToggle({
		Name = 'When falling into the void',
		Default = true,
		Darker = true,
		Visible = false
	})
	GameEnd = ChestManager:CreateToggle({
		Name = 'When the game ends',
		Darker = true,
		Visible = false
	})
end)

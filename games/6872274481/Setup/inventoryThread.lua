run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') then
			return
		end

		entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
			local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
			return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
		end or function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end)
	end

	entitylib.start = function()
		if entitylib.Running then entitylib.stop() end

		local function customEntity(ent)
			if playersService:GetPlayerFromCharacter(ent) then return end
			if collectionService:HasTag(ent.Parent, 'entity') then return end
			local teamFunc = function(self)
				local npcTeam = self.Character:GetAttribute('Team')
				if not npcTeam then return true end
				return lplr:GetAttribute('Team') ~= npcTeam
			end
			entitylib.addEntity(ent, nil, teamFunc)
		end

		table.insert(entitylib.Connections, playersService.PlayerAdded:Connect(function(v)
			entitylib.addPlayer(v)
		end))
		table.insert(entitylib.Connections, playersService.PlayerRemoving:Connect(function(v)
			entitylib.removePlayer(v)
		end))

		for _, v in playersService:GetPlayers() do
			entitylib.addPlayer(v)
		end

		for _, ent in collectionService:GetTagged('entity') do
			customEntity(ent)
		end

		table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
		table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
			entitylib.removeEntity(ent)
		end))

		local function addDesertPot(pot)
			if not pot:IsA('Model') then return end
			entitylib.addEntity(pot, nil, function() return true end)
		end
		for _, v in collectionService:GetTagged('desert_pot') do
			addDesertPot(v)
		end
		table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('desert_pot'):Connect(addDesertPot))
		table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('desert_pot'):Connect(function(v)
			entitylib.removeEntity(v)
		end))

		table.insert(entitylib.Connections, workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
			gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
		end))

		entitylib.Running = true
	end

	entitylib.addPlayer = function(plr)
		if entitylib.PlayerConnections[plr] then
			for _, conn in ipairs(entitylib.PlayerConnections[plr]) do
				if conn and typeof(conn) == "RBXScriptConnection" then
					conn:Disconnect()
				end
			end
		end

		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('Team'):Connect(function()
				if plr == lplr then
					for _, v in entitylib.List do
						local newTargetable = entitylib.targetCheck(v)
						if v.Targetable ~= newTargetable then
							v.Targetable = newTargetable
							entitylib.Events.EntityUpdated:Fire(v)
						end
					end
				else
					entitylib.refreshEntity(plr.Character, plr)
					for _, v in entitylib.List do
						if v.Player ~= plr and v.Targetable ~= entitylib.targetCheck(v) then
							local newTargetable = entitylib.targetCheck(v)
							v.Targetable = newTargetable
							entitylib.Events.EntityUpdated:Fire(v)
						end
					end
				end
			end)
		}
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum, humrootpart, head
			if plr then
				hum = waitForChildOfType(char, 'Humanoid', 10)
				humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				head = char:WaitForChild('Head', 10) or humrootpart
			else
				hum = {HipHeight = 0.5}
				humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
				head = humrootpart
			end
			local updateobjects = {}
			if plr and plr ~= lplr then
				local names = {'ArmorInvItem_0', 'ArmorInvItem_1', 'ArmorInvItem_2', 'HandInvItem'}
				for _, name in names do
					local found = char:FindFirstChild(name)
					if found then
						table.insert(updateobjects, found)
					end
				end
			end

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Jumps = 0,
					JumpTick = tick(),
					Jumping = false,
					LandTick = tick(),
					MaxHealth = char:GetAttribute('MaxHealth') or 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entity.AirTime = tick()
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
					table.insert(entity.Connections, char.AttributeChanged:Connect(function(attr)
						vapeEvents.AttributeChanged:Fire(attr)
					end))
				else
					entity.Targetable = entitylib.targetCheck(entity)

					if not plr then
						table.insert(entity.Connections, char.AttributeChanged:Connect(function(attr)
							if attr == 'Team' then
								entity.Targetable = entitylib.targetCheck(entity)
								entitylib.Events.EntityUpdated:Fire(entity)
							end
						end))
					end

					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					local invUpdatePending = {}

					for _, v in updateobjects do
						table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
							if invUpdatePending[entity] then return end
							invUpdatePending[entity] = true
							task.delay(0.1, function()
								invUpdatePending[entity] = nil
								if bedwars.getInventory then
									store.inventories[plr] = bedwars.getInventory(plr)
									entitylib.Events.EntityUpdated:Fire(entity)
								end
							end)
						end))
					end

					if plr then
						local anim = char:FindFirstChild('Animate')
						if anim then
							pcall(function()
								local jumpAnimId = anim.jump:FindFirstChildWhichIsA('Animation').AnimationId
								table.insert(entity.Connections, hum.StateChanged:Connect(function(old, new)
									if new == Enum.HumanoidStateType.Jumping then
										entity.JumpTick = tick()
										entity.Jumps += 1
										entity.LandTick = tick() + 1
										entity.Jumping = entity.Jumps > 1
									elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running or new == Enum.HumanoidStateType.Freefall then
										entity.Jumping = false
									end
								end))
							end)
						end

						local inventoryThread
						inventoryThread = task.spawn(function()
							local waitTime = 0.3
							while plr and plr.Parent and entity.Character and entity.Character.Parent do
								if bedwars.getInventory then
									local inv = bedwars.getInventory(plr)
									if inv then
										local old = store.inventories[plr]
										store.inventories[plr] = inv
										local changed = true
										if old then
											local oh = old.hand and old.hand.itemType or ''
											local nh = inv.hand and inv.hand.itemType or ''
											local oa = ''
											local na = ''
											for i = 4, 6 do
												oa = oa .. '|' .. tostring(old.armor and old.armor[i] and old.armor[i].itemType or '')
												na = na .. '|' .. tostring(inv.armor and inv.armor[i] and inv.armor[i].itemType or '')
											end
											changed = (oh ~= nh) or (oa ~= na)
										end
										if changed then
											entitylib.Events.EntityUpdated:Fire(entity)
										end
									end
								end
								task.wait(waitTime)
								if waitTime < 0.6 then
									waitTime = math.min(0.6, waitTime + 0.1)
								end
							end
							inventoryThread = nil
						end)
						table.insert(entity.Connections, {
							Disconnect = function()
								if inventoryThread then
									pcall(task.cancel, inventoryThread)
									inventoryThread = nil
								end
							end
						})
					end
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end

				table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
					if part == humrootpart or part == hum or part == head then
						if part == humrootpart and hum.RootPart then
							humrootpart = hum.RootPart
							entity.RootPart = hum.RootPart
							entity.HumanoidRootPart = hum.RootPart
							return
						end
						entitylib.removeEntity(char, plr == lplr)
					end
				end))
			end
			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.getUpdateConnections = function(ent)
		local char = ent.Character
		local tab = {
			char:GetAttributeChangedSignal('Health'),
			char:GetAttributeChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}

		if ent.Player then
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKit'))
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKits'))

			local vkSignal = {
				Connect = function(_, func)
					local conn = ent.Player:GetAttributeChangedSignal('VoidKnightTier'):Connect(function()
						lastUpdate[ent] = 0
						func()
					end)
					return conn
				end
			}
			table.insert(tab, vkSignal)
		end

		local blockKickerSignal = {
			Connect = function(_, func)
				local conn = char.AttributeChanged:Connect(function(attr)
					if attr == 'BlockKickerKit_BlockCount' then
						lastUpdate[ent] = 0
						func()
					end
				end)
				return conn
			end
		}
		table.insert(tab, blockKickerSignal)

		local shieldSignal = {
			Connect = function(_, func)
				local conn = char.AttributeChanged:Connect(function(attr)
					if attr:find('Shield') then
						func()
					end
				end)
				return conn
			end
		}
		table.insert(tab, shieldSignal)

		return tab
	end

	entitylib.targetCheck = function(ent)
		if ent.Character and ent.Character:HasTag('petrified-player') then return false end
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then
			local npcTeam = ent.Character and ent.Character:GetAttribute('Team')
			if not npcTeam then return true end
			return lplr:GetAttribute('Team') ~= npcTeam
		end
		if isFriend(ent.Player) then return false end
		return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
end)
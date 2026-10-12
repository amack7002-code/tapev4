run(function()
	local AutoCyber
	local DropMode
	local Collect
	local Target
	local Limit

	local genItems = {'emerald', 'diamond'}

	local teamCache, cacheExpire = nil, 0
	local function getTeamGenerator()
		if cacheExpire > tick() and teamCache and teamCache.Parent then
			return teamCache
		end
		teamCache, cacheExpire = collectionService:GetTagged(lplr:GetAttribute('Team') .. '_TeamOreGenerator')[1], tick() + 5
		return teamCache
	end

	local cache = nil
	local function getDrone()
		if Limit.Enabled and (not store.hand.tool or store.hand.tool.Name ~= 'drone') then
			return nil
		end
		if cache and cache.Parent then
			return cache
		end
		for _, v in collectionService:GetTagged('Drone') do
			if v:GetAttribute('PlayerUserId') == lplr.UserId then
				local Changed = function()
					if v:GetAttribute('HeldItem') then
						repeat
							bedwars.Handler:Get('DropDroneItem'):Fire('SendToServer', {
								direction = Vector3.new(1000, 10, 0),
								position = v.PrimaryPart.Position
							})
							task.wait(0.1)
						until not v:GetAttribute('HeldItem') or not AutoCyber.Enabled
					end
				end
				AutoCyber:Clean(v:GetAttributeChangedSignal('HeldItem'):Connect(Changed))
				AutoCyber:Clean(v:GetAttributeChangedSignal('HeldItemAmount'):Connect(Changed))
				cache = v
				return v
			end
		end
		if getItem('drone') and bedwars.Handler:Get('FireGuidedProjectile'):Fire('CallServer', 'drone') then
			task.wait(0.1)
			return getDrone()
		end
		return nil
	end

	local function getGenerator(drone, item)
		local children = collectionService:GetTagged(item .. '_OreGenerator')
		local pos = drone.PrimaryPart.Position
		table.sort(children, function(a, b)
			return (pos - a.PrimaryPart.Position).Magnitude < (pos - b.PrimaryPart.Position).Magnitude
		end)
		return children[1] and children[1].PrimaryPart or nil
	end

	local blacklist = {}
	local function getItemDrop(drone)
		local generator = getTeamGenerator()
		generator = generator and generator.PrimaryPart.Position or Vector3.zero
		local children = workspace.ItemDrops:GetChildren()
		local pos = drone.PrimaryPart.Position
		table.sort(children, function(a, b)
			return (pos - a.Position).Magnitude < (pos - b.Position).Magnitude
		end)
		local stealSplit = Collect.Value == 'Steal Split'
		local genOnly = Collect.Value == 'Generator'
		for _, v in children do
			local passesType = true
			if genOnly and not table.find(genItems, v.Name) then
				passesType = false
			end
			if tick() > (blacklist[v] or 0)
				and passesType
				and v.Position.Y > 0
				and math.abs(v.Velocity.Y) <= 0
				and (not stealSplit or (v.Position - generator).Magnitude > 20)
				and (not Target.Enabled or not entitylib.EntityPosition({
					Origin = pos,
					Range = 60,
					Part = 'RootPart',
					Players = true
				}))
			then
				return v
			end
		end
		return nil
	end

	AutoCyber = vape.Categories.Minigames:CreateModule({
		Name = 'AutoCyber',
		Function = function(callback)
			if callback then
				AutoCyber:Clean(workspace.ItemDrops.ChildAdded:Connect(function(v)
					task.wait()
					if v.Velocity.X > 100 then
						blacklist[v] = tick() + 5
						local Amount = v:GetAttribute('Amount')
						local LastParent = v.Parent
						if DropMode.Value == 'Player' then
							notif('AutoCyber', 'Collecting ' .. tostring(Amount) .. ' ' .. v.Name, 4, 'info')
							repeat
								v.Velocity = Vector3.zero
								v.CFrame = entitylib.character.RootPart.CFrame - Vector3.new(0, 4, 0)
								task.spawn(function()
									bedwars.Handler:Get('PickupItemDrop'):Fire('CallServerAsync', {
										itemDrop = v
									}):andThen(function(suc)
										if suc and bedwars.SoundList then
											bedwars.AudioManager:playAudio(bedwars.SoundList.PICKUP_ITEM_DROP)
											local sound = bedwars.ItemMeta[v.Name].pickUpOverlaySound
											if sound then
												bedwars.AudioManager:playAudio(sound, {
													position = v.Position,
													volumeMultiplier = 0.9
												})
											end
										end
									end)
								end)
								task.wait(0.02)
							until not v or v.Parent ~= LastParent

							notif('AutoCyber', `Collected {Amount} {v.Name}{Amount > 1 and 's' or ''}`, 4, 'info')
						else
							local start = tick()
							local generator = getTeamGenerator()
							if generator then
								repeat
									v.Velocity = Vector3.zero
									v.CFrame = generator.PrimaryPart.CFrame
									task.wait()
								until (tick() - start) >= 1 or not v or v.Parent ~= LastParent
								notif('AutoCyber', 'Dropped ' .. tostring(Amount) .. ' ' .. v.Name, 8, 'info')
							else
								notif('AutoCyber', 'Base generator not found', 20, 'alert')
							end
						end
					end
				end))

				repeat
					local drone = getDrone()
					if drone then
						local v = getItemDrop(drone)
						if v then
							task.wait(0.3)
							drone.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
							drone.PrimaryPart.CFrame = CFrame.new(drone.PrimaryPart.CFrame.X, 10000, drone.PrimaryPart.CFrame.Z)
							local magnitude, lastmag = 0, 9e9
							local pos = v.Position
							repeat
								if drone and drone.Parent then
									pos = v.Position
									drone.PrimaryPart.CanCollide = false
									drone.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
									drone.PrimaryPart.AssemblyLinearVelocity = CFrame.lookAt(drone.PrimaryPart.Position * Vector3.new(1, 0, 1), pos * Vector3.new(1, 0, 1)).LookVector * 30
									magnitude = ((drone.PrimaryPart.Position * Vector3.new(1, 0, 1)) - (pos * Vector3.new(1, 0, 1))).Magnitude
								else
									break
								end
								task.wait()
							until not v or v.Parent ~= workspace.ItemDrops or not AutoCyber.Enabled or magnitude <= 2
							if not AutoCyber.Enabled then
								break
							end

							if magnitude <= 5 then
								local start = tick()
								repeat
									if drone and drone.Parent then
										drone.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
										drone.PrimaryPart.AssemblyAngularVelocity = Vector3.new(0, -30, 0)
										drone.PrimaryPart.CFrame = CFrame.new(pos - Vector3.new(0, drone.Hitbox.Size.Y, 0))
									end
									task.wait(0.02)
								until (tick() - start) >= 1.25
							end
						else
							drone.PrimaryPart.CFrame = CFrame.new(drone.PrimaryPart.CFrame.X, 10000, drone.PrimaryPart.CFrame.Z)
							drone.PrimaryPart.Velocity = Vector3.zero
							if Collect.Value == 'Generator' then
								for _, v2 in genItems do
									local gen = getGenerator(drone, v2)
									if gen then
										local magnitude = 0
										repeat
											if drone and drone.Parent then
												if getItemDrop(drone) then break end
												drone.PrimaryPart.CanCollide = false
												drone.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
												drone.PrimaryPart.AssemblyLinearVelocity = CFrame.lookAt(drone.PrimaryPart.Position * Vector3.new(1, 0, 1), gen.Position * Vector3.new(1, 0, 1)).LookVector * 30
												magnitude = ((drone.PrimaryPart.Position * Vector3.new(1, 0, 1)) - (gen.Position * Vector3.new(1, 0, 1))).Magnitude
											else
												break
											end
											task.wait()
										until not AutoCyber.Enabled or magnitude <= 5
									end
								end
							end
						end
					end
					task.wait()
				until not AutoCyber.Enabled
			else
				local drone = getDrone()
				if drone then
					drone.PrimaryPart.CFrame = CFrame.new(drone.PrimaryPart.CFrame.X, 500, drone.PrimaryPart.CFrame.Z)
				end
			end
		end,
		Tooltip = 'uses ur drone to grab loot n bring it back gng'
	})

	DropMode = AutoCyber:CreateDropdown({
		Name = 'Drop mode',
		List = {'Player', 'Base'},
		Default = 'Player',
		Tooltip = 'where the drone drops the loot it grabs'
	})

	Collect = AutoCyber:CreateDropdown({
		Name = 'Collect',
		List = {'Generator', 'Closest', 'Steal Split'},
		Default = 'Closest',
		Tooltip = 'Generator = only diamond n emerald gens, Closest = grabs whatevers closest, Steal Split = jacks the loot off the gen'
	})

	Target = AutoCyber:CreateToggle({Name = 'Target check'})
	Limit = AutoCyber:CreateToggle({Name = 'Limit to item'})
end)
run(function()
	local InfiniteAura
	local Range
	local Height
	local target
	local idleSince = 0

	local function release()
		target = nil
		store.infiniteAura = nil
		mergeRoot('InfiniteAura')
	end

	local function candidates(origin)
		local list = {}
		for _, ent in entitylib.List do
			if ent.Targetable and ent.Player and ent.RootPart and ent.RootPart.Parent and ent.Health > 0 and not fallen(ent) and (ent.RootPart.Position - origin).Magnitude <= Range.Value then
				table.insert(list, ent)
			end
		end
		return list
	end

	-- the weakest one, since moving to a new target costs about as long as a hit does
	local function choose(list)
		local best
		for _, ent in list do
			if not best or ent.Health < best.Health then
				best = ent
			end
		end
		return best
	end

	InfiniteAura = vape.Categories.Blatant:CreateModule({
		Name = 'InfiniteAura',
		Function = function(callback)
			if callback then
				InfiniteAura:Clean(runService.Heartbeat:Connect(function()
					local sword = store.tools.sword
					if not entitylib.isAlive or not sword or outranked('infiniteAura') then
						release()
						return
					end
					local list = candidates(bodyRoot().Position)
					if #list == 0 then
						target = nil
						store.infiniteAura = nil
						if tick() - idleSince > 1 then
							mergeRoot('InfiniteAura')
						end
						return
					end

					if not splitRoot('InfiniteAura') then return end
					store.infiniteAura = true
					idleSince = tick()
					store.noShoot = tick() + 1

					if not (target and table.find(list, target)) then
						target = choose(list)
					end

					sendRoot(attachPosition(target, Height.Value))
					targetinfo.Targets[target] = tick() + 1
					local struck = false
					local origin = realRoot().Position
					for _, ent in list do
						if (ent == target or (ent.RootPart.Position - origin).Magnitude <= 17) and strikeReady(ent) then
							if not struck then
								struck = true
								equip(sword)
							end
							fireRemote('strike', ent.Player)
						end
					end
					if struck then
						equip(nil)
					end
				end))
			else
				release()
			end
		end,
		Tooltip = 'Hits every enemy in range, however far, by sending the hitbox the server uses\nabove each of them in turn. Your character and camera never move.'
	})
	Range = InfiniteAura:CreateSlider({
		Name = 'Range',
		Min = 20,
		Max = 1000,
		Default = 150,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Height = InfiniteAura:CreateSlider({
		Name = 'Height',
		Min = 0,
		Max = 17,
		Default = 15,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far above each enemy the hitbox hangs. They reach 13.5 studs, your hits land from up to 17.'
	})
end)

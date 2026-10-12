run(function()
	local AutoWin
	local Eggs
	local EggHeight = {Object = {}, Value = 20}
	local Height
	local Notify
	local home
	local lastGround
	local target
	local egg
	local eggStarted = 0
	local oldSlot
	local lastStrike = 0
	local announced = false
	local view
	local skipped = setmetatable({}, {__mode = 'k'})
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include

	local function onBlock(position, distance)
		local container = workspace:FindFirstChild('BlockContainer')
		if not container then return false end
		rayCheck.FilterDescendantsInstances = {container}
		return workspace:Raycast(position, Vector3.new(0, -distance, 0), rayCheck) ~= nil
	end

	local function moveTo(position)
		sendRoot(position)
	end

	-- really selects the hotbar slot, so the tool is in your hand for everyone
	local function hold(tool, slot)
		if store.hand ~= tool and slot and slot <= 7 then
			local current = skywars.Store:getState().ActiveSlot
			if current ~= slot then
				oldSlot = oldSlot or current
				skywars.HotbarController:setActiveSlot(slot)
			end
		end
		equip(tool)
	end

	local function stop(goHome)
		target = nil
		egg = nil
		view = nil
		store.autoWin = nil
		mergeRoot('AutoWin')
		if oldSlot then
			local slot = oldSlot
			oldSlot = nil
			if entitylib.isAlive and skywars.Store:getState().ActiveSlot ~= slot then
				skywars.HotbarController:setActiveSlot(slot)
			end
		end
		equip(nil)
		if goHome and home and entitylib.isAlive and not store.split and not outranked('autoWin') then
			moveTo(home)
		end
		home = nil
	end

	local function nextEgg(eggs, origin)
		local best, bestDistance
		for _, v in eggs do
			if v.PrimaryPart and (v:GetAttribute('Health') or 0) > 0 and v:GetAttribute('TeamId') ~= lplr:GetAttribute('TeamId') and (skipped[v] or 0) < tick() then
				local distance = (v.PrimaryPart.Position - origin).Magnitude
				if not bestDistance or distance < bestDistance then
					best, bestDistance = v, distance
				end
			end
		end
		return best
	end

	local function validTarget(ent)
		if not (ent and ent.Targetable and ent.RootPart and ent.RootPart.Parent and ent.Health > 0) or fallen(ent) then return false end
		return table.find(entitylib.List, ent) ~= nil
	end

	local function step(eggs, dt)
		if not entitylib.isAlive or outranked('autoWin') then
			target = nil
			egg = nil
			view = nil
			store.autoWin = nil
			mergeRoot('AutoWin')
			return
		end
		if skywars.Store:getState().GameState ~= 'InGame' then
			stop(true)
			announced = false
			return
		end

		local root = realRoot()
		if not home and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and onBlock(bodyRoot().Position, entitylib.character.HipHeight + 3) then
			lastGround = bodyRoot().Position
		end

		-- eggs first, or everyone just respawns
		if Eggs.Enabled then
			if egg and (not (egg.Parent and egg.PrimaryPart) or (egg:GetAttribute('Health') or 0) <= 0) then
				egg = nil
			end
			if egg and tick() - eggStarted > 8 then
				skipped[egg] = tick() + 15
				egg = nil
			end
			if not egg then
				egg = nextEgg(eggs, root.Position)
				eggStarted = tick()
			end
		else
			egg = nil
		end

		if not egg and not validTarget(target) then
			target = nil
			local nearest
			for _, ent in entitylib.List do
				if ent.Player and validTarget(ent) then
					local distance = (ent.RootPart.Position - root.Position).Magnitude
					if not nearest or distance < nearest then
						target, nearest = ent, distance
					end
				end
			end
		end

		if not egg and not target then
			if home then
				stop(true)
				if Notify.Enabled and not announced then
					announced = true
					notif('AutoWin', 'Nobody is left to fight.', 5)
				end
			end
			return
		end

		if not home then
			home = lastGround or bodyRoot().Position
			store.autoWin = true
			announced = false
		end
		store.noShoot = tick() + 1

		if egg then
			view = nil
			mergeRoot('AutoWin')
			local pick, sword = store.tools.pickaxe, store.tools.sword
			local position = egg.PrimaryPart.Position
			if pick then
				moveTo(position + Vector3.new(0, EggHeight.Value, 0))
				hold(pick, store.tools.pickaxeSlot)
				fireRemote('hitBlock', (position + Vector3.new(0, 1.5, 0)) // 1)
			elseif sword then
				moveTo(position + Vector3.new(0, math.min(EggHeight.Value, 14), 0))
				hold(sword, store.tools.swordSlot)
				if lastStrike < tick() then
					lastStrike = tick() + 0.05
					fireRemote('strikeEntity', egg)
				end
			end
			return
		end

		local sword = store.tools.sword
		if not sword then return end
		local goal = attachPosition(target, Height.Value)
		if splitRoot('AutoWin') then
			-- the hitbox does the jumping about, the body you watch glides after the target
			sendRoot(goal)
			local body = bodyRoot()
			local want = target.RootPart.Position + Vector3.new(0, Height.Value, 0)
			want = Vector3.new(want.X, math.max(want.Y, voidFloor()), want.Z)
			view = (view or body.Position):Lerp(want, 1 - math.exp(-(dt or 1 / 60) * 6))
			body.CFrame = CFrame.new(view) * (body.CFrame - body.CFrame.Position)
			body.AssemblyLinearVelocity = Vector3.zero
		else
			view = nil
			moveTo(goal)
		end
		hold(sword, store.tools.swordSlot)
		targetinfo.Targets[target] = tick() + 1
		if targetinfo.Focus then
			targetinfo.Focus[target] = tick() + 1
		end
		-- every frame the cooldown allows, for the target and anyone else in reach
		if strikeReady(target) then
			fireRemote('strike', target.Player)
		end
		for _, ent in entitylib.List do
			if ent ~= target and ent.Targetable and ent.Player and ent.RootPart and ent.Health > 0 and (ent.RootPart.Position - root.Position).Magnitude <= 17 and strikeReady(ent) then
				fireRemote('strike', ent.Player)
			end
		end
	end

	AutoWin = vape.Categories.Utility:CreateModule({
		Name = 'AutoWin v2',
		Function = function(callback)
			if callback then
				local eggs = collection('egg', AutoWin)
				AutoWin:Clean(entitylib.Events.LocalRemoved:Connect(function()
					target = nil
					egg = nil
					home = nil
					lastGround = nil
					oldSlot = nil
					view = nil
					store.autoWin = nil
				end))
				AutoWin:Clean(runService.Heartbeat:Connect(function(dt)
					step(eggs, dt)
				end))
			else
				stop(true)
			end
		end,
		Tooltip = 'Breaks every enemy egg, then sticks to each enemy\nin turn until nobody is left.'
	})
	Eggs = AutoWin:CreateToggle({
		Name = 'Break eggs first',
		Default = true,
		Function = function(callback)
			EggHeight.Object.Visible = callback
		end
	})
	EggHeight = AutoWin:CreateSlider({
		Name = 'Egg height',
		Min = 8,
		Max = 22,
		Default = 20,
		Darker = true,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far above an egg you hang. A pickaxe reaches from 22, a sword from 14.'
	})
	Height = AutoWin:CreateSlider({
		Name = 'Player height',
		Min = 0,
		Max = 17,
		Default = 15,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far above a player you stay. They reach 13.5 studs, your hits land from up to 17.'
	})
	Notify = AutoWin:CreateToggle({
		Name = 'Notify',
		Default = true
	})
end)

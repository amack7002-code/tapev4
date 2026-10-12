run(function()
	local CannonHandController = bedwars.CannonHandController
	local CannonController = bedwars.CannonController
	local oldLaunchSelf = CannonHandController.launchSelf
	local oldStopAiming = CannonController.stopAiming
	local oldStartAiming = CannonController.startAiming
	local AutoDavey
	local AutoDaveyAutojump
	local AutoDaveyAutoLaunch
	local AutoDaveyAutoBreak
	local AutoDaveyPickaxeCheck
	local AutoDaveyAutoSwitch
	local LaunchDelay
	local BreakDelay
	local isLaunching = false
	local didAutoLaunch = false

	local function getCannonSlot()
		for i, v in pairs(store.inventory.hotbar) do
			if v.item then
				local t = tostring(v.item.itemType):lower()
				if t:find("cannon") then
					return i - 1
				end
			end
		end
		return nil
	end

	local function hasWoodPickaxeOnly()
		local bestTier = 0
		for _, slot in pairs(store.inventory.hotbar) do
			if slot.item then
				local t = tostring(slot.item.itemType):lower()
				if t == "wood_pickaxe" and bestTier < 1 then
					bestTier = 1
				elseif (t:find("pickaxe") or t:find("drill")) and t ~= "wood_pickaxe" then
					bestTier = 2
				end
			end
		end
		return bestTier == 1
	end

	local function getNearestCannon()
		if not entitylib.isAlive then return nil end
		local nearest
		local nearestDist = math.huge
		for i, v in pairs(CannonController.getCannons()) do
			pcall(function()
				local dist = (v.Position - entitylib.character.RootPart.Position).Magnitude
				if dist < nearestDist and dist < 30 then
					nearestDist = dist
					nearest = v
				end
			end)
		end
		return nearest
	end

	local function findCannonModel(pos)
		local closest = nil
		local closestDist = 8
		for _, obj in store.blocks do
			if obj and obj:IsA("BasePart") and obj.Name == "cannon" then
				local dist = (obj.Position - pos).Magnitude
				if dist < closestDist then
					closestDist = dist
					closest = obj
				end
			end
		end
		return closest
	end

	local function doBreakCannon(cannon)
		if not entitylib.isAlive then return end
		if not cannon or not cannon.Parent then return end
		local block, blockpos = getPlacedBlock(cannon.Position)
		if block and block.Name == 'cannon' and
		   (entitylib.character.RootPart.Position - block.Position).Magnitude < 30 then
			pcall(bedwars.breakBlock, block, false, nil, true)
		else
			local directBlock = findCannonModel(cannon.Position)
			if directBlock and directBlock.Parent then
				pcall(bedwars.breakBlock, directBlock, false, nil, true)
			end
		end
	end

	local function firstHitCannon(cannon)
		if not entitylib.isAlive then return end
		if not cannon or not cannon.Parent then return end
		if hasWoodPickaxeOnly() then
			doBreakCannon(cannon)
		end
	end

	local function breakCannon(cannon, shootfunc)
		if not entitylib.isAlive then
			isLaunching = false
			return shootfunc()
		end

		local cannonSlot = nil

		if AutoDaveyAutoSwitch.Enabled and not isHoldingPickaxe() then
			local pickaxeSlot = getPickaxeSlot()
			if not pickaxeSlot then
				notif("AutoDavey", "No pickaxe found in hotbar!", 3)
				if AutoDaveyAutojump.Enabled and entitylib.isAlive and entitylib.character.Humanoid then
					entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end
				isLaunching = false
				return shootfunc()
			end
			cannonSlot = getCannonSlot()
			if hotbarSwitch(pickaxeSlot) then
				task.wait(0.05)
			end
		end

		if AutoDaveyPickaxeCheck.Enabled and not isHoldingPickaxe() then
			notif("AutoDavey", "You need to HOLD a pickaxe to break cannons!", 3)
			if AutoDaveyAutojump.Enabled and entitylib.isAlive and entitylib.character.Humanoid then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
			isLaunching = false
			return shootfunc()
		end

		if BreakDelay.Value > 0 then
			task.wait(BreakDelay.Value)
		end

		local cannonRef = cannon
		if AutoDaveyAutojump.Enabled and entitylib.isAlive and entitylib.character.Humanoid then
			entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
		shootfunc()
		isLaunching = false

		task.spawn(function()
			task.wait(0.05)
			doBreakCannon(cannonRef)
			task.wait(0.35)
			if cannonRef and cannonRef.Parent then
				doBreakCannon(cannonRef)
			end
			if AutoDaveyAutoSwitch.Enabled and cannonSlot then
				task.wait(0.05)
				hotbarSwitch(cannonSlot)
			end
		end)
	end

	AutoDavey = vape.Categories.Kits:CreateModule({
		Name = 'AutoDavey',
		Function = function(callback)
			if callback then
				CannonHandController.launchSelf = function(...)
					if isLaunching then
						isLaunching = false
						return oldLaunchSelf(...)
					end
					isLaunching = true
					if LaunchDelay.Value > 0 then
						task.wait(LaunchDelay.Value)
					end
					if AutoDaveyAutoBreak.Enabled then
						local cannon = getNearestCannon()
						if cannon then
							local args = {...}
							breakCannon(cannon, function()
								oldLaunchSelf(unpack(args))
							end)
							return
						else
							if AutoDaveyAutojump.Enabled and entitylib.isAlive and entitylib.character.Humanoid then
								entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
							end
							local res = oldLaunchSelf(...)
							isLaunching = false
							return res
						end
					else
						if AutoDaveyAutojump.Enabled and entitylib.isAlive and entitylib.character.Humanoid then
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
						local res = oldLaunchSelf(...)
						isLaunching = false
						return res
					end
				end

				local aimedCannon = nil
				CannonController.startAiming = function(...)
					didAutoLaunch = false
					isLaunching = false
					local result = oldStartAiming(...)
					aimedCannon = getNearestCannon()
					return result
				end

				CannonController.stopAiming = function(...)
					local cannon = aimedCannon or getNearestCannon()
					local result = oldStopAiming(...)
					aimedCannon = nil
					isLaunching = false
					if AutoDaveyAutoLaunch.Enabled and not didAutoLaunch then
						didAutoLaunch = true
						if AutoDaveyAutoBreak.Enabled and AutoDaveyPickaxeCheck.Enabled and not isHoldingPickaxe() and not AutoDaveyAutoSwitch.Enabled then
							notif("AutoDavey", "Hold a pickaxe to auto-break!", 3)
							return result
						end
						if cannon then
							task.spawn(function()
								pcall(CannonHandController.launchSelf, CannonHandController, cannon)
							end)
						end
					end
					return result
				end

				local firstHitDebounce = {}
				AutoDavey:Clean(workspace.DescendantAdded:Connect(function(obj)
					if not (obj:IsA("BasePart") and obj.Name == "cannon") then return end
					if firstHitDebounce[obj] then return end
					firstHitDebounce[obj] = true
					task.spawn(function()
						task.wait(0.5)
						if AutoDaveyAutoBreak.Enabled and hasWoodPickaxeOnly() then
							local dist = entitylib.isAlive
								and (entitylib.character.RootPart.Position - obj.Position).Magnitude
								or math.huge
							if dist < 20 and obj.Parent then
								firstHitCannon(obj)
							end
						end
						firstHitDebounce[obj] = nil
					end)
				end))
			else
				CannonHandController.launchSelf = oldLaunchSelf
				CannonController.stopAiming = oldStopAiming
				CannonController.startAiming = oldStartAiming
				isLaunching = false
				didAutoLaunch = false
			end
		end,
	})

	LaunchDelay = AutoDavey:CreateSlider({
		Name = 'Launch Delay',
		Min = 0,
		Max = 2,
		Default = 0,
		Decimal = 10,
		Suffix = 's',
	})
	BreakDelay = AutoDavey:CreateSlider({
		Name = 'Break Delay',
		Min = 0,
		Max = 2,
		Default = 0,
		Decimal = 10,
		Suffix = 's',
	})

	AutoDaveyAutojump = AutoDavey:CreateToggle({
		Name = 'Auto Jump',
		Default = true,
	})
	AutoDaveyAutoLaunch = AutoDavey:CreateToggle({
		Name = 'Auto Launch',
		Default = true,
		Tooltip = 'automatically lauches u after your done aiming'
	})
	AutoDaveyAutoBreak = AutoDavey:CreateToggle({
		Name = 'Auto Break',
		Default = true,
		Tooltip = 'auto breaks cannon when you lauch'
	})
	AutoDaveyPickaxeCheck = AutoDavey:CreateToggle({
		Name = 'Pickaxe Check',
		Default = true,
	})
	AutoDaveyAutoSwitch = AutoDavey:CreateToggle({
		Name = 'AutoSwitch Pickaxe',
		Default = false,
		Tooltip = 'switches to pickaxe when breaking thens switches back to cannon'
	})
end)
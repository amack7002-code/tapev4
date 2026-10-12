run(function()
	local Attack
	local Mine
	local Place
	local oldAttackReach, oldMineReach, oldPlaceReach
	local SwordReach, MineReach
	local AirReach, AirReachChance
	local airReachState = false
	local airReachRolled = false
	local _airReachThread

	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			if callback then
				if SwordReach and SwordReach.Enabled then
					task.spawn(function()
						repeat task.wait(0.1) until (bedwars.CombatConstant and bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE) or not Reach.Enabled
						if not Reach.Enabled or not SwordReach.Enabled then return end
						oldAttackReach = bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE
						bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
					end)
				end
				
				task.spawn(function()
					repeat task.wait(0.1) until bedwars.BlockBreakController or not Reach.Enabled
					if not Reach.Enabled or not MineReach or not MineReach.Enabled then return end
					
					pcall(function()
						local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
						if blockBreaker then
							oldMineReach = oldMineReach or blockBreaker:getRange()
							blockBreaker:setRange(Mine.Value)
						end
					end)
				end)
				
				local _reachLoopThread = task.spawn(function()
					while Reach.Enabled do
						task.wait(5)
						if not Reach.Enabled then break end
						if SwordReach.Enabled and not (AirReach and AirReach.Enabled) and bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE ~= Attack.Value + 2 then
							bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
						end
						if MineReach.Enabled then
							pcall(function()
								local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
								if blockBreaker and blockBreaker:getRange() ~= Mine.Value then
									blockBreaker:setRange(Mine.Value)
								end
							end)
						end
					end
				end)
				airReachRolled = false
				_airReachThread = task.spawn(function()
					while Reach.Enabled do
						task.wait(0.05)
						if not Reach.Enabled then break end
						if not AirReach or not AirReach.Enabled or not SwordReach.Enabled then
							airReachRolled = false
						else
							local ent = store.KillauraTarget
							local tchar = ent and ent.Character
							local hum = tchar and tchar:FindFirstChildOfClass('Humanoid')
							local inAir = false
							if hum then
								inAir = hum.FloorMaterial == Enum.Material.Air
								if not inAir then
									local st = hum:GetState()
									inAir = st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall
								end
								if not inAir then
									local root = tchar.PrimaryPart
									local vy = root and root.AssemblyLinearVelocity.Y or 0
									inAir = math.abs(vy) > 3
								end
							end
							if not inAir then
								airReachRolled = false
								bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
							else
								if not airReachRolled then
									airReachRolled = true
									airReachState = math.random(1, 100) <= AirReachChance.Value
								end
								bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = airReachState and (Attack.Value + 2) or (oldAttackReach or 14.4)
							end
						end
					end
				end)
				Reach:Clean(function()
					if _airReachThread then
						pcall(task.cancel, _airReachThread)
						_airReachThread = nil
					end
					airReachRolled = false
				end)
				Reach:Clean(function()
					if _reachLoopThread then
						pcall(task.cancel, _reachLoopThread)
						_reachLoopThread = nil
					end
				end)
			else
				if oldAttackReach then
					bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = oldAttackReach
				end
				
				if oldMineReach then
					pcall(function()
						local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
						if blockBreaker then
							blockBreaker:setRange(oldMineReach)
						end
					end)
				end

				oldAttackReach, oldMineReach = nil, nil
			end
		end,
		Tooltip = 'increases reach for attacking, mining'
	})
	
	SwordReach = Reach:CreateToggle({
		Name = 'Sword Reach',
		Default = true,
		Function = function(v)
			if Attack then Attack.Object.Visible = v end
			if Reach.Enabled then
				if v then
					bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
				else
					bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = oldAttackReach or 14.4
				end
			end
		end
	})

	Attack = Reach:CreateSlider({
		Name = 'Attack Range',
		Darker = true,
		Visible = true,
		Min = 0,
		Max = 20,
		Default = 18,
		Function = function(val)
			if Reach.Enabled then
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = val + 2
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	
	AirReach = Reach:CreateToggle({
		Name = 'Air Reach',
		Default = false,
		Tooltip = 'puts ur reach back to normal when they in the air so it looks legit',
		Function = function(v)
			if AirReachChance then AirReachChance.Object.Visible = v end
			if not v and Reach.Enabled and SwordReach and SwordReach.Enabled then
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
			end
		end
	})

	AirReachChance = Reach:CreateSlider({
		Name = 'Air Reach Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Suffix = '%',
		Darker = true,
		Visible = false,
		Tooltip = 'how often u still get reach while they jumpin'
	})

	MineReach = Reach:CreateToggle({
		Name = 'Mine Reach',
		Default = false,
		Function = function(v)
			if Mine then Mine.Object.Visible = v end
		end
	})

	Mine = Reach:CreateSlider({
		Name = 'Mine Range',
		Darker = true,
		Visible = false,
		Min = 0,
		Max = 30,
		Default = 18,
		Function = function(val)
			if Reach.Enabled then
				pcall(function()
					local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
					if blockBreaker then
						blockBreaker:setRange(val)
					end
				end)
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
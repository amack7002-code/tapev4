run(function()
	local AutoHonor
	local Delay
	local honoredusers = {}
	local maxhonors = 2
	
	local function getTeammates()
		local teammates = {}
		local nonteammates = {}
		local myTeam = lplr.Team
		
		for i, plr in playersService:GetPlayers() do
			if plr ~= lplr then
				if plr.Team == myTeam then
					table.insert(teammates, plr)
				else
					table.insert(nonteammates, plr)
				end
			end
		end
		return teammates, nonteammates
	end
	
	local function honorPlayers()
		if #honoredusers >= maxhonors then return end
		
		local teammates, nonteammates = getTeammates()
		
		if #teammates > 0 and #honoredusers < maxhonors then
			local randomTeammate = teammates[math.random(1, #teammates)]
			if not honoredusers[randomTeammate.UserId] then
				task.wait(Delay.Value)
				bedwars.HonorController:honorPlayer(randomTeammate.UserId)
				honoredusers[randomTeammate.UserId] = true
			end
		end
		
		if #nonteammates > 0 and #honoredusers < maxhonors then
			local randomEnemy = nonteammates[math.random(1, #nonteammates)]
			if not honoredusers[randomEnemy.UserId] then
				task.wait(Delay.Value)
				bedwars.HonorController:honorPlayer(randomEnemy.UserId)
				honoredusers[randomEnemy.UserId] = true
			end
		end
	end
	
	AutoHonor = vape.Categories.Minigames:CreateModule({
		Name = "AutoHonor",
		Function = function(callback)
			if callback then
				AutoHonor:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill and deathTable.entityInstance == lplr.Character and isEveryoneDead() and store.matchState ~= 2 then
						honorPlayers()
					end
				end))
				AutoHonor:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(...)
					honorPlayers()
				end))
			else
				table.clear(honoredusers)
			end
		end
	})
	Delay = AutoHonor:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Default = 0.05
	})
end)
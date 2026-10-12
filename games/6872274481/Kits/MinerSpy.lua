run(function()
	local MinerSpy
	local IgnoreTeammatesMiner

	MinerSpy = vape.Categories.Kits:CreateModule({
		Name = "MinerSpy",
		Tooltip = 'notifies when players get petrified or mined by a miner',
		Function = function(callback)
			if callback then
				MinerSpy:Clean(bedwars.Client:OnEvent("Petrified", function(tbl)
					if not MinerSpy.Enabled then return end
					local victim = playersService:GetPlayerFromCharacter(tbl.to)
					local killer = playersService:GetPlayerFromCharacter(tbl.killer)
					if not victim then return end

					if IgnoreTeammatesMiner.Enabled then
						if victim.Team == lplr.Team then return end
					end

					local victimName = victim.Name
					victimName = victimName:sub(1, 1):upper() .. victimName:sub(2)

					local killerText = ''
					if killer then
						local killerName = killer.Name
						killerName = killerName:sub(1, 1):upper() .. killerName:sub(2)
						killerText = ' by ' .. killerName
					end

					notif("MinerSpy", victimName .. " was petrified" .. killerText, 8)
				end))

				MinerSpy:Clean(bedwars.Client:OnEvent("PetrifiedPlayerDestroyed", function(tbl)
					if not MinerSpy.Enabled then return end
					local destroyer = tbl.destroyer

					local destroyerText = 'Unknown'
					if destroyer then
						local destroyerName = destroyer.Name
						destroyerText = destroyerName:sub(1, 1):upper() .. destroyerName:sub(2)
						if IgnoreTeammatesMiner.Enabled and destroyer.Team == lplr.Team then return end
					end

					local rewardText = ''
					if tbl.rewards then
						local totals = {}
						local order = {}
						for _, reward in ipairs(tbl.rewards) do
							local item = tostring(reward.itemType) or 'unknown'
							local amount = tonumber(reward.amount) or 0
							if not totals[item] then
								totals[item] = 0
								table.insert(order, item)
							end
							totals[item] = totals[item] + amount
						end
						local parts = {}
						for _, item in ipairs(order) do
							table.insert(parts, item .. ' x' .. totals[item])
						end
						if #parts > 0 then
							rewardText = ' | Loot: ' .. table.concat(parts, ', ')
						end
					end

					notif("MinerSpy", destroyerText .. " mined a petrified player" .. rewardText, 8)
				end))
			end
		end
	})
	IgnoreTeammatesMiner = MinerSpy:CreateToggle({Name='Ignore Teammates',Default=true})
end)
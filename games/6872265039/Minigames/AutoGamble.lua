run(function()
	local AutoGamble
	local SpawnRemote = bedwars.Client:GetNamespace('RewardCrate'):Get('SpawnRewardCrate')
	local OpenRemote = bedwars.Client:GetNamespace('RewardCrate'):Get('OpenRewardCrate')
	local crateTypes = {'level_up_crate', 'diamond_lucky_crate', 'afk_crate', 'murder_crate', 'kitskin_crate'}

	local function getNextCrateId(skip)
		local active = bedwars.CrateAltarController and bedwars.CrateAltarController.activeCrates
		if type(active) ~= 'table' then return nil end
		for _, crateList in pairs(active) do
			if type(crateList) == 'table' then
				for _, crate in pairs(crateList) do
					if type(crate) == 'table' then
						local id = crate.attributes and crate.attributes.crateId
						if not id and crate.instance then
							local ok, a = pcall(function() return crate.instance:GetAttribute('crateId') end)
							if ok then id = a end
						end
						if id and not (skip and skip[id]) then
							return id
						end
					end
				end
			end
		end
		return nil
	end

	AutoGamble = vape.Categories.Minigames:CreateModule({
		Name = 'AutoGamble',
		Function = function(callback)
			if callback then
				pcall(function()
					AutoGamble:Clean(bedwars.Client:GetNamespace('RewardCrate'):Get('CrateOpened'):Connect(function(data)
						if data.openingPlayer == lplr then
							local tab = bedwars.CrateItemMeta and bedwars.CrateItemMeta[data.reward.itemType] or {displayName = data.reward.itemType or 'unknown'}
							notif('AutoGamble', 'Won '..tab.displayName, 5)
						end
					end))
				end)

				task.spawn(function()
					local opened = {}
					local spawnAltar = 1
					local knownType = nil
					repeat
						local crateId = getNextCrateId(opened)
						if crateId then
							opened[crateId] = true
							OpenRemote:SendToServer({ crateId = crateId })
							task.wait(1)
						else
							local list = knownType and {knownType} or crateTypes
							local spawned = false
							for _, ct in ipairs(list) do
								if not AutoGamble.Enabled then break end
								SpawnRemote:SendToServer({ altarId = spawnAltar, crateType = ct, useAltarUpgrade = false })
								for _ = 1, 12 do
									if not AutoGamble.Enabled then break end
									if getNextCrateId(opened) then
										knownType = ct
										spawned = true
										break
									end
									task.wait(0.2)
								end
								if spawned then break end
							end
							spawnAltar = spawnAltar == 1 and 0 or 1
							if not spawned then
								knownType = nil
								task.wait(0.5)
							end
						end
					until not AutoGamble.Enabled
				end)
			end
		end,
		Tooltip = 'auto opens whatever crate u own on whatever altar is open'
	})
end)
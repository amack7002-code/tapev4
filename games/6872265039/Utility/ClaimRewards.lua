run(function()
	local ClaimRewards, CratesOnly, Notify
	local confirmed = {}
	local warned = false

	local function alreadyClaimed(claimed, id)
		return confirmed[id] or claimed[id] == true or table.find(claimed, id) ~= nil
	end

	local function claimAvailable()
		local rewards = bedwars.MilestoneRewards
		if type(rewards) ~= 'table' then
			if not warned then
				warned = true
				notif('ClaimRewards', 'reward data missing gng', 5)
			end
			return
		end

		local state = bedwars.Store:getState()
		local info = state and state.Bedwars
		if type(info) ~= 'table' then return end
		local level = tonumber(info.playerLevel) or 0
		local controller = bedwars.MilestonesController
		local claimed = controller and controller.milestoneRewardsClaimed

		if type(claimed) ~= 'table' then
			claimed = type(info.milestoneRewardsClaimed) == 'table' and info.milestoneRewardsClaimed or {}
		end

		for _, reward in pairs(rewards) do
			if not ClaimRewards.Enabled then break end

			if type(reward) == 'table' and reward.id ~= nil
				and (tonumber(reward.levelRequirement) or math.huge) <= level
				and (not CratesOnly.Enabled or reward.instantClaim == true)
				and not alreadyClaimed(claimed, reward.id) then

				local ok, result = pcall(function()
					return bedwars.Client:Get('ClaimMilestoneReward'):CallServer(reward.id)
				end)

				if ok and result then
					confirmed[reward.id] = true

					if Notify.Enabled then
						notif('ClaimRewards', 'claimed '..tostring(reward.description or reward.id):lower(), 5)
					end
				end

				task.wait(1)
			end
		end
	end

	ClaimRewards = vape.Categories.Utility:CreateModule({
		Name = 'ClaimRewards',
		Function = function(enabled)
			if not enabled then return end

			task.spawn(function()
				while ClaimRewards.Enabled do
					local ok, err = pcall(claimAvailable)

					if not ok and not warned then
						warned = true
						warn(err)
						notif('ClaimRewards', 'claim check failed gng', 5)
					end

					task.wait(5)
				end
			end)
		end,
		Tooltip = 'claims ur unlocked milestone rewards for u'
	})

	CratesOnly = ClaimRewards:CreateToggle({
		Name = 'crates only',
		Tooltip = 'only grab instant rewards like crates'
	})

	Notify = ClaimRewards:CreateToggle({
		Name = 'notify',
		Default = true,
		Tooltip = 'tells u what got claimed'
	})
end)

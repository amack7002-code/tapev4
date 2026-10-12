run(function()
	local Knit = require(replicatedStorage.Modules.Knit.Client)
	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end

	bd = setmetatable({
		BedwarsShop = require(replicatedStorage.Constants.BedWarsShop),
		BedwarsUpgrades = require(replicatedStorage.Constants.BedWarsTeamUpgrades),
		Blink = require(replicatedStorage.Blink.Client),
		BreakTimes = require(replicatedStorage.Constants.Blocks),
		BowClient = require(replicatedStorage.Client.Components.All.Tools.BowClient),
		CombatConstants = require(replicatedStorage.Constants.Melee),
		Communication = require(replicatedStorage.Client.Communication),
		Knit = Knit,
		Entity = require(replicatedStorage.Modules.Entity),
		ServerData = require(replicatedStorage.Modules.ServerData),
	}, {
		__index = function(self, ind)
			rawset(self, ind, ind:find('Service') and Knit.GetService(ind) or Knit.GetController(ind))
			return rawget(self, ind)
		end
	})

	task.spawn(function()
		local map = workspace:WaitForChild('Map', 99999)
		if map and vape.Loaded ~= nil then
			vape:Clean(map.DescendantAdded:Connect(function(v)
				parsePositions(v, function(pos)
					store.blocks[pos] = v
				end)
			end))
			vape:Clean(map.DescendantRemoving:Connect(function(v)
				parsePositions(v, function(pos)
					if store.blocks[pos] == v then
						store.blocks[pos] = nil
						store.serverBlocks[pos] = nil
					end
				end)
			end))
			for _, v in map:GetDescendants() do
				parsePositions(v, function(pos)
					store.blocks[pos] = v
					store.serverBlocks[pos] = v
				end)
			end
		end
	end)

	vape:Clean(function()
		table.clear(store.blocks)
		table.clear(store)
	end)
end)
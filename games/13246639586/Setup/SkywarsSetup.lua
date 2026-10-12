run(function()
	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local ControllerTable = {}

	if not debug.getupvalue(Flamework.ignite, 1) then
		repeat task.wait() until debug.getupvalue(Flamework.ignite, 1)
	end

	local function searchFunction(name, i2, v2)
		for i3, v3 in debug.getconstants(v2) do
			if tostring(v3):find('-') == 9 then
				remotes[(rawget(remotes, i2) and name..':' or '')..i2] = v3
			end
		end
	end

	for i, v in debug.getupvalue(Flamework.ignite, 2).idToObj do
		local name = tostring(v)
		ControllerTable[name] = Flamework.resolveDependency(i)
		for i2, v2 in v do
			if type(v2) == 'function' then
				searchFunction(name, i2, v2)

				for _, v3 in debug.getprotos(v2) do
					searchFunction(name, i2, v3)
				end
			end
		end
	end

	local roactCheck = replicatedStorage['rbxts_include']['node_modules']['@rbxts']:FindFirstChild('roact')
	skywars = setmetatable({
		CameraUtil = require(lplr.PlayerScripts.TS.util['camera-util']).CameraUtil,
		FireOrigin = debug.getupvalue(ControllerTable.ProjectileController.chargeBow, 11).ORIGIN_OFFSET,
		Gravity = debug.getupvalue(ControllerTable.ProjectileController.chargeBow, 13).WORLD_ACCELERATION.Y,
		ItemMeta = debug.getupvalue(ControllerTable.HotbarController.getSword, 1),
		Remotes = debug.getupvalue(ControllerTable.MeleeController.strikeDesktop, 6),
		Roact = require(roactCheck and roactCheck.src or replicatedStorage['rbxts_include']['node_modules']['@rbxts'].ReactLua['node_modules']['@jsdotlua']['roact-compat']),
		Store = require(lplr.PlayerScripts.TS.ui.rodux['global-store']).GlobalStore,
		Shop = require(replicatedStorage.TS.game.shop['game-shop']).Shops
	}, {
		__index = function(self, ind)
			rawset(self, ind, ControllerTable[ind])
			return rawget(self, ind)
		end
	})

	local kills = sessioninfo:AddItem('Kills')
	local eggs = sessioninfo:AddItem('Eggs')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	task.delay(1, function()
		games:Increment()
	end)

	local function updateStore(newStore, oldStore)
		if newStore.GameCurrency ~= oldStore.GameCurrency then
			vapeEvents.CurrencyChange:Fire(table.clone(newStore.GameCurrency.Quantities))
		end

		if newStore.ActiveSlot ~= oldStore.ActiveSlot then
			store.hand = newStore.Inventory.Contents[newStore.ActiveSlot]
			store.hand = store.hand and skywars.ItemMeta[store.hand.Type] or {}
		end

		if newStore.Inventory ~= oldStore.Inventory then
			store.inventory = newStore.Inventory.Contents
			store.hand = newStore.Inventory.Contents[newStore.ActiveSlot]
			store.hand = store.hand and skywars.ItemMeta[store.hand.Type] or {}
			store.tools.sword = getSword()
			store.tools.pickaxe = getPickaxe()
			vapeEvents.InventoryAmountChanged:Fire()
		end

		if oldStore.Profile and oldStore.Profile.WasTeleporting and newStore.Profile.Stats ~= oldStore.Profile.Stats then
			if newStore.Profile.Stats.Kills ~= oldStore.Profile.Stats.Kills and oldStore.Profile.Stats.Kills then
				kills:Increment()
			end

			if newStore.Profile.Stats.Wins ~= oldStore.Profile.Stats.Wins and oldStore.Profile.Stats.Wins then
				wins:Increment()
			end
		end
	end

	local storeChanged = skywars.Store.changed:connect(updateStore)
	updateStore(skywars.Store:getState(), {})

	task.spawn(function()
		repeat
			if entitylib.isAlive then
				entitylib.character.GroundPosition = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and entitylib.character.RootPart.Position or entitylib.character.GroundPosition
			end
			task.wait()
		until vape.Loaded == nil
	end)

	vape:Clean(workspace.BlockContainer.DescendantAdded:Connect(function(v)
		parsePositions(v, function(pos)
			store.blocks[pos] = v
		end)
	end))
	vape:Clean(workspace.BlockContainer.DescendantRemoving:Connect(function(v)
		parsePositions(v, function(pos)
			store.blocks[pos] = nil
		end)
	end))
	for _, v in workspace.BlockContainer:GetDescendants() do
		parsePositions(v, function(pos)
			store.blocks[pos] = v
		end)
	end

	vape:Clean(function()
		for _, v in vapeEvents do
			v:Destroy()
		end
		for _, playerConnections in entitylib.PlayerConnections do
			for _, connection in playerConnections do
				connection:Disconnect()
			end
		end
		table.clear(entitylib.PlayerConnections)
		table.clear(ControllerTable)
		table.clear(remotes)
		table.clear(vapeEvents)
		table.clear(skywars)
		table.clear(store.blocks)
		table.clear(store)
		storeChanged:disconnect()
		storeChanged = nil
	end)
end)
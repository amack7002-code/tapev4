local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})

local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local collectionService = cloneref(game:GetService('CollectionService'))
local httpService = cloneref(game:GetService('HttpService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local tweenService = cloneref(game:GetService('TweenService'))
local runService = cloneref(game:GetService('RunService'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local getcustomasset = vape.Libraries.getcustomasset

local skywars, remotes = {}, {}
local store = {
	blocks = {},
	hand = {},
	inventory = {},
	tools = {},
	noShoot = tick()
}
local ViewmodelTool
local ViewmodelMotor

local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, connections = {}, {}

	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if customadd then
				customadd(objs, v, tag)
				return
			end
			table.insert(objs, v)
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if customremove then
				customremove(objs, v, tag)
				return
			end
			v = table.find(objs, v)
			if v then
				table.remove(objs, v)
			end
		end))

		for _, v in collectionService:GetTagged(tag) do
			if customadd then
				customadd(objs, v, tag)
				continue
			end
			table.insert(objs, v)
		end
	end

	local cleanFunc = function(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end

local function getItem(check)
	for _, item in store.inventory do
		if item.Type == check then
			return item
		end
	end
end

local function getSword()
	local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
	for slot, item in store.inventory do
		item = skywars.ItemMeta[item.Type]
		local swordDamage = item.Melee and item.Melee.Damage or 0
		if swordDamage > bestSwordDamage then
			bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
		end
	end
	return bestSword, bestSwordSlot
end

local function getPickaxe()
	local bestPick, bestPickSlot, bestPickDamage = nil, nil, math.huge
	for slot, item in store.inventory do
		item = skywars.ItemMeta[item.Type]
		local pickDamage = item.Pickaxe and item.Pickaxe.TimeMultiplier or math.huge
		if pickDamage < bestPickDamage then
			bestPick, bestPickSlot, bestPickDamage = item, slot, pickDamage
		end
	end
	return bestPick, bestPickSlot
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function parsePositions(v, func)
	if v:IsA('BasePart') and v.Size // 1 == v.Size then
		local start = (v.Position - (v.Size / 2)) + Vector3.new(1.5, 1.5, 1.5)
		for x = 0, v.Size.X - 1, 3 do
			for y = 0, v.Size.Y - 1, 3 do
				for z = 0, v.Size.Z - 1, 3 do
					func(start + Vector3.new(x, y, z))
				end
			end
		end
	end
end

local function waitForChildOfType(obj, name, timeout, prop)
	local checktick = tick() + timeout
	local returned
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if returned or checktick < tick() then break end
		task.wait()
	until false
	return returned
end

run(function()
	entitylib.addPlayer = function(plr)
		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('TeamId'):Connect(function()
				for i, v in entitylib.List do
					if v.Targetable ~= entitylib.targetCheck(v) then
						entitylib.refreshEntity(v.Character, v.Player)
					end
				end

				if plr == lplr then
					entitylib.start()
				else
					entitylib.refreshEntity(plr.Character, plr)
				end
			end)
		}
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum = waitForChildOfType(char, 'Humanoid', 10)
			local humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
			local head = char:WaitForChild('Head', 10) or humrootpart

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (plr:GetAttribute('Health') or 100),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					MaxHealth = 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entity.GroundPosition = Vector3.zero
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
				else
					entity.Targetable = (teamfunc or entitylib.targetCheck)(entity)

					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = (plr:GetAttribute('Health') or 100)
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end
			end
			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.getUpdateConnections = function(ent)
		return {
			ent.Player:GetAttributeChangedSignal('Health'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}
	end

	entitylib.targetCheck = function(ent)
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		return lplr:GetAttribute('TeamId') ~= ent.Player:GetAttribute('TeamId')
	end

	entitylib.getEntityColor = function(ent)
		ent = ent.Player
		if not (ent and vape.Categories.Main.Options['Use team color'].Enabled) then return end
		if isFriend(ent, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end
		return skywars.TeamController:getTeamColour(ent:GetAttribute('TeamId'))
	end
end)
entitylib.start()

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

--vape remove thing
for _, v in {'Reach', 'TriggerBot', 'Disabler', 'SilentAim', 'AutoRejoin', 'Rejoin', 'ServerHop', 'MurderMystery'} do
	vape:Remove(v)
end
run(function()
	local AutoClicker
	local CPS
	local Blocks
	local BlocksCPS = {Object = {}}
	local Thread
	local old
	
	local function AutoClick()
		Thread = task.delay(1 / 8, function()
			repeat
				local held = store.hand
				if held then
					if held.Rewrite and Blocks.Enabled then
						local block = skywars.ItemMeta[held.Rewrite.Type:gsub('{TeamId}', skywars.TeamController:getPlayerTeamId(lplr) or 'White')]
						local ray = skywars.BlockRaycastController:executeRaycast(inputService:GetMouseLocation(), 1, 0, block)
						if ray and ray.BlockPosition then
							skywars.BlockController:placeBlock(ray.BlockPosition, held.Name, block, ray.Rotation)
						end
					elseif held.Melee then
						skywars.MeleeController:strike(held)
					end
				end
	
				task.wait(1 / (held and held.Rewrite and BlocksCPS or CPS).GetRandomValue())
			until not AutoClicker.Enabled
		end)
	end
	
	AutoClicker = vape.Categories.Combat:CreateModule({
		Name = 'AutoClicker',
		Function = function(callback)
			if callback then
				AutoClicker:Clean(inputService.InputBegan:Connect(function(input, gameProcessed)
					if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
						AutoClick()
					end
				end))
				AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 and Thread then
						task.cancel(Thread)
						Thread = nil
					end
				end))
			end
		end,
		Tooltip = 'Hold attack button to automatically click'
	})
	CPS = AutoClicker:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 9,
		DefaultMax = 9
	})
	Blocks = AutoClicker:CreateToggle({
		Name = 'Place Blocks',
		Default = true,
		Function = function(callback)
			BlocksCPS.Object.Visible = callback
		end
	})
	BlocksCPS = AutoClicker:CreateTwoSlider({
		Name = 'Block CPS',
		Min = 1,
		Max = 20,
		DefaultMin = 9,
		DefaultMax = 9,
		Darker = true
	})
end)
	
run(function()
	local Sprint
	local old
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				old = skywars.SprintingController.disableSprinting
				skywars.SprintingController.disableSprinting = function(tab, ...)
					local originalCall = old(tab, ...)
					if not tab.canSprint then
						task.spawn(function()
							repeat task.wait(0.1) until tab.canSprint or not Sprint.Enabled
							if Sprint.Enabled then
								skywars.SprintingController:enableSprinting(tab)
							end
						end)
					else
						skywars.SprintingController:enableSprinting(tab)
					end
					return originalCall
				end
				Sprint:Clean(entitylib.Events.LocalAdded:Connect(function()
					skywars.SprintingController:disableSprinting()
				end))
				skywars.SprintingController:disableSprinting()
			else
				skywars.SprintingController.disableSprinting = old
				skywars.SprintingController:disableSprinting()
			end
		end,
		Tooltip = 'Sets your sprinting to true.'
	})
end)
	
run(function()
	local Velocity
	local Horizontal
	local Vertical
	local Chance
	local Targeting
	local connection
	local rand, old = Random.new()
	
	local function velocityFunction(velo, ...)
		if rand:NextNumber(0, 100) > Chance.Value then
			return old(velo, ...)
		end
		local check = (not Targeting.Enabled) or entitylib.EntityPosition({
			Range = 50,
			Part = 'RootPart',
			Players = true
		})
		
		if check then
			local hort, vert = (Horizontal.Value / 100), (Vertical.Value / 100)
			if hort == 0 and vert == 0 then return end
			velo = Vector3.new(velo.X * hort, velo.Y * vert, velo.Z * hort)
		end
	
		return old(velo, ...)
	end
	
	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Function = function(callback)
			if callback then
				connection = getconnections(debug.getupvalue(debug.getupvalue(skywars.Remotes[remotes['PlayerVelocityController:onStart']].connect, 1).fireClient, 1).OnClientEvent)[1]
				if not connection then return end
				old = hookfunction(connection.Function, function(...)
					return velocityFunction(...)
				end)
			else
				if old then 
					hookfunction(connection.Function, old) 
				end
				connection = nil
			end
		end,
		Tooltip = 'Reduces knockback taken'
	})
	Horizontal = Velocity:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%'
	})
	Vertical = Velocity:CreateSlider({
		Name = 'Vertical',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%'
	})
	Chance = Velocity:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	Targeting = Velocity:CreateToggle({Name = 'Only when targeting'})
end)
	
run(function()
	local AntiFall
	local Method
	local Mode
	local Material
	local Color
	local part
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

	local function getRoot()
		local character = entitylib.character
		if entitylib.isAlive and character and character.Character == lplr.Character
			and character.RootPart and character.RootPart.Parent then
			return character.RootPart, character.Humanoid
		end
	end
	
	AntiFall = vape.Categories.Blatant:CreateModule({
		Name = 'AntiFall',
		Function = function(callback)
			if callback then
				if Method.Value == 'Part' then
					local debounce = tick()
					local lastUpdate = 0
					part = Instance.new('Part')
					part.Size = Vector3.new(10000, 1, 10000)
					part.Transparency = 1 - Color.Opacity
					part.Material = Enum.Material[Material.Value]
					part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					part.Position = Vector3.new(0, workspace.FallenPartsDestroyHeight + 10, 0)
					part.CanCollide = Mode.Value == 'Collide'
					part.Anchored = true
					part.CanQuery = false
					part.Parent = workspace
					AntiFall:Clean(part)
					AntiFall:Clean(part.Touched:Connect(function(touchedpart)
						local root = getRoot()
						if root and touchedpart.Parent == lplr.Character and debounce < tick() then
							debounce = tick() + 0.1
							local velocity = root.AssemblyLinearVelocity
							if Mode.Value == 'Velocity' then
								root.AssemblyLinearVelocity = Vector3.new(velocity.X, 100, velocity.Z)
							elseif Mode.Value == 'Impulse' then
								root:ApplyImpulse(Vector3.new(0, 100 - velocity.Y, 0) * root.AssemblyMass)
							end
						end
					end))
					local function updatePart()
						local root = getRoot()
						if not root or not part then return end
						rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character, part}
						rayCheck.CollisionGroup = root.CollisionGroup
						local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
						local height = ray and math.max(ray.Position.Y - 15, workspace.FallenPartsDestroyHeight + 10) or part.Position.Y
						part.Position = Vector3.new(root.Position.X, height, root.Position.Z)
					end
					updatePart()
					AntiFall:Clean(runService.PreSimulation:Connect(function()
						if tick() - lastUpdate >= 0.1 then
							lastUpdate = tick()
							updatePart()
						end
					end))
				else
					local lastpos, lastCharacter
					AntiFall:Clean(runService.PreSimulation:Connect(function(dt)
						local root, humanoid = getRoot()
						if not root or not humanoid then return end
						if lastCharacter ~= lplr.Character then
							lastCharacter = lplr.Character
							lastpos = nil
						end
						local threshold = workspace.FallenPartsDestroyHeight + 10
						if humanoid.FloorMaterial ~= Enum.Material.Air and root.Position.Y > threshold then
							lastpos = root.Position
						end
						local velocity = root.AssemblyLinearVelocity
						if root.Position.Y + math.min(velocity.Y, 0) * math.clamp(dt or 0.016, 0, 0.1) <= threshold then
							local destination = lastpos or Vector3.new(root.Position.X, threshold + 10, root.Position.Z)
							root.CFrame += destination - root.Position
							root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
						end
					end))
				end
			else
				part = nil
			end
		end,
		Tooltip = 'Prevents falling into the void using a safety platform or a last-ground teleport.'
	})
	Method = AntiFall:CreateDropdown({
		Name = 'Method',
		List = {'Part', 'Teleport'},
		Default = 'Part',
		Function = function(val)
			for _, option in {Mode, Material, Color} do
				if option and option.Object then option.Object.Visible = val == 'Part' end
			end
			if AntiFall.Enabled then
				AntiFall:Toggle()
				AntiFall:Toggle()
			end
		end
	})
	Mode = AntiFall:CreateDropdown({
		Name = 'Move Mode',
		List = {'Velocity', 'Impulse', 'Collide'},
		Default = 'Velocity',
		Function = function(val)
			if part then
				part.CanCollide = val == 'Collide'
			end
		end,
		Tooltip = 'Velocity / Impulse - Launch upward on contact\nCollide - Walk on the safety platform'
	})
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = AntiFall:CreateDropdown({
		Name = 'Material',
		List = materials,
		Function = function(val)
			if part then 
				part.Material = Enum.Material[val] 
			end
		end
	})
	Color = AntiFall:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.5,
		Function = function(h, s, v, o)
			if part then
				part.Color = Color3.fromHSV(h, s, v)
				part.Transparency = 1 - o
			end
		end
	})
end)
	
run(function()
	local InvMove
	local restore

	InvMove = vape.Categories.Blatant:CreateModule({
		Name = 'InvMove',
		Function = function(callback)
			if callback then
				if restore then return end
				local controller = skywars.ScreenController
				local original = controller and controller.enableFocus
				if type(original) ~= 'function' then
					notif('InvMove', 'Screen focus controller is unavailable.', 5, 'alert')
					if InvMove.Enabled then InvMove:Toggle() end
					return
				end

				local changed = {}
				local active = true
				local hook
				hook = function(self, screen, ...)
					if active and type(screen) == 'table' then
						local handler = screen.Handler
						local options = type(handler) == 'table' and handler.Options
						if type(options) == 'table' then
							if not changed[options] then
								-- Store a wrapper so an original nil value is preserved too.
								changed[options] = {value = options.focusedAllowMovement}
							end
							options.focusedAllowMovement = true
						end
					end
					return original(self, screen, ...)
				end
				controller.enableFocus = hook
				restore = function()
					if not active then return end
					active = false
					-- Do not overwrite a hook installed by another module after ours.
					if controller.enableFocus == hook then controller.enableFocus = original end
					for options, saved in changed do
						if options.focusedAllowMovement == true then options.focusedAllowMovement = saved.value end
					end
					table.clear(changed)
					restore = nil
				end
				InvMove:Clean(restore)
			elseif restore then
				restore()
			end
		end,
		Tooltip = 'Allows movement in menus opened while enabled. Reopen an already-open menu to apply.'
	})
end)
	
run(function()
	local Killaura
	local Targets
	local AttackRange
	local AngleCheck
	local Max
	local Mouse
	local Limit
	local Swing
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local AnimTween
	local Attacking
	local Particles, Boxes = {}, {}
	local anims, armC0 = vape.Libraries.auraanims
	
	local function getAttackData()
		if Mouse.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			return false
		end
	
		if not entitylib.isAlive or not entitylib.character or not entitylib.character.RootPart
			or not lplr.Character then return nil end
		return (not Limit.Enabled) and store.tools.sword or store.hand
	end
	
	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				if Animation.Enabled then
					task.spawn(function()
						local started = false
						repeat
							if ViewmodelMotor then
								if Attacking then
									if not armC0 then armC0 = ViewmodelMotor.C0 end
									local first = not started
									started = true
	
									if AnimationMode.Value == 'Random' then
										anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
									end
	
									for _, v in anims[AnimationMode.Value] do
										AnimTween = tweenService:Create(ViewmodelMotor, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
											C0 = armC0 * v.CFrame
										})
										AnimTween:Play()
										AnimTween.Completed:Wait()
										first = false
										if (not Killaura.Enabled) or (not Attacking) then break end
									end
								elseif started then
									started = false
									AnimTween = tweenService:Create(ViewmodelMotor, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
										C0 = armC0
									})
									AnimTween:Play()
								end
							end
	
							if not started then
								task.wait(1 / 60)
							end
						until (not Killaura.Enabled) or (not Animation.Enabled)
					end)
				end
	
				repeat
					local attacked = {}
					local tool = getAttackData()
					if tool and tool.Melee and tool.Name then
						local plrs = entitylib.AllPosition({
							Range = AttackRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = math.max(Max.Value, #entitylib.List)
						})
						local switched = false
	
						if #plrs > 0 then
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
							store.noShoot = tick() + 1
	
							for i, v in plrs do
								if #attacked >= Max.Value then break end
								if not v.Player or not v.RootPart or not v.RootPart.Parent or (v.Health or 0) <= 0 then continue end
								local targetPosition = v.RootPart.Position
								if v.Player:GetAttribute('InVoid') or v.Player:GetAttribute('PlayerConnected') == false then continue end
								local delta = (targetPosition - entitylib.character.RootPart.Position)
								if delta.X == 0 and delta.Z == 0 then continue end
								local angle = math.acos(math.clamp(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit), -1, 1))
								if angle > (math.rad(AngleCheck.Value) / 2) then continue end
								table.insert(attacked, v)
								targetinfo.Targets[v] = tick() + 1
	
								if not Swing.Enabled then
									skywars.MeleeController:playAnimation(lplr.Character, tool)
								end
	
								if not switched then
									switched = true
									skywars.Remotes[remotes.updateActiveItem]:fire(tool.Name)
								end
	
								skywars.Remotes[remotes.strikeDesktop]:fire(v.Player)
							end
						end
	
						if switched and store.hand and store.hand.Name and store.hand.Name ~= tool.Name then
							skywars.Remotes[remotes.updateActiveItem]:fire(store.hand.Name)
						end
					end
	
					Attacking = #attacked > 0
					if Attacking and vape.ThreadFix then
						setthreadidentity(8)
					end
	
					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(BoxAttackColor.Hue, BoxAttackColor.Sat, BoxAttackColor.Value)
							v.Transparency = 1 - BoxAttackColor.Opacity
						end
					end
	
					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end
	
					task.wait()
				until not Killaura.Enabled
			else
				for i, v in Boxes do
					v.Adornee = nil
				end
				for i, v in Particles do
					v.Parent = nil
				end
				if armC0 and ViewmodelMotor then
					AnimTween = tweenService:Create(ViewmodelMotor, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					AnimTween:Play()
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({Players = true})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 18,
		Default = 40,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleCheck = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	Max = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 10,
		Default = 10
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for i, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.14,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationTween.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end
	})
	local animnames = {}
	for i in anims do
		table.insert(animnames, i)
	end
	AnimationMode = Killaura:CreateDropdown({
		Name = 'Animation Mode',
		List = animnames,
		Darker = true,
		Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
		Name = 'No Tween',
		Darker = true,
		Visible = false
	})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only attacks when the sword is held'
	})
end)
	
run(function()
	local NoFall
	local rayCheck = RaycastParams.new()
	
	NoFall = vape.Categories.Blatant:CreateModule({
		Name = 'NoFall',
		Function = function(callback)
			if callback then
				repeat
					local waitdelay = 0
					if entitylib.isAlive then
						local hum = entitylib.character.Humanoid
						if (entitylib.character.GroundPosition.Y - entitylib.character.RootPart.Position.Y) > 10 then
							rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
							local ray = workspace:Raycast(entitylib.character.RootPart.Position, Vector3.new(0, -(entitylib.character.HipHeight + 10), 0), rayCheck)
							if not ray then
								hum:ChangeState(Enum.HumanoidStateType.Ragdoll)
								task.wait(0.1)
								hum:ChangeState(Enum.HumanoidStateType.Running)
								waitdelay = 0.05
							end
						end
					end
					task.wait(waitdelay)
				until not NoFall.Enabled
			end
		end,
		Tooltip = 'Prevents taking fall damage.'
	})
end)
	
run(function()
	local old, old2
	
	vape.Categories.Blatant:CreateModule({
		Name = 'NoSlowdown',
		Function = function(callback)
			if callback then
				old = skywars.HumanoidController.addSpeedModifier
				old2 = skywars.SprintingController.setCanSprint
	
				skywars.HumanoidController.addSpeedModifier = function(self, index, speed)
					speed = math.max(speed, 1)
					return old(self, index, speed)
				end
	
				skywars.SprintingController.setCanSprint = function(self, canSprint)
					return old2(self, true)
				end
	
				for i, v in skywars.HumanoidController.speedModifiers do
					if v < 1 then
						skywars.HumanoidController:removeSpeedModifier(i)
					end
				end
				skywars.SprintingController:setCanSprint(true)
				skywars.SprintingController:enableSprinting()
			else
				skywars.HumanoidController.addSpeedModifier = old
				skywars.SprintingController.setCanSprint = old2
				old = nil
				old2 = nil
			end
		end,
		Tooltip = 'Prevents slowing down when using items.'
	})
end)
	
run(function()
	local TargetPart
	local FOV
	local old, oldMobile
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	local function aimFunction(...)
		if store.hand and store.hand.Ranged then
			local plr = entitylib.EntityMouse({
				Range = FOV.Value,
				Part = 'RootPart',
				Players = true
			})
		
			if plr then
				rayCheck.FilterDescendantsInstances = {plr.Character, gameCamera}
				rayCheck.CollisionGroup = plr[TargetPart.Value].CollisionGroup
				local offsetpos = entitylib.character.RootPart.CFrame * skywars.FireOrigin
				local calc = prediction.SolveTrajectory(offsetpos.Position, 200, math.abs(skywars.Gravity), plr[TargetPart.Value].Position, plr[TargetPart.Value].Velocity, workspace.Gravity, plr.HipHeight, nil, rayCheck)
				
				if calc then
					targetinfo.Targets[plr] = tick() + 1
					return CFrame.new(offsetpos.Position, calc).LookVector
				end
			end
		end
	
		return old(...)
	end
	
	local ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		Function = function(callback)
			if callback then 
				old = hookfunction(skywars.CameraUtil.getCursorDirection, function(...)
					return aimFunction(...)
				end)
				oldMobile = hookfunction(skywars.CameraUtil.getDirection, function(...)
					return aimFunction(...)
				end)
			else
				hookfunction(skywars.CameraUtil.getCursorDirection, old)
				hookfunction(skywars.CameraUtil.getDirection, oldMobile)
				old = nil
				oldMobile = nil
			end
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = ProjectileAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000
	})
end)
	
run(function()
	local ProjectileAura
	local Targets
	local Range
	local List
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	local FireDelays = {}
	
	local function getProjectiles()
		local items = {}
		for slot, item in store.inventory do
			item = skywars.ItemMeta[item.Type]
			if item.Ranged and table.find(List.ListEnabled, item.Ranged.ProjectileType) and getItem(item.Ranged.ProjectileType) then
				table.insert(items, item)
			end
		end
		return items
	end
	
	ProjectileAura = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAura',
		Function = function(callback)
			if callback then
				repeat
					local ent = entitylib.EntityPosition({
						Part = 'RootPart',
						Range = Range.Value,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled
					})
	
					if ent then
						local offsetpos = entitylib.character.RootPart.CFrame * skywars.FireOrigin
						for _, item in getProjectiles() do
							if (FireDelays[item] or 0) < tick() then
								rayCheck.FilterDescendantsInstances = {ent.Character, gameCamera}
								rayCheck.CollisionGroup = ent.RootPart.CollisionGroup
								local calc = prediction.SolveTrajectory(offsetpos.Position, 200, math.abs(skywars.Gravity), ent.RootPart.Position, ent.RootPart.Velocity, workspace.Gravity, ent.HipHeight, nil, rayCheck)
								
								if calc then
									targetinfo.Targets[ent] = tick() + 1
									FireDelays[item] = tick() + 0.5
									skywars.Remotes[remotes.updateActiveItem]:fire(item.Name)
									skywars.Remotes[remotes.chargeBow]:fire(CFrame.new(offsetpos.Position, calc).LookVector, 1)
									if store.hand.Name then
										skywars.Remotes[remotes.updateActiveItem](store.hand.Name)
									end
									break
								end
							end
						end
					end
					task.wait(0.1)
				until not ProjectileAura.Enabled
			end
		end,
		Tooltip = 'Shoots people around you'
	})
	Targets = ProjectileAura:CreateTargets({
		Players = true, 
		Walls = true
	})
	List = ProjectileAura:CreateTextList({
		Name = 'Projectiles',
		Default = {'Arrow', 'Snowball', 'Capybara'}
	})
	Range = ProjectileAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 50,
		Default = 50,
		Suffix = function(val) 
			return val == 1 and 'stud' or 'studs' 
		end
	})
end)
	
run(function()
	local Scaffold
	local Expand
	local Tower
	local Downwards
	local Diagonal
	local LimitItem
	local adjacent, lastpos = {}, Vector3.zero
	
	for x = -3, 3, 3 do
		for y = -3, 3, 3 do
			for z = -3, 3, 3 do
				local vec = Vector3.new(x, y, z)
				if vec.Y ~= 0 and (vec.X ~= 0 or vec.Z ~= 0) then
					continue
				end
	
				if vec ~= Vector3.zero then 
					table.insert(adjacent, vec)
				end
			end
		end
	end
	
	local function getBlocksInPoints(s, e)
		local list = {}
		for x = s.X, e.X, 3 do
			for y = s.Y, e.Y, 3 do
				for z = s.Z, e.Z, 3 do
					local vec = Vector3.new(x, y, z)
					if store.blocks[vec] then
						table.insert(list, vec)
					end
				end
			end
		end
		return list
	end
	
	local function roundPos(vec)
		return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
	end
	
	local function nearCorner(poscheck, pos)
		local startpos = poscheck - Vector3.new(3, 3, 3)
		local endpos = poscheck + Vector3.new(3, 3, 3)
		local check = poscheck + (pos - poscheck).Unit * 100
		if math.abs(check.Y - startpos.Y) > 3 then
			return Vector3.new(poscheck.X, math.clamp(check.Y, startpos.Y, endpos.Y), poscheck.Z)
		end
		return Vector3.new(math.clamp(check.X, startpos.X, endpos.X), math.clamp(check.Y, startpos.Y, endpos.Y), math.clamp(check.Z, startpos.Z, endpos.Z))
	end
	
	local function blockProximity(pos)
		local mag, returned = 60
		local tab = getBlocksInPoints(pos - Vector3.new(21, 21, 21), pos + Vector3.new(21, 21, 21))
		for _, v in tab do
			local blockpos = nearCorner(v, pos)
			local newmag = (pos - blockpos).Magnitude
			if newmag < mag then
				mag, returned = newmag, blockpos
			end
		end
		table.clear(tab)
		return returned
	end
	
	local function checkAdjacent(pos)
		for _, v in adjacent do
			if store.blocks[pos + v] then return true end
		end
		return false
	end
	
	local function getBlock()
		for slot, item in store.inventory do
			item = skywars.ItemMeta[item.Type]
			if item.Rewrite then return item, slot end
		end
	end
	
	Scaffold = vape.Categories.Utility:CreateModule({
		Name = 'Scaffold',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive then
						local wool = (not LimitItem.Enabled) and getBlock() or store.hand.Rewrite and store.hand
						if wool then
							local root = entitylib.character.RootPart
							if Tower.Enabled and inputService:IsKeyDown(Enum.KeyCode.Space) and (not inputService:GetFocusedTextBox()) then
								root.Velocity = Vector3.new(root.Velocity.X, 38, root.Velocity.Z)
							end
	
							for i = Expand.Value, 1, -1 do
								local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + (Downwards.Enabled and inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4.5 or 1.5), 0) + entitylib.character.Humanoid.MoveDirection * (i * 3))
								if Diagonal.Enabled then
									if math.abs(math.round(math.deg(math.atan2(-entitylib.character.Humanoid.MoveDirection.X, -entitylib.character.Humanoid.MoveDirection.Z)) / 45) * 45) % 90 == 45 then
										local dt = (lastpos - currentpos)
										if ((dt.X == 0 and dt.Z ~= 0) or (dt.X ~= 0 and dt.Z == 0)) and ((lastpos - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 then
											currentpos = lastpos
										end
									end
								end
	
								local block = store.blocks[currentpos]
								if not block then
									local blockpos = checkAdjacent(currentpos) and currentpos or blockProximity(currentpos)
									if blockpos then
										local block = skywars.ItemMeta[wool.Rewrite.Type:gsub('{TeamId}', skywars.TeamController:getPlayerTeamId(lplr) or 'White')]
										skywars.BlockController:placeBlock(blockpos, wool.Name, block, Vector3.zero)
									end
								end
								lastpos = currentpos
							end
						end
					end
					task.wait(0.03)
				until not Scaffold.Enabled
			end
		end,
		Tooltip = 'Helps you make bridges/scaffold walk.'
	})
	Expand = Scaffold:CreateSlider({
		Name = 'Expand',
		Min = 1,
		Max = 6
	})
	Tower = Scaffold:CreateToggle({
		Name = 'Tower',
		Default = true
	})
	Downwards = Scaffold:CreateToggle({
		Name = 'Downwards',
		Default = true
	})
	Diagonal = Scaffold:CreateToggle({
		Name = 'Diagonal',
		Default = true
	})
	LimitItem = Scaffold:CreateToggle({Name = 'Limit to items'})
end)
	
run(function()
	local ChestSteal
	local Range
	local Open
	local Delay = {}
	
	ChestSteal = vape.Categories.World:CreateModule({
		Name = 'ChestSteal',
		Function = function(callback)
			if callback then
				local chests = collection('block:chest', ChestSteal)
				ChestSteal:Clean(skywars.Remotes[remotes['ChestController:onStart']]:connect(function(self, items)
					if Delay[self] then return end
	
					for _, item in items do
						skywars.Remotes[remotes.updateChest]:fire(self, item.Type, -item.Quantity)
					end
					skywars.Remotes[remotes.closeChest]:fire(self)
					Delay[self] = true
				end))
	
				repeat
					if entitylib.isAlive and not Open.Enabled then
									local localPosition = entitylib.character.RootPart.Position
						for i, v in chests do
							if v.PrimaryPart and (localPosition - v.PrimaryPart.Position).Magnitude <= Range.Value and not Delay[v] then
								skywars.Remotes[remotes.openChest]:fire(v)
							end
						end
					end
					task.wait(0.1)
				until not ChestSteal.Enabled
			end
		end,
		Tooltip = 'Grabs items from near chests.'
	})
	Range = ChestSteal:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 10,
		Default = 10,
		Suffix = function(val) 
			return val == 1 and 'stud' or 'studs' 
		end
	})
	Open = ChestSteal:CreateToggle({Name = 'GUI Check'})
end)
	
run(function()
	local AutoBuy
	local Sword
	local Armor
	local Pickaxe
	local Upgrades
	local UpgradeObjects = {}
	local Functions = {}
	
	local function buyCheck(currencytable)
		for i, v in Functions do 
			v(currencytable) 
		end
	end
	
	local function buyUpgrade(name, upgrade, currencytable)
		local currentitem
		for shopIndex, shopItem in upgrade.Items do
			if shopItem.ItemType == name then 
				currentitem = shopIndex 
			end
		end
		if not currentitem then return end
	
		for i = currentitem + 1, #upgrade.Items do
			local nextitem = upgrade.Items[i]
			if nextitem and currencytable[nextitem.CurrencyType] >= nextitem.Price then
				skywars.Remotes[remotes.purchaseItemUpgrade]:fire('Blacksmith', upgrade.ItemIndex)
				currencytable[nextitem.CurrencyType] -= nextitem.Price
			end
		end
	end
	
	local function buyTeamUpgrade(upgrade, currencytable)
		local currentitem = skywars.Store:getState().TeamUpgrades[upgrade.Name] or 0
		for i = currentitem + 1, #upgrade.Tiers do
			local nextitem = upgrade.Tiers[i]
			if nextitem and currencytable[nextitem.CurrencyType] >= nextitem.Price then
				skywars.Remotes[remotes.purchaseTeamUpgrade]:fire('Merchant', upgrade.ItemIndex)
				currencytable[nextitem.CurrencyType] -= nextitem.Price
			end
		end
	end
	
	AutoBuy = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBuy',
		Function = function(callback)
			if callback then
				AutoBuy:Clean(vapeEvents.CurrencyChange.Event:Connect(buyCheck))
				buyCheck(table.clone(skywars.Store:getState().GameCurrency.Quantities))
			end
		end,
		Tooltip = 'Automatically buys items when you go near the shop'
	})
	Sword = AutoBuy:CreateToggle({
		Name = 'Buy Sword',
		Function = function(callback)
			Functions[2] = callback and function(currencytable, shop, upgrades)
				buyUpgrade(store.tools.sword and store.tools.sword.Name, skywars.Shop.Blacksmith.ItemUpgrades[2], currencytable)
			end or nil
		end,
		Default = true
	})
	Armor = AutoBuy:CreateToggle({
		Name = 'Buy Armor',
		Function = function(callback)
			Functions[1] = callback and function(currencytable, shop, upgrades)
				if lplr.Character then
					for _, v in lplr.Character:GetChildren() do
						if v:GetAttribute('Armour') and v.Name:find('Chestplate') then
							buyUpgrade(v.Name, skywars.Shop.Blacksmith.ItemUpgrades[1], currencytable)
							break
						end
					end
				end
			end or nil
		end,
		Default = true
	})
	Pickaxe = AutoBuy:CreateToggle({
		Name = 'Buy Pickaxe',
		Function = function(callback)
			Functions[3] = callback and function(currencytable, shop, upgrades)
				buyUpgrade(store.tools.pickaxe and store.tools.pickaxe.Name, skywars.Shop.Blacksmith.ItemUpgrades[3], currencytable)
			end or nil
		end,
		Default = true
	})
	Upgrades = AutoBuy:CreateToggle({
		Name = 'Buy Upgrades',
		Function = function(callback)
			for i, v in UpgradeObjects do
				v.Object.Visible = callback
			end
		end,
		Default = true
	})
	for i, v in skywars.Shop.Merchant.TeamUpgrades do
		table.insert(UpgradeObjects, AutoBuy:CreateToggle({
			Name = 'Buy '..v.Name,
			Function = function(callback)
				Functions[4 + i] = callback and function(currencytable, shop, upgrades)
					buyTeamUpgrade(v, currencytable)
				end or nil
			end,
			Darker = true,
			Default = (v.Name == 'Generator' or v.Name == 'Vampyrism')
		}))
	end
end)
	
run(function()
	local AutoConsume
	
	local function consumeCheck()
		if (lplr:GetAttribute('Shield') or 0) <= 0 and getItem('Shield') then
			skywars.Remotes[remotes.updateActiveItem]:fire('Shield')
			skywars.Remotes[remotes.usePowerUp]:fire()
			if store.hand.Name then
				skywars.Remotes[remotes.updateActiveItem]:fire(store.hand.Name)
			end
		end
	end
	
	AutoConsume = vape.Categories.Inventory:CreateModule({
		Name = 'AutoConsume',
		Function = function(callback)
			if callback then
				AutoConsume:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(consumeCheck))
				AutoConsume:Clean(lplr:GetAttributeChangedSignal('Shield'):Connect(consumeCheck))
				consumeCheck()
			end
		end,
		Tooltip = 'Automatically uses shield potions.'
	})
end)
	
run(function()
	local Breaker
	local Range
	local BreakerPart
	local BreakerUI
	local BreakerRef = skywars.Roact.createRef()
	
	local function clean()
		if not BreakerUI then return end
		if BreakerPart then 
			BreakerPart:Destroy() 
		end
		skywars.Roact.unmount(BreakerUI)
		BreakerUI = nil
		BreakerPart = nil
	end
	
	local function customHealthbar(block, health, maxHealth, changeHealth)
		if not BreakerPart then
			local create = skywars.Roact.createElement
			local percent = math.clamp(health / maxHealth, 0, 1)
			local cleanCheck = true
			local part = Instance.new('Part')
			part.Size = Vector3.one
			part.CFrame = block.PrimaryPart.CFrame
			part.Transparency = 1
			part.Anchored = true
			part.CanCollide = false
			part.Parent = workspace
			BreakerPart = part
	
			BreakerUI = skywars.Roact.mount(create('BillboardGui', {
				Size = UDim2.fromOffset(249, 102),
				StudsOffset = Vector3.new(0, 2.5, 0),
				Adornee = part,
				MaxDistance = 40,
				AlwaysOnTop = true
			}, {
				create('Frame', {
					Size = UDim2.fromOffset(160, 50),
					Position = UDim2.fromOffset(44, 32),
					BackgroundColor3 = Color3.new(),
					BackgroundTransparency = 0.5
				}, {
					create('UICorner', {CornerRadius = UDim.new(0, 5)}),
					create('ImageLabel', {
						Size = UDim2.new(1, 89, 1, 52),
						Position = UDim2.fromOffset(-48, -31),
						BackgroundTransparency = 1,
						Image = getcustomasset('aerov4/assets/new/blur.png'),
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(52, 31, 261, 502)
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(13, 12),
						BackgroundTransparency = 1,
						Text = block.Name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = Color3.new(),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(12, 11),
						BackgroundTransparency = 1,
						Text = block.Name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = color.Dark(uipallet.Text, 0.16),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('Frame', {
						Size = UDim2.fromOffset(138, 4),
						Position = UDim2.fromOffset(12, 32),
						BackgroundColor3 = uipallet.Main
					}, {
						create('UICorner', {CornerRadius = UDim.new(1, 0)}),
						create('Frame', {
							[skywars.Roact.Ref] = BreakerRef,
							Size = UDim2.fromScale(percent, 1),
							BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
						}, {create('UICorner', {CornerRadius = UDim.new(1, 0)})})
					})
				})
			}), part)
	
			task.delay(5, clean)
		end
	
		local newpercent = math.clamp((health - changeHealth) / maxHealth, 0, 1)
		if newpercent == 0 then 
			clean() 
			return 
		end
		
		task.delay(0, function()
			local val = BreakerRef:getValue()
			if val then
				tweenService:Create(val, TweenInfo.new(0.3), {
					Size = UDim2.fromScale(newpercent, 1), 
					BackgroundColor3 = Color3.fromHSV(math.clamp(newpercent / 2.5, 0, 1), 0.89, 0.75)
				}):Play()
			end
		end)
	end
	
	Breaker = vape.Categories.Minigames:CreateModule({
		Name = 'Breaker',
		Function = function(callback)
			if callback then
				local eggs = collection('egg', Breaker)
				local currentblock
				local oldblockhealth = 0
				
				repeat
					if entitylib.isAlive and store.hand then
						local localPosition = entitylib.character.RootPart.Position
						for i, v in eggs do
							if v.PrimaryPart and (localPosition - v.PrimaryPart.Position).Magnitude < Range.Value then
								local hp = v:GetAttribute('Health') or 0
								if v:GetAttribute('TeamId') == lplr:GetAttribute('TeamId') then continue end
								if currentblock ~= v then
									oldblockhealth = hp
									currentblock = v
								end
	
								if hp ~= oldblockhealth then
									customHealthbar(v, oldblockhealth, 100, oldblockhealth - hp)
									oldblockhealth = hp
								end
	
								store.noShoot = tick() + 1
								if hp <= 0 then continue end
								if store.hand.Melee then 
									skywars.Remotes[remotes['MeleeController:attemptStrikeDesktop']]:fire(v)
								elseif store.hand.Pickaxe then 
									skywars.Remotes[remotes.hitBlock]:fire((v.PrimaryPart.Position + Vector3.new(0, 1.5, 0)) // 1)
								end
							end
						end
					end
					
					task.wait(0.016)
				until not Breaker.Enabled
			end
		end,
		Tooltip = 'Automatically destroys eggs around you'
	})
	Range = Breaker:CreateSlider({
		Name = 'Break range',
		Min = 1,
		Max = 40,
		Default = 100,
		Suffix = function(val) 
			return val == 1 and 'stud' or 'studs' 
		end
	})
end)
	
run(function()
	local Viewmodel
	local oldtool
	
	local function newCharacter(char)
		Viewmodel:Clean(char.Character.ChildAdded:Connect(function(obj)
			if obj:IsA('Tool') then 
				oldtool = obj
				ViewmodelTool = oldtool.Handle:Clone()
				ViewmodelTool.CanCollide = false
				ViewmodelTool.Massless = true
				ViewmodelTool.Anchored = true
				ViewmodelTool:ClearAllChildren()
				ViewmodelTool.Parent = gameCamera
				ViewmodelTool.LocalTransparencyModifier = 0
				oldtool.Handle.LocalTransparencyModifier = 1
			end
		end))
		
		Viewmodel:Clean(char.Character.ChildRemoved:Connect(function(obj)
			if obj == oldtool then 
				ViewmodelTool:Destroy()
				ViewmodelTool = nil
				oldtool = nil
			end
		end))
	end
	
	Viewmodel = vape.Categories.Legit:CreateModule({
		Name = 'Viewmodel',
		Function = function(callback)
			if callback then 
				ViewmodelMotor = Instance.new('Motor6D')
				vape:Clean(ViewmodelMotor)
				vape:Clean(runService.RenderStepped:Connect(function()
					if ViewmodelTool then 
						local dcf = ((CFrame.new(2.06, -2.44, -2.24) * CFrame.new(0.6, -0.2, -0.6)) * CFrame.Angles(math.rad(99), math.rad(2), math.rad(-4))) * ViewmodelMotor.C0
						local offsetcf = (CFrame.new(0, -0.15, -1.56) * CFrame.Angles(math.rad(-90), math.rad(-90), 0))
						ViewmodelTool.CFrame = ((gameCamera.CFrame * dcf) * offsetcf)
					end
				end))
				vape:Clean(entitylib.Events.LocalAdded:Connect(newCharacter))
				if entitylib.isAlive then 
					newCharacter(entitylib.character) 
				end
			else
				if ViewmodelTool then
					ViewmodelTool:Destroy()
					ViewmodelTool = nil
				end
				if oldtool and oldtool:FindFirstChild('Handle') then
					oldtool.Handle.LocalTransparencyModifier = 0
				end
				oldtool = nil
			end
		end,
		Tooltip = 'Replaces the default viewmodel'
	})
end)

run(function()
	local AutoWin
	local previousStates
	local worker
	local status = 'Idle'

	local Minigames = vape.Categories and vape.Categories.Minigames
	if not Minigames or not Minigames.CreateModule then
		return
	end

	AutoWin = Minigames:CreateModule({
		Name = 'AutoWin',
		Function = function(callback)
			if callback then
				local Breaker = vape.Modules.Breaker
				local Killaura = vape.Modules.Killaura
				if not (Breaker and Killaura) then
					AutoWin:Toggle()
					notif('AutoWin', 'Breaker or Killaura is unavailable.', 5, 'alert')
					return
				end

				previousStates = {
					Breaker = Breaker.Enabled,
					Killaura = Killaura.Enabled
				}
				if not previousStates.Breaker then
					Breaker:Toggle()
				end
				if not previousStates.Killaura then
					Killaura:Toggle()
				end

				local eggs = collection('egg', AutoWin)
				local warnedNoTargets = false
				worker = task.spawn(function()
					while AutoWin.Enabled do
						if not entitylib.isAlive then
							status = 'Waiting for respawn'
							task.wait()
							continue
						end

						local root = entitylib.character and entitylib.character.RootPart
						if not root or not root.Parent then
							status = 'Waiting for character'
							task.wait()
							continue
						end
						local localTeamId = lplr:GetAttribute('TeamId')
						if localTeamId == nil then
							status = 'Waiting for team'
							task.wait()
							continue
						end
						local foundTarget = false
						local targetEgg
						local lowestHealth = math.huge
						for _, egg in eggs do
							if not egg.Parent or egg:GetAttribute('TeamId') == nil or egg:GetAttribute('TeamId') == localTeamId then
								continue
							end
							local health = egg:GetAttribute('Health')
							local eggRoot = egg:IsA('Model') and (egg.PrimaryPart or egg:FindFirstChildWhichIsA('BasePart')) or egg
							if eggRoot and eggRoot.Parent and typeof(health) == 'number' and health > 0 and health < lowestHealth then
								lowestHealth = health
								targetEgg = eggRoot
							end
						end

						if targetEgg then
							foundTarget = true
							status = 'Targeting egg'
							local targetPosition = targetEgg.Position
							if (root.Position - targetPosition).Magnitude > 6 then
								local destination = targetPosition - Vector3.new(0, 8, 0) -- under them
								root.CFrame = CFrame.lookAt(destination, targetPosition)
							end
						else
							local target
							local nearestDistance = math.huge
							for _, entity in entitylib.List do
								if entity.Player and entity.Targetable and (entity.Health or 0) > 0 and entity.RootPart and entity.RootPart.Parent then
									local targetPosition = entity.RootPart.Position
									if entity.Player:GetAttribute('InVoid') or entity.Player:GetAttribute('PlayerConnected') == false then continue end
									local distance = (root.Position - targetPosition).Magnitude
									if distance < nearestDistance then
										nearestDistance = distance
										target = entity.RootPart
									end
								end
							end
							if target then
								foundTarget = true
								status = 'Targeting player'
							end
							if target and nearestDistance > 6 then
								local targetPosition = target.Position
								local destination = targetPosition + Vector3.new(0, 10, 0) -- above them
								root.CFrame = CFrame.lookAt(destination, targetPosition)
							end
						end

						if foundTarget then
							warnedNoTargets = false
						else
							status = 'No eligible targets'
							if not warnedNoTargets then
								warnedNoTargets = true
								notif('AutoWin', 'No eligible targets. Waiting for enemy players or eggs to spawn.', 5, 'alert')
							end
						end
						task.wait(.00001) -- faster TP
					end
				end)
				local activeWorker = worker
				AutoWin:Clean(function()
					if coroutine.status(activeWorker) ~= 'dead' then task.cancel(activeWorker) end
				end)
			else
				if worker and coroutine.status(worker) ~= 'dead' then task.cancel(worker) end
				worker = nil
				status = 'Idle'
				if previousStates then
					local Breaker = vape.Modules.Breaker
					local Killaura = vape.Modules.Killaura
					if Breaker and not previousStates.Breaker and Breaker.Enabled then
						Breaker:Toggle()
					end
					if Killaura and not previousStates.Killaura and Killaura.Enabled then
						Killaura:Toggle()
					end
					previousStates = nil
				end
			end
		end,
		ExtraText = function() return status end,
		Tooltip = 'Automatically wins for you'
	})
end)

run(function()
	local GodMode
	local Range
	local Safe
	local Dodge
	local idleSince = 0
	local dodgeUntil = 0

	local function threats(origin)
		local list = {}
		for _, ent in entitylib.List do
			if ent.Targetable and ent.RootPart and ent.RootPart.Parent and ent.Health > 0 and not fallen(ent) then
				local distance = (ent.RootPart.Position - origin).Magnitude
				if distance <= Range.Value then
					table.insert(list, {Entity = ent, Distance = distance})
				end
			end
		end
		table.sort(list, function(a, b)
			return a.Distance < b.Distance
		end)
		return list
	end

	-- over the closest enemy, raised until nobody is nearer than the safe distance
	local function safeSpot(list)
		local goal = attachPosition(list[1].Entity, Safe.Value)
		for _ = 1, 4 do
			local lift = 0
			for _, threat in list do
				local position = threat.Entity.RootPart.Position
				local delta = goal - position
				if delta.Magnitude < Safe.Value - 0.25 then
					local flat = Vector3.new(delta.X, 0, delta.Z).Magnitude
					local need = math.sqrt(math.max(Safe.Value ^ 2 - flat ^ 2, 0))
					lift = math.max(lift, position.Y + need - goal.Y)
				end
			end
			if lift <= 0 then break end
			goal += Vector3.new(0, lift, 0)
		end
		return goal
	end

	local function release()
		if store.godMode then
			store.attached = nil
		end
		store.godMode = nil
		mergeRoot('GodMode')
	end

	-- lifts the root out of the way of a shot that would pass close to it
	local function projectile(shooter, kind, origin, direction, speed)
		if not (Dodge.Enabled and entitylib.isAlive) then return end
		if not (typeof(shooter) == 'Instance' and shooter:IsA('Player') and shooter ~= lplr) then return end
		if not (type(kind) == 'string' and typeof(origin) == 'Vector3' and typeof(direction) == 'Vector3' and type(speed) == 'number') then return end
		if shooter:GetAttribute('TeamId') ~= nil and shooter:GetAttribute('TeamId') == lplr:GetAttribute('TeamId') then return end
		local meta = skywars.ItemMeta[kind]
		local acceleration = meta and meta.Projectile and meta.Projectile.Acceleration or Vector3.new(0, skywars.Gravity, 0)
		local velocity = direction.Unit * speed
		local mine = realRoot().Position
		for step = 1, 50 do
			local t = step * 0.05
			if (origin + velocity * t + acceleration * (t * t / 2) - mine).Magnitude < 10 then
				dodgeUntil = math.max(dodgeUntil, tick() + t + 0.5)
				return
			end
		end
	end

	GodMode = vape.Categories.Blatant:CreateModule({
		Name = 'GodMode',
		Function = function(callback)
			if callback then
				for _, id in (remotes.projectileEvents or {}) do
					local event = skywars.Remotes[id]
					if event then
						GodMode:Clean(event:connect(projectile))
					end
				end
				GodMode:Clean(runService.Heartbeat:Connect(function()
					if not entitylib.isAlive or outranked('godMode') then
						release()
						return
					end
					local body = bodyRoot().Position
					local list = threats(body)
					local dodging = dodgeUntil > tick()
					if #list == 0 and not dodging then
						if store.godMode then
							store.attached = nil
						end
						store.godMode = nil
						if tick() - idleSince > 1 then
							mergeRoot('GodMode')
						end
						return
					end

					if not splitRoot('GodMode') then return end
					store.godMode = true
					store.attached = list[1] and list[1].Entity or nil
					idleSince = tick()
					local goal = #list > 0 and safeSpot(list) or body
					if dodging then
						goal += Vector3.new(0, 40, 0)
					end
					sendRoot(goal)
				end))
			else
				release()
			end
		end,
		Tooltip = 'Keeps the hitbox the server uses out of every enemy\'s reach while they are close.\nYour character and camera stay where you put them, only on your screen.'
	})
	Range = GodMode:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 60,
		Default = 22,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How close an enemy has to come before your hitbox leaves the ground'
	})
	Safe = GodMode:CreateSlider({
		Name = 'Distance',
		Min = 14,
		Max = 25,
		Default = 15,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far your hitbox stays from every enemy. They reach 13.5 studs, your own hits land from up to 17.'
	})
	Dodge = GodMode:CreateToggle({
		Name = 'Dodge projectiles',
		Default = true,
		Tooltip = 'Lifts your hitbox another 40 studs when a shot is heading for it'
	})
end)


run(function()
	local PlayerAttach
	local Targets
	local Range
	local Height
	local lastGround
	local attached = false
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	local blockCheck = RaycastParams.new()
	blockCheck.FilterType = Enum.RaycastFilterType.Include

	local function onBlock(position, distance)
		local container = workspace:FindFirstChild('BlockContainer')
		if not container then return nil end
		blockCheck.FilterDescendantsInstances = {container}
		return workspace:Raycast(position, Vector3.new(0, -distance, 0), blockCheck)
	end

	-- puts you back on something solid once there is nobody to stick to
	local function release()
		if not attached then return end
		attached = false
		store.playerAttach = nil
		store.attached = nil
		if not entitylib.isAlive or store.split or outranked('playerAttach') then return end
		local hit = onBlock(realRoot().Position, 80)
		local position = hit and hit.Position + Vector3.new(0, entitylib.character.HipHeight + 0.2, 0) or lastGround
		if position then
			sendRoot(position)
		end
	end

	PlayerAttach = vape.Categories.Blatant:CreateModule({
		Name = 'PlayerAttach',
		Tooltip = 'Attaches you to the nearest target',
		Function = function(call)
			if call then
				PlayerAttach:Clean(entitylib.Events.LocalRemoved:Connect(function()
					attached = false
					store.playerAttach = nil
					lastGround = nil
				end))
				local plr, nextScan = nil, 0
				local function sortHealth(a, b)
					return a.Entity.Health < b.Entity.Health
				end
				repeat
					if entitylib.isAlive and not outranked('playerAttach') then
						local root = bodyRoot()
						if not attached and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and onBlock(root.Position, entitylib.character.HipHeight + 3) then
							lastGround = root.Position
						end
						if tick() >= nextScan then
							nextScan = tick() + 0.1
							plr = entitylib.AllPosition({
								Range = attached and Range.Value + Height.Value or Range.Value,
								Wallcheck = Targets.Walls.Enabled or nil,
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								Priority = Targets.Priority and Targets.Priority.Value,
								NPCs = Targets.NPCs.Enabled,
								Limit = 1,
								Sort = sortHealth
							})[1]
						end
						if plr and plr.RootPart and plr.RootPart.Parent and isnetworkowner(realRoot()) then
							attached = true
							store.playerAttach = true
							store.attached = plr
							if Height.Value > 0 then
								sendRoot(attachPosition(plr, Height.Value))
							else
								rayCheck.FilterDescendantsInstances = {plr.RootPart.Parent, lplr.Character}
								sendRoot(attachPosition(plr, 0) + (not workspace:Raycast(plr.RootPart.Position, plr.RootPart.CFrame.LookVector, rayCheck) and (plr.RootPart.CFrame.LookVector * 1.4) or Vector3.zero))
							end
						else
							release()
						end
					else
						plr = nil
						if attached then
							store.attached = nil
						end
						attached = false
						store.playerAttach = nil
					end
					task.wait()
				until not PlayerAttach.Enabled
			else
				release()
			end
		end
	})

	Targets = PlayerAttach:CreateTargets({
		Players = true,
		NPCs = true
	})

	Range = PlayerAttach:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 100,
		Default = 23,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	Height = PlayerAttach:CreateSlider({
		Name = 'Height',
		Min = 0,
		Max = 17,
		Default = 0,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far above the target you stay. Their hits stop reaching at 14, yours land from up to 17.'
	})
end)


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


run(function()
	local ShopClicker
	local HoldDelay
	local CPS
	local guiService = cloneref(game:GetService('GuiService'))
	local holding = false
	local clickThread
	local catalog

	-- every blacksmith item by the name its card carries, with the call that buys it
	local function items()
		if catalog then return catalog end
		local shop = skywars.Shop and skywars.Shop.Blacksmith
		if type(shop) ~= 'table' then return {} end
		catalog = {}
		for _, upgrade in shop.ItemUpgrades or {} do
			for _, item in upgrade.Items or {} do
				if item.ItemType then
					catalog[item.ItemType] = {Remote = 'purchaseItemUpgrade', Index = upgrade.ItemIndex, Item = item}
				end
			end
		end
		for _, item in shop.Items or {} do
			if item.ItemType then
				catalog[item.ItemType] = {Remote = 'purchaseItem', Index = item.ItemIndex, Item = item}
			end
		end
		return catalog
	end

	local function getHoveredItem()
		local list = items()
		local mouse = inputService:GetMouseLocation() - guiService:GetGuiInset()
		for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y) do
			local obj = v
			while obj and obj ~= lplr.PlayerGui do
				-- the card is the one frame that holds both the picture and the buy button
				if list[obj.Name] and obj:FindFirstChild('ButtonClipping', true) then
					return obj.Name
				end
				obj = obj.Parent
			end
		end
		return nil
	end

	local function purchase(name)
		local entry = items()[name]
		if not (entry and entry.Index) then return end
		local currency = skywars.Store:getState().GameCurrency
		local have = currency and currency.Quantities and currency.Quantities[entry.Item.CurrencyType] or 0
		if entry.Item.Price and have < entry.Item.Price then return end
		fireRemote(entry.Remote, 'Blacksmith', entry.Index)
	end

	local function startClicking(name)
		if clickThread then
			task.cancel(clickThread)
		end
		clickThread = task.spawn(function()
			repeat
				-- the card is only under the cursor while the shop is open
				if getHoveredItem() == name then
					purchase(name)
				end
				task.wait(1 / CPS.Value)
			until not holding
			clickThread = nil
		end)
	end

	ShopClicker = vape.Categories.Utility:CreateModule({
		Name = 'ShopClicker',
		Function = function(callback)
			if callback then
				ShopClicker:Clean(inputService.InputBegan:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
					local name = getHoveredItem()
					if not name then return end

					holding = true
					task.delay(HoldDelay.Value, function()
						if holding and getHoveredItem() == name then
							startClicking(name)
						end
					end)
				end))

				ShopClicker:Clean(inputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						holding = false
					end
				end))
			else
				holding = false
				if clickThread then
					task.cancel(clickThread)
					clickThread = nil
				end
			end
		end,
		Tooltip = 'Hold on a blacksmith item to rapidly buy or upgrade it'
	})
	HoldDelay = ShopClicker:CreateSlider({
		Name = 'Hold Delay',
		Min = 0,
		Max = 1,
		Default = 0.15,
		Decimal = 20,
		Suffix = 'seconds'
	})
	CPS = ShopClicker:CreateSlider({
		Name = 'CPS',
		Min = 1,
		Max = 20,
		Default = 20,
		Darker = true
	})
end)


run(function()
	local GameStaller
	local Height
	local Hidden
	local Notify
	local home
	local announced = false

	local function stop()
		local position = home
		home = nil
		store.staller = nil
		if store.split then
			mergeRoot('GameStaller')
		elseif position and entitylib.isAlive then
			sendRoot(position)
		end
	end

	GameStaller = vape.Categories.Utility:CreateModule({
		Name = 'GameStaller',
		Function = function(callback)
			if callback then
				GameStaller:Clean(entitylib.Events.LocalRemoved:Connect(function()
					home = nil
					store.staller = nil
				end))
				GameStaller:Clean(runService.Heartbeat:Connect(function()
					if not entitylib.isAlive or skywars.Store:getState().GameState ~= 'InGame' then
						if home then
							stop()
						end
						announced = false
						return
					end
					if not home then
						home = bodyRoot().Position
					end
					if Hidden.Enabled then
						splitRoot('GameStaller')
					elseif store.split then
						mergeRoot('GameStaller')
					end
					store.staller = true
					sendRoot(Vector3.new(home.X, home.Y + Height.Value, home.Z))
					if Notify.Enabled and not announced then
						announced = true
						notif('GameStaller', 'Your hitbox is '..Height.Value..' studs above the map until the game ends.', 6)
					end
				end))
			else
				stop()
			end
		end,
		Tooltip = 'Parks the hitbox the server uses far above the map from the start\nof the game until it ends, so nobody can reach you.'
	})
	Height = GameStaller:CreateSlider({
		Name = 'Height',
		Min = 200,
		Max = 5000,
		Default = 1500,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Hidden = GameStaller:CreateToggle({
		Name = 'Keep my view',
		Default = true,
		Tooltip = 'Only the hitbox goes up. Your character and camera stay on the map, on your screen only.'
	})
	Notify = GameStaller:CreateToggle({
		Name = 'Notify',
		Default = true
	})
end)

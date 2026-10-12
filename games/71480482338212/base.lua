-- tapev4 BedFight: shared setup for the categorized feature files.
if not game:IsLoaded() then game.Loaded:Wait() end

local run = function(callback)
	local ok, result = xpcall(callback, debug and debug.traceback or tostring)
	if not ok then warn('[tapev4/BedFight] Startup failed: '..tostring(result)) end
	return ok, result
end
local cloneref = cloneref or function(object) return object end
local vape = assert(shared.vape, 'BedFight requires the tapev4 GUI')
local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local collectionService = cloneref(game:GetService('CollectionService'))
local lightingService = cloneref(game:GetService('Lighting'))
local tweenService = cloneref(game:GetService('TweenService'))
local guiService = cloneref(game:GetService('GuiService'))
local runService = vape.Libraries.profiler and vape.Libraries.profiler.RunService or cloneref(game:GetService('RunService'))
local task = vape.Libraries.profiler and vape.Libraries.profiler.Task or task
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local entitylib = assert(vape.Libraries.entity, 'BedFight requires the universal entity library')
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local isnetworkowner = isnetworkowner or function() return true end
local vapeEvents = setmetatable({}, {
	__index = function(events, name)
		local event = Instance.new('BindableEvent')
		rawset(events, name, event)
		return event
	end
})
local bedfight, remotes = {}, {}
local store = {inventory = {}, tools = {}, anticheat = {Tables = {}, Blocked = {}, Armed = true}}
local active = true
local function notif(...) return vape:CreateNotification(...) end

local function disarmAnticheat(disarm)
	local state = store.anticheat
	state.Armed = not disarm
	state.Errors = {}
	-- Restoration uses the saved entries, even if discovery APIs have disappeared.
	if disarm then
		if not active then return nil, 'BedFight has unloaded' end
		if type(getloadedmodules) ~= 'function' then return nil, 'getloadedmodules is unavailable' end
		local ok, modules = pcall(getloadedmodules)
		if not ok or type(modules) ~= 'table' then
			local reason = ok and 'getloadedmodules returned a non-table' or tostring(modules)
			state.Errors.Discovery = reason
			return nil, reason
		end
		for _, module in modules do
			if module.Name == 'ClientModule' then
				local loaded, client = pcall(require, module)
				if not loaded then
					state.Errors[module] = tostring(client)
				elseif type(client) == 'table' and not state.Tables[client] then
					local original = rawget(client, 'Catch')
					if type(original) == 'function' then
						local entry = {Original = original}
						entry.Wrapper = function(...)
							-- A retained reference must stop intercepting immediately on disable.
							if not active or state.Armed then return original(...) end
							local reason = tostring(select(1, ...))
							state.Blocked[reason] = (state.Blocked[reason] or 0) + 1
							vapeEvents.AnticheatBlocked:Fire(reason)
						end
						state.Tables[client] = entry
					end
				end
			end
		end
	end
	local count, hooked = 0, 0
	for client, entry in state.Tables do
		count += 1
		local current = rawget(client, 'Catch')
		local wanted = disarm and entry.Wrapper or entry.Original
		local owned = current == entry.Wrapper
		if current ~= wanted and (disarm and current == entry.Original or not disarm and owned) then
			local ok, err = pcall(rawset, client, 'Catch', wanted)
			if not ok then state.Errors[client] = tostring(err) end
		elseif current ~= wanted then
			state.Errors[client] = 'Catch was replaced externally; leaving it untouched'
		end
		if rawget(client, 'Catch') == entry.Wrapper then hooked += 1 end
	end
	state.Found, state.Hooked = count, hooked
	if disarm then return hooked end
	return count
end
run(function() disarmAnticheat(true) end)

local function isFriend(player, recolor)
	local category = vape.Categories.Friends
	if category.Options['Use friends'].Enabled then
		local friend = table.find(category.ListEnabled, player.Name) ~= nil
		return friend and (not recolor or category.Options['Recolor visuals'].Enabled)
	end
end
local function isTarget(player) return table.find(vape.Categories.Targets.ListEnabled, player.Name) ~= nil end
local function fireRemote(name, ...)
	local remote = remotes[name]
	if not (remote and remote.Parent) then return false end
	remote:FireServer(...)
	return true
end
local function getItem(name) return store.inventory[name] end
local function heldTool()
	local character = lplr.Character
	for _, object in character and character:GetChildren() or {} do
		if object:IsA('Model') and object:HasTag('Tool') then return object end
	end
end
local function heldName() local tool = heldTool(); return tool and tool.Name end
local function serverTool()
	local value = lplr:FindFirstChild('EquippedTool')
	return value and value.Value ~= '' and value.Value or nil
end
local function sentRecently()
	return store.sentTool ~= nil and store.sentAt ~= nil and tick() - store.sentAt < math.clamp(lplr:GetNetworkPing() * 1.5 + 0.1, 0.2, 1)
end
local function equipServer(name, owner)
	store.toolOwner = owner
	local shown = serverTool() == name
	if sentRecently() then
		if store.sentTool == name then return shown end
	elseif shown then return true end
	if not fireRemote('EquipTool', name) then return false end
	store.sentTool, store.sentAt, store.toolDirty = name, tick(), true
	return false
end
local function syncTool(owner)
	if not store.toolDirty or (owner and store.toolOwner and store.toolOwner ~= owner) then return end
	local held, holding = heldName(), serverTool()
	if sentRecently() then holding = store.sentTool or nil end
	if holding ~= held then
		if not fireRemote('EquipTool', held) then return end
		store.sentTool, store.sentAt = held or false, tick()
	end
	store.toolDirty, store.toolOwner = nil, nil
end
local function getSword()
	local best, rate, damage = nil, 0, 0
	for name, amount in store.inventory do
		local data = bedfight.SwordsData and bedfight.SwordsData[name]
		if amount > 0 and type(data) == 'table' and data.Damage then
			local dps = data.Damage / math.max(data.DamageCooldown or 0.3, 0.05)
			if dps > rate or (dps == rate and data.Damage > damage) then best, rate, damage = name, dps, data.Damage end
		end
	end
	return best
end
local function getTool(blockName)
	local best, damage = nil, 0
	for name, amount in store.inventory do
		local data = bedfight.MiningData and bedfight.MiningData[name]
		if amount > 0 and type(data) == 'table' and data.Cooldown then
			local hit = data.Damages and data.Damages[blockName] or data.DefaultDamage or 0
			if hit > damage then best, damage = name, hit end
		end
	end
	return best, damage
end
local function getBlock()
	local best, amount = nil, 0
	for name, count in store.inventory do
		local data = bedfight.ItemsData and bedfight.ItemsData[name]
		local template = data and data.Class == 'Blocks' and bedfight.Blocks:FindFirstChild(name)
		if template and template:IsA('BasePart') and not name:find('TNT') and count > amount then best, amount = name, count end
	end
	return best
end
local function snap(position) return Vector3.new(math.round(position.X / 3) * 3, math.round(position.Y / 3) * 3, math.round(position.Z / 3) * 3) end
local function mapBlocks()
	local info = bedfight.GameInfo and bedfight.GameInfo:FindFirstChild('MapInfo')
	local value = info and info:FindFirstChild('BlocksContainer')
	return value and value.Value
end
local blockRay = RaycastParams.new()
blockRay.FilterType = Enum.RaycastFilterType.Include
local function blockParams()
	local list = {}
	for _, name in {'PlayersBlocksContainer', 'BedsContainer'} do
		local folder = workspace:FindFirstChild(name)
		if folder then table.insert(list, folder) end
	end
	local map = mapBlocks()
	if map then table.insert(list, map) end
	blockRay.FilterDescendantsInstances = list
	return blockRay
end
local function canFight() return entitylib.isAlive and lplr:GetAttribute('PVP') == true end
local function inMatch() return lplr.Team ~= nil and lplr.Team.Name ~= 'Spectators' end

local split
local function bodyRoot() return entitylib.character.RootPart end
local function realRoot() return split and split.Real or bodyRoot() end
local function splitJoints(state, part)
	for _, joint in state.Joints do
		local value = joint[3] and part:FindFirstChild(joint[3]) or part
		if value then joint[1][joint[2]] = value end
	end
end
local function mergeRoot(owner, force)
	if not split then return end
	if owner then split.Owners[owner] = nil end
	if not force and next(split.Owners) then return end
	local state = split
	split, store.split = nil, nil
	local real, clone, character = state.Real, state.Clone, state.Character
	if entitylib.character and entitylib.character.RootPart == clone then
		entitylib.character.RootPart, entitylib.character.HumanoidRootPart = real, real
	end
	if real.Parent and clone.Parent and character.Parent then
		local cf, velocity = clone.CFrame, clone.AssemblyLinearVelocity
		character.Parent = replicatedStorage
		real.Parent = character
		splitJoints(state, real)
		clone:Destroy()
		character.PrimaryPart, character.Parent = real, state.Home
		real.CanCollide = state.CanCollide
		if isnetworkowner(real) then real.CFrame, real.AssemblyLinearVelocity = cf, velocity end
	else clone:Destroy() end
end
local function splitRoot(owner)
	if split then split.Owners[owner] = true; return split.Real end
	if not entitylib.isAlive then return nil end
	local character, real = lplr.Character, bodyRoot()
	local home = character and character.Parent
	if not (home and home:IsDescendantOf(workspace) and real and real.Parent == character and isnetworkowner(real)) then return nil end
	local joints = {}
	for _, object in character:GetDescendants() do
		if object:IsA('Constraint') then
			for _, property in {'Attachment0', 'Attachment1'} do
				local ok, attachment = pcall(function() return object[property] end)
				if ok and attachment and attachment.Parent == real then table.insert(joints, {object, property, attachment.Name}) end
			end
		elseif object:IsA('JointInstance') and object.Parent ~= real and object.Name ~= 'HitboxMotor' then
			if object.Part0 == real then table.insert(joints, {object, 'Part0'}) end
			if object.Part1 == real then table.insert(joints, {object, 'Part1'}) end
		end
	end
	if #joints == 0 then return nil end
	local velocity, canCollide = real.AssemblyLinearVelocity, real.CanCollide
	character.Parent = replicatedStorage
	local clone = real:Clone()
	clone.Parent, real.Parent = character, workspace
	split = {Real = real, Clone = clone, Character = character, Home = home, Joints = joints, Owners = {[owner] = true}, GoalAt = 0, CanCollide = canCollide}
	splitJoints(split, clone)
	character.PrimaryPart, character.Parent = clone, home
	clone.AssemblyLinearVelocity, real.CanCollide = velocity, false
	entitylib.character.RootPart, entitylib.character.HumanoidRootPart = clone, clone
	store.split = split
	return real
end
local function sendRoot(cframe)
	if not split then return end
	split.Goal, split.GoalAt = cframe, tick()
	if isnetworkowner(split.Real) then split.Real.CFrame, split.Real.AssemblyLinearVelocity = cframe, Vector3.zero end
end

-- Register teardown before loading: partial startup must still release its connections.
vape:Clean(function()
	active = false
	run(function() disarmAnticheat(false) end)
	run(function() mergeRoot(nil, true) end)
	run(syncTool)
	for _, event in vapeEvents do event:Destroy() end
	table.clear(vapeEvents)
end)
local setupOK, setupError = run(function()
	local function child(parent, ...)
		for _, name in {...} do
			parent = parent and parent:WaitForChild(name, 20)
			if not parent then error('Missing BedFight object: '..table.concat({...}, '.')) end
		end
		return parent
	end
	local started = tick()
	local function gameRequire(module)
		local deadline = tick() + 10
		repeat
			if not active then error('BedFight startup cancelled') end
			if getloadedmodules then
				local ok, list = pcall(getloadedmodules)
				if ok and type(list) == 'table' and table.find(list, module) then break end
			elseif tick() - started > 5 then break end
			task.wait(0.1)
		until tick() >= deadline
		return require(module)
	end
	local folder = child(replicatedStorage, 'Remotes')
	local items = child(folder, 'ItemsRemotes')
	for _, name in {'SwordHit', 'EquipTool', 'ShootProjectile', 'PlaceBlock', 'MineBlock', 'Eat', 'DeployBalloon', 'DropItem'} do remotes[name] = child(items, name) end
	for _, name in {'Knockback', 'PutItemInChest', 'TakeItemFromChest', 'PurchaseItemShopItem', 'TeamUpgrade', 'PlayEmote', 'QueueToOpenServer', 'UpdateLeaderboardRanking', 'DamageIndicator'} do remotes[name] = child(folder, name) end
	remotes.Join = child(folder, 'GameRemotes', 'Join')
	local modules = child(replicatedStorage, 'Modules')
	local data = child(modules, 'DataModules')
	local handlers = child(replicatedStorage, 'ToolHandlers')
	for key, name in {GameInfo = 'GameInfo', Blocks = 'Blocks', TeamUpgrades = 'TeamUpgrades', TeamChests = 'TeamChestsStorage', Lobby = 'LobbyObject'} do bedfight[key] = child(replicatedStorage, name) end
	for _, name in {'ItemsData', 'SwordsData', 'RangedData', 'ProjectilesData', 'BlocksData', 'MiningData', 'ItemShopData', 'TeamUpgradesData', 'EmotesData', 'RanksData'} do bedfight[name] = gameRequire(child(data, name)) end
	for key, name in {InventoryHandler = 'InventoryHandler', ProjectilesController = 'ProjectilesController', PlayerConfig = 'PlayerConfigurations', ViewModelHandler = 'ViewModelHandler', VelocityUtils = 'VelocityUtils', JetpackState = 'JetpackState', ButtonProperties = 'ButtonProperties', Signals = 'Signals'} do bedfight[key] = gameRequire(child(modules, name)) end
	for _, name in {'Sword', 'Ranged', 'Block'} do bedfight[name] = gameRequire(child(handlers, name)) end
	local inventory = child(lplr, 'Inventory')
	local function refresh()
		table.clear(store.inventory)
		for _, value in inventory:GetChildren() do
			if value:IsA('NumberValue') and value.Name ~= '' and value.Value > 0 then store.inventory[value.Name] = value.Value end
		end
		store.tools.sword = getSword()
		vapeEvents.InventoryChanged:Fire()
	end
	local watched = {}
	local function unwatch(value)
		for _, connection in watched[value] or {} do connection:Disconnect() end
		watched[value] = nil
	end
	local function watch(value)
		if value:IsA('NumberValue') and not watched[value] then
			watched[value] = {value:GetPropertyChangedSignal('Value'):Connect(refresh), value:GetPropertyChangedSignal('Name'):Connect(refresh)}
		end
	end
	vape:Clean(function() for value in watched do unwatch(value) end end)
	vape:Clean(inventory.ChildAdded:Connect(function(value) watch(value); refresh() end))
	vape:Clean(inventory.ChildRemoved:Connect(function(value) unwatch(value); refresh() end))
	for _, value in inventory:GetChildren() do watch(value) end
	refresh()
	local kills, beds = sessioninfo:AddItem('Kills'), sessioninfo:AddItem('Beds')
	local function count(value, item)
		if not (value and active) then return end
		local last = value.Value
		vape:Clean(value:GetPropertyChangedSignal('Value'):Connect(function()
			if value.Value > last then item:Increment() end
			last = value.Value
		end))
	end
	task.spawn(function()
		local stats = lplr:WaitForChild('leaderstats', 20)
		count(stats and stats:WaitForChild('Kills', 5), kills)
		local gameStats = lplr:WaitForChild('GameStats', 20)
		count(gameStats and gameStats:WaitForChild('Beds Broken', 5), beds)
	end)
	local gui = lplr:FindFirstChildOfClass('PlayerGui')
	if gui then
		vape:Clean(gui.ChildAdded:Connect(function(object)
			if object:IsA('LayerCollector') or store.anticheat.Armed then return end
			task.delay(1, function() if active and not store.anticheat.Armed then run(function() disarmAnticheat(true) end) end end)
		end))
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(function() store.sentTool, store.toolDirty, store.toolOwner = nil, nil, nil end))
	if type(vape.SetGameInfo) == 'function' then
		vape:SetGameInfo({Name = 'BedFight', GetKit = function()
			local kit = lplr:FindFirstChild('Kit')
			return kit and kit.Value ~= '' and kit.Value or nil
		end})
	end
end)
if not setupOK then
	notif('BedFight', 'Game setup failed. See the startup error; try again after the game loads.', 15, 'alert')
	error('[tapev4/BedFight] Cannot load features: '..tostring(setupError), 0)
end

entitylib.targetCheck = function(ent)
	if ent.TeamCheck then return ent:TeamCheck() end
	if ent.NPC then return true end
	if isFriend(ent.Player) or not select(2, whitelist:get(ent.Player)) then return false end
	if not vape.Categories.Main.Options['Teams by server'].Enabled then return true end
	local mine, theirs = lplr.Team, ent.Player.Team
	return not mine or not theirs or mine ~= theirs or mine.Name == 'Spectators'
end
entitylib.isVulnerable = function(ent)
	return ent.Health > 0 and not ent.Character:GetAttribute('Forcefield') and (ent.NPC or ent.Player:GetAttribute('PVP') == true)
end
entitylib.getUpdateConnections = function(ent)
	return {ent.Humanoid:GetPropertyChangedSignal('Health'), ent.Humanoid:GetPropertyChangedSignal('MaxHealth'), {
		Connect = function()
			ent.Friend, ent.Target = ent.Player and isFriend(ent.Player), ent.Player and isTarget(ent.Player)
			return {Disconnect = function() end}
		end
	}}
end
entitylib.getEntityColor = function(ent)
	local player = ent.Player
	if not (player and vape.Categories.Main.Options['Use team color'].Enabled) then return end
	if isFriend(player, true) then
		local option = vape.Categories.Friends.Options['Friends color']
		return Color3.fromHSV(option.Hue, option.Sat, option.Value)
	end
	return player.Team and player.Team.Name ~= 'Spectators' and player.TeamColor.Color or nil
end
entitylib.start()

-- This checkout has no fovcircle library; use the GUI and camera directly.
local function screenDistance(position)
	local point, visible = gameCamera:WorldToViewportPoint(position)
	if not visible or point.Z <= 0 then return math.huge end
	local mouse = inputService:GetMouseLocation() - guiService:GetGuiInset()
	return (Vector2.new(point.X, point.Y) - mouse).Magnitude
end
store.sortList = {'Distance', 'Cursor', 'Angle', 'Lowest Health', 'Highest Health'}
store.targets = function(options)
	local found, candidates = {}, {}
	if not entitylib.isAlive then return found end
	local origin = options.Origin or bodyRoot().Position
	local look, mode = gameCamera.CFrame.LookVector, options.Sort or 'Distance'
	for _, ent in entitylib.List do
		if ent.Player and not options.Players or ent.NPC and not options.NPCs then continue end
		if not (ent.Targetable and ent.RootPart and entitylib.isVulnerable(ent)) then continue end
		local delta = ent.RootPart.Position - origin
		local distance = delta.Magnitude
		if distance > (options.Range or math.huge) then continue end
		local pixels = screenDistance(ent.RootPart.Position)
		if options.FOV and pixels > options.FOV or mode == 'Cursor' and pixels == math.huge then continue end
		local key = distance
		if mode == 'Cursor' then key = pixels
		elseif mode == 'Angle' then key = distance > 0.1 and math.acos(math.clamp(look:Dot(delta.Unit), -1, 1)) or 0
		elseif mode == 'Lowest Health' then key = ent.Health
		elseif mode == 'Highest Health' then key = -ent.Health end
		table.insert(candidates, {Entity = ent, Key = ent.Target and -math.huge or key, Distance = distance})
	end
	table.sort(candidates, function(a, b) return a.Key == b.Key and a.Distance < b.Distance or a.Key < b.Key end)
	for _, entry in candidates do
		if options.Walls and entitylib.Wallcheck(options.WallOrigin or origin, entry.Entity.RootPart.Position) then continue end
		table.insert(found, entry.Entity)
		if #found >= (options.Limit or 1) then break end
	end
	return found
end
local history = setmetatable({}, {__mode = 'k'})
store.motion = function(ent)
	local now, root = os.clock(), ent.RootPart
	local samples = history[ent]
	if not samples or now - samples[#samples].At > 0.5 then samples = {}; history[ent] = samples end
	table.insert(samples, {At = now, Position = root.Position})
	while #samples > 2 and now - samples[2].At >= 0.2 do table.remove(samples, 1) end
	local first = samples[1]
	return now - first.At < 0.1 and root.AssemblyLinearVelocity or (root.Position - first.Position) / (now - first.At)
end
local floorRay = RaycastParams.new()
floorRay.FilterType, floorRay.RespectCanCollide = Enum.RaycastFilterType.Exclude, true
store.aimPoint = function(origin, speed, gravity, ent, part, scale)
	if not speed or speed <= 0 or not part then return nil end
	local root, velocity = ent.RootPart, store.motion(ent)
	local horizontal, vertical = scale and scale.Horizontal or 1, scale and scale.Vertical or 1
	local flat = Vector3.new(velocity.X, 0, velocity.Z) * horizontal
	local airborne = ent.Humanoid and ent.Humanoid.FloorMaterial == Enum.Material.Air
	local offset, pull = part.Position - root.Position, Vector3.new(0, -gravity, 0)
	local floor
	if airborne then
		floorRay.FilterDescendantsInstances = {workspace:FindFirstChild('PlayersContainer') or ent.Character, gameCamera}
		local ground = workspace:Raycast(root.Position, Vector3.new(0, -60, 0), floorRay)
		floor = ground and ground.Position.Y + (ent.HipHeight or 3)
	end
	local function at(time)
		local position = root.Position + flat * time
		if airborne then
			local y = root.Position.Y + velocity.Y * time - workspace.Gravity * time * time / 2
			if floor then y = math.max(y, floor) end
			position = Vector3.new(position.X, root.Position.Y + (y - root.Position.Y) * vertical, position.Z)
		end
		return position + offset
	end
	local lead = math.clamp(lplr:GetNetworkPing() + 0.05, 0, 0.4)
	local time = (at(lead) - origin).Magnitude / speed
	local aim
	for _ = 1, 8 do aim = at(lead + time) - pull * (time * time / 2); time = (aim - origin).Magnitude / speed end
	aim = at(lead + time) - pull * (time * time / 2)
	return aim == aim and aim or nil
end
store.ring = function(module, name, tooltip)
	local api = {}
	local circle, show, colour, thickness
	function api.Update(state)
		if circle then circle:Destroy(); circle = nil end
		if state == nil then state = module.Enabled end
		if not (state and show.Enabled) then return end
		circle = Instance.new('Frame')
		circle.Name, circle.BackgroundTransparency, circle.AnchorPoint = name, 1, Vector2.new(0.5, 0.5)
		circle.Parent = vape.gui
		local corner = Instance.new('UICorner')
		corner.CornerRadius, corner.Parent = UDim.new(1, 0), circle
		local stroke = Instance.new('UIStroke')
		stroke.Parent = circle
		local current = circle
		local connection = runService.RenderStepped:Connect(function()
			local radius = api.Radius and api.Radius() or 0
			local mouse = inputService:GetMouseLocation()
			if not vape.gui.IgnoreGuiInset then mouse -= guiService:GetGuiInset() end
			current.Position, current.Size = UDim2.fromOffset(mouse.X, mouse.Y), UDim2.fromOffset(radius * 2, radius * 2)
			stroke.Color, stroke.Thickness = Color3.fromHSV(colour.Hue, colour.Sat, colour.Value), thickness.Value
		end)
		current.Destroying:Once(function() connection:Disconnect() end)
	end
	show = module:CreateToggle({Name = 'FOV Circle', Tooltip = tooltip, Function = function(value)
		if colour then colour.Object.Visible = value end
		if thickness then thickness.Object.Visible = value end
		api.Update()
	end})
	colour = module:CreateColorSlider({Name = 'Circle colour', Darker = true, Visible = false})
	thickness = module:CreateSlider({Name = 'Circle thickness', Min = 1, Max = 8, Default = 1, Darker = true, Visible = false})
	api.Show = show
	vape:Clean(function() if circle then circle:Destroy(); circle = nil end end)
	return api
end
store.inCombat = function()
	if not entitylib.isAlive then return false end
	local health = entitylib.character.Humanoid.Health
	if store.seenHealth and health < store.seenHealth - 0.5 then store.hurtAt = tick() end
	store.seenHealth = health
	return tick() - (store.hurtAt or 0) < 5 or tick() - (store.melee or 0) < 3 or #store.targets({Range = 20, Players = true, NPCs = true}) > 0
end
vape:Clean(entitylib.Events.LocalRemoved:Connect(function()
	if not split then return end
	local hum = split.Character.Parent and split.Character:FindFirstChildOfClass('Humanoid')
	if hum and hum.Health > 0 and lplr.Character == split.Character then mergeRoot(nil, true); return end
	local clone = split.Clone
	split, store.split = nil, nil
	clone:Destroy()
end))
vape:Clean(runService.Heartbeat:Connect(function()
	if not split then return end
	local real, clone = split.Real, split.Clone
	if not (entitylib.isAlive and real.Parent and clone.Parent) then mergeRoot(nil, true); return end
	if isnetworkowner(real) then
		real.CFrame = split.GoalAt > tick() - 0.1 and split.Goal or clone.CFrame
		real.AssemblyLinearVelocity = Vector3.zero
	end
end))
if store.anticheat.Tripped then notif('BedFight', 'This session was already flagged before startup; rejoin before testing.', 20, 'alert') end
for _, name in {'Killaura', 'Reach', 'Speed', 'Fly', 'HitBoxes', 'SilentAim', 'Disabler', 'MurderMystery'} do vape:Remove(name) end

-- Feature placeholders are maintained by tools/game_modules.py.

--[[AEROV4_GAME_MODULE_001]]

--[[AEROV4_GAME_MODULE_002]]

--[[AEROV4_GAME_MODULE_003]]

--[[AEROV4_GAME_MODULE_004]]

--[[AEROV4_GAME_MODULE_005]]

--[[AEROV4_GAME_MODULE_006]]

--[[AEROV4_GAME_MODULE_007]]

--[[AEROV4_GAME_MODULE_008]]

--[[AEROV4_GAME_MODULE_009]]

--[[AEROV4_GAME_MODULE_010]]

--[[AEROV4_GAME_MODULE_011]]

--[[AEROV4_GAME_MODULE_012]]

--[[AEROV4_GAME_MODULE_013]]

--[[AEROV4_GAME_MODULE_014]]

--[[AEROV4_GAME_MODULE_015]]

--[[AEROV4_GAME_MODULE_016]]

--[[AEROV4_GAME_MODULE_017]]

--[[AEROV4_GAME_MODULE_018]]

--[[AEROV4_GAME_MODULE_019]]

--[[AEROV4_GAME_MODULE_020]]

--[[AEROV4_GAME_MODULE_021]]

--[[AEROV4_GAME_MODULE_022]]

--[[AEROV4_GAME_MODULE_023]]

--[[AEROV4_GAME_MODULE_024]]

--[[AEROV4_GAME_MODULE_025]]

--[[AEROV4_GAME_MODULE_026]]

--[[AEROV4_GAME_MODULE_027]]

--[[AEROV4_GAME_MODULE_028]]

--[[AEROV4_GAME_MODULE_029]]

--[[AEROV4_GAME_MODULE_030]]

--[[AEROV4_GAME_MODULE_031]]

--[[AEROV4_GAME_MODULE_032]]

--[[AEROV4_GAME_MODULE_033]]

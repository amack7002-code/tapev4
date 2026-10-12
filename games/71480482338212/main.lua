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

run(function()
	local AntiHit
	local Range
	local Height
	local Hits
	local Dodge
	local filtered
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	-- measured 2026-10-12: a root that has been off the ground for a second is taken by the server and
	-- left on the ground for four. 0.9s up with 0.1s on the ground held every time, 1.1s up never did
	local UP, DOWN, EARLY = 0.75, 0.13, 0.35
	-- coming down from more than 20 studs costs health
	local MAX_DROP = 18
	-- the game's own swing box ends 13.75 studs from the swinger, and no hit sent from 17 or more ever counted
	local SWING, CLEAR = 14.5, 17.5
	-- the root is back in reach this long before your hit is sent, and stays this long after
	local LEAD, HOLD = 0.12, 0.05
	local FLAT = Vector3.new(1, 0, 1)

	local idle, lastDraw = 0, 0
	local groundAt, downUntil, standing = 0, 0, false
	local peak, lastSpot, stepped
	local managedAt, gateSince, gateAt = 0, nil, 0
	local reachOf, reachSince
	local struckAt, seenStruck = 0, nil
	local dangers = {}

	local function release()
		if store.antiHit then
			store.antiHit = nil
			mergeRoot('AntiHit')
		end
		reachOf, reachSince, peak, lastSpot, stepped = nil, nil, nil, nil, nil
	end

	local function reach()
		return math.min(store.meleeRange or 14, 14)
	end

	local function cooldown()
		local data = store.tools.sword and bedfight.SwordsData and bedfight.SwordsData[store.tools.sword]
		return type(data) == 'table' and data.DamageCooldown or 0.3
	end

	-- the shot that is about to pass, if any
	local function incoming(now)
		for i = #dangers, 1, -1 do
			if dangers[i].To < now then
				table.remove(dangers, i)
			end
		end
		return dangers[1]
	end

	-- how much room a hitbox at this height has from every shot passing right now. below zero is a hit
	local function room(y, now)
		local least = math.huge
		for _, shot in dangers do
			if now >= shot.From then
				least = math.min(least, math.abs(shot.Y - y) - shot.Need)
			end
		end
		return least
	end

	AntiHit = vape.Categories.Blatant:CreateModule({
		Name = 'AntiHit',
		Function = function(callback)
			if callback then
				-- Killaura asks before each hit. the root is only brought into reach for the hit itself
				store.strikeGate = function(ent)
					local now = tick()
					if not Hits.Enabled or now - managedAt > 0.1 then return true end
					gateAt = now
					gateSince = gateSince or now
					-- never holds a hit back for long
					if now - gateSince > 0.45 then return true end
					if now - struckAt < cooldown() - 0.02 then return false end
					return reachOf == ent and reachSince ~= nil and now - reachSince >= LEAD
				end

				AntiHit:Clean(entitylib.Events.LocalRemoved:Connect(function()
					store.antiHit = nil
					table.clear(dangers)
				end))

				local remote = replicatedStorage:FindFirstChild('Remotes')
				remote = remote and remote:FindFirstChild('ReplicateProjectile')
				if remote then
					AntiHit:Clean(remote.OnClientEvent:Connect(function(userId, _, name, origin, speed, unit)
						if not Dodge.Enabled or userId == lplr.UserId or not entitylib.isAlive then return end
						if typeof(origin) ~= 'Vector3' or typeof(unit) ~= 'Vector3' or type(speed) ~= 'number' then return end
						local data = bedfight.ProjectilesData and bedfight.ProjectilesData[name]
						if type(data) ~= 'table' then return end
						local shooter = playersService:GetPlayerByUserId(userId)
						if shooter and lplr.Team and shooter.Team == lplr.Team and lplr.Team.Name ~= 'Spectators' then return end
						-- the game flies it as origin + velocity * t + gravity * t * t / 2
						local body = bodyRoot().Position
						local velocity = unit * speed
						local across = velocity * FLAT
						if across.Magnitude < 1 then return end
						local t = ((body - origin) * FLAT):Dot(across) / across.Magnitude ^ 2
						if t <= 0 or t > math.min(data.LifeTime or 5, 4) then return end
						local gravity = typeof(data.Gravity) == 'Vector3' and data.Gravity or Vector3.zero
						local at = origin + velocity * t + gravity * (t * t / 2)
						local blast = data.BlastRadius or 0
						if ((at - body) * FLAT).Magnitude > blast + 8 then return end
						-- it left a ping ago by the time the root can be somewhere else for the server
						local arrive = tick() + t - math.min(lplr:GetNetworkPing() * 2, 0.6)
						if arrive + 0.3 < tick() or #dangers >= 24 then return end
						-- the hitbox is 6.5 tall
						table.insert(dangers, {From = arrive - 0.25, To = arrive + 0.3, Y = at.Y, Need = math.max(5, blast + 3)})
					end))
				end

				AntiHit:Clean(runService.Heartbeat:Connect(function()
					if not entitylib.isAlive or store.flyOn or store.dashOn then
						release()
						return
					end
					local now = tick()
					local danger = incoming(now)
					local threat = canFight() and store.targets({Range = Range.Value, Players = true, NPCs = true, Limit = 1})[1]
					if threat or danger then
						idle = now
					elseif now - idle > 0.6 then
						release()
						return
					end
					if not store.antiHit then
						if not ((threat or danger) and splitRoot('AntiHit')) then return end
						store.antiHit = true
						groundAt, downUntil, standing = now, 0, false
					end
					if store.struckAt ~= seenStruck then
						seenStruck = store.struckAt
						struckAt = now
						gateSince = nil
					elseif gateSince and now - gateAt > 0.15 then
						gateSince = nil
					end

					local fighting = now - (store.melee or 0) < 0.4
					local held = inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and heldName()
					if held then
						-- your own shots leave from the root, and a swing by hand is measured from it
						if bedfight.RangedData and bedfight.RangedData[held] then
							lastDraw = now
						elseif Hits.Enabled and not fighting and threat and bedfight.SwordsData and bedfight.SwordsData[held] and (threat.RootPart.Position - bodyRoot().Position).Magnitude < SWING + 2 then
							lastDraw = now
						end
					end
					local body = bodyRoot()
					local hip = entitylib.character.HipHeight
					local container = workspace:FindFirstChild('PlayersContainer') or lplr.Character
					if filtered ~= container then
						filtered = container
						rayCheck.FilterDescendantsInstances = {container, gameCamera}
					end
					local under = now - lastDraw >= 0.3 and workspace:Raycast(body.Position, Vector3.new(0, -(MAX_DROP + hip + 2), 0), rayCheck)
					if not under then
						-- drawing a shot, or nothing to stand on within a free drop: the root stays in the body
						if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
							groundAt, peak = now, nil
						end
						standing, downUntil = false, 0
						reachOf, reachSince = nil, nil
						return
					end
					local spot = Vector3.new(body.Position.X, under.Position.Y + hip, body.Position.Z)
					store.antiHitAt = now
					managedAt = now

					-- the server counts a fall from the highest point since the root last stood. when the ground
					-- under you drops, it stands on the old ground once more before it follows you down
					local stand = spot
					if peak and peak - spot.Y > MAX_DROP + 1.5 then
						if lastSpot and not stepped and ((lastSpot - spot) * FLAT).Magnitude < 12 then
							stand = lastSpot
						end
					else
						lastSpot, stepped = spot, nil
					end

					if standing and now >= downUntil then
						standing = false
						groundAt = now
						peak = stand.Y
						if stand ~= spot then
							stepped = true
							stand = spot
						end
					end

					local top = spot.Y + Height.Value
					local target = Hits.Enabled and fighting and store.meleeTarget or nil
					if target and not (target.RootPart and target.RootPart.Parent) then
						target = nil
					end
					local strikeY, grounded
					if target then
						-- as high as still reaches who you are hitting
						local far = reach() - 0.75
						local aimed = target.RootPart.Position
						local flat = ((aimed - spot) * FLAT).Magnitude
						strikeY = math.clamp(aimed.Y + (far > flat and math.sqrt(far * far - flat * flat) or 0), spot.Y, top)
						grounded = (aimed - spot).Magnitude <= far
					end
					local due = target and math.max(store.meleeDue or now, struckAt + cooldown()) or nil
					-- a hit that does not go out within a moment is not waited for down there
					local strike = due and ((due - now <= LEAD and now - due < 0.3) or now - struckAt < HOLD)
					local since = now - groundAt
					local clear = not threat or (threat.RootPart.Position - spot).Magnitude > CLEAR

					local y
					if standing then
						y = stand.Y
					elseif stand ~= spot or since >= UP then
						standing, downUntil = true, now + DOWN
						y = stand.Y
					elseif since >= EARLY and clear and (not danger or room(stand.Y, now) >= 0) then
						-- it has to stand once in a while, and does while nothing can reach the spot
						standing, downUntil = true, now + DOWN
						y = stand.Y
					elseif strike then
						y = strikeY
					else
						y = top
					end
					if danger and not standing and room(y, now) < 0 then
						-- a shot passes at that height. the hitbox waits at the height furthest from every shot instead
						local best, most = y, room(y, now)
						local try = top
						while try >= spot.Y + 3 do
							local space = room(try, now)
							if space > most + 0.5 then
								best, most = try, space
							end
							try -= 3
						end
						y = best
					end
					if standing and strike and grounded and now + HOLD > downUntil then
						-- your hit goes out from down here
						downUntil = now + HOLD
					end

					local at = Vector3.new(stand.X, y, stand.Z)
					peak = math.max(peak or y, y)
					if target and (at - target.RootPart.Position).Magnitude <= reach() - 0.25 then
						if reachOf ~= target or not reachSince then
							reachOf, reachSince = target, now
						end
					else
						reachOf, reachSince = nil, nil
					end
					sendRoot(CFrame.new(at) * body.CFrame.Rotation)
				end))
			else
				store.strikeGate = nil
				table.clear(dangers)
				release()
			end
		end,
		Tooltip = 'While an enemy is close, keeps the hitbox the server hits high above you, out of reach of any sword.\nYour character and camera stay where they are. The hitbox touches the ground for an eighth of a second\nevery three quarters of a second, because the server takes back one that floats for a whole second, and sooner whenever nobody can reach it.'
	})
	Range = AntiHit:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 40,
		Default = 22,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How close an enemy has to be before the hitbox lifts'
	})
	Height = AntiHit:CreateSlider({
		Name = 'Hover height',
		Min = 12,
		Max = 18,
		Default = 17,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far above the ground under you the hitbox waits. A swing ends 13.75 studs from the swinger, and coming down from more than 20 costs health.'
	})
	Hits = AntiHit:CreateToggle({
		Name = 'Keep your hits',
		Default = true,
		Tooltip = 'Your own hits are measured from the hitbox. With Killaura it drops into reach for a moment before each hit and goes straight back up.\nSwinging by hand or drawing a bow brings it back to you for as long as you hold the button.'
	})
	Dodge = AntiHit:CreateToggle({
		Name = 'Dodge projectiles',
		Default = true,
		Tooltip = 'Works out where an arrow or fireball passes you and has the hitbox at a height it misses when it does.\nA shot that takes less than your ping to arrive cannot be dodged, and neither can one that comes while the hitbox has to touch the ground.'
	})
end)


run(function()
	local Fly
	local Value
	local Vertical
	local AirTime
	local Extend
	local ShowUI
	local gui, bar, label
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

	local function setBar(fraction, text)
		if not gui then return end
		gui.Visible = ShowUI.Enabled
		bar.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		label.Text = text
	end

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			store.flyOn = callback or nil
			if callback then
				local air, phase, returnY, landY = 0, 'fly', 0, 0

				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if not entitylib.isAlive then return end
					local hum, root = entitylib.character.Humanoid, entitylib.character.RootPart
					rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
					local ground = workspace:Raycast(root.Position, Vector3.new(0, -500, 0), rayCheck)
					local height = entitylib.character.HipHeight
					local grounded = ground and ground.Distance <= height + 0.4

					local vertical = 0
					if not inputService:GetFocusedTextBox() then
						vertical = (inputService:IsKeyDown(Enum.KeyCode.Space) and Vertical.Value or 0) - (inputService:IsKeyDown(Enum.KeyCode.LeftShift) and Vertical.Value or 0)
					end

					if phase == 'down' then
						-- stand on the block below for a moment, then go straight back up
						air += dt
						if air >= 0.15 or not ground then
							root.CFrame += Vector3.new(0, returnY - root.Position.Y, 0)
							phase, air = 'fly', 0
						else
							root.CFrame += Vector3.new(0, landY - root.Position.Y, 0)
							vertical = 0
						end
					else
						-- AntiCheatBypass touches down for you without moving the camera
						local covered = store.floatCover and tick() - store.floatCover < 0.25
						air = (grounded or covered) and 0 or air + dt
						if air >= math.min(AirTime.Value, 0.9) then
							if Extend.Enabled and ground and ground.Distance - height <= 15 then
								phase, air, returnY, landY = 'down', 0, root.Position.Y, ground.Position.Y + height
							elseif air >= 0.9 then
								notif('Fly', 'No ground close enough to touch, landing before the server pulls you back.', 4)
								Fly:Toggle()
								return
							end
						end
					end

					local move = hum.MoveDirection * Value.Value
					-- half a frame of gravity keeps the hover level
					root.AssemblyLinearVelocity = Vector3.new(move.X, vertical + workspace.Gravity * dt / 2, move.Z)
					local limit = Extend.Enabled and math.min(AirTime.Value, 0.9) or 0.9
					setBar(phase == 'down' and 0 or 1 - air / limit, string.format('%.1fs', phase == 'down' and 0 or math.max(limit - air, 0)))
				end))
			elseif gui then
				gui.Visible = false
			end
		end,
		Tooltip = 'Flies with Space and Shift for up and down.\nThe server takes over a character that has been off the ground for a second,\nso the flight touches the ground in time or ends.'
	})
	Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 30,
		Default = 24,
		Suffix = 'studs',
		Tooltip = '24 flew without the server stepping in, 32 was pulled back after five seconds'
	})
	Vertical = Fly:CreateSlider({
		Name = 'Vertical speed',
		Min = 1,
		Max = 30,
		Default = 24,
		Suffix = 'studs'
	})
	AirTime = Fly:CreateSlider({
		Name = 'Air time',
		Min = 0.5,
		Max = 0.9,
		Default = 0.8,
		Decimal = 10,
		Suffix = 's',
		Tooltip = 'How long you stay up between two ground touches. 0.9 held, 1.1 did not.'
	})
	Extend = Fly:CreateToggle({
		Name = 'Touch ground',
		Default = true,
		Tooltip = 'Stands on the ground for 0.15 seconds each time the air time is up and comes straight back.\nWorks while the ground is within 15 studs. Off, or over the void, the flight ends after 0.9 seconds.'
	})
	ShowUI = Fly:CreateToggle({
		Name = 'Show UI',
		Default = true
	})

	gui = Instance.new('Frame')
	gui.Size = UDim2.fromOffset(220, 12)
	gui.Position = UDim2.new(0.5, -110, 0.72, 0)
	gui.BackgroundColor3 = Color3.new()
	gui.BackgroundTransparency = 0.5
	gui.BorderSizePixel = 0
	gui.Visible = false
	gui.Parent = vape.gui
	bar = Instance.new('Frame')
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(211, 120, 255)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	label = Instance.new('TextLabel')
	label.Size = UDim2.new(1, 0, 0, 16)
	label.Position = UDim2.fromOffset(0, -18)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = ''
	label.Parent = gui
	for _, v in {gui, bar} do
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = v
	end
	vape:Clean(gui)
end)


run(function()
	local InfiniteFly
	local Value
	local Vertical
	local Safe
	local Leash
	local Notify
	local state
	local landing = false
	local active = false
	local filtered
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	-- measured 2026-10-12 with the root hidden. along the ground at 22 studs a second it went 50 seconds
	-- and 1,089 studs without the server stepping in; at 30 it was pulled back after 31 seconds.
	-- one jump of 100 studs in a third of a second is let through when the root stood still for two
	-- seconds before and after it. a second jump sooner, or one that takes longer than 0.4s, is put back.
	-- 128 studs at 450 a second got through three times out of three after six seconds of standing,
	-- and failed straight after other jumps
	local WALK = 22
	local HOP, HOP_SPEED, REST = 100, 300, 2
	local FAR, FAR_SPEED, FAR_REST = 136, 450, 6
	-- with Safe on, how far from the root a landing may be: one of the jumps that went through 16 times out of 17
	local SAFE = HOP - 4
	-- coming down more than 20 studs costs health
	local FREE_DROP = 18
	local STEP_UP = 4
	-- standing on the last three studs of the lobby's stone ledge got the root taken and dropped
	local EDGE = 3
	local SIDES = {Vector3.zero, Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1)}

	local function tell(text, kind)
		if Notify.Enabled then
			notif('InfiniteFly', text, 6, kind)
		end
	end

	-- the longest jump the root may try
	local function furthest()
		return Safe.Enabled and HOP or FAR
	end

	local function aim()
		local container = workspace:FindFirstChild('PlayersContainer') or lplr.Character
		if filtered ~= container then
			filtered = container
			rayCheck.FilterDescendantsInstances = {container, gameCamera}
		end
	end

	local function floor(position, depth)
		return workspace:Raycast(position, Vector3.new(0, -depth, 0), rayCheck)
	end

	-- the ground one step ahead, when the root can simply walk onto it. it goes through walls,
	-- up a block and down any drop that is free
	local function walkable(st, point)
		local feet = st.Root.Position.Y - st.Hip
		local hit = floor(Vector3.new(point.X, feet + STEP_UP, point.Z), STEP_UP + FREE_DROP)
		if not hit or hit.Instance.Transparency >= 1 then return nil end
		return hit.Position.Y + st.Hip
	end

	-- real ground under a point, looked for from a height. invisible walls and thin edges do not count
	local function ground(point, top, depth)
		local y
		for i, side in SIDES do
			local hit = floor(Vector3.new(point.X, top, point.Z) + side, depth)
			if not hit or hit.Instance.Transparency >= 1 then return nil end
			if i == 1 then
				y = hit.Position.Y
			elseif math.abs(hit.Position.Y - y) > 3 then
				return nil
			end
		end
		return y
	end

	-- where the root could stand at a point and get to in one jump
	local function standing(point, st, bodyY, final)
		local from = st.Root.Position
		-- the highest ground under your flight, or failing that the ground on the root's own level
		for _, top in {math.max(from.Y, bodyY) + 6, from.Y + 6} do
			local y = ground(point, top, top - from.Y + st.Hip + (final and 4 * FREE_DROP or FREE_DROP) + 1)
			if y then
				local spot = Vector3.new(point.X, y + st.Hip, point.Z)
				if (spot - from).Magnitude <= furthest() + 0.5 then
					return spot
				end
			end
		end
		return nil
	end

	-- a long jump needs a longer stand first. true once the root is on its way
	local function hop(st, to, final, now)
		local from = st.Root.Position
		local length = (to - from).Magnitude
		local far = length > HOP + 0.5
		if now - st.Still < (far and FAR_REST or REST) then return false end
		st.Leg = {From = from, To = to, Time = math.max(length, 25) / (far and FAR_SPEED or HOP_SPEED), Alpha = 0, Final = final}
		st.Still, st.Blocked = nil, nil
		return true
	end

	-- moves the root one frame towards the target: a step along the ground, a frame of a jump, or a wait
	local function advance(st, dt, target, final)
		local real = realRoot()
		local now = tick()
		if not isnetworkowner(real) then
			-- the server has it. whatever it does with it, carry on from there afterwards
			st.HeldAt = st.HeldAt or now
			st.Leg = nil
			return
		elseif st.HeldAt then
			st.HeldAt = nil
			st.Root = CFrame.new(real.Position) * st.Root.Rotation
			st.Still = now
			st.Pulls = (st.Pulls or 0) + 1
			tell('The server moved your hitbox back. It carries on from there.', 'warning')
		end

		local leg = st.Leg
		if leg then
			leg.Alpha = math.min(leg.Alpha + dt / leg.Time, 1)
			st.Root = CFrame.new(leg.From:Lerp(leg.To, leg.Alpha)) * st.Root.Rotation
			if leg.Alpha >= 1 then
				st.Leg = nil
				st.Arrived = leg.Final or nil
				st.Still = now
				st.RestUntil = now + REST
			end
			return
		end

		local from = st.Root.Position
		local offset = target - from
		local flat = offset * Vector3.new(1, 0, 1)
		local distance = flat.Magnitude
		if final and offset.Magnitude < 0.5 then
			st.Arrived = true
			return
		end
		if now < (st.RestUntil or 0) then return end
		aim()

		if distance > (final and 0.05 or 2) then
			local unit = flat.Unit
			local step = math.min(WALK * dt, distance)
			local point = from + unit * step
			local y
			if final and step >= distance - 0.01 and math.abs(target.Y - from.Y) <= STEP_UP then
				y = target.Y
			elseif (final and distance <= EDGE) or walkable(st, point + unit * EDGE) then
				-- it stops short of an edge it is walking towards
				y = walkable(st, point)
			end
			if y then
				st.Root = CFrame.new(point.X, y, point.Z) * st.Root.Rotation
				st.Still, st.Blocked = nil, nil
				return
			end
		elseif not final then
			-- under you
			st.Still = st.Still or now
			st.Blocked = nil
			return
		end

		-- nothing to walk on ahead: a gap, a drop, or the landing spot is on another level
		st.Still = st.Still or now
		st.Blocked = st.Blocked or now
		if now - st.Still < REST or now - (st.Thought or 0) < 0.3 then return end
		st.Thought = now
		if final and offset.Magnitude <= furthest() + 0.5 then
			hop(st, target, true, now)
			return
		end
		if distance > 1 then
			-- as far across as one jump goes and the ground lets it
			local unit = flat.Unit
			local length = math.min(distance, furthest())
			while length >= 5 do
				local spot = standing(from + unit * length, st, target.Y, final)
				if spot then
					hop(st, spot, false, now)
					return
				end
				length -= 5
			end
		end
		if final and now - st.Blocked > (Safe.Enabled and REST or FAR_REST) + 1.5 then
			st.Failed = true
		end
	end

	-- how far off the next ground on the way to you is, for the notice
	local function gap(st, target)
		local from = st.Root.Position
		local flat = (target - from) * Vector3.new(1, 0, 1)
		if flat.Magnitude < 1 then return nil end
		aim()
		local top = math.max(from.Y, target.Y) + 6
		for length = 10, math.min(flat.Magnitude, 600), 5 do
			if ground(from + flat.Unit * length, top, top - from.Y + 400) then
				return length
			end
		end
		return nil
	end

	-- the body waits where you want to be while the root finishes its way there
	local function land(st)
		landing = true
		aim()
		local body = bodyRoot()
		local under = floor(body.Position, 700)
		local goal
		if under then
			goal = Vector3.new(body.Position.X, under.Position.Y + st.Hip, body.Position.Z)
			if st.Root.Position.Y - goal.Y > FREE_DROP + 2 then
				tell(string.format('Landing %d studs lower than your hitbox stands. The server counts that as a fall.', st.Root.Position.Y - goal.Y), 'warning')
			end
		else
			goal = st.Root.Position
			tell('Nothing to land on under you, so you are back where your hitbox stands.', 'warning')
		end
		local away = ((goal - st.Root.Position) * Vector3.new(1, 0, 1)).Magnitude
		if away > WALK * 3 then
			tell(string.format('Your hitbox is still on its way, about %d seconds.', away / WALK + 1))
		end

		local hover = CFrame.new(goal) * body.CFrame.Rotation
		local done, standUntil, back = false, nil, false
		local started = tick()
		st.Landing = true
		st.Blocked = nil
		local conn
		conn = runService.Heartbeat:Connect(function(dt)
			if not (entitylib.isAlive and store.split) then
				done = true
				return
			end
			local clone = bodyRoot()
			clone.CFrame = hover
			clone.AssemblyLinearVelocity = Vector3.zero
			store.antiHitAt = tick()
			advance(st, dt, goal, true)
			sendRoot(st.Root)
			if st.Arrived and not st.Leg then
				-- stands there for a moment before the two are one again
				standUntil = standUntil or tick() + 0.3
				if tick() >= standUntil then
					done = true
				end
			elseif st.Failed then
				local wide = gap(st, goal)
				tell(wide and string.format('The next ground on the way is %d studs off and the hitbox can only jump %d, so you are back where it stands.', wide, furthest()) or 'The hitbox has no way to that spot, so you are back where it stands.', 'warning')
				done, back = true, true
			elseif (st.HeldAt and tick() - st.HeldAt > 8) or (st.Pulls or 0) >= 3 or tick() - started > 90 then
				tell('The server keeps hold of your hitbox, so you are back where it stands.', 'warning')
				done, back = true, true
			end
		end)
		repeat task.wait() until done
		conn:Disconnect()
		if back and store.split and entitylib.isAlive then
			-- you go to the hitbox. the hitbox is never thrown across to you
			local real = realRoot()
			local clone = bodyRoot()
			clone.CFrame = isnetworkowner(real) and st.Root or real.CFrame
			clone.AssemblyLinearVelocity = Vector3.zero
		end
		mergeRoot('InfiniteFly')
		store.flyOn = nil
		active = false
		landing = false
		state = nil
	end

	InfiniteFly = vape.Categories.Blatant:CreateModule({
		Name = 'InfiniteFly',
		Function = function(callback)
			if callback then
				if landing or not entitylib.isAlive or store.flyOn or store.dashOn then
					task.defer(function()
						if InfiniteFly.Enabled then
							InfiniteFly:Toggle()
						end
					end)
					return
				end
				aim()
				local body = bodyRoot()
				local hip = entitylib.character.HipHeight
				local under = floor(body.Position, FREE_DROP + hip + 2)
				local real = under and splitRoot('InfiniteFly')
				if not real then
					tell(under and 'Could not take off right now.' or 'Take off from the ground, or from less than 18 studs above it.', 'warning')
					task.defer(function()
						if InfiniteFly.Enabled then
							InfiniteFly:Toggle()
						end
					end)
					return
				end

				-- the server only ever sees the root on the ground. where you fly is up to you
				local st = {
					Root = CFrame.new(body.Position.X, under.Position.Y + hip, body.Position.Z) * body.CFrame.Rotation,
					Hip = hip,
					Still = tick()
				}
				state = st
				store.flyOn = true
				active = true
				InfiniteFly:Clean(runService.PreSimulation:Connect(function(dt)
					if not (entitylib.isAlive and store.split) then
						if state == st then
							state = nil
						end
						InfiniteFly:Toggle()
						return
					end
					-- Prevent lagback and AntiHit leave the root alone while this is fresh
					store.antiHitAt = tick()
					local hum, clone = entitylib.character.Humanoid, bodyRoot()
					advance(st, dt, clone.Position, false)
					sendRoot(st.Root)
					if not st.Blocked then
						st.Told = nil
					elseif not st.Told and tick() - st.Blocked > 4 then
						st.Told = true
						local wide = gap(st, clone.Position)
						tell(wide and wide > furthest() and string.format('Your hitbox waits at an edge. The next ground on your way is %d studs off and it can only jump %d, so land on this side.', wide, furthest()) or 'Your hitbox waits at an edge until there is ground under your way again.', 'warning')
					end

					local vertical = 0
					if not inputService:GetFocusedTextBox() then
						vertical = (inputService:IsKeyDown(Enum.KeyCode.Space) and Vertical.Value or 0) - (inputService:IsKeyDown(Enum.KeyCode.LeftShift) and Vertical.Value or 0)
					end
					local move = hum.MoveDirection * Value.Value
					-- how fast you may still move away from the hitbox. it eases off, so nothing stutters at a limit
					local ahead = (clone.Position - st.Root.Position) * Vector3.new(1, 0, 1)
					local gone = ahead.Magnitude
					if gone > 0.1 then
						local out = ahead.Unit
						local along = move:Dot(out)
						local pace = math.huge
						if Leash.Value < 500 then
							-- down to the hitbox's own pace at the leash, so a landing never waits long
							pace = WALK * 0.95 + math.max(Leash.Value - gone, 0) * 4
						end
						if Safe.Enabled then
							-- and to a stop one sure jump out, measured to where you would land
							aim()
							local below = floor(clone.Position, 500)
							local level = below and below.Position.Y + st.Hip - st.Root.Position.Y or 0
							local room = math.sqrt(math.max(SAFE * SAFE - level * level, 0)) - gone
							local safe = math.max(room, 0) * 4
							if safe < pace then
								pace = safe
								if room < 3 and along > pace then
									local now = tick()
									st.Capped = now
									st.CappedSince = st.CappedSince or now
									if not st.SafeTold and now - st.CappedSince > 1.5 then
										st.SafeTold = true
										tell(string.format('Safe keeps you within one %d stud jump of your hitbox. Wait for it to catch up, or switch Safe off to fly further ahead.', HOP))
									end
								else
									st.CappedSince = nil
								end
							else
								st.CappedSince = nil
							end
						end
						if along > pace then
							move -= out * (along - pace)
						end
					end
					-- half a frame of gravity keeps the hover level
					clone.AssemblyLinearVelocity = Vector3.new(move.X, vertical + workspace.Gravity * dt / 2, move.Z)
				end))
			else
				local st = state
				if st and not st.Landing and store.split and entitylib.isAlive then
					task.spawn(land, st)
				elseif active and not landing then
					mergeRoot('InfiniteFly')
					store.flyOn = nil
					active = false
					state = nil
				end
			end
		end,
		ExtraText = function()
			local st = state
			if not (st and store.split and entitylib.isAlive) then return '' end
			local behind = ((bodyRoot().Position - st.Root.Position) * Vector3.new(1, 0, 1)).Magnitude
			if st.Landing then
				return string.format('landing %ds', behind / WALK + 1)
			end
			if st.Capped and tick() - st.Capped < 0.3 then
				return string.format('%d behind, safe limit', behind)
			end
			return string.format(st.Blocked and '%d behind, waiting' or '%d behind', behind)
		end,
		Tooltip = 'Flies for as long as you like, with Space and Shift for up and down.\nYour hitbox follows on the ground below at 22 studs a second, the fastest the server lets a character go for long,\nand jumps a gap once there is ground on your way again: up to 100 studs after standing for two seconds, and with Safe off up to 136 after six.\nSwitch it off over ground to land. A landing waits until the hitbox is there.\nWhile you fly, players can hit you where the hitbox is, and you cannot hit, mine or pick anything up.'
	})
	Value = InfiniteFly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 40,
		Suffix = 'studs',
		Tooltip = 'How fast you fly. The hitbox follows at 22, so anything faster only gets you as far ahead as the leash.'
	})
	Vertical = InfiniteFly:CreateSlider({
		Name = 'Vertical speed',
		Min = 1,
		Max = 150,
		Default = 40,
		Suffix = 'studs'
	})
	Safe = InfiniteFly:CreateToggle({
		Name = 'Safe',
		Tooltip = 'Keeps to what the server let through 16 times out of 17. You cannot get further from your hitbox than one 100 stud jump, measured to where you would land,\nand the hitbox does not try the longer jump of up to 136 studs, which was put back two times in five in the lobby.\nWith it on, a gap wider than about 95 studs cannot be crossed.'
	})
	Leash = InfiniteFly:CreateSlider({
		Name = 'Leash',
		Min = 20,
		Max = 500,
		Default = 80,
		Suffix = 'studs',
		Tooltip = 'How far ahead of the hitbox you may get. Past it you fly at its pace, so a landing waits a few seconds at most.\n500 switches the leash off: you fly at full speed and the landing waits for as long as the hitbox needs.'
	})
	Notify = InfiniteFly:CreateToggle({
		Name = 'Notify',
		Default = true,
		Tooltip = 'Tells you when the hitbox waits at a gap, when a landing has to wait for it and when the server moved it back'
	})
end)


run(function()
	local Knockback
	local Power
	local Duration
	local Direction

	Knockback = vape.Categories.Blatant:CreateModule({
		Name = 'Knockback',
		Function = function(callback)
			if not callback then return end
			if entitylib.isAlive then
				local root = entitylib.character.RootPart
				local look = gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
				look = look.Magnitude > 0.01 and look.Unit or root.CFrame.LookVector
				local dir = Direction.Value == 'Forward' and (look + Vector3.new(0, 0.3, 0)).Unit
					or Direction.Value == 'Up' and Vector3.yAxis
					or (-look + Vector3.new(0, 0.35, 0)).Unit
				-- the push the game gives you when you are hit, aimed by you
				bedfight.VelocityUtils.Create(root, dir * Power.Value, Duration.Value)
				task.wait(Duration.Value)
				if root.Parent then
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
			if Knockback.Enabled then
				Knockback:Toggle()
			end
		end,
		Tooltip = 'Launches you once with the game\'s own knockback, then switches off.\nBind it to a key.'
	})
	Direction = Knockback:CreateDropdown({
		Name = 'Direction',
		List = {'Backward', 'Forward', 'Up'}
	})
	Power = Knockback:CreateSlider({
		Name = 'Power',
		Min = 10,
		Max = 300,
		Default = 80
	})
	Duration = Knockback:CreateSlider({
		Name = 'Duration',
		Min = 0.05,
		Max = 1,
		Default = 0.15,
		Decimal = 100,
		Suffix = 's'
	})
end)


run(function()
	local Killaura
	local Targets
	local AttackRange
	local AngleCheck
	local Mouse
	local Limit
	local Swing
	local Face
	local BoxColor
	local TargetColor
	local BoxAnimation
	local BoxStart
	local BoxEnd
	local SwingRange
	local AirChance
	local MaxTargets
	local Sort
	local ContinueSwing
	local AFK
	local GUICheck
	local ParticleTexture
	local ParticleBegin
	local ParticleEnd
	local ParticleSize
	local boxes, shown = {}, {}
	local particles, emitting = {}, {}
	local rng = Random.new()
	local lastInput = tick()
	local nextAnim, continueUntil = 0, 0
	local Custom
	local AttackSpeed
	local Reset
	local SwingOnly
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local AnimTween
	local Attacking = false
	local animId = 0
	local anims = vape.Libraries.auraanims
	-- never parented, it only carries the pose the animation is at
	local pose = Instance.new('Motor6D')
	-- where the game holds its first person arms
	local VIEW = CFrame.new(2.5, -3, -4) * CFrame.fromOrientation(math.rad(15), 0, 0)
	local tracks, viewTracks = {}, {}
	local nextSwing = 0
	local combo = 1
	-- the server counts the first hit that arrives once the sword's cooldown is over, so one goes out every frame
	local FASTEST, BURST = 1 / 60, 0.05
	local FLAT = Vector3.new(1, 0, 1)
	local burstUntil, turn = 0, 0
	local rolls = setmetatable({}, {__mode = 'k'})

	local function play(cache, animator, anim)
		if not (anim and animator) then return end
		if cache.Animator ~= animator then
			table.clear(cache)
			cache.Animator = animator
		end
		cache[anim] = cache[anim] or animator:LoadAnimation(anim)
		cache[anim]:Play()
	end

	-- one swing per hit sent, on the body and on the first person arms
	local function swing(sword)
		local data = bedfight.SwordsData[sword]
		if type(data) ~= 'table' then return end
		local set = data.Animations or bedfight.SwordsData.DefaultAnimation
		local anim = set and set.Swing
		if data.AnimationCombo and set then
			-- katanas and the like walk through a set of swings, the same way the game does
			anim = set[combo] or anim
			combo = (combo + 2) % data.AnimationCombo + 1
		end
		if not anim then return end
		play(tracks, entitylib.character.Humanoid:FindFirstChildOfClass('Animator'), anim.Animation)
		-- the arms only show the sword while it is the item in your hand
		if heldName() == sword then
			play(viewTracks, bedfight.ViewModelHandler.ViewModelAnimator, anim.ViewModel)
		end
	end

	local function swordCooldown(sword)
		local data = sword and bedfight.SwordsData[sword]
		return type(data) == 'table' and data.DamageCooldown or 0.3
	end

	-- how often the swing plays. the game itself never swings faster than the sword's AnimationCooldown
	local function swingPace(sword)
		if Custom.Enabled then
			local data = bedfight.SwordsData[sword]
			return math.max(AttackSpeed.Value, type(data) == 'table' and data.AnimationCooldown or 0.1)
		end
		return swordCooldown(sword)
	end

	-- how far a plain swing of this sword lands, root to root
	local function legitReach(sword)
		local data = sword and bedfight.SwordsData[sword]
		if type(data) ~= 'table' or not data.Range then return 10.5 end
		return data.Range + (data.HitboxSize and data.HitboxSize.Z / 2 or 2.5) + 2.75
	end

	-- a shop, chest, kit or settings screen of the game is up
	local function guiOpen()
		local gui = lplr:FindFirstChildOfClass('PlayerGui')
		for _, name in {'ItemShopGui', 'TeamUpgradesGui', 'TeamChestGui', 'SettingsGui', 'KitsGui', 'LockerGui'} do
			local screen = gui and gui:FindFirstChild(name)
			if screen and screen:IsA('LayerCollector') and screen.Enabled then
				return true
			end
		end
		return false
	end

	local function particleColor()
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleBegin.Hue, ParticleBegin.Sat, ParticleBegin.Value)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleEnd.Hue, ParticleEnd.Sat, ParticleEnd.Value))
		})
	end

	-- rolled once per cooldown, not for every hit sent
	local function airPass(ent, sword, now)
		if not (ent.Humanoid and ent.Humanoid.FloorMaterial == Enum.Material.Air) then return true end
		local roll = rolls[ent]
		if not roll then
			roll = {At = -1, Pass = true}
			rolls[ent] = roll
		end
		if now - roll.At >= swordCooldown(sword) then
			roll.At = now
			roll.Pass = rng:NextNumber(0, 100) <= AirChance:GetRandomValue()
		end
		return roll.Pass
	end

	local function getSwordName()
		if Limit.Enabled then
			local held = heldName()
			return held and type(bedfight.SwordsData[held]) == 'table' and held or nil
		end
		return store.tools.sword
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				lastInput = tick()
				Killaura:Clean(inputService.InputChanged:Connect(function()
					lastInput = tick()
				end))
				-- a click with a sword out is a swing of your own
				Killaura:Clean(inputService.InputBegan:Connect(function(input, processed)
					lastInput = tick()
					if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
					local held = heldName()
					if held and type(bedfight.SwordsData[held]) == 'table' then
						store.swung = tick()
					end
				end))

				if Animation.Enabled then
					local name = 'AetherAuraPose'
					runService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
						if pose.C0 == CFrame.identity then return end
						local handler = bedfight.ViewModelHandler
						local model = handler and handler.Visible and handler.CurrentViewModel
						local root = model and model.PrimaryPart
						if root then
							root.CFrame = gameCamera.CFrame * VIEW * pose.C0
						end
					end)
					Killaura:Clean(function()
						runService:UnbindFromRenderStep(name)
					end)
					animId += 1
					local id = animId
					task.spawn(function()
						local started = false
						repeat
							if Attacking then
								local first = not started
								started = true
								if AnimationMode.Value == 'Random' then
									anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
								end
								for _, v in anims[AnimationMode.Value] or anims.Normal do
									AnimTween = tweenService:Create(pose, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / math.max(AnimationSpeed.Value, 0.05), Enum.EasingStyle.Linear), {
										C0 = v.CFrame
									})
									AnimTween:Play()
									AnimTween.Completed:Wait()
									first = false
									if (not Killaura.Enabled) or (not Attacking) or id ~= animId then break end
								end
							elseif started then
								started = false
								AnimTween = tweenService:Create(pose, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
									C0 = CFrame.identity
								})
								AnimTween:Play()
							end

							if not started then
								task.wait(1 / 60)
							end
						until (not Killaura.Enabled) or (not Animation.Enabled) or id ~= animId
					end)
				end

				repeat
					local list = {}
					local fighting = false
					local sword = canFight() and getSwordName()
					local idle = not sword
						or (Mouse.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1))
						or (SwingOnly.Enabled and tick() - (store.swung or 0) > 0.35)
						or (AFK.Enabled and tick() - lastInput > 30)
						or (GUICheck.Enabled and guiOpen())
					if not idle then
						local root = entitylib.character.RootPart
						-- AntiHit brings the hitbox into reach for each hit by itself
						local managed = store.antiHit and tick() - (store.antiHitAt or 0) < 0.1
						-- the server measures from the hitbox, which may not be where the body is
						local from = managed and root.Position or realRoot().Position
						-- what you see of someone is a ping old by the time your hit reaches the server
						local lead = managed and 0 or math.clamp(lplr:GetNetworkPing() + 0.05, 0, 0.45)
						local reach = AttackRange.Value
						local plrs = store.targets({
							Range = math.max(SwingRange.Value, reach + lead * 40),
							Walls = Targets.Walls.Enabled,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = Sort.Value,
							Limit = 10
						})
						local facing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
						local hits = {}

						for _, v in plrs do
							local pos = v.RootPart.Position
							local delta = (pos - root.Position) * FLAT
							if AngleCheck.Value < 360 and delta.Magnitude > 0.5 and facing.Magnitude > 0.01 then
								local angle = math.acos(math.clamp(facing.Unit:Dot(delta.Unit), -1, 1))
								if angle > math.rad(AngleCheck.Value) / 2 then continue end
							end
							local close = (pos - from).Magnitude <= reach
							if lead > 0 then
								-- someone running at you is in reach for the server before they look it
								local ahead = pos + store.motion(v) * FLAT * lead
								close = close or (ahead - from).Magnitude <= reach
							end
							if not close and (pos - root.Position).Magnitude > SwingRange.Value then continue end
							table.insert(list, {Entity = v, Check = close and BoxColor or TargetColor})
							if close then
								table.insert(hits, v)
							end
							targetinfo.Targets[v] = tick() + 1
							if #list >= MaxTargets.Value then break end
						end

						if hits[1] then
							fighting = true
							store.melee = tick()
							store.meleeTarget, store.meleeRange = hits[1], reach
							if targetinfo.Focus then
								targetinfo.Focus[hits[1]] = tick() + 1
							end

							local now = os.clock()
							-- the server only has to hold the sword, the hotbar is left alone. it takes the
							-- switch and the hits in the order they were sent, so nothing waits for the switch to show
							equipServer(sword, 'Killaura')
							local wait = math.max(Custom.Enabled and AttackSpeed.Value or managed and swordCooldown(sword) or 0, FASTEST)
							store.meleeDue = tick() + nextSwing - now
							local fire = now < burstUntil
							-- AntiHit keeps the hitbox out of reach and brings it in for the hit
							if not fire and now >= nextSwing and (not store.strikeGate or store.strikeGate(hits[1])) then
								store.struckAt = tick()
								-- timed from the last slot, not from this frame, so no hit is lost to frame timing
								nextSwing = now - nextSwing > wait and now + wait or nextSwing + wait
								-- the hitbox is only down for a moment, and every frame of it gets a hit
								burstUntil = managed and now + BURST or 0
								fire = true
							end
							if fire then
								-- one hit a frame at most. several targets take turns unless hits are spaced out
								local all = managed or wait > 1 / 30
								turn += 1
								for i, v in hits do
									if (all or (turn - 1) % #hits + 1 == i) and airPass(v, sword, now) then
										fireRemote('SwordHit', v.Character, sword)
									end
								end
							end
						end

						if list[1] and Face.Enabled then
							local pos = list[1].Entity.RootPart.Position
							root.CFrame = CFrame.lookAt(root.Position, Vector3.new(pos.X, root.Position.Y, pos.Z))
						end
					end

					-- the swing runs on its own clock, so it also plays for someone who is only close
					if list[1] then
						continueUntil = tick() + ContinueSwing:GetRandomValue() / 1000
					end
					if sword and (list[1] or tick() < continueUntil) and tick() >= nextAnim and not Swing.Enabled and not SwingOnly.Enabled and entitylib.isAlive then
						nextAnim = tick() + swingPace(sword)
						swing(sword)
					end

					Attacking = list[1] ~= nil
					-- someone stepping out of reach for a moment does not cost a switch each way
					if not fighting and tick() - (store.melee or 0) > 0.25 then
						syncTool('Killaura')
					end
					for i, v in boxes do
						local entry = list[i]
						if entry and not shown[v] then
							v.Size = Vector3.zero
							tweenService:Create(v, TweenInfo.new(BoxStart.Value, Enum.EasingStyle[BoxAnimation.Value]), {Size = Vector3.new(3, 5, 3)}):Play()
						elseif shown[v] and not entry then
							tweenService:Create(v, TweenInfo.new(BoxEnd.Value, Enum.EasingStyle[BoxAnimation.Value]), {Size = Vector3.zero}):Play()
						end
						shown[v] = entry and true or nil
						if entry then
							v.Adornee = entry.Entity.RootPart
							v.Color3 = Color3.fromHSV(entry.Check.Hue, entry.Check.Sat, entry.Check.Value)
							v.Transparency = 1 - entry.Check.Opacity
						end
					end
					for i, v in particles do
						local entry = list[i]
						if entry then
							v.Position = entry.Entity.RootPart.Position
							if not emitting[v] then
								v.Parent = gameCamera
								emitting[v] = true
							end
						elseif emitting[v] then
							v.Parent = nil
							emitting[v] = nil
						end
					end

					runService.Heartbeat:Wait()
				until not Killaura.Enabled
			else
				Attacking = false
				if AnimTween then
					AnimTween:Cancel()
				end
				pose.C0 = CFrame.identity
				syncTool('Killaura')
				for _, v in boxes do
					v.Adornee = nil
					v.Size = Vector3.zero
					shown[v] = nil
				end
				for _, v in particles do
					v.Parent = nil
					emitting[v] = nil
				end
			end
		end,
		Tooltip = 'Attacks players around you without aiming at them.\nYour hotbar is never touched, so you can hold and switch items while it fights.'
	})
	Targets = Killaura:CreateTargets({Players = true})
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 22,
		Default = 14,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How close someone has to be before you start swinging. Hits are only sent inside Attack range'
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 14,
		Default = 14,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'As far as a normal swing can reach'
	})
	Killaura:CreateButton({
		Name = 'Sync to legit ranges',
		Function = function()
			local reach = math.clamp(math.floor(legitReach(store.tools.sword) * 10) / 10, 1, 14)
			SwingRange:SetValue(reach)
			AttackRange:SetValue(reach)
		end,
		Tooltip = 'Drops both ranges down to what a plain swing of your sword reaches'
	})
	AngleCheck = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	AirChance = Killaura:CreateTwoSlider({
		Name = 'Air hit chance',
		Min = 0,
		Max = 100,
		DefaultMin = 100,
		DefaultMax = 100,
		Tooltip = 'Chance to send a hit while the target is off the ground, rolled fresh between the two values on every hit'
	})
	MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 5,
		Default = 1,
		Tooltip = 'How many players are sent a hit with each swing'
	})
	Sort = Killaura:CreateDropdown({
		Name = 'Target Mode',
		List = store.sortList,
		Tooltip = 'Distance - the nearest\nCursor - nearest your cursor on screen\nAngle - nearest to where your camera looks\nLowest Health / Highest Health'
	})
	Custom = Killaura:CreateToggle({
		Name = 'Custom Attack Speed',
		Function = function(callback)
			AttackSpeed.Object.Visible = callback
			Reset.Object.Visible = callback
			nextSwing, nextAnim = 0, 0
		end,
		Tooltip = 'Sets how often hits are sent and how fast you swing.\nOff, a hit goes out every frame and the server counts the first one it can after each sword cooldown (0.3s for most swords), which is as many hits as it allows. Only switch this on to hit slower.'
	})
	AttackSpeed = Killaura:CreateSlider({
		Name = 'Time between hits',
		Min = 0,
		Max = 1,
		Default = 0.3,
		Decimal = 100,
		Suffix = 's',
		Darker = true,
		Visible = false,
		Function = function()
			nextSwing, nextAnim = 0, 0
		end,
		Tooltip = '0 sends a hit every frame, the same as with Custom Attack Speed off, and swings as fast as the game allows. 1 is one hit and one swing a second'
	})
	Reset = Killaura:CreateButton({
		Name = 'Reset to default',
		Function = function()
			AttackSpeed:SetValue(swordCooldown(store.tools.sword))
		end,
		Darker = true,
		Visible = false,
		Tooltip = 'Back to the cooldown of the sword you carry'
	})
	ContinueSwing = Killaura:CreateTwoSlider({
		Name = 'Continue swing',
		Min = 0,
		Max = 1000,
		DefaultMin = 0,
		DefaultMax = 0,
		Tooltip = 'Keeps playing the swing animation for a random amount of ms after you stop targeting'
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	AFK = Killaura:CreateToggle({
		Name = 'AFK check',
		Tooltip = 'Stops attacking once you have not touched your mouse or keyboard for 30 seconds'
	})
	GUICheck = Killaura:CreateToggle({
		Name = 'GUI check',
		Tooltip = 'Stops attacking while a shop, chest, kit or settings screen is open'
	})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only attacks while you hold a sword'
	})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	SwingOnly = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while swinging manually'
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
		end,
		Tooltip = 'Animates your first person arms while attacking'
	})
	local animnames = {}
	for name in anims do
		if name ~= 'Normal' then
			table.insert(animnames, name)
		end
	end
	table.sort(animnames)
	table.insert(animnames, 1, 'Normal')
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
	Face = Killaura:CreateToggle({
		Name = 'Face target',
		Tooltip = 'Turns your character toward the target'
	})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxColor.Object.Visible = callback
			TargetColor.Object.Visible = callback
			BoxAnimation.Object.Visible = callback
			BoxStart.Object.Visible = callback
			BoxEnd.Object.Visible = callback
			if callback then
				for i = 1, 5 do
					local box = Instance.new('BoxHandleAdornment')
					box.AlwaysOnTop = true
					box.Size = Vector3.zero
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					boxes[i] = box
				end
			else
				for _, v in boxes do
					v:Destroy()
				end
				table.clear(boxes)
				table.clear(shown)
			end
		end
	})
	local easings = {'Bounce'}
	for _, v in Enum.EasingStyle:GetEnumItems() do
		if not table.find(easings, v.Name) then
			table.insert(easings, v.Name)
		end
	end
	BoxAnimation = Killaura:CreateDropdown({
		Name = 'Box Animation',
		List = easings,
		Darker = true,
		Visible = false
	})
	BoxStart = Killaura:CreateSlider({
		Name = 'Start Animation Speed',
		Min = 0,
		Max = 10,
		Default = 0.9,
		Decimal = 30,
		Darker = true,
		Visible = false
	})
	BoxEnd = Killaura:CreateSlider({
		Name = 'End Animation Speed',
		Min = 0,
		Max = 10,
		Default = 1.4,
		Decimal = 30,
		Darker = true,
		Visible = false
	})
	TargetColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleBegin.Object.Visible = callback
			ParticleEnd.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 5 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.Transparency = 1
					local emitter = Instance.new('ParticleEmitter')
					emitter.Brightness = 1.5
					emitter.Size = NumberSequence.new(ParticleSize.Value)
					emitter.Shape = Enum.ParticleEmitterShape.Sphere
					emitter.Texture = ParticleTexture.Value
					emitter.Transparency = NumberSequence.new(0)
					emitter.Lifetime = NumberRange.new(0.4)
					emitter.Speed = NumberRange.new(16)
					emitter.Rate = 128
					emitter.Drag = 16
					emitter.ShapePartial = 1
					emitter.Color = particleColor()
					emitter.Parent = part
					particles[i] = part
				end
			else
				for _, v in particles do
					v:Destroy()
				end
				table.clear(particles)
				table.clear(emitting)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Function = function()
			for _, v in particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Default = 'rbxassetid://14736249347',
		Darker = true,
		Visible = false
	})
	ParticleBegin = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function()
			if not ParticleEnd then return end
			for _, v in particles do
				v.ParticleEmitter.Color = particleColor()
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleEnd = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function()
			for _, v in particles do
				v.ParticleEmitter.Color = particleColor()
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Function = function(val)
			for _, v in particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Default = 0.2,
		Darker = true,
		Visible = false
	})
end)


run(function()
	local LongJump
	local Value
	local Duration
	local Slope
	local VoidCheck
	local readyAt = 0
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	-- a landing may be this far under the path. falling further than 20 studs costs health
	local MAX_FALL = 30

	local function ground(point)
		return workspace:Raycast(point + Vector3.new(0, 3, 0), Vector3.new(0, -(MAX_FALL + 3), 0), rayCheck) ~= nil
	end

	-- how far the dash may go: up to the first wall, and with Void check only as far as the last
	-- spot on the way that has ground under it and under the two studs before it
	local function plan(start, dir, flat, distance)
		local wall = workspace:Raycast(start, dir * (distance + 2), rayCheck)
		if wall then
			distance = math.max(wall.Distance - 2, 0)
		end
		if not VoidCheck.Enabled then
			return distance, wall ~= nil
		end
		local travelled = distance
		while travelled >= 4 do
			local point = start + dir * travelled
			if ground(point) and ground(point - flat * 2) then
				return travelled, wall ~= nil, travelled < distance - 0.5
			end
			travelled -= 2
		end
		return nil
	end

	LongJump = vape.Categories.Blatant:CreateModule({
		Name = 'LongJump',
		Function = function(callback)
			if callback then
				if tick() < readyAt then
					notif('LongJump', string.format('Ready in %.1fs.', readyAt - tick()), 2)
					LongJump:Toggle()
					return
				end
				if not entitylib.isAlive then
					LongJump:Toggle()
					return
				end

				local look = gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
				if look.Magnitude < 0.01 then
					look = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
				end
				local flat = look.Unit
				local angle = math.rad(Slope.Value)
				local dir = flat * math.cos(angle) + Vector3.new(0, math.sin(angle), 0)
				local startPos = entitylib.character.RootPart.Position
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, workspace:FindFirstChild('PlayersContainer')}

				-- decided once, before moving. checking on the way only saw the void when it was already underneath
				local distance, walled, shortened = plan(startPos, dir, flat, Value.Value * Duration.Value)
				if not distance or distance < 1 then
					notif('LongJump', distance and 'A wall is in the way.' or 'Nothing to land on that way.', 3, 'warning')
					LongJump:Toggle()
					return
				end
				local reason = shortened and 'Stopped over the last ground' or walled and 'Stopped at a wall' or 'Ended'
				local travelled = 0
				store.dashOn = true

				LongJump:Clean(runService.PreSimulation:Connect(function(dt)
					if not entitylib.isAlive then
						LongJump:Toggle()
						return
					end
					local root = entitylib.character.RootPart
					local length = math.min(Value.Value * dt, distance - travelled)
					local step = dir * length
					-- something that moved into the way since the plan was made
					if workspace:Raycast(root.Position, step + dir * 2, rayCheck) then
						reason = 'Hit a wall'
						LongJump:Toggle()
						return
					end
					travelled += length
					root.CFrame += step
					-- the step is the whole move, carried as velocity too it went twice as far
					root.AssemblyLinearVelocity = Vector3.zero
					if travelled >= distance - 0.01 then
						LongJump:Toggle()
					end
				end))

				LongJump:Clean(function()
					store.dashOn = nil
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						root.AssemblyLinearVelocity = Vector3.zero
						-- further flights wait longer before the next one
						local dist = ((root.Position - startPos) * Vector3.new(1, 0, 1)).Magnitude
						readyAt = tick() + math.clamp((dist / 50) ^ 2.5, 1, 3)
					end
					notif('LongJump', reason..'.', 2)
				end)
			end
		end,
		Tooltip = 'One fast dash the way your camera faces, exactly Speed x Duration long.\nSwitches itself off when the dash is over.'
	})
	Value = LongJump:CreateSlider({
		Name = 'Speed',
		Min = 20,
		Max = 300,
		Default = 300,
		Suffix = 'studs'
	})
	Duration = LongJump:CreateSlider({
		Name = 'Duration',
		Min = 0.1,
		Max = 2,
		Default = 0.2,
		Decimal = 100,
		Suffix = 's'
	})
	Slope = LongJump:CreateSlider({
		Name = 'Slope angle',
		Min = 0,
		Max = 10,
		Default = 5,
		Suffix = 'deg'
	})
	VoidCheck = LongJump:CreateToggle({
		Name = 'Void check',
		Tooltip = 'Ends the dash over the last ground on the way, and does not start when there is none.\nA landing counts when there is ground within 30 studs under it.'
	})
end)


run(function()
	local NoSlowdown

	-- the speed the game would give you with nothing drawn
	local function normalSpeed(hum)
		local sprint = bedfight.ButtonProperties.new('Sprint')
		local speed = (hum:GetAttribute('DefaultSpeed') or 16) + (hum:GetAttribute('SpeedBoost') or 0) + (sprint.Active.Value and 4 or 0)
		-- the game flags 25 and over
		return math.min(speed, 24)
	end

	NoSlowdown = vape.Categories.Blatant:CreateModule({
		Name = 'NoSlowdown',
		Function = function(callback)
			if callback then
				local function hook(ent)
					local hum = ent.Humanoid
					NoSlowdown:Clean(hum:GetPropertyChangedSignal('WalkSpeed'):Connect(function()
						if hum:GetAttribute('SpeedLock') and hum.WalkSpeed < normalSpeed(hum) then
							hum.WalkSpeed = normalSpeed(hum)
						end
					end))
				end
				NoSlowdown:Clean(entitylib.Events.LocalAdded:Connect(hook))
				if entitylib.isAlive then
					hook(entitylib.character)
				end
			end
		end,
		Tooltip = 'Keeps your normal speed while a bow or crossbow is drawn'
	})
end)


run(function()
	local ProjectileAimbot
	local Targets
	local Sort
	local TargetPart
	local FOV
	local Range
	local Horizontal
	local Vertical
	local AutoCharge
	local OtherProjectiles
	local Blacklist
	local ring
	local old, wrapper
	local oldFire, fireWrapper

	-- bows and crossbows always, the rest only when asked for and not on the blacklist
	local function wanted(name)
		for _, v in Blacklist.ListEnabled do
			if v:lower() == name:lower() then
				return false
			end
		end
		return OtherProjectiles.Enabled or name == 'Bow' or name == 'Crossbow'
	end

	local function solve(self, root, projData)
		if not (entitylib.isAlive and projData and projData.Speed and self.Charge and wanted(self.Name)) then return end
		local origin = bedfight.Ranged.GetFireOrigin(root, self.Data.Offset)
		local ent = store.targets({
			Origin = origin,
			Range = Range.Value,
			FOV = FOV.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Walls = Targets.Walls.Enabled,
			Sort = Sort.Value
		})[1]
		if not ent then return end

		-- a full draw flies at the top of the weapon's speed range
		local charge = AutoCharge.Enabled and 1 or self.Charge.Value
		local speed = math.map(charge, 0, 1, projData.Speed.Min, projData.Speed.Max)
		local part = ent[TargetPart.Value] or ent.RootPart
		local scale = {Horizontal = Horizontal.Value, Vertical = Vertical.Value}
		local point = store.aimPoint(origin, speed, math.abs(projData.Gravity.Y), ent, part, scale)
		if not point or (point - origin).Magnitude < 0.1 then return end
		-- firing turns the camera onto the shot, which moves the point it leaves from a little
		origin = root.Position + CFrame.lookAlong(gameCamera.CFrame.Position, (point - origin).Unit):VectorToWorldSpace(self.Data.Offset)
		point = store.aimPoint(origin, speed, math.abs(projData.Gravity.Y), ent, part, scale)
		if not point or (point - origin).Magnitude < 0.1 then return end
		targetinfo.Targets[ent] = tick() + 1
		return (point - origin).Unit * speed
	end

	ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		Function = function(callback)
			ring.Update(callback)
			if callback then
				if wrapper then return end
				old = bedfight.Ranged.UpdateBeam
				-- the game aims from the cursor here every frame while a shot is drawn
				wrapper = function(self, root, projData, ...)
					local data = self.TrajectoryData
					-- a failed solve must never stop the game drawing its own line
					local ok, velocity = pcall(function()
						return ProjectileAimbot.Enabled and data and solve(self, root, projData)
					end)
					if not (ok and velocity) then
						if data then
							rawset(data, 'Aimed', nil)
						end
						return old(self, root, projData, ...)
					end

					-- the game sets the cursor's direction and then draws, so the bent shot is put in between
					local curve = data.CurveBeam
					rawset(data, 'CurveBeam', function(traj, ...)
						traj.Velocity = velocity
						return curve(traj, ...)
					end)
					local results = table.pack(pcall(old, self, root, projData, ...))
					rawset(data, 'CurveBeam', nil)
					if not results[1] then
						error(results[2], 0)
					end
					data.Velocity = velocity
					rawset(data, 'Aimed', velocity)
					return table.unpack(results, 2, results.n)
				end
				bedfight.Ranged.UpdateBeam = wrapper

				oldFire = bedfight.Ranged.Fire
				-- the shot leaves from a point that turns with the camera, and the camera is sent along with it.
				-- so for the instant of firing the camera looks where the shot goes
				fireWrapper = function(self, ...)
					local data = self.TrajectoryData
					local velocity = ProjectileAimbot.Enabled and self.Activated and data and data.Aimed
					if not velocity then
						return oldFire(self, ...)
					end
					local real = gameCamera.CFrame
					gameCamera.CFrame = CFrame.lookAlong(real.Position, velocity.Unit)
					local results = table.pack(pcall(oldFire, self, ...))
					gameCamera.CFrame = real
					if not results[1] then
						error(results[2], 0)
					end
					return table.unpack(results, 2, results.n)
				end
				bedfight.Ranged.Fire = fireWrapper
			else
				if wrapper and bedfight.Ranged.UpdateBeam == wrapper then
					bedfight.Ranged.UpdateBeam = old
					old, wrapper = nil, nil
				end
				if fireWrapper and bedfight.Ranged.Fire == fireWrapper then
					bedfight.Ranged.Fire = oldFire
					oldFire, fireWrapper = nil, nil
				end
			end
		end,
		Tooltip = 'Bends your bow, crossbow and fireball shots onto a player inside the FOV.\nThe aim line shows where the shot will really go.'
	})
	Targets = ProjectileAimbot:CreateTargets({
		Players = true,
		Walls = true
	})
	Sort = ProjectileAimbot:CreateDropdown({
		Name = 'Target mode',
		List = store.sortList,
		Default = 'Cursor',
		Tooltip = 'Distance - the nearest\nCursor - nearest your cursor on screen\nAngle - nearest to where your camera looks\nLowest Health / Highest Health'
	})
	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = ProjectileAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 250,
		Tooltip = 'How far from your cursor a player can be, in pixels'
	})
	Range = ProjectileAimbot:CreateSlider({
		Name = 'Range',
		Min = 30,
		Max = 500,
		Default = 500,
		Suffix = 'studs',
		Tooltip = 'Only targets players within this distance'
	})
	ring = store.ring(ProjectileAimbot, 'BFPAFOVCircle', 'Draws the range a target is caught at, centred on the cursor')
	ring.Radius = function()
		return FOV.Value
	end
	Horizontal = ProjectileAimbot:CreateSlider({
		Name = 'Horizontal prediction',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 100,
		Tooltip = 'Scales how far ahead of the target you aim sideways'
	})
	Vertical = ProjectileAimbot:CreateSlider({
		Name = 'Vertical prediction',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 100,
		Tooltip = 'Scales how far ahead of the target you aim while it rises or falls'
	})
	AutoCharge = ProjectileAimbot:CreateToggle({
		Name = 'Auto Charge',
		Tooltip = 'Aims and fires a bow at its full speed however long you drew it.\nWhether the server accepts a full speed shot from a short draw has not been checked'
	})
	OtherProjectiles = ProjectileAimbot:CreateToggle({
		Name = 'Other Projectiles',
		Default = true,
		Function = function(callback)
			if Blacklist then
				Blacklist.Object.Visible = callback
			end
		end,
		Tooltip = 'Also bends fireballs, hotdogs and anything else that is not a bow or a crossbow'
	})
	Blacklist = ProjectileAimbot:CreateTextList({
		Name = 'Blacklist',
		Darker = true,
		Default = {'Teleorb'},
		Placeholder = 'weapon name',
		Tooltip = 'Weapons that are never bent'
	})
end)


run(function()
	local ProjectileAura
	local Targets
	local Range
	local List
	local Delay
	local Sort
	local Part
	local FOV
	local ring
	local nextShot = {}

	-- a ranged weapon you own together with the first ammo you have for it
	local function getWeapon()
		for name in store.inventory do
			local data = bedfight.RangedData[name]
			if type(data) == 'table' and table.find(List.ListEnabled, name) and (nextShot[name] or 0) < tick() then
				for _, projectile in data.ProjectileOrder or {data.Projectile} do
					local meta = bedfight.ProjectilesData[projectile]
					if meta and (store.inventory[meta.Projectile or projectile] or 0) > 0 then
						return name, data, projectile, meta
					end
				end
			end
		end
	end

	-- the same local projectile the game makes for a shot. its id pairs the shot with the server's
	local function launch(projectile, meta, origin, velocity)
		local container = workspace:FindFirstChild('ProjectilesContainer')
		if not container then return nil end
		local shot = bedfight.ProjectilesController.new(nil, velocity, meta)
		shot:AddProjectile(meta.Projectile or projectile)
		shot.ProjectileRoot.CFrame = CFrame.lookAlong(origin, velocity.Unit)
		shot.UpdatedVelocity = velocity
		shot.Projectile.Parent = container
		return shot:Play()
	end

	ProjectileAura = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAura',
		Function = function(callback)
			ring.Update(callback)
			if callback then
				local switched = false
				repeat
					local fired = false
					-- swords come first, both need the server to hold their own item
					if canFight() and tick() - (store.melee or 0) > 0.5 then
						local weapon, data, projectile, meta = getWeapon()
						local ent = weapon and store.targets({
							Range = Range.Value,
							FOV = ring.Show.Enabled and FOV.Value or nil,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Walls = Targets.Walls.Enabled,
							Sort = Sort.Value
						})[1]

						if ent then
							-- the server launches from the root it follows, wherever that is
							local root = realRoot()
							local origin = bedfight.Ranged.GetFireOrigin(root, data.Offset)
							local speed = meta.Speed.Max
							local point = store.aimPoint(origin, speed, math.abs(meta.Gravity.Y), ent, ent[Part.Value] or ent.RootPart)

							if point and (point - origin).Magnitude > 1 then
								fired = true
								switched = true
								targetinfo.Targets[ent] = tick() + 1
								if equipServer(weapon, 'ProjectileAura') or (store.sentAt and tick() - store.sentAt > 0.6) then
									local velocity = (point - origin).Unit * speed
									local ok, id = pcall(launch, projectile, meta, origin, velocity)
									if ok and id then
										nextShot[weapon] = tick() + math.max(data.Cooldown or 0, Delay.Value)
										fireRemote('ShootProjectile', id, weapon, velocity.Unit, velocity, CFrame.lookAt(gameCamera.CFrame.Position, point))
									end
								end
							end
						end
					end

					if switched and not fired then
						switched = false
						syncTool('ProjectileAura')
					end
					task.wait(0.05)
				until not ProjectileAura.Enabled
			else
				syncTool('ProjectileAura')
			end
		end,
		Tooltip = 'Shoots players around you with the bows and fireballs you carry.\nShots leave fully charged and your hotbar is not touched.'
	})
	Targets = ProjectileAura:CreateTargets({
		Players = true,
		Walls = true
	})
	Sort = ProjectileAura:CreateDropdown({
		Name = 'Target mode',
		List = store.sortList,
		Tooltip = 'Distance - the nearest\nCursor - nearest your cursor on screen\nAngle - nearest to where your camera looks\nLowest Health / Highest Health'
	})
	Part = ProjectileAura:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'},
		Tooltip = 'Where on the body the shot is aimed'
	})
	List = ProjectileAura:CreateTextList({
		Name = 'Weapons',
		Default = {'Bow', 'Crossbow'},
		Tooltip = 'Bow, Crossbow, Fireball, Teleorb or Hotdog'
	})
	Delay = ProjectileAura:CreateSlider({
		Name = 'Fire delay',
		Min = 0.2,
		Max = 3,
		Default = 0.8,
		Decimal = 10,
		Suffix = 's',
		Tooltip = 'Never shorter than the weapon\'s own cooldown'
	})
	Range = ProjectileAura:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 150,
		Default = 80,
		Suffix = 'studs'
	})
	ring = store.ring(ProjectileAura, 'BFPAuraFOVCircle', 'Draws the FOV ring and only shoots targets inside it')
	ring.Radius = function()
		return FOV.Value
	end
	FOV = ProjectileAura:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 300,
		Darker = true,
		Visible = function()
			return ring.Show.Enabled
		end,
		Tooltip = 'How far from your cursor a player can be, in pixels'
	})
end)


run(function()
	local Speed
	local Mode
	local Value
	local AutoJump
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			if callback then
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					if not entitylib.isAlive or store.flyOn or store.dashOn then return end
					local hum, root = entitylib.character.Humanoid, entitylib.character.RootPart
					local dir = hum.MoveDirection
					if dir.Magnitude < 0.05 or hum:GetState() == Enum.HumanoidStateType.Climbing then return end

					if Mode.Value == 'CFrame' then
						-- the walk covers WalkSpeed, the rest is added on top
						local extra = dir * math.max(Value.Value - hum.WalkSpeed, 0) * dt
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
						if not workspace:Raycast(root.Position, extra + dir * 1.5, rayCheck) then
							root.CFrame += extra
						end
					else
						root.AssemblyLinearVelocity = Vector3.new(dir.X * Value.Value, root.AssemblyLinearVelocity.Y, dir.Z * Value.Value)
					end

					if AutoJump.Enabled and hum.FloorMaterial ~= Enum.Material.Air then
						hum:ChangeState(Enum.HumanoidStateType.Jumping)
					end
				end))
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Moves you faster. WalkSpeed is never changed, the game checks it.'
	})
	Mode = Speed:CreateDropdown({
		Name = 'Mode',
		List = {'Velocity', 'CFrame'},
		Tooltip = 'Velocity - sets your speed\nCFrame - moves the root on top of walking'
	})
	Value = Speed:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 30,
		Default = 24,
		Suffix = 'studs',
		Tooltip = '24 ran without the server stepping in. At 32 it pulled the character back after five seconds, and at 45 after less than two.'
	})
	AutoJump = Speed:CreateToggle({Name = 'AutoJump'})
end)


run(function()
	local AutoClicker
	local Attack
	local CPS
	local Place
	local BlockCPS = {Object = {}}

	local function canClick()
		if inputService:GetFocusedTextBox() then return false end
		local menu = vape.gui:FindFirstChild('ScaledGui')
		menu = menu and menu:FindFirstChild('ClickGui')
		return not (menu and menu.Visible)
	end

	-- what the held item is to the game, a sword, a block or neither
	local function heldKind()
		local name = heldName()
		if not name then return nil end
		if type(bedfight.SwordsData[name]) == 'table' then
			return Attack.Enabled and 'sword' or nil
		end
		local data = bedfight.ItemsData and bedfight.ItemsData[name]
		if data and data.Class == 'Blocks' then
			return Place.Enabled and 'block' or nil
		end
		return nil
	end

	AutoClicker = vape.Categories.Combat:CreateModule({
		Name = 'AutoClicker',
		Function = function(callback)
			if callback then
				local nextClick
				repeat
					local kind = entitylib.isAlive and inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and canClick() and heldKind()
					if kind then
						local now = os.clock()
						local cps = math.max((kind == 'block' and BlockCPS or CPS):GetRandomValue(), 1)
						if not nextClick then
							-- the press itself is the game's own first click
							nextClick = now + 1 / cps
						elseif now >= nextClick then
							nextClick = now + 1 / cps
							local signals = bedfight.Signals
							if kind == 'sword' then
								store.swung = tick()
								if signals and signals.MobileSword then
									signals.MobileSword:Fire()
								end
							elseif signals and signals.MobileBuild then
								signals.MobileBuild:Fire()
							end
						end
					else
						nextClick = nil
					end
					task.wait()
				until not AutoClicker.Enabled
			end
		end,
		Tooltip = 'Hold attack button to automatically click'
	})
	Attack = AutoClicker:CreateToggle({
		Name = 'Attack',
		Default = true,
		Function = function(callback)
			if CPS and CPS.Object then
				CPS.Object.Visible = callback
			end
		end,
		Tooltip = 'Swings your sword while the attack button is held'
	})
	CPS = AutoClicker:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 20,
		DefaultMin = 9,
		DefaultMax = 9
	})
	Place = AutoClicker:CreateToggle({
		Name = 'Place Blocks',
		Function = function(callback)
			if BlockCPS.Object then
				BlockCPS.Object.Visible = callback
			end
		end,
		Tooltip = 'Places through the game\'s build button, which builds where you are walking'
	})
	BlockCPS = AutoClicker:CreateTwoSlider({
		Name = 'Block CPS',
		Min = 1,
		Max = 20,
		DefaultMin = 12,
		DefaultMax = 12,
		Darker = true,
		Visible = false
	})
end)


run(function()
	local Reach
	local Range
	local Width
	local Place
	local PlaceRange
	local Break
	local BreakRange
	local original = {}
	local placeOld
	local mineOld = {}

	local function writable(data)
		if not table.isfrozen(data) then return true end
		if not setreadonly then return false end
		setreadonly(data, false)
		return true
	end

	local function apply(enabled)
		for name, data in bedfight.SwordsData do
			if type(data) ~= 'table' or not (data.Range and data.HitboxSize) then continue end
			if not writable(data) then continue end
			original[name] = original[name] or {data.Range, data.HitboxSize}
			local range, size = original[name][1], original[name][2]
			if enabled then
				-- the game puts its hit box one Range ahead, so half the reach each way covers all of it
				data.Range = Range.Value / 2
				data.HitboxSize = Vector3.new(math.max(size.X, Width.Value), math.max(size.Y, Width.Value), Range.Value)
			else
				data.Range, data.HitboxSize = range, size
			end
		end

		-- tools pick a new block range up the next time they are selected
		local place = bedfight.BlocksData and bedfight.BlocksData.Default
		if type(place) == 'table' and place.Range and writable(place) then
			placeOld = placeOld or place.Range
			place.Range = enabled and Place.Enabled and PlaceRange.Value or placeOld
		end
		for name, data in bedfight.MiningData do
			if type(data) == 'table' and data.Range and writable(data) then
				mineOld[name] = mineOld[name] or data.Range
				data.Range = enabled and Break.Enabled and BreakRange.Value or mineOld[name]
			end
		end
	end

	local function refresh()
		if Reach.Enabled and BreakRange then
			apply(true)
		end
	end

	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			apply(callback)
		end,
		Tooltip = 'Makes your own swings hit from further away, and lets you place and mine blocks further away.\nTools pick a new block range up the next time you select them.'
	})
	Range = Reach:CreateSlider({
		Name = 'Range',
		Min = 10.5,
		Max = 14,
		Default = 14,
		Decimal = 10,
		Suffix = 'studs',
		Function = refresh,
		Tooltip = 'How far ahead a swing looks for a player. The game\'s own is 10.5, and 14 is as far as a swing can connect.'
	})
	Width = Reach:CreateSlider({
		Name = 'Width',
		Min = 4,
		Max = 12,
		Default = 4,
		Decimal = 10,
		Suffix = 'studs',
		Function = refresh,
		Tooltip = 'How far off your crosshair a swing still lands'
	})
	Place = Reach:CreateToggle({
		Name = 'Place',
		Function = function(callback)
			if PlaceRange and PlaceRange.Object then
				PlaceRange.Object.Visible = callback
			end
			refresh()
		end,
		Tooltip = 'Lets you place blocks further away than the game\'s 18 studs'
	})
	PlaceRange = Reach:CreateSlider({
		Name = 'Place range',
		Min = 18,
		Max = 200,
		Default = 50,
		Suffix = 'studs',
		Darker = true,
		Visible = false,
		Function = refresh
	})
	Break = Reach:CreateToggle({
		Name = 'Break',
		Function = function(callback)
			if BreakRange and BreakRange.Object then
				BreakRange.Object.Visible = callback
			end
			refresh()
		end,
		Tooltip = 'Gives pickaxes and axes a longer mining range than the game\'s 18 studs'
	})
	BreakRange = Reach:CreateSlider({
		Name = 'Break range',
		Min = 18,
		Max = 200,
		Default = 50,
		Suffix = 'studs',
		Darker = true,
		Visible = false,
		Function = refresh
	})
end)


run(function()
	local SilentAim
	local Targets
	local TargetPart
	local Sort
	local Prediction
	local FOV
	local Range
	local HeadChance
	local TorsoChance
	local OtherProjectiles
	local Blacklist
	local AutoCharge
	local ChargePercent
	local Debug
	local ring
	local oldFire, wrapper
	local rng = Random.new()
	-- the game's own Fire, before any module wraps it. it reaches the remote through one of its upvalues
	local gameFire = bedfight.Ranged.Fire
	local slot

	local function upvalues(fn)
		if debug.getupvalues then
			local ok, list = pcall(debug.getupvalues, fn)
			if ok and type(list) == 'table' then
				return list
			end
		end
		local list = {}
		for i = 1, 40 do
			local ok, value = pcall(debug.getupvalue, fn, i)
			if not ok then break end
			list[i] = value
		end
		return list
	end

	-- the slot is found by what it holds. a Fire that something already wrapped is looked through
	local function findSlot(fn, depth)
		local folder = remotes.ShootProjectile and remotes.ShootProjectile.Parent
		if not (folder and debug.setupvalue and debug.getupvalue and type(fn) == 'function') then return nil end
		local list = upvalues(fn)
		for i, v in list do
			if v == folder then
				gameFire = fn
				return i
			end
		end
		if depth < 3 then
			for _, v in list do
				if type(v) == 'function' then
					local found = findSlot(v, depth + 1)
					if found then
						return found
					end
				end
			end
		end
		return nil
	end

	local function report(text)
		if Debug.Enabled then
			notif('SilentAim', text, 4)
		end
	end

	local function wanted(name)
		if name == 'Bow' or name == 'Crossbow' then return true end
		if not OtherProjectiles.Enabled then return false end
		for _, v in Blacklist.ListEnabled do
			if v:lower() == name:lower() then
				return false
			end
		end
		return true
	end

	local function pickPart(ent)
		local mode = TargetPart.Value
		if mode == 'Head' then
			return ent.Head or ent.RootPart
		elseif mode == 'Closest' then
			-- whichever of the two is nearer your cursor
			local fov = vape.Libraries.fovcircle
			local head = ent.Head
			if fov and head then
				local _, toHead = fov.ContainsPoint(head.Position, math.huge)
				local _, toRoot = fov.ContainsPoint(ent.RootPart.Position, math.huge)
				return toHead < toRoot and head or ent.RootPart
			end
		elseif mode == 'Randomize' then
			local roll = rng:NextNumber(0, 100)
			if roll < HeadChance.Value then
				return ent.Head or ent.RootPart
			elseif roll < HeadChance.Value + TorsoChance.Value then
				return ent.Character:FindFirstChild('UpperTorso') or ent.RootPart
			end
		end
		return ent.RootPart
	end

	-- what the server is told instead: a shot from the same place that meets the target
	local function plan(self)
		local data = self.TrajectoryData
		if not (entitylib.isAlive and self.Activated and data and data.Velocity) then return nil end
		if rawget(data, 'Aimed') then return nil end
		if not wanted(self.Name) then
			report(self.Name..' is not a weapon SilentAim bends')
			return nil
		end
		local meta = bedfight.ProjectilesData[data.ProjectileName] or data.ProjectileData
		if not (meta and meta.Speed and meta.Gravity) then return nil end

		-- the server launches from the root it follows
		local root = realRoot()
		local offset = self.Data.Offset
		local eye = gameCamera.CFrame.Position
		local origin = root.Position + gameCamera.CFrame:VectorToWorldSpace(offset)
		local ent = store.targets({
			Origin = origin,
			Range = Range.Value,
			FOV = FOV.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Walls = Targets.Walls.Enabled,
			Sort = Sort.Value
		})[1]
		if not ent then
			report('Nobody inside the FOV, the shot went where you aimed')
			return nil
		end

		local speed = data.Velocity.Magnitude
		if AutoCharge.Enabled then
			local range = self.Data.ChargeRange
			local charge = math.clamp(ChargePercent.Value / 100, range and range.Min or 0, range and range.Max or 1)
			speed = math.map(charge, 0, 1, meta.Speed.Min, meta.Speed.Max)
		end
		if speed < 1 then return nil end

		local part = pickPart(ent)
		local gravity = math.abs(meta.Gravity.Y)
		local scale = {Horizontal = Prediction.Value, Vertical = Prediction.Value}
		local point = store.aimPoint(origin, speed, gravity, ent, part, scale)
		if not point or (point - origin).Magnitude < 0.1 then return nil end
		-- the camera is sent along and the shot leaves from a point that turns with it
		origin = root.Position + CFrame.lookAlong(eye, (point - origin).Unit):VectorToWorldSpace(offset)
		point = store.aimPoint(origin, speed, gravity, ent, part, scale)
		if not point or (point - origin).Magnitude < 0.1 then return nil end

		local velocity = (point - origin).Unit * speed
		targetinfo.Targets[ent] = tick() + 1
		report('Sent to '..(ent.Player and ent.Player.Name or ent.Character.Name)..' ('..part.Name..', '..math.floor((point - origin).Magnitude)..' studs)')
		return velocity, CFrame.lookAlong(eye, velocity.Unit)
	end

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			ring.Update(callback)
			if callback then
				slot = slot or findSlot(gameFire, 0)
				if not slot then
					notif('SilentAim', 'Your executor cannot reach the game\'s shoot call (no debug.setupvalue), so SilentAim cannot work here. ProjectileAimbot still does.', 10, 'alert')
					task.defer(function()
						if SilentAim.Enabled then
							SilentAim:Toggle()
						end
					end)
					return
				end
				if wrapper then return end
				oldFire = bedfight.Ranged.Fire
				wrapper = function(self, ...)
					local ok, velocity, camera
					if SilentAim.Enabled then
						ok, velocity, camera = pcall(plan, self)
					end
					if not (ok and velocity) then
						return oldFire(self, ...)
					end

					-- only the values in the request change. the arrow on your screen flies where you aimed
					local folder = remotes.ShootProjectile.Parent
					local shoot = remotes.ShootProjectile
					local restored = false
					local function restore()
						if not restored then
							restored = true
							debug.setupvalue(gameFire, slot, folder)
						end
					end
					debug.setupvalue(gameFire, slot, setmetatable({
						ShootProjectile = {
							FireServer = function(_, id, name)
								restore()
								shoot:FireServer(id, name, velocity.Unit, velocity, camera)
							end
						}
					}, {
						__index = function(_, key)
							return folder[key]
						end
					}))
					local results = table.pack(pcall(oldFire, self, ...))
					restore()
					if not results[1] then
						error(results[2], 0)
					end
					return table.unpack(results, 2, results.n)
				end
				bedfight.Ranged.Fire = wrapper
			elseif wrapper and bedfight.Ranged.Fire == wrapper then
				bedfight.Ranged.Fire = oldFire
				oldFire, wrapper = nil, nil
			end
		end,
		Tooltip = 'Redirects only the shot values sent to the server, so enemies get hit while your shot flies exactly where you aimed on your own screen'
	})
	Targets = SilentAim:CreateTargets({
		Players = true,
		Walls = true
	})
	TargetPart = SilentAim:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head', 'Closest', 'Randomize'},
		Default = 'RootPart',
		Tooltip = 'Where on the body the shot is aimed\nClosest - the head or the body, whichever is nearer your cursor\nRandomize - picked per shot from the chances below'
	})
	HeadChance = SilentAim:CreateSlider({
		Name = 'Head Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Suffix = '%',
		Darker = true,
		Visible = function()
			return TargetPart.Value == 'Randomize'
		end
	})
	TorsoChance = SilentAim:CreateSlider({
		Name = 'Torso Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Suffix = '%',
		Darker = true,
		Visible = function()
			return TargetPart.Value == 'Randomize'
		end,
		Tooltip = 'What is left after the head and the torso goes to the root part'
	})
	Sort = SilentAim:CreateDropdown({
		Name = 'Sort Method',
		List = store.sortList,
		Default = 'Cursor',
		Tooltip = 'Distance - the nearest\nCursor - nearest your cursor on screen\nAngle - nearest to where your camera looks\nLowest Health / Highest Health'
	})
	Prediction = SilentAim:CreateSlider({
		Name = 'Prediction',
		Min = 0.1,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Tooltip = 'Scales how far ahead of a moving target the shot is sent'
	})
	FOV = SilentAim:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 300,
		Tooltip = 'How far from your cursor a player can be, in pixels'
	})
	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 30,
		Max = 500,
		Default = 500,
		Suffix = 'studs',
		Tooltip = 'Only targets players within this distance'
	})
	ring = store.ring(SilentAim, 'BFSAFOVCircle', 'Draws the range a target is caught at, centred on the cursor')
	ring.Radius = function()
		return FOV.Value
	end
	OtherProjectiles = SilentAim:CreateToggle({
		Name = 'Other Projectiles',
		Default = true,
		Function = function(callback)
			if Blacklist then
				Blacklist.Object.Visible = callback
			end
		end,
		Tooltip = 'Also redirects fireballs, hotdogs and anything else that is not a bow or a crossbow'
	})
	Blacklist = SilentAim:CreateTextList({
		Name = 'Blacklist',
		Darker = true,
		Default = {'Teleorb'},
		Placeholder = 'weapon name'
	})
	AutoCharge = SilentAim:CreateToggle({
		Name = 'AutoCharge',
		Function = function(callback)
			if ChargePercent then
				ChargePercent.Object.Visible = callback
			end
		end,
		Tooltip = 'Sends the shot at the charge below however long you drew it.\nWhether the server accepts a stronger shot than you drew has not been checked'
	})
	ChargePercent = SilentAim:CreateSlider({
		Name = 'Charge Percent',
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%',
		Darker = true,
		Visible = false
	})
	Debug = SilentAim:CreateToggle({
		Name = 'Debug',
		Tooltip = 'Reports what each shot did - which target it was sent to, or why it was left alone'
	})
end)


run(function()
	local Sprint

	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				-- the same switch the game's sprint key and mobile button use
				local sprint = bedfight.ButtonProperties.new('Sprint')
				repeat
					if entitylib.isAlive and entitylib.character.Humanoid.MoveDirection.Magnitude > 0 then
						if not sprint.Active.Value and sprint.Priority == 0 then
							sprint:Set(true, nil, true)
						end
					end
					task.wait(0.1)
				until not Sprint.Enabled
			end
		end,
		Tooltip = 'Keeps you sprinting whenever you move'
	})
end)


run(function()
	local Velocity
	local Horizontal
	local Vertical
	local Chance
	local Targeting
	local connection, old
	local attribute
	local rand = Random.new()

	local function scaled(velocity)
		if rand:NextNumber(0, 100) > Chance.Value then return velocity end
		if Targeting.Enabled and not entitylib.EntityPosition({Range = 50, Part = 'RootPart', Players = true}) then return velocity end
		local hort, vert = Horizontal.Value / 100, Vertical.Value / 100
		if hort == 0 and vert == 0 then return nil end
		return Vector3.new(velocity.X * hort, velocity.Y * vert, velocity.Z * hort)
	end

	local function handler(part, velocity, ...)
		if typeof(velocity) == 'Vector3' then
			velocity = scaled(velocity)
			if not velocity then return end
		end
		return old(part, velocity, ...)
	end

	-- the game's own knockback listener, picked out by the script it lives in
	local function knockbackConnection()
		local list = getconnections(remotes.Knockback.OnClientEvent)
		for _, v in list do
			local ok, source = pcall(debug.info, v.Function, 's')
			if ok and type(source) == 'string' and source:find('KnockbackScript') then
				return v
			end
		end
		return #list == 1 and list[1] or nil
	end

	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Function = function(callback)
			if callback then
				if hookfunction and getconnections then
					connection = knockbackConnection()
					if connection and connection.Function then
						old = hookfunction(connection.Function, function(...)
							return handler(...)
						end)
						return
					end
					connection = nil
				end

				-- no hooks: the game skips knockback while this attribute is set, so it is all or nothing
				notif('Velocity', 'Your executor cannot hook the knockback handler, so knockback is removed completely instead of scaled.', 8, 'warning')
				attribute = true
				repeat
					if entitylib.isAlive and not entitylib.character.Humanoid:GetAttribute('KnockbackDisabled') then
						entitylib.character.Humanoid:SetAttribute('KnockbackDisabled', true)
					end
					task.wait(0.2)
				until not Velocity.Enabled
			else
				if old and connection then
					hookfunction(connection.Function, old)
				end
				old, connection = nil, nil
				if attribute then
					attribute = nil
					if entitylib.isAlive then
						entitylib.character.Humanoid:SetAttribute('KnockbackDisabled', nil)
					end
				end
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
	local AutoBuy
	local Swords
	local Armor
	local Pickaxes
	local Ranged
	local Blocks
	local BlockAmount
	local Arrows
	local ArrowAmount
	local Crossbow
	local GUI
	local SmartCheck
	local Upgrades = {}
	local Custom, CustomPost = {}, {}

	-- nearest shop or upgrade stand within range
	local function prompt(tag)
		-- the shop screen closes at 10 studs, a purchase from 21 was turned down
		local best, dist = nil, 10
		for _, v in collectionService:GetTagged(tag) do
			if v:IsA('BasePart') and v:IsDescendantOf(workspace) then
				local mag = (v.Position - entitylib.character.RootPart.Position).Magnitude
				if mag <= dist then
					best, dist = v, mag
				end
			end
		end
		return best
	end

	-- the game's own "can I buy this" answer, from the shop screen's module
	local function buyResult(name, data)
		local gui = lplr.PlayerGui:FindFirstChild('ItemShopGui')
		local module = gui and gui:FindFirstChild('ItemShopHandler')
		if not module then return nil end
		local ok, handler = pcall(require, module)
		if not ok then return nil end
		local okr, result = pcall(handler.GetBuyResult, name, data)
		return okr and result or nil
	end

	local function count(pattern)
		local total = 0
		for name, amount in store.inventory do
			if name:find(pattern) then
				total += amount
			end
		end
		return total
	end

	local function screenOpen(name)
		local gui = lplr.PlayerGui:FindFirstChild(name)
		return gui ~= nil and gui:IsA('LayerCollector') and gui.Enabled
	end

	-- one purchase a pass, the best thing first
	local function shop(stand)
		local kit = lplr:FindFirstChild('Kit')
		local list = bedfight.ItemShopData.GetItemShop(false, kit and kit.Value or '')
		local function try(category, name, data)
			if buyResult(name, data) == 'Buy' then
				fireRemote('PurchaseItemShopItem', stand, category, name)
				return true
			end
		end

		-- what the Item list asks for, in the order of its numbers
		local function extras(entries)
			for _, want in entries do
				for _, entry in list do
					for _, data in entry.List do
						if data.Name:lower() == want.Name then
							local have = data.ReplaceName and count(data.Name..'$') or getItem(data.Name) or 0
							if have < want.Amount and try(entry.Category, data.Name, data) then return true end
						end
					end
				end
			end
			return false
		end
		if extras(Custom) then return true end

		-- the next sword or armour you are still saving for, and what it is paid in
		local saving = {}
		if SmartCheck.Enabled then
			for _, entry in list do
				if (entry.Category == 'Swords' and Swords.Enabled) or (entry.Category == 'Armor' and Armor.Enabled) then
					for _, data in entry.List do
						if data.Max == 1 and buyResult(data.Name, data) == 'Not Enough' then
							for currency in data.Price do
								saving[currency] = true
							end
							break
						end
					end
				end
			end
		end

		for _, entry in list do
			local category = entry.Category
			local upgrade = (category == 'Swords' and Swords.Enabled) or (category == 'Armor' and Armor.Enabled)
				or (category == 'Pickaxes' and Pickaxes.Enabled) or (category == 'Ranged' and Ranged.Enabled)
			for i = #entry.List, 1, -1 do
				local data = entry.List[i]
				local wanted = upgrade and data.Max == 1 and not (data.Name == 'Crossbow' and not Crossbow.Enabled)
				if wanted and category == 'Pickaxes' then
					for currency in data.Price do
						if saving[currency] then
							wanted = false
						end
					end
				end
				if wanted and try(category, data.Name, data) then return true end
				if data.Name == 'Wool' and Blocks.Enabled and count('Wool$') < BlockAmount.Value and try(category, data.Name, data) then return true end
				if data.Name == 'Arrow' and Arrows.Enabled and (getItem('Bow') or getItem('Crossbow')) and count('^Arrow$') < ArrowAmount.Value and try(category, data.Name, data) then return true end
			end
		end
		return extras(CustomPost)
	end

	local function upgrade(stand)
		local folder = bedfight.TeamUpgrades:FindFirstChild(lplr.Team.Name)
		if not folder then return end
		for index, name in bedfight.TeamUpgradesData.UpgradesOrder do
			local toggle, value, meta = Upgrades[name], folder:FindFirstChild(name), bedfight.TeamUpgradesData.Upgrades[name]
			local price = toggle and toggle.Enabled and value and meta and meta.Prices[value.Value + 1]
			if price then
				local afford = true
				for currency, amount in price do
					if (getItem(currency) or 0) < amount then
						afford = false
					end
				end
				if afford then
					fireRemote('TeamUpgrade', stand, index)
					return
				end
			end
		end
	end

	AutoBuy = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBuy',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and inMatch() then
						local stand = prompt('ItemShopPrompt')
						if stand and (not GUI.Enabled or screenOpen('ItemShopGui')) then
							shop(stand)
						end
						stand = prompt('TeamUpgradePrompt')
						if stand and (not GUI.Enabled or screenOpen('TeamUpgradesGui')) then
							upgrade(stand)
						end
					end
					task.wait(0.35)
				until not AutoBuy.Enabled
			end
		end,
		Tooltip = 'Buys gear and team upgrades as soon as you can afford them.\nYou have to be within 10 studs of the shopkeeper, the same as opening the shop.'
	})
	Swords = AutoBuy:CreateToggle({Name = 'Swords', Default = true, Tooltip = 'The best weapon your kit can buy'})
	Armor = AutoBuy:CreateToggle({Name = 'Armor', Default = true})
	Pickaxes = AutoBuy:CreateToggle({Name = 'Pickaxes'})
	Ranged = AutoBuy:CreateToggle({
		Name = 'Bow and crossbow',
		Function = function(callback)
			if Crossbow then
				Crossbow.Object.Visible = callback
			end
		end
	})
	Crossbow = AutoBuy:CreateToggle({
		Name = 'Buy Crossbow',
		Default = true,
		Darker = true,
		Visible = false,
		Tooltip = 'Off, only the bow is bought'
	})
	Arrows = AutoBuy:CreateToggle({
		Name = 'Arrows',
		Function = function(callback)
			ArrowAmount.Object.Visible = callback
		end
	})
	ArrowAmount = AutoBuy:CreateSlider({
		Name = 'Keep arrows',
		Min = 8,
		Max = 64,
		Default = 16,
		Darker = true,
		Visible = false
	})
	Blocks = AutoBuy:CreateToggle({
		Name = 'Wool',
		Function = function(callback)
			BlockAmount.Object.Visible = callback
		end
	})
	BlockAmount = AutoBuy:CreateSlider({
		Name = 'Keep wool',
		Min = 8,
		Max = 128,
		Default = 32,
		Darker = true,
		Visible = false
	})
	GUI = AutoBuy:CreateToggle({
		Name = 'GUI check',
		Tooltip = 'Only buys while the shop or the team upgrade screen is open'
	})
	SmartCheck = AutoBuy:CreateToggle({
		Name = 'Smart check',
		Default = true,
		Tooltip = 'Holds off on pickaxes while you are still saving the same resource for your next sword or armour'
	})
	AutoBuy:CreateTextList({
		Name = 'Item',
		Placeholder = 'priority/item/amount/after',
		Tooltip = 'Extra items to keep in stock, for example 1/Fireball/2 or 2/Obsidian/8.\nA fourth part (1/TNT/1/after) buys it after your gear, not before',
		Function = function(list)
			table.clear(Custom)
			table.clear(CustomPost)
			for _, entry in list do
				local tab = entry:split('/')
				local priority, amount = tonumber(tab[1]), tonumber(tab[3])
				if priority and tab[2] and amount then
					table.insert(tab[4] and CustomPost or Custom, {Priority = priority, Name = tab[2]:lower(), Amount = amount})
				end
			end
			for _, tab in {Custom, CustomPost} do
				table.sort(tab, function(a, b)
					return a.Priority < b.Priority
				end)
			end
		end
	})
	for _, name in bedfight.TeamUpgradesData.UpgradesOrder do
		Upgrades[name] = AutoBuy:CreateToggle({
			Name = name,
			Default = name == 'Team Generator',
			Tooltip = 'Team upgrade, paid in diamonds'
		})
	end
end)


run(function()
	local ChestManager
	local Loot
	local Chests
	local KeepInv
	local Health
	local Void
	local GameEnd
	local saved = {}
	local saveAt = 0

	local function teamName()
		return inMatch() and lplr.Team.Name or nil
	end

	-- the chest model of a team, when it stands within range
	local function chestInRange(team)
		if not entitylib.isAlive then return false end
		for _, v in collectionService:GetTagged('TeamChest') do
			if v.Name == team and v:IsDescendantOf(workspace) then
				-- the game closes a chest once you are 24 studs away
				return (v:GetPivot().Position - entitylib.character.RootPart.Position).Magnitude <= 24
			end
		end
		return false
	end

	local function lootChests()
		local mine = teamName()
		if not mine then return end
		for _, storage in bedfight.TeamChests:GetChildren() do
			local own = storage.Name == mine
			if (Chests.Value == 'Own team' and not own) or (Chests.Value == 'Enemy teams' and own) then continue end
			if not chestInRange(storage.Name) then continue end
			for _, slot in storage:GetChildren() do
				local index, item = tonumber(slot.Name), slot:GetAttribute('Name')
				-- what KeepInv parked in your own chest stays there until you are back
				if index and item and item ~= '' and not (own and saved[index]) then
					fireRemote('TakeItemFromChest', storage.Name, index, item)
					task.wait(0.1)
					if not ChestManager.Enabled then return end
				end
			end
		end
	end

	local function save()
		local team = teamName()
		local storage = team and bedfight.TeamChests:FindFirstChild(team)
		if not storage or saveAt > tick() or not chestInRange(team) then return end
		saveAt = tick() + 5
		local index = 0
		for name in store.inventory do
			local data = bedfight.ItemsData[name]
			if data and data.CanStoreInChest then
				repeat index += 1 until index > 20 or not storage:FindFirstChild(tostring(index))
				if index > 20 then break end
				saved[index] = name
				fireRemote('PutItemInChest', name, team, index)
			end
		end
	end

	local function restore()
		local team = teamName()
		if not team or not next(saved) then return end
		local list = table.clone(saved)
		table.clear(saved)
		for index, name in list do
			fireRemote('TakeItemFromChest', team, index, name)
			task.wait(0.25)
		end
	end

	ChestManager = vape.Categories.Inventory:CreateModule({
		Name = 'ChestManager',
		Function = function(callback)
			if callback then
				ChestManager:Clean(entitylib.Events.LocalAdded:Connect(function()
					task.wait(1)
					if KeepInv.Enabled then
						restore()
					end
				end))
				ChestManager:Clean(bedfight.Signals.EndGame:Connect(function()
					if KeepInv.Enabled and GameEnd.Enabled then
						saveAt = 0
						save()
					end
				end))

				local floor
				repeat
					if entitylib.isAlive and inMatch() then
						if KeepInv.Enabled then
							local hum, root = entitylib.character.Humanoid, entitylib.character.RootPart
							if hum.Health > 0 and hum.Health / hum.MaxHealth * 100 <= Health.Value then
								save()
							elseif Void.Enabled then
								-- lowest block of the map, looked up once a match
								local map = mapBlocks()
								if map and (not floor or floor.Map ~= map) then
									local low = math.huge
									for _, v in map:GetDescendants() do
										if v:IsA('BasePart') and v.Position.Y < low then
											low = v.Position.Y
										end
									end
									floor = {Map = map, Y = low}
								end
								if floor and root.Position.Y < floor.Y - 15 then
									save()
								end
							end
						end
						if Loot.Enabled then
							lootChests()
						end
					end
					task.wait(0.3)
				until not ChestManager.Enabled
			end
		end,
		Tooltip = 'Empties team chests into your inventory and can park your items in your own chest before you die.\nWorks within 24 studs of a chest, the distance the game keeps one open.'
	})
	Loot = ChestManager:CreateToggle({
		Name = 'Loot chests',
		Default = true,
		Function = function(callback)
			if Chests then
				Chests.Object.Visible = callback
			end
		end
	})
	Chests = ChestManager:CreateDropdown({
		Name = 'Chests',
		List = {'All teams', 'Enemy teams', 'Own team'},
		Darker = true
	})
	KeepInv = ChestManager:CreateToggle({
		Name = 'Keep inventory',
		Function = function(callback)
			Health.Object.Visible = callback
			Void.Object.Visible = callback
			GameEnd.Object.Visible = callback
		end,
		Tooltip = 'Puts everything storable into your team chest when you are about to die and takes it back after you respawn'
	})
	Health = ChestManager:CreateSlider({
		Name = 'Health',
		Min = 5,
		Max = 60,
		Default = 25,
		Suffix = '%',
		Darker = true,
		Visible = false
	})
	Void = ChestManager:CreateToggle({
		Name = 'When falling into the void',
		Default = true,
		Darker = true,
		Visible = false
	})
	GameEnd = ChestManager:CreateToggle({
		Name = 'When the game ends',
		Darker = true,
		Visible = false
	})
end)


run(function()
	local UICleanup
	local groups = {
		Popups = {'KitPopupsGui', 'AnnouncementGui', 'NotificationGui', 'AchievementGui', 'OfflineRewardsGui', 'GiftedKitGui', 'GroupVerificationGui', 'UpdateLogGui'},
		['Purchase effects'] = {'PurchaseEffectGui', 'PurchasingEffectGui2'},
		['Damage flash'] = {'DamageScreenEffectGui'},
		['Shift lock icon'] = {'ShiftlockDisplayGui'}
	}
	local toggles = {}
	local TopBar
	local saved = {}

	local function hide(obj, prop)
		if obj[prop] then
			saved[obj] = saved[obj] or prop
			obj[prop] = false
		end
	end

	local function restore(filter)
		for obj, prop in saved do
			if not filter or filter(obj) then
				saved[obj] = nil
				pcall(function()
					obj[prop] = true
				end)
			end
		end
	end

	UICleanup = vape.Categories.Legit:CreateModule({
		Name = 'UICleanup',
		Function = function(callback)
			if callback then
				repeat
					local gui = lplr:FindFirstChildOfClass('PlayerGui')
					if gui then
						for group, names in groups do
							if toggles[group].Enabled then
								for _, name in names do
									local screen = gui:FindFirstChild(name)
									if screen and screen:IsA('ScreenGui') then
										hide(screen, 'Enabled')
									end
								end
							end
						end
						if TopBar.Enabled then
							local list = gui:FindFirstChild('TopbarButtonsGui') and gui.TopbarButtonsGui:FindFirstChild('ButtonsList')
							for _, name in {'UpdateLog', 'Codes'} do
								local button = list and list:FindFirstChild(name)
								if button and button:IsA('GuiObject') then
									hide(button, 'Visible')
								end
							end
						end
					end
					task.wait(0.25)
				until not UICleanup.Enabled
			else
				restore()
			end
		end,
		Tooltip = 'Keeps the game\'s popups and extra buttons off your screen'
	})
	for group in groups do
		toggles[group] = UICleanup:CreateToggle({
			Name = group,
			Default = true,
			Function = function(callback)
				if not callback then
					restore(function(obj)
						return table.find(groups[group], obj.Name) ~= nil
					end)
				end
			end
		})
	end
	TopBar = UICleanup:CreateToggle({
		Name = 'Top bar buttons',
		Default = true,
		Function = function(callback)
			if not callback then
				restore(function(obj)
					return obj.Name == 'UpdateLog' or obj.Name == 'Codes'
				end)
			end
		end,
		Tooltip = 'The update log and codes buttons'
	})
end)


run(function()
	local BedESP
	local EnemyOnly
	local Fill
	local ShowName
	local ShowDistance
	local Reference = {}
	local folder = Instance.new('Folder')
	folder.Parent = vape.gui
	vape:Clean(folder)

	local function teamColor(name)
		local team = game:GetService('Teams'):FindFirstChild(tostring(name))
		return team and team.TeamColor.Color or Color3.fromRGB(220, 60, 60)
	end

	-- nothing may ever be parented into a bed, the game treats that as bed ESP
	local function added(bed)
		if Reference[bed] then return end
		local hitbox = bed:IsA('Model') and bed:WaitForChild('BedHitbox', 5)
		if not hitbox or Reference[bed] or not BedESP.Enabled then return end
		local color = teamColor(bed:GetAttribute('Team'))
		local box = Instance.new('BoxHandleAdornment')
		box.Adornee = hitbox
		box.Size = hitbox.Size + Vector3.new(0.2, 0.2, 0.2)
		box.AlwaysOnTop = true
		box.ZIndex = 0
		box.Color3 = color
		box.Transparency = 1 - Fill.Value
		box.Parent = folder
		local billboard = Instance.new('BillboardGui')
		billboard.Adornee = hitbox
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.fromOffset(160, 18)
		billboard.StudsOffset = Vector3.new(0, 4, 0)
		billboard.Parent = folder
		local label = Instance.new('TextLabel')
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 13
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.4
		label.Parent = billboard
		Reference[bed] = {Box = box, Billboard = billboard, Label = label, Hitbox = hitbox}
	end

	local function removed(bed)
		local ref = Reference[bed]
		if ref then
			Reference[bed] = nil
			ref.Box:Destroy()
			ref.Billboard:Destroy()
		end
	end

	BedESP = vape.Categories.Render:CreateModule({
		Name = 'BedESP',
		Function = function(callback)
			if callback then
				local function watch(container)
					BedESP:Clean(container.ChildAdded:Connect(function(bed)
						task.spawn(added, bed)
					end))
					BedESP:Clean(container.ChildRemoved:Connect(removed))
					for _, bed in container:GetChildren() do
						task.spawn(added, bed)
					end
				end
				BedESP:Clean(workspace.ChildAdded:Connect(function(v)
					if v.Name == 'BedsContainer' then
						watch(v)
					end
				end))
				if workspace:FindFirstChild('BedsContainer') then
					watch(workspace.BedsContainer)
				end

				repeat
					local mine = lplr.Team and lplr.Team.Name
					for bed, ref in Reference do
						local team = bed:GetAttribute('Team')
						local shown = not (EnemyOnly.Enabled and team == mine)
						ref.Box.Visible = shown
						ref.Box.Transparency = 1 - Fill.Value
						ref.Billboard.Enabled = shown and (ShowName.Enabled or ShowDistance.Enabled)
						if ref.Billboard.Enabled then
							local text = ShowName.Enabled and tostring(team)..' Bed' or ''
							if ShowDistance.Enabled and entitylib.isAlive then
								text ..= string.format(' [%d]', (ref.Hitbox.Position - entitylib.character.RootPart.Position).Magnitude)
							end
							ref.Label.Text = text
						end
					end
					task.wait(0.2)
				until not BedESP.Enabled
			else
				for bed in table.clone(Reference) do
					removed(bed)
				end
			end
		end,
		Tooltip = 'Shows beds through walls'
	})
	EnemyOnly = BedESP:CreateToggle({
		Name = 'Enemy only',
		Default = true
	})
	Fill = BedESP:CreateSlider({
		Name = 'Opacity',
		Min = 0.1,
		Max = 1,
		Default = 0.5,
		Decimal = 10
	})
	ShowName = BedESP:CreateToggle({
		Name = 'Team name',
		Default = true
	})
	ShowDistance = BedESP:CreateToggle({
		Name = 'Distance',
		Default = true
	})
end)


run(function()
	local BedPlates
	local Background
	local Color
	local Counter
	local Reach
	local Reference = {}
	local folder = Instance.new('Folder')
	folder.Parent = vape.gui
	vape:Clean(folder)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include

	-- the kinds of block stacked around a bed, most of them first
	local function scan(hitbox)
		local container = workspace:FindFirstChild('PlayersBlocksContainer')
		if not container then return {} end
		overlap.FilterDescendantsInstances = {container}
		local reach = Reach.Value * 3 * 2
		local counts, seen = {}, {}
		for _, part in workspace:GetPartBoundsInBox(hitbox.CFrame, hitbox.Size + Vector3.new(reach, reach, reach), overlap) do
			local node = part
			while node.Parent and node.Parent.Parent ~= container and node.Parent ~= container do
				node = node.Parent
			end
			local kind = node.Parent and node.Parent ~= container and node.Parent.Name or node.Name
			-- a block made of several parts counts once
			if not seen[node] then
				seen[node] = true
				counts[kind] = (counts[kind] or 0) + 1
			end
		end
		local list = {}
		for kind, amount in counts do
			table.insert(list, {kind, amount})
		end
		table.sort(list, function(a, b)
			return a[2] == b[2] and a[1] < b[1] or a[2] > b[2]
		end)
		return list
	end

	local function refresh(billboard)
		local frame = billboard.Frame
		local list = scan(billboard.Adornee)
		local key = ''
		for _, entry in list do
			key ..= entry[1]..entry[2]..';'
		end
		if frame:GetAttribute('Shown') == key then return end
		frame:SetAttribute('Shown', key)
		for _, obj in frame:GetChildren() do
			if obj:IsA('ImageLabel') or obj:IsA('TextLabel') then
				obj:Destroy()
			end
		end
		billboard.Enabled = #list > 0
		for index, entry in list do
			if index > 6 then break end
			local data = bedfight.ItemsData and bedfight.ItemsData[entry[1]]
			local image = Instance.new('ImageLabel')
			image.Size = UDim2.fromOffset(32, 32)
			image.BackgroundTransparency = 1
			image.Image = data and data.Image or ''
			image.Parent = frame
			local amount = Instance.new('TextLabel')
			amount.Name = 'Amount'
			amount.Size = UDim2.fromScale(1, 1)
			amount.BackgroundTransparency = 1
			-- a kind with no picture is named
			amount.Text = (data and data.Image) and (Counter.Enabled and tostring(entry[2]) or '') or entry[1]:sub(1, 6)
			amount.TextColor3 = Color3.new(1, 1, 1)
			amount.TextSize = (data and data.Image) and 16 or 10
			amount.TextStrokeTransparency = 0.3
			amount.Font = Enum.Font.Arial
			amount.Parent = image
		end
	end

	-- nothing may ever be parented into a bed, the game treats that as bed ESP
	local function added(bed)
		if Reference[bed] then return end
		local hitbox = bed:IsA('Model') and bed:WaitForChild('BedHitbox', 5)
		if not hitbox or Reference[bed] or not BedPlates.Enabled then return end
		local billboard = Instance.new('BillboardGui')
		billboard.Name = 'bed'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = hitbox
		local frame = Instance.new('Frame')
		frame.Name = 'Frame'
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		frame.Parent = billboard
		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 4)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
		end)
		layout.Parent = frame
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame
		billboard.Parent = folder
		Reference[bed] = billboard
		refresh(billboard)
	end

	local function removed(bed)
		if Reference[bed] then
			Reference[bed]:Destroy()
			Reference[bed] = nil
		end
	end

	local function watch(container)
		BedPlates:Clean(container.ChildAdded:Connect(function(bed)
			task.spawn(added, bed)
		end))
		BedPlates:Clean(container.ChildRemoved:Connect(removed))
		for _, bed in container:GetChildren() do
			task.spawn(added, bed)
		end
	end

	BedPlates = vape.Categories.Render:CreateModule({
		Name = 'BedPlates',
		Function = function(callback)
			if callback then
				if workspace:FindFirstChild('BedsContainer') then
					watch(workspace.BedsContainer)
				end
				BedPlates:Clean(workspace.ChildAdded:Connect(function(v)
					if v.Name == 'BedsContainer' then
						watch(v)
					end
				end))
				repeat
					for bed, billboard in Reference do
						if bed.Parent and billboard.Adornee and billboard.Adornee.Parent then
							refresh(billboard)
						else
							removed(bed)
						end
					end
					task.wait(1)
				until not BedPlates.Enabled
			else
				for bed in Reference do
					removed(bed)
				end
			end
		end,
		Tooltip = 'Shows over every bed which blocks are built around it'
	})
	Reach = BedPlates:CreateSlider({
		Name = 'Layers',
		Min = 1,
		Max = 5,
		Default = 3,
		Tooltip = 'How many blocks out from the bed are counted'
	})
	Counter = BedPlates:CreateToggle({
		Name = 'Block count',
		Default = true,
		Function = function()
			for _, billboard in Reference do
				billboard.Frame:SetAttribute('Shown', nil)
			end
		end
	})
	Background = BedPlates:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color and Color.Object then
				Color.Object.Visible = callback
			end
			for _, billboard in Reference do
				billboard.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
			end
		end,
		Default = true
	})
	Color = BedPlates:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, billboard in Reference do
				billboard.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				billboard.Frame.BackgroundTransparency = 1 - (Background.Enabled and opacity or 0)
			end
		end,
		Darker = true
	})
end)




run(function()
	local StreamerMode
	local Name
	local FakeName
	local Rank
	local RankName
	local Board
	local BoardRank
	local BoardScore
	local changed = {}

	local function rankImage()
		for _, v in bedfight.RanksData.Ranks do
			if v.Name == RankName.Value then
				return v.Image
			end
		end
	end

	-- the game's own tag above your head
	local function ownTag()
		local gui = lplr.PlayerGui:FindFirstChild('PlayersNameTagGui')
		local head = lplr.Character and lplr.Character:FindFirstChild('Head')
		for _, tag in gui and head and gui:GetChildren() or {} do
			if tag:IsA('BillboardGui') and tag.Adornee == head then
				return tag:FindFirstChild('BottomFrame')
			end
		end
	end

	local function set(obj, prop, value)
		if obj[prop] == value then return end
		changed[obj] = changed[obj] or {}
		if changed[obj][prop] == nil then
			changed[obj][prop] = obj[prop]
		end
		obj[prop] = value
	end

	local function isOwnName(text)
		return text == lplr.Name or text == lplr.DisplayName or text == '@'..lplr.Name
	end

	local function boards()
		local lobby = bedfight.Lobby.Value
		local folder = lobby and lobby:FindFirstChild('Leaderboards')
		local list = {}
		for _, kind in folder and folder:GetChildren() or {} do
			for _, board in kind:GetChildren() do
				local frame = board:FindFirstChild('Bottom') and board.Bottom:FindFirstChild('BottomGui') and board.Bottom.BottomGui:FindFirstChild('Frame')
				if frame then
					table.insert(list, frame)
				end
			end
		end
		return list
	end

	StreamerMode = vape.Categories.Render:CreateModule({
		Name = 'StreamerMode',
		Function = function(callback)
			if callback then
				-- new text that is exactly your name, kill log and popups included
				StreamerMode:Clean(lplr.PlayerGui.DescendantAdded:Connect(function(v)
					if not v:IsA('TextLabel') or not Name.Enabled or v:IsDescendantOf(vape.gui) then return end
					task.defer(function()
						if StreamerMode.Enabled and v.Parent and isOwnName(v.Text) then
							set(v, 'Text', FakeName.Value)
						end
					end)
				end))

				repeat
					local tag = ownTag()
					if tag then
						local label, icon = tag:FindFirstChild('NameLabel'), tag:FindFirstChild('RankIcon')
						if label and Name.Enabled and FakeName.Value ~= '' then
							set(label, 'Text', FakeName.Value)
						end
						local image = icon and Rank.Enabled and rankImage()
						if image then
							set(icon, 'Image', image)
						end
					end
					if Board.Enabled then
						for _, frame in boards() do
							local text, value = frame:FindFirstChild('TextLabel'), frame:FindFirstChild('ValueLabel')
							if text and value then
								set(text, 'Text', '#'..BoardRank.Value..' You:')
								set(value, 'Text', tostring(BoardScore.Value))
							end
						end
					end
					task.wait(0.25)
				until not StreamerMode.Enabled
			else
				for obj, props in changed do
					for prop, value in props do
						pcall(function()
							obj[prop] = value
						end)
					end
				end
				table.clear(changed)
			end
		end,
		Tooltip = 'Hides who you are on your own screen, for recordings and streams'
	})
	Name = StreamerMode:CreateToggle({
		Name = 'Hide name',
		Default = true,
		Function = function(callback)
			if FakeName then
				FakeName.Object.Visible = callback
			end
		end
	})
	FakeName = StreamerMode:CreateTextBox({
		Name = 'Shown name',
		Default = 'Player',
		Darker = true
	})
	Rank = StreamerMode:CreateToggle({
		Name = 'Change rank icon',
		Function = function(callback)
			if RankName then
				RankName.Object.Visible = callback
			end
		end
	})
	local ranks = {}
	for _, v in bedfight.RanksData.Ranks do
		table.insert(ranks, v.Name)
	end
	RankName = StreamerMode:CreateDropdown({
		Name = 'Rank',
		List = ranks,
		Darker = true,
		Visible = false
	})
	Board = StreamerMode:CreateToggle({
		Name = 'Change leaderboard row',
		Function = function(callback)
			if BoardRank then
				BoardRank.Object.Visible = callback
				BoardScore.Object.Visible = callback
			end
		end,
		Tooltip = 'Your own row under the lobby leaderboards'
	})
	BoardRank = StreamerMode:CreateSlider({
		Name = 'Position',
		Min = 1,
		Max = 100,
		Default = 1,
		Darker = true,
		Visible = false
	})
	BoardScore = StreamerMode:CreateSlider({
		Name = 'Score',
		Min = 0,
		Max = 9999,
		Default = 9999,
		Darker = true,
		Visible = false
	})
end)


run(function()
	local AntiCheatBypass
	local Notify
	local Lagback
	local warned = {}
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	-- drops up to 20 studs are free, and the root may be off the ground for a second (0.9 held, 1.1 did not)
	local MAX_DROP, AIR, STAND = 18, 0.75, 0.13

	local function uncover()
		store.floatCover = nil
		mergeRoot('Lagback')
	end
	local userOff = false

	AntiCheatBypass = vape.Categories.Utility:CreateModule({
		Name = 'AntiCheatBypass',
		Function = function(callback)
			if callback then
				userOff = false
				AntiCheatBypass:Clean(function()
					disarmAnticheat(false)
					uncover()
				end)
				local found, reason = disarmAnticheat(true)
				if found == nil then
					notif('AntiCheatBypass', 'Client hooks unavailable: '..tostring(reason)..'. Protection is not confirmed.', 15, 'alert')
				elseif store.anticheat.Tripped then
					notif('AntiCheatBypass', 'The anticheat already went off this session, so your actions no longer reach the server. Rejoin to fix it.', 15, 'alert')
				elseif found == 0 and vape.Loaded then
					notif('AntiCheatBypass', store.anticheat.Found and store.anticheat.Found > 0 and 'Client checks were found, but no hook could be installed. Inspect the hook errors; protection is not confirmed.' or 'No client hook is installed yet. New client copies are checked when they arrive.', 8, 'warning')
				end

				-- the server pulls back a root that has been off the ground too long, and it only follows
				-- the real root. so that one stands on the ground below for a moment while you stay up
				local air, standUntil = 0, nil
				AntiCheatBypass:Clean(runService.Heartbeat:Connect(function(dt)
					local character = entitylib.character
					if not (AntiCheatBypass.Enabled and Lagback.Enabled and entitylib.isAlive and character and character.RootPart and character.RootPart.Parent and character.Humanoid) or store.dashOn then
						air, standUntil = 0, nil
						uncover()
						return
					end
					-- AntiHit is moving the root and stands it on the ground itself
					if store.antiHitAt and tick() - store.antiHitAt < 0.2 then
						air, standUntil = 0, nil
						store.floatCover = tick()
						mergeRoot('Lagback')
						return
					end
					local body = bodyRoot()
					if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
						air, standUntil = 0, nil
						store.floatCover = tick()
						mergeRoot('Lagback')
						return
					end
					rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('PlayersContainer') or lplr.Character, gameCamera}
					local ground = workspace:Raycast(body.Position, Vector3.new(0, -60, 0), rayCheck)
					local height = entitylib.character.HipHeight
					local drop = ground and ground.Distance - height
					if not drop or drop > MAX_DROP then
						-- too high to come down for free, or nothing below
						air, standUntil = air + dt, nil
						uncover()
						return
					end
					store.floatCover = tick()
					if standUntil then
						if tick() < standUntil then
							sendRoot(CFrame.new(body.Position.X, ground.Position.Y + height, body.Position.Z) * body.CFrame.Rotation)
						else
							air, standUntil = 0, nil
						end
						return
					end
					air += dt
					if air >= AIR and drop > 0.5 and splitRoot('Lagback') then
						standUntil = tick() + STAND
					end
				end))

				AntiCheatBypass:Clean(vapeEvents.AnticheatBlocked.Event:Connect(function(reason)
					if Notify.Enabled and not warned[reason] then
						warned[reason] = true
						notif('AntiCheatBypass', 'Stopped a detection: '..reason, 8, 'warning')
					end
				end))
			else
				userOff = true
				disarmAnticheat(false)
				uncover()
				table.clear(warned)
				if vape.Loaded then
					notif('AntiCheatBypass', 'Client interception is disabled. Owned hooks were restored where writable; external hooks were left untouched.', 10, 'warning')
				end
			end
		end,
		ExtraText = function()
			local total = 0
			for _, v in store.anticheat.Blocked do
				total += v
			end
			return total > 0 and total..' stopped' or ''
		end,
		Tooltip = 'Switches off the hidden client check that swaps every remote for a dead copy and reports you.\nIt watches hitbox size, an anchored root, WalkSpeed of 25 or more, unknown capes,\nanything added to a bed and the knockback script.\nTurns itself on each launch.'
	})
	Lagback = AntiCheatBypass:CreateToggle({
		Name = 'Prevent lagback',
		Default = true,
		Function = function(callback)
			if not callback then
				uncover()
			end
		end,
		Tooltip = 'Stops the pull back for being off the ground too long, while the ground is within 18 studs below you.\nOnly the hitbox the server follows touches down, every three quarters of a second. You and your camera stay up.\nIt cannot cover moving faster than the server allows, or heights above 18 studs.'
	})
	Notify = AntiCheatBypass:CreateToggle({
		Name = 'Notify',
		Default = true,
		Tooltip = 'Says once per reason what the anticheat tried to flag'
	})

	-- on unless the player switched it off this session
	task.spawn(function()
		repeat task.wait(0.5) until vape.Loaded ~= false
		task.wait(1)
		if vape.Loaded and not userOff and not AntiCheatBypass.Enabled then
			AntiCheatBypass:Toggle()
		end
	end)
end)


run(function()
	local AutoQueue
	local Join
	local Hop

	AutoQueue = vape.Categories.Utility:CreateModule({
		Name = 'AutoQueue',
		Function = function(callback)
			if callback then
				local sent = 0
				repeat
					local status, timer = bedfight.GameInfo:FindFirstChild('Status'), bedfight.GameInfo:FindFirstChild('Timer')
					if not inMatch() and status and timer and status.Value == 'Started' and tick() - sent > 8 then
						-- the game lets you in for the first three minutes, after that it offers another server
						if timer.Value <= 180 then
							if Join.Enabled and lplr:GetAttribute('CanJoinGame') then
								sent = tick()
								fireRemote('Join')
							end
						elseif Hop.Enabled then
							sent = tick()
							fireRemote('QueueToOpenServer')
						end
					end
					task.wait(1)
				until not AutoQueue.Enabled
			end
		end,
		Tooltip = 'Gets you back into a match while you sit in the lobby or spectate'
	})
	Join = AutoQueue:CreateToggle({
		Name = 'Join running match',
		Default = true,
		Tooltip = 'Presses Join for you while the match is under three minutes old'
	})
	Hop = AutoQueue:CreateToggle({
		Name = 'Find open server',
		Default = true,
		Tooltip = 'Asks the game for a server with an open match once this one is closed'
	})
end)


run(function()
	local PlayEmote
	local Emote
	local Loop
	local Others
	local Mute
	local sounds = {}

	local function wheel()
		local folder, list = lplr:FindFirstChild('EmoteWheel'), {}
		for _, v in folder and folder:GetChildren() or {} do
			if v:IsA('StringValue') and v.Value ~= '' then
				table.insert(list, v)
			end
		end
		table.sort(list, function(a, b)
			return a.Name < b.Name
		end)
		return list
	end

	local function play()
		for _, slot in wheel() do
			if slot.Value == Emote.Value then
				bedfight.Signals.PlayEmote:Fire(slot.Name)
				if Others.Enabled then
					fireRemote('PlayEmote', tonumber(slot.Name) or slot.Name)
				end
				return
			end
		end
	end

	local function mute(enabled)
		for _, emote in bedfight.EmotesData do
			if type(emote) == 'table' and type(emote.FrameConfigs) == 'table' then
				for _, frame in emote.FrameConfigs do
					for _, config in frame do
						if type(config) == 'table' and config.Id then
							sounds[config] = sounds[config] or config.Id
							config.Id = enabled and 'rbxassetid://0' or sounds[config]
						end
					end
				end
			end
		end
	end

	PlayEmote = vape.Categories.Utility:CreateModule({
		Name = 'PlayEmote',
		Function = function(callback)
			mute(callback and Mute.Enabled)
			if callback then
				repeat
					play()
					-- the game allows one emote every three seconds
					task.wait(3.1)
				until not (PlayEmote.Enabled and Loop.Enabled)
			end
		end,
		Tooltip = 'Plays an emote from your wheel without opening it'
	})
	local names = {}
	for _, slot in wheel() do
		table.insert(names, slot.Value)
	end
	Emote = PlayEmote:CreateDropdown({
		Name = 'Emote',
		List = names
	})
	Loop = PlayEmote:CreateToggle({
		Name = 'Loop',
		Tooltip = 'Plays it again every three seconds'
	})
	Others = PlayEmote:CreateToggle({
		Name = 'Show to others',
		Default = true
	})
	Mute = PlayEmote:CreateToggle({
		Name = 'Mute',
		Function = function(callback)
			if PlayEmote.Enabled then
				mute(callback)
			end
		end,
		Tooltip = 'Silences emote sounds on your side'
	})
end)


run(function()
	local FastBreak
	local Cooldown
	local old = {}

	local function apply(enabled)
		for name, data in bedfight.MiningData do
			if type(data) == 'table' and data.Cooldown and not table.isfrozen(data) then
				old[name] = old[name] or data.Cooldown
				data.Cooldown = enabled and Cooldown.Value or old[name]
			end
		end
	end

	FastBreak = vape.Categories.Utility:CreateModule({
		Name = 'FastBreak',
		Function = function(callback)
			apply(callback)
		end,
		Tooltip = 'Shortens the wait between your pickaxe and axe hits'
	})
	Cooldown = FastBreak:CreateSlider({
		Name = 'Cooldown',
		Min = 0,
		Max = 0.3,
		Default = 0.1,
		Decimal = 100,
		Suffix = 's',
		Function = function()
			if FastBreak.Enabled then
				apply(true)
			end
		end,
		Tooltip = 'The game\'s own is 0.3'
	})
end)


run(function()
	local GhostDetector
	local seen = {}

	GhostDetector = vape.Categories.Utility:CreateModule({
		Name = 'GhostDetector',
		Function = function(callback)
			if callback then
				-- staff watch matches as ghosts, the game hides them from everyone else
				local function check(plr)
					if plr ~= lplr and plr:GetAttribute('Ghost') == true and not seen[plr] then
						seen[plr] = true
						notif('GhostDetector', plr.Name..' is watching this server as an invisible ghost.', 20, 'alert')
					end
				end
				local function watch(plr)
					GhostDetector:Clean(plr:GetAttributeChangedSignal('Ghost'):Connect(function()
						check(plr)
					end))
					check(plr)
				end
				GhostDetector:Clean(playersService.PlayerAdded:Connect(watch))
				for _, plr in playersService:GetPlayers() do
					watch(plr)
				end
			else
				table.clear(seen)
			end
		end,
		Tooltip = 'Warns you when someone joins or turns into a hidden spectator'
	})
end)


run(function()
	local InfJetpack

	InfJetpack = vape.Categories.Utility:CreateModule({
		Name = 'InfJetpack',
		Function = function(callback)
			if callback then
				-- the Booster kit burns this down on your side only
				InfJetpack:Clean(runService.Heartbeat:Connect(function()
					bedfight.JetpackState.Fuel = 1
				end))
			end
		end,
		Tooltip = 'Keeps the Booster kit\'s jetpack fuel full'
	})
end)


run(function()
	local PearlTP
	local Limit
	local ITEM = 'Teleorb'
	local lastThrow = 0

	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	rayCheck.RespectCanCollide = true

	local function getMouseTarget(mousePosition)
		rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, workspace:FindFirstChild('PlayersContainer'), workspace:FindFirstChild('ProjectilesContainer')}
		local ray = gameCamera:ViewportPointToRay(mousePosition.X, mousePosition.Y)
		local result = workspace:Raycast(ray.Origin, ray.Direction * 2048, rayCheck)
		return result and result.Position
	end

	-- the flattest throw at full speed that passes through the target. the game flies its
	-- projectiles as origin + velocity * t + gravity * t * t / 2
	local function solve(origin, target, speed, gravity)
		local delta = target - origin
		local flat = Vector3.new(delta.X, 0, delta.Z)
		local distance = flat.Magnitude
		if distance < 0.5 then
			return Vector3.new(0, delta.Y >= 0 and speed or -speed, 0)
		end
		if gravity <= 0 then
			return delta.Unit * speed
		end
		local root = speed ^ 4 - gravity * (gravity * distance * distance + 2 * delta.Y * speed * speed)
		if root < 0 then return nil end
		local angle = math.atan((speed * speed - math.sqrt(root)) / (gravity * distance))
		return flat.Unit * (math.cos(angle) * speed) + Vector3.new(0, math.sin(angle) * speed, 0)
	end

	-- walks the orb's own arc and reports the first thing it would hit before the target
	local function getPathObstacle(origin, velocity, gravity, target)
		local flight = ((target - origin) * Vector3.new(1, 0, 1)).Magnitude / math.max((velocity * Vector3.new(1, 0, 1)).Magnitude, 1)
		local steps = math.clamp(math.ceil(flight / 0.05), 1, 120)
		local previous = origin
		for i = 1, steps do
			local t = flight * i / steps
			local point = origin + velocity * t + Vector3.new(0, -gravity * t * t / 2, 0)
			if (point - target).Magnitude <= 1.5 then break end
			local segment = point - previous
			if segment.Magnitude > 0 then
				local hit = workspace:Raycast(previous, segment, rayCheck)
				if hit and (hit.Position - target).Magnitude > 1.5 then
					return hit
				end
			end
			previous = point
		end
		return nil
	end

	local function throwPearl(target)
		if not entitylib.isAlive then notif('PearlTP', 'Character missing.', 3, 'warning') return false end
		if (store.inventory[ITEM] or 0) <= 0 then notif('PearlTP', 'No teleorb available.', 3, 'warning') return false end
		if Limit.Enabled and heldName() ~= ITEM then
			notif('PearlTP', 'Hold a teleorb first.', 3, 'warning')
			return false
		end
		local data = bedfight.RangedData[ITEM]
		local meta = data and bedfight.ProjectilesData[data.Projectile or ITEM]
		if not (meta and meta.Speed) then
			notif('PearlTP', 'Teleorb projectile data unavailable.', 3, 'warning')
			return false
		end
		-- the game itself will not throw one while abilities are switched off
		local ok, abilities = pcall(function()
			return require(replicatedStorage.Modules.AbilitiesManager)
		end)
		if ok and type(abilities) == 'table' and abilities.Enabled == false then
			notif('PearlTP', 'Abilities are switched off right now.', 3, 'warning')
			return false
		end
		if tick() - lastThrow < (data.Cooldown or 0.2) then return false end

		local speed, gravity = meta.Speed.Max, math.abs(meta.Gravity.Y)
		-- the server launches from the root it follows, offset the way the camera that is sent faces
		local root = realRoot()
		local camera = CFrame.lookAt(gameCamera.CFrame.Position, target)
		local origin, velocity
		for _ = 1, 2 do
			origin = root.Position + camera:VectorToWorldSpace(data.Offset)
			velocity = solve(origin, target, speed, gravity)
			if not velocity then
				notif('PearlTP', 'Target is too far away for the teleorb.', 4, 'warning')
				return false
			end
			camera = CFrame.lookAlong(gameCamera.CFrame.Position, velocity.Unit)
		end

		local obstacle = getPathObstacle(origin, velocity, gravity, target)
		if obstacle and obstacle.Instance then
			notif('PearlTP', 'Obstacle in the way of the teleorb ('..obstacle.Instance.Name..')', 4, 'warning')
			return false
		end

		local container = workspace:FindFirstChild('ProjectilesContainer')
		if not container then return false end
		-- the same local projectile the game makes for a shot. its id pairs the shot with the server's
		local made, id = pcall(function()
			local shot = bedfight.ProjectilesController.new(nil, velocity, meta)
			shot:AddProjectile(meta.Projectile or data.Projectile or ITEM)
			shot.ProjectileRoot.CFrame = CFrame.lookAlong(origin, velocity.Unit)
			shot.UpdatedVelocity = velocity
			shot.Projectile.Parent = container
			return shot:Play()
		end)
		if not (made and id) then return false end

		lastThrow = tick()
		-- the server takes the switch and the throw in the order they are sent, the hotbar is left alone
		equipServer(ITEM, 'PearlTP')
		fireRemote('ShootProjectile', id, ITEM, velocity.Unit, velocity, camera)
		task.delay(0.4, syncTool, 'PearlTP')
		return true
	end

	PearlTP = vape.Categories.Utility:CreateModule({
		Name = 'PearlTP',
		Function = function(callback)
			if not callback then return end
			local target = entitylib.isAlive and getMouseTarget(inputService:GetMouseLocation())
			if not target then
				notif('PearlTP', 'No valid position under the mouse.', 3, 'warning')
				PearlTP:Toggle()
				return
			end
			throwPearl(target)
			PearlTP:Toggle()
		end,
		Tooltip = 'Throws a teleorb to the position under your mouse on the fastest arc that reaches it.\nYour hotbar is not touched.'
	})

	Limit = PearlTP:CreateToggle({Name = 'Limit to item', Tooltip = 'Only activates when you are already holding a teleorb'})
end)


run(function()
	local Scaffold
	local Expand
	local Tower
	local Downwards
	local Diagonal
	local LimitItem
	local Mouse
	local FillColor
	local OutlineColor
	local label, visualBlock, visualTween, visualPos
	local nextId = 500000
	local lastPlace = 0
	local lastpos = Vector3.zero

	-- the game's own two steps: a local stand-in block, then the request with its id
	local function place(name, position)
		local template = bedfight.Blocks:FindFirstChild(name)
		local container = workspace:FindFirstChild('FakeBlocksContainer')
		if not (template and container) then return end
		nextId += 1
		local id, queue = nextId, bedfight.Block.BlocksInQueue
		local fake = template:Clone()
		fake:PivotTo(CFrame.new(position))
		fake.Parent = container
		queue[id] = {Block = fake, LastTime = time()}
		fireRemote('PlaceBlock', name, id, position)
		-- the server answers by removing it. unanswered ones go after a while
		task.delay(3, function()
			if queue[id] then
				queue[id] = nil
			end
			fake:Destroy()
		end)
	end

	-- the game's own answer to "may a block go here"
	local function buildable(position)
		local ok, info = bedfight.Block.GetBuildResult(nil, position, 3)
		return ok and info and not info.InsideAntiBuild and info.InBounds ~= false, info
	end

	local function clearVisual()
		if visualTween then
			visualTween:Cancel()
			visualTween = nil
		end
		if visualBlock then
			visualBlock.Parent = nil
		end
		visualPos = nil
	end

	local function showVisual(position)
		if not visualBlock or visualPos == position then return end
		if visualTween then
			visualTween:Cancel()
			visualTween = nil
		end
		if visualBlock.Parent == gameCamera then
			visualTween = tweenService:Create(visualBlock, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = CFrame.new(position)})
			visualTween:Play()
		else
			visualBlock.CFrame = CFrame.new(position)
			visualBlock.Parent = gameCamera
		end
		visualPos = position
	end

	Scaffold = vape.Categories.Utility:CreateModule({
		Name = 'Scaffold',
		ExtraText = function()
			return tostring(Expand.Value)
		end,
		Function = function(callback)
			if label then
				label.Visible = callback
			end
			if callback then
				local switched = false
				repeat
					local placed = false
					local amount = 0
					if canFight() then
						local held = heldName()
						local block = LimitItem.Enabled and (held and bedfight.Blocks:FindFirstChild(held) and getItem(held) and held) or (not LimitItem.Enabled and getBlock())
						amount = block and getItem(block) or 0
						if block and Mouse.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
							block = nil
						end
						if block then
							local hum, root = entitylib.character.Humanoid, entitylib.character.RootPart
							local sneak = Downwards.Enabled and inputService:IsKeyDown(Enum.KeyCode.LeftShift) and not inputService:GetFocusedTextBox()
							if Tower.Enabled and inputService:IsKeyDown(Enum.KeyCode.Space) and not inputService:GetFocusedTextBox() and hum.MoveDirection.Magnitude < 0.1 then
								root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 32, root.AssemblyLinearVelocity.Z)
							end

							local feet = root.Position - Vector3.new(0, entitylib.character.HipHeight + (sneak and 4.5 or 1.5), 0)
							local move = hum.MoveDirection
							for i = 0, Expand.Value - 1 do
								local position = snap(feet + move * (i * 3))
								local previous = lastpos
								if i == 0 then
									-- walking at 45 degrees, the block stays put until the next one touches it corner to corner
									if Diagonal.Enabled and move.Magnitude > 0.1 and math.abs(math.round(math.deg(math.atan2(-move.X, -move.Z)) / 45) * 45) % 90 == 45 then
										local dt = lastpos - position
										if ((dt.X == 0 and dt.Z ~= 0) or (dt.X ~= 0 and dt.Z == 0)) and ((lastpos - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 then
											position = lastpos
										end
									end
									lastpos = position
									showVisual(position)
								end

								local ok, info = buildable(position)
								if not ok and i == 0 and info and not info.Collided and not info.Connected and previous.Y == position.Y then
									-- nothing next to it yet: fill the corner between the last block and this one first
									for _, filler in {Vector3.new(previous.X, position.Y, position.Z), Vector3.new(position.X, position.Y, previous.Z)} do
										if filler ~= position and buildable(filler) then
											position, ok = filler, true
											break
										end
									end
								end
								if ok then
									placed = true
									switched = true
									if tick() - lastPlace >= bedfight.BlocksData.Default.Cooldown and (equipServer(block, 'Scaffold') or (store.sentAt and tick() - store.sentAt > 0.6)) then
										lastPlace = tick()
										place(block, position)
									end
									break
								end
							end
						else
							clearVisual()
						end
					else
						clearVisual()
					end

					if label then
						label.Text = amount..' <font color="rgb(170, 170, 170)">(Scaffold)</font>'
						label.TextColor3 = Color3.fromHSV(math.clamp(amount / 128, 0, 1) / 2.8, 0.86, 1)
					end
					if switched and not placed and tick() - lastPlace > 0.4 then
						switched = false
						syncTool('Scaffold')
					end
					task.wait(0.03)
				until not Scaffold.Enabled
				clearVisual()
			else
				syncTool('Scaffold')
				clearVisual()
			end
		end,
		Tooltip = 'Places blocks under you as you walk'
	})
	Expand = Scaffold:CreateSlider({
		Name = 'Expand',
		Min = 1,
		Max = 5,
		Default = 1,
		Tooltip = 'How many blocks ahead it builds'
	})
	Tower = Scaffold:CreateToggle({
		Name = 'Tower',
		Default = true,
		Tooltip = 'Hold Space while standing still to build straight up'
	})
	Downwards = Scaffold:CreateToggle({
		Name = 'Downwards',
		Default = true,
		Tooltip = 'Hold Shift to build one block lower'
	})
	Diagonal = Scaffold:CreateToggle({
		Name = 'Diagonal',
		Tooltip = 'Walking diagonally builds a straight diagonal line instead of a staircase. Where the game refuses a block that only touches by its corner, the corner is filled in first'
	})
	LimitItem = Scaffold:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only while you hold a block'
	})
	Mouse = Scaffold:CreateToggle({Name = 'Require mouse down'})
	Scaffold:CreateToggle({
		Name = 'Visual',
		Function = function(callback)
			FillColor.Object.Visible = callback
			OutlineColor.Object.Visible = callback
			if callback then
				visualBlock = Instance.new('Part')
				visualBlock.Size = Vector3.new(3, 3, 3)
				visualBlock.Anchored = true
				visualBlock.CanCollide = false
				visualBlock.CanQuery = false
				visualBlock.CanTouch = false
				visualBlock.CastShadow = false
				visualBlock.Transparency = 1
				local selection = Instance.new('SelectionBox')
				selection.Adornee = visualBlock
				selection.LineThickness = 0.04
				selection.Color3 = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
				selection.Transparency = 1 - OutlineColor.Opacity
				selection.SurfaceColor3 = Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
				selection.SurfaceTransparency = 1 - FillColor.Opacity
				selection.Parent = visualBlock
			else
				clearVisual()
				if visualBlock then
					visualBlock:Destroy()
					visualBlock = nil
				end
			end
		end,
		Tooltip = 'Renders an overlay on the block about to be placed'
	})
	FillColor = Scaffold:CreateColorSlider({
		Name = 'Fill colour',
		DefaultSat = 0,
		DefaultOpacity = 0.4,
		Darker = true,
		Visible = false,
		Function = function(hue, sat, val, opacity)
			if visualBlock then
				visualBlock.SelectionBox.SurfaceColor3 = Color3.fromHSV(hue, sat, val)
				visualBlock.SelectionBox.SurfaceTransparency = 1 - opacity
			end
		end
	})
	OutlineColor = Scaffold:CreateColorSlider({
		Name = 'Outline colour',
		DefaultValue = 0,
		Darker = true,
		Visible = false,
		Function = function(hue, sat, val, opacity)
			if visualBlock then
				visualBlock.SelectionBox.Color3 = Color3.fromHSV(hue, sat, val)
				visualBlock.SelectionBox.Transparency = 1 - opacity
			end
		end
	})
	Scaffold:CreateToggle({
		Name = 'Block Count',
		Function = function(callback)
			if callback then
				label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 60)
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Text = '0'
				label.TextColor3 = Color3.new(0, 1, 0)
				label.TextSize = 18
				label.RichText = true
				label.Font = Enum.Font.Arial
				label.Visible = Scaffold.Enabled
				label.Parent = vape.gui
			elseif label then
				label:Destroy()
				label = nil
			end
		end
	})
end)


run(function()
	local ShopClicker
	local HoldDelay
	local CPS
	local guiService = cloneref(game:GetService('GuiService'))
	local holding = false
	local clickThread
	local shopList, shopKit

	local function shopGui()
		local gui = lplr.PlayerGui:FindFirstChild('ItemShopGui')
		return gui and gui:IsA('LayerCollector') and gui.Enabled and gui or nil
	end

	-- every item button sits in a category frame inside the shop's list, named after its item
	local function getHoveredItem(gui)
		local list = gui:FindFirstChild('ItemsListFrame', true)
		if not list then return nil end
		local mouse = inputService:GetMouseLocation() - guiService:GetGuiInset()
		for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y) do
			local obj = v
			while obj and obj ~= gui do
				local category = obj.Parent
				if category and category.Parent == list then
					return obj.Name
				end
				obj = category
			end
		end
		return nil
	end

	local function find(name)
		local value = lplr:FindFirstChild('Kit')
		local kit = value and value.Value or ''
		if not shopList or shopKit ~= kit then
			shopList, shopKit = bedfight.ItemShopData.GetItemShop(false, kit), kit
		end
		for _, entry in shopList do
			for _, data in entry.List do
				if data.Name == name then
					return entry.Category, data
				end
			end
		end
	end

	-- the stand of the shop that is open, the way the game's own buy button finds it
	local function stand(gui)
		local module = gui:FindFirstChild('InfoFrameHandler')
		local ok, handler = pcall(function()
			return module and require(module)
		end)
		local part = ok and type(handler) == 'table' and handler.Prompt
		if typeof(part) == 'Instance' and part:IsDescendantOf(workspace) then
			return part
		end
		local best, dist = nil, 10
		for _, v in collectionService:GetTagged('ItemShopPrompt') do
			if v:IsA('BasePart') and v:IsDescendantOf(workspace) then
				local mag = (v.Position - entitylib.character.RootPart.Position).Magnitude
				if mag <= dist then
					best, dist = v, mag
				end
			end
		end
		return best
	end

	local function purchase(gui, name)
		if not entitylib.isAlive then return end
		local category, data = find(name)
		if not category then return end
		-- the game's own "can I buy this" answer
		local module = gui:FindFirstChild('ItemShopHandler')
		local ok, result = pcall(function()
			return require(module).GetBuyResult(name, data)
		end)
		if not ok or result ~= 'Buy' then return end
		local part = stand(gui)
		if part then
			fireRemote('PurchaseItemShopItem', part, category, name)
		end
	end

	local function startClicking(name)
		if clickThread then
			task.cancel(clickThread)
		end
		clickThread = task.spawn(function()
			repeat
				local gui = shopGui()
				if gui then
					purchase(gui, name)
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
					local gui = shopGui()
					local name = gui and getHoveredItem(gui)
					if not name then return end

					holding = true
					task.delay(HoldDelay.Value, function()
						local open = shopGui()
						if holding and open and getHoveredItem(open) == name then
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
		Tooltip = 'Hold on a shop item to rapidly buy it'
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
	local AutoVoidDrop
	local PearlCheck
	local BalloonCheck
	-- how far under the lowest block of the map the fall has to be before anything is dropped
	local MARGIN = 25
	local resources

	local orbRay = RaycastParams.new()
	orbRay.RespectCanCollide = true
	orbRay.FilterType = Enum.RaycastFilterType.Exclude

	-- every stack the module gets rid of on the way down: what the shops are paid in
	local function voidItems()
		if not resources then
			resources = {}
			for name, data in bedfight.ItemsData do
				if type(data) == 'table' and data.Class == 'Resources' and data.CanDrop ~= false then
					table.insert(resources, name)
				end
			end
		end
		return resources
	end

	-- the bottom of the lowest block the map has, walked a little each frame
	local function lowest(container)
		local low, started = math.huge, os.clock()
		for _, v in container:GetDescendants() do
			if v:IsA('BasePart') then
				local point = v.Position.Y - v.Size.Y / 2
				if point < low then
					low = point
				end
			end
			if os.clock() - started > 0.002 then
				task.wait()
				started = os.clock()
				if not AutoVoidDrop.Enabled then return nil end
			end
		end
		return low
	end

	-- follows a teleorb you threw along its own arc and says whether it comes down on something
	local function orbLands(shot, floor)
		local root = shot.ProjectileRoot
		local velocity = shot.UpdatedVelocity
		local gravity = shot.ProjectileData and shot.ProjectileData.Gravity
		if not (root and root.Parent and typeof(velocity) == 'Vector3' and typeof(gravity) == 'Vector3') then return false end
		local position = root.Position
		orbRay.FilterDescendantsInstances = {lplr.Character, gameCamera, workspace:FindFirstChild('PlayersContainer'), workspace:FindFirstChild('ProjectilesContainer')}
		local step = 0.05
		for _ = 1, 120 do
			local nextPosition = position + velocity * step
			local result = workspace:Raycast(position, nextPosition - position, orbRay)
			if result then
				return result.Position.Y > floor
			end
			if nextPosition.Y < floor then return false end
			position = nextPosition
			velocity += gravity * step
		end
		return false
	end

	local function orbWillSave(floor)
		local mine = '^'..lplr.UserId..'_'
		for key, shot in bedfight.ProjectilesController.PlayingProjectiles do
			if type(key) == 'string' and key:find(mine) and shot.ProjectileName == 'Teleorb' and orbLands(shot, floor) then
				return true
			end
		end
		return false
	end

	local function floating()
		local amount = lplr:FindFirstChild('BalloonsAmount')
		return (amount and amount.Value or 0) > 0 or (store.inventory.Balloon or 0) > 0 or (store.inventory['Skull Balloon'] or 0) > 0
	end

	AutoVoidDrop = vape.Categories.Utility:CreateModule({
		Name = 'AutoVoidDrop',
		Function = function(callback)
			if callback then
				local map, floor
				local dropped = 0
				repeat
					local container = inMatch() and mapBlocks()
					if container ~= map then
						map, floor = container, nil
						if container then
							local low = lowest(container)
							if low and low < math.huge and mapBlocks() == container then
								floor = low - MARGIN
							else
								map = nil
							end
						end
					end

					if floor and entitylib.isAlive and tick() - dropped > 1 then
						local root = bodyRoot()
						-- under the whole map with nothing below, placed blocks included
						if root.Position.Y < floor and not workspace:Raycast(root.Position, Vector3.new(0, -500, 0), blockParams()) then
							local saved = (BalloonCheck.Enabled and floating()) or (PearlCheck.Enabled and orbWillSave(floor))
							if not saved then
								for _, name in voidItems() do
									if (store.inventory[name] or 0) > 0 then
										fireRemote('DropItem', name, 'All')
										dropped = tick()
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoVoidDrop.Enabled
			end
		end,
		Tooltip = 'Drops your iron, diamonds and emeralds when you fall into the void'
	})
	PearlCheck = AutoVoidDrop:CreateToggle({
		Name = 'Pearl check',
		Default = true,
		Tooltip = 'Keeps your loot if a teleorb you threw is still in the air and looks like it lands on ground'
	})
	BalloonCheck = AutoVoidDrop:CreateToggle({
		Name = 'Balloon check',
		Default = true,
		Tooltip = 'Keeps your loot while you have a balloon out or carry one'
	})
end)


run(function()
	local Breaker
	local BreakerType
	local BreakChance
	local CombatOnly
	local Angle
	local Range
	local UpdateRate
	local Custom
	local Bed
	local SelfBreak
	local AutoTool
	local LimitItem
	local Animation
	local box
	local lock, lostAt
	local lastHit, jitter = 0, 0
	local confirmed, warned = false, false
	local rng = Random.new()
	local tracks, viewTracks = {}, {}
	local skip = setmetatable({}, {__mode = 'k'})
	local left = setmetatable({}, {__mode = 'k'})
	local full = {}
	-- how far around a bed its cover is read, in blocks: sideways, down and up
	local SIDE, DOWN, UP = 5, 2, 4
	local NEIGHBOURS = {
		{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}
	}
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	local routeAt = 0
	local FACES = {
		Vector3.zero,
		Vector3.new(1.35, 0, 0), Vector3.new(-1.35, 0, 0),
		Vector3.new(0, 1.35, 0), Vector3.new(0, -1.35, 0),
		Vector3.new(0, 0, 1.35), Vector3.new(0, 0, -1.35)
	}

	local function isLegit()
		return BreakerType.Value == 'Legit'
	end

	local function unlock()
		lock, lostAt = nil, nil
	end

	-- a block somebody placed, with the name the game keeps its kind under
	local function placedBlock(part)
		local placed = workspace:FindFirstChild('PlayersBlocksContainer')
		if not (placed and part:IsDescendantOf(placed)) then return nil end
		local object = part.Parent:IsA('Model') and part.Parent or part
		return object, object.Parent.Name
	end

	local function toolFor(kind)
		local held = heldName()
		local data = held and bedfight.MiningData[held]
		local holding = type(data) == 'table' and data.Cooldown ~= nil
		if (LimitItem.Enabled or not AutoTool.Enabled) and not holding then return nil end
		if AutoTool.Enabled then
			return getTool(kind)
		end
		return held, data.Damages and data.Damages[kind] or data.DefaultDamage or 0
	end

	local function hitsFor(object, kind)
		local tool, damage = toolFor(kind)
		if not tool or (damage or 0) <= 0 then return math.huge end
		return math.ceil((left[object] or full[kind] or 30) / damage)
	end

	-- the middle of the bed, each of its halves and the spot on it nearest you
	local function probes(hitbox, from)
		local cf, size = hitbox.CFrame, hitbox.Size
		local long = size.X > size.Z and Vector3.new(size.X / 4, 0, 0) or Vector3.new(0, 0, size.Z / 4)
		local half = size / 2 - Vector3.new(0.3, 0.3, 0.3)
		local near = cf:PointToObjectSpace(from)
		return {
			cf * Vector3.new(math.clamp(near.X, -half.X, half.X), math.clamp(near.Y, -half.Y, half.Y), math.clamp(near.Z, -half.Z, half.Z)),
			hitbox.Position,
			cf * long,
			cf * -long
		}
	end

	-- every placed block on the line to a point of the bed, nearest first.
	-- nothing comes back when a map block is in the way, those cannot be mined
	local function trace(from, point, bed, params)
		local list = {}
		local origin = from
		for _ = 1, 10 do
			local ray = point - origin
			if ray.Magnitude < 0.05 then
				return list
			end
			local hit = workspace:Raycast(origin, ray, params)
			if not hit then
				return list
			end
			if hit.Instance:IsDescendantOf(bed) then
				return list, hit
			end
			local object, kind = placedBlock(hit.Instance)
			if not object then return nil end
			table.insert(list, {Object = object, Part = hit.Instance, Kind = kind})
			origin = hit.Position + ray.Unit * 0.1
		end
		return nil
	end

	-- the first thing a ray from you meets, the way the game's own pickaxe looks for a block
	local function visible(from, part, params)
		for _, offset in FACES do
			local point = part.Position + offset
			local hit = workspace:Raycast(from, point - from, params)
			if hit and hit.Instance == part then
				return hit, point
			end
		end
	end

	local function cellId(x, y, z)
		return (x + 8) * 256 + (y + 8) * 16 + (z + 8)
	end

	-- the cheapest way from open air to the bed, counted in hits and looked for from every side.
	-- comes back as the bed itself when a side of it is already open, else as the outermost block
	-- of that way, with the open spot it can be hit from
	local function route(bed, hitbox, body, reach)
		local placed = workspace:FindFirstChild('PlayersBlocksContainer')
		local centre = snap(hitbox.Position)
		local list = {}
		if placed then
			table.insert(list, placed)
		end
		local map = mapBlocks()
		if map then
			table.insert(list, map)
		end
		overlap.FilterDescendantsInstances = list

		-- false is a map block, a table is a block somebody placed
		local grid = {}
		local size = Vector3.new(SIDE * 2 + 1, DOWN + UP + 1, SIDE * 2 + 1) * 3
		local middle = centre + Vector3.new(0, (UP - DOWN) * 1.5, 0)
		for _, part in workspace:GetPartBoundsInBox(CFrame.new(middle), size, overlap) do
			if not part.CanCollide then continue end
			local offset = part.Position - centre
			if placed and part:IsDescendantOf(placed) then
				local object, kind = placedBlock(part)
				local x, y, z = math.round(offset.X / 3), math.round(offset.Y / 3), math.round(offset.Z / 3)
				if object and math.abs(x) <= SIDE and math.abs(z) <= SIDE and y >= -DOWN and y <= UP then
					grid[cellId(x, y, z)] = {Object = object, Part = part, Kind = kind}
				end
			else
				-- a piece of the map fills every cell its middle reaches
				local cf, half = part.CFrame, part.Size / 2
				local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
				local ex = math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(l.X) * half.Z - 1
				local ey = math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(l.Y) * half.Z - 1
				local ez = math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(l.Z) * half.Z - 1
				for x = math.max(-SIDE, math.ceil((offset.X - ex) / 3)), math.min(SIDE, math.floor((offset.X + ex) / 3)) do
					for y = math.max(-DOWN, math.ceil((offset.Y - ey) / 3)), math.min(UP, math.floor((offset.Y + ey) / 3)) do
						for z = math.max(-SIDE, math.ceil((offset.Z - ez) / 3)), math.min(SIDE, math.floor((offset.Z + ez) / 3)) do
							grid[cellId(x, y, z)] = false
						end
					end
				end
			end
		end

		-- the two halves of the bed
		local long = hitbox.Size.X > hitbox.Size.Z and Vector3.new(hitbox.Size.X / 4, 0, 0) or Vector3.new(0, 0, hitbox.Size.Z / 4)
		local dist, prev, where, isBed = {}, {}, {}, {}
		local buckets = {[0] = {}}
		for _, point in {hitbox.CFrame * long, hitbox.CFrame * -long} do
			local offset = snap(point) - centre
			local x, y, z = math.round(offset.X / 3), math.round(offset.Y / 3), math.round(offset.Z / 3)
			local id = cellId(x, y, z)
			if not isBed[id] then
				isBed[id] = true
				dist[id] = 0
				where[id] = {x, y, z}
				table.insert(buckets[0], id)
			end
		end

		local goal
		local cost, highest = 0, 0
		while cost <= highest and not goal do
			local bucket = buckets[cost]
			local index = 1
			while bucket and index <= #bucket do
				local id = bucket[index]
				index += 1
				if dist[id] ~= cost then continue end
				local at = where[id]
				local x, y, z = at[1], at[2], at[3]
				if not isBed[id] and not grid[id] and (math.abs(x) == SIDE or math.abs(z) == SIDE or y == UP) then
					-- open air at the edge of what was read: this is outside
					goal = id
					break
				end
				for _, step in NEIGHBOURS do
					local nx, ny, nz = x + step[1], y + step[2], z + step[3]
					if math.abs(nx) > SIDE or math.abs(nz) > SIDE or ny < -DOWN or ny > UP then continue end
					local nid = cellId(nx, ny, nz)
					if isBed[nid] then continue end
					local cell = grid[nid]
					local extra = 0
					if cell == false then
						continue
					elseif cell then
						if (cell.Part.Position - body).Magnitude > reach or (skip[cell.Object] or 0) > tick() then continue end
						extra = hitsFor(cell.Object, cell.Kind)
						if extra == math.huge then continue end
					end
					local total = cost + extra
					if total < (dist[nid] or math.huge) then
						dist[nid] = total
						prev[nid] = id
						where[nid] = {nx, ny, nz}
						buckets[total] = buckets[total] or {}
						table.insert(buckets[total], nid)
						highest = math.max(highest, total)
					end
				end
			end
			cost += 1
		end
		if not goal then return nil end

		local function world(id)
			local at = where[id]
			return centre + Vector3.new(at[1], at[2], at[3]) * 3
		end
		-- walked from outside in, the first block met is the one to start on
		local open, id = goal, prev[goal]
		while id do
			if isBed[id] then
				local from, to = world(open), world(id)
				-- a side of the bed is open, just not the one facing you
				return dist[goal], {Object = bed, Part = hitbox, Kind = 'Bed', Bed = bed, Cell = to, From = from, Direction = (to - from).Unit, Routed = true, BedCell = to}
			end
			local cell = grid[id]
			if cell then
				local from = world(open)
				return dist[goal], {Object = cell.Object, Part = cell.Part, Kind = cell.Kind, Bed = bed, Cell = snap(cell.Part.Position), From = from, Direction = (cell.Part.Position - from).Unit, Routed = true}
			end
			open, id = id, prev[id]
		end
		return nil
	end

	local function play(cache, animator, anim)
		if not (anim and animator) then return end
		if cache.Animator ~= animator then
			table.clear(cache)
			cache.Animator = animator
		end
		cache[anim] = cache[anim] or animator:LoadAnimation(anim)
		cache[anim]:Play()
	end

	local function swing(tool)
		local data = bedfight.MiningData[tool]
		local anims = data.Animations or bedfight.MiningData.DefaultAnimation
		local anim = anims and anims.Mine
		if not anim then return end
		play(tracks, entitylib.character.Humanoid:FindFirstChildOfClass('Animator'), anim.Animation)
		if heldName() == tool then
			play(viewTracks, bedfight.ViewModelHandler.ViewModelAnimator, anim.ViewModel)
		end
	end

	-- one hit, no sooner than the tool allows. the server only has to hold the tool
	local function strike(target)
		local tool = toolFor(target.Kind)
		if not tool then return end
		local now = tick()
		local legit = isLegit()
		local cooldown = bedfight.MiningData[tool].Cooldown or 0.3
		if now - lastHit < cooldown + (legit and jitter or 0) then return end
		if not (equipServer(tool, 'Breaker') or (store.sentAt and now - store.sentAt > 0.6)) then return end
		lastHit, jitter = now, rng:NextNumber(0, 0.05)
		if legit and BreakChance.Value < 100 and (not CombatOnly.Enabled or store.inCombat()) and rng:NextNumber(0, 100) >= BreakChance.Value then return end
		target.Sent = (target.Sent or 0) + 1
		fireRemote('MineBlock', tool, target.Object, target.Cell, target.From, target.Direction)
		if Animation.Enabled then
			pcall(swing, tool)
		end
	end

	local function step()
		local legit = isLegit()
		local body = entitylib.character.RootPart.Position
		-- a pickaxe in your hand is aimed from the camera, the blatant one from your chest
		local from = legit and gameCamera.CFrame.Position or body + Vector3.new(0, 1.5, 0)
		local look = gameCamera.CFrame.LookVector
		local reach = Range.Value
		local params = blockParams()
		local team = lplr.Team.Name

		local function allowed(position)
			if (position - body).Magnitude > reach then return false end
			if legit and Angle.Value < 360 then
				local dir = position - from
				if dir.Magnitude > 0.5 and math.deg(math.acos(math.clamp(look:Dot(dir.Unit), -1, 1))) > Angle.Value / 2 then return false end
			end
			return true
		end

		local target, candidate, score = nil, nil, math.huge
		local reachable = {}
		local beds = Bed.Enabled and workspace:FindFirstChild('BedsContainer')
		for _, bed in beds and beds:GetChildren() or {} do
			local hitbox = bed:FindFirstChild('BedHitbox')
			if not hitbox or bed:GetAttribute('Team') == team or (hitbox.Position - body).Magnitude > reach + 4 then continue end
			table.insert(reachable, {bed, hitbox})
			for _, point in probes(hitbox, from) do
				local list, hit = trace(from, point, bed, params)
				if not list then continue end
				if #list == 0 then
					-- an open line to the bed always wins over anything in front of it
					local cell = hit and snap(hit.Position - hit.Normal * 1.5) or snap(point)
					if allowed(cell) and toolFor('Bed') then
						target = {Object = bed, Part = hitbox, Kind = 'Bed', Cell = cell, From = from, Direction = (point - from).Unit}
						break
					end
				elseif legit and not lock then
					local first = list[1]
					if not allowed(first.Part.Position) or (skip[first.Object] or 0) > tick() then continue end
					-- nearest first, and fewer blocks behind it is better
					local cost = (first.Part.Position - body).Magnitude + #list * 3
					if cost < score then
						first.Bed = bed
						candidate, score = first, cost
					end
				end
			end
			if target then break end
		end

		if target then
			unlock()
		else
			if lock then
				local gone = not lock.Object.Parent or not lock.Part.Parent or (lock.Bed and not (lock.Bed.Parent and Bed.Enabled))
				if gone or (lock.Part.Position - body).Magnitude > reach or not toolFor(lock.Kind) then
					unlock()
				elseif confirmed and (lock.Sent or 0) >= 6 and tick() - (lock.Progress or lock.Since) > 2.5 then
					-- hits that change nothing are not reaching it
					skip[lock.Object] = tick() + 4
					unlock()
				end
			end

			if not legit and not lock and tick() - routeAt > 0.2 then
				-- the fewest hits to any bed in reach, whichever side that is and however far the block is from you
				routeAt = tick()
				local best = math.huge
				for _, v in reachable do
					local cost, found = route(v[1], v[2], body, reach)
					if cost and cost < best and toolFor(found.Kind) then
						best, candidate = cost, found
					end
				end
			end
			if not lock and candidate then
				lock = candidate
				lock.Since = tick()
			end

			if not lock and #Custom.ListEnabled > 0 then
				local placed = workspace:FindFirstChild('PlayersBlocksContainer')
				local own = team..' Wool'
				local found = {}
				for _, folder in placed and placed:GetChildren() or {} do
					local wanted = false
					for _, name in Custom.ListEnabled do
						if name:lower() == folder.Name:lower() then
							wanted = true
							break
						end
					end
					if not wanted then continue end
					for _, object in folder:GetChildren() do
						local part = object:IsA('BasePart') and object or object:FindFirstChildWhichIsA('BasePart', true)
						if part and (SelfBreak.Enabled or object.Name ~= own) and (skip[object] or 0) <= tick() and allowed(part.Position) then
							table.insert(found, {Object = object, Part = part, Kind = folder.Name, Distance = (part.Position - body).Magnitude})
						end
					end
				end
				table.sort(found, function(a, b)
					return a.Distance < b.Distance
				end)
				for i = 1, math.min(#found, 6) do
					if toolFor(found[i].Kind) and (not legit or visible(from, found[i].Part, params)) then
						lock = found[i]
						lock.Since = tick()
						break
					end
				end
			end

			if lock and not target then
				local hit, point = visible(from, lock.Part, params)
				if legit and not (hit and allowed(lock.Part.Position)) then
					-- out of sight or out of your view for a moment is not a reason to start on another block
					lostAt = lostAt or tick()
					if tick() - lostAt > 1.5 then
						unlock()
					end
				elseif lock.Routed and not hit then
					-- not in your line of sight, so the hit comes from the open side the route found.
					-- every other three hits it is tried straight from you, whichever the server takes
					lostAt = nil
					lock.Side = lock.Side or {lock.From, lock.Direction}
					if (lock.Sent or 0) % 6 < 3 then
						lock.From, lock.Direction = lock.Side[1], lock.Side[2]
					else
						lock.From, lock.Direction = from, (lock.Part.Position - from).Unit
					end
					lock.Cell = lock.BedCell or snap(lock.Part.Position)
					target = lock
				else
					lostAt = nil
					point = point or lock.Part.Position
					lock.Cell = hit and snap(hit.Position - hit.Normal * 1.5) or snap(lock.Part.Position)
					lock.From, lock.Direction = from, (point - from).Unit
					target = lock
				end
			end
		end

		if target then
			strike(target)
		end
		return target, lock ~= nil
	end

	Breaker = vape.Categories.World:CreateModule({
		Name = 'Breaker',
		Function = function(callback)
			if callback then
				local display = replicatedStorage:FindFirstChild('Remotes') and replicatedStorage.Remotes:FindFirstChild('DisplayBlockHealth')
				if display then
					-- the server tells you what a block has left every time one is hit
					Breaker:Clean(display.OnClientEvent:Connect(function(object, _, health, max)
						if typeof(object) ~= 'Instance' or type(health) ~= 'number' then return end
						left[object] = health
						if type(max) == 'number' and object.Parent and object.Parent.Parent == workspace:FindFirstChild('PlayersBlocksContainer') then
							full[object.Parent.Name] = max
						end
						if lock and lock.Object == object then
							lock.Progress = tick()
							confirmed = true
						end
					end))
				end

				local switched = false
				repeat
					local target, busy
					if canFight() and inMatch() then
						local ok, a, b = pcall(step)
						if ok then
							target, busy = a, b
						elseif not warned then
							warned = true
							warn('[AetherV2] Breaker: '..tostring(a))
						end
					else
						unlock()
					end

					if target then
						switched = true
					elseif switched and not busy then
						switched = false
						syncTool('Breaker')
					end
					if box then
						box.Adornee = target and target.Part or nil
						if target then
							box.Size = target.Part.Size + Vector3.new(0.1, 0.1, 0.1)
						end
					end
					task.wait(1 / UpdateRate.Value)
				until not Breaker.Enabled
			else
				unlock()
				syncTool('Breaker')
				if box then
					box.Adornee = nil
				end
			end
		end,
		ExtraText = function()
			return BreakerType.Value
		end,
		Tooltip = 'Mines enemy beds near you with your pickaxe or axe.\nYour hotbar is not touched.'
	})
	BreakerType = Breaker:CreateDropdown({
		Name = 'Breaker Type',
		List = {'Blatant', 'Legit'},
		Default = 'Blatant',
		Tooltip = 'Blatant - the way to the bed that takes the fewest hits, from whichever side that is, through walls and at any angle\nLegit - only blocks you could really mine: in view of your camera, the nearest one first, and it stays on a block until it is gone',
		Function = function()
			unlock()
		end
	})
	BreakChance = Breaker:CreateSlider({
		Name = 'Break Chance',
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%',
		Darker = true,
		Visible = function()
			return BreakerType.Value == 'Legit'
		end,
		Tooltip = 'How many of your mining hits are actually sent. The rest are skipped like a missed swing'
	})
	CombatOnly = Breaker:CreateToggle({
		Name = 'Only while in combat',
		Darker = true,
		Visible = function()
			return BreakerType.Value == 'Legit'
		end,
		Tooltip = 'Break Chance only applies while you are in a fight. Out of combat every hit is sent'
	})
	Angle = Breaker:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 120,
		Darker = true,
		Visible = function()
			return BreakerType.Value == 'Legit'
		end,
		Tooltip = 'How far from where your camera is facing a block can be'
	})
	Range = Breaker:CreateSlider({
		Name = 'Break range',
		Min = 1,
		Max = 18,
		Default = 18,
		Suffix = 'studs',
		Tooltip = 'The game\'s own mining range is 18'
	})
	UpdateRate = Breaker:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	Custom = Breaker:CreateTextList({
		Name = 'Custom',
		Placeholder = 'block name',
		Tooltip = 'Placed blocks to mine wherever they are in range, for example Wool, Wood Plank, Stone Brick or Obsidian'
	})
	Bed = Breaker:CreateToggle({
		Name = 'Break Bed',
		Default = true
	})
	Animation = Breaker:CreateToggle({
		Name = 'Animation',
		Tooltip = 'Plays the mining swing for every hit'
	})
	SelfBreak = Breaker:CreateToggle({
		Name = 'Self Break',
		Tooltip = 'Lets the Custom list mine your own team\'s wool. Other blocks do not say who placed them'
	})
	AutoTool = Breaker:CreateToggle({
		Name = 'Auto Tool',
		Default = true,
		Tooltip = 'Has the server hold the best tool you own for the block, an axe for a bed. Off, only the tool in your hand is used'
	})
	LimitItem = Breaker:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only mines while you hold a pickaxe or an axe'
	})
	Breaker:CreateToggle({
		Name = 'Show target',
		Default = true,
		Function = function(callback)
			if callback then
				box = Instance.new('BoxHandleAdornment')
				box.AlwaysOnTop = true
				box.ZIndex = 0
				box.Color3 = Color3.fromRGB(255, 80, 80)
				box.Transparency = 0.6
				box.Parent = vape.gui
			elseif box then
				box:Destroy()
				box = nil
			end
		end
	})
end)


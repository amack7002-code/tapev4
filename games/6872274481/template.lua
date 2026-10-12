local run = function(func)
	func()
end
task.wait()
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})
getgenv().vapeEvents = vapeEvents

local cloneref = cloneref or function(obj)
	return obj
end

local function safeGetProto(func, index)
    if not func then return nil end
    local success, proto = pcall(debug.getconstant, func, index)
    if success then
        return proto
    end
end

local inventoryDebounce = false
local function fireInventoryChanged()
    if inventoryDebounce then return end
    inventoryDebounce = true
    task.spawn(function()
        task.wait() 
        vapeEvents.InventoryChanged:Fire()
        inventoryDebounce = false
    end)
end

local playersService = cloneref(game:GetService('Players'))
local collectionService = cloneref(game:GetService('CollectionService'))
local function getLocalKits()
	local raw = playersService.LocalPlayer:GetAttribute('PlayingAsKits')
	local list = {}
	if type(raw) == 'string' then
		for kit in raw:gmatch('[%w_]+') do
			if kit ~= '' and kit ~= 'none' then
				table.insert(list, kit)
			end
		end
	end
	return list
end
getgenv().aeroTeamColors = {
	[1] = {name = 'blue',   color = Color3.fromRGB(85, 150, 255)},
	[2] = {name = 'orange', color = Color3.fromRGB(255, 150, 50)},
	[3] = {name = 'pink',   color = Color3.fromRGB(255, 100, 200)},
	[4] = {name = 'yellow', color = Color3.fromRGB(255, 255, 50)},
	[5] = {name = 'brown',  color = Color3.fromRGB(139, 69, 19)},  
	[6] = {name = 'white',  color = Color3.fromRGB(255, 255, 255)}, 
	[7] = {name = 'cyan',   color = Color3.fromRGB(120, 255, 255)}, 
	[8] = {name = 'purple', color = Color3.fromRGB(180, 90, 255)},  
}
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))
local VirtualInputManager = game:GetService("VirtualInputManager")
local lightingService = cloneref(game:GetService('Lighting'))

local isnetworkowner = identifyexecutor and table.find({'Delta', 'Volt'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
if vape and not vape.Clean then
	vape.Clean = function(self, conn)
		if not conn then return end
		
		if not vape.Connections then
			vape.Connections = {}
		end

		if self and self.Enabled then
			vape.Connections[conn] = true
			return conn
		else
			if vape.Connections[conn] then
				if typeof(conn) == "RBXScriptConnection" then
					pcall(conn.Disconnect, conn)
				end
				vape.Connections[conn] = nil
			end
		end
	end
end
if vape and not vape.Remove then
    vape.Remove = function(module) 
		return module 
	end
end
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = { get = function() return nil, true end, tag = function() return '' end, customtags = {} }
local prediction = vape.Libraries.prediction
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local store = {
    attackReach = 0,
    attackReachUpdate = tick(),
    damageBlockFail = tick(),
    hand = {},
    inventory = {
        inventory = {
            items = {},
            armor = {}
        },
        hotbar = {}
    },
    inventories = setmetatable({}, { __mode = "k" }), 
    matchState = 0,
    queueType = 'bedwars_test',
    tools = {},
    lastToolUpdate = 0,
	lastKrystalUpdateCheck = 0,
	BedAlarmNotifyTick = 0,
	BedAlarmIsTrigged = false,
	BedAlarmHighlightedEnimes = {},
	BedAlarm = {},
	BedAlarmSoundTick = 0,
	silasAbilityTime = 0,
	terraStompTime = 0,
	terraKickTime = 0,
}
getgenv().store = store
local Reach = {}
local HitBoxes = {}
local InfiniteFly = {}
local TrapDisabler
local TrapSnap, TrapMine, TrapTeleport, TrapPortal = {}, {}, {}, {}
local AntiFallPart
local bedwars, remotes, sides, oldinvrender, oldSwing = {}, {}, {}, {}, {}

local function getReach(tool)
	local itemMeta = tool and bedwars.ItemMeta and bedwars.ItemMeta[tool.Name]
	return itemMeta and itemMeta.sword and itemMeta.sword.attackRange or 14.4
end
getgenv().getReach = getReach

local _missingRemotes = {}
setmetatable(remotes, {
	__index = function(_, key)
		if not _missingRemotes[key] then
			_missingRemotes[key] = true
			task.delay(10, function()
				if rawget(remotes, key) == nil then
					pcall(function()
						vape.Notify('[aerov4] remote "' .. tostring(key) .. '" changed or removed some features may not work bru (dm @5qvx for fix)', 6)
					end)
				end
			end)
		end
		return nil
	end
})
local originalKnit

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('aerov4/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local readyGate = getgenv().aeroReadyGate or {}
getgenv().aeroReadyGate = readyGate

function readyGate.Release()
	if not readyGate.Held then
		return
	end
	readyGate.Held = false
	local heldRemote = readyGate.Remote
	readyGate.Remote = nil
	if heldRemote then
		heldRemote:FireServer()
	end
end

if not readyGate.Hooked and hookmetamethod and not lplr:GetAttribute('PlayerConnected') then
	readyGate.Hooked = true
	readyGate.Held = true
	readyGate.Started = os.clock()
	local wrap = newcclosure or function(f) return f end
	local oldNamecall
	oldNamecall = hookmetamethod(game, '__namecall', wrap(function(...)
		local self = ...
		if readyGate.Held and not checkcaller() and getnamecallmethod() == 'FireServer' and tostring(self) == 'PlayerReady' then
			readyGate.Remote = self
			return
		end
		return oldNamecall(...)
	end))
	task.delay(45, function()
		if not readyGate.Claimed then
			readyGate.Release()
		end
	end)
end
vape:Clean(function()
	readyGate.Release()
end)

local function notif(...) return
	vape:CreateNotification(...)
end

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
			local idx = table.find(objs, v)
			if idx then
				local last = #objs
				objs[idx] = objs[last]
				objs[last] = nil
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

local function scanDescendants(root, fn, module)
	local state = {cancelled = false}
	if module then
		module:Clean(function() state.cancelled = true end)
	end
	task.spawn(function()
		local stack = {root or workspace}
		local budget = 0
		while #stack > 0 do
			if state.cancelled then return end
			local node = stack[#stack]
			stack[#stack] = nil
			local kids = node:GetChildren()
			for i = 1, #kids do
				local child = kids[i]
				stack[#stack + 1] = child
				fn(child)
			end
			budget += #kids
			if budget >= 700 then
				budget = 0
				task.wait()
				if state.cancelled then return end
			end
		end
	end)
	return state
end

local function cleanThread(module, thread)
	module:Clean(function()
		if thread then
			pcall(task.cancel, thread)
			thread = nil
		end
	end)
	return thread
end

local function getBestArmor(slot)
	local closest, mag = nil, 0

	for _, item in store.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta[item.itemType] or {}

		if meta.armor and meta.armor.slot == slot then
			local newmag = (meta.armor.damageReductionMultiplier or 0)

			if newmag > mag then
				closest, mag = item, newmag
			end
		end
	end

	return closest
end

local function getBow()
	local bestBow, bestBowSlot, bestBowDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local _bowItemMeta = bedwars.ItemMeta[item.itemType]
        local bowMeta = _bowItemMeta and _bowItemMeta.projectileSource
		if bowMeta and table.find(bowMeta.ammoItemTypes, 'arrow') then
			local bowDamage = bedwars.ProjectileMeta[bowMeta.projectileType('arrow')].combat.damage or 0
			if bowDamage > bestBowDamage then
				bestBow, bestBowSlot, bestBowDamage = item, slot, bowDamage
			end
		end
	end
	return bestBow, bestBowSlot
end

local function getItem(itemName, inv)
	for slot, item in (inv or store.inventory.inventory.items) do
		if item.itemType == itemName then
			return item, slot
		end
	end
	return nil
end

local function GetItems(item: string): table
	local Items: table = {};
	for _, v in next, Enum[item]:GetEnumItems() do 
		table.insert(Items, v["Name"]) ;
	end;
	return Items;
end;

local function getRoactRender(func)
	return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
end

local function getSword()
	local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local _swordItemMeta = bedwars.ItemMeta[item.itemType]
        local swordMeta = _swordItemMeta and _swordItemMeta.sword
		if swordMeta then
			local swordDamage = swordMeta.damage or 0
			if swordDamage > bestSwordDamage then
				bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
			end
		end
	end
	return bestSword, bestSwordSlot
end

local function getTool(breakType)
	local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local _toolItemMeta = bedwars.ItemMeta[item.itemType]
        local toolMeta = _toolItemMeta and _toolItemMeta.breakBlock
		if toolMeta then
			local toolDamage = toolMeta[breakType] or 0
			if toolDamage > bestToolDamage then
				bestTool, bestToolSlot, bestToolDamage = item, slot, toolDamage
			end
		end
	end
	return bestTool, bestToolSlot
end

local function getWool()
	for _, wool in store.inventory.inventory.items do
		if wool.itemType:find('wool') then
			return wool and wool.itemType, wool and wool.amount
		end
	end
end

local function getStrength(plr)
	if not plr or not plr.Player then
		return 0
	end

	local strength = 0
	for _, v in (store.inventories[plr.Player] or {items = {}}).items do
		local itemmeta = bedwars.ItemMeta[v.itemType]
		if itemmeta and itemmeta.sword and itemmeta.sword.damage > strength then
			strength = itemmeta.sword.damage
		end
	end

	return strength
end

local function getPlacedBlock(pos)
	if not pos then
		return
	end
	local roundedPosition = bedwars.BlockController:getBlockPosition(pos)
	return bedwars.BlockController:getStore():getBlockAt(roundedPosition), roundedPosition
end

local function getBlocksInPoints(s, e)
	local blocks, list = bedwars.BlockController:getStore(), {}
	for x = s.X, e.X do
		for y = s.Y, e.Y do
			for z = s.Z, e.Z do
				local vec = Vector3.new(x, y, z)
				if blocks:getBlockAt(vec) then
					table.insert(list, vec * 3)
				end
			end
		end
	end
	return list
end

local function getNearGround(range)
	range = Vector3.new(3, 3, 3) * (range or 10)
	local localPosition, mag, closest = entitylib.character.RootPart.Position, 60
	local blocks = getBlocksInPoints(bedwars.BlockController:getBlockPosition(localPosition - range), bedwars.BlockController:getBlockPosition(localPosition + range))

	for _, v in blocks do
		if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
			local newmag = (localPosition - v).Magnitude
			if newmag < mag then
				mag, closest = newmag, v + Vector3.new(0, 3, 0)
			end
		end
	end

	table.clear(blocks)
	return closest
end

local itemSkinMetaFn
local function getItemSkinMeta(skin)
	if itemSkinMetaFn == nil then
		itemSkinMetaFn = false
		pcall(function()
			for _, m in replicatedStorage.TS.games.bedwars['item-skin']:GetDescendants() do
				if m:IsA('ModuleScript') then
					local ok, res = pcall(require, m)
					if ok and type(res) == 'table' and type(res.getItemSkinMeta) == 'function' then
						itemSkinMetaFn = res.getItemSkinMeta
						break
					end
				end
			end
		end)
	end
	if not itemSkinMetaFn then return nil end
	local ok, res = pcall(itemSkinMetaFn, skin)
	return ok and res or nil
end

local skinSoundBackup = {}
local function applySkinSounds(itemType, skin)
	local meta = bedwars.ItemMeta and bedwars.ItemMeta[itemType]
	if not meta then return end
	local backup = skinSoundBackup[itemType]
	if backup then
		for _, v in backup do
			v[1][v[2]] = v[3]
		end
		skinSoundBackup[itemType] = nil
	end
	local skinmeta = skin and getItemSkinMeta(skin)
	if type(skinmeta) ~= 'table' then return end
	local saved = {}
	for section, data in skinmeta do
		local target = meta[section]
		if type(data) == 'table' and type(target) == 'table' then
			for key, val in data do
				if type(key) == 'string' and key:lower():find('sound') then
					table.insert(saved, {target, key, target[key]})
					target[key] = val
				end
			end
		end
	end
	if #saved > 0 then
		skinSoundBackup[itemType] = saved
	end
end

local function getShieldAttribute(char)
	local total = char:GetAttribute('TotalShield')
	if type(total) == 'number' then
		return math.max(total, 0)
	end
	local returned = 0
	for name, val in char:GetAttributes() do
		if name:find('Shield') and type(val) == 'number' and val > 0 then
			returned += val
		end
	end
	return returned
end

local function getSpeed()
	local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()

	local modifiers2 = bedwars.SprintController:getMovementStatusModifier():getModifiers()
	for _, v in modifiers do
		if type(v) == 'table' then
			local val = v.constantSpeedMultiplier and v.constantSpeedMultiplier or 0
			if val and val > math.max(multi, 1) then
				increase = false
				multi = val - (0.06 * math.round(val))
			end
		end
	end

	for _, v in modifiers2 do
		if type(v) == 'table' then
			multi += math.max((v.moveSpeedMultiplier or 0) - 1, 0)
		end
	end

	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end

	return 20 * (multi + 1)
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end

local function hotbarSwitch(slot)
	if slot and store.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		vapeEvents.InventoryChanged.Event:Wait()
		return true
	end
	return false
end

local function getHotbar(tool)
	for i, v in (store.inventory.hotbar or {}) do
		if v.item and v.item.tool == tool then
			return i - 1
		end
	end
	return nil
end
getgenv().getHotbar = getHotbar

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

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local function roundPos(vec)
    return Vector3.new(
        math.round(vec.X / 3) * 3,
        math.round(vec.Y / 3) * 3,
        math.round(vec.Z / 3) * 3
    )
end

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end

local function waitForChildOfType(obj, name, timeout, prop)
	local check, returned = tick() + timeout
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if (returned and returned.Name ~= 'UpperTorso') or check < tick() then
			break
		end
		task.wait()
	until false
	return returned
end

local frictionTable, oldfrict = {}, {}
local lastUpdate = {}
local lagConnections = {}
local frictionConnection
local frictionState

local function modifyVelocity(v)
	if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
		oldfrict[v] = v.CustomPhysicalProperties or 'none'
		v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	end
end

local function updateVelocity(force)
	local newState = getTableSize(frictionTable) > 0
	if frictionState ~= newState or force then
		if frictionConnection then
			frictionConnection:Disconnect()
		end
		if newState then
			if entitylib.isAlive then
				for _, v in entitylib.character.Character:GetDescendants() do
					modifyVelocity(v)
				end
				frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
			end
		else
			for i, v in oldfrict do
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
			table.clear(oldfrict)
		end
	end
	frictionState = newState
end

local function isEveryoneDead()
	return #bedwars.Store:getState().Party.members <= 0
end
	
local function joinQueue()
	if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
		bedwars.QueueController:joinQueue(store.queueType)
	end
end

local function lobby()
    bedwars.Client:Get(remotes.TeleportToLobby):FireServer()
end

local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}

local function HasSeed(character)
    if not character then return false end
    return character:FindFirstChild("Seed", true) ~= nil
end

local sortmethods = {
	Threat = function(a, b)
		if not a.Entity then return false end
		if not b.Entity then return true end
		return getStrength(a.Entity) > getStrength(b.Entity)
	end,
	Health = function(a, b)
		if not a.Entity then return false end
		if not b.Entity then return true end
		return a.Entity.Health < b.Entity.Health
	end,
	Angle = function(a, b)
		if not a.Entity or not a.Entity.RootPart then return false end
		if not b.Entity or not b.Entity.RootPart then return true end
		local selfrootpos = entitylib.character.RootPart.Position
		local rawFacing = (getgenv().ViewMode and getgenv().ViewMode.Value == 'Third Person') and gameCamera.CFrame.LookVector or entitylib.character.RootPart.CFrame.LookVector
		local flatFacing = Vector3.new(rawFacing.X, 0, rawFacing.Z)
		if flatFacing.Magnitude < 0.001 then return false end
		local localFacing = flatFacing.Unit
		local deltaA = Vector3.new(a.Entity.RootPart.Position.X - selfrootpos.X, 0, a.Entity.RootPart.Position.Z - selfrootpos.Z)
		local deltaB = Vector3.new(b.Entity.RootPart.Position.X - selfrootpos.X, 0, b.Entity.RootPart.Position.Z - selfrootpos.Z)
		if deltaA.Magnitude < 0.001 or deltaB.Magnitude < 0.001 then return deltaA.Magnitude < deltaB.Magnitude end
		local angle = math.acos(math.clamp(localFacing:Dot(deltaA.Unit), -1, 1))
		local angle2 = math.acos(math.clamp(localFacing:Dot(deltaB.Unit), -1, 1))
		return angle < angle2
	end,
	Distance = function(a, b)
		if not a.Entity or not a.Entity.RootPart then return false end
		if not b.Entity or not b.Entity.RootPart then return true end
		local selfpos = entitylib.character.RootPart.Position
		local distA = (a.Entity.RootPart.Position - selfpos).Magnitude
		local distB = (b.Entity.RootPart.Position - selfpos).Magnitude
		return distA < distB
	end,
	Cursor = function(a, b)
		if not a.Entity or not a.Entity.RootPart then return false end
		if not b.Entity or not b.Entity.RootPart then return true end
		local camera = gameCamera
		local mousePos = inputService:GetMouseLocation()
		local function screenDist(ent)
			local rootPart = ent.RootPart
			if not rootPart then return math.huge end
			local screenPos, onScreen = camera:WorldToScreenPoint(rootPart.Position)
			if not onScreen then return math.huge end
			return (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
		end
		local distA = screenDist(a.Entity)
		local distB = screenDist(b.Entity)
		if distA == math.huge and distB == math.huge then
			local selfpos = entitylib.character.RootPart.Position
			local worldA = (a.Entity.RootPart.Position - selfpos).Magnitude
			local worldB = (b.Entity.RootPart.Position - selfpos).Magnitude
			return worldA < worldB
		end
		return distA < distB
	end,
	Forest = function(a, b)
		if not a.Entity then return false end
		if not b.Entity then return true end
		local aHasSeed = HasSeed(a.Entity.Character)
		local bHasSeed = HasSeed(b.Entity.Character)
		if aHasSeed and not bHasSeed then return true end
		if not aHasSeed and bHasSeed then return false end
		if not a.Entity.RootPart then return false end
		if not b.Entity.RootPart then return true end
		local selfpos = entitylib.character.RootPart.Position
		local distA = (a.Entity.RootPart.Position - selfpos).Magnitude
		local distB = (b.Entity.RootPart.Position - selfpos).Magnitude
		return distA < distB
	end
}

local function getSortList(priority)
	local methods = {}
	for _, v in ipairs(priority or {}) do
		table.insert(methods, v)
	end
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	return methods
end

--[[AEROV4_GAME_MODULE_001]]
entitylib.start()

--[[AEROV4_GAME_MODULE_002]]

for _, v in {'AntiRagdoll', 'TriggerBot', 'SilentAim', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'MouseTP', 'MurderMystery', 'NameTags', 'Killaura', 'AimAssist', 'AutoClicker', 'Reach', 'AntiFall', 'Fly', 'HitBoxes', 'LongJump', 'Speed', 'Swim', 'PlayerModel', 'Search', 'Waypoints', 'Blink', 'StaffDetector', ''} do
	vape:Remove(v)
end

local Fly
local LongJump

local kitImageIds = {
	['none'] = "rbxassetid://16493320215",
	["random"] = "rbxassetid://79773209697352",
	["cowgirl"] = "rbxassetid://9155462968",
	["davey"] = "rbxassetid://9155464612",
	["warlock"] = "rbxassetid://15186338366",
	["ember"] = "rbxassetid://9630017904",
	["black_market_trader"] = "rbxassetid://18922642482",
	["yeti"] = "rbxassetid://9166205917",
	["scarab"] = "rbxassetid://137137517627492",
	["defender"] = "rbxassetid://131690429591874",
	["cactus"] = "rbxassetid://104436517801089",
	["oasis"] = "rbxassetid://120283205213823",
	["berserker"] = "rbxassetid://90258047545241",
	["sword_shield"] = "rbxassetid://131690429591874",
	["airbender"] = "rbxassetid://74712750354593",
	["gun_blade"] = "rbxassetid://138231219644853",
	["frost_hammer_kit"] = "rbxassetid://11838567073",
	["spider_queen"] = "rbxassetid://95237509752482",
	["archer"] = "rbxassetid://9224796984",
	["axolotl"] = "rbxassetid://9155466713",
	["baker"] = "rbxassetid://9155463919",
	["barbarian"] = "rbxassetid://9166207628",
	["builder"] = "rbxassetid://9155463708",
	["necromancer"] = "rbxassetid://11343458097",
	["cyber"] = "rbxassetid://9507126891",
	["sorcerer"] = "rbxassetid://97940108361528",
	["bigman"] = "rbxassetid://9155467211",
	["spirit_assassin"] = "rbxassetid://10406002412",
	["farmer_cletus"] = "rbxassetid://9155466936",
	["ice_queen"] = "rbxassetid://9155466204",
	["grim_reaper"] = "rbxassetid://9155467410",
	["spirit_gardener"] = "rbxassetid://132108376114488",
	["hannah"] = "rbxassetid://10726577232",
	["shielder"] = "rbxassetid://9155464114",
	["summoner"] = "rbxassetid://18922378956",
	["glacial_skater"] = "rbxassetid://84628060516931",
	["dragon_sword"] = "rbxassetid://16215630104",
	["lumen"] = "rbxassetid://9630018371",
	["flower_bee"] = "rbxassetid://101569742252812",
	["jellyfish"] = "rbxassetid://18129974852",
	["melody"] = "rbxassetid://9155464915",
	["mimic"] = "rbxassetid://14783283296",
	["miner"] = "rbxassetid://9166208461",
	["nazar"] = "rbxassetid://18926951849",
	["seahorse"] = "rbxassetid://11902552560",
	["elk_master"] = "rbxassetid://15714972287",
	["rebellion_leader"] = "rbxassetid://18926409564",
	["void_hunter"] = "rbxassetid://122370766273698",
	["taliyah"] = "rbxassetid://13989437601",
	["angel"] = "rbxassetid://9166208240",
	["harpoon"] = "rbxassetid://18250634847",
	["void_walker"] = "rbxassetid://78915127961078",
	["spirit_summoner"] = "rbxassetid://95760990786863",
	["triple_shot"] = "rbxassetid://9166208149",
	["void_knight"] = "rbxassetid://73636326782144",
	["regent"] = "rbxassetid://9166208904",
	["vulcan"] = "rbxassetid://9155465543",
	["owl"] = "rbxassetid://12509401147",
	["dasher"] = "rbxassetid://9155467645",
	["disruptor"] = "rbxassetid://11596993583",
	["wizard"] = "rbxassetid://13353923546",
	["aery"] = "rbxassetid://9155463221",
	["agni"] = "rbxassetid://17024640133",
	["alchemist"] = "rbxassetid://9155462512",
	["spearman"] = "rbxassetid://9166207341",
	["beekeeper"] = "rbxassetid://9312831285",
	["falconer"] = "rbxassetid://17022941869",
	["bounty_hunter"] = "rbxassetid://9166208649",
	["blood_assassin"] = "rbxassetid://12520290159",
	["battery"] = "rbxassetid://10159166528",
	["steam_engineer"] = "rbxassetid://15380413567",
	["vesta"] = "rbxassetid://9568930198",
	["beast"] = "rbxassetid://9155465124",
	["dino_tamer"] = "rbxassetid://9872357009",
	["drill"] = "rbxassetid://12955100280",
	["elektra"] = "rbxassetid://13841413050",
	["fisherman"] = "rbxassetid://9166208359",
	["queen_bee"] = "rbxassetid://12671498918",
	["card"] = "rbxassetid://13841410580",
	["frosty"] = "rbxassetid://9166208762",
	["gingerbread_man"] = "rbxassetid://9155464364",
	["ghost_catcher"] = "rbxassetid://9224802656",
	["tinker"] = "rbxassetid://17025762404",
	["ignis"] = "rbxassetid://13835258938",
	["oil_man"] = "rbxassetid://9166206259",
	["jade"] = "rbxassetid://9166306816",
	["dragon_slayer"] = "rbxassetid://10982192175",
	["paladin"] = "rbxassetid://11202785737",
	["pinata"] = "rbxassetid://10011261147",
	["merchant"] = "rbxassetid://9872356790",
	["metal_detector"] = "rbxassetid://9378298061",
	["slime_tamer"] = "rbxassetid://15379766168",
	["nyoka"] = "rbxassetid://17022941410",
	["midnight"] = "rbxassetid://9155462763",
	["pyro"] = "rbxassetid://9155464770",
	["raven"] = "rbxassetid://9166206554",
	["santa"] = "rbxassetid://9166206101",
	["sheep_herder"] = "rbxassetid://9155465730",
	["smoke"] = "rbxassetid://9155462247",
	["spirit_catcher"] = "rbxassetid://9166207943",
	["star_collector"] = "rbxassetid://9872356516",
	["styx"] = "rbxassetid://17014536631",
	["block_kicker"] = "rbxassetid://15382536098",
	["trapper"] = "rbxassetid://9166206875",
	["hatter"] = "rbxassetid://12509388633",
	["ninja"] = "rbxassetid://15517037848",
	["jailor"] = "rbxassetid://11664116980",
	["warrior"] = "rbxassetid://9166207008",
	["mage"] = "rbxassetid://10982191792",
	["void_dragon"] = "rbxassetid://10982192753",
	["cat"] = "rbxassetid://15350740470",
	["wind_walker"] = "rbxassetid://9872355499",
	['skeleton'] = "rbxassetid://120123419412119",
	['winter_lady'] = "rbxassetid://83274578564074",
	['soul_broker'] = 'rbxassetid://130409166262430'
}

local function isFirstPerson()
    if not (lplr.Character and lplr.Character:FindFirstChild("Head")) then
        return false
    end
    return (lplr.Character.Head.Position - gameCamera.CFrame.Position).Magnitude < 2
end

local function isFrozen(entity, threshold)
    threshold = threshold or 10
    local char
    if type(entity) == "table" and entity.Character then
        char = entity.Character
    elseif type(entity) == "Instance" and entity:IsA("Model") then
        char = entity
    elseif entity == nil then
        if not entitylib.isAlive then return false end
        char = entitylib.character.Character
    else
        return false
    end

    local stacks = char:GetAttribute("ColdStacks") or char:GetAttribute("FrostStacks")
               or char:GetAttribute("FreezeStacks") or char:GetAttribute("FROZEN_STACKS")
    if stacks and stacks >= threshold then return true end

    local statusEffects = char:GetAttribute("StatusEffects")
    if type(statusEffects) == "table" then
        for effectName, stackCount in pairs(statusEffects) do
            local nameLower = tostring(effectName):lower()
            if nameLower:match("cold") or nameLower:match("frost") or nameLower:match("freeze") then
                if type(stackCount) == "number" then
                    if stackCount >= threshold then return true end
                elseif stackCount then
                    return true
                end
            end
        end
    end

    if char:FindFirstChild("IceBlock") or char:FindFirstChild("FrozenBlock") or char:FindFirstChild("IceShell") then
        return true
    end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.WalkSpeed <= 2 then
        return true
    end

    return false
end

local sharedRaycast = RaycastParams.new()
sharedRaycast.FilterType = Enum.RaycastFilterType.Include
sharedRaycast.FilterDescendantsInstances = {workspace:FindFirstChild('Map') or workspace}

local function cloneRaycast()
    local r = RaycastParams.new()
    r.FilterType = sharedRaycast.FilterType
    r.FilterDescendantsInstances = sharedRaycast.FilterDescendantsInstances
    r.RespectCanCollide = sharedRaycast.RespectCanCollide
    return r
end

local function isSword()
    return store.hand and store.hand.toolType == 'sword'
end

local function hasValidWeapon()
    if not store.hand or not store.hand.tool then return false end
    local toolType = store.hand.toolType
    local toolName = store.hand.tool.Name:lower()
    if toolName:find('headhunter') then return true end
    return toolType == 'sword' or toolType == 'bow' or toolType == 'crossbow'
end

local function fixPosition(pos)
    if bedwars and bedwars.BlockController and bedwars.BlockController.getBlockPosition then
        return bedwars.BlockController:getBlockPosition(pos) * 3
    end
    return pos * 3
end

local function getAmmoForProjectile(check)
    for _, item in store.inventory.inventory.items do
        if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
            return item.itemType
        end
    end
end

local function getProjectileItems(ammoFilter)
    local items = {}
    for _, item in store.inventory.inventory.items do
        local _itemMeta = bedwars.ItemMeta[item.itemType]
        local proj = _itemMeta and _itemMeta.projectileSource
        local ammo = proj and getAmmoForProjectile(proj)
        if ammo and table.find(ammoFilter, ammo) then
            table.insert(items, {item, ammo, proj.projectileType(ammo), proj})
        end
    end
    return items
end

local function isHoldingItem(keywords, includeProjectileSource)
    if not store.hand or not store.hand.tool then return false end
    local toolName = store.hand.tool.Name:lower()
    for _, kw in ipairs(keywords) do
        if toolName:find(kw) then return true end
    end
    if includeProjectileSource then
        return bedwars.ItemMeta[toolName] and bedwars.ItemMeta[toolName].projectileSource and true or false
    end
    return false
end

local function isHoldingBowCrossbow(includeProjectileSource)
    return isHoldingItem({'bow', 'crossbow', 'headhunter'}, includeProjectileSource)
end

local function isHoldingPickaxe()
    return isHoldingItem({'pickaxe'})
end

local function isEnemy(ent)
    if not ent then return false end
    if ent.Character and ent.Character:HasTag('petrified-player') then return false end
    if ent.Player then
        local myTeam = lplr:GetAttribute('Team')
        local theirTeam = ent.Player:GetAttribute('Team')
        if not myTeam or not theirTeam or myTeam == theirTeam then return false end
        return true
    elseif ent.NPC then
        local npcTeam = ent.Character:GetAttribute('Team')
        if npcTeam then return lplr:GetAttribute('Team') ~= npcTeam end
        return true
    end
    return false
end

local function getShopNPC()
    local shop, items, upgrades, newid = nil, false, false, nil
    if entitylib.isAlive then
        local localPosition = entitylib.character.RootPart.Position
        for _, v in (store.shop or {}) do
            if v.RootPart and v.RootPart.Parent and (v.RootPart.Position - localPosition).Magnitude <= 20 then
                shop = v.Upgrades or v.Shop or nil
                upgrades = upgrades or v.Upgrades
                items = items or v.Shop
                newid = v.Shop and v.Id or newid
            end
        end
    end
    return shop, items, upgrades, newid
end

local function isTeammate(player)
    if not lplr or not player then return false end
    local myTeam = lplr:GetAttribute('Team')
    local theirTeam = player:GetAttribute('Team')
    return myTeam and theirTeam and myTeam == theirTeam
end

local function getPlayerName(player, useDisplayName)
    if not player then return '' end
    return (useDisplayName and player.DisplayName ~= "" and player.DisplayName) or player.Name
end

local armorTiers = {'none','leather_chestplate','iron_chestplate','diamond_chestplate','emerald_chestplate'}
local function getArmorTier(player)
    if not player or not store.inventories[player] then return 0 end
    local chest = store.inventories[player].armor and store.inventories[player].armor[5]
    if not chest or chest == 'empty' then return 1 end
    return table.find(armorTiers, chest.itemType) or 1
end

local function checkFaceAdjacent(pos, faces)
    faces = faces or {
        Vector3.new(3,0,0), Vector3.new(-3,0,0), Vector3.new(0,3,0),
        Vector3.new(0,-3,0), Vector3.new(0,0,3), Vector3.new(0,0,-3)
    }
    for _, v in ipairs(faces) do
        if getPlacedBlock(pos + v) then return true end
    end
    return false
end

local _isAboveVoidParams = RaycastParams.new()
_isAboveVoidParams.FilterType = Enum.RaycastFilterType.Exclude
local function isAboveVoid(position)
    if not entitylib.isAlive or not entitylib.character then return false end
    _isAboveVoidParams.FilterDescendantsInstances = {entitylib.character.Character}
    local result = workspace:Raycast(position, Vector3.new(0, -500, 0), _isAboveVoidParams)
    return result == nil
end

local function hasFaceBelowOrSide(pos)
    if getPlacedBlock(pos - Vector3.new(0,3,0)) then return true end
    local sides = {Vector3.new(3,0,0), Vector3.new(-3,0,0), Vector3.new(0,0,3), Vector3.new(0,0,-3)}
    for _, v in ipairs(sides) do
        if getPlacedBlock(pos + v) then return true end
    end
    return false
end

local function nearCorner(poscheck, pos)
    local start = poscheck - Vector3.new(3,3,3)
    local fin = poscheck + Vector3.new(3,3,3)
    local dir = (pos - poscheck).Unit * 100
    local check = poscheck + dir
    return Vector3.new(
        math.clamp(check.X, start.X, fin.X),
        math.clamp(check.Y, start.Y, fin.Y),
        math.clamp(check.Z, start.Z, fin.Z)
    )
end

local function blockProximity(pos, rangeBlocks)
    rangeBlocks = rangeBlocks or 21
    local mag, best = 60, nil
    local blocks = getBlocksInPoints(
        bedwars.BlockController:getBlockPosition(pos - Vector3.new(rangeBlocks,rangeBlocks,rangeBlocks)),
        bedwars.BlockController:getBlockPosition(pos + Vector3.new(rangeBlocks,rangeBlocks,rangeBlocks))
    )
    for _, v in ipairs(blocks) do
        local bp = nearCorner(v, pos)
        local d = (pos - bp).Magnitude
        if hasFaceBelowOrSide(bp) and d < mag then
            mag, best = d, bp
        end
    end
    return best
end

local function isGUIOpen()
    return bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN)
        or bedwars.AppController:isLayerOpen(bedwars.UILayers.DIALOG)
        or bedwars.AppController:isLayerOpen(bedwars.UILayers.POPUP)
        or bedwars.AppController:isAppOpen('BedwarsItemShopApp')
        or (bedwars.Store:getState().Inventory and bedwars.Store:getState().Inventory.open)
end

local function isTargetValid(ent, maxDist, checkWalls)
    if not ent or not ent.RootPart or not ent.Character then return false end
    if not entitylib.isAlive then return false end
    local dist = (ent.RootPart.Position - entitylib.character.RootPart.Position).Magnitude
    if dist > maxDist then return false end
    if checkWalls then
        local ray = workspace:Raycast(
            entitylib.character.RootPart.Position,
            (ent.RootPart.Position - entitylib.character.RootPart.Position),
            sharedRaycast
        )
        if ray then return false end
    end
    local hum = ent.Character:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

local function getTargetByPriority(originPos, range, opts)
    opts = opts or {}
    local players = opts.players == nil and true or opts.players
    local npcs = opts.npcs or false
    local walls = opts.walls or false
    local sort = opts.sort or 'distance' -- 'health','armor','damage'
    local damageTracker = opts.damageTracker 

    local valid = {}
    for _, ent in ipairs(entitylib.List) do
        if (players and ent.Player) or (npcs and ent.NPC) then
            if isEnemy(ent) and ent.RootPart then
                local dist = (ent.RootPart.Position - originPos).Magnitude
                if dist <= range then
                    if walls then
                        local ray = workspace:Raycast(originPos, (ent.RootPart.Position - originPos), sharedRaycast)
                        if not ray then
                            table.insert(valid, ent)
                        end
                    else
                        table.insert(valid, ent)
                    end
                end
            end
        end
    end
    if #valid == 0 then return nil end

    if sort == 'distance' then
        table.sort(valid, function(a,b)
            return (a.RootPart.Position - originPos).Magnitude < (b.RootPart.Position - originPos).Magnitude
        end)
    elseif sort == 'damage' and damageTracker then
        table.sort(valid, function(a,b)
            local keyA = a.Player and a.Player.UserId or tostring(a)
            local keyB = b.Player and b.Player.UserId or tostring(b)
            return (damageTracker[keyA] or 0) > (damageTracker[keyB] or 0)
        end)
    elseif sort == 'health' then
        table.sort(valid, function(a,b)
            return a.Health < b.Health
        end)
    elseif sort == 'armor' then
        table.sort(valid, function(a,b)
            return getArmorTier(a.Player) < getArmorTier(b.Player)
        end)
    end
    return valid[1]
end

local isMobile = inputService.TouchEnabled and not inputService.KeyboardEnabled and not inputService.MouseEnabled

local function getTeammates(namesOnly)
    local result = {}
    local myTeam = lplr:GetAttribute('Team')
    if not myTeam then return result end
    for _, player in playersService:GetPlayers() do
        if player ~= lplr and player:GetAttribute('Team') == myTeam then
            if namesOnly then
                table.insert(result, player.Name)
            elseif player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
                table.insert(result, player)
            end
        end
    end
    if namesOnly then
        table.sort(result)
    end
    return result
end

local function getNearestTeammateInRange(range, condition)
    if not entitylib.isAlive then return nil end
    local myPos = entitylib.character.RootPart.Position
    local nearest = nil
    local nearestDist = math.huge
    for _, player in ipairs(getTeammates()) do
        if player.Character and player.Character.PrimaryPart then
            local dist = (player.Character.PrimaryPart.Position - myPos).Magnitude
            if dist <= range then
                if condition and not condition(player) then continue end
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = player
                end
            end
        end
    end
    return nearest
end

local function getPlayerHealth(player)
    if not player or not player.Character then return 0, 100 end
    local health = player.Character:GetAttribute('Health') or (player.Character:FindFirstChildOfClass('Humanoid') and player.Character.Humanoid.Health) or 0
    local maxHealth = player.Character:GetAttribute('MaxHealth') or (player.Character:FindFirstChildOfClass('Humanoid') and player.Character.Humanoid.MaxHealth) or 100
    return health, maxHealth
end

local function getPlayerHealthPercent(player)
    local health, maxHealth = getPlayerHealth(player)
    if maxHealth == 0 then return 0 end
    return (health / maxHealth) * 100
end

local function leftClick()
	pcall(function()
		VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
		task.wait(0.05)
		VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
	end)
end

local function getWorldFolder()
    local Map = workspace:FindFirstChild("Map")
    if not Map then return nil end
    local Worlds = Map:FindFirstChild("Worlds")
    if not Worlds then return nil end
    for _, world in Worlds:GetChildren() do
        return world
    end
    return nil
end

local function getPickaxeSlot()
	for i, v in store.inventory.hotbar do
		if v.item and bedwars.ItemMeta[v.item.itemType] then
			local meta = bedwars.ItemMeta[v.item.itemType]
			if meta.breakBlock then
				return i - 1
			end
		end
	end
	return nil
end

local function getScaffoldBlockForModule(limitItem)
	if limitItem.Enabled then
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name
		end
		return nil
	else
		local wool = getWool()
		if wool then
			return wool
		else
			for _, item in store.inventory.inventory.items do
				local meta = bedwars.ItemMeta[item.itemType]
				if meta and meta.block then
					return item.itemType
				end
			end
		end
	end
	return nil
end

local function safeIsBreakable(pos)
    if not bedwars.BlockController then return false end
    local ok, result = pcall(function()
        return bedwars.BlockController:isBlockBreakable({blockPosition = pos / 3}, lplr)
    end)
    return ok and result
end

--[[
	Combat Modules
]]

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

--[[
	Blatant Modules
]]


--[[AEROV4_GAME_MODULE_013]]

--[[AEROV4_GAME_MODULE_014]]

local AntiFallDirection
--[[AEROV4_GAME_MODULE_015]]

--[[AEROV4_GAME_MODULE_016]]

--[[AEROV4_GAME_MODULE_017]]

--[[AEROV4_GAME_MODULE_018]]

--[[AEROV4_GAME_MODULE_019]]

--[[AEROV4_GAME_MODULE_020]]

--[[AEROV4_GAME_MODULE_021]]

--[[AEROV4_GAME_MODULE_022]]

--[[AEROV4_GAME_MODULE_023]]

local Attacking
--[[AEROV4_GAME_MODULE_024]]

--[[AEROV4_GAME_MODULE_025]]

--[[AEROV4_GAME_MODULE_026]]

--[[AEROV4_GAME_MODULE_027]]

--[[AEROV4_GAME_MODULE_028]]

--[[
	Render Modules
]]

--[[AEROV4_GAME_MODULE_029]]

--[[AEROV4_GAME_MODULE_030]]

--[[AEROV4_GAME_MODULE_031]]

--[[AEROV4_GAME_MODULE_032]]

--[[AEROV4_GAME_MODULE_033]]

--[[AEROV4_GAME_MODULE_034]]

--[[AEROV4_GAME_MODULE_035]]

--[[AEROV4_GAME_MODULE_036]]

--[[AEROV4_GAME_MODULE_037]]

--[[AEROV4_GAME_MODULE_038]]

--[[AEROV4_GAME_MODULE_039]]

--[[AEROV4_GAME_MODULE_040]]

--[[AEROV4_GAME_MODULE_041]]

--[[AEROV4_GAME_MODULE_042]]

--[[AEROV4_GAME_MODULE_043]]

--[[
	Utility Mobule
]]

--[[AEROV4_GAME_MODULE_044]]

--[[AEROV4_GAME_MODULE_045]]

--[[AEROV4_GAME_MODULE_046]]

--[[AEROV4_GAME_MODULE_047]]

--[[AEROV4_GAME_MODULE_048]]

--[[AEROV4_GAME_MODULE_049]]

--[[AEROV4_GAME_MODULE_050]]
	
--[[AEROV4_GAME_MODULE_051]]

--[[AEROV4_GAME_MODULE_052]]

--[[AEROV4_GAME_MODULE_053]]

--[[AEROV4_GAME_MODULE_054]]

--[[AEROV4_GAME_MODULE_055]]

--[[AEROV4_GAME_MODULE_056]]

--[[AEROV4_GAME_MODULE_057]]

--[[AEROV4_GAME_MODULE_058]]

--[[AEROV4_GAME_MODULE_059]]

--[[AEROV4_GAME_MODULE_060]]

--[[AEROV4_GAME_MODULE_061]]

--[[AEROV4_GAME_MODULE_062]]

--[[AEROV4_GAME_MODULE_063]]

--[[AEROV4_GAME_MODULE_064]]

--[[AEROV4_GAME_MODULE_065]]

--[[
	World Modules
]]

--[[AEROV4_GAME_MODULE_066]]

--[[AEROV4_GAME_MODULE_067]]

--[[AEROV4_GAME_MODULE_068]]

--[[AEROV4_GAME_MODULE_069]]

--[[AEROV4_GAME_MODULE_070]]
	
--[[AEROV4_GAME_MODULE_071]]

--[[AEROV4_GAME_MODULE_072]]

--[[AEROV4_GAME_MODULE_073]]
	
--[[AEROV4_GAME_MODULE_074]]

--[[AEROV4_GAME_MODULE_075]]

--[[AEROV4_GAME_MODULE_076]]

--[[AEROV4_GAME_MODULE_077]]

--[[AEROV4_GAME_MODULE_078]]

--[[AEROV4_GAME_MODULE_079]]

--[[AEROV4_GAME_MODULE_080]]

--[[AEROV4_GAME_MODULE_081]]

--[[AEROV4_GAME_MODULE_082]]

--[[AEROV4_GAME_MODULE_083]]

--[[AEROV4_GAME_MODULE_084]]

--[[
	Inventory Modules
]]

--[[AEROV4_GAME_MODULE_085]]
	
--[[AEROV4_GAME_MODULE_086]]

--[[AEROV4_GAME_MODULE_087]]
	
--[[AEROV4_GAME_MODULE_088]]

--[[AEROV4_GAME_MODULE_089]]

--[[
	Minigames Modules
]]

--[[AEROV4_GAME_MODULE_090]]

--[[AEROV4_GAME_MODULE_091]]

--[[AEROV4_GAME_MODULE_092]]

--[[
	Legit Modules
]]

--[[AEROV4_GAME_MODULE_093]]

--[[AEROV4_GAME_MODULE_094]]

--[[AEROV4_GAME_MODULE_095]]
	
--[[AEROV4_GAME_MODULE_096]]
	
--[[AEROV4_GAME_MODULE_097]]

--[[AEROV4_GAME_MODULE_098]]

--[[AEROV4_GAME_MODULE_099]]

--[[AEROV4_GAME_MODULE_100]]

--[[
	Kits Modules
]]

--[[AEROV4_GAME_MODULE_101]]

--[[AEROV4_GAME_MODULE_102]]

--[[AEROV4_GAME_MODULE_103]]

--[[AEROV4_GAME_MODULE_104]]

--[[AEROV4_GAME_MODULE_105]]

--[[AEROV4_GAME_MODULE_106]]

--[[AEROV4_GAME_MODULE_107]]

--[[AEROV4_GAME_MODULE_108]]

--[[AEROV4_GAME_MODULE_109]]

--[[AEROV4_GAME_MODULE_110]]

--[[AEROV4_GAME_MODULE_111]]

--[[AEROV4_GAME_MODULE_112]]

--[[AEROV4_GAME_MODULE_113]]

--[[AEROV4_GAME_MODULE_114]]

--[[AEROV4_GAME_MODULE_115]]

--[[AEROV4_GAME_MODULE_116]]

--[[AEROV4_GAME_MODULE_117]]

--[[AEROV4_GAME_MODULE_118]]

--[[AEROV4_GAME_MODULE_119]]

--[[AEROV4_GAME_MODULE_120]]

--[[AEROV4_GAME_MODULE_121]]

--[[AEROV4_GAME_MODULE_122]]

--[[AEROV4_GAME_MODULE_123]]

--[[AEROV4_GAME_MODULE_124]]

--[[AEROV4_GAME_MODULE_125]]

--[[AEROV4_GAME_MODULE_126]]

--[[AEROV4_GAME_MODULE_127]]

--[[AEROV4_GAME_MODULE_128]]

--[[AEROV4_GAME_MODULE_129]]

--[[AEROV4_GAME_MODULE_130]]

--[[AEROV4_GAME_MODULE_131]]

--[[AEROV4_GAME_MODULE_132]]

--[[AEROV4_GAME_MODULE_133]]

--[[AEROV4_GAME_MODULE_134]]

--[[AEROV4_GAME_MODULE_135]]

--[[AEROV4_GAME_MODULE_136]]

--[[AEROV4_GAME_MODULE_137]]

--[[AEROV4_GAME_MODULE_138]]

--[[AEROV4_GAME_MODULE_139]]

--[[AEROV4_GAME_MODULE_140]]

--[[AEROV4_GAME_MODULE_141]]

--[[AEROV4_GAME_MODULE_142]]

--[[AEROV4_GAME_MODULE_143]]

--[[AEROV4_GAME_MODULE_144]]

--[[AEROV4_GAME_MODULE_145]]

--[[AEROV4_GAME_MODULE_146]]

--[[AEROV4_GAME_MODULE_147]]

--[[AEROV4_GAME_MODULE_148]]

--[[AEROV4_GAME_MODULE_149]]

--[[AEROV4_GAME_MODULE_150]]

--[[AEROV4_GAME_MODULE_151]]

--[[AEROV4_GAME_MODULE_152]]

--[[AEROV4_GAME_MODULE_153]]

--[[AEROV4_GAME_MODULE_154]]

--[[AEROV4_GAME_MODULE_155]]

--[[AEROV4_GAME_MODULE_156]]

--[[AEROV4_GAME_MODULE_157]]

--[[AEROV4_GAME_MODULE_158]]

--[[AEROV4_GAME_MODULE_159]]

--[[AEROV4_GAME_MODULE_160]]

--[[AEROV4_GAME_MODULE_161]]

--[[AEROV4_GAME_MODULE_162]]

--[[AEROV4_GAME_MODULE_163]]

--[[AEROV4_GAME_MODULE_164]]

--[[AEROV4_GAME_MODULE_165]]

--[[AEROV4_GAME_MODULE_166]]

--[[AEROV4_GAME_MODULE_167]]

--[[AEROV4_GAME_MODULE_168]]

--[[AEROV4_GAME_MODULE_169]]

--[[AEROV4_GAME_MODULE_170]]

--[[AEROV4_GAME_MODULE_171]]

--[[AEROV4_GAME_MODULE_172]]

--[[AEROV4_GAME_MODULE_173]]

--[[AEROV4_GAME_MODULE_174]]

--[[AEROV4_GAME_MODULE_175]]

--[[AEROV4_GAME_MODULE_176]]

--[[AEROV4_GAME_MODULE_177]]
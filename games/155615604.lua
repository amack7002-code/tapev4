local run = function(func)
    local ok, err = xpcall(func, debug.traceback)

    if not ok then
        warn('[Module Error] ' .. tostring(err))
    end

    return ok, err
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
local replicatedFirst = cloneref(game:GetService('ReplicatedFirst'))
local collectionService = cloneref(game:GetService('CollectionService'))
local marketplaceService = cloneref(game:GetService('MarketplaceService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local tweenService = cloneref(game:GetService('TweenService'))
local runService = cloneref(game:GetService('RunService'))
local guiService = cloneref(game:GetService('GuiService'))
local teams = cloneref(game:GetService('Teams'))
local coreGui = cloneref(game:GetService('CoreGui'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local whitelist = vape.Libraries.whitelist
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local getfontbounds = vape.Libraries.getfontbounds

local pl = {}
local Spring = {}
local TracerHook = {Hooks = {}}
local VehicleWallbang = {Enabled = false}
local oldshoot, oldequip
local aimTimer, shootTimer, aimVec = 0, 0
local arrestCooldown = 0
local teamCooldown = 0
local tempTargets = {}
local gamepasses = {}

local function checkPoint(pos, params)
	for _, part in workspace:GetPartBoundsInRadius(pos, 0, params) do
		if part.CanCollide and (part:GetClosestPointOnSurface(pos) - pos).Magnitude <= 0.0001 then
			return false
		end
	end

	return true
end

local function canClick()
	local mousePosition = (inputService:GetMouseLocation() - guiService:GetGuiInset())

	for _, hit in lplr.PlayerGui:GetGuiObjectsAtPosition(mousePosition.X, mousePosition.Y) do
		local obj = hit:FindFirstAncestorOfClass('ScreenGui')
		if hit.Active and hit.Visible and obj and obj.Enabled then
			return false
		end
	end

	for _, hit in coreGui:GetGuiObjectsAtPosition(mousePosition.X, mousePosition.Y) do
		local obj = hit:FindFirstAncestorOfClass('ScreenGui')
		if hit.Active and hit.Visible and obj and obj.Enabled then
			return false
		end
	end

	return (not vape.gui.ScaledGui.ClickGui.Visible) and (not inputService:GetFocusedTextBox())
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
	return (table.find(vape.Categories.Targets.ListEnabled, plr.Name) or tempTargets[plr.Name]) and true
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function pickTeam(button)
	if teamCooldown < os.clock() then
		firesignal(button.MouseButton1Click)
		teamCooldown = os.clock() + 0.1
	end
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local OriginScanner = {Cache = {}, Offset = 0}
run(function()
	local rayParams = RaycastParams.new()
	local overlapParams = OverlapParams.new()
	rayParams.CollisionGroup = 'ClientBullet'
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.CollisionGroup = 'ClientBullet'
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	OriginScanner.Ray = rayParams

	local positions = {
		Vector3.new(0, 1, 0),
		Vector3.new(1, 0, 0),
		Vector3.new(0.7, -0.5, -0.5),
		Vector3.new(-0.1, -0.8, -0.8),
		Vector3.new(-0.8, -0.5, -0.5),
		Vector3.new(-1, 0, 0),
		Vector3.new(-0.8, 0.4, 0.4),
		Vector3.new(0, 0.7, 0.7),
		Vector3.new(0.7, 0.5, 0.5),
		Vector3.new(1, 0, 0),
		Vector3.new(0.7, 0, -0.8),
		Vector3.new(-0.1, 0, -1),
		Vector3.new(-0.8, 0, -0.8),
		Vector3.new(-1, 0, 0),
		Vector3.new(-0.8, 0, 0.7),
		Vector3.new(0, 0, 1),
		Vector3.new(0.7, 0, 0.7),
		Vector3.new(1, 0, 0),
		Vector3.new(0.7, 0.4, -0.5),
		Vector3.new(-0.1, 0.7, -0.8),
		Vector3.new(-0.8, 0.4, -0.5),
		Vector3.new(-1, -0.1, 0),
		Vector3.new(-0.8, -0.5, 0.4),
		Vector3.new(0, -0.8, 0.7),
		Vector3.new(0.7, -0.6, 0.5),
		Vector3.new(0, -1, 0)
	}

	function OriginScanner:Scan(origin, target, extra, part, entity)
		if self.Cache[part] then
			return table.unpack(self.Cache[part])
		end

		local hitboxPositions = {}
		if checkPoint(target, overlapParams) then
			if extra and (origin - extra).Magnitude < 7.5 then
				self.Cache[part] = {extra}
				return extra
			end

			table.insert(hitboxPositions, target)
		end

		local scanPositions = {origin}
		local diff = CFrame.lookAt(origin * Vector3.new(1, 0, 1), target * Vector3.new(1, 0, 1)).LookVector
		for _, normal in Enum.NormalId:GetEnumItems() do
			local offset = Vector3.fromNormalId(normal)

			if (offset * Vector3.new(1, 0, 1)):Dot(-diff) > -0.5 then
				local pos = entity.RootPart.Position + offset * 7.4

				if checkPoint(pos, overlapParams) then
					table.insert(hitboxPositions, pos)
				end
			end
		end

		for _, offset in positions do
			if (offset * Vector3.new(1, 0, 1)):Dot(diff) > -0.5 then
				local pos = origin + offset * (7 - math.min(self.Offset, 1))

				if checkPoint(pos, overlapParams) then
					table.insert(scanPositions, pos)
				end
			end
		end

		for _, hitbox in hitboxPositions do
			for _, pos in scanPositions do
				local ray = workspace:Raycast(hitbox, (pos - hitbox), rayParams)

				if not ray then
					self.Cache[part] = {pos, hitbox ~= target and hitbox or nil}
					return pos, hitbox
				end
			end
		end
	end

	function OriginScanner:UpdateIgnore()
		local ignoreList = VehicleWallbang.Enabled and {lplr.Character, workspace.CarContainer} or {lplr.Character}
		for _, entity in entitylib.List do
			table.insert(ignoreList, entity.Character)
		end

		rayParams.FilterDescendantsInstances = ignoreList
		overlapParams.FilterDescendantsInstances = ignoreList
	end

	local localPositions = {}
	vape:Clean(task.spawn(function()
		repeat
			if entitylib.isAlive then
				repeat
					local _, obj = next(localPositions)
					if obj and (os.clock() - obj[2]) > 0.1 then
						table.remove(localPositions, 1)
					else
						break
					end
				until false

				table.insert(localPositions, {entitylib.character.RootPart.Position, os.clock()})
				OriginScanner.Offset = (entitylib.character.RootPart.Position - (localPositions[1] and localPositions[1][1] or entitylib.character.RootPart.Position)).Magnitude
			else
				table.clear(localPositions)
			end

			task.wait()
		until false
	end))
end)

local Cheats = {Flags = {}, Flagged = {}}
run(function()
	function Cheats:Flag(plr, flagType, limit)
		if self.Flagged[plr.UserId] then
			return
		end

		if not self.Flags[plr.UserId] then
			self.Flags[plr.UserId] = {}
		end

		local flags = self.Flags[plr.UserId]
		flags[flagType] = (flags[flagType] or 0) + 1

		if flags[flagType] > limit then
			self.Flagged[plr.UserId] = true
			vapeEvents.CheatFlagged:Fire(plr, flagType)
		end
	end

	function Cheats:Clear()
		table.clear(self.Flags)
		table.clear(self.Flagged)
	end
end)

run(function()
	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
		return inputService.GetMouseLocation(inputService)
	end

	entitylib.getUpdateConnections = function(entity)
		local humanoid = entity.Humanoid
		return {
			humanoid:GetPropertyChangedSignal('Health'),
			humanoid:GetPropertyChangedSignal('MaxHealth'),
			entity.Character:GetAttributeChangedSignal('Trespassing'),
			entity.Character:GetAttributeChangedSignal('Hostile'),
			entity.Player:GetAttributeChangedSignal('InnocentKills'),
			{
				Connect = function()
					entity.Friend = entity.Player and isFriend(entity.Player) or nil
					entity.Target = entity.Player and isTarget(entity.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}
	end

	entitylib.targetCheck = function(entity, skip)
		if entity.TeamCheck then
			return entity:TeamCheck()
		end
		if entity.NPC then return true end
		if isFriend(entity.Player) then return false end
		if not select(2, whitelist:get(entity.Player)) then return false end
		if vape.Settings.Modules.Options['Teams by server'].Enabled and (not skip or lplr.Team == teams.Guards) then
			return lplr.Team ~= entity.Player.Team and entity.Player.Team ~= teams.Neutral
		end
		return true
	end

	entitylib.isVulnerable = function(entity, attackCheck, skipCheck)
		if attackCheck and lplr.Team == teams.Guards and entity.Player.Team == teams.Inmates and not entity.Character:GetAttribute('Hostile') then
			return false
		end

		return entity.Health > 0 and entity.Humanoid:GetState() ~= Enum.HumanoidStateType.Dead and entity.SpawnTime < os.clock() and not not entity.Character:FindFirstChildWhichIsA('ForceField') and (entity.Player.Team ~= teams.Inmates or (skipCheck or entity.Character:GetAttribute('Trespassing') or entity.Character:GetAttribute('Hostile')))
	end

	entitylib.EntityMouse = function(entitysettings)
		if entitylib.isAlive then
			local mouseLocation, sortingTable = entitysettings.MouseOrigin or getMousePosition(), {}
			local localPosition = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position
			for _, entity in entitylib.List do
				if not entitysettings.Players and entity.Player then continue end
				if not entitysettings.NPCs and entity.NPC then continue end
				if not entity.Targetable then continue end
				local position, vis = gameCamera.WorldToViewportPoint(gameCamera, entity[entitysettings.Part].Position)
				if not vis then continue end
				local mag = (mouseLocation - Vector2.new(position.x, position.y)).Magnitude
				if mag > entitysettings.Range then continue end
				if entitylib.isVulnerable(entity, entitysettings.AttackCheck) then
					if entitysettings.RangePosition then
						local pmag = (entity[entitysettings.Part].Position - localPosition).Magnitude
						if pmag > entitysettings.RangePosition then continue end
					end

					table.insert(sortingTable, {
						Entity = entity,
						Magnitude = entity.Target and -1 or mag
					})
				end
			end

			table.sort(sortingTable, entitysettings.Sort or function(a, b)
				return a.Magnitude < b.Magnitude
			end)

			for _, v in sortingTable do
				if entitysettings.Wallcheck then
					if entitylib.Wallcheck(entitysettings.Origin, v.Entity[entitysettings.Part].Position, entitysettings.Wallbang, v.Entity[entitysettings.Part], v.Entity) then continue end
				end
				table.clear(entitysettings)
				table.clear(sortingTable)
				return v.Entity
			end
			table.clear(sortingTable)
		end
		table.clear(entitysettings)
	end

	entitylib.EntityPosition = function(entitysettings)
		if entitylib.isAlive then
			local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
			for _, entity in entitylib.List do
				if not entitysettings.Players and entity.Player then continue end
				if not entitysettings.NPCs and entity.NPC then continue end
				if not entity.Targetable then continue end
				local mag = (entity[entitysettings.Part].Position - localPosition).Magnitude
				if mag > entitysettings.Range then continue end
				if entitylib.isVulnerable(entity, entitysettings.AttackCheck) then
					table.insert(sortingTable, {
						Entity = entity,
						Magnitude = entity.Target and -1 or mag
					})
				end
			end

			table.sort(sortingTable, entitysettings.Sort or function(a, b)
				return a.Magnitude < b.Magnitude
			end)

			for _, v in sortingTable do
				if entitysettings.Wallcheck then
					if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, entitysettings.Wallbang, v.Entity[entitysettings.Part], v.Entity) then continue end
				end
				table.clear(entitysettings)
				table.clear(sortingTable)
				return v.Entity
			end
			table.clear(sortingTable)
		end
		table.clear(entitysettings)
	end

	entitylib.AllPosition = function(entitysettings)
		local returned = {}
		if entitylib.isAlive then
			local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
			for _, entity in entitylib.List do
				if not entitysettings.Players and entity.Player then continue end
				if not entitysettings.NPCs and entity.NPC then continue end
				if not (entity.Targetable or entitysettings.SkipTeam and entitylib.targetCheck(entity, true)) then continue end
				local mag = (entity[entitysettings.Part].Position - localPosition).Magnitude
				if mag > entitysettings.Range then continue end
				if entitylib.isVulnerable(entity, entitysettings.AttackCheck, entitysettings.SkipTeam) then
					table.insert(sortingTable, {
						Entity = entity,
						Magnitude = entity.Target and -1 or mag
					})
				end
			end

			table.sort(sortingTable, entitysettings.Sort or function(a, b)
				return a.Magnitude < b.Magnitude
			end)

			for _, v in sortingTable do
				if entitysettings.Wallcheck then
					if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, entitysettings.Wallbang, v.Entity[entitysettings.Part], v.Entity) then continue end
				end
				table.insert(returned, v.Entity)
				if #returned >= (entitysettings.Limit or math.huge) then break end
			end
			table.clear(sortingTable)
		end
		table.clear(entitysettings)
		return returned
	end

	entitylib.getEntityColor = function(entity)
		if not (entity.Player and vape.Settings.Modules.Options['Use team color'].Enabled) then
			return
		end

		if isFriend(entity.Player, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end

		local color = tostring(entity.Player.TeamColor) ~= 'White' and entity.Player.TeamColor.Color or nil
		if entity.Player.Team == teams.Inmates and (entity.Character:GetAttribute('Hostile') or entity.Character:GetAttribute('Trespassing')) then
			return Color3.new(color.R, color.G * 0.5, color.B * 0.5)
		end

		return color
	end

	entitylib.Wallcheck = function(origin, position, checkPosition, part, entity)
		local ray = workspace.Raycast(workspace, position, (origin - position), OriginScanner.Ray)
		if ray or workspace.Raycast(workspace, origin, (position - origin), OriginScanner.Ray) then
			return not checkPosition or not OriginScanner:Scan(checkPosition, position, ray and ray.Position + ray.Normal * 0.01 or nil, part, entity)
		end

		return false
	end
end)
entitylib.start()

run(function()
	pl = {
		GunTracers = require(replicatedStorage.SharedModules.GunTracers)
	}

	local gui = lplr.PlayerGui:WaitForChild('Home', 10)
	gui = gui and gui.hud.ActionArea
	if vape.Loaded == nil then
		return
	end

	local function getShootFunction()
		for _, connection in getconnections(gui.InputBegan) do
			if connection.Function then
				pl.Shoot = debug.getupvalue(connection.Function, 2)
				pl.Reload = debug.getupvalue(pl.Shoot, 2)
				pl.Bullet = debug.getupvalue(pl.Shoot, 16)
				pl.PlaySound = debug.getupvalue(pl.Reload, 3)
				break
			end
		end

		for _, connection in getconnections(lplr.CharacterAdded) do
			if connection.Function and debug.info(connection.Function, 's'):find('GunController') then
				pl.ShootParams = debug.getupvalue(connection.Function, 2)
				pl.Equip = debug.getupvalue(connection.Function, 3)
				break
			end
		end

		for _, connection in getconnections(lplr:GetAttributeChangedSignal('BackpackEnabled')) do
			pl.SwitchUpdate = debug.getupvalue(debug.getupvalue(connection.Function, 10), 5)
			pl.SwitchTable = debug.getupvalue(debug.getupvalue(connection.Function, 8), 2)
			break
		end
	end

	getShootFunction()
	if not (pl.Bullet and pl.SwitchTable) then
		repeat
			getShootFunction()
			task.wait()
		until pl.Bullet and pl.SwitchTable or vape.Loaded == nil

		if vape.Loaded == nil then
			table.clear(pl)
		end
	end

	local kills = sessioninfo:AddItem('Kills')
	local deaths = sessioninfo:AddItem('Deaths')
	local arrests = sessioninfo:AddItem('Arrests')
	local cheaterkicked = sessioninfo:AddItem('Cheaters Kicked')
	local cheaters = sessioninfo:AddItem('Cheater List', '', function()
		local text = ''
		for _, plr in playersService:GetPlayers() do
			if Cheats.Flagged[plr.UserId] then
				text = text..'\n'..(plr.DisplayName ~= plr.Name and plr.DisplayName..' ('..plr.Name..')' or plr.Name)
			end
		end

		return text
	end, false)

	if type(whitelist.tagcallback) ~= 'table' then
		whitelist.tagcallback = {}
	end

	table.insert(whitelist.tagcallback, function(plr, plrtag, rich)
		if plr then
			local entity = entitylib.getEntity(plr)

			if entity then
				if Cheats.Flagged[plr.UserId] then
					table.insert(plrtag, {
						text = rich and '⚠️' or 'Cheater'
					})
				end

				if plr.Team == teams.Inmates then
					if entity.Character:GetAttribute('Hostile') then
						table.insert(plrtag, {
							text = rich and '💢' or 'Hostile'
						})
					elseif entity.Character:GetAttribute('Trespassing') then
						table.insert(plrtag, {
							text = rich and '🔗' or 'Trespassing'
						})
					end
				elseif plr.Team == teams.Guards then
					local count = plr:GetAttribute('InnocentKills') or 0

					if count > 0 then
						table.insert(plrtag, {
							text = tostring(count),
							color = Color3.fromHSV(
								math.clamp(1 - (count / 2), 0, 1) / 2.5,
								0.89,
								0.75
							)
						})
					end
				end
			end
		end
	end)

	task.spawn(function()
		gamepasses = {
			['Riot Police'] = marketplaceService:UserOwnsGamePassAsync(lplr.UserId, 643697197),
			Mafia = marketplaceService:UserOwnsGamePassAsync(lplr.UserId, 1443271),
			Sniper = marketplaceService:UserOwnsGamePassAsync(lplr.UserId, 699360089)
		}
	end)

	OriginScanner:UpdateIgnore()
	for _, event in {'EntityAdded', 'LocalAdded'} do
		vape:Clean(entitylib.Events[event]:Connect(function()
			OriginScanner:UpdateIgnore()
		end))
	end

	vape:Clean(replicatedStorage.Killfeed.ChildAdded:Connect(function(obj)
		local names = {}

		-- killer
		local start = obj.Name:find('@')
		local endchar = obj.Name:find(')')
		table.insert(names, obj.Name:sub(start + 1, endchar - 1))

		-- victim
		start = obj.Name:find('killed ') + 7
		endchar = obj.Name:find(' ', start)
		table.insert(names, obj.Name:sub(start, endchar - 1))

		vapeEvents.PlayerKill:Fire(unpack(names))
		if names[1] == lplr.Name then
			kills:Increment()
		elseif names[2] == lplr.Name then
			deaths:Increment()
		end
	end))

	vape:Clean(vapeEvents.Arrested.Event:Connect(function()
		arrests:Increment()
	end))

	vape:Clean(replicatedStorage.Remotes.MessageReceived.OnClientEvent:Connect(function(msg)
		if msg:find('kicked') then
			cheaterkicked:Increment()

			task.defer(function()
				vapeEvents.CheaterKicked:Fire(msg:sub(1, msg:find(' ')))
			end)
		end
	end))

	vape:Clean(entitylib.Events.EntityUpdated:Connect(function(entity)
		if entity.Player and entity.Player.Team == teams.Inmates then
			vape.Categories.Friends.ColorUpdate:Fire()
		end
	end))

	vape:Clean(runService.RenderStepped:Connect(function()
		table.clear(OriginScanner.Cache)
	end))

	vape:Clean(function()
		table.clear(pl)
	end)
end)

run(function()
	-- https://github.com/J1ck/roblox-spring/blob/main/src/roblox-spring.luau
	Spring.__index = Spring

	function Spring.new(Properties)
		local TypeRefined = Properties or {}

		local self = setmetatable({
			Target = Vector3.new(),
			Position = Vector3.new(),
			Velocity = Vector3.new(),

			Mass = TypeRefined.Mass or 5,
			Force = TypeRefined.Force or 50,
			Damping	= TypeRefined.Damping or 4,
			Speed = TypeRefined.Speed or 4,
		}, Spring)

		return self
	end

	function Spring:Update(DeltaTime)
		local IterationsThisFrame = DeltaTime / ((1 / 60) / 8)
		local ScaledDeltaTime = DeltaTime * self.Speed / IterationsThisFrame

		for i = 1, math.round(IterationsThisFrame) do
			local IterationForce = self.Target - self.Position
			local Acceleration = (IterationForce * self.Force) / self.Mass

			Acceleration -= self.Velocity * self.Damping

			self.Velocity += Acceleration * ScaledDeltaTime
			self.Position += self.Velocity * ScaledDeltaTime
		end

		return self.Position
	end
end)

run(function()
	local oldtracer, oldtracertaser, oldtracersniper

	local function Hook(...)
		if debug.info(3, 's') ~= 'ReplicatedStorage.Scripts.Replication.ClientReplicator' then
			for _, v in TracerHook.Hooks do
				if v[2](...) then return end
			end
		end

		return oldtracer(...)
	end

	local function HookTaser(...)
		if debug.info(3, 's') ~= 'ReplicatedStorage.Scripts.Replication.ClientReplicator' then
			for _, v in TracerHook.Hooks do
				if v[2](...) then return end
			end
		end

		return oldtracertaser(...)
	end

	local function HookSniper(...)
		if debug.info(3, 's') ~= 'ReplicatedStorage.Scripts.Replication.ClientReplicator' then
			for _, v in TracerHook.Hooks do
				if v[2](...) then return end
			end
		end

		return oldtracersniper(...)
	end

	function TracerHook:Add(key, val, priority)
		table.insert(self.Hooks, {key, val, priority or 0})
		table.sort(self.Hooks, function(a, b)
			return a[3] < b[3]
		end)

		if not oldtracer then
			oldtracer = hookfunction(pl.GunTracers.createBullet, function(...)
				return Hook(...)
			end)

			oldtracertaser = hookfunction(pl.GunTracers.createTaser, function(...)
				return HookTaser(...)
			end)

			oldtracersniper = hookfunction(pl.GunTracers.createSniper, function(...)
				return HookSniper(...)
			end)
		end
	end

	function TracerHook:Remove(key)
		for i, v in self.Hooks do
			if v[1] == key then
				table.remove(self.Hooks, i)
				break
			end
		end

		if oldtracer and not next(self.Hooks) then
			if restorefunction then
				restorefunction(pl.GunTracers.createBullet)
				restorefunction(pl.GunTracers.createTaser)
				restorefunction(pl.GunTracers.createSniper)
			else
				hookfunction(pl.GunTracers.createBullet, oldtracer)
				hookfunction(pl.GunTracers.createTaser, oldtracertaser)
				hookfunction(pl.GunTracers.createSniper, oldtracersniper)
			end

			oldtracer = nil
			oldtracertaser = nil
			oldtracersniper = nil
		end
	end
end)

for _, v in {'Reach', 'Jesus', 'MurderMystery','Timer'} do
	vape:Remove(v)
end

run(function()
	local AntiFling
	local modified = {}

	local function LocalAdded(entity)
		for _, prompt in workspace.CarContainer:QueryDescendants('ProximityPrompt') do
			prompt.Enabled = not entity.Humanoid.SeatPart and not prompt.Parent.Occupant
		end

		AntiFling:Clean(entity.Humanoid:GetPropertyChangedSignal('SeatPart'):Connect(function()
			for _, prompt in workspace.CarContainer:QueryDescendants('ProximityPrompt') do
				prompt.Enabled = not entity.Humanoid.SeatPart and not prompt.Parent.Occupant
			end
		end))
	end

	local function Modify(part)
		if part:IsA('BasePart') and part.CollisionGroup ~= 'Wheels' then
			if not modified[part] then
				modified[part] = {part.CanCollide, part.CanQuery}
			end

			if (part:IsA('Seat') or part:IsA('VehicleSeat')) and part.Name == part.ClassName then
				local connection
				local prox = Instance.new('ProximityPrompt')
				prox.ActionText = 'Enter'
				prox.Enabled = not part.Occupant
				prox.MaxActivationDistance = 8
				prox.RequiresLineOfSight = false
				prox.Parent = part

				prox.Triggered:Connect(function()
					if entitylib.isAlive then
						part:Sit(entitylib.character.Humanoid)
					end
				end)

				prox.Destroying:Connect(function()
					connection:Disconnect()
				end)

				connection = part:GetPropertyChangedSignal('Occupant'):Connect(function()
					prox.Enabled = not part.Occupant
				end)
			end

			part.CanCollide = false
			part.CanTouch = false
		end
	end

	AntiFling = vape.Categories.Blatant:CreateModule({
		Name = 'AntiFling',
		Function = function(callback)
			if callback then
				AntiFling:Clean(workspace.CarContainer.DescendantAdded:Connect(Modify))
				AntiFling:Clean(entitylib.Events.LocalAdded:Connect(LocalAdded))

				for _, part in workspace.CarContainer:QueryDescendants('BasePart') do
					Modify(part)
				end

				if entitylib.isAlive then
					LocalAdded(entitylib.character)
				end
			else
				for part, value in modified do
					part.CanCollide = value[1]
					part.CanTouch = value[2]
				end

				for _, prompt in workspace.CarContainer:QueryDescendants('ProximityPrompt') do
					prompt:Destroy()
				end

				table.clear(modified)
			end
		end,
		Tooltip = 'Prevent certain methods of flinging you'
	})
end)

run(function()
	local AntiInvisible
	local threads = {}
	local whitelist = {
		-- default roblox animations
		['http://www.roblox.com/asset/?id=125750702'] = true,
		['http://www.roblox.com/asset/?id=128777973'] = true,
		['http://www.roblox.com/asset/?id=128853357'] = true,
		['http://www.roblox.com/asset/?id=129423030'] = true,
		['http://www.roblox.com/asset/?id=129423131'] = true,
		['http://www.roblox.com/asset/?id=129967390'] = true,
		['http://www.roblox.com/asset/?id=129967478'] = true,
		['http://www.roblox.com/asset/?id=178130996'] = true,
		['http://www.roblox.com/asset/?id=180426354'] = true,
		['http://www.roblox.com/asset/?id=180435571'] = true,
		['http://www.roblox.com/asset/?id=180435792'] = true,
		['http://www.roblox.com/asset/?id=180436148'] = true,
		['http://www.roblox.com/asset/?id=180436334'] = true,
		['http://www.roblox.com/asset/?id=182393478'] = true,
		['http://www.roblox.com/asset/?id=182435998'] = true,
		['http://www.roblox.com/asset/?id=182436842'] = true,
		['http://www.roblox.com/asset/?id=182436935'] = true,
		['http://www.roblox.com/asset/?id=182491037'] = true,
		['http://www.roblox.com/asset/?id=182491065'] = true,
		['http://www.roblox.com/asset/?id=182491248'] = true,
		['http://www.roblox.com/asset/?id=182491277'] = true,
		['http://www.roblox.com/asset/?id=182491368'] = true,
		['http://www.roblox.com/asset/?id=182491423'] = true,
		-- game animations
		['rbxassetid://279227693'] = true,
		['rbxassetid://279229192'] = true,
		['rbxassetid://287112271'] = true,
		['rbxassetid://388723916'] = true,
		['rbxassetid://388726667'] = true,
		['rbxassetid://389472570'] = true,
		['rbxassetid://405194080'] = true,
		['rbxassetid://405212265'] = true,
		['rbxassetid://481088553'] = true,
		['rbxassetid://481089053'] = true,
		['rbxassetid://484200742'] = true,
		['rbxassetid://484926359'] = true,
		['rbxassetid://83690472549256'] = true,
		['rbxassetid://107176344504758'] = true,
		['rbxassetid://111090572475133'] = true,
		['rbxassetid://113267949064300'] = true,
		['rbxassetid://131326339350805'] = true
	}

	local function AnimationAdded(anim, plr)
		if not whitelist[anim.Animation.AnimationId] and plr then
			if threads[anim] then
				task.cancel(threads[anim])
			end

			Cheats:Flag(plr, 'invalid animation', 1)
			threads[anim] = task.spawn(function()
				repeat
					anim:AdjustWeight(0, 0)
					task.wait()
				until not (anim.IsPlaying and AntiInvisible.Enabled)

				threads[anim] = nil
			end)
		end
	end

	local function EntityAdded(ent)
		local animator = ent.Humanoid:WaitForChild('Animator', 5)

		if animator and AntiInvisible.Enabled then
			AntiInvisible:Clean(animator.AnimationPlayed:Connect(function(anim)
				AnimationAdded(anim, ent.Player)
			end))

			for _, anim in animator:GetPlayingAnimationTracks() do
				task.spawn(AnimationAdded, anim, ent.Player)
			end
		end
	end

	for _, v in replicatedStorage:QueryDescendants('Animation') do
		whitelist[v.AnimationId] = true
	end

	AntiInvisible = vape.Categories.Blatant:CreateModule({
		Name = 'AntiInvisible',
		Function = function(callback)
			if callback then
				AntiInvisible:Clean(entitylib.Events.EntityAdded:Connect(EntityAdded))
				for _, v in entitylib.List do
					task.spawn(EntityAdded, v)
				end
			else
				for _, v in threads do
					task.cancel(v)
				end
				table.clear(threads)
			end
		end,
		Tooltip = 'Prevent people from using animations outside of the game\'s scope'
	})
end)

run(function()
	local AntiKillPlane

	AntiKillPlane = vape.Categories.Blatant:CreateModule({
		Name = 'AntiKillPlane',
		Function = function(callback)
			if callback then
				AntiKillPlane:Clean(runService.Heartbeat:Connect(function()
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local diff = math.clamp(root.Position.Y, -10, 179.99) - root.Position.Y

						if math.abs(diff) > 0 then
							root.CFrame += Vector3.new(0, diff, 0)
							root.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)
						end
					end
				end))
			end
		end,
		Tooltip = 'Prevents you from touching the kill plane'
	})
end)

run(function()
	local AntiRiotShield

	AntiRiotShield = vape.Categories.Blatant:CreateModule({
		Name = 'AntiRiotShield',
		Function = function(callback)
			if callback then
				repeat
					for _, entity in entitylib.List do
						local shield = entity.Character:FindFirstChild('RiotShieldPart')
						if shield then
							shield.CanQuery = false
						end
					end

					task.wait(0.05)
				until not AntiRiotShield.Enabled
			else
				for _, entity in entitylib.List do
					local shield = entity.Character:FindFirstChild('RiotShieldPart')
					if shield then
						shield.CanQuery = true
					end
				end
			end
		end,
		Tooltip = 'Allow you to shoot through riot shields.'
	})
end)

run(function()
	local AntiTaze
	local old, connection

	local function EntityAdded(ent)
		connection = getconnections(replicatedStorage.GunRemotes.PlayerTased.OnClientEvent)[1]
		if not (connection and connection.Function) then
			repeat
				connection = getconnections(replicatedStorage.GunRemotes.PlayerTased.OnClientEvent)[1]
				task.wait()
			until connection and connection.Function or not AntiTaze.Enabled
		end

		if connection and AntiTaze.Enabled then
			old = hookfunction(connection.Function, function()
				local char = lplr.Character
				lplr:SetAttribute('BackpackEnabled', false)
				if entitylib.isAlive then
					entitylib.character.Humanoid:UnequipTools()
				end

				task.wait(3.5)
				if lplr.Character == char then
					lplr:SetAttribute('BackpackEnabled', true)
				end
			end)
		end
	end

	AntiTaze = vape.Categories.Blatant:CreateModule({
		Name = 'AntiTaze',
		Function = function(callback)
			if callback then
				AntiTaze:Clean(entitylib.Events.LocalAdded:Connect(EntityAdded))
				if entitylib.isAlive then
					task.spawn(EntityAdded, entitylib.character)
				end
			else
				if old and connection.Function then
					hookfunction(connection.Function, old)
					old = nil
				end
			end
		end,
		Tooltip = 'Prevent you from getting tazed'
	})
end)

run(function()
	local AutoArrest
	local Range
	local HandCheck
	local CooldownBar
	local toggles = {}
	local cdholder, cdframe, cdlabel
	local arrestCooldown = 0

	AutoArrest = vape.Categories.Blatant:CreateModule({
		Name = 'AutoArrest',
		Function = function(callback)
			if callback then
				repeat
					local check = arrestCooldown < os.clock()
					if HandCheck.Enabled then
						local tool = entitylib.isAlive and lplr.Character:FindFirstChildWhichIsA('Tool')
						check = check and tool and tool.Name == 'Handcuffs'
					end

					if check then
						local entities = entitylib.AllPosition({
							Range = Range.Value,
							Players = true,
							Part = 'RootPart',
							TargetCheck = true
						})

						for _, ent in entities do
							if not ent.Character:GetAttribute('Arrested') then
								local toggle = ent.Player.Team and toggles[ent.Player.Team.Name]
								if toggle and not toggle.Enabled then
									continue
								end

								if ent.Player.Team == teams.Inmates and ent.Character:GetAttribute('Hostile') and not ent.Character:GetAttribute('Tased') then
									continue
								end

								if replicatedStorage.Remotes.ArrestPlayer:InvokeServer(ent.Player, 1) then
									arrestCooldown = os.clock() + 7
									vapeEvents.Arrested:Fire()
									notif('AutoArrest', 'Arrested '..(ent.Player.Name), 7)
								end

								break
							end
						end
					end

					if cdholder then
						cdholder.Visible = arrestCooldown > os.clock()

						if cdholder.Visible then
							local diff = (arrestCooldown - os.clock())
							cdframe.Size = UDim2.new(math.clamp(diff / 7, 0, 1), -2, 1, -2)
							cdlabel.Text = (math.round(diff * 10) / 10)..'s'
						end
					end

					task.wait(0.05)
				until not AutoArrest.Enabled
			else
				if cdholder then
					cdholder.Visible = false
				end
			end
		end,
		Tooltip = 'Automatically uses handcuffs on nearby entities'
	})
	Range = AutoArrest:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 8,
		Default = 8,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	HandCheck = AutoArrest:CreateToggle({
		Name = 'Hand Check',
		Tooltip = 'Only arrest if you have handcuffs equipped.'
	})
	CooldownBar = AutoArrest:CreateToggle({
		Name = 'Cooldown Bar',
		Function = function(callback)
			if callback then
				cdholder = Instance.new('Frame')
				cdholder.Visible = false
				cdholder.BorderSizePixel = 0
				cdholder.BackgroundTransparency = 0.7
				cdholder.AnchorPoint = Vector2.new(0.5, 0)
				cdholder.BackgroundColor3 = Color3.new(1, 1, 1)
				cdholder.Size = UDim2.new(0.1, 0, 0, 5)
				cdholder.Position = UDim2.fromScale(0.5, 0.55)
				cdholder.Parent = vape.gui
				cdframe = Instance.new('Frame')
				cdframe.BorderSizePixel = 0
				cdframe.BackgroundTransparency = 0.3
				cdframe.BackgroundColor3 = Color3.new(1, 1, 1)
				cdframe.Size = UDim2.new(1, -2, 1, -2)
				cdframe.Position = UDim2.fromOffset(1, 1)
				cdframe.Parent = cdholder
				cdlabel = Instance.new('TextLabel')
				cdlabel.Size = UDim2.new(1, 0, 0, 14)
				cdlabel.Position = UDim2.fromOffset(0, 10)
				cdlabel.BackgroundTransparency = 1
				cdlabel.TextColor3 = Color3.new(1, 1, 1)
				cdlabel.TextScaled = true
				cdlabel.TextStrokeTransparency = 0
				cdlabel.Font = Enum.Font.Arial
				cdlabel.Parent = cdholder
			else
				if cdholder then
					cdholder:Destroy()
					cdholder = nil
				end
			end
		end,
		Tooltip = 'Show the cooldown for arresting'
	})

	for _, v in {'Inmates', 'Criminals'} do
		toggles[v] = AutoArrest:CreateToggle({
			Name = 'Arrest '..v,
			Default = true
		})
	end
end)

run(function()
	local AutoReset

	AutoReset = vape.Categories.Blatant:CreateModule({
		Name = 'AutoReset',
		Function = function(callback)
			if callback then
				AutoReset:Clean(lplr:GetPropertyChangedSignal('Team'):Connect(function()
					if lplr.Team == teams.Criminals and entitylib.isAlive then
						entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
					end
				end))
			end
		end,
		Tooltip = 'Automatically reset after becoming a criminal.'
	})
end)

run(function()
	local AutoTaze
	local Range
	local VelocityCheck
	local cooldown = 0

	AutoTaze = vape.Categories.Blatant:CreateModule({
		Name = 'AutoTaze',
		Function = function(callback)
			if callback then
				repeat
					local backpack = lplr:FindFirstChildWhichIsA('Backpack')
					local taser = backpack and backpack:FindFirstChild('Taser')

					if taser and (taser:GetAttribute('CurrentAmmo') or 1) > 0 and cooldown < os.clock() and (arrestCooldown - os.clock()) < 3 then
						if not VelocityCheck.Enabled or entitylib.isAlive and entitylib.character.RootPart.AssemblyLinearVelocity.Magnitude < 40 then
							local entities = entitylib.AllPosition({
								Range = Range.Value,
								AttackCheck = false,
								Wallcheck = true,
								Part = 'Head',
								Origin = entitylib.isAlive and entitylib.character.Head.Position or Vector3.zero,
								Players = true
							})

							for _, entity in entities do
								if not (entity.Character:GetAttribute('Tased') or entity.Character:GetAttribute('Arrested')) then
									cooldown = os.clock() + 2
									entitylib.character.Humanoid:EquipTool(taser)
									break
								end
							end
						end
					end

					task.wait(0.05)
				until not AutoTaze.Enabled
			end
		end,
		Tooltip = 'Automatically taze people around you. (only works with SilentAim AutoFire with Position Mode enabled)'
	})
	Range = AutoTaze:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 52,
		Default = 52,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	VelocityCheck = AutoTaze:CreateToggle({
		Name = 'Velocity Check',
		Default = true
	})
end)

run(function()
	local FenceGodmode

	FenceGodmode = vape.Categories.Blatant:CreateModule({
		Name = 'FenceGodmode',
		Function = function(callback)
			for _, fence in workspace.Prison_Fences:QueryDescendants('BasePart:has(> TouchTransmitter)') do
				fence.CanTouch = not callback
			end
		end,
		Tooltip = 'Ignore damage from standing ontop of fences.'
	})
end)

run(function()
	local FlingExploit
	local Mode
	local List
	local Movement
	local Equipment
	local AutoRejoin
	local PlayerLimit
	local TimeLimit
	local HopList
	local didClick = {}
	local lastFling = {}
	local tempList = setmetatable({}, {
		__mode = 'k'
	})

	local function getTarget(seat)
		local tEntity = tempList[seat]
		if tEntity and tEntity.RootPart:IsDescendantOf(workspace) and (os.clock() - lastFling[tEntity.Player.Name]) < 0.75 and not (tEntity.Humanoid.Sit and tEntity.Humanoid.SeatPart.Anchored) then
			return tEntity
		end

		if entitylib.isAlive then
			local cloned = table.clone(entitylib.List)
			table.sort(cloned, function(a, b)
				return (lastFling[a.Player.Name] or 0) < (lastFling[b.Player.Name] or 0)
			end)

			for _, entity in cloned do
				if isFriend(entity.Player) then continue end
				if not select(2, whitelist:get(entity.Player)) then continue end
				if entity.Player.Team == teams.Neutral then continue end
				if Mode.Value ~= 'All' and not table.find(List.ListEnabled, entity.Player.Name) then continue end
				if not (entity.Humanoid.Sit and entity.Humanoid.SeatPart.Anchored) and entity.RootPart:IsDescendantOf(workspace) and (os.clock() - entity.SpawnTime) > 2 then
					lastFling[entity.Player.Name] = os.clock()
					tempList[seat] = entity
					table.clear(cloned)
					notif('FlingExploit', 'Attempted fling: '..entity.Player.Name, 5)
					return entity
				end
			end

			table.clear(cloned)
		end
	end

	FlingExploit = vape.Categories.Blatant:CreateModule({
		Name = 'FlingExploit',
		Function = function(callback)
			if callback then
				local reqTimer = os.clock()
				local startTime = os.clock()
				local dir = 0

				if not vape.Modules.AntiFling.Enabled then
					vape.Modules.AntiFling:Toggle()
				end

				if AutoRejoin.Enabled then
					for _, plr in playersService:GetPlayers() do
						if plr and plr.Team ~= teams.Neutral and table.find(HopList.ListEnabled, plr.Name) then
							repeat
								vape.Modules.ServerHop:Toggle()
								task.wait(1)
							until not FlingExploit.Enabled

							return
						end
					end
				end

				FlingExploit:Clean(runService.Heartbeat:Connect(function(dt)
					if lplr.Team == teams.Neutral then
						local gui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)
						if gui then
							local buttons = gui:GetChildren()
							table.sort(buttons, function(a, b)
								return (a.Name == 'Inmates' and 1 or 2) < (b.Name == 'Inmates' and 1 or 2)
							end)

							for _, holder in buttons do
								if holder.Button.AutoButtonColor then
									pickTeam(holder.Button)
									break
								end
							end
						end

						return
					end

					if AutoRejoin.Enabled then
						local plrCount = #teams.Guards:GetPlayers() + #teams.Inmates:GetPlayers() + #teams.Criminals:GetPlayers()

						if ((os.clock() - startTime) > TimeLimit.Value * 60 or plrCount <= PlayerLimit.Value) then
							if (os.clock() - reqTimer) > 1 then
								vape.Modules.ServerHop:Toggle()
								reqTimer = os.clock()
							end

							return
						end
					end

					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local didMove

						for _, button in workspace.Prison_ITEMS.buttons:GetChildren() do
							if button.Name == 'Car Spawner' then
								local mag = (button['Car Spawner'].Position - root.Position).Magnitude
								if mag < 15 and (didClick[button] or 0) < os.clock() then
									didClick[button] = os.clock() + 0.2
									task.spawn(function()
										replicatedStorage.Remotes.InteractWithItem:InvokeServer(button['Car Spawner'])
									end)
								end

								if mag < 50 and button['Car Spawner'].BrickColor == BrickColor.new('Cyan') and not didMove then
									local diff = math.clamp((button['Car Spawner'].Position - root.Position).X, -1, 1)
									dir = math.clamp(dir + (diff * dt * 24), -12, 14)
									didMove = true
								end
							end
						end

						if not didMove then
							local diff = math.clamp(0 - dir, -1, 1)
							dir = math.clamp(dir + (diff * dt * 24), -12, 14)
						end

						if Movement.Enabled then
							if Equipment.Enabled and (os.clock() - entitylib.character.SpawnTime) < 2 then
								local backpack = lplr:FindFirstChildWhichIsA('Backpack')
								local btool = backpack and backpack:FindFirstChildWhichIsA('Tool') or nil
								local ltool = lplr.Character:FindFirstChildWhichIsA('Tool')

								if not (btool or ltool) then
									root.CFrame = CFrame.new(Vector3.new(816, 98, 2233))
									return
								elseif btool and not ltool then
									entitylib.character.Humanoid:EquipTool(btool)
								end
							end

							if (root.Position - Vector3.new(633, 98, 2489)).Magnitude < 40 or (os.clock() - entitylib.character.SpawnTime) < 2 then
								root.CFrame = CFrame.new(Vector3.new(610 + dir, 90, 2494))
								root.AssemblyLinearVelocity = Vector3.new(24, 0, 0)
							end
						end

						for _, seat in workspace.CarContainer:QueryDescendants('VehicleSeat') do
							if isnetworkowner(seat) then
								local target = getTarget(seat)
								if target then
									seat.AssemblyLinearVelocity = Vector3.new(10000, 10000, 0)
									seat.CFrame = CFrame.new(target.RootPart.Position) * CFrame.new(-2, 0, -12)
									target.RootPart.AssemblyLinearVelocity = Vector3.zero
									sethiddenproperty(seat, 'PhysicsRepRootPart', target.RootPart)
									sethiddenproperty(seat, 'PhysicsRepRootRef', InstanceHandle.new(target.RootPart))

									local wheels = seat.Parent.Parent:FindFirstChild('Wheels')
									if wheels then
										wheels:Destroy()
									end
								end
							end
						end
					end
				end))
			end
		end,
		Tooltip = 'aesthetical, just remove collisions on vehicles please, this is the worst.'
	})
	Mode = FlingExploit:CreateDropdown({
		Name = 'Mode',
		List = {'All', 'Individual'},
		Function = function(value)
			List.Object.Visible = value ~= 'All'
		end
	})
	List = FlingExploit:CreateTextList({
		Name = 'Targets',
		Placeholder = 'Roblox username',
		Player = true,
		Visible = false,
		Darker = true
	})
	Movement = FlingExploit:CreateToggle({
		Name = 'Movement',
		Default = true
	})
	Equipment = FlingExploit:CreateToggle({
		Name = 'Equipment',
		Tooltip = 'Grab a gun before kicking to kill seated players.'
	})
	AutoRejoin = FlingExploit:CreateToggle({
		Name = 'AutoRejoin',
		Function = function(callback)
			PlayerLimit.Object.Visible = callback
			TimeLimit.Object.Visible = callback
			HopList.Object.Visible = callback
		end,
		Tooltip = 'Automatically server hop after certain conditions are met.'
	})
	PlayerLimit = FlingExploit:CreateSlider({
		Name = 'Player Limit',
		Min = 1,
		Max = 24,
		Default = 10,
		Visible = false,
		Darker = true,
		Suffix = function(value)
			return value == 1 and 'player' or 'players'
		end
	})
	TimeLimit = FlingExploit:CreateSlider({
		Name = 'Time Limit',
		Min = 1,
		Max = 20,
		Default = 6,
		Visible = false,
		Darker = true,
		Suffix = function(value)
			return value == 1 and 'minute' or 'minutes'
		end
	})
	HopList = FlingExploit:CreateTextList({
		Name = 'Hop List',
		Placeholder = 'Roblox username',
		Tooltip = 'Automatically hop if the player is spawned in and in the server, good for multiboxing.',
		Player = true,
		Visible = false,
		Darker = true
	})
end)

run(function()
local GunModifications
local Spread
local FireRate
local Automatic
local olddata, old = {}
local oldhook

local function Modify()
	local data = debug.getupvalue(oldshoot or pl.Shoot, 10)
	if data and GunModifications.Enabled then
		if old ~= data then
			olddata = table.clone(data)
			old = data
		end

		data.SpreadRadius = Spread.Enabled and 0 or olddata.SpreadRadius
		data.FireRate = (olddata.FireRate or 0) * (FireRate.Value / 100)
		data.AutoFire = Automatic.Enabled or olddata.AutoFire
	end
end


GunModifications = vape.Categories.Blatant:CreateModule({
	Name = 'GunModifications',
	Function = function(callback)
		if callback then
			oldequip = hookfunction(pl.Equip, function(...)
				local res = table.pack(oldequip(...))
				Modify()
				return unpack(res, 1, res.n)
			end)

			Modify()
		else
			if oldequip then
				if restorefunction then
					restorefunction(pl.Equip)
				else
					oldequip = nil
				end
			end

			if old then
				for i, v in olddata do
					old[i] = v
				end
				table.clear(olddata)
				old = nil
			end
		end
	end,
	Tooltip = 'Apply various modifications to enhance any firearm'
})
FireRate = GunModifications:CreateSlider({
	Name = 'FireRate Multiplier',
	Min = 1,
	Max = 100,
	Default = 100,
	Suffix = '%',
	Function = Modify
})
Spread = GunModifications:CreateToggle({
	Name = 'No Spread',
	Function = Modify
})
Automatic = GunModifications:CreateToggle({
	Name = 'Full Automatic',
	Function = Modify
})
end)

run(function()
	local Killaura
	local Targets
	local AttackRange
	local AngleSlider
	local Max
	local Mouse
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Overlay = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	local Particles, Boxes, AttackDelay = {}, {}, tick()

	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end

		return true
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				repeat
					local canAttack = getAttackData()
					local attacked = {}

					if canAttack then
						local entities = entitylib.AllPosition({
							Range = AttackRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = Max.Value,
							AttackCheck = true,
							SkipTeam = true
						})

						if #entities > 0 then
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

							for _, entity in entities do
								local delta = (entity.RootPart.Position - selfpos)
								local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end
								if lplr.Team == teams.Guards and entity.Player.Team == teams.Inmates and not entity.Character:GetAttribute('Hostile') then
									continue
								end

								targetinfo.Targets[entity] = os.clock() + 1
								table.insert(attacked, {
									Entity = entity,
									Check = BoxAttackColor
								})

								replicatedStorage.meleeEvent:FireServer(entity.Player, 1, 1)
							end
						end
					end

					for index, box in Boxes do
						box.Adornee = attacked[index] and attacked[index].Entity.RootPart or nil
						if box.Adornee then
							box.Color3 = Color3.fromHSV(attacked[index].Check.Hue, attacked[index].Check.Sat, attacked[index].Check.Value)
							box.Transparency = 1 - attacked[index].Check.Opacity
						end
					end

					for index, particle in Particles do
						particle.Position = attacked[index] and attacked[index].Entity.RootPart.Position or Vector3.new(math.huge, math.huge, math.huge)
						particle.Parent = attacked[index] and gameCamera or nil
					end

					if Face.Enabled and attacked[1] then
						local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.01, vec.Z))
					end

					task.wait(0.05)
				until not Killaura.Enabled
			else
				for _, box in Boxes do
					box.Adornee = nil
				end

				for _, particle in Particles do
					particle.Parent = nil
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 12,
		Default = 12,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
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
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.holder
					Boxes[i] = box
				end
			else
				for _, box in Boxes do
					box:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
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
				for _, particle in Particles do
					particle:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, particle in Particles do
				particle.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, particle in Particles do
				particle.ParticleEmitter.Color = ColorSequence.new({
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
			for _, particle in Particles do
				particle.ParticleEmitter.Color = ColorSequence.new({
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
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, particle in Particles do
				particle.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({
		Name = 'Face target'
	})
end)

run(function()
	local NoJumpCooldown
	local old

	local function EntityAdded(ent)
		old = getconnections(ent.Humanoid:GetPropertyChangedSignal('Jump'))[1]
		if not old then
			repeat
				old = getconnections(ent.Humanoid:GetPropertyChangedSignal('Jump'))[1]
				task.wait()
			until old or not NoJumpCooldown.Enabled

			if not NoJumpCooldown.Enabled then
				return
			end
		end

		if old then
			old:Disable()
		end
	end

	NoJumpCooldown = vape.Categories.Blatant:CreateModule({
		Name = 'NoJumpCooldown',
		Function = function(callback)
			if callback then
				NoJumpCooldown:Clean(entitylib.Events.LocalAdded:Connect(EntityAdded))
				if entitylib.isAlive then
					task.spawn(EntityAdded, entitylib.character)
				end
			else
				if old then
					old:Enable()
					old = nil
				end
			end
		end,
		Tooltip = 'Remove the stamina cooldown from jumping'
	})
end)

run(function()
	local VehicleFly
	local Mode
	local Speed
	local CameraMove
	local welds = {}
	local up, down = 0, 0

	local function getMoveVecFromCamera(cf, moveVec)
		local yaw = select(2, cf:ToEulerAnglesYXZ())
		return CFrame.fromEulerAnglesYXZ(0, yaw, 0):VectorToObjectSpace(moveVec)
	end

	VehicleFly = vape.Categories.Blatant:CreateModule({
		Name = 'VehicleFly',
		Function = function(callback)
			if callback then
				up, down = 0, 0
				for _, v in {'InputBegan', 'InputEnded'} do
					VehicleFly:Clean(inputService[v]:Connect(function(input)
						if not inputService:GetFocusedTextBox() then
							if input.KeyCode == Enum.KeyCode.E then
								up = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode.Q then
								down = v == 'InputBegan' and -1 or 0
							end
						end
					end))
				end

				if Mode.Value == 'Part' then
					local part = Instance.new('Part')
					part.Size = Vector3.new(50, 1, 50)
					part.Anchored = true
					part.CanQuery = false
					part.Transparency = 1

					VehicleFly:Clean(part)
					repeat
						local seat = entitylib.isAlive and entitylib.character.Humanoid.SeatPart
						if seat then
							part.CFrame = CFrame.new(seat.Position - Vector3.new(0, 2.2 - (up + down), 0))
							part.Parent = workspace
						else
							part.Parent = nil
						end

						task.wait(0.05)
					until not VehicleFly.Enabled
				else
					local inCar = false
					local old
					VehicleFly:Clean(runService.PreSimulation:Connect(function(dt)
						local seat = entitylib.isAlive and entitylib.character.Humanoid.SeatPart
						local root = seat and entitylib.character.RootPart

						if root then
							if seat ~= old then
								inCar = seat:IsDescendantOf(workspace.CarContainer) and seat:IsA('VehicleSeat')
								if inCar then
									table.clear(welds)
									for _, weld in seat.Parent.Parent.Wheels:QueryDescendants('Rotate') do
										welds[weld] = root.CFrame:ToObjectSpace(weld.Part0.CFrame)
									end
								end

								old = seat
							end

							if inCar then
								root.AssemblyLinearVelocity = Vector3.new(0, 2.25, 0)
								if CameraMove.Enabled then
									local moveVec = getMoveVecFromCamera(gameCamera.CFrame, entitylib.character.Humanoid.MoveDirection)
									root.CFrame = CFrame.lookAlong(root.Position, gameCamera.CFrame.LookVector) * CFrame.new(Vector3.new(moveVec.X, up + down, moveVec.Z) * Speed.Value * dt)
								else
									root.CFrame = CFrame.lookAlong(root.Position, gameCamera.CFrame.LookVector) + (entitylib.character.Humanoid.MoveDirection + Vector3.new(0, up + down, 0)) * Speed.Value * dt
								end

								for weld, offset in welds do
									weld.Part0.CFrame = root.CFrame * offset
								end

								gameCamera.CameraSubject = entitylib.character.Humanoid
							end
						end
					end))
				end
			else
				table.clear(welds)
			end
		end,
		Tooltip = 'Allow you to fly with a vehicle'
	})
	Mode = VehicleFly:CreateDropdown({
		Name = 'Mode',
		List = {'CFrame', 'Part'},
		Function = function(val)
			Speed.Object.Visible = val == 'CFrame'
			if VehicleFly.Enabled then
				VehicleFly:Toggle()
				VehicleFly:Toggle()
			end
		end
	})
	Speed = VehicleFly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 100,
		Default = 60,
		Darker = true
	})
	CameraMove = VehicleFly:CreateToggle({
		Name = 'Camera Move',
		Default = true,
		Tooltip = 'Move based on the camera look direction.'
	})
end)

run(function()
	local VehicleSpeed
	local Speed
	local old
	local seats = {}

	VehicleSpeed = vape.Categories.Blatant:CreateModule({
		Name = 'VehicleSpeed',
		Function = function(callback)
			if callback then
				repeat
					local seat = entitylib.isAlive and entitylib.character.Humanoid.SeatPart
					if seat then
						if seat ~= old then
							if seat:IsDescendantOf(workspace.CarContainer) then
								seats = seat.Parent.Parent:QueryDescendants('VehicleSeat')
							end

							old = seat
						end

						for _, seat in seats do
							seat.MaxSpeed = Speed.Value
							seat.Torque = 4
						end
					end

					task.wait()
				until not VehicleSpeed.Enabled
			else
				table.clear(seats)
			end
		end,
		Tooltip = 'Increase vehicle speed'
	})
	Speed = VehicleSpeed:CreateSlider({
		Name = 'Speed',
		Min = 80,
		Max = 200,
		Default = 140
	})
end)

run(function()
	VehicleWallbang = vape.Categories.Blatant:CreateModule({
	Name = 'VehicleWallbang',
	Function = function(callback)
		OriginScanner:UpdateIgnore()

		if callback then
			pl.ShootParams.FilterDescendantsInstances = {lplr.Character, workspace.CarContainer}

			VehicleWallbang:Clean(entitylib.Events.LocalAdded:Connect(function()
				task.defer(function()
					pl.ShootParams.FilterDescendantsInstances = {lplr.Character, workspace.CarContainer}
				end)
			end))
		else
			pl.ShootParams.FilterDescendantsInstances = {lplr.Character}
		end
	end,
	Tooltip = 'Allow you to shoot through vehicles.'
})
end)
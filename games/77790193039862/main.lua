-- tapev4 arena setup.
if not game:IsLoaded() then game.Loaded:Wait() end

local run = function(func)
	local ok, result = xpcall(func, debug and debug.traceback or tostring)
	if not ok then warn('[tapev4/Arena] Startup failed: ' .. tostring(result)) end
	return ok, result
end

local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local replicatedFirst = cloneref(game:GetService('ReplicatedFirst'))
local collectionService = cloneref(game:GetService('CollectionService'))
local runService = cloneref(game:GetService('RunService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local gameCamera = workspace.CurrentCamera or workspace:WaitForChild('Camera', 20)
assert(gameCamera, 'Arena camera did not become available')
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local arena = {}
local oldhit
local Spider = {Enabled = false}
local Phase = {Enabled = false}
local SpiderShift = false
local active = true
vape:Clean(function() active = false end)
local function child(parent, name)
	local object = parent:WaitForChild(name, 20)
	assert(object, 'Arena object unavailable: '..name)
	return object
end
local function readUpvalue(callback, index)
	local results = table.pack(pcall(debug.getupvalue, callback, index))
	if not results[1] then return nil end
	if results.n >= 3 then return results[3] end
	return results[2]
end
local function calculateMoveVector()
	local vec = arena.MoveController:GetMoveVector()		local c, s
	local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = gameCamera.CFrame:GetComponents()
	if R12 < 1 and R12 > -1 then
		c = R22
		s = R02
	else
		c = R00
		s = -R01 * math.sign(R12)
	end
	local length = math.sqrt(c * c + s * s)
	if length < 1e-6 then return Vector3.zero end
	vec = Vector3.new((c * vec.X + s * vec.Z), 0, (c * vec.Z - s * vec.X)) / length
	return vec.Unit == vec.Unit and vec.Unit or Vector3.zero
end
local function notif(...)
	return vape:CreateNotification(...)
end
local setupOK, setupError = run(function()
	assert(type(getsenv) == 'function' and type(getconnections) == 'function', 'Executor requires getsenv and getconnections')
	assert(debug and type(debug.getupvalue) == 'function' and type(debug.setupvalue) == 'function' and type(debug.getconstants) == 'function', 'Executor requires debug upvalue/constants APIs')
	local scripts = child(lplr, 'PlayerScripts')
	local charscript = child(scripts, 'CharacterController')
	local deadline = tick() + 20
	local ok, env = pcall(getsenv, charscript)
	if not ok then env = nil end
	if not (env and env.startHit) then
		repeat
			local success, value = pcall(getsenv, charscript)
			env = success and value or nil
			task.wait(0.1)
		until env and env.startHit or tick() >= deadline or not active
		assert(active and env and type(env.startHit) == 'function', 'CharacterController was not ready within 20 seconds')
	end
	arena = {
		Client = env,
		PlayerState = require(child(charscript, 'PlayerState')),
		Inventory = require(child(charscript, 'Inventory')),
		MoveController = require(child(scripts, 'PlayerModule')):GetControls(),
		SwingFunction = readUpvalue(env.startHit, 1)
	}
		-- Discover controller callbacks, retrying while the game initializes.
	local callbackDeadline = tick() + 20
	repeat
		arena.TickFunction = nil
		arena.MoveFunction = nil
		-- Find the movement/tick callback. The 0.05 constant may not be first.
		local heartbeatOK, heartbeatConnections = pcall(getconnections, runService.Heartbeat)
		if heartbeatOK and type(heartbeatConnections) == 'table' then
			for _, connection in ipairs(heartbeatConnections) do
				local callback = connection.Function
				if type(callback) == 'function' and (not islclosure or islclosure(callback)) then
					local constantsOK, constants = pcall(debug.getconstants, callback)
					if constantsOK and type(constants) == 'table' then
						local matches = false
						for _, constant in ipairs(constants) do
							if constant == 0.05 then
								matches = true
								break
							end
						end
						if matches then
							local candidate = readUpvalue(callback, 3)
							if type(candidate) == 'function' then
								arena.TickFunction = candidate
								break
							end
						end
					end
				end
			end
		end
		-- Find the movement callback from the character-loading event.
		local eventOK, eventConnections = pcall(function()
			return getconnections(
				child(child(replicatedStorage, 'Remotes'), 'LoadLocalCharacter').OnClientEvent
			)
		end)
		if eventOK and type(eventConnections) == 'table' then
			for _, connection in ipairs(eventConnections) do
				local callback = connection.Function
				if type(callback) == 'function' then
					local candidate = readUpvalue(callback, 9)
					if type(candidate) == 'function' then
						arena.MoveFunction = candidate
						break
					end
				end
			end
		end
		if type(arena.TickFunction) == 'function'
			and type(arena.MoveFunction) == 'function' then
			break
		end
		task.wait(0.25)
	until tick() >= callbackDeadline or not active
	assert(type(arena.SwingFunction) == 'function',
		'Arena setup failed: startHit callback unavailable')
	assert(type(arena.TickFunction) == 'function',
		'Arena setup failed: tick callback not found; controller layout may have changed')
	assert(type(arena.MoveFunction) == 'function',
		'Arena setup failed: movement callback not found; controller layout may have changed')
child(workspace, 'OtherCharacters')
end)
if not setupOK then error('[tapev4/Arena] '..tostring(setupError), 0) end
run(function()
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
	entitylib.getUpdateConnections = function(ent)
		return {
			(ent.Player and ent.Player:FindFirstChild('HealthValue')) and ent.Player.HealthValue:GetPropertyChangedSignal('Value') or ent.Humanoid:GetPropertyChangedSignal('Health')
		}
	end
	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		if plr == lplr then
			local hum = {GetState = function() end, Health = 100}
			local humrootpart = gameCamera and gameCamera.CameraSubject
			if humrootpart and humrootpart:IsA('Humanoid') then humrootpart = humrootpart.RootPart end
			entitylib.removeEntity(nil, true)
			if not (humrootpart and humrootpart:IsA('BasePart') and humrootpart.Parent) then return end
			local entity = {
				Connections = {},
				Character = humrootpart:FindFirstAncestorOfClass('Model') or humrootpart.Parent,
				Health = 100,
				Head = humrootpart,
				Humanoid = hum,
				HumanoidRootPart = humrootpart,
				HipHeight = 5,
				MaxHealth = 100,
				NPC = plr == nil,
				Player = plr,
				RootPart = humrootpart,
				TeamCheck = teamfunc
			}
			entitylib.character = entity
			entitylib.isAlive = true
			table.insert(entity.Connections, humrootpart.AncestryChanged:Connect(function()
				if not humrootpart:IsDescendantOf(workspace) then entitylib.removeEntity(nil, true) end
			end))
			entitylib.Events.LocalAdded:Fire(entity)
			return
		end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum = waitForChildOfType(char, 'Humanoid', 10)
			local humrootpart = char:WaitForChild('Torso', 10)
			local head = char:WaitForChild('Head', 10) or humrootpart
			local val = plr and plr:WaitForChild('HealthValue', 10)
			if active and entitylib.Running and char.Parent and hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = val and val.Value or hum.Health,
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					Hitbox = char:FindFirstChild('PlayerHitbox'),
					HipHeight = 3,
					MaxHealth = 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}
				entity.Targetable = entitylib.targetCheck(entity)
				for _, v in entitylib.getUpdateConnections(entity) do
					table.insert(entity.Connections, v:Connect(function()
						entity.Health = val and val.Value or hum.Health
						entitylib.Events.EntityUpdated:Fire(entity)
					end))
				end
				table.insert(entitylib.List, entity)
				entitylib.Events.EntityAdded:Fire(entity)
			end
			entitylib.EntityThreads[char] = nil
		end)
	end
	entitylib.addPlayer = function(plr) end
	local oldstart = entitylib.start
	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			local cameraConnection
			local function bindCamera()
				if cameraConnection then cameraConnection:Disconnect() end
				gameCamera = workspace.CurrentCamera
				if gameCamera then
					cameraConnection = gameCamera:GetPropertyChangedSignal('CameraSubject'):Connect(function()
						entitylib.addEntity(true, lplr)
					end)
					table.insert(entitylib.Connections, cameraConnection)
				end
				entitylib.addEntity(true, lplr)
			end
			table.insert(entitylib.Connections, workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(bindCamera))
			bindCamera()
			table.insert(entitylib.Connections, workspace.OtherCharacters.ChildAdded:Connect(function(ent)
				local plr = playersService:FindFirstChild(ent.Name:sub(1, #ent.Name - 14))
				if plr then
					entitylib.refreshEntity(ent, plr)
				end
			end))
			table.insert(entitylib.Connections, workspace.OtherCharacters.ChildRemoved:Connect(function(ent)
				entitylib.removeEntity(ent)
			end))
			for _, ent in workspace.OtherCharacters:GetChildren() do
				local plr = playersService:FindFirstChild(ent.Name:sub(1, #ent.Name - 14))
				if plr then
					entitylib.refreshEntity(ent, plr)
				end
			end
		end
	end
	entitylib.start()
end)
for _, v in {'AutoClicker', 'Killaura', 'Fly', 'Speed', 'Spider', 'Sprint', 'Velocity', 'HighJump', 'LongJump', 'HitBoxes', 'NoSlow', 'FastBreak', 'FastPlace', 'AutoBlock', 'AimAssist', 'Reach', 'SilentAim', 'AntiFall', 'Desync', 'Invisible', 'Jesus', 'MouseTP', 'Phase', 'SpinBot', 'Swim', 'TargetStrafe', 'AnimationPlayer', 'AntiRagdoll', 'ChatSpammer', 'Disabler', 'HumSpoofer', 'Freecam', 'Gravity', 'Parkour', 'SafeWalk', 'MurderMystery'} do
	vape:Remove(v)
end
-- Separate scopes keep feature locals below Luau's limit while sharing arena state.
run(function()
local AutoBlock
AutoBlock = vape.Categories.Blatant:CreateModule({
	Name = 'AutoBlock',
	Function = function(callback)
		if callback then
			oldhit = hookfunction(arena.Client.startHit, function(...)
				if debug.getupvalue(oldhit, 6) then
					arena.Client.endBlockEvent:FireServer()
					debug.setupvalue(oldhit, 6, false)
					local results = table.pack(oldhit(...))
					arena.Client.beginBlockEvent:FireServer()
					debug.setupvalue(oldhit, 6, true)
					return unpack(results, 1, results.n)
				else
					return oldhit(...)
				end
			end)
		else
			if oldhit then
				hookfunction(arena.Client.startHit, oldhit)
				oldhit = nil
			end
		end
	end,
	Tooltip = 'Automatically unblock and reblock before hitting'
})
end)
run(function()
local Fly
local LongJump
run(function()
	local Keys
	local Value
	local VerticalValue
	local up = 0
	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			if callback then
				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						local movedir = calculateMoveVector() * Value.Value
						local keys = Keys.Value:split('/')
						local focused = inputService:GetFocusedTextBox() ~= nil
						local keyboardUp = not focused and inputService:IsKeyDown(Enum.KeyCode[keys[1]]) and 1 or 0
						local keyboardDown = not focused and inputService:IsKeyDown(Enum.KeyCode[keys[2]]) and -1 or 0
						debug.setupvalue(arena.TickFunction, 6, Vector3.new(movedir.X, 1 + ((math.max(up, keyboardUp) + keyboardDown) * VerticalValue.Value), movedir.Z))
					end
				end))
				up = 0
				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
							up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
						end))
					end)
				end
			end
		end,
		Tooltip = 'Makes you go zoom.'
	})
	Keys = Fly:CreateDropdown({
		Name = 'Keys',
		List = {'Space/LeftControl', 'Space/LeftShift', 'E/Q', 'Space/Q'},
		Default = 'Space/LeftControl',
		Tooltip = 'Keys for flying upwards and downwards'
	})
	Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	VerticalValue = Fly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
end)
run(function()
local HighJump
local Value
local AutoDisable
local function jump()
	local onground = debug.getupvalue(arena.MoveFunction, 4)
	if onground then
		local velocity = debug.getupvalue(arena.TickFunction, 6)
		debug.setupvalue(arena.TickFunction, 6, Vector3.new(velocity.X, Value.Value, velocity.Z))
	end
end
HighJump = vape.Categories.Blatant:CreateModule({
	Name = 'HighJump',
	Function = function(callback)
		if callback then
			if AutoDisable.Enabled then
				jump()
				HighJump:Toggle()
			else
				HighJump:Clean(runService.RenderStepped:Connect(function()
					if not inputService:GetFocusedTextBox() and inputService:IsKeyDown(Enum.KeyCode.Space) then
						jump()
					end
				end))
			end
		end
	end,
	Tooltip = 'Lets you jump higher'
})
Value = HighJump:CreateSlider({
	Name = 'Velocity',
	Min = 1,
	Max = 150,
	Default = 50,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
AutoDisable = HighJump:CreateToggle({
	Name = 'Auto Disable',
	Default = true
})
end)
run(function()
local HitBoxes
local Targets
local TargetPart
local Expand
local modified = {}
HitBoxes = vape.Categories.Blatant:CreateModule({
	Name = 'HitBoxes',
	Function = function(callback)
		if callback then
			repeat
				for _, v in entitylib.List do
					if v.Targetable then
						if not Targets.Players.Enabled and v.Player then continue end
						if not Targets.NPCs.Enabled and v.NPC then continue end
						local part = v.Hitbox
						if not modified[part] then
							modified[part] = part.Size
						end
						part.Size = modified[part] + Vector3.new(Expand.Value, Expand.Value, Expand.Value)
					end
				end
				task.wait()
			until not HitBoxes.Enabled
		else
			for i, v in modified do
				i.Size = v
			end
			table.clear(modified)
		end
	end,
	Tooltip = 'Expands entities hitboxes'
})
Targets = HitBoxes:CreateTargets({Players = true})
Expand = HitBoxes:CreateSlider({
	Name = 'Expand amount',
	Min = 0,
	Max = 6,
	Decimal = 10,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
end)
run(function()
local Killaura
local Targets
local AttackRange
local AngleSlider
local Max
local Mouse
local BoxAttackColor
local ParticleTexture
local ParticleColor1
local ParticleColor2
local ParticleSize
local Face
local Sort
local GUICheck
local generation = 0
local restoreCamera
local guiService = cloneref(game:GetService('GuiService'))
local Particles, Boxes, AttackDelay = {}, {}, tick()
local function getAttackData()
	if not (entitylib.isAlive and entitylib.character and entitylib.character.RootPart and entitylib.character.RootPart.Parent and gameCamera) then return false end
	if inputService:GetFocusedTextBox() then return false end
	if Mouse.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return false end
	local scaled = vape.gui and vape.gui:FindFirstChild('ScaledGui')
	local menu = scaled and scaled:FindFirstChild('ClickGui')
	if GUICheck.Enabled and (guiService.MenuIsOpen or menu and menu.Visible) then return false end
	return true
end
local function selectTargets(origin, facing)
	local entries = {}
	local flat = Vector3.new(facing.X, 0, facing.Z)
	for _, ent in entitylib.List do
		local root = ent.RootPart
		if not (root and root.Parent and ent.Character and ent.Character.Parent and ent.Targetable) then continue end
		if ent.Player == lplr or ent.Friend or (ent.Health and ent.Health <= 0) then continue end
		if ent.Player and not Targets.Players.Enabled or ent.NPC and not Targets.NPCs.Enabled then continue end
		if not entitylib.targetCheck(ent) or not entitylib.isVulnerable(ent) then continue end
		local delta = root.Position - origin
		local distance = delta.Magnitude
		if distance <= 0.001 or distance > AttackRange.Value then continue end
		local horizontal = Vector3.new(delta.X, 0, delta.Z)
		local angle = 0
		if flat.Magnitude > 0.001 and horizontal.Magnitude > 0.001 then angle = math.acos(math.clamp(flat.Unit:Dot(horizontal.Unit), -1, 1)) end
		if angle > math.rad(AngleSlider.Value) / 2 then continue end
		if Targets.Walls.Enabled and entitylib.Wallcheck(origin, root.Position) then continue end
		local score = distance
		if Sort.Value == 'Angle' then score = angle
		elseif Sort.Value == 'Lowest Health' then score = ent.Health or 100
		elseif Sort.Value == 'Highest Health' then score = -(ent.Health or 100) end
		table.insert(entries, {Entity = ent, Angle = angle, Distance = distance, Score = score})
	end
	table.sort(entries, function(a, b)
		local aTarget, bTarget = a.Entity.Target == true, b.Entity.Target == true
		if aTarget ~= bTarget then return aTarget end
		if a.Score == b.Score then return a.Distance < b.Distance end
		return a.Score < b.Score
	end)
	while #entries > Max.Value do table.remove(entries) end
	return entries
end
Killaura = vape.Categories.Blatant:CreateModule({
	Name = 'Killaura',
	Function = function(callback)
		generation += 1
		local currentGeneration = generation
		if restoreCamera then restoreCamera(); restoreCamera = nil end
		if callback then
			local customvec
			local originalCamera = readUpvalue(arena.TickFunction, 13)
			if originalCamera == nil then
				notif('Killaura', 'Camera hook unavailable; cannot enable safely.', 8, 'warning')
				task.defer(function() if Killaura.Enabled and generation == currentGeneration then Killaura:Toggle() end end)
				return
			end
			local proxy = setmetatable({}, {})
			local blockfunc = oldhit or arena.Client.startHit
			getmetatable(proxy).__index = function(self, key)
				if key == 'CFrame' then
					return customvec or gameCamera.CFrame
				end
				return gameCamera[key]
			end
			local restored = false
			local function cleanup()
				if restored then return end
				restored = true
				if readUpvalue(arena.TickFunction, 13) == proxy then
					local ok, err = pcall(debug.setupvalue, arena.TickFunction, 13, originalCamera)
					if not ok then warn('[tapev4/Killaura] Restore failed: '..tostring(err)) end
				end
				if generation == currentGeneration then
					for _, box in Boxes do box.Adornee = nil end
					for _, part in Particles do part.Parent = nil end
				end
			end
			restoreCamera = cleanup
			Killaura:Clean(cleanup)
			local succeeded, err = xpcall(function()
			debug.setupvalue(arena.TickFunction, 13, proxy)
			assert(readUpvalue(arena.TickFunction, 13) == proxy, 'Camera hook installation failed')
			repeat
				customvec = nil
				local interest = getAttackData()
				local attacked = {}
				if interest then
					local plrs = selectTargets(entitylib.character.RootPart.Position, gameCamera.CFrame.LookVector)
					if #plrs > 0 then
						blockfunc = oldhit or arena.Client.startHit
						local selfpos = entitylib.character.RootPart.Position
						local reblock = false
						local hitsOK, hitsError = xpcall(function()
						for _, entry in plrs do
							local v, angle = entry.Entity, entry.Angle
							if not (v.RootPart.Parent and v.Character.Parent) then continue end
							table.insert(attacked, {
								Entity = v,
								Check = BoxAttackColor
							})
							if targetinfo and targetinfo.Targets then targetinfo.Targets[v] = tick() + 1 end
							if readUpvalue(blockfunc, 6) == true then
								arena.Client.endBlockEvent:FireServer()
								reblock = true
								debug.setupvalue(blockfunc, 6, false)
							end
							if AttackDelay < tick() then
								arena.SwingFunction()
								AttackDelay = tick() + 0.11
							end
							local vec = CFrame.lookAt(selfpos, v.RootPart.Position)
							if angle > math.rad(65) then
								customvec = vec
							end
							replicatedStorage.Remotes.HitRequest:FireServer(selfpos, vec.LookVector, v.Character, v.Player)
						end
						end, debug and debug.traceback or tostring)
						if reblock then
							local sent, sendError = pcall(function() arena.Client.beginBlockEvent:FireServer() end)
							local reset, resetError = pcall(debug.setupvalue, blockfunc, 6, true)
							if not sent or not reset then error('Block restoration failed: '..tostring(sendError or resetError)) end
						end
						if not hitsOK then error(hitsError, 0) end
					end
				end
				for i, v in Boxes do
					v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
					if v.Adornee then
						v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
						v.Transparency = 1 - attacked[i].Check.Opacity
					end
				end
				for i, v in Particles do
					v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
					v.Parent = attacked[i] and gameCamera or nil
				end
				if Face.Enabled and attacked[1] then
					local root = entitylib.character.RootPart
					local delta = (attacked[1].Entity.RootPart.Position - root.Position) * Vector3.new(1, 0, 1)
					if delta.Magnitude > 0.001 then root.CFrame = CFrame.lookAt(root.Position, root.Position + delta) end
				end
				task.wait(#attacked > 0 and #attacked * 0.07 or 0.016)
			until not Killaura.Enabled or generation ~= currentGeneration
			end, debug and debug.traceback or tostring)
			cleanup()
			if not succeeded then
				warn('[tapev4/Killaura] '..tostring(err))
				notif('Killaura', 'Stopped after a runtime error; check the tapev4 warning.', 8, 'warning')
				if Killaura.Enabled and generation == currentGeneration then Killaura:Toggle() end
			end
		else
			for _, v in Boxes do
				v.Adornee = nil
			end
			for _, v in Particles do
				v.Parent = nil
			end
		end
	end,
	Tooltip = 'Attack players around you\nwithout aiming at them.'
})
Targets = Killaura:CreateTargets({Players = true})
AttackRange = Killaura:CreateSlider({
	Name = 'Attack range',
	Min = 1,
	Max = 16,
	Default = 16,
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
Sort = Killaura:CreateDropdown({Name = 'Target Mode', List = {'Distance', 'Angle', 'Lowest Health', 'Highest Health'}, Default = 'Distance', Tooltip = 'Sorts eligible targets before Max targets is applied. Marked targets have priority.'})
GUICheck = Killaura:CreateToggle({Name = 'GUI check', Default = true, Tooltip = 'Pauses while the tapev4 or Roblox menu is open. Typing always pauses attacks.'})
Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
Killaura:CreateToggle({
	Name = 'Show target',
	Function = function(callback)
		if BoxAttackColor then BoxAttackColor.Object.Visible = callback end
		if callback then
			for i = 1, 10 do
				local box = Instance.new('BoxHandleAdornment')
				box.Adornee = nil
				box.AlwaysOnTop = true
				box.Size = Vector3.new(3, 7, 3)
				box.CFrame = CFrame.new(0, -0.5, 0)
				box.ZIndex = 0
				box.Parent = vape.gui
				Boxes[i] = box
			end
		else
			for _, v in Boxes do
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
	Function = function(callback)		   ParticleTexture.Object.Visible = callback
		ParticleColor1.Object.Visible = callback
		ParticleColor2.Object.Visible = callback
		ParticleSize.Object.Visible = callback
		if callback then
			for i = 1, 10 do
				local part = Instance.new('Part')
				part.Size = Vector3.new(2, 4, 2)
				part.Anchored = true
				part.CanCollide = false
				part.CanTouch = false
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
			if ParticleTexture then v.ParticleEmitter.Texture = ParticleTexture.Value end
		end
	end,
	Darker = true,
	Visible = false
})
ParticleColor1 = Killaura:CreateColorSlider({
	Name = 'Color Begin',
	Function = function(hue, sat, val)
		if not ParticleColor2 then return end
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
		if not ParticleColor1 then return end
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
	Default = 0.2,
	Decimal = 100,
	Function = function(val)
		for _, v in Particles do
			v.ParticleEmitter.Size = NumberSequence.new(val)
		end
	end,
	Darker = true,
	Visible = false
})
Face = Killaura:CreateToggle({Name = 'Face target', Tooltip = 'Turns horizontally toward the first selected target.'})
vape:Clean(function()
	generation += 1
	if restoreCamera then restoreCamera(); restoreCamera = nil end
	for _, box in Boxes do box:Destroy() end
	for _, part in Particles do part:Destroy() end
	table.clear(Boxes)
	table.clear(Particles)
end)
end)

run(function()
local Value
local AutoDisable
LongJump = vape.Categories.Blatant:CreateModule({
	Name = 'LongJump',
	Function = function(callback)
		if callback then
			local exempt = tick() + 0.1
			LongJump:Clean(runService.PreSimulation:Connect(function(dt)
				if entitylib.isAlive then
					local movedir = calculateMoveVector() * Value.Value
					local onground = debug.getupvalue(arena.MoveFunction, 4)
					if onground then
						if exempt < tick() and AutoDisable.Enabled then
							if LongJump.Enabled then
								LongJump:Toggle()
							end
						else
							debug.setupvalue(arena.TickFunction, 6, Vector3.new(movedir.X, 30, movedir.Z))
						end
					end
					local velocity = debug.getupvalue(arena.TickFunction, 6)
					debug.setupvalue(arena.TickFunction, 6, Vector3.new(movedir.X, velocity.Y, movedir.Z))
				end
			end))
		end
	end,
	Tooltip = 'Lets you jump farther'
})
Value = LongJump:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 150,
	Default = 50,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
AutoDisable = LongJump:CreateToggle({
	Name = 'Auto Disable',
	Default = true
})
end)

run(function()
local NoSlowdown
local old
NoSlowdown = vape.Categories.Blatant:CreateModule({
	Name = 'NoSlowdown',
	Function = function(callback)
		if callback then
			old = debug.getupvalue(arena.MoveFunction, 17)
			debug.setupvalue(arena.MoveFunction, 17, debug.getupvalue(arena.MoveFunction, 19))
		else
			if old then
				debug.setupvalue(arena.MoveFunction, 17, old)
				old = nil
			end
		end
	end,
	Tooltip = 'Prevent you from slowing down when using items.'
})
end)

run(function()
local Speed
local Value
local AutoJump
Speed = vape.Categories.Blatant:CreateModule({
	Name = 'Speed',
	Function = function(callback)
		if callback then
			Speed:Clean(runService.PreSimulation:Connect(function()
				if not Fly.Enabled and not LongJump.Enabled then
					local movedir = calculateMoveVector() * Value.Value
					local onground = debug.getupvalue(arena.MoveFunction, 4)
					local velocity = debug.getupvalue(arena.TickFunction, 6)
					debug.setupvalue(arena.TickFunction, 6, Vector3.new(movedir.X, AutoJump.Enabled and onground and movedir.Magnitude > 0 and 20 or velocity.Y, movedir.Z))
				end
			end))
		end
	end,
	Tooltip = 'Increases your movement with various methods.'
})
Value = Speed:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 90,
	Default = 30,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
AutoJump = Speed:CreateToggle({
	Name = 'AutoJump'
})
end)

run(function()
local Value
local rayCheck = RaycastParams.new()
rayCheck.RespectCanCollide = true
local Active
Spider = vape.Categories.Blatant:CreateModule({
	Name = 'Spider',
	Function = function(callback)
		if callback then
			Spider:Clean(runService.PreSimulation:Connect(function(dt)
				if entitylib.isAlive then
					local root = entitylib.character.RootPart
					local chars = {gameCamera, lplr.Character}
					for _, v in entitylib.List do
						table.insert(chars, v.Character)
					end
					SpiderShift = inputService:IsKeyDown(Enum.KeyCode.LeftShift)
					rayCheck.FilterDescendantsInstances = chars
					rayCheck.CollisionGroup = 'Hitbox'
					local vec = calculateMoveVector() * 2.5
					local ray = workspace:Raycast(root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0), vec, rayCheck)
					if Active and not ray then
						root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
					end
					Active = ray
					if Active and ray.Normal.Y == 0 then
						if not Phase.Enabled or not SpiderShift then
							local velocity = debug.getupvalue(arena.TickFunction, 6)
							debug.setupvalue(arena.TickFunction, 6, Vector3.new(velocity.X, Value.Value, velocity.Z))
						end
					end
				end
			end))
		else
			SpiderShift = false
		end
	end,
	Tooltip = 'Lets you climb up walls. (Hold shift to use Phase over spider)'
})
Value = Spider:CreateSlider({
	Name = 'Speed',
	Min = 0,
	Max = 100,
	Default = 30,
	Darker = true,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
end)

run(function()
local AutoClicker
local CPS
local Thread
local function AutoClick()
	if Thread then
		task.cancel(Thread)
	end
	Thread = task.delay(1 / CPS.GetRandomValue(), function()
		repeat
			task.spawn(arena.Client.startHit)
			task.wait(1 / CPS.GetRandomValue())
		until not AutoClicker.Enabled
	end)
end
AutoClicker = vape.Categories.Combat:CreateModule({
	Name = 'AutoClicker',
	Function = function(callback)
		if callback then
			AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					AutoClick()
				end
			end))
			AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 and Thread then
					task.cancel(Thread)
					Thread = nil
				end
			end))
		else
			if Thread then
				task.cancel(Thread)
				Thread = nil
			end
		end
	end,
	Tooltip = 'Hold attack button to automatically click'
})
CPS = AutoClicker:CreateTwoSlider({
	Name = 'CPS',
	Min = 1,
	Max = 9,
	DefaultMin = 7,
	DefaultMax = 7
})
end)

run(function()
local Reach
local Value
local old
Reach = vape.Categories.Combat:CreateModule({
	Name = 'Reach',
	Function = function(callback)
		if callback then
			old = debug.getupvalue(oldhit or arena.Client.startHit, 4)
			debug.setupvalue(oldhit or arena.Client.startHit, 4, old + Value.Value)
		else
			if old then
				debug.setupvalue(oldhit or arena.Client.startHit, 4, old)
				old = nil
			end
		end
	end,
	Tooltip = 'Extends attack reach'
})

Value = Reach:CreateSlider({
	Name = 'Range',
	Min = 0,
	Max = 6,
	Default = 6,
	Decimal = 10,
	Function = function(val)
		if Reach.Enabled then
			debug.setupvalue(oldhit or arena.Client.startHit, 4, old + val)
		end
	end,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
end)

run(function()
local Sprint
Sprint = vape.Categories.Combat:CreateModule({
	Name = 'Sprint',
	Function = function(callback)
		if callback then
			repeat
				arena.PlayerState.Preferences.AutoSprint = true
				task.wait(0.016)
			until not Sprint.Enabled
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
local function velocityFunction(...)
	if rand:NextNumber(0, 100) > Chance.Value then return old(...) end
	local data = ...
	local check = (not Targeting.Enabled) or entitylib.EntityPosition({
		Range = 50,
		Part = 'RootPart',
		Players = true
	})
	if check and not data.position then
		local hort, vert = (Horizontal.Value / 100), (Vertical.Value / 100)
		if hort == 0 and vert == 0 then return end
		data.vel = Vector3.new(data.vel.X * hort, data.vel.Y * vert, data.vel.Z * hort)
	end
	return old(...)
end
Velocity = vape.Categories.Combat:CreateModule({
	Name = 'Velocity',
	Function = function(callback)
		if callback then
			connection = getconnections(replicatedStorage.Remotes.ClientStateUpdate.OnClientEvent)[1]
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
local FastBreak
local Value
local old
FastBreak = vape.Categories.World:CreateModule({
	Name = 'FastBreak',
	Function = function(callback)
		if callback then
			old = hookfunction(arena.Client.showMiningProgress, function(progress)
				progress *= Value.Value
				debug.setstack(3, 5, debug.getstack(3, 5) * Value.Value)
				return old(progress)
			end)
		else
			if old then
				hookfunction(arena.Client.showMiningProgress, old)
				old = nil
			end
		end
	end,
	Tooltip = 'Break blocks faster when mining.'
})
Value = FastBreak:CreateSlider({
	Name = 'Multiplier',
	Min = 0,
	Max = 3,
	Default = 3,
	Decimal = 10
})
end)

run(function()
local FastPlace
local Value
local old
FastPlace = vape.Categories.World:CreateModule({
	Name = 'FastPlace',
	Function = function(callback)
		if callback then
			old = debug.getupvalue(arena.Client.startPlaceHold, 7)
			debug.setupvalue(arena.Client.startPlaceHold, 7, math.max(Value.Value, 0.001))
		else
			if old then
				debug.setupvalue(arena.Client.startPlaceHold, 7, old)
				old = nil
			end
		end
	end,
	Tooltip = 'Place blocks faster while holding right click.'
})

Value = FastPlace:CreateSlider({
	Name = 'Delay',
	Min = 0,
	Max = 0.2,
	Default = 0,
	Decimal = 100,
	Function = function(val)
		if FastPlace.Enabled then
			debug.setupvalue(arena.Client.startPlaceHold, 7, math.max(val, 0.001))
		end
	end,
	Suffix = function(val)
		return 'seconds'
	end
})
end)

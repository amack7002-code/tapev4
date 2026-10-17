-- tapev4 arena setup (FIXED)
if not game:IsLoaded() then game.Loaded:Wait() end

local run = function(func)
	local ok, result = xpcall(func, debug and debug.traceback or tostring)
	if not ok then
		warn('[tapev4/Arena] Startup failed: ' .. tostring(result))
	end
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
local guiService = cloneref(game:GetService('GuiService'))

local gameCamera = workspace.CurrentCamera or workspace:WaitForChild('Camera', 20)
assert(gameCamera, 'Arena camera did not become available')

local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local arena = {}
local oldhit
local Fly
local LongJump
local Spider = {Enabled = false}
local Phase = {Enabled = false}
local SpiderShift = false
local active = true

vape:Clean(function()
	active = false
end)

local function child(parent, name)
	local object = parent:WaitForChild(name, 20)
	assert(object, 'Arena object unavailable: '..name)
	return object
end

-- Fixed readUpvalue
local function readUpvalue(callback, index)
	if type(callback) ~= 'function' then return nil end
	local ok, first, second = pcall(debug.getupvalue, callback, index)
	if not ok then return nil end
	-- Standard Lua returns (name, value); Luau executors commonly return only value.
	if second ~= nil then return second end
	if type(first) == 'string' then return nil end
	return first
end

local function calculateMoveVector()
	local vec = arena.MoveController:GetMoveVector()
	local c, s
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

	local deadline = tick() + 25
	local env

	-- Wait until startHit exists
	repeat
		local success, value = pcall(getsenv, charscript)
		env = success and value or nil
		task.wait(0.1)
	until (env and type(env.startHit) == 'function') or tick() >= deadline or not active

	assert(active and env and type(env.startHit) == 'function', 'CharacterController was not ready within 25 seconds')

	-- Better SwingFunction detection (tries multiple upvalues)
	local swingFunc
	for i = 1, 15 do
		local uv = readUpvalue(env.startHit, i)
		if type(uv) == 'function' then
			swingFunc = uv
			break
		end
	end
	if not swingFunc then
		swingFunc = env.startHit -- fallback
	end

	arena = {
		Client = env,
		PlayerState = require(child(charscript, 'PlayerState')),
		Inventory = require(child(charscript, 'Inventory')),
		MoveController = require(child(scripts, 'PlayerModule')):GetControls(),
		Fly = {Enabled = false},
		LongJump = {Enabled = false},
		SwingFunction = swingFunc
	}

	pcall(function()
		local flyModule = scripts:FindFirstChild('Fly')
		if flyModule then
			arena.Fly = require(flyModule)
			arena.Fly.Enabled = true
			arena.Fly.PhaseLocked = false
		end
		local longJumpModule = scripts:FindFirstChild('LongJump')
		if longJumpModule then
			arena.LongJump = require(longJumpModule)
			arena.LongJump.Enabled = true
			arena.LongJump.AutoActivate = false
		end
	end)

	-- Discover TickFunction + MoveFunction (more aggressive + non-fatal)
	local callbackDeadline = tick() + 20
	repeat
		arena.TickFunction = nil
		arena.MoveFunction = nil

		-- ===== TickFunction search =====
		local heartbeatOK, heartbeatConnections = pcall(getconnections, runService.Heartbeat)
		if heartbeatOK and type(heartbeatConnections) == 'table' then
			for _, connection in ipairs(heartbeatConnections) do
				local callback = connection.Function
				if type(callback) == 'function' and (not islclosure or islclosure(callback)) then
					-- Try many upvalue indexes
					for idx = 1, 12 do
						local candidate = readUpvalue(callback, idx)
						if type(candidate) == 'function' then
							arena.TickFunction = candidate
							break
						end
					end
				end
				if arena.TickFunction then break end
			end
		end

		-- ===== MoveFunction search =====
		local eventOK, eventConnections = pcall(function()
			return getconnections(child(child(replicatedStorage, 'Remotes'), 'LoadLocalCharacter').OnClientEvent)
		end)
		if eventOK and type(eventConnections) == 'table' then
			for _, connection in ipairs(eventConnections) do
				local callback = connection.Function
				if type(callback) == 'function' then
					for idx = 1, 15 do
						local candidate = readUpvalue(callback, idx)
						if type(candidate) == 'function' then
							arena.MoveFunction = candidate
							break
						end
					end
				end
				if arena.MoveFunction then break end
			end
		end

		if type(arena.TickFunction) == 'function' and type(arena.MoveFunction) == 'function' then
			break
		end
		task.wait(0.3)
	until tick() >= callbackDeadline or not active

	-- Make them non-fatal
	if type(arena.SwingFunction) ~= 'function' then
		error('Arena setup failed: startHit callback unavailable', 0)
	end

	if type(arena.TickFunction) ~= 'function' then
		warn('[tapev4/Arena] TickFunction not found — Fly / Speed / HighJump / LongJump / Spider will not work')
		arena.TickFunction = function() end -- dummy so the rest of the script doesn't crash
	end

	if type(arena.MoveFunction) ~= 'function' then
		warn('[tapev4/Arena] MoveFunction not found — some movement features will not work')
		arena.MoveFunction = function() end
	end

	child(workspace, 'OtherCharacters')
end)

if not setupOK then
	error('[tapev4/Arena] '..tostring(setupError), 0)
end

-- ==================== ENTITYLIB PATCH ====================
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
				if cameraConnection then
					cameraConnection:Disconnect()
				end
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

			local otherChars = workspace:FindFirstChild("OtherCharacters")
			if otherChars then
				table.insert(entitylib.Connections, otherChars.ChildAdded:Connect(function(ent)
					local plr = playersService:FindFirstChild(ent.Name:sub(1, #ent.Name - 14))
					if plr then
						if entitylib.refreshEntity then
							entitylib.refreshEntity(ent, plr)
						else
							entitylib.addEntity(ent, plr)
						end
					end
				end))

				table.insert(entitylib.Connections, otherChars.ChildRemoved:Connect(function(ent)
					entitylib.removeEntity(ent)
				end))

				for _, ent in otherChars:GetChildren() do
					local plr = playersService:FindFirstChild(ent.Name:sub(1, #ent.Name - 14))
					if plr then
						if entitylib.refreshEntity then
							entitylib.refreshEntity(ent, plr)
						else
							entitylib.addEntity(ent, plr)
						end
					end
				end
			end
		end
	end
	entitylib.start()
end)

-- Remove default modules
for _, v in {'AutoClicker', 'Killaura', 'Fly', 'Speed', 'Spider', 'Sprint', 'Velocity', 'HighJump', 'LongJump', 'HitBoxes', 'NoSlow', 'FastBreak', 'FastPlace', 'AutoBlock', 'AimAssist', 'Reach', 'SilentAim', 'AntiFall', 'Desync', 'Invisible', 'Jesus', 'MouseTP', 'Phase', 'SpinBot', 'Swim', 'TargetStrafe', 'AnimationPlayer', 'AntiRagdoll', 'ChatSpammer', 'Disabler', 'HumSpoofer', 'Freecam', 'Gravity', 'Parkour', 'SafeWalk', 'MurderMystery'} do
	vape:Remove(v)
end

-- Separate scopes keep feature locals below Luau's limit while sharing arena state.
run(function()
--[[AEROV4_GAME_MODULE_001]]
end)
run(function()
--[[AEROV4_GAME_MODULE_002]]
end)
run(function()
--[[AEROV4_GAME_MODULE_003]]
end)
run(function()
--[[AEROV4_GAME_MODULE_004]]
end)
run(function()
--[[AEROV4_GAME_MODULE_005]]
end)
run(function()
--[[AEROV4_GAME_MODULE_006]]
end)
run(function()
--[[AEROV4_GAME_MODULE_007]]
end)
run(function()
--[[AEROV4_GAME_MODULE_008]]
end)
run(function()
--[[AEROV4_GAME_MODULE_009]]
end)
run(function()
--[[AEROV4_GAME_MODULE_010]]
end)
run(function()
--[[AEROV4_GAME_MODULE_011]]
end)
run(function()
--[[AEROV4_GAME_MODULE_012]]
end)
run(function()
--[[AEROV4_GAME_MODULE_013]]
end)
run(function()
--[[AEROV4_GAME_MODULE_014]]
end)
run(function()
--[[AEROV4_GAME_MODULE_015]]
end)
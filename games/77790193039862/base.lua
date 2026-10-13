-- tapev4 arena setup.
if not game:IsLoaded() then game.Loaded:Wait() end
local run = function(func)
	local ok, result = xpcall(func, debug and debug.traceback or tostring)
	if not ok then warn('[tapev4/Arena] Startup failed: '..tostring(result)) end
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
	local deadline = tick() + 20
	local ok, env = pcall(getsenv, charscript)
	if not ok then env = nil end
	local fallback
	repeat
		if env and env.startHit then
			fallback = readUpvalue(env.startHit, 1) or env.startHit
			if fallback ~= env.startHit then
				env.startHit = fallback
			end
		end
		task.wait(0.1)
	until env and fallback ~= env.startHit or tick() >= deadline or not active
	assert(active and env and env.startHit and type(env.startHit) == 'function', 'CharacterController did not expose the startHit callback within 20 seconds')

	arena = {
		Client = env,
		PlayerState = require(child(charscript, 'PlayerState')),
		Inventory = require(child(charscript, 'Inventory')),
		MoveController = require(child(scripts, 'PlayerModule')):GetControls(),
		SwingFunction = readUpvalue(env.startHit, 1)
	}

	local flySetupOK, flySetupError = run(function()
		local scripts = child(lplr, 'PlayerScripts')
		local flyModule = child(scripts, 'Fly')
		arena.Fly = require(flyModule)
		arena.Fly.Enabled = true
		arena.Fly.PhaseLocked = false
	end)
	local longJumpSetupOK, longJumpSetupError = run(function()
		local scripts = child(lplr, 'PlayerScripts')
		local longJumpModule = child(scripts, 'LongJump')
		arena.LongJump = require(longJumpModule)
		arena.LongJump.Enabled = true
		arena.LongJump.AutoActivate = false
	end)
	assert(flySetupOK and longJumpSetupOK, 'Arena controller setup failed: Fly='..tostring(flySetupOK)..' LongJump='..tostring(longJumpSetupOK))

	for _, v in getconnections(runService.Heartbeat) do
		if type(v.Function) == 'function' and (not islclosure or islclosure(v.Function)) then
			local success, constants = pcall(debug.getconstants, v.Function)
			if success and type(constants) == 'table' and constants[1] == 0.05 then
				local value = readUpvalue(v.Function, 3)
				if type(value) == 'function' then arena.TickFunction = value end
			end
		end
	end

	for _, v in getconnections(child(child(replicatedStorage, 'Remotes'), 'LoadLocalCharacter').OnClientEvent) do
		if v.Function then
			local value = readUpvalue(v.Function, 9)
			if type(value) == 'function' then arena.MoveFunction = value end
		end
	end

	assert(type(arena.SwingFunction) == 'function' and arena.TickFunction and arena.MoveFunction, 'Arena controller callbacks unavailable; wait for the game to load or check executor support')
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


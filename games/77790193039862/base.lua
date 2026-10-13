-- tapev4 arena setup
if not game:IsLoaded() then game.Loaded:Wait() end

local run = function(func)
	local ok, result = xpcall(func, debug and debug.traceback or tostring)
	if not ok then
		warn('[tapev4/Arena] Startup failed: '..tostring(result))
	end
	return ok, result
end

local cloneref = cloneref or function(obj) return obj end

local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))

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
	local ok, val = pcall(debug.getupvalue, callback, index)
	return ok and val or nil
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

local setupOK, setupError = run(function()
	assert(type(getsenv) == 'function' and type(getconnections) == 'function',
		'Executor requires getsenv and getconnections')
	assert(debug and type(debug.getupvalue) == 'function' and
		type(debug.setupvalue) == 'function' and type(debug.getconstants) == 'function',
		'Executor requires debug upvalue / constants APIs')

	local scripts = child(lplr, 'PlayerScripts')
	local charscript = child(scripts, 'CharacterController')

	-- Wait for the CharacterController executors to expose a usable startHit.
	local env, startHitFunc
	local deadline = tick() + 20

	repeat
		local ok, result = pcall(getsenv, charscript)
		if ok and type(result) == 'table' then
			env = result

			-- Sometimes it lives in an upvalue.
			if type(env.startHit) == 'function' then
				startHitFunc = env.startHit
			else
				for i = 1, 20 do
					local uv = readUpvalue(env.startHit or function() end, i)
					if type(uv) == 'function' then
						startHitFunc = uv
						break
					end
				end
			end
		end

		if startHitFunc then break end
		task.wait(0.15)
	until tick() >= deadline or not active

	assert(active and startHitFunc, 'startHit callback unavailable')

	-- Get the real swing function (usually upvalue 1)
	local swingFunc = readUpvalue(startHitFunc, 1) or startHitFunc

	arena = {
		Client = env,
		PlayerState = require(child(charscript, 'PlayerState')),
		Inventory = require(child(charscript, 'Inventory')),
		MoveController = require(child(scripts, 'PlayerModule')):GetControls(),
		Fly = {Enabled = false},
		LongJump = {Enabled = false},
		SwingFunction = swingFunc,
		startHit = startHitFunc
	}

	-- Fly + LongJump setup (fixed variable names)
	local flySetupOK = run(function()
		local flyModule = child(scripts, 'Fly')
		arena.Fly = require(flyModule)
		arena.Fly.Enabled = true
		arena.Fly.PhaseLocked = false

		local longJumpModule = child(scripts, 'LongJump')
		arena.LongJump = require(longJumpModule)
		arena.LongJump.Enabled = true
		arena.LongJump.AutoActivate = false
	end)
	assert(flySetupOK, 'Arena controller setup failed (Fly/LongJump)')

	-- Find TickFunction
	for _, v in getconnections(runService.Heartbeat) do
		if type(v.Function) == 'function' and (not islclosure or islclosure(v.Function)) then
			local success, constants = pcall(debug.getconstants, v.Function)
			if success and type(constants) == 'table' and constants[1] == 0.05 then
				local value = readUpvalue(v.Function, 3)
				if type(value) == 'function' then
					arena.TickFunction = value
				end
			end
		end
	end

	-- Find MoveFunction
	local loadRemote = child(child(replicatedStorage, 'Remotes'), 'LoadLocalCharacter')
	for _, v in getconnections(loadRemote.OnClientEvent) do
		if v.Function then
			local value = readUpvalue(v.Function, 9)
			if type(value) == 'function' then
				arena.MoveFunction = value
			end
		end
	end

	assert(type(arena.SwingFunction) == 'function' and arena.TickFunction and arena.MoveFunction,
		'Arena controller callbacks unavailable; wait for the game to fully load')

	child(workspace, 'OtherCharacters')
end)

if not setupOK then
	error('[tapev4/Arena] '..tostring(setupError), 0)
end
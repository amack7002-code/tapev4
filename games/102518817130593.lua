--1.8 PvP club
local run = function(func) func() end
local cloneref = cloneref or function(obj) return obj end
local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local runService = cloneref(game:GetService('RunService'))
local httpService = cloneref(game:GetService('HttpService'))
local virtualUser = cloneref(game:GetService('VirtualUser'))
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local sessioninfo = vape.Libraries.sessioninfo
local gameapi = {}

local PlayerVideoSettings = require(replicatedStorage:WaitForChild("PlayerVideoSettings"))
local ControllerInput = require(replicatedStorage:WaitForChild("ControllerInput"))
local FirstPersonItemSwing = require(replicatedStorage:WaitForChild("FirstPersonItemSwing"))
local MeleeHitVisuals = require(replicatedStorage:WaitForChild("MeleeHitVisuals"))
local MinecraftMeleeGeometry = require(replicatedStorage:WaitForChild("MinecraftMeleeGeometry"))
local HeldItemFov = require(replicatedStorage:WaitForChild("HeldItemFov"))
local GameplayInputGuard = require(replicatedStorage:WaitForChild("GameplayInputGuard"))
local EmoteRuntime = require(replicatedStorage:WaitForChild("EmoteRuntime"))

local SwordSkinRuntime = require(replicatedStorage:WaitForChild("SwordSkinRuntime"))
local CosmeticsCatalog = require(replicatedStorage:WaitForChild("CosmeticsCatalog"))
local MinecraftCombat = replicatedStorage:WaitForChild("MinecraftCombat")
local Attack = MinecraftCombat:WaitForChild("Attack")
local Block = MinecraftCombat:WaitForChild("Block")
local Sprint = MinecraftCombat:WaitForChild("Sprint")
local Feedback = MinecraftCombat:WaitForChild("Feedback")
local Swing = MinecraftCombat:WaitForChild("Swing")
--local PlrBody = lplr.MinecraftBody

local function notif(...) return
	vape:CreateNotification(...)
end

for _, v in {'PlayerModel','AimAssist', 'Search', 'Waypoints', 'Disabler', 'MurderMystery', 'SilentAim', 'Gravity', 'Parkour', 'LongJump', 'HitBoxes', "AutoClicker", "MouseTP"} do
    vape:Remove(v)
end


run(function()
    local sprint

    sprint = vape.Categories.Combat:CreateModule({
        Name = 'Sprint',
        Function = function(callback)
            if callback then
                local running = true

                sprint:Clean(function()
                    running = false
                end)

                task.spawn(function()
                    while running and sprint.Enabled do
                        Sprint:FireServer(true)
                        task.wait()
                    end
                end)
            else
                Sprint:FireServer(false)
            end
        end,
        Tooltip = 'sprints for you gng'
    })
end)

run(function()
	local Velocity
	local Mode
	local Vertical
	local Horizontal
	local DelayGround
	local DelayAir
	local Targetting
	local Chance
	local rand = Random.new()
	local kbEvent = MinecraftCombat:FindFirstChild('KnockbackAck') or MinecraftCombat:WaitForChild('KnockbackAck', 10)
	local oldnamecall
	local kbModule, oldApply
	local lastDecision, lastDecisionAt = false, 0

	local function shouldModify()
		-- the local application and the server ack both call this for the same hit,
		-- so the roll is shared for a short window to keep them in sync
		if tick() - lastDecisionAt < 0.25 then
			return lastDecision
		end
		local decision = rand:NextNumber(0, 100) < Chance.Value
		if decision and Targetting.Enabled then
			decision = entitylib.EntityPosition({
				Range = 50,
				Part = 'RootPart',
				Players = true
			}) ~= nil
		end
		lastDecision, lastDecisionAt = decision, tick()
		return decision
	end

	local function findKnockbackModule()
		-- the game's own knockback controller, with Apply/Step/ScaleHorizontal
		local found
		for _, m in replicatedStorage:GetDescendants() do
			if m:IsA('ModuleScript') and m.Name:lower():find('knockback') then
				local ok, res = pcall(require, m)
				if ok and type(res) == 'table' and type(rawget(res, 'Apply')) == 'function' and type(rawget(res, 'Step')) == 'function' then
					found = res
					break
				end
			end
		end

		if not found and getconnections then
			-- its simulation loop holds the module table as an upvalue
			pcall(function()
				for _, conn in getconnections(runService.PreSimulation) do
					local f = conn and conn.Function
					if type(f) == 'function' then
						for i = 1, 6 do
							local ok, upv = pcall(debug.getupvalue, f, i)
							if ok and type(upv) == 'table' and type(rawget(upv, 'Apply')) == 'function' and type(rawget(upv, 'Step')) == 'function' and type(rawget(upv, 'ScaleHorizontal')) == 'function' then
								found = upv
								break
							end
						end
					end
					if found then break end
				end
			end)
		end
		return found
	end

	local function scaleVelocity(vel)
		if typeof(vel) ~= 'Vector3' then return vel end
		return vel * Vector3.new(Horizontal.Value / 100, Vertical.Value / 100, Horizontal.Value / 100)
	end

	local function currentDelay()
		local airborne = entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air
		return (airborne and DelayAir.Value or DelayGround.Value) / 1000
	end

	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Function = function(callback)
			if callback then
				-- the game applies knockback locally through its own module:
				-- Knockback.Apply(character, velocity)
				kbModule = kbModule or findKnockbackModule()
				if kbModule then
					oldApply = kbModule.Apply
					kbModule.Apply = function(char, vel, ...)
						if char == lplr.Character and shouldModify() then
							if Mode.Value == 'Lag' then
								-- the knockback starts late
								task.delay(currentDelay(), oldApply, char, vel, ...)
								return
							end
							vel = scaleVelocity(vel)
						end
						return oldApply(char, vel, ...)
					end
					Velocity:Clean(function()
						if oldApply then
							kbModule.Apply = oldApply
							oldApply = nil
						end
					end)
				end

				-- and the client acks it to the server with the velocity it took:
				-- KnockbackAck:FireServer(id, playerName, velocity)
				if kbEvent then
					oldnamecall = hookmetamethod(game, '__namecall', function(...)
						local self, method = ..., getnamecallmethod()
						if self == kbEvent and method == 'FireServer' and shouldModify() then
							local args = table.pack(...)

							if Mode.Value == 'Lag' then
								-- the ack goes out late so the server registers it late
								task.delay(currentDelay(), oldnamecall, unpack(args, 1, args.n))
								return
							end

							-- the server applies whatever velocity we ack, so scale it too
							if typeof(args[3]) == 'Vector3' then
								args[3] = scaleVelocity(args[3])
							end
							return oldnamecall(unpack(args, 1, args.n))
						end
						return oldnamecall(...)
					end)
					Velocity:Clean(function()
						if oldnamecall then
							hookmetamethod(game, '__namecall', oldnamecall)
							oldnamecall = nil
						end
					end)
				end
			end
		end,
		Tooltip = 'control you to edit ur knockback'
	})
	Mode = Velocity:CreateDropdown({
		Name = 'Mode',
		List = {'Lag', 'Default'},
		Function = function(val)
			local isDefault = val == 'Default'
			if Horizontal then Horizontal.Object.Visible = isDefault end
			if Vertical then Vertical.Object.Visible = isDefault end
			if DelayGround then DelayGround.Object.Visible = not isDefault end
			if DelayAir then DelayAir.Object.Visible = not isDefault end
		end
	})
	Vertical = Velocity:CreateSlider({
		Name = 'Vertical',
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 1,
		Visible = false
	})
	Horizontal = Velocity:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 1,
		Visible = false
	})
	DelayGround = Velocity:CreateSlider({
		Name = 'Delay Ground',
		Min = 0,
		Max = 3000,
		Default = 1000,
		Suffix = 'ms',
		Decimal = 1
	})
	DelayAir = Velocity:CreateSlider({
		Name = 'Delay Air',
		Min = 0,
		Max = 3000,
		Default = 1000,
		Suffix = 'ms',
		Decimal = 1
	})
	Targetting = Velocity:CreateToggle({
		Name = 'Only when targetting',
		Default = false
	})
	Chance = Velocity:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 1,
		Suffix = '%',
		Tooltip = 'how often it actually changes ur knockback, 100 means every hit'
	})
end)

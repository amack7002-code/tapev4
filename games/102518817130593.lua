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
	local dampUntil = 0
	local dampScale = Vector3.zero
	local lastVelocity

	local function shouldModify()
		if rand:NextNumber(0, 100) >= Chance.Value then return false end
		if Targetting.Enabled then
			return entitylib.EntityPosition({
				Range = 50,
				Part = 'RootPart',
				Players = true
			}) ~= nil
		end
		return true
	end

	local function applyDamp()
		local airborne = entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air
		if Mode.Value == 'Lag' then
			-- eat the knockback for the delay window, then let the rest through late
			local delay = (airborne and DelayAir.Value or DelayGround.Value) / 1000
			dampUntil = tick() + delay
			dampScale = Vector3.zero
		else
			-- scale the knockback by the sliders for the moment it lands
			dampUntil = tick() + 0.3
			dampScale = Vector3.new(Horizontal.Value / 100, Vertical.Value / 100, Horizontal.Value / 100)
		end
	end

	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Function = function(callback)
			if callback then
				-- we own our own physics, so damping the velocity change right after
				-- a hit works no matter which side ends up applying the knockback
				Velocity:Clean(runService.Heartbeat:Connect(function()
					local root = entitylib.isAlive and entitylib.character.RootPart
					if not root then
						lastVelocity = nil
						return
					end
					local vel = root.AssemblyLinearVelocity
					if tick() < dampUntil and lastVelocity then
						local delta = vel - lastVelocity
						root.AssemblyLinearVelocity = lastVelocity + delta * dampScale
					else
						lastVelocity = vel
					end
				end))

				if kbEvent then
					-- the knockback is acked to the server through this remote
					oldnamecall = hookmetamethod(game, '__namecall', function(...)
						local self, method = ..., getnamecallmethod()
						if self == kbEvent and (method == 'FireServer' or method == 'InvokeServer') and shouldModify() then
							applyDamp()
							if method == 'FireServer' and Mode.Value == 'Lag' then
								-- the ack itself goes out late so the server registers the hit late
								local airborne = entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air
								task.delay((airborne and DelayAir.Value or DelayGround.Value) / 1000, oldnamecall, self, ...)
								return
							end
						end
						return oldnamecall(...)
					end)
					Velocity:Clean(function()
						if oldnamecall then
							hookmetamethod(game, '__namecall', oldnamecall)
							oldnamecall = nil
						end
					end)

					-- if the server is the side announcing the knockback, that works as the trigger too
					if kbEvent.OnClientEvent then
						Velocity:Clean(kbEvent.OnClientEvent:Connect(function()
							if shouldModify() then
								applyDamp()
							end
						end))
					end
				end
			else
				dampUntil = 0
				lastVelocity = nil
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

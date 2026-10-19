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

local Raycast = loadstring(game:HttpGet('https://gitlab.com/stxvv/koolrewrite/-/raw/master/libraries/Raycast.lua?ref_type=heads'))()

local function isAlive(plr)
    plr = plr or lplr
    
    local obj
	if plr:IsA('Model') then
		obj = {
			Character = plr
		}
	else
		obj = plr
	end

	return (obj.Character and obj.Character:FindFirstChild('Humanoid') and obj.Character.Humanoid.Health > 0) and true or false
end

local function getClosestEntity(range, angle, wallcheck)
    local minrnge, entity = range, nil

    local lroot = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")
    if not lroot then return nil end

    for _, v in playersService:GetPlayers() do
        if isAlive(v) and v ~= lplr then
            local root = v.Character:FindFirstChild("HumanoidRootPart")
            if not root then continue end
            if wallcheck and not Raycast:CanSee(root) then continue end

            local offset = root.Position - lroot.Position
            local dist = offset.Magnitude
            if dist <= 0 then continue end

            local plrDir = math.deg(math.acos(math.clamp(lroot.CFrame.LookVector:Dot(offset.Unit), -1, 1)))
            if plrDir > angle / 2 then continue end

            if dist < minrnge then
                minrnge = dist
                entity = v
            end
        end
    end

    return entity
end

local function getTool(plr)
	plr = plr or lplr

    if isAlive(plr) then
    	return plr.Character and plr.Character:FindFirstChildOfClass('Tool') or nil
    end

    return nil
end


local function decompile(scriptPath: ModuleScript | LocalScript): string
    local sucByte, bytecode = pcall(getscriptbytecode, scriptPath)

    if not sucByte then
        return `-- Failed to get script bytecode, error:\n\n--[[\n{bytecode}\n--]]`
    end

    local okRequest: boolean, httpResult = pcall(request, {
        Url = 'https://api.lua.expert/decompile',
        Method = 'POST',
        Body = HttpService:JSONEncode({
            script = base64encode(bytecode),
        }),
        Headers = {
            ['Content-Type'] = 'application/json'
        },
    })

    if not okRequest then
        return `-- Failed to decompile, error:\n\n--[[\n{httpResult}\n--]]`
    end

    if httpResult.StatusCode ~= 200 then
        return `-- Error occurred while requesting the API, error:\n\n--[[\n{httpResult.Body}\n--]]`
    end

    return string.gsub(httpResult.Body, string.char(0x00CD), ' ')
end

local req, fakereq = require, nil
local function require(obj)
    local exec = select(1, identifyexecutor())
    if not require or table.find({'Solara', 'Xeno'}, exec) then
        local source = decompile(obj)
        local func = loadstring(source)

        if getfenv then
            getfenv(func).require = fakereq
            getfenv(func).script = obj
        end

        local suc, res = pcall(function()
            return func()
        end)

        if suc and res ~= nil then
            return res
        else
            return error('Requested module experienced an error while loading')
        end
    end

    return req(obj)
end
fakereq = require

local ControllerInput = {
    IsBlocked = function()
		local MenuIsOpen
        if lplr:GetAttribute('DuelMenuOpen') or lplr:GetAttribute('DuelFrozen') or lplr:GetAttribute('SettingsOpen') then
        	MenuIsOpen = true
        else
        	MenuIsOpen = GuiService.MenuIsOpen
            if not MenuIsOpen then
            	if not UserInputService:GetFocusedTextBox() then
            		if lplr:GetAttribute('UpgradeShopOpen') or lplr:GetAttribute('RobuxShopOpen') or lplr:GetAttribute('CosmeticsOpen') or lplr:GetAttribute('CosmeticCrateOpen') then
            			MenuIsOpen = true
            		else
            			MenuIsOpen = lplr:GetAttribute('DailyRewardsOpen') == true
            		end
            	else
            		MenuIsOpen = true
            	end
            end
        end

        return MenuIsOpen
	end
}

local Dependencies = {
    Geometry = MinecraftMeleeGeometry,
    HitVisuals = MeleeHitVisuals,
    isBlocked = ControllerInput.IsBlocked,
    vmSwing = -10
}

do
    local restP, unstableSince, lastClone, parts = nil, nil, nil, {}

    pcall(function()
    	RunService:UnbindFromRenderStep('Swing')
    end)

    local function getViewmodel()
    	if not isAlive(lplr) then return end
    	if not workspace.CurrentCamera:FindFirstChild('MinecraftSwordViewmodel') or not workspace.CurrentCamera:FindFirstChild('MinecraftSwordViewmodel'):FindFirstChild('Sword') then return end
        if not lplr.PlayerGui:FindFirstChild('FixedFovHeldItems'):FindFirstChildOfClass('ViewportFrame'):FindFirstChild('Sword') then return end

        return workspace.CurrentCamera, workspace.CurrentCamera:FindFirstChild('MinecraftSwordViewmodel'):FindFirstChild('Sword'), lplr.PlayerGui:FindFirstChild('FixedFovHeldItems'):FindFirstChildOfClass('ViewportFrame'):FindFirstChild('Sword')
    end

    local function swingQ(p, e)
        local t = math.clamp(e / 0.3, 0, 1)
        local s2, s3, s4, s5 = math.sin(t * t * math.pi), math.sin(math.sqrt(t) * math.pi), math.sin(math.sqrt(t) * math.pi * 2), math.sin(t * math.pi)

        local off, yaw, v6 = Vector3.new(-s3 * 0.4, s4 * 0.2, -s5 * 0.2), CFrame.Angles(0, 0.7853981633974483, 0), CFrame.Angles(0, math.rad(s2 * -20), 0) * CFrame.Angles(0, 0, math.rad(s3 * -20)) * CFrame.Angles(math.rad(s3 * -80), 0, 0)
        return CFrame.new(p + off) * yaw * v6 * yaw:Inverse() * CFrame.new(-p)
    end

    RunService:BindToRenderStep('Swing', Enum.RenderPriority.Last.Value + 101, function()
    	local cam, orig, clone = getViewmodel()
        if not cam then return end
        
        local k, ls = 0.7002075382097097 / math.tan(math.rad(cam.FieldOfView) * 0.5), cam.CFrame:ToObjectSpace(orig:GetPivot())
        local lp = Vector3.new(ls.X, ls.Y, ls.Z / k)

        if not restP then
            restP = lp
            unstableSince = nil
        elseif (lp - restP).Magnitude < 0.03 then
            restP = lp
            unstableSince = nil
        else
            if not unstableSince then
                unstableSince = os.clock() + 1.2
            end
            
            if not (os.clock() >= unstableSince) then
                return
            end

            restP = lp
            unstableSince = nil
        end

        local e = os.clock() - Dependencies.vmSwing
        if e < 0 or e > 0.3 then return end

        local Q = swingQ(restP, e)
        if clone ~= lastClone then
            lastClone = clone
            table.clear(parts)

            for _, v in ipairs(clone:GetDescendants()) do
                if v:IsA('BasePart') then
                    table.insert(parts, v)
                end
            end
        end

        for _, v in ipairs(parts) do
            if v.Parent then
                v.CFrame = Q * v.CFrame
            end
        end
    end)
end

local function notif(...) return
	vape:CreateNotification(...)
end

for _, v in {'PlayerModel', 'Search', 'Waypoints', 'Disabler', 'MurderMystery', 'SilentAim', 'Gravity', 'Parkour', 'LongJump', 'HitBoxes', "AutoClicker", "MouseTP"} do
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

	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Function = function(callback)
			if callback then
				replicatedStorage.MinecraftKnockbackMotion:Destroy()
			end
		end,
		Tooltip = 'makes you take no knockback but you cant undo it'
	})
end)


run(function()
    if not shared.seq then
        shared.seq = 0
    end

    local lastSwing, lastAttack = 0, 0
    local function getKillauraValues(range, angle, wallcheck) -- haha very funny gpt moment (it's not, i can assure :/)
        if not isAlive(lplr.Character) then return end
        if Dependencies.isBlocked() then return end
        if lplr.Character:GetAttribute('EatingApple') or lplr.Character:GetAttribute('BowDrawStarted') then return end

        local entity = getClosestEntity(range, angle, wallcheck)
        if not entity then return end

        local eye = Dependencies.Geometry.Eye(lplr.Character.PrimaryPart.Position, lplr.Character:GetAttribute('Sneaking'))
        local dir = CFrame.lookAt(lplr.Character.PrimaryPart.Position, entity.Character.PrimaryPart.Position).LookVector

        local dist, part = Dependencies.Geometry.Hit(eye, dir, entity.Character.PrimaryPart.Position, entity.Character:GetAttribute('Sneaking'), range)
        if not dist then return end
        
        return {char = entity.Character, root = entity.Character.PrimaryPart, dist = dist, part = part, eye = eye, dir = dir}
    end

    local killaura, attackInterval, range, angle, itemCheck, wallCheck, swing
    killaura = vape.Categories.Combat:CreateModule({
        Name = 'Killaura',
        Function = function(callback)
            if callback then
                repeat
                    task.wait()

                    if isAlive(lplr) then
                        local item = getTool(lplr)
                        if itemCheck.Value and item and item.Name ~= 'Diamond Sword' then continue end

                        local entity = getKillauraValues(range.Value, angle.Value, wallCheck.Value)
                        if entity then
                            if workspace.SkySpawn.CourtyardArchitecture['Arena red wool floor edge'].Position.Y <= lplr.Character.PrimaryPart.Position.Y then continue end

                            if swing.Value and os.clock() >= lastSwing then
                                Dependencies.vmSwing = os.clock()
                                lastSwing = os.clock() + math.max(0.15, attackInterval.Value)

                                lplr.Character:SetAttribute('LocalAttackSwing', os.clock())
                            end

                            if attackInterval.Value and os.clock() >= lastAttack then
                                lastAttack = os.clock() + attackInterval.Value

                                shared.seq += 1
                                local payload = {
                                    version = 2,
                                    character = lplr.Character,
                                    seq = shared.seq,
                                    sentAt = workspace:GetServerTimeNow(),
                                    eye = entity.eye,
                                    targetRoot = entity.root.Position,
                                    hitPart = entity.part,
                                }

                                Dependencies.HitVisuals.Predict(entity.char)
                                replicatedStorage.MinecraftCombat.Attack:FireServer(entity.char, entity.eye + entity.dir * entity.dist, entity.dir, nil, payload)
                            end
                        end
                    end
                until not killaura.Enabled
            end
        end,
        Tooltip = 'Automatically attacks players around you.'
    })
    attackInterval = killaura:CreateSlider({
        Name = 'Attack Interval',
        Min = 0.05,
        Max = 1,
        Default = 0.05,
        Function = function() end,
        Suffix = 's'
    })
    range = killaura:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 11.25,
        Default = 11.25,
        Function = function() end,
        Suffix = 'studs'
    })
    angle = killaura:CreateSlider({
        Name = 'Angle',
        Min = 1,
        Max = 360,
        Default = 360,
        Function = function() end,
        Suffix = '°'
    })
    itemCheck = killaura:CreateToggle({
        Name = 'Item Check',
        Default = false,
        Function = function() end,
        Tooltip = 'Automatically checks to see if you are holding the correct item.'
    })
    wallCheck = killaura:CreateToggle({
        Name = 'Wall check',
        Default = false,
        Function = function() end,
        Tooltip = 'Automatically checks to see if the person is in your line of sight.'
    })
    swing = killaura:CreateToggle({
        Name = 'Swing',
        Default = false,
        Function = function() end,
        Tooltip = 'Automatically plays the swing animation.'
    })
end)
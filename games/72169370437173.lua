local run = function(func)
    local ok, err = pcall(func)
    if not ok then warn('module load failed: ' .. tostring(err)) end
end
local cloneref = cloneref or function(obj) return obj end
local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local inputService = cloneref(game:GetService('UserInputService'))
local runService = cloneref(game:GetService('RunService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local lplr = playersService.LocalPlayer
local vape = shared.vape
local gameapi = {}

local previous = shared.tribesGameSupport
if type(previous) == 'table' and type(previous.Cleanup) == 'function' then
    pcall(previous.Cleanup)
end

for _, v in {'PlayerModel', 'AimAssist', 'Search', 'Waypoints', 'StaffDetector', 'AutoClicker', 'Reach', 'Disabler', 'MurderMystery', 'Killaura', 'TriggerBot', 'SilentAim', 'Gravity', 'Parkour', 'LongJump', 'HitBoxes', 'TargetStrafe', 'NameTags', 'Aimbot', 'AutoKill', 'AutoWin', 'Speed', 'FreeCursor', 'PlayerAttach', 'NoSlowdown', 'InstantConsume', 'AntiHit', 'TrapESP', 'StreakSpoof', 'LevelSpoof', 'AntiSmoke', 'Velocity', 'AutoUpgrade', 'AutoQueue'} do
	vape:Remove(v)
end

local scripts = lplr:WaitForChild('PlayerScripts')
local combatFolder = scripts:WaitForChild('Combat')
local handlers = combatFolder:WaitForChild('Handlers')
local sharedFolder = replicatedStorage:WaitForChild('Shared')
local combat = require(sharedFolder:WaitForChild('Combat'))
local weapons = require(sharedFolder:WaitForChild('Weapons'))
local util = require(combatFolder:WaitForChild('Util'))
local controller = require(combatFolder:WaitForChild('Controller'))
local effects = require(combatFolder:WaitForChild('Effects'))
local use = require(handlers:WaitForChild('Use'))
local melee = require(handlers:WaitForChild('Melee'))
local bow = require(handlers:WaitForChild('Bow'))
local throwing = require(handlers:WaitForChild('Throw'))
local gun = require(handlers:WaitForChild('Gun'))

local options = {
    Headshots = false,
    SilentAim = false,
    SilentTargets = nil,
    SilentRange = 300,
    SilentFov = 140,
    SilentWalls = true,
    HeadshotsTargets = nil,
    HitBoxes = false,
    HitboxRadius = 0,
    NoSlowdown = false,
    AutoKilling = false
}

local FALL_GRAVITY_SCALE = 1.3
local patches = {}
local connections = {}
local tracked = {}
local guiObjects = {}

function gameapi.Cleanup()
    if gameapi.ReleasePrimary then gameapi.ReleasePrimary() end
    for _, connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    for index = #patches, 1, -1 do
        local patch = patches[index]
        pcall(function()
            if patch.table[patch.key] == patch.new then
                patch.table[patch.key] = patch.old
            end
        end)
    end
    for _, object in ipairs(guiObjects) do
        pcall(function() object:Destroy() end)
    end
    for _, item in ipairs(tracked) do
        pcall(function() item:Destroy() end)
    end
    if gameapi.RestoreHitboxes then
        pcall(gameapi.RestoreHitboxes)
    end
    if gameapi.RestoreTrapESP then
        pcall(gameapi.RestoreTrapESP)
    end
    if gameapi.RestoreStatSpoofs then
        pcall(gameapi.RestoreStatSpoofs)
    end
end

function gameapi.Patch(tab, key, factory)
    if type(tab) ~= 'table' or type(tab[key]) ~= 'function' then return false end
    local old = tab[key]
    local replacement = factory(old)
    local ok = pcall(function() tab[key] = replacement end)
    if not ok or tab[key] ~= replacement then return false end
    patches[#patches + 1] = {table = tab, key = key, old = old, new = replacement}
    return true
end

function gameapi.Connect(event, callback)
    local connection = event:Connect(callback)
    connections[#connections + 1] = connection
    return connection
end


local statSpoofs = {}

function gameapi.StatSpoof(name, attribute, includeCharacter)
    local module, slider
    local enabled = false
    local saved = setmetatable({}, {__mode = 'k'})
    local watched = setmetatable({}, {__mode = 'k'})
    local conns = {}

    local function disconnect()
        for _, conn in ipairs(conns) do conn:Disconnect() end
        table.clear(conns)
        table.clear(watched)
    end

    local function apply()
        if not enabled or not slider then return end
        local function update(object)
            if not object then return end
            if not saved[object] then
                saved[object] = {value = object:GetAttribute(attribute)}
            end
            if object:GetAttribute(attribute) ~= slider.Value then
                object:SetAttribute(attribute, slider.Value)
            end
        end
        update(lplr)
        if includeCharacter then update(lplr.Character) end
    end

    local function watch(object)
        if not object or watched[object] then return end
        watched[object] = true
        conns[#conns + 1] = object:GetAttributeChangedSignal(attribute):Connect(function()
            if enabled then task.defer(apply) end
        end)
    end

    local function restore()
        enabled = false
        disconnect()
        for object, record in pairs(saved) do
            pcall(function()
                if object.Parent and slider and object:GetAttribute(attribute) == slider.Value then
                    object:SetAttribute(attribute, record.value)
                end
            end)
            saved[object] = nil
        end
    end

    module = vape.Categories.Render:CreateModule({
        Name = name,
        Function = function(state)
            if not state then restore() return end
            enabled = true
            watch(lplr)
            if includeCharacter then
                watch(lplr.Character)
                conns[#conns + 1] = lplr.CharacterAdded:Connect(function(char)
                    watch(char)
                    task.defer(apply)
                end)
            end
            apply()
        end,
        Tooltip = 'changes the local ' .. attribute:lower() .. ' display only'
    })

    slider = module:CreateSlider({
        Name = 'value', Min = 0, Max = 9999, Default = 100,
        Function = function() apply() end
    })

    statSpoofs[#statSpoofs + 1] = restore
    return module
end

function gameapi.RestoreStatSpoofs()
    for _, restore in ipairs(statSpoofs) do restore() end
end

function gameapi.Tool()
    local char = lplr.Character
    local tool = char and char:FindFirstChildOfClass('Tool')
    local state = controller.State()
    if type(state) ~= 'table' or state.equipPending then return end
    if tool and state.tool ~= tool.Name then return end
    local id = tool and tool:GetAttribute('WeaponId') or combat.FISTS_ID
    if type(id) ~= 'string' then return end
    local def = weapons.Get(id)
    local kind = def and def.kind or (not tool and 'Fists')
    if kind ~= state.kind then return end
    return tool, id, kind, combat.Tuning(id), state
end

function gameapi.Valid(model, targets)
    if typeof(model) ~= 'Instance' or not model:IsA('Model') then return false end
    if model == lplr.Character or not model:IsDescendantOf(workspace) then return false end
    local player = playersService:GetPlayerFromCharacter(model)
    if targets then
        if player and not targets.Players.Enabled then return false end
        if not player and not targets.NPCs.Enabled then return false end
    end
    local humanoid = model:FindFirstChildOfClass('Humanoid')
    return humanoid ~= nil and humanoid.Health > 0 and util.CanPredictHit(model)
end

function gameapi.TargetPart(model, head)
    if head then
        return model:FindFirstChild('Head') or model:FindFirstChild('UpperTorso') or model:FindFirstChild('HumanoidRootPart')
    end
    return model:FindFirstChild('UpperTorso') or model:FindFirstChild('Torso') or model:FindFirstChild('HumanoidRootPart') or model:FindFirstChild('Head')
end

function gameapi.Cursor()
    local camera = workspace.CurrentCamera
    if not camera then return Vector2.zero end
    return inputService.TouchEnabled and camera.ViewportSize * 0.5 or inputService:GetMouseLocation()
end

function gameapi.Clear(origin, point, model)
    if combat.SmokeBlocks(origin, point) then return false end
    local params = util.WorldParams(util.Targets())
    local hit = workspace:Raycast(origin, point - origin, params)
    return hit == nil or hit.Instance:IsDescendantOf(model)
end

function gameapi.Closest(targets, distanceLimit, fov, head, wallcheck, origin)
    local camera = workspace.CurrentCamera
    if not camera then return nil end

    local center = gameapi.Cursor()
    local source = typeof(origin) == 'Vector3' and origin or camera.CFrame.Position
    local best, score = nil, math.huge
    local extraStuds = options.HitBoxes and options.HitboxRadius / 8 or 0
    local focal = camera.ViewportSize.Y / (2 * math.tan(math.rad(camera.FieldOfView) * 0.5))

    for _, model in ipairs(util.Targets()) do
        if gameapi.Valid(model, targets) then
            local part = gameapi.TargetPart(model, head)

            if head and wallcheck and part and not gameapi.Clear(source, part.Position, model) then
                part = gameapi.TargetPart(model, false)
            end

            if part and part:IsA('BasePart') then
                local delta = part.Position - source
                local distance = delta.Magnitude

                if distance <= distanceLimit then
                    local cursorPart = gameapi.TargetPart(model, false) or part
                    local point, onScreen = camera:WorldToViewportPoint(cursorPart.Position)

                    if onScreen and point.Z > 0 then
                        local pixels = (Vector2.new(point.X, point.Y) - center).Magnitude
                        local depth = (part.Position - camera.CFrame.Position):Dot(camera.CFrame.LookVector)
                        local allowance = extraStuds * focal / math.max(depth, 1) * 0.5

                        if pixels <= fov + allowance and pixels < score then
                            if not wallcheck or gameapi.Clear(source, part.Position, model) then
                                best, score = part, pixels
                            end
                        end
                    end
                end
            end
        end
    end

    return best
end

local velocityHistory = setmetatable({}, {__mode = 'k'})

function gameapi.TargetVelocity(model, root)
    local now = os.clock()
    local raw = root.AssemblyLinearVelocity
    local record = velocityHistory[model]

    if not record then
        velocityHistory[model] = {
            position = root.Position,
            velocity = raw,
            time = now
        }

        return raw
    end

    local dt = now - record.time

    if dt < 0.035 then
        return record.velocity
    end

    local displacement = root.Position - record.position
    local measured = displacement / math.max(dt, 0.001)

    if displacement.Magnitude > 15 or dt > 0.4 then
        record.velocity = raw
    else
        local candidate = raw

        if measured.Magnitude < 90 then
            candidate = raw:Lerp(measured, 0.3)
        end

        local change = (candidate - record.velocity).Magnitude
        local response = change > 12 and 0.85 or 0.6

        record.velocity = record.velocity:Lerp(candidate, response)
    end

    record.position = root.Position
    record.time = now

    return record.velocity
end

local nextVelocitySample = 0

gameapi.Connect(runService.Heartbeat, function()
    if not options.SilentAim or os.clock() < nextVelocitySample then
        return
    end

    nextVelocitySample = os.clock() + 0.08

    for _, model in ipairs(util.Targets()) do
        if gameapi.Valid(model, options.SilentTargets) then
            local root = model:FindFirstChild('HumanoidRootPart')

            if root then
                gameapi.TargetVelocity(model, root)
            end
        end
    end
end)

function gameapi.TrajectoryClear(origin, velocity, gravity, flight)
    local params = util.WorldParams(util.Targets())
    local ballistics = combat.Ballistics
    local projectile = ballistics.new(origin, velocity, gravity)
    local elapsed = 0

    while elapsed < flight - 0.025 do
        local dt = math.min(0.06, flight - elapsed - 0.025)
        if dt <= 0 then break end
        local position, displacement = ballistics.Advance(projectile, dt)
        if ballistics.Cast(position, displacement, 0, params) then
            return false
        end
        elapsed += dt
    end

    return true
end

function gameapi.Aim(origin, target, speed, gravity, checkWalls)
    if typeof(origin) ~= 'Vector3' then return nil end
    if not target or not target:IsA('BasePart') then return nil end
    if type(speed) ~= 'number' or speed <= 0 then return nil end

    gravity = tonumber(gravity) or 0

    local model = target:FindFirstAncestorOfClass('Model')
    local root = model and model:FindFirstChild('HumanoidRootPart')
    local humanoid = model and model:FindFirstChildOfClass('Humanoid')

    local velocity = root
        and gameapi.TargetVelocity(model, root)
        or target.AssemblyLinearVelocity

    local airborne = (humanoid and humanoid.FloorMaterial == Enum.Material.Air)
        or math.abs(velocity.Y) > 1

    local latency = 0

    pcall(function()
        latency = math.clamp(lplr:GetNetworkPing() * 0.65, 0, 0.09)
    end)

    local horizontal = Vector3.new(velocity.X, 0, velocity.Z)

    if horizontal.Magnitude > 85 then
        horizontal = horizontal.Unit * 85
    end

    local groundHeight

    if airborne and root then
        local params = util.WorldParams(util.Targets())
        local hit = workspace:Raycast(
            root.Position,
            Vector3.new(0, -24, 0),
            params
        )

        if hit and root.Position.Y - hit.Position.Y < 16 then
            groundHeight = hit.Position.Y
                + (humanoid.HipHeight or 0)
                + root.Size.Y * 0.5
                + (target.Position.Y - root.Position.Y)
        end
    end

    local speedSquared = speed * speed
    local lifetime = math.min(combat.Ballistics.MAX_LIFETIME or 5, 5)

    local function evaluate(t)
        local ahead = t + latency
        local displacement = horizontal * ahead
        local point = target.Position + displacement

        if airborne then
            local rise = workspace.Gravity
            local fall = rise * FALL_GRAVITY_SCALE
            local vy = velocity.Y
            local vertical
            if vy > 0 then
                local apex = vy / rise
                if ahead <= apex then
                    vertical = vy * ahead - rise * ahead * ahead * 0.5
                else
                    local down = ahead - apex
                    vertical = vy * apex - rise * apex * apex * 0.5 - fall * down * down * 0.5
                end
            else
                vertical = vy * ahead - fall * ahead * ahead * 0.5
            end

            local predictedY = target.Position.Y + vertical

            if groundHeight and displacement.Magnitude < 10 then
                predictedY = math.max(predictedY, groundHeight)
            end

            point = Vector3.new(point.X, predictedY, point.Z)
        end

        local offset = point - origin
            + Vector3.new(0, gravity * t * t * 0.5, 0)

        return offset:Dot(offset) - speedSquared * t * t, offset
    end

    local previous = 0

    for t = 0.025, lifetime, 0.025 do
        local error = evaluate(t)

        if error <= 0 then
            local low = previous
            local high = t

            for _ = 1, 24 do
                local middle = (low + high) * 0.5
                local difference = evaluate(middle)

                if difference > 0 then
                    low = middle
                else
                    high = middle
                end
            end

            local flight = (low + high) * 0.5
            local _, vector = evaluate(flight)

            if vector.Magnitude < 0.001 then return nil end

            local direction = vector.Unit

            if checkWalls and not gameapi.TrajectoryClear(
                origin,
                direction * speed,
                gravity,
                flight
            ) then
                return nil
            end

            return direction, flight
        end

        previous = t
    end

    return nil
end

function gameapi.ShotSpeed(tool, kind, tuning)
    if not tuning then return nil end
    if combat.IsDrawn(kind) then
        local snap = gameapi.Shot
        local charge = snap.tool == tool and os.clock() - snap.at < 0.35 and snap.charge or nil
        if type(charge) == 'number' then
            local ok, _, speed = pcall(combat.DrawnShot, tuning, charge)
            if ok then return speed end
        end
        return nil
    end
    local ok, speed = pcall(combat.ShotSpeed, tuning)
    return ok and speed or nil
end

function gameapi.ShotProfile(tool, kind, tuning, speed)
    if not tuning or not kind then return nil end
    speed = tonumber(speed) or gameapi.ShotSpeed(tool, kind, tuning)
        or tonumber(tuning.speedMax) or tonumber(tuning.speed)
    if not speed or speed <= 0 then return nil end
    local gravity = tonumber(tuning.gravity)
    if gravity == nil then
        gravity = (combat.IsDrawn(kind) or kind == 'Javelin' or kind == 'Knives' or kind == 'Sling' or kind == 'Bomb') and 60 or 0
    end
    return {speed = speed, gravity = gravity}
end

function gameapi.Dispatch(action, pressed)
    local state = controller.State()
    if type(state) ~= 'table' or state.equipPending or not util.CanAct() then
        return false
    end
    if pressed and util.IsMouseUnlocked() then return false end
    return pcall(controller.Dispatch, action, pressed)
end

local primaryOwner
function gameapi.Primary(owner, pressed)
    if pressed then
        if primaryOwner == owner then return true end
        if primaryOwner ~= nil then return false end
        if inputService:GetFocusedTextBox() or lplr:GetAttribute('MenuOpen') == true then
            return false
        end
        if not gameapi.Dispatch('Primary', true) then return false end
        primaryOwner = owner
        return true
    end
    if primaryOwner ~= owner then return false end
    primaryOwner = nil
    return pcall(controller.Dispatch, 'Primary', false)
end

function gameapi.ReleasePrimary()
    if primaryOwner then
        primaryOwner = nil
        pcall(controller.Dispatch, 'Primary', false)
    end
end

function gameapi.WeaponFromBackpack()
    local backpack = lplr:FindFirstChildOfClass('Backpack')
    if not backpack then return nil end
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA('Tool') then
            local id = tool:GetAttribute('WeaponId')
            local kind = type(id) == 'string' and combat.Kind(id)
            if kind and combat.FiresProjectile(kind) and kind ~= 'Bomb' then
                local tuning = combat.Tuning(id)
                local ammo = tuning and tuning.ammo
                local loaded = tool:GetAttribute('Ammo')
                if tool:GetAttribute('Reloading') ~= true and (type(loaded) ~= 'number' or loaded > 0) and (not ammo or util.AmmoLeft(lplr.Character, ammo) > 0) then
                    return tool, kind, tuning
                end
            end
        end
    end
end

gameapi.Shot = {tool = nil, charge = 0, at = 0}
gameapi.Options = options
shared.tribesGameSupport = gameapi

gameapi.Patch(bow, 'Charge', function(original)
    return function(self, ...)
        local value = original(self, ...)
        gameapi.Shot = {tool = self.ctx and self.ctx.tool, charge = value, at = os.clock()}
        return value
    end
end)

gameapi.Patch(throwing, 'Charge', function(original)
    return function(self, ...)
        local value = original(self, ...)
        gameapi.Shot = {tool = self.ctx and self.ctx.tool, charge = value, at = os.clock()}
        return value
    end
end)

run(function()
	local NameTags, FontOption, Color, Scale, Background, Health, Distance, DisplayName, Layout, Teammates, Targets
	local state, weaponIcon
	local references = {}
	local generation = 0
	local getfontsize = vape.Libraries.getfontsize
	local slotNames = {primary = 1, secondary = 2, melee = 3, utility = 4}
	local old = vape.gui:FindFirstChild('tribes nametags')
	if old then old:Destroy() end
	old = lplr.PlayerGui:FindFirstChild('tribes nametags')
	if old then old:Destroy() end
	local overlay = Instance.new('ScreenGui')
	overlay.Name = 'tribes nametags'
	overlay.IgnoreGuiInset = true
	overlay.ResetOnSpawn = false
	overlay.DisplayOrder = 100
	overlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	overlay.Parent = lplr:WaitForChild('PlayerGui')

	task.spawn(function()
		local scripts = lplr:WaitForChild('PlayerScripts', 20)
		local ui = scripts and scripts:WaitForChild('UI', 20)
		if not ui then return end
		local stateScript = ui:WaitForChild('State', 15)
		local iconScript = ui:WaitForChild('WeaponIcon', 15)
		if stateScript then
			local ok, result = pcall(require, stateScript)
			if ok and type(result) == 'table' then
				state = result
			end
		end
		if iconScript then
			local ok, result = pcall(require, iconScript)
			if ok and type(result) == 'table' and type(result.Set) == 'function' then
				weaponIcon = result
			end
		end
	end)

	local function safeText(value)
		return tostring(value or ''):lower():gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;')
	end

	local function getId(model, player)
		local id = model:GetAttribute('CombatantId')
		if type(id) == 'string' and id ~= '' then
			return id
		end
		return player and 'p' .. player.UserId or nil
	end

	local function getRoster()
		local roster = {}
		local match = state and state.Match
		if type(match) == 'table' and type(match.teams) == 'table' then
			for teamNumber, team in pairs(match.teams) do
				if type(team) == 'table' and type(team.members) == 'table' then
					for _, member in pairs(team.members) do
						if type(member) == 'table' and type(member.id) == 'string' then
							roster[member.id] = {data = member, team = tonumber(teamNumber)}
						end
					end
				end
			end
		end
		return roster
	end

	local function getTeam(model, player, record)
		local team = record and tonumber(record.team)

		if team == 1 or team == 2 then
			return team
		end

		team = tonumber(model:GetAttribute('Team'))

		if team ~= 1 and team ~= 2 then
			team = player and tonumber(player:GetAttribute('Team'))
		end

		return (team == 1 or team == 2) and team or nil
	end

	local function getMyTeam()
		if state and type(state.MyTeam) == 'function' then
			local ok, team = pcall(state.MyTeam)

			if ok and (team == 1 or team == 2) then
				return team
			end
		end

		local team = tonumber(lplr:GetAttribute('Team'))
		return (team == 1 or team == 2) and team or nil
	end

	local function getItems(model, player, record)
		local items = {}
		local loadout = record and record.data and record.data.loadout
		if type(loadout) == 'table' and type(loadout.items) == 'table' then
			for _, id in ipairs(loadout.items) do
				if type(id) == 'string' and id ~= '' and #items < 6 then
					items[#items + 1] = id
				end
			end
			if type(loadout.armor) == 'string' and loadout.armor ~= '' then
				items[#items + 1] = loadout.armor
			end
			return items
		end

		local slotted, other, seen = {}, {}, {}
		local function scan(source)
			if not source then return end
			for _, tool in ipairs(source:GetChildren()) do
				if tool:IsA('Tool') then
					local id = tool:GetAttribute('WeaponId')
					if type(id) ~= 'string' or id == '' then
						id = tool.Name
					end
					if not seen[id] then
						seen[id] = true
						local slot = tool:GetAttribute('SlotIndex')
						if type(slot) ~= 'number' or slot < 1 or slot > 6 then
							slot = slotNames[tool:GetAttribute('Slot')]
						end
						if type(slot) == 'number' and slot >= 1 and slot <= 6 then
							slotted[slot] = id
						else
							other[#other + 1] = id
						end
					end
				end
			end
		end

		if player then
			scan(player:FindFirstChildOfClass('Backpack'))
		end
		scan(model)
		for slot = 1, 6 do
			if slotted[slot] then
				items[#items + 1] = slotted[slot]
			end
		end
		for _, id in ipairs(other) do
			if #items >= 6 then break end
			items[#items + 1] = id
		end
		return items
	end

	local function remove(model)
		local entry = references[model]
		if entry then
			entry.Label:Destroy()
			references[model] = nil
		end
	end

	local function add(model)
		local label = Instance.new('TextLabel')
		label.Name = model.Name
		label.Size = UDim2.fromOffset(80, 24)
		label.AnchorPoint = Vector2.new(0.5, 1)
		label.BackgroundColor3 = Color3.new(0, 0, 0)
		label.BackgroundTransparency = Background.Value
		label.BorderSizePixel = 0
		label.Text = ''
		label.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		label.TextSize = 14 * Scale.Value
		label.FontFace = FontOption.Value
		label.RichText = true
		label.Visible = false
		label.ZIndex = 2
		label.Parent = overlay

		local row = Instance.new('Frame')
		row.Name = 'layout'
		row.AnchorPoint = Vector2.new(0.5, 0)
		row.Position = UDim2.new(0.5, 0, 0, -32 * Scale.Value)
		row.Size = UDim2.fromOffset(0, 30 * Scale.Value)
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Visible = false
		row.ZIndex = 3
		row.Parent = label

		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 2 * Scale.Value)
		layout.Parent = row

		local entry = {Label = label, Row = row, Key = nil}
		references[model] = entry
		return entry
	end

	local function setLayout(entry, items)
		local row = entry.Row
		if not Layout.Enabled or #items == 0 then
			row.Visible = false
			entry.Key = nil

			for _, child in ipairs(row:GetChildren()) do
				if child:IsA('Frame') then
					child:Destroy()
				end
			end

			return
		end

		row.Visible = true
		local scale = Scale.Value
		local size = 28 * scale
		row.Size = UDim2.fromOffset(#items * (size + 2 * scale), size)
		row.Position = UDim2.new(0.5, 0, 0, -32 * scale)

		if not weaponIcon then
			return
		end

		local key = table.concat(items, '|') .. '|' .. tostring(scale)
		if entry.Key == key then return end
		entry.Key = nil
		for _, child in ipairs(row:GetChildren()) do
			if child:IsA('Frame') then
				child:Destroy()
			end
		end

		local completed = true
		for index, id in ipairs(items) do
			local holder = Instance.new('Frame')
			holder.Name = 'item' .. index
			holder.Size = UDim2.fromOffset(size, size)
			holder.BackgroundTransparency = 1
			holder.BorderSizePixel = 0
			holder.LayoutOrder = index
			holder.ZIndex = 3
			holder.Parent = row

			local ok = pcall(weaponIcon.Set, holder, id, {glow = false, outline = false, spin = false})
			if not ok then
				completed = false
			end
		end
		if completed then
			entry.Key = key
		end
	end

	local function shouldShow(model, player, record, myTeam)
		if model == lplr.Character or not model:IsDescendantOf(workspace) then
			return false
		end
		local dummy = collectionService:HasTag(model, 'TrainingDummy')
		local bot = collectionService:HasTag(model, 'Bot')

		if not player and not dummy and not bot and not collectionService:HasTag(model, 'Combatant') then
			return false
		end

		if player and not Targets.Players.Enabled then
			return false
		end

		if not player and not Targets.NPCs.Enabled then
			return false
		end
		local humanoid = model:FindFirstChildOfClass('Humanoid')
		if not humanoid or humanoid.Health <= 0 then
			return false
		end
		if not dummy then
			if not state or not state.SeesMatch() then
				return false
			end

			local matchId = state.SeenMatchId()
			local theirMatch = model:GetAttribute('MatchId')

			if type(matchId) == 'string' and matchId ~= '' and type(theirMatch) == 'string' and theirMatch ~= '' and theirMatch ~= matchId then
				return false
			end

			local team = getTeam(model, player, record)

			if team ~= 1 and team ~= 2 then
				return false
			end

			if not Teammates.Enabled and myTeam and team == myTeam then
				return false
			end
		end
		return true
	end

	local function refresh()
		local roster = getRoster()
		local myTeam = getMyTeam()
		local seen = {}

		local function update(model)
			if not model or seen[model] then return end
			seen[model] = true
			local player = playersService:GetPlayerFromCharacter(model)
			local record = roster[getId(model, player)]
			if not shouldShow(model, player, record, myTeam) then
				remove(model)
				return
			end

			local entry = references[model] or add(model)
			local label = entry.Label
			local humanoid = model:FindFirstChildOfClass('Humanoid')
			local name = player and (DisplayName.Enabled and player.DisplayName or player.Name) or (record and record.data.name) or model.Name
			local content = safeText(name)
			if Health.Enabled then
				local hp = math.ceil(humanoid.Health)
				local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
				local color = ratio > 0.5 and Color3.fromRGB(255, 214, 80):Lerp(Color3.fromRGB(66, 220, 116), (ratio - 0.5) * 2) or Color3.fromRGB(255, 74, 74):Lerp(Color3.fromRGB(255, 214, 80), ratio * 2)
				content = content .. ' <font color="#' .. color:ToHex() .. '">' .. hp .. 'hp</font>'
			end
			if Distance.Enabled and lplr.Character then
				local myRoot = lplr.Character:FindFirstChild('HumanoidRootPart')
				local root = model:FindFirstChild('HumanoidRootPart')
				if myRoot and root then
					content = '[' .. math.floor((myRoot.Position - root.Position).Magnitude) .. '] ' .. content
				end
			end

			local size = 14 * Scale.Value
			label.Text = content
			label.TextSize = size
			label.FontFace = FontOption.Value
			label.BackgroundTransparency = Background.Value

			local team = getTeam(model, player, record)
			local nameColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)

			if team and myTeam then
				nameColor = team == myTeam
					and Color3.fromRGB(90, 195, 255)
					or Color3.fromRGB(255, 95, 110)
			elseif team == 1 then
				nameColor = Color3.fromRGB(90, 195, 255)
			elseif team == 2 then
				nameColor = Color3.fromRGB(255, 95, 110)
			end

			label.TextColor3 = nameColor
			local plain = content:gsub('<[^>]+>', '')
			local bounds = getfontsize(plain, size, FontOption.Value, Vector2.new(100000, 100000))
			label.Size = UDim2.fromOffset(bounds.X + 8, bounds.Y + 7)
			setLayout(entry, getItems(model, player, record))
		end

		for _, player in ipairs(playersService:GetPlayers()) do
			update(player.Character)
		end
		for _, tag in ipairs({'Combatant', 'Bot', 'TrainingDummy'}) do
			for _, model in ipairs(collectionService:GetTagged(tag)) do
				if model:IsA('Model') then
					update(model)
				end
			end
		end
		for model in pairs(references) do
			if not seen[model] then
				remove(model)
			end
		end
	end

	local function draw()
		local camera = workspace.CurrentCamera
		if not camera then return end
		for model, entry in pairs(references) do
			local head = model:FindFirstChild('Head') or model:FindFirstChild('HumanoidRootPart')
			if head and head:IsA('BasePart') then
				local position, visible = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1.4, 0))
				entry.Label.Visible = visible and position.Z > 0
				if entry.Label.Visible then
					entry.Label.Position = UDim2.fromOffset(position.X, position.Y)
				end
			else
				entry.Label.Visible = false
			end
		end
	end

	NameTags = vape.Categories.Render:CreateModule({
		Name = 'NameTags',
		Function = function(enabled)
			generation = generation + 1
			local current = generation
			if enabled then
				overlay.Enabled = true
				NameTags:Clean(runService.RenderStepped:Connect(draw))
				task.spawn(function()
					while NameTags.Enabled and generation == current do
						local ok, err = pcall(refresh)
						if not ok then
							warn('nametags: ' .. tostring(err))
						end
						task.wait(0.25)
					end
				end)
			else
				overlay.Enabled = false

				for model in pairs(references) do
					remove(model)
				end
			end
		end,
		Tooltip = 'shows player names, hp and their full weapon layout'
	})

	Targets = NameTags:CreateTargets({Players = true, NPCs = true})
	FontOption = NameTags:CreateFont({Name = 'font', Blacklist = 'Arial'})
	Color = NameTags:CreateColorSlider({Name = 'player color'})
	Scale = NameTags:CreateSlider({Name = 'scale', Default = 1, Min = 0.1, Max = 1.5, Decimal = 10})
	Background = NameTags:CreateSlider({Name = 'transparency', Default = 0.5, Min = 0, Max = 1, Decimal = 10})
	Health = NameTags:CreateToggle({Name = 'health', Default = true})
	Distance = NameTags:CreateToggle({Name = 'distance'})
	DisplayName = NameTags:CreateToggle({Name = 'use displayname', Default = true})
	Layout = NameTags:CreateToggle({Name = 'layout', Default = true, Tooltip = 'shows their weapons and armor as images'})
	Teammates = NameTags:CreateToggle({Name = 'teammates', Tooltip = 'shows your team too'})
end)



run(function()
    local SilentAim, Targets, Range, Fov, ShowFov, AutoShoot, Hold, Headshot
    local guiService = game:GetService('GuiService')
    local holding = false
    local holdTool
    local holdKind
    local nextFire = 0
    local nextCheck = 0
    local chosenDirection
    local chosenAt = 0
    local firing = false
    local canceling = false

    local existing = lplr.PlayerGui:FindFirstChild('tribes fov')
    if existing then existing:Destroy() end

    local overlay = Instance.new('ScreenGui')
    overlay.Name = 'tribes fov'
    overlay.IgnoreGuiInset = true
    overlay.ResetOnSpawn = false
    overlay.DisplayOrder = 500
    overlay.Enabled = false
    overlay.Parent = lplr.PlayerGui
    guiObjects[#guiObjects + 1] = overlay

    local circle = Instance.new('Frame')
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.BackgroundTransparency = 1
    circle.BorderSizePixel = 0
    circle.Parent = overlay

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = circle

    local outline = Instance.new('UIStroke')
    outline.Color = Color3.new(1, 1, 1)
    outline.Thickness = 1
    outline.Parent = circle

    local visibleNames = {
        'Head', 'UpperTorso', 'Torso', 'LowerTorso',
        'LeftUpperArm', 'RightUpperArm', 'LeftLowerArm', 'RightLowerArm',
        'Left Arm', 'Right Arm', 'LeftUpperLeg', 'RightUpperLeg',
        'LeftLowerLeg', 'RightLowerLeg', 'Left Leg', 'Right Leg'
    }

    local function cursorPosition(camera)
        if inputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
            return camera.ViewportSize * 0.5
        end
        return gameapi.Cursor()
    end

    local function weapon()
        local tool, id, kind, tuning = gameapi.Tool()
        if tool and kind and combat.FiresProjectile(kind) then
            return tool, id, kind, tuning
        end
        local char = lplr.Character
        local equipped = char and char:FindFirstChildOfClass('Tool')
        if not equipped then return end
        local key = equipped:GetAttribute('WeaponId')
        if type(key) ~= 'string' then return end
        local mode = combat.Kind(key)
        if not mode or not combat.FiresProjectile(mode) then return end
        local state = controller.State()
        if type(state) ~= 'table' or state.equipPending or state.tool ~= equipped.Name
            or state.kind ~= mode then return end
        return equipped, key, mode, combat.Tuning(key)
    end

    local function handler()
        if not debug or type(debug.getupvalue) ~= 'function' then return nil end
        local ok, first, second = pcall(debug.getupvalue, controller.State, 2)
        if not ok then return nil end
        local state = type(first) == 'table' and first or type(second) == 'table' and second
        if not state or type(state.handler) ~= 'table' then return nil end
        local active = state.handler
        if type(active.Input) ~= 'function' then return nil end
        if active.ctx and active.ctx.tool then
            if active.ctx.tool.Parent ~= lplr.Character then return nil end
        end
        return active
    end

    local function inputPrimary(pressed, kind)
        local active = handler()
        if active then
            local previous = active.lastShot
            local ok = pcall(active.Input, active, 'Primary', pressed)
            if not ok then return false end
            if not pressed then return true end
            if combat.IsDrawn(kind) then return active.drawing == true end
            if kind == 'Javelin' or kind == 'Bomb' then
                return active.winding == true
            end
            return active.lastShot ~= previous or active.holding == true
                or active.m1Down == true
        end
        return gameapi.Dispatch('Primary', pressed)
    end

    local function targetVisible(origin, point, model)
        local delta = point - origin
        if delta.Magnitude < 0.1 or combat.SmokeBlocks(origin, point) then return false end
        local hit = workspace:Raycast(origin, delta, util.WorldParams())
        return hit == nil or hit.Instance:IsDescendantOf(model)
    end

    local function insideFov(camera, cursor, part)
        local projected = camera:WorldToViewportPoint(part.Position)
        if projected.Z <= 0 then return nil end
        local focal = camera.ViewportSize.Y
            / (2 * math.tan(math.rad(camera.FieldOfView) * 0.5))
        local radius = part.Size.Magnitude * 0.5 * focal / math.max(projected.Z, 0.1)
        local distance = (Vector2.new(projected.X, projected.Y) - cursor).Magnitude
        local edge = math.max(0, distance - radius)
        return edge <= Fov.Value and edge or nil
    end

    local function pick(origin, maxDistance, shot)
        if not SilentAim or not SilentAim.Enabled then return nil end
        local camera = workspace.CurrentCamera
        if not camera or typeof(origin) ~= 'Vector3' then return nil end
        local cursor = cursorPosition(camera)
        local limit = math.min(Range.Value, maxDistance or Range.Value)
        local ranked = {}

        for _, model in ipairs(util.Targets()) do
            if gameapi.Valid(model, Targets) and not util.IsTeammate(model) then
                local root = model:FindFirstChild('HumanoidRootPart')
                if root and (root.Position - origin).Magnitude <= limit + 5 then
                    local edge = math.huge
                    local entered = false
                    for _, name in ipairs(visibleNames) do
                        local part = model:FindFirstChild(name)
                        if part and part:IsA('BasePart') then
                            local score = insideFov(camera, cursor, part)
                            if score then
                                edge = math.min(edge, score)
                                entered = true
                            end
                        end
                    end
                    if entered then
                        ranked[#ranked + 1] = {model = model, score = edge}
                    end
                end
            end
        end

        table.sort(ranked, function(a, b) return a.score < b.score end)

        for _, entry in ipairs(ranked) do
            local model = entry.model
            local head = model:FindFirstChild('Head')
            local torso = model:FindFirstChild('UpperTorso')
                or model:FindFirstChild('Torso')
                or model:FindFirstChild('LowerTorso')
                or model:FindFirstChild('HumanoidRootPart')
            local parts = {}
            if Headshot.Enabled then
                if head and head:IsA('BasePart') then parts[1] = head end
            else
                if torso and torso:IsA('BasePart') then parts[#parts + 1] = torso end
                for _, name in ipairs(visibleNames) do
                    local part = model:FindFirstChild(name)
                    if part and part:IsA('BasePart') and part ~= torso
                        and part ~= head then parts[#parts + 1] = part end
                end
                if #parts == 0 and head then parts[1] = head end
            end
            for _, part in ipairs(parts) do
                if (part.Position - origin).Magnitude <= limit then
                    local points = {
                        part.Position,
                        part.Position + Vector3.new(0, part.Size.Y * 0.15, 0),
                        part.Position - Vector3.new(0, part.Size.Y * 0.15, 0)
                    }
                    for _, point in ipairs(points) do
                        if targetVisible(origin, point, model) then
                            local delta = point - origin
                            if delta.Magnitude > 0.1 then
                                if shot then
                                    local predicted = gameapi.Aim(origin, part, shot.speed, shot.gravity, false)
                                    if predicted then
                                        return predicted, model, part
                                    end
                                end
                                return delta.Unit, model, part
                            end
                        end
                    end
                end
            end
        end
    end

    gameapi.Patch(util, 'AssistDirection', function(original)
        return function(origin, direction, flat)
            local normal = original(origin, direction, flat)
            if not SilentAim or not SilentAim.Enabled then return normal end
            local tool, _, kind, tuning = weapon()
            if not tool or not kind or kind == 'Knives' or kind == 'Sling'
                or kind == 'Javelin' or kind == 'Bomb' then return normal end
            local direct = pick(origin, tonumber(tuning and tuning.range), gameapi.ShotProfile(tool, kind, tuning))
            if direct then return direct end
            if firing and chosenDirection and os.clock() - chosenAt <= 0.2 then
                return chosenDirection
            end
            return normal
        end
    end)

    gameapi.Patch(throwing, 'Launch', function(original)
        return function(self, charge, assisted)
            local origin, direction, speed = original(self, charge, assisted)
            if not SilentAim or not SilentAim.Enabled then return origin, direction, speed end
            local limit = self.tuning and self.tuning.returns
                and tonumber(self.tuning.returns.range) or nil
            local tuning = self.tuning
            local shot = tuning and {speed = speed, gravity = tonumber(tuning.gravity) or 60} or nil
            local direct = pick(origin, limit, shot)
            if direct then return origin, direct, speed end
            if firing and chosenDirection and os.clock() - chosenAt <= 0.2 then
                return origin, chosenDirection, speed
            end
            return origin, direction, speed
        end
    end)

    local function release(cancel)
        if cancel then
            chosenDirection = nil
        end
        if not holding then return end
        canceling = cancel == true
        firing = not cancel
        inputPrimary(false, holdKind)
        firing = false
        canceling = false
        holding = false
        holdTool = nil
        holdKind = nil
    end

    gameapi.Patch(bow, 'Fire', function(original)
        return function(self, ...)
            if canceling and self.drawing then
                self:CancelDraw()
                return
            end
            return original(self, ...)
        end
    end)

    gameapi.Patch(throwing, 'Throw', function(original)
        return function(self, ...)
            if canceling and self.winding then
                self:Cancel()
                return
            end
            return original(self, ...)
        end
    end)

    local function ammoReady(tool, kind, tuning)
        if not tool or not tuning or tool:GetAttribute('Reloading') == true then return false end
        if tuning.ammo and util.AmmoLeft(lplr.Character, tuning.ammo) <= 0 then return false end
        local charges = tool:GetAttribute('Charges')
        if (tonumber(tuning.charges) or 0) > 0
            and type(charges) == 'number' and charges <= 0 then return false end
        if kind == 'Crossbow' or kind == 'Musket' or kind == 'Pistol'
            or kind == 'Blunderbuss' then
            local magazine = tool:GetAttribute('Ammo')
            if type(magazine) == 'number' and magazine <= 0 then return false end
        end
        return true
    end

    local function autoUpdate()
        if not SilentAim or not SilentAim.Enabled or not AutoShoot.Enabled
            or options.AutoKilling or not util.CanAct()
            or guiService.MenuIsOpen or lplr:GetAttribute('MenuOpen') == true
            or inputService:GetFocusedTextBox()
            or inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            release(true)
            return
        end

        local tool, id, kind, tuning = weapon()
        if not tool or not kind or not ammoReady(tool, kind, tuning) then
            release(true)
            return
        end
        if holding and tool ~= holdTool then release(true) return end

        local thrown = kind == 'Knives' or kind == 'Sling'
            or kind == 'Javelin' or kind == 'Bomb'
        local origin = util.ShotOrigin(tool, thrown and 'Tip' or 'Muzzle')
        if thrown and (kind == 'Sling' or id == 'bolas')
            and util.InFirstPerson() then origin = util.ShotOrigin(nil) end
        if typeof(origin) ~= 'Vector3' then return end

        local now = os.clock()
        local charged = combat.IsDrawn(kind) or kind == 'Javelin' or kind == 'Bomb'
        local precharge = id == 'longbow' and Hold.Enabled
        if precharge and not holding and now >= nextFire then
            if inputPrimary(true, kind) then
                holding = true
                holdTool = tool
                holdKind = kind
                heldAt = now
            end
        end

        local direction, model = pick(origin, tonumber(tuning and tuning.range), gameapi.ShotProfile(tool, kind, tuning))
        if not direction then
            if not precharge and holding and now - heldAt > 1.2 then release(true) end
            return
        end
        chosenDirection = direction
        chosenAt = now

        if charged then
            if not holding then
                if now < nextFire then return end
                if inputPrimary(true, kind) then
                    holding = true
                    holdTool = tool
                    holdKind = kind
                    heldAt = now
                end
            else
                local duration = math.max(0.1, tonumber(tuning.drawTime) or 0.5)
                local required = duration * (Hold.Enabled and 1
                    or math.max(0.25, tonumber(tuning.minCharge) or 0.35))
                if now - heldAt >= required and now >= nextFire then
                    nextFire = now + math.max(0.18, tonumber(tuning.cooldown) or 0.25)
                    release(false)
                end
            end
        elseif now >= nextFire then
            firing = true
            local success = inputPrimary(true, kind)
            firing = false
            if success then
                nextFire = now + math.max(0.13,
                    tonumber(tuning.fireInterval) or tonumber(tuning.cooldown) or 0.3)
                task.defer(function() inputPrimary(false, kind) end)
            else
                nextFire = now + 0.08
            end
        end
    end

    SilentAim = vape.Categories.Blatant:CreateModule({
        Name = 'SilentAim',
        Function = function(enabled)
            options.SilentAim = enabled
            options.SilentTargets = Targets
            overlay.Enabled = enabled and ShowFov.Enabled
            if not enabled then release(true) end
        end,
        Tooltip = 'leads ur shots onto enemies inside ur fov'
    })
    Targets = SilentAim:CreateTargets({Players = true, NPCs = true, Walls = true})
    Range = SilentAim:CreateSlider({Name = 'range', Min = 10, Max = 1000, Default = 300})
    Fov = SilentAim:CreateSlider({Name = 'fov', Min = 20, Max = 500, Default = 140})
    ShowFov = SilentAim:CreateToggle({
        Name = 'show fov', Default = true,
        Function = function(enabled) overlay.Enabled = enabled and SilentAim.Enabled end
    })
    Headshot = SilentAim:CreateToggle({Name = 'headshot', Default = false})
    AutoShoot = SilentAim:CreateToggle({
        Name = 'auto shoot', Default = false,
        Function = function(enabled)
            if Hold then Hold.Object.Visible = enabled end
            if not enabled then release(true) end
        end
    })
    Hold = SilentAim:CreateToggle({
        Name = 'hold', Default = true, Darker = true, Visible = false,
        Tooltip = 'holds fully charged weapons before firing'
    })

    gameapi.Connect(runService.Heartbeat, function()
        if not SilentAim or not SilentAim.Enabled then return end
        local now = os.clock()
        if now >= nextCheck then
            nextCheck = now + 0.04
            autoUpdate()
        end
    end)
    gameapi.Connect(runService.RenderStepped, function()
        local tool, _, kind = weapon()
        circle.Visible = overlay.Enabled and tool ~= nil and kind ~= nil
            and combat.FiresProjectile(kind)
        if circle.Visible then
            local camera = workspace.CurrentCamera
            if camera then
                local point = cursorPosition(camera)
                circle.Position = UDim2.fromOffset(point.X, point.Y)
                circle.Size = UDim2.fromOffset(Fov.Value * 2, Fov.Value * 2)
            end
        end
    end)
end)

run(function()
    local Killaura, Targets, Range, Max, FaceTarget, GuardCheck, AutoBlock, BlockMelee, BlockProjectiles
    local focus, swingUntil, activeHandler, activeTool
    local holding, blocking = false, false
    local guardUntil, guardPosition = 0, nil
    local generation = 0
    local previousHumanoid, previousRotate
    local projectiles = {}

    local function setPrimary(enabled)
        if holding == enabled then return end
        if enabled then
            holding = gameapi.Primary('Killaura', true)
        else
            gameapi.Primary('Killaura', false)
            holding = false
        end
    end

    local function setGuard(enabled)
        if blocking == enabled then return end
        if enabled then setPrimary(false) end
        gameapi.Dispatch('Secondary', enabled)
        blocking = enabled
    end

    local function restoreRotate()
        if previousHumanoid and previousHumanoid.Parent then
            previousHumanoid.AutoRotate = previousRotate
        end
        previousHumanoid, previousRotate = nil, nil
    end

    local function findTargets(root, reach, count)
        local targets = {}
        local char = lplr.Character
        local head = char and char:FindFirstChild('Head')
        local source = head and head.Position or root.Position
        local camera = workspace.CurrentCamera
        local center = gameapi.Cursor()
        local world = util.WorldParams(util.Targets())

        for _, model in ipairs(util.Targets()) do
            local guarded = GuardCheck and GuardCheck.Enabled and model:GetAttribute('Blocking') == true
            if not guarded and gameapi.Valid(model, Targets) and not util.IsTeammate(model) then
                local part = model:FindFirstChild('HumanoidRootPart')
                if part and part:IsA('BasePart') then
                    local delta = part.Position - root.Position
                    if delta.Magnitude <= reach and math.abs(delta.Y) < 8 then
                        local clear = not workspace:Raycast(
                            source,
                            part.Position - source,
                            world
                        )

                        if clear then
                            local screenScore = math.huge
                            if camera then
                                local point, visible = camera:WorldToViewportPoint(part.Position)
                                if visible and point.Z > 0 then
                                    screenScore = (
                                        Vector2.new(point.X, point.Y) - center
                                    ).Magnitude
                                end
                            end

                            targets[#targets + 1] = {
                                model = model,
                                part = part,
                                distance = delta.Magnitude,
                                score = screenScore
                            }
                        end
                    end
                end
            end
        end

        table.sort(targets, function(a, b)
            if math.abs(a.distance - b.distance) < 0.1 then
                return a.score < b.score
            end
            return a.distance < b.distance
        end)

        local result = {}
        for i = 1, math.min(count, #targets) do
            result[i] = targets[i].model
        end
        return result
    end

    gameapi.Patch(melee, 'Input', function(original)
        return function(self, action, pressed, ...)
            if Killaura and Killaura.Enabled and action == 'Primary' then
                activeHandler = self
            end
            return original(self, action, pressed, ...)
        end
    end)

    gameapi.Patch(melee, 'Detect', function(original)
        return function(self, nativeReach, nativeArc, nativeMax)
            if not Killaura or not Killaura.Enabled
                or not focus or os.clock() > swingUntil
                or not self.ctx or not self.ctx.root then
                return original(self, nativeReach, nativeArc, nativeMax)
            end

            local limit = math.max(1, math.floor(Max.Value))
            local reach = math.min(
                Range.Value,
                (tonumber(nativeReach) or 8) + 1.2
            )
            return findTargets(self.ctx.root, reach, limit)
        end
    end)

    gameapi.Patch(util, 'FaceCamera', function(original)
        return function(...)
            if Killaura and Killaura.Enabled
                and FaceTarget and FaceTarget.Enabled
                and focus and focus.Parent
                and not options.AutoKilling then

                local _, _, kind = gameapi.Tool()
                if kind and combat.IsMelee(kind) then
                    return
                end
            end

            return original(...)
        end
    end)

    gameapi.Patch(util, 'GetAimRay', function(original)
        return function(...)
            local ray = original(...)
            if not Killaura or not Killaura.Enabled
                or not focus or not focus.Parent
                or os.clock() > swingUntil then
                return ray
            end

            local _, _, kind = gameapi.Tool()
            if not kind or not combat.IsMelee(kind) then return ray end

            local direction = focus.Position
                + focus.AssemblyLinearVelocity * 0.04
                - ray.Origin

            if direction.Magnitude < 0.01 then return ray end
            return Ray.new(ray.Origin, direction.Unit)
        end
    end)

    gameapi.Connect(runService.RenderStepped, function()
        local char = lplr.Character
        local root = char and char:FindFirstChild('HumanoidRootPart')
        local hum = char and char:FindFirstChildOfClass('Humanoid')
        local position = guardPosition and blocking and guardPosition

        if FaceTarget and FaceTarget.Enabled
            and focus and focus.Parent then
            position = focus.Position
        end

        if not Killaura or not Killaura.Enabled
            or not root or not hum
            or hum.Health <= 0 or not position then
            restoreRotate()
            return
        end

        if previousHumanoid ~= hum then
            restoreRotate()
            previousHumanoid, previousRotate = hum, hum.AutoRotate
        end

        hum.AutoRotate = false
        local flat = Vector3.new(position.X, root.Position.Y, position.Z)
        if (flat - root.Position).Magnitude > 0.1 then
            root.CFrame = CFrame.lookAt(root.Position, flat)
        end
    end)

    local net = require(sharedFolder:WaitForChild('Net'))

    local function combatEvent(action, payload)
        if not Killaura or not Killaura.Enabled
            or not AutoBlock.Enabled or type(payload) ~= 'table' then
            return
        end

        if action == 'Swing' and BlockMelee.Enabled then
            local attacker = payload.attacker
            if typeof(attacker) ~= 'Instance' then return end
            if attacker:IsA('Player') then attacker = attacker.Character end
            if not gameapi.Valid(attacker, Targets)
                or util.IsTeammate(attacker) then
                return
            end

            local root = lplr.Character
                and lplr.Character:FindFirstChild('HumanoidRootPart')
            local enemyRoot = attacker:FindFirstChild('HumanoidRootPart')
            if not root or not enemyRoot then return end

            local held = attacker:FindFirstChildOfClass('Tool')
            local id = held and held:GetAttribute('WeaponId')
            local tune = type(id) == 'string' and combat.Tuning(id)
            local reach = tonumber(tune and tune.range) or 8
            local displacement = root.Position - enemyRoot.Position

            if displacement.Magnitude > reach + 2 then return end
            local horizontal = Vector3.new(
                displacement.X, 0, displacement.Z
            )
            if horizontal.Magnitude < 0.1 then return end

            local facing = enemyRoot.CFrame.LookVector
                * Vector3.new(1, 0, 1)

            if facing.Magnitude > 0.1
                and facing.Unit:Dot(horizontal.Unit) < 0.1 then
                return
            end

            guardPosition = enemyRoot.Position
            guardUntil = math.max(guardUntil, os.clock() + 0.18)

        elseif action == 'Projectile' and BlockProjectiles.Enabled then
            if typeof(payload.origin) ~= 'Vector3'
                or typeof(payload.velocity) ~= 'Vector3' then
                return
            end
            if payload.velocity.Magnitude < 1 then return end

            local attacker = payload.shooter
            if typeof(attacker) ~= 'Instance' then return end
            if attacker:IsA('Player') then attacker = attacker.Character end
            if not gameapi.Valid(attacker, Targets)
                or util.IsTeammate(attacker) then
                return
            end

            local key = type(payload.key) == 'string'
                and payload.key or tostring(os.clock())

            projectiles[key] = {
                start = payload.origin,
                velocity = payload.velocity,
                gravity = tonumber(payload.gravity) or 0,
                seen = os.clock()
            }
        end
    end

    gameapi.Connect(
        net.Event('CombatFX').OnClientEvent,
        combatEvent
    )
    gameapi.Connect(
        net.UnreliableEvent('CombatFXU').OnClientEvent,
        combatEvent
    )

    local function approachingProjectile(root)
        local now = os.clock()
        local playerPosition = root.Position + Vector3.new(0, 1, 0)

        for key, shot in pairs(projectiles) do
            local age = now - shot.seen
            if age > 2 or age < 0 then
                projectiles[key] = nil
            else
                local current = shot.start + shot.velocity * age
                    - Vector3.new(0, shot.gravity * age * age * 0.5, 0)

                local motion = shot.velocity
                    - Vector3.new(0, shot.gravity * age, 0)

                local time = (playerPosition - current):Dot(motion)
                    / math.max(motion:Dot(motion), 1)

                if time > 0 and time < 0.3 then
                    local impact = current + motion * time
                        - Vector3.new(
                            0, shot.gravity * time * time * 0.5, 0
                        )

                    local moved = playerPosition
                        + root.AssemblyLinearVelocity * math.min(time, 0.12)

                    if (impact - moved).Magnitude <= 4
                        and not workspace:Raycast(
                            current,
                            impact - current,
                            util.WorldParams(util.Targets())
                        ) then
                        guardPosition = current
                        guardUntil = math.max(
                            guardUntil,
                            now + time + 0.07
                        )
                        return true
                    end
                end
            end
        end

        return false
    end

    Killaura = vape.Categories.Blatant:CreateModule({
        Name = 'Killaura',
        Function = function(enabled)
            generation += 1
            local token = generation

            if not enabled then
                setPrimary(false)
                setGuard(false)
                focus, swingUntil, activeHandler, activeTool =
                    nil, 0, nil, nil
                guardUntil, guardPosition = 0, nil
                table.clear(projectiles)
                restoreRotate()
                return
            end

            task.spawn(function()
                while Killaura.Enabled and token == generation do
                    local ok, err = pcall(function()
                        if options.AutoKilling or options.AutoSpecial
                            or not util.CanAct() then
                            focus = nil
                            setPrimary(false)
                            setGuard(false)
                            return
                        end

                        local tool, _, kind, tuning = gameapi.Tool()
                        local char = lplr.Character
                        local root = char
                            and char:FindFirstChild('HumanoidRootPart')

                        if not kind or not combat.IsMelee(kind)
                            or not tuning or not root then
                            focus = nil
                            setPrimary(false)
                            setGuard(false)
                            return
                        end

                        if activeTool ~= tool then
                            activeTool = tool
                            activeHandler = nil
                            holding, blocking = false, false
                        end

                        local nativeReach = tonumber(tuning.range) or 8
                        local attackReach = math.min(
                            Range.Value,
                            nativeReach + 1.2
                        )
                        local trackingReach = math.min(
                            Range.Value,
                            nativeReach + 5
                        )

                        local models = findTargets(
                            root,
                            trackingReach,
                            math.max(1, math.floor(Max.Value))
                        )

                        local first = models[1]
                        local part = first
                            and first:FindFirstChild('HumanoidRootPart')

                        local ready = true
                        if activeHandler and activeHandler.ctx
                            and activeHandler.ctx.tool == tool
                            and type(activeHandler.Ready) == 'function' then
                            ready = activeHandler:Ready()
                        end

                        local now = os.clock()
                        if AutoBlock.Enabled and tuning.block then
                            if BlockProjectiles.Enabled
                                and (tonumber(tuning.block.ranged) or 0) > 0 then
                                approachingProjectile(root)
                            end

                            local danger = now < guardUntil
                            if danger and (not first or not ready) then
                                setPrimary(false)
                                setGuard(true)
                                return
                            end
                        end

                        setGuard(false)

                        focus = part

                        if part and (part.Position - root.Position).Magnitude
                            <= attackReach then

                            local hitDelay = tonumber(
                                activeHandler
                                and activeHandler.preset
                                and activeHandler.preset.hitDelay
                            ) or tonumber(tuning.hitDelay) or 0.1

                            swingUntil = now + hitDelay + 0.25
                            setPrimary(true)
                        else
                            swingUntil = 0
                            setPrimary(false)
                        end
                    end)

                    if not ok then
                        setPrimary(false)
                        setGuard(false)
                        focus = nil
                        warn('killaura: ' .. tostring(err))
                    end

                    task.wait(0.025)
                end

                setPrimary(false)
                setGuard(false)
                focus = nil
                restoreRotate()
            end)
        end,
        Tooltip = 'attacks nearby enemies with native melee swings'
    })

    Targets = Killaura:CreateTargets({
        Players = true,
        NPCs = true,
        Walls = true
    })

    Range = Killaura:CreateSlider({
        Name = 'range',
        Min = 1,
        Max = 14,
        Default = 14
    })

    Max = Killaura:CreateSlider({
        Name = 'max targets',
        Min = 1,
        Max = 10,
        Default = 10
    })

    FaceTarget = Killaura:CreateToggle({
        Name = 'face target',
        Default = true
    })

    GuardCheck = Killaura:CreateToggle({
        Name = 'guard check',
        Tooltip = 'waits for enemies to drop their block before swinging at em'
    })

    AutoBlock = Killaura:CreateToggle({
        Name = 'auto block',
        Function = function(enabled)
            if BlockMelee then
                BlockMelee.Object.Visible = enabled
            end
            if BlockProjectiles then
                BlockProjectiles.Object.Visible = enabled
            end

            if not enabled then
                guardUntil, guardPosition = 0, nil
                setGuard(false)
                table.clear(projectiles)
            end
        end
    })

    BlockMelee = Killaura:CreateToggle({
        Name = 'melee',
        Default = true
    })

    BlockProjectiles = Killaura:CreateToggle({
        Name = 'projectiles',
        Default = true
    })

    BlockMelee.Object.Visible = AutoBlock.Enabled
    BlockProjectiles.Object.Visible = AutoBlock.Enabled
end)


run(function()
    local TriggerBot, Targets, Range, Melees, Projectiles, Cps
    local token = 0
    local releaseAt = 0
    local firedAt = 0
    local held = false
    local currentTool

    local function stop()
        if held then
            gameapi.Primary('TriggerBot', false)
            held = false
        end
        currentTool = nil
        releaseAt = 0
    end

    local function aimedTarget(maxDistance)
        local ray = util.GetAimRay()
        if typeof(ray) ~= 'Ray' or ray.Direction.Magnitude < 0.001 then return nil end
        local hit = workspace:Raycast(
            ray.Origin,
            ray.Direction.Unit * maxDistance,
            util.WorldParams()
        )
        if not hit then return nil end
        local model = hit.Instance:FindFirstAncestorOfClass('Model')
        while model and not model:FindFirstChildOfClass('Humanoid') do
            model = model.Parent and model.Parent:FindFirstAncestorOfClass('Model')
        end
        if model and gameapi.Valid(model, Targets) and not util.IsTeammate(model) then
            return model
        end
        return nil
    end

    TriggerBot = vape.Categories.Combat:CreateModule({
        Name = 'TriggerBot',
        Function = function(enabled)
            token += 1
            local generation = token
            stop()
            if not enabled then return end
            task.spawn(function()
                while TriggerBot.Enabled and token == generation do
                    local now = os.clock()
                    local tool, _, kind, tuning = gameapi.Tool()
                    local meleeWeapon = kind and combat.IsMelee(kind)
                    local range = Range.Value
                    local compatible = kind and tuning
                        and ((meleeWeapon and Melees.Enabled)
                            or (not meleeWeapon and Projectiles.Enabled and combat.FiresProjectile(kind)))
                    if held and (now >= releaseAt or tool ~= currentTool
                        or not compatible or not util.CanAct()) then
                        stop()
                    end
                    if compatible and util.CanAct() and not options.AutoKilling
                        and not held and now >= firedAt
                        and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        and aimedTarget(range) then
                        local waiting = math.max(1 / math.max(Cps.Value, 1),
                            tonumber(tuning.cooldown) or tonumber(tuning.fireInterval) or 0.2)
                        local duration = (combat.IsDrawn(kind) or kind == 'Javelin' or kind == 'Bomb')
                            and math.max(0.12, tonumber(tuning.drawTime) or 0.5) + 0.04 or 0.055
                        if gameapi.Primary('TriggerBot', true) then
                            held = true
                            currentTool = tool
                            releaseAt = now + duration
                            firedAt = now + math.max(waiting, duration)
                        end
                    end
                    task.wait(0.025)
                end
                stop()
            end)
        end,
        Tooltip = 'fires when ur crosshair points at an enemy'
    })
    Targets = TriggerBot:CreateTargets({Players = true, NPCs = true})
    Range = TriggerBot:CreateSlider({Name = 'range', Min = 1, Max = 300, Default = 80})
    Melees = TriggerBot:CreateToggle({Name = 'melees', Default = true})
    Projectiles = TriggerBot:CreateToggle({Name = 'projectiles', Default = true})
    Cps = TriggerBot:CreateSlider({Name = 'cps', Min = 1, Max = 15, Default = 5})
    TriggerBot:Clean(stop)
end)


run(function()
    local NoSlowdown
    local simulation = require(sharedFolder:WaitForChild('Simulation'))
    local humanoid
    local attributeConnection
    local applying = false

    local affectedInputs = {
        Aim = true,
        Charge = true,
        Block = true,
        Reload = true,
        Use = true
    }

    gameapi.Patch(combat, 'MoveSpeed', function(original)
        return function(id, aiming, charging, blocking, reloading, using)
            if not options.NoSlowdown then
                return original(id, aiming, charging, blocking, reloading, using)
            end

            local base = original(id, false, false, false, false, false)
            return math.max(1, tonumber(base) or 1), false
        end
    end)

    gameapi.Patch(simulation, 'SetInput', function(original)
        return function(name, value, ...)
            if options.NoSlowdown and affectedInputs[name] then
                return original(name, false, ...)
            end

            return original(name, value, ...)
        end
    end)

    local function neutralize()
        if not options.NoSlowdown or not humanoid
            or not humanoid.Parent or applying then
            return
        end

        applying = true

        for name, value in pairs(humanoid:GetAttributes()) do
            if type(name) == 'string'
                and name:sub(1, 9) == 'SpeedMult'
                and type(value) == 'number'
                and value >= 0 and value < 1 then
                humanoid:SetAttribute(name, 1)
            end
        end

        applying = false
    end

    local function detach()
        if attributeConnection then
            attributeConnection:Disconnect()
            attributeConnection = nil
        end

        humanoid = nil
    end

    local function attach(char)
        detach()

        if not options.NoSlowdown or not char then return end

        humanoid = char:FindFirstChildOfClass('Humanoid')
            or char:WaitForChild('Humanoid', 5)

        if not humanoid then return end

        attributeConnection = humanoid.AttributeChanged:Connect(function()
            neutralize()
        end)

        neutralize()
    end

    gameapi.Connect(lplr.CharacterAdded, function(char)
        if options.NoSlowdown then
            task.defer(function()
                if options.NoSlowdown then
                    attach(char)
                end
            end)
        end
    end)

    NoSlowdown = vape.Categories.Blatant:CreateModule({
        Name = 'NoSlowdown',
        Function = function(enabled)
            options.NoSlowdown = enabled

            if enabled then
                for name in pairs(affectedInputs) do
                    simulation.SetInput(name, false)
                end

                attach(lplr.Character)
            else
                detach()
            end
        end,
        Tooltip = 'reduces weapon and hit slowdown'
    })

    NoSlowdown:Clean(function()
        options.NoSlowdown = false
        detach()
    end)
end)

run(function()
    local TrapESP
    local folder = Instance.new('Folder')
    folder.Name = 'tribes trap esp'
    folder.Parent = workspace.CurrentCamera
    guiObjects[#guiObjects + 1] = folder
    local highlighted = {}
    local added

    local function clear()
        if added then
            added:Disconnect()
            added = nil
        end
        for part, glow in pairs(highlighted) do
            glow:Destroy()
            highlighted[part] = nil
        end
    end

    local function inspect(obj)
        if not (obj:IsA('Model') or obj:IsA('BasePart')) then return end
        local name = obj.Name:lower()
        if not name:find('snaptrap', 1, true) and not name:find('snap trap', 1, true) then return end
        if highlighted[obj] then return end
        local glow = Instance.new('Highlight')
        glow.Name = 'trap warning'
        glow.Adornee = obj
        glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        glow.FillColor = Color3.fromRGB(255, 105, 65)
        glow.FillTransparency = 0.65
        glow.OutlineColor = Color3.fromRGB(255, 150, 90)
        glow.Parent = folder
        highlighted[obj] = glow
    end

    TrapESP = vape.Categories.Render:CreateModule({
        Name = 'TrapESP',
        Function = function(enabled)
            if not enabled then clear() return end
            clear()
            for _, obj in ipairs(workspace:GetDescendants()) do
                inspect(obj)
            end
            added = workspace.DescendantAdded:Connect(inspect)
        end,
        Tooltip = 'highlights snap traps so you can avoid em'
    })
    gameapi.RestoreTrapESP = clear
end)

run(function()
    gameapi.StatSpoof('StreakSpoof', 'Streak', false)
end)

run(function()
    gameapi.StatSpoof('LevelSpoof', 'Level', true)
end)

run(function()
    local AntiSmoke

    gameapi.Patch(effects, 'SmokeCloud', function(original)
        return function(...)
            if AntiSmoke and AntiSmoke.Enabled then
                return
            end

            return original(...)
        end
    end)

    gameapi.Patch(combat, 'SmokeBlocks', function(original)
        return function(...)
            if AntiSmoke and AntiSmoke.Enabled then
                return false
            end

            return original(...)
        end
    end)

    local function clearSmoke()
        local fx = workspace:FindFirstChild('FX')
        if not fx then return end

        for _, object in ipairs(fx:GetChildren()) do
            if object:IsA('BasePart')
                and object.Name == 'PuffFX'
                and object:FindFirstChild('Body')
                and object:FindFirstChild('Low') then

                object:Destroy()
            end
        end
    end

    AntiSmoke = vape.Categories.Render:CreateModule({
        Name = 'AntiSmoke',
        Function = function(enabled)
            if enabled then
                clearSmoke()
            end
        end,
        Tooltip = 'hides smoke clouds so u can see through em'
    })
end)

run(function()
    local AutoKill
    local target
    local held = false
    local generation = 0
    local nextEquip = 0
    local equippedReadyAt = 0
    local oldHumanoid
    local oldAutoRotate
    local nextSearch = 0

    local function attack(enabled)
        if held == enabled then return end
        if enabled then
            held = gameapi.Primary('AutoKill', true)
        else
            gameapi.Primary('AutoKill', false)
            held = false
        end
    end

    local function enemy(model)
        return model and gameapi.Valid(model) and not util.IsTeammate(model)
    end

    local function nearest(root)
        local best, bestDistance
        for _, model in ipairs(util.Targets()) do
            if enemy(model) then
                local part = model:FindFirstChild('HumanoidRootPart')
                if part then
                    local distance = (part.Position - root.Position).Magnitude
                    if not bestDistance or distance < bestDistance then
                        best, bestDistance = model, distance
                    end
                end
            end
        end
        return best
    end

    local function strongest()
        local char = lplr.Character
        local backpack = lplr:FindFirstChildOfClass('Backpack')
        local best, bestScore
        for _, container in ipairs({char, backpack}) do
            if container then
                for _, item in ipairs(container:GetChildren()) do
                    if item:IsA('Tool') then
                        local id = item:GetAttribute('WeaponId')
                        local kind = type(id) == 'string' and combat.Kind(id)
                        if kind and combat.IsMelee(kind) then
                            local tuning = combat.Tuning(id)
                            local dmg = tonumber(tuning and tuning.damage) or 0
                            local delay = math.max(tonumber(tuning and tuning.cooldown) or 0.5, 0.15)
                            local score = dmg * (tonumber(tuning and tuning.backstabMult) or 1) / delay
                            if not bestScore or score > bestScore then
                                best, bestScore = item, score
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    local function restoreRotate()
        if oldHumanoid and oldHumanoid.Parent then
            oldHumanoid.AutoRotate = oldAutoRotate
        end
        oldHumanoid = nil
        oldAutoRotate = nil
    end

    gameapi.Patch(util, 'GetAimRay', function(original)
        return function(...)
            local ray = original(...)
            if not AutoKill or not AutoKill.Enabled or not enemy(target) then return ray end
            local _, _, kind = gameapi.Tool()
            if not kind or not combat.IsMelee(kind) then return ray end
            local part = target:FindFirstChild('HumanoidRootPart')
            if not part then return ray end
            local aim = part.Position + part.AssemblyLinearVelocity * 0.04 - ray.Origin
            return aim.Magnitude > 0.01 and Ray.new(ray.Origin, aim.Unit) or ray
        end
    end)

    gameapi.Patch(util, 'FaceCamera', function(original)
        return function(...)
            if AutoKill and AutoKill.Enabled and enemy(target) then return end
            return original(...)
        end
    end)

    gameapi.Patch(melee, 'Detect', function(original)
        return function(self, nativeRange, nativeArc, maxTargets)
            if not AutoKill or not AutoKill.Enabled then
                return original(self, nativeRange, nativeArc, maxTargets)
            end
            if not enemy(target) or not self.ctx or not self.ctx.root then return {} end
            local part = target:FindFirstChild('HumanoidRootPart')
            if not part then return {} end
            local root = self.ctx.root
            local delta = part.Position - root.Position
            if delta.Magnitude > (tonumber(nativeRange) or 8) + 1.2
                or math.abs(delta.Y) >= 8 then return {} end
            local head = self.ctx.char and self.ctx.char:FindFirstChild('Head')
            local origin = head and head.Position or root.Position
            if workspace:Raycast(origin, part.Position - origin, util.WorldParams(util.Targets())) then
                return {}
            end
            return {target}
        end
    end)

    local function follow()
        if not AutoKill or not AutoKill.Enabled then return end
        if options.AntiHitDodgeUntil and os.clock() < options.AntiHitDodgeUntil then return end

        local char = lplr.Character
        local root = char and char:FindFirstChild('HumanoidRootPart')
        local humanoid = char and char:FindFirstChildOfClass('Humanoid')
        if not root or not humanoid or humanoid.Health <= 0 or not util.CanAct() then
            target = nil
            attack(false)
            restoreRotate()
            return
        end
        if not enemy(target) or not target:FindFirstChild('HumanoidRootPart') then
            target = nil
            attack(false)
            if os.clock() >= nextSearch then
                nextSearch = os.clock() + 0.15
                target = nearest(root)
            end
        end
        local part = target and target:FindFirstChild('HumanoidRootPart')
        if not part then restoreRotate() return end
        if oldHumanoid ~= humanoid then
            restoreRotate()
            oldHumanoid = humanoid
            oldAutoRotate = humanoid.AutoRotate
        end
        humanoid.AutoRotate = false
        local look = part.CFrame.LookVector
        local horizontal = Vector3.new(look.X, 0, look.Z)
        if horizontal.Magnitude < 0.01 then return end
        local back = part.Position - horizontal.Unit * 2.8
        local position = Vector3.new(back.X, part.Position.Y, back.Z)
        root.CFrame = CFrame.lookAt(position,
            Vector3.new(part.Position.X, position.Y, part.Position.Z))
    end

    AutoKill = vape.Categories.Blatant:CreateModule({
        Name = 'AutoKill',
        Function = function(enabled)
            generation += 1
            local token = generation
            options.AutoKilling = enabled
            attack(false)
            if not enabled then
                target = nil
                restoreRotate()
                return
            end
            task.spawn(function()
                while AutoKill.Enabled and generation == token do
                    local ok, err = pcall(function()
                        local char = lplr.Character
                        local root = char and char:FindFirstChild('HumanoidRootPart')
                        local humanoid = char and char:FindFirstChildOfClass('Humanoid')
                        if not root or not humanoid or humanoid.Health <= 0 or not util.CanAct() then
                            attack(false)
                            return
                        end
                        local part = target and target:FindFirstChild('HumanoidRootPart')
                        local best = strongest()
                        if not part or not enemy(target) or not best then
                            attack(false)
                            return
                        end
                        local equipped, _, kind, tuning, state = gameapi.Tool()
                        if equipped ~= best then
                            attack(false)
                            local controllerState = controller.State()
                            if controllerState and not controllerState.equipPending
                                and os.clock() >= nextEquip then
                                nextEquip = os.clock() + 0.5
                                controller.Equip(best)
                                equippedReadyAt = os.clock() + 0.2
                            end
                            return
                        end
                        if not kind or not combat.IsMelee(kind) or not tuning
                            or (state and state.equipPending) or os.clock() < equippedReadyAt then
                            attack(false)
                            return
                        end
                        if (part.Position - root.Position).Magnitude >
                            (tonumber(tuning.range) or 8) + 0.7 then
                            attack(false)
                            return
                        end
                        attack(true)
                    end)
                    if not ok then
                        attack(false)
                        warn('autokill: ' .. tostring(err))
                    end
                    task.wait(0.04)
                end
                attack(false)
                if generation == token then options.AutoKilling = false end
                restoreRotate()
            end)
        end,
        Tooltip = 'sticks behind the nearest enemy n attacks with ur best melee'
    })

    AutoKill:Clean(function()
        attack(false)
        target = nil
        options.AutoKilling = false
        restoreRotate()
    end)

    gameapi.Connect(runService.Heartbeat, follow)
end)

run(function()
    local Aimbot, Targets, Range, Fov, ShowFov, AimSpeed, Melee, Projectiles, PriorityMode
    local locked
    local lookLocked = false
    local bindName = 'tribes aimbot lock'
    local cameraApi = util.Camera() or require(sharedFolder:WaitForChild('Camera'))
    local ui = lplr:WaitForChild('PlayerGui')
    local old = ui:FindFirstChild('tribes aimbot fov')
    if old then old:Destroy() end

    local overlay = Instance.new('ScreenGui')
    overlay.Name = 'tribes aimbot fov'
    overlay.IgnoreGuiInset = true
    overlay.ResetOnSpawn = false
    overlay.DisplayOrder = 501
    overlay.Parent = ui
    guiObjects[#guiObjects + 1] = overlay

    local circle = Instance.new('Frame')
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.BackgroundTransparency = 1
    circle.BorderSizePixel = 0
    circle.Visible = false
    circle.Parent = overlay

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = circle

    local stroke = Instance.new('UIStroke')
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Parent = circle

    local function eligible(model, root, camera, center, retained)
        if not gameapi.Valid(model, Targets) or util.IsTeammate(model) then return nil end
        local head = model:FindFirstChild('Head')
        if not head or not head:IsA('BasePart') then return nil end
        if (head.Position - root.Position).Magnitude > Range.Value then return nil end
        local screen, visible = camera:WorldToViewportPoint(head.Position)
        if not visible or screen.Z <= 0 then return nil end
        local pixels = (Vector2.new(screen.X, screen.Y) - center).Magnitude
        if pixels > Fov.Value then return nil end
        if Targets.Walls.Enabled and not gameapi.Clear(camera.CFrame.Position, head.Position, model) then
            return nil
        end
        return head, pixels
    end

    local function releaseLook()
        if lookLocked then
            cameraApi.PopLookLock(bindName)
            lookLocked = false
        end
    end

    local function update(dt)
        if not Aimbot.Enabled then
            releaseLook()
            return
        end
        local camera = workspace.CurrentCamera
        if not camera then return end
        local center = inputService.MouseBehavior == Enum.MouseBehavior.LockCenter
            and camera.ViewportSize * 0.5 or gameapi.Cursor()

        circle.Visible = ShowFov.Enabled
        circle.Position = UDim2.fromOffset(center.X, center.Y)
        circle.Size = UDim2.fromOffset(Fov.Value * 2, Fov.Value * 2)

        if options.AutoKilling then
            locked = nil
            releaseLook()
            return
        end
        local char = lplr.Character
        local root = char and char:FindFirstChild('HumanoidRootPart')
        local hum = char and char:FindFirstChildOfClass('Humanoid')
        if not root or not hum or hum.Health <= 0 then
            locked = nil
            releaseLook()
            return
        end
        local tool, _, kind, tuning = gameapi.Tool()
        local allowed = kind and ((Melee.Enabled and combat.IsMelee(kind))
            or (Projectiles.Enabled and combat.FiresProjectile(kind)))
        if not allowed then
            locked = nil
            releaseLook()
            return
        end

        local head

        if PriorityMode.Enabled and locked then
            head = eligible(locked, root, camera, center, true)
        end

        if not head then
            locked = nil

            local closest = Fov.Value

            for _, model in ipairs(util.Targets()) do
                local part, pixels = eligible(model, root, camera, center, false)

                if part and pixels < closest then
                    closest = pixels
                    locked = model
                    head = part
                end
            end
        end
        if not head then
            releaseLook()
            return
        end
        if not lookLocked then
            cameraApi.PushLookLock(bindName)
            lookLocked = true
        end
        local current = camera.CFrame
        local aimPoint = head.Position
        if tool and combat.FiresProjectile(kind) then
            local origin = util.ShotOrigin(tool, 'Muzzle')
            local shot = gameapi.ShotProfile(tool, kind, tuning)
            if typeof(origin) == 'Vector3' and shot then
                local predicted = gameapi.Aim(origin, head, shot.speed, shot.gravity, false)
                if predicted then
                    aimPoint = origin + predicted * (head.Position - origin).Magnitude
                end
            end
        end
        local delta = aimPoint - current.Position
        if delta.Magnitude < 0.01 then return end

        local wanted = CFrame.lookAt(current.Position, aimPoint)
        local alpha = 1 - math.exp(
            -AimSpeed.Value * math.clamp(dt, 0, 0.1) * 4.5
        )

        local result = current:Lerp(wanted, alpha)
        camera.CFrame = result

        local direction = result.LookVector
        cameraApi.SetLook(
            math.atan2(-direction.X, -direction.Z),
            math.asin(math.clamp(direction.Y, -1, 1))
        )
    end

    Aimbot = vape.Categories.Combat:CreateModule({
        Name = 'Aimbot',
        Function = function(enabled)
            runService:UnbindFromRenderStep(bindName)
            locked = nil
            releaseLook()
            circle.Visible = false
            if enabled then
                runService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 2, update)
            end
        end,
        Tooltip = 'locks ur aim onto nearby enemy heads'
    })

    Aimbot:Clean(function()
        runService:UnbindFromRenderStep(bindName)
        locked = nil
        releaseLook()
        circle.Visible = false
    end)

    Targets = Aimbot:CreateTargets({Players = true, NPCs = true, Walls = true})
    Range = Aimbot:CreateSlider({Name = 'range', Min = 1, Max = 150, Default = 100})
    Fov = Aimbot:CreateSlider({Name = 'fov', Min = 10, Max = 500, Default = 120})
    AimSpeed = Aimbot:CreateSlider({Name = 'aim speed', Min = 1, Max = 20, Default = 8})
    ShowFov = Aimbot:CreateToggle({Name = 'show fov', Default = true})

    PriorityMode = Aimbot:CreateToggle({
        Name = 'priority mode',
        Default = false,
        Function = function()
            locked = nil
        end,
        Tooltip = 'stays on the same enemy till they die or leave ur fov'
    })

    Melee = Aimbot:CreateToggle({Name = 'melee', Default = true})
    Projectiles = Aimbot:CreateToggle({Name = 'projectiles', Default = true})
end)


run(function()
    local Speed, Mode, MoveMethod, Value, WallCheck, TPFrequency, PulseLength, PulseDelay
    local AutoJump, CustomJump, JumpPower, Intermission
    local modes = {'Velocity', 'Impulse', 'CFrame', 'TP', 'WalkSpeed', 'Pulse'}
    local nextTeleport = 0
    local initialHumanoid
    local initialWalkSpeed
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide = true

    local ui = lplr:WaitForChild('PlayerScripts'):WaitForChild('UI')
    local state = require(ui:WaitForChild('State'))

    local function restoreWalkSpeed()
        if initialHumanoid and initialHumanoid.Parent and initialWalkSpeed then
            if initialHumanoid.WalkSpeed == Value.Value then
                initialHumanoid.WalkSpeed = initialWalkSpeed
            end
        end
        initialHumanoid = nil
        initialWalkSpeed = nil
    end

    local function directMove()
        if inputService:GetFocusedTextBox() then return Vector3.zero end
        local x = (inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
            - (inputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
        local z = (inputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
            - (inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
        local camera = workspace.CurrentCamera
        if not camera then return Vector3.zero end
        local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
        local right = camera.CFrame.RightVector * Vector3.new(1, 0, 1)
        if look.Magnitude < 0.01 or right.Magnitude < 0.01 then return Vector3.zero end
        local vector = look.Unit * z + right.Unit * x
        return vector.Magnitude > 1 and vector.Unit or vector
    end

    local function moveCFrame(root, hum, direction, dt)
        local offset = direction * math.max(Value.Value - hum.WalkSpeed, 0) * dt
        if offset.Magnitude <= 0.0001 then return end
        if WallCheck.Enabled then
            local camera = workspace.CurrentCamera
            rayParams.FilterDescendantsInstances = camera and {lplr.Character, camera} or {lplr.Character}
            rayParams.CollisionGroup = root.CollisionGroup
            local hit = workspace:Raycast(root.Position, offset, rayParams)
            if hit then
                local step = hit.Position - root.Position - offset.Unit * 0.4
                if step:Dot(offset) <= 0 then return end
                offset = step
            end
        end
        root.CFrame += offset
    end

    local function setVisible()
        if not (Mode and WallCheck and TPFrequency and PulseLength and PulseDelay) then return end
        local mode = Mode.Value
        WallCheck.Object.Visible = mode == 'CFrame' or mode == 'TP'
        TPFrequency.Object.Visible = mode == 'TP'
        PulseLength.Object.Visible = mode == 'Pulse'
        PulseDelay.Object.Visible = mode == 'Pulse'
    end

    local function update(dt)
        if not Speed.Enabled then return end
        local modules = vape.Modules
        if options.AutoKilling or (modules and (
            modules.PlayerAttach and modules.PlayerAttach.Enabled
            or modules.Fly and modules.Fly.Enabled
            or modules.LongJump and modules.LongJump.Enabled
        )) then return end
        if Intermission.Enabled and state.InMatch() then
            local phase = state.Phase()
            if not phase then phase = state.PhaseClock() end
            if phase == 'Intro' or phase == 'PreRound' or phase == 'RoundEnd'
                or phase == 'MatchEnd' then
                restoreWalkSpeed()
                return
            end
        end

        local char = lplr.Character
        local root = char and char:FindFirstChild('HumanoidRootPart')
        local hum = char and char:FindFirstChildOfClass('Humanoid')
        if not root or not hum or hum.Health <= 0 then return end
        if hum:GetState() == Enum.HumanoidStateType.Climbing then return end
        if hum:GetState() == Enum.HumanoidStateType.Seated then return end

        local direction = MoveMethod.Value == 'Direct' and directMove() or hum.MoveDirection
        direction *= Vector3.new(1, 0, 1)
        if direction.Magnitude > 1 then direction = direction.Unit end

        local mode = Mode.Value
        local vertical = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
        local targetVelocity = direction * Value.Value

        if mode == 'Velocity' then
            root.AssemblyLinearVelocity = targetVelocity + vertical
        elseif mode == 'Impulse' then
            local difference = (targetVelocity - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
            if difference.Magnitude > (direction == Vector3.zero and 10 or 2) then
                root:ApplyImpulse(difference * root.AssemblyMass)
            end
        elseif mode == 'CFrame' then
            moveCFrame(root, hum, direction, dt)
        elseif mode == 'TP' then
            if os.clock() >= nextTeleport then
                nextTeleport = os.clock() + TPFrequency.Value
                moveCFrame(root, hum, direction, 1)
            end
        elseif mode == 'WalkSpeed' then
            if initialHumanoid ~= hum then
                initialHumanoid = hum
                initialWalkSpeed = hum.WalkSpeed
            end
            hum.WalkSpeed = Value.Value
        elseif mode == 'Pulse' then
            local length = math.max(0.05, PulseLength.Value)
            local delay = math.max(0, PulseDelay.Value)
            local phase = (os.clock() % (length + delay)) / length
            local bonus = math.max(Value.Value - hum.WalkSpeed, 0)
                * (1 - math.min(phase, 1))
            root.AssemblyLinearVelocity = direction * (hum.WalkSpeed + bonus) + vertical
        end

        if AutoJump.Enabled and direction.Magnitude > 0.05
            and hum.FloorMaterial ~= Enum.Material.Air then
            if CustomJump.Enabled then
                local v = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(v.X, JumpPower.Value, v.Z)
            else
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end

    Speed = vape.Categories.Blatant:CreateModule({
        Name = 'Speed',
        Function = function(enabled)
            if not enabled then
                restoreWalkSpeed()
                return
            end
            nextTeleport = 0
            Speed:Clean(runService.PreSimulation:Connect(update))
        end,
        ExtraText = function()
            return Mode.Value
        end,
        Tooltip = 'moves faster with different methods'
    })

    Mode = Speed:CreateDropdown({
        Name = 'mode',
        List = modes,
        Function = function()
            restoreWalkSpeed()
            setVisible()
        end
    })
    MoveMethod = Speed:CreateDropdown({Name = 'move mode', List = {'MoveDirection', 'Direct'}})
    Value = Speed:CreateSlider({Name = 'speed', Min = 1, Max = 150, Default = 50})
    WallCheck = Speed:CreateToggle({Name = 'wall check', Default = true, Darker = true, Visible = false})
    TPFrequency = Speed:CreateSlider({Name = 'tp frequency', Min = 0, Max = 1, Decimal = 100, Default = 0.3, Darker = true, Visible = false})
    PulseLength = Speed:CreateSlider({Name = 'pulse length', Min = 0.05, Max = 1, Decimal = 100, Default = 0.3, Darker = true, Visible = false})
    PulseDelay = Speed:CreateSlider({Name = 'pulse delay', Min = 0, Max = 1, Decimal = 100, Default = 0.3, Darker = true, Visible = false})
    AutoJump = Speed:CreateToggle({Name = 'auto jump', Function = function(enabled)
        if CustomJump then CustomJump.Object.Visible = enabled end
        if JumpPower then JumpPower.Object.Visible = enabled and CustomJump and CustomJump.Enabled end
    end})
    CustomJump = Speed:CreateToggle({Name = 'custom jump', Darker = true, Visible = false, Function = function(enabled)
        JumpPower.Object.Visible = enabled and AutoJump.Enabled
    end})
    JumpPower = Speed:CreateSlider({Name = 'jump power', Min = 1, Max = 50, Default = 30, Darker = true, Visible = false})
    Intermission = Speed:CreateToggle({Name = 'intermission', Default = true,
        Tooltip = 'waits for the round to start before speed works'})
    setVisible()
end)

run(function()
    local PlayerAttach, Range
    local target
    local nextScan = 0

    local function enemy(model)
        return gameapi.Valid(model) and not util.IsTeammate(model)
    end

    local function closest(root)
        local selected
        local nearest = Range.Value

        for _, model in ipairs(util.Targets()) do
            if enemy(model) then
                local part = model:FindFirstChild('HumanoidRootPart')
                if part then
                    local distance = (part.Position - root.Position).Magnitude
                    if distance <= nearest then
                        nearest = distance
                        selected = model
                    end
                end
            end
        end

        return selected
    end

    gameapi.Patch(util, 'GetAimRay', function(original)
        return function(...)
            local ray = original(...)
            if not PlayerAttach or not PlayerAttach.Enabled or not enemy(target)
                or options.AutoKilling then
                return ray
            end

            local _, _, kind = gameapi.Tool()
            if not kind or not combat.IsMelee(kind) then
                return ray
            end

            local part = target:FindFirstChild('HumanoidRootPart')
            if not part then return ray end

            local direction = part.Position - ray.Origin
            if direction.Magnitude <= 0.01 then return ray end

            return Ray.new(ray.Origin, direction.Unit)
        end
    end)

    gameapi.Patch(util, 'FaceCamera', function(original)
        return function(...)
            if PlayerAttach and PlayerAttach.Enabled and enemy(target)
                and not options.AutoKilling then
                return
            end
            return original(...)
        end
    end)

    gameapi.Connect(runService.Heartbeat, function()
        if not PlayerAttach or not PlayerAttach.Enabled then return end
        if options.AutoKilling then
            target = nil
            return
        end

        local char = lplr.Character
        local root = char and char:FindFirstChild('HumanoidRootPart')
        local hum = char and char:FindFirstChildOfClass('Humanoid')
        if not root or not hum or hum.Health <= 0 or not util.CanAct() then
            target = nil
            return
        end

        if target and not enemy(target) then
            target = nil
            nextScan = 0
        end

        if not target and os.clock() >= nextScan then
            nextScan = os.clock() + 0.15
            target = closest(root)
        end

        local enemyRoot = target and target:FindFirstChild('HumanoidRootPart')
        if not enemyRoot then return end

        local direction = enemyRoot.CFrame.LookVector
        local flat = Vector3.new(direction.X, 0, direction.Z)
        if flat.Magnitude <= 0.01 then return end

        local back = enemyRoot.Position - flat.Unit * 2.8
        local position = Vector3.new(back.X, enemyRoot.Position.Y, back.Z)
        local face = Vector3.new(enemyRoot.Position.X, position.Y, enemyRoot.Position.Z)

        root.CFrame = CFrame.lookAt(position, face)
    end)

    PlayerAttach = vape.Categories.Blatant:CreateModule({
        Name = 'PlayerAttach',
        Function = function(enabled)
            if not enabled then
                target = nil
                nextScan = 0
            end
        end,
        Tooltip = 'sticks behind the nearest enemy till they die'
    })

    Range = PlayerAttach:CreateSlider({Name = 'range', Min = 5, Max = 150, Default = 45})
end)


run(function()
    local AutoWin
    local ui = lplr:WaitForChild('PlayerScripts'):WaitForChild('UI')
    local state = require(ui:WaitForChild('State'))
    local queueApi = require(ui:WaitForChild('Remotes'))
    local remotes = replicatedStorage:WaitForChild('Remotes')
    local matchEvent = remotes:WaitForChild('MatchEvent')
    local generation = 0
    local lastQueueAt = -math.huge
    local lastQueueKey
    local queueBusy = false
    local matchFinished = false
    local replayWaitUntil = 0

    local function setAutoKill(enabled)
        local module = vape.Modules and vape.Modules.AutoKill
        if not module then return false end
        if module.Enabled ~= enabled then
            module:Toggle()
        end
        return true
    end

    local function queue(action, key, token)
        local now = os.clock()
        if queueBusy or now - lastQueueAt < 8 then return end
        if key == lastQueueKey and now - lastQueueAt < 15 then return end
        if state.Get('Queued') == true or lplr:GetAttribute('Teleporting') == true then return end

        queueBusy = true
        lastQueueAt = now
        task.spawn(function()
            local ok, transport, accepted = pcall(queueApi.Invoke, 'QueueAction', action)
            queueBusy = false
            if not AutoWin or not AutoWin.Enabled or generation ~= token then return end
            if ok and transport == true and accepted == true then
                lastQueueKey = key
            else
                warn('autowin: queue failed: ' .. action)
            end
        end)
    end

    local function endMatch(token)
        if not AutoWin or not AutoWin.Enabled or generation ~= token then return end
        setAutoKill(false)
        matchFinished = true
        replayWaitUntil = os.clock() + 12

        local match = state.Match
        local id = match and match.matchId or state.SeenMatchId()
        local key = 'play:' .. tostring(id or 'last')

        task.delay(0.25, function()
            if AutoWin and AutoWin.Enabled and generation == token then
                queue('PlayAgain', key, token)
            end
        end)
    end

    gameapi.Connect(matchEvent.OnClientEvent, function(event)
        if event == 'MatchEnd' and AutoWin and AutoWin.Enabled then
            endMatch(generation)
        end
    end)

    AutoWin = vape.Categories.Blatant:CreateModule({
        Name = 'AutoWin',
        Function = function(enabled)
            generation += 1
            local token = generation

            if not enabled then
                setAutoKill(false)
                matchFinished = false
                return
            end

            matchFinished = false
            replayWaitUntil = 0

            if not vape.Modules or not vape.Modules.AutoKill then
                warn('autowin: autokill not loaded')
                task.defer(function()
                    if AutoWin.Enabled and generation == token then
                        AutoWin:Toggle()
                    end
                end)
                return
            end

            task.spawn(function()
                while AutoWin.Enabled and generation == token do
                    local phase = state.PhaseClock()
                    local inMatch = state.InMatch()
                    local alive = state.IsAlive()

                    if phase == 'MatchEnd' then
                        if not matchFinished then
                            endMatch(token)
                        else
                            setAutoKill(false)
                        end
                    elseif matchFinished then
                        setAutoKill(false)
                        if inMatch and phase == 'PreRound' then
                            matchFinished = false
                        end
                    elseif inMatch then
                        setAutoKill(
                            alive and (phase == 'Live' or phase == 'Overtime')
                        )
                    else
                        setAutoKill(false)

                        if state.GetPlayerState() == 'Lobby'
                            and state.Get('Queued') ~= true
                            and os.clock() >= replayWaitUntil then
                            queue(
                                'Queue',
                                'lobby:' .. tostring(state.SeenMatchId()),
                                token
                            )
                        end
                    end

                    task.wait(0.2)
                end

                setAutoKill(false)
            end)
        end,
    })
end)


run(function()
    local FreeCursor
    local cameraApi = util.Camera() or require(sharedFolder:WaitForChild('Camera'))
    local reason = 'tribes free cursor module'
    local hud = require(combatFolder:WaitForChild('Hud'))
    local cursorGuiService = game:GetService('GuiService')
    local crosshairs = {'Melee', 'Bow', 'Gun', 'Spread', 'Throw', 'Use', 'Dot'}

    local function cursorReady()
        return FreeCursor and FreeCursor.Enabled
            and not cursorGuiService.MenuIsOpen
            and lplr:GetAttribute('MenuOpen') ~= true
            and not inputService:GetFocusedTextBox()
    end

    local function updateCrosshair(restore)
        local gui = lplr.PlayerGui:FindFirstChild('CombatHUD')
        local center = gui and gui:FindFirstChild('Center')
        if not center then return end

        local style = hud.GetStyle()
        local show = restore or not cursorReady()

        for _, name in ipairs(crosshairs) do
            local item = center:FindFirstChild(name)
            if item then
                item.Visible = show and name == style
            end
        end
    end

    gameapi.Patch(util, 'IsMouseUnlocked', function(original)
        return function(...)
            if cursorReady() then
                return false
            end

            return original(...)
        end
    end)

    gameapi.Patch(cameraApi, 'GetAimRay', function(original)
        return function(...)
            if cursorReady() then
                local camera = workspace.CurrentCamera

                if camera then
                    local position = inputService:GetMouseLocation()

                    return camera:ViewportPointToRay(
                        position.X,
                        position.Y
                    )
                end
            end

            return original(...)
        end
    end)

    gameapi.Patch(hud, 'SetStyle', function(original)
        return function(...)
            local result = original(...)

            if cursorReady() then
                updateCrosshair(false)
            end

            return result
        end
    end)

    gameapi.Connect(runService.RenderStepped, function()
        if cursorReady() then
            updateCrosshair(false)
        end
    end)
    local function setUnlocked(enabled)
        if enabled then
            cameraApi.PushMouseUnlock(reason)
            updateCrosshair(false)
        else
            cameraApi.PopMouseUnlock(reason)
            updateCrosshair(true)
        end
    end

    gameapi.Connect(inputService.InputBegan, function(input, processed)
        if not FreeCursor or not FreeCursor.Enabled then return end
        if inputService:GetFocusedTextBox() then return end
        if input.KeyCode == Enum.KeyCode.V then
            cameraApi.ToggleFirstPerson()
        end
    end)

    gameapi.Connect(inputService.InputChanged, function(input)
        if not FreeCursor or not FreeCursor.Enabled then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
        local delta = input.Delta
        local multiplier = 0.003
        cameraApi.SetLook(
            cameraApi.GetYaw() - delta.X * multiplier,
            cameraApi.GetPitch() - delta.Y * multiplier
        )
    end)

    FreeCursor = vape.Categories.Render:CreateModule({
        Name = 'FreeCursor',
        Function = setUnlocked,
        Tooltip = 'unlocks ur cursor from the middle of the screen'
    })

    FreeCursor:Clean(function()
        setUnlocked(false)
    end)
end)


run(function()
    local Velocity
    local trackedRoot
    local attributeConnection

    local knockbackAttributes = {
        NKb = true,
        NKbDur = true,
        SKb = true,
        SKbF = true,
        SKbN = true
    }

    local function neutralize()
        if not Velocity or not Velocity.Enabled or not trackedRoot then
            return
        end

        for name in pairs(knockbackAttributes) do
            if trackedRoot:GetAttribute(name) ~= nil then
                trackedRoot:SetAttribute(name, nil)
            end
        end
    end

    local function detach()
        if attributeConnection then
            attributeConnection:Disconnect()
            attributeConnection = nil
        end

        trackedRoot = nil
    end

    local function attach(char)
        detach()

        if not Velocity or not Velocity.Enabled or not char then
            return
        end

        local root = char:FindFirstChild('HumanoidRootPart')
            or char:WaitForChild('HumanoidRootPart', 5)

        if not root then return end

        trackedRoot = root

        attributeConnection = root.AttributeChanged:Connect(function(name)
            if knockbackAttributes[name] or name == 'NKbSeq' then
                neutralize()
            end
        end)

        neutralize()
    end

    gameapi.Connect(lplr.CharacterAdded, function(char)
        if Velocity and Velocity.Enabled then
            task.defer(function()
                if Velocity.Enabled then
                    attach(char)
                end
            end)
        end
    end)

    Velocity = vape.Categories.Combat:CreateModule({
        Name = 'Velocity',
        Function = function(enabled)
            if enabled then
                attach(lplr.Character)
            else
                detach()
            end
        end,
        Tooltip = 'tries to stop incoming knockback'
    })

    Velocity:Clean(detach)
end)


run(function()
    local AutoUpgrade
    local economy = require(
        lplr:WaitForChild('PlayerScripts')
            :WaitForChild('UI')
            :WaitForChild('Economy')
    )

    local generation = 0
    local attempted = {}

    local function canUpgrade()
        local char = lplr.Character
        if not char then return false end

        local matchId = char:GetAttribute('MatchId')
        return type(matchId) ~= 'string' or matchId == ''
    end

    AutoUpgrade = vape.Categories.Inventory:CreateModule({
        Name = 'AutoUpgrade',
        Function = function(enabled)
            generation += 1
            local token = generation

            if not enabled then
                table.clear(attempted)
                return
            end

            task.spawn(function()
                while AutoUpgrade.Enabled and token == generation do
                    if canUpgrade() then
                        local ok, ready = pcall(economy.ReadyList)

                        if ok and type(ready) == 'table' then
                            local now = os.clock()

                            for _, item in ipairs(ready) do
                                if type(item) == 'string'
                                    and now >= (attempted[item] or 0) then

                                    attempted[item] = now + 1.5

                                    local success, err = pcall(
                                        economy.Upgrade,
                                        item
                                    )

                                    if not success then
                                        warn('auto upgrade: ' .. tostring(err))
                                    end

                                    break
                                end
                            end
                        end
                    end

                    task.wait(0.3)
                end
            end)
        end,
        Tooltip = 'automatically upgrades gear when ready'
    })
end)


run(function()
    local AutoQueue
    local requeueing = false
    local remotes = replicatedStorage:WaitForChild('Remotes')
    local matchEvent = remotes:WaitForChild('MatchEvent')
    local queueAction = remotes:WaitForChild('QueueAction')

    AutoQueue = vape.Categories.Utility:CreateModule({
        Name = 'AutoQueue',
        Function = function(enabled)
            if not enabled then
                requeueing = false
                return
            end

            AutoQueue:Clean(matchEvent.OnClientEvent:Connect(function(event)
                if event ~= 'MatchEnd' or requeueing then
                    return
                end

                requeueing = true

                task.spawn(function()
                    local ok, err = pcall(function()
                        queueAction:InvokeServer('PlayAgain')
                    end)

                    if not ok then
                        warn('auto queue: ' .. tostring(err))
                    end

                    task.wait(4)
                    requeueing = false
                end)
            end))
        end,
        Tooltip = 'queues again when the match ends'
    })
end)

run(function()
    local GunMods, NoRecoil, NoShake, NoSpread
    local cameraApi = util.Camera() or require(sharedFolder:WaitForChild('Camera'))
    local hud = require(combatFolder:WaitForChild('Hud'))
    local poses = require(combatFolder:WaitForChild('Poses'))
    local activeShot

    local function active(option)
        return GunMods and GunMods.Enabled and option and option.Enabled
    end

    local function resetRecoil()
        if not active(NoRecoil) or type(cameraApi) ~= 'table' then return end
        local spring = cameraApi.SlowRecoil
        if type(spring) == 'table' and type(spring.Snap) == 'function' then
            pcall(spring.Snap, spring, Vector3.zero)
        end
        pcall(function()
            cameraApi.SlowRecoilStay = Vector3.zero
        end)
    end

    local function block(tab, key, option)
        gameapi.Patch(tab, key, function(original)
            return function(...)
                if active(option) then return end
                return original(...)
            end
        end)
    end

    block(util, 'Recoil', NoRecoil)
    block(util, 'RecoilSlow', NoRecoil)
    block(util, 'Shake', NoShake)
    block(hud, 'Kick', NoRecoil)

    gameapi.Patch(poses, 'Kick', function(original)
        return function(char, ...)
            if active(NoRecoil) and char == lplr.Character then return end
            return original(char, ...)
        end
    end)

    local function compensate(spread, goal, degrees, seed)
        if typeof(goal) ~= 'Vector3' or goal.Magnitude < 0.001 then return nil end
        goal = goal.Unit
        local candidate = goal
        for _ = 1, 14 do
            local result = spread(candidate, degrees, seed, 0)
            if typeof(result) ~= 'Vector3' then return nil end
            if result:Dot(goal) >= 0.9999999 then return candidate end
            local adjusted = candidate + (goal - result)
            if adjusted.Magnitude < 0.001 then return nil end
            candidate = adjusted.Unit
        end
        return nil
    end

    gameapi.Patch(combat, 'SpreadDir', function(original)
        return function(direction, degrees, seed, index)
            local shot = activeShot
            if shot and index == 0 and type(degrees) == 'number' and degrees > 0
                and typeof(direction) == 'Vector3' then
                local corrected = compensate(original, direction, degrees, seed)
                if corrected then
                    shot.original = direction
                    shot.corrected = corrected
                    shot.seed = seed
                    return original(corrected, degrees, seed, index)
                end
            end
            return original(direction, degrees, seed, index)
        end
    end)

    gameapi.Patch(gun, 'Fire', function(original)
        return function(self, ...)
            local ctx = self and self.ctx
            if not active(NoSpread) or self.kind == 'Blunderbuss' or self.kind == 'Crossbow'
                or type(ctx) ~= 'table' or type(ctx.send) ~= 'function' then
                return original(self, ...)
            end

            local shot = {}
            local nativeSend = ctx.send
            local function send(action, packet, ...)
                if action == 'Shoot' and shot.corrected and type(packet) == 'table'
                    and type(packet.id) == 'number' and typeof(packet.dir) == 'Vector3'
                    and packet.dir:Dot(shot.original) >= 0.999999 then
                    local nonce = ctx.char and ctx.char:GetAttribute('ShotNonce')
                    if combat.SeedFor(packet.id, type(nonce) == 'number' and nonce or 0) == shot.seed then
                        local fixed = table.clone(packet)
                        fixed.dir = shot.corrected
                        return nativeSend(action, fixed, ...)
                    end
                end
                return nativeSend(action, packet, ...)
            end

            if not pcall(function() ctx.send = send end) or ctx.send ~= send then
                return original(self, ...)
            end

            local previous = activeShot
            activeShot = shot
            local result = table.pack(pcall(original, self, ...))
            activeShot = previous
            if ctx.send == send then
                ctx.send = nativeSend
            end
            if not result[1] then
                error(result[2], 0)
            end
            return table.unpack(result, 2, result.n)
        end
    end)

    GunMods = vape.Categories.Combat:CreateModule({
        Name = 'GunMods',
        Function = function(enabled)
            if enabled then resetRecoil() end
        end,
        Tooltip = 'modify your gun !@!@'
    })
    NoRecoil = GunMods:CreateToggle({
        Name = 'no recoil',
        Default = true,
        Function = function(enabled)
            if enabled then resetRecoil() end
        end
    })
    NoShake = GunMods:CreateToggle({
        Name = 'no shake',
        Default = true
    })
    NoSpread = GunMods:CreateToggle({
        Name = 'no spread',
        Default = true,
        Tooltip = 'makes the flintlock and musket shoot dead straight'
    })
end)
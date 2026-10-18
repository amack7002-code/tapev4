--tribes 3v3
local run = function(func)
	func()
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
local collectionService = cloneref(game:GetService('CollectionService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local runService = cloneref(game:GetService('RunService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))

local gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo

local tribes = {}
local store = {}
local isMatch = false

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

local function notif(...)
	return vape:CreateNotification(...)
end

run(function()
	entitylib.targetCheck = function(entity)
		if entity.TeamCheck then
			return entity:TeamCheck()
		end
		if entity.NPC then return true end
		if isFriend(entity.Player) then return false end
		if not select(2, whitelist:get(entity.Player)) then return false end
		return lplr:GetAttribute('Team') ~= entity.Player:GetAttribute('Team')
	end

	entitylib.addPlayer = function(plr)

	end

	local oldstart = entitylib.start
	local function customEntity(entity)
		local plr = playersService:GetPlayerFromCharacter(entity)
		entitylib.addEntity(entity, plr, not plr and function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end or nil)
	end

	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, entity in collectionService:GetTagged('Combatant') do
				customEntity(entity)
			end

			table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('Combatant'):Connect(customEntity))
			table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('Combatant'):Connect(function(entity)
				entitylib.removeEntity(entity)
			end))
		end
	end
end)
entitylib.start()

run(function()
	repeat
		local suc = pcall(function()
			tribes = {
				Camera = require(replicatedStorage.Shared.Camera),
				Combat = require(replicatedStorage.Shared.Combat),
				CombatController = require(lplr.PlayerScripts.Combat.Controller),
				Economy = require(lplr.PlayerScripts.UI.Economy),
				Melee = require(lplr.PlayerScripts.Combat.Handlers.Melee),
				Weapons = require(replicatedStorage.Shared.Weapons),
				Util = require(lplr.PlayerScripts.Combat.Util)
			}
		end)
		if not suc then
			task.wait()
		end
	until suc

	pcall(function()
		tribes.State = debug.getupvalue(tribes.CombatController.State, 2)
	end)
	pcall(function()
		tribes.SetSpeed = debug.getupvalue(debug.getupvalue(tribes.CombatController.Equip, 11), 15)
	end)

	local kills = sessioninfo:AddItem('Kills')
	local deaths = sessioninfo:AddItem('Deaths')
	local games = sessioninfo:AddItem('Games')
	local wins = sessioninfo:AddItem('Wins')
	local winstreaks = sessioninfo:AddItem('Winstreaks', '', function()
		local streaks = {}

		for _, plr in playersService:GetPlayers() do
			if plr ~= lplr and (plr:GetAttribute('Streak') or 0) > 0 then
				table.insert(streaks, plr.Name..': '..plr:GetAttribute('Streak'))
			end
		end

		if #streaks > 0 then
			table.sort(streaks, function(a, b)
				return (tonumber(a:split(': ')[2]) or 0) > (tonumber(b:split(': ')[2]) or 0)
			end)

			return '\n'..table.concat(streaks, '\n')
		end

		return 'None'
	end, false)
	isMatch = not workspace:FindFirstChild('Lobby')

	if isMatch then
		task.delay(1, function()
			games:Increment()
		end)
	end

	task.spawn(function()
		local remotes = replicatedStorage:WaitForChild('Remotes', 30)
		if not remotes then return end

		local hitConfirm = remotes:WaitForChild('HitConfirm', 30)
		local matchEvent = remotes:WaitForChild('MatchEvent', 30)

		if hitConfirm then
			vape:Clean(hitConfirm.OnClientEvent:Connect(function(data)
				if data and data.killed and isMatch then
					kills:Increment()
				end
			end))
		end

		if matchEvent then
			vape:Clean(matchEvent.OnClientEvent:Connect(function(event, data)
				if isMatch then
					if event == 'MatchEnd' then
						local didWin = data and data.winnerTeam == lplr:GetAttribute('Team')
						if didWin then
							wins:Increment()
						end

						vapeEvents.MatchEnded:Fire(didWin)
					elseif event == 'Elimination' and data and data.victimId == 'p'..lplr.UserId then
						deaths:Increment()
					end
				end
			end))
		end
	end)
end)

-- shared support layer for the combat modules: weapon classes, items, aiming
-- and the movement arbitration AutoWin/AntiHit move your hitbox through
local RANGEDKINDS = {Crossbow = 'Bow', Bow = 'Bow', Longbow = 'Bow', Blunderbuss = 'Gun', Gun = 'Gun', Javelin = 'Throw', Bomb = 'Throw', Sling = 'Throw', Grenade = 'Throw', Herbs = 'Herbs'}
local MELEEKINDS = {Sword = true, Fists = true, Spear = true, Dagger = true, Hammer = true, Axe = true, Greatsword = true, Knife = true, Club = true}

store.KIND = {}
for kind in MELEEKINDS do
	store.KIND[kind] = 'Melee'
end
for kind, class in RANGEDKINDS do
	store.KIND[kind] = class
end

function store.handler()
	local state = tribes.State
	local handler = state and state.handler
	if not (handler and handler.tuning and handler.ctx) then return nil end
	local kind = handler.kind or state.kind or (typeof(state.tool) == 'Instance' and state.tool.Name) or nil
	local class = kind and store.KIND[kind] or nil
	if not class and (handler.lastSwing or handler.tuning.combo or handler.tuning.range) then
		-- unknown kind but it swings like a melee weapon
		class = 'Melee'
	end
	return handler, class, kind
end

function store.body()
	local root = entitylib.isAlive and entitylib.character.RootPart
	return root and root.Position or Vector3.zero
end

store.hitbox = store.body

function store.velocityOf(ent)
	return ent.RootPart.AssemblyLinearVelocity
end

function store.heldClass(char)
	if typeof(char) ~= 'Instance' then return nil end
	local tool = char:FindFirstChildWhichIsA('Tool', true)
	return tool and store.KIND[tool.Name] or nil
end

local worldParams = RaycastParams.new()
worldParams.FilterType = Enum.RaycastFilterType.Exclude

function store.worldParams()
	worldParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
	return worldParams
end

function store.tools()
	local list, seen = {}, {}
	local function add(tool, held)
		if not (tool and tool:IsA('Tool')) or seen[tool] then return end
		seen[tool] = true
		table.insert(list, {Tool = tool, Held = held, Kind = tool.Name, Class = store.KIND[tool.Name]})
	end
	if tribes.State and typeof(tribes.State.tool) == 'Instance' then
		add(tribes.State.tool, true)
	end
	if lplr.Character then
		add(lplr.Character:FindFirstChildOfClass('Tool'), true)
	end
	local backpack = lplr:FindFirstChildOfClass('Backpack')
	if backpack then
		for _, tool in backpack:GetChildren() do
			add(tool, false)
		end
	end
	return list
end

function store.equip(tool)
	pcall(function()
		local hum = lplr.Character and lplr.Character:FindFirstChildOfClass('Humanoid')
		if hum and typeof(tool) == 'Instance' then
			hum:EquipTool(tool)
		end
	end)
end

function store.aimAt(origin, ent)
	if not (tribes.Camera and tribes.Camera.SetLook and ent and ent.RootPart) then return false end
	local delta = ent.RootPart.Position - origin
	local flat = delta * Vector3.new(1, 0, 1)
	if delta.Magnitude < 0.1 or flat.Magnitude < 0.1 then return false end
	pcall(tribes.Camera.SetLook, math.atan2(-flat.X, -flat.Z), math.asin(delta.Y / delta.Magnitude))
	return true
end

function store.press(handler, down, ent)
	if ent and not store.aimAt(store.body(), ent) then return end
	pcall(handler.Input, handler, 'Primary', down)
end

local MOVEMENTPRIORITY = {AutoWin = 2, AntiHit = 1}
local movementRequests = {}
local movementLast, movementLastAt

function store.move(owner, position)
	movementRequests[owner] = {mode = 'move', value = position}
end

function store.lift(owner, height)
	movementRequests[owner] = {mode = 'lift', value = height}
end

function store.release(owner)
	movementRequests[owner] = nil
end

function store.outranked(owner)
	local mine = MOVEMENTPRIORITY[owner] or 0
	for other in movementRequests do
		if other ~= owner and (MOVEMENTPRIORITY[other] or 0) > mine then
			return true
		end
	end
	return false
end

vape:Clean(runService.Heartbeat:Connect(function()
	store.moving = entitylib.isAlive and entitylib.character.Humanoid.MoveDirection.Magnitude > 0 or nil

	local best, bestOwner
	for owner, request in movementRequests do
		if not best or (MOVEMENTPRIORITY[owner] or 0) > (MOVEMENTPRIORITY[bestOwner] or 0) then
			best, bestOwner = request, owner
		end
	end
	if not (best and entitylib.isAlive) then
		movementLast = nil
		return
	end

	local root = entitylib.character.RootPart
	local goal = best.mode == 'move' and best.value or Vector3.new(root.Position.X, best.value, root.Position.Z)

	-- the server put us somewhere else than where we placed ourselves
	if movementLast and tick() - movementLastAt < 0.5 and (root.Position - movementLast).Magnitude > 6 then
		vapeEvents.Pulled:Fire(bestOwner)
	end

	root.CFrame = (root.CFrame - root.CFrame.Position) + goal
	movementLast, movementLastAt = goal, tick()
end))

local function canAct()
	if tribes.Util and tribes.Util.CanAct then
		local ok, res = pcall(tribes.Util.CanAct)
		return ok and res ~= false
	end
	return true
end

local function inMatch()
	return isMatch == true
end

local function isEnemy(ent)
	return ent ~= nil and ent.Targetable == true and (ent.Health or 0) > 0
end

-- best effort enemy shot watcher for AntiHit's projectile dodge: fast, small
-- loose parts that appear near an enemy are treated as their shots
task.spawn(function()
	workspace.ChildAdded:Connect(function(obj)
		if not obj:IsA('BasePart') or obj.Anchored then return end
		task.defer(function()
			if not obj.Parent then return end
			local vel = obj.AssemblyLinearVelocity
			if vel.Magnitude < 30 or obj.Size.Magnitude > 12 then return end
			local origin = obj.Position
			for _, ent in entitylib.List do
				if ent.Targetable and ent.RootPart and ent.Health and ent.Health > 0 and (ent.RootPart.Position - origin).Magnitude < 40 then
					vapeEvents.EnemyShot:Fire(ent, origin, vel, 60)
					break
				end
			end
		end)
	end)
end)

for _, v in {'AutoClicker', 'TriggerBot', 'Jesus', 'AutoRejoin', 'Disabler', 'MurderMystery', 'Parkour', "Xray", "SafeWalk"} do
	vape:Remove(v)
end

run(function()
local AntiFall

AntiFall = vape.Categories.Blatant:CreateModule({
	Name = 'AntiFall',
	Function = function(callback)
		if callback then
			AntiFall:Clean(runService.Heartbeat:Connect(function()
				if entitylib.isAlive then
					local root = entitylib.character.RootPart
					local diff = math.max(root.Position.Y, -29.9) - root.Position.Y

					if math.abs(diff) > 0 then
						root.CFrame += Vector3.new(0, diff, 0)
						root.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)
					end
				end
			end))
		end
	end,
	Tooltip = 'Prevents you from dying to the void'
})
end)

run(function()
	local Killaura
	local Targets
	local SwingRange
	local AttackRange
	local AngleSlider
	local AirHits
	local SwingTime
	local AttackSpeed
	local MaxTargets
	local Sort
	local ContinueSwing
	local Mouse
	local AFKCheck
	local NoSwing
	local GUI
	local BoxTween
	local BoxStart
	local BoxEnd
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local AutoBlock
	local Limit
	local SwingOnly
	local Boxes, Particles = {}, {}
	local nextAttack, nextSwing, swingUntil, ownSwing = 0, 0, 0, 0
	local lastInput = tick()
	local blocked = false
	local rng = Random.new()
	local tweenService = cloneref(game:GetService('TweenService'))
	local SORTS = {'Damage', 'Distance', 'Angle', 'Cursor', 'Lowest Health', 'Highest Health'}

	local function meleeHandler()
		local handler, class = store.handler()
		if not (handler and class == 'Melee' and type(handler.Detect) == 'function' and handler.ctx) then return nil end
		return handler
	end

	local function weaponReach(handler)
		return (handler.tuning.range or 8) + 1.2
	end

	-- the game's own test, from where the server sees you. held in the air the height rule is the point
	local function inReach(ent, reach)
		local delta = ent.RootPart.Position - store.hitbox()
		return delta.Magnitude <= reach and (store.moving ~= nil or math.abs(delta.Y) < 8)
	end

	local function airborne(ent)
		return ent.Humanoid.FloorMaterial == Enum.Material.Air
	end

	local function score(ent, mode, pos, look)
		if mode == 'Damage' then
			return ent.Health + (ent.Character:GetAttribute('Armor') or 0)
		elseif mode == 'Angle' then
			local flat = (ent.RootPart.Position - pos) * Vector3.new(1, 0, 1)
			return flat.Magnitude > 0.1 and look:Angle(flat) or 0
		elseif mode == 'Cursor' then
			local point, onScreen = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
			return onScreen and (Vector2.new(point.X, point.Y) - inputService:GetMouseLocation()).Magnitude or math.huge
		elseif mode == 'Lowest Health' then
			return ent.Health
		elseif mode == 'Highest Health' then
			return -ent.Health
		end
		return (ent.RootPart.Position - pos).Magnitude
	end

	local function setBlock(handler, on)
		if not (AutoBlock.Enabled and handler.tuning and handler.tuning.block) then return end
		if on == (handler.blocking == true) then return end
		if on and not canAct() then return end
		pcall(handler.SetBlock, handler, on)
	end

	local function animate(handler)
		local tuning, preset, ctx = handler.tuning, handler.preset or {}, handler.ctx
		local now = os.clock()
		local oneHanded = handler.OneHanded and handler:OneHanded()
		local combo = oneHanded and tuning.oneHanded and tuning.oneHanded.combo or tuning.combo or {1}
		if now - (handler.lastSwing or 0) <= (tuning.comboWindow or 1) then
			handler.combo = ((handler.combo or 0) % #combo) + 1
		else
			handler.combo = 1
		end
		handler.lastSwing = now
		ownSwing = now
		local step = handler.combo
		local finisher = #combo > 2 and step == #combo
		if not NoSwing.Enabled then
			local anims = oneHanded and preset.oneSwings or preset.swings or {}
			pcall(tribes.Util.PlayAnim, ctx.animator, anims[((step - 1) % math.max(1, #anims)) + 1], (preset.swingSpeed or 1) * (finisher and 0.95 or 1), 0.05)
			pcall(ctx.emit, 'Swing', {
				step = step,
				finisher = finisher,
				hitDelay = preset.hitDelay or 0.1,
				oneHanded = oneHanded
			})
			pcall(tribes.Util.Sound, preset.swingSound or 'Swing_Sword', ctx.root, {PlaybackSpeed = finisher and 0.88 or 1})
		end
	end

	local function pulse(box)
		if BoxStart.Value <= 0 then return end
		local full = Vector3.new(3, 5, 3)
		box.Size = full * 0.8
		tweenService:Create(box, TweenInfo.new(0.1 / BoxStart.Value + 0.1 / math.max(BoxEnd.Value, 0.01), Enum.EasingStyle[BoxTween.Value] or Enum.EasingStyle.Quad), {Size = full}):Play()
	end

	-- hits go out after the swing's own delay, like the game's, with whoever is still in reach
	local function attack(handler, list)
		local preset, ctx = handler.preset or {}, handler.ctx
		local delay = preset.hitDelay or 0.1
		animate(handler)
		store.strikeAt = tick() + delay
		store.meleeTarget = list[1]
		for i, box in Boxes do
			if list[i] and box.Adornee then pulse(box) end
		end
		task.delay(delay, function()
			if not (Killaura.Enabled and entitylib.isAlive) or (ctx.alive and not ctx.alive()) then return end
			local reach = AttackRange.Value
			local hits = {}
			for _, ent in list do
				if ent.Character.Parent and ent.Health > 0 and inReach(ent, reach) then
					table.insert(hits, ent.Character)
				end
			end
			if #hits == 0 then return end
			local from = store.hitbox()
			local to = list[1].RootPart.Position
			local dir = to - from
			ctx.send('Swing', {
				tool = (tribes.State and tribes.State.tool) or ctx.tool,
				dir = dir.Magnitude > 0.1 and dir.Unit or entitylib.character.RootPart.CFrame.LookVector,
				hits = hits
			})
		end)
	end

	local function equipMelee()
		for _, item in store.tools() do
			if item.Class == 'Melee' and item.Kind ~= 'Fists' and not item.Held then
				store.equip(item.Tool)
				return
			end
		end
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				Killaura:Clean(inputService.InputBegan:Connect(function()
					lastInput = tick()
				end))
				repeat
					local shownList = {}
					local ready = entitylib.isAlive and (not Mouse.Enabled or inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1))
						and not (AFKCheck.Enabled and tick() - lastInput > 30)
						and not (GUI.Enabled and lplr:GetAttribute('MenuOpen') == true)
					local handler = ready and meleeHandler()
					if ready and not handler and not Limit.Enabled and inMatch() then
						-- someone in swing range and no melee weapon out, so take one out
						for _, ent in entitylib.List do
							if ent.Targetable and ent.Health > 0 and (ent.RootPart.Position - store.body()).Magnitude <= SwingRange.Value then
								equipMelee()
								break
							end
						end
					end
					if handler and SwingOnly.Enabled then
						-- only while you are swinging yourself
						local manual = handler.lastSwing and handler.lastSwing ~= ownSwing and os.clock() - handler.lastSwing < 0.5
						if not manual then handler = nil end
					end

					if handler then
						local pos = store.body()
						local look = gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
						local found = entitylib.AllPosition({
							Range = math.max(SwingRange.Value, AttackRange.Value),
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = 10
						})
						local swingList, attackList = {}, {}
						for _, ent in found do
							local flat = (ent.RootPart.Position - pos) * Vector3.new(1, 0, 1)
							if flat.Magnitude < 3.2 or math.deg(look:Angle(flat)) <= AngleSlider.Value / 2 then
								table.insert(swingList, ent)
							end
						end
						local mode = Sort.Value
						local scores = {}
						for _, ent in swingList do
							scores[ent] = score(ent, mode, pos, look)
						end
						table.sort(swingList, function(a, b)
							return scores[a] < scores[b]
						end)
						local cap = math.min(MaxTargets.Value, math.max(1, handler.tuning.maxTargets or 1))
						for _, ent in swingList do
							if inReach(ent, AttackRange.Value) then
								table.insert(attackList, ent)
								if #attackList >= cap then break end
							end
						end
						for _, ent in swingList do
							targetinfo.Targets[ent] = tick() + 1
						end
						shownList = swingList

						local now = os.clock()
						if #attackList > 0 then
							swingUntil = now + ContinueSwing:GetRandomValue() / 1000
							if targetinfo.Focus then
								targetinfo.Focus[attackList[1]] = tick() + 1
							end
							local cooldown = math.max(handler.Cooldown and handler:Cooldown() or handler.tuning.cooldown or 0.5, AttackSpeed.Value)
							local free = not handler.Ready or handler:Ready()
							if free and now >= nextAttack and canAct() and (AutoBlock.Enabled or not handler.blocking) then
								-- air hit chance is rolled once a swing for every target off the ground
								local chance = AirHits:GetRandomValue()
								local list = {}
								for _, ent in attackList do
									if not airborne(ent) or rng:NextNumber(0, 100) < chance then
										table.insert(list, ent)
									end
								end
								nextAttack = now + cooldown
								if Face.Enabled then
									local root = entitylib.character.RootPart
									local flat = (attackList[1].RootPart.Position - root.Position) * Vector3.new(1, 0, 1)
									if flat.Magnitude > 0.1 then
										root.CFrame = CFrame.lookAlong(root.Position, flat)
									end
								end
								if handler.blocking then setBlock(handler, false) end
								if #list > 0 then
									attack(handler, list)
								else
									animate(handler)
								end
								nextSwing = now + SwingTime:GetRandomValue()
								blocked = false
							end
						elseif (#swingList > 0 or now < swingUntil) and now >= nextSwing and canAct() then
							-- in swing range only, or still swinging after the last target: the animation alone
							if #swingList > 0 then
								swingUntil = now + ContinueSwing:GetRandomValue() / 1000
							end
							nextSwing = now + SwingTime:GetRandomValue()
							animate(handler)
						elseif #swingList == 0 and AutoBlock.Enabled then
							setBlock(handler, true)
							blocked = true
						end
					elseif blocked then
						local h = meleeHandler()
						if h then setBlock(h, false) end
						blocked = false
					end

					for i, box in Boxes do
						local ent = shownList[i]
						box.Adornee = ent and ent.RootPart or nil
						if ent then
							local color = inReach(ent, AttackRange.Value) and BoxAttackColor or BoxSwingColor
							box.Color3 = Color3.fromHSV(color.Hue, color.Sat, color.Value)
							box.Transparency = 1 - color.Opacity
						end
					end
					for i, part in Particles do
						local ent = shownList[i]
						part.Position = ent and ent.RootPart.Position or Vector3.new(0, -1e5, 0)
						part.Parent = ent and gameCamera or nil
					end
					task.wait()
				until not Killaura.Enabled
			else
				local handler = meleeHandler()
				if handler and blocked then
					setBlock(handler, false)
				end
				blocked = false
				store.strikeAt = nil
				for _, box in Boxes do
					box.Adornee = nil
				end
				for _, part in Particles do
					part.Parent = nil
				end
			end
		end,
		Tooltip = 'Swings at enemies around you with your melee weapon, without aiming at them'
	})
	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 20,
		Default = 14,
		Suffix = 'studs',
		Tooltip = 'How close an enemy has to be before you start swinging'
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 14,
		Default = 10.7,
		Decimal = 10,
		Suffix = 'studs',
		Tooltip = 'How far away a target can be, measured where the server sees you. A sword reaches 10.7'
	})
	Killaura:CreateButton({
		Name = 'Sync to legit ranges',
		Function = function()
			local handler = meleeHandler()
			if handler then
				local reach = weaponReach(handler)
				SwingRange:SetValue(math.ceil(reach))
				AttackRange:SetValue(math.floor(reach * 10) / 10)
			else
				notif('Killaura', 'Hold a melee weapon first', 3, 'warning')
			end
		end,
		Tooltip = 'Drops both ranges to what the melee weapon in your hand reaches'
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	AirHits = Killaura:CreateTwoSlider({
		Name = 'Air hit chance',
		Min = 0,
		Max = 100,
		DefaultMin = 100,
		DefaultMax = 100,
		Tooltip = 'Chance to hit a target that is off the ground, rolled between the two values on every swing'
	})
	SwingTime = Killaura:CreateTwoSlider({
		Name = 'Swing time',
		Min = 0.11,
		Max = 2,
		DefaultMin = 0.42,
		DefaultMax = 0.42,
		Decimal = 100,
		Tooltip = 'Seconds between swings that do not attack, rolled between the two values every time'
	})
	AttackSpeed = Killaura:CreateSlider({
		Name = 'Attack speed',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Default = 0,
		Suffix = 'seconds',
		Tooltip = 'Seconds between attacks, never faster than your weapon allows. 0 keeps its own'
	})
	MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 5,
		Default = 5,
		Tooltip = 'How many enemies one swing hits, never more than your weapon can'
	})
	Sort = Killaura:CreateDropdown({
		Name = 'Target Mode',
		List = SORTS,
		Tooltip = 'Damage - least health and armour first\nDistance - closest first\nAngle - closest to where you face\nCursor - closest to your cursor'
	})
	ContinueSwing = Killaura:CreateTwoSlider({
		Name = 'Continue swing',
		Min = 0,
		Max = 1000,
		DefaultMin = 0,
		DefaultMax = 0,
		Tooltip = 'Keeps swinging for a random number of ms after the last target leaves'
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	AFKCheck = Killaura:CreateToggle({
		Name = 'AFK check',
		Tooltip = 'Stops attacking once you have not touched your mouse or keyboard for 30 seconds'
	})
	NoSwing = Killaura:CreateToggle({
		Name = 'No Swing',
		Tooltip = 'Attacks without playing the swing'
	})
	GUI = Killaura:CreateToggle({
		Name = 'GUI check',
		Tooltip = 'Stops attacking while a game menu is open'
	})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			for _, v in {BoxTween, BoxStart, BoxEnd, BoxSwingColor, BoxAttackColor} do
				if v then v.Object.Visible = callback end
			end
			if callback then
				for i = 1, 5 do
					local box = Instance.new('BoxHandleAdornment')
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
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
	local styles = {'Bounce'}
	for _, v in Enum.EasingStyle:GetEnumItems() do
		if not table.find(styles, v.Name) then
			table.insert(styles, v.Name)
		end
	end
	BoxTween = Killaura:CreateDropdown({
		Name = 'Box Animation',
		List = styles,
		Darker = true,
		Visible = false
	})
	BoxStart = Killaura:CreateSlider({
		Name = 'Start Animation Speed',
		Min = 0,
		Max = 10,
		Default = 0.9,
		Decimal = 30,
		Darker = true,
		Visible = false
	})
	BoxEnd = Killaura:CreateSlider({
		Name = 'End Animation Speed',
		Min = 0,
		Max = 10,
		Default = 1.4,
		Decimal = 30,
		Darker = true,
		Visible = false
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
			for _, v in {ParticleTexture, ParticleColor1, ParticleColor2, ParticleSize} do
				if v then v.Object.Visible = callback end
			end
			if callback then
				for i = 1, 5 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.Transparency = 1
					local emitter = Instance.new('ParticleEmitter')
					emitter.Brightness = 1.5
					emitter.Size = NumberSequence.new(ParticleSize.Value)
					emitter.Shape = Enum.ParticleEmitterShape.Sphere
					emitter.Texture = ParticleTexture.Value
					emitter.Transparency = NumberSequence.new(0)
					emitter.Lifetime = NumberRange.new(0.4)
					emitter.Speed = NumberRange.new(16)
					emitter.Rate = 128
					emitter.Drag = 16
					emitter.ShapePartial = 1
					emitter.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					emitter.Parent = part
					Particles[i] = part
				end
			else
				for _, part in Particles do
					part:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	local function recolour()
		for _, part in Particles do
			part.ParticleEmitter.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
			})
		end
	end
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, part in Particles do
				part.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function()
			if ParticleColor2 then recolour() end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function()
			recolour()
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
			for _, part in Particles do
				part.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({
		Name = 'Face target',
		Default = true,
		Tooltip = 'Turns your character toward the target for each attack'
	})
	AutoBlock = Killaura:CreateToggle({
		Name = 'AutoBlock',
		Tooltip = 'Blocks between swings with weapons that can block'
	})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only attacks while a melee weapon is held. Off, it takes one out when an enemy is close'
	})
	SwingOnly = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while you are swinging yourself'
	})
end)


run(function()
    local old

    vape.Categories.Blatant:CreateModule({
	Name = 'NoSlowdown',
	Function = function(callback)
		if callback then
			if type(tribes.SetSpeed) == 'function' then
				old = hookfunction(tribes.SetSpeed, function() end)
			end
			if tribes.State and tribes.State.speed then
				table.clear(tribes.State.speed)
			end
		else
			if old then
				if restorefunction then
					restorefunction(tribes.SetSpeed)
				else
					hookfunction(tribes.SetSpeed, old)
				end
				old = nil
			end
		end
	end,
	Tooltip = 'Prevents slowing down when using items.'
})
end)

run(function()
    local AimAssist
local Targets
local Sort
local AimSpeed
local Distance
local AngleSlider
local StrafeIncrease
local Vertical
local ClickAim

AimAssist = vape.Categories.Combat:CreateModule({
	Name = 'AimAssist',
	Function = function(callback)
		if callback then
			AimAssist:Clean(runService.Heartbeat:Connect(function(dt)
				if entitylib.isAlive and tribes.State and tribes.State.handler and tribes.State.handler.lastSwing and ((not ClickAim.Enabled) or (os.clock() - (tribes.State.handler.lastSwing or 0)) < 0.5) then
					local entity = entitylib.EntityPosition({
						Range = Distance.Value,
						Part = 'RootPart',
						Wallcheck = Targets.Walls.Enabled,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled
					})

					if entity then
						local delta = (entity.RootPart.Position - entitylib.character.RootPart.Position)
						local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
						local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
						if angle >= (math.rad(AngleSlider.Value) / 2) then return end
						targetinfo.Targets[entity] = os.clock() + 1
						local lerped = gameCamera.CFrame:Lerp(CFrame.lookAt(gameCamera.CFrame.Position, entity.RootPart.Position), (AimSpeed.Value + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 0)) * dt).LookVector
						if tribes.Camera and tribes.Camera.SetLook then
						tribes.Camera.SetLook(math.atan2(-lerped.X, -lerped.Z), Vertical.Enabled and math.asin(lerped.Y) or nil)
					end
					end
				end
			end))
		end
	end,
	Tooltip = 'Smoothly aims to closest valid target with sword'
})
Targets = AimAssist:CreateTargets({
	Players = true,
	NPCs = true,
	Walls = true
})
AimSpeed = AimAssist:CreateSlider({
	Name = 'Aim Speed',
	Min = 1,
	Max = 20,
	Default = 6
})
Distance = AimAssist:CreateSlider({
	Name = 'Distance',
	Min = 1,
	Max = 30,
	Default = 30,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
AngleSlider = AimAssist:CreateSlider({
	Name = 'Max angle',
	Min = 1,
	Max = 360,
	Default = 70
})
ClickAim = AimAssist:CreateToggle({
	Name = 'Click Aim',
	Default = true
})
Vertical = AimAssist:CreateToggle({
	Name = 'Vertical Aim'
})
StrafeIncrease = AimAssist:CreateToggle({
	Name = 'Strafe increase'
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
			if type(tribes.Melee and tribes.Melee.Detect) == 'function' then
				old = hookfunction(tribes.Melee.Detect, function(...)
					local pack = table.pack(...)
					if pack.n >= 2 and type(pack[2]) == 'number' then
						pack[2] += Value.Value
					end

					return old(unpack(pack, 1, pack.n))
				end)
			end
		else
			if old then
				if restorefunction then
					restorefunction(tribes.Melee.Detect)
				else
					hookfunction(tribes.Melee.Detect, old)
				end
				old = nil
			end
		end
	end,
	Tooltip = 'Extends attack reach'
})
Value = Reach:CreateSlider({
	Name = 'Range',
	Min = 0,
	Max = 4,
	Default = 4,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
end)

run(function()
    local SilentAim
local Target
local Range
local HitChance
local CircleColor
local CircleTransparency
local CircleFilled
local CircleObject
local old

local function Hook(...)
	local handler

	for _, obj in debug.getstack(3) do
		if type(obj) == 'table' and rawget(obj, 'tuning') then
			handler = obj
			break
		end
	end

	if not handler then
		return old(...)
	end

	local args = table.pack(...)
	local ok, res = pcall(function()
		local entity = entitylib.EntityMouse({
			Range = Range.Value,
			Part = 'RootPart',
			Players = Target.Players.Enabled,
			NPCs = Target.NPCs.Enabled
		})

		if entity then
			local targetPart = entity.RootPart
			local origin = args[1] or gameCamera.CFrame.Position
			local projSpeed = handler.tuning.speed or (handler.tuning.speedMax or 200)

			if handler.drawStart and tribes.Combat then
				local drawOk, _, drawnSpeed = pcall(tribes.Combat.DrawnShot, handler.tuning, debug.getstack(3, 4))
				if drawOk and drawnSpeed then
					projSpeed = drawnSpeed
				end
			end

			local calc = prediction.SolveTrajectory(origin, projSpeed, math.abs(handler.tuning.gravity or (handler.spreadNow and 0 or 60)), targetPart.Position, entity.RootPart.AssemblyLinearVelocity)
			if calc then
				local lookDir = CFrame.lookAt(origin, calc).LookVector
				targetinfo.Targets[entity] = os.clock() + 1

				if handler.lastThrow then
					return (lookDir - Vector3.new(0, ((handler.kind == 'Bomb') and 0.16) or (((handler.kind == 'Sling') and 0.05) or (((handler.kind ~= 'Javelin') and 0.01) or 0.04)), 0)).Unit
				end

				if handler.lastShot and handler.kind ~= 'Blunderbuss' then
					local spread
					if handler.kind == 'Crossbow' then
						spread = 0
					elseif handler:Aimed() then
						spread = handler.tuning.spreadAim or 0
					else
						spread = handler.tuning.spreadHip or 0
					end

					local spreadDir = tribes.Combat.SpreadDir(lookDir, spread, handler:Seed(tribes.State and (tribes.State.shotId + 1) or 1), 0)
					return (CFrame.lookAt(Vector3.zero, lookDir) * CFrame.lookAt(Vector3.zero, lookDir):ToObjectSpace(CFrame.lookAt(Vector3.zero, spreadDir)):Inverse()).LookVector
				end

				return lookDir
			end
		end
	end)

	if ok and res then
		return res
	end
	return old(unpack(args, 1, args.n))
end

SilentAim = vape.Categories.Combat:CreateModule({
	Name = 'SilentAim',
	Function = function(callback)
		if CircleObject then
			CircleObject.Visible = callback
		end

		if callback then
			if type(tribes.Util and tribes.Util.AimDirection) == 'function' then
				old = hookfunction(tribes.Util.AimDirection, function(...)
					return Hook(...)
				end)
			end

			repeat
				if CircleObject then
					CircleObject.Position = inputService:GetMouseLocation()
				end

				task.wait()
			until not SilentAim.Enabled
		else
			if old then
				if restorefunction then
					restorefunction(tribes.Util.AimDirection)
				else
					hookfunction(tribes.Util.AimDirection, old)
				end
				old = nil
			end
		end
	end,
	ExtraText = function()
		return 'Tribes'
	end,
	Tooltip = 'Silently adjusts your aim towards the enemy'
})
Target = SilentAim:CreateTargets({
	Players = true,
	NPCs = true
})
Range = SilentAim:CreateSlider({
	Name = 'Range',
	Min = 1,
	Max = 1000,
	Default = 150,
	Function = function(val)
		if CircleObject then
			CircleObject.Radius = val
		end
	end,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
HitChance = SilentAim:CreateSlider({
	Name = 'Hit Chance',
	Min = 0,
	Max = 100,
	Default = 85,
	Suffix = '%'
})
SilentAim:CreateToggle({
	Name = 'Range Circle',
	Function = function(callback)
		if callback then
			CircleObject = Drawing.new('Circle')
			CircleObject.Filled = CircleFilled.Enabled
			CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
			CircleObject.Position = vape.gui.AbsoluteSize / 2
			CircleObject.Radius = Range.Value
			CircleObject.NumSides = 100
			CircleObject.Transparency = 1 - CircleTransparency.Value
			CircleObject.Visible = SilentAim.Enabled
		else
			pcall(function()
				CircleObject.Visible = false
				CircleObject:Remove()
			end)
		end
		CircleColor.Object.Visible = callback
		CircleTransparency.Object.Visible = callback
		CircleFilled.Object.Visible = callback
	end
})
CircleColor = SilentAim:CreateColorSlider({
	Name = 'Circle Color',
	Function = function(hue, sat, val)
		if CircleObject then
			CircleObject.Color = Color3.fromHSV(hue, sat, val)
		end
	end,
	Darker = true,
	Visible = false
})
CircleTransparency = SilentAim:CreateSlider({
	Name = 'Transparency',
	Min = 0,
	Max = 1,
	Decimal = 10,
	Default = 0.5,
	Function = function(val)
		if CircleObject then
			CircleObject.Transparency = 1 - val
		end
	end,
	Darker = true,
	Visible = false
})
CircleFilled = SilentAim:CreateToggle({
	Name = 'Circle Filled',
	Function = function(callback)
		if CircleObject then
			CircleObject.Filled = callback
		end
	end,
	Darker = true,
	Visible = false
})
end)

run(function()
    local Velocity

local function LocalAdded(char)
	if not (char and char.RootPart) then return end
	Velocity:Clean(char.RootPart.AttributeChanged:Connect(function(key)
		if key:find('Kb') and char.RootPart:GetAttribute(key) then
			char.RootPart:SetAttribute(key, nil)
		end
	end))
end

Velocity = vape.Categories.Combat:CreateModule({
	Name = 'Velocity',
	Function = function(callback)
		if callback then
			Velocity:Clean(entitylib.Events.LocalAdded:Connect(LocalAdded))
			if entitylib.isAlive then
				LocalAdded(entitylib.character)
			end
		end
	end,
	Tooltip = 'Prevent the player from taking knockback'
})
end)

run(function()
    local AutoUpgrade

AutoUpgrade = vape.Categories.Inventory:CreateModule({
	Name = 'AutoUpgrade',
	Function = function(callback)
		if callback then
			repeat
				if tribes.Economy and (not lplr:GetAttribute('MatchId') or lplr:GetAttribute('MatchId') == '') then
					pcall(function()
						local item = tribes.Economy.ReadyList()[1]
						if item then
							tribes.Economy.Upgrade(item)
						end
					end)
				end

				task.wait(0.05)
			until not AutoUpgrade.Enabled
		end
	end,
	Tooltip = 'Automatically upgrade all collectable gear.'
})
end)

run(function()
    local AutoQueue
local Delay
local Notification

AutoQueue = vape.Categories.Utility:CreateModule({
	Name = 'AutoQueue',
	Function = function(callback)
		if callback then
			AutoQueue:Clean(vapeEvents.MatchEnded.Event:Connect(function()
				if Notification.Enabled and Delay.Value > 0 then
					notif('AutoQueue', 'Playing again in '..string.format('%.1f', Delay.Value)..' seconds!', Delay.Value)
				end

				task.delay(Delay.Value, function()
					pcall(function()
						replicatedStorage.Remotes.QueueAction:InvokeServer('PlayAgain')
					end)
				end)
			end))
		end
	end,
	Tooltip = 'Automatically requeue after the match ends.'
})
Delay = AutoQueue:CreateSlider({
	Name = 'Delay',
	Min = 0,
	Max = 2,
	Default = 1,
	Decimal = 10,
	Suffix = function(val)
		return val == 1 and 'second' or 'seconds'
	end
})
Notification = AutoQueue:CreateToggle({
	Name = 'Notification',
	Default = true
})
end)

run(function()
    local AutoToxic
local GG
local Toggles, Lists, Cloned, Presets = {}, {}, {}, {}

local function sendMessage(name, obj, default)
	local message = default
	if #Lists[name].ListEnabled > 0 then
		if #Cloned[name] <= 0 then
			Cloned[name] = table.clone(Lists[name].ListEnabled)
		end

		local entry = Random.new():NextInteger(1, #Cloned[name])
		message = Cloned[name][entry]
		table.remove(Cloned[name], entry)
	end

	if not message then return end

	message = message and message:gsub('<obj>', obj or '') or ''
	if textChatService:CanUserChatAsync(lplr.UserId) then
		pcall(function()
			textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(message)
		end)
	else
		pcall(function()
			textChatService.ChatInputBarConfiguration.TargetTextChannel:SendPresetAsync(Presets[message] or Presets['So close'])
		end)
	end
end

AutoToxic = vape.Categories.Utility:CreateModule({
	Name = 'AutoToxic',
	Function = function(callback)
		if callback then
			AutoToxic:Clean(vapeEvents.MatchEnded.Event:Connect(function(won)
				if GG.Enabled then
					if textChatService:CanUserChatAsync(lplr.UserId) then
						pcall(function()
							textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('gg')
						end)
					else
						pcall(function()
							textChatService.ChatInputBarConfiguration.TargetTextChannel:SendPresetAsync(Presets['Good game'])
						end)
					end
				end

				if won then
					if Toggles.Win.Enabled then
						sendMessage('Win', nil, 'yall garbage')
					end
				end
			end))
		end
	end,
	Tooltip = 'Says a message after a certain action'
})
GG = AutoToxic:CreateToggle({
	Name = 'AutoGG',
	Default = true
})
for _, v in {'Win'} do
	Cloned[v] = {}
	Toggles[v] = AutoToxic:CreateToggle({
		Name = v..' ',
		Function = function(callback)
			if Lists[v] then
				Lists[v].Object.Visible = callback
			end
		end
	})
	Lists[v] = AutoToxic:CreateTextList({
		Name = v,
		Darker = true,
		Visible = false,
		Function = function()
			table.clear(Cloned[v])
		end
	})
end

pcall(function()
	for _, group in textChatService:GetPresetsAsync().categoryGroups do
		for _, category in group.categories do
			for _, message in category.messages do
				Presets[message.value] = message.presetId
			end
		end
	end
end)
end)

run(function()
	local AutoWin
	local Mode
	local Height
	local Travel
	local Speed
	local AuraOn
	local target, held
	local pausedUntil, warned = 0, false
	local auraByUs = false
	-- an enemy's own client only sends a melee hit while you are less than 8 studs above or below them,
	-- and the server holds your hits to the same rule, so you come down for the moment each one is sent
	local SAFE = 8.3
	local STRIKE = 6
	local SIDE = 2.5
	local LEAD, HOLD = 0.08, 0.1

	local function meleeTool()
		local best
		for _, item in store.tools() do
			if item.Class == 'Melee' and item.Kind ~= 'Fists' then
				if item.Held then return item end
				best = best or item
			end
		end
		return best
	end

	local function pick(root)
		local best, score
		for _, ent in entitylib.List do
			if ent.Targetable and ent.Health > 0 and ent.Character.Parent then
				local value = Mode.Value == 'Lowest health' and ent.Health or (ent.RootPart.Position - root.Position).Magnitude
				if not score or value < score then
					best, score = ent, value
				end
			end
		end
		return best
	end

	local function stop()
		store.release('AutoWin')
		target, held = nil, nil
	end

	AutoWin = vape.Categories.Utility:CreateModule({
		Name = 'AutoWin',
		Function = function(callback)
			if callback then
				warned = false
				local aura = vape.Modules.Killaura
				if AuraOn.Enabled and aura and not aura.Enabled then
					aura:Toggle()
					auraByUs = true
				end
				AutoWin:Clean(vapeEvents.Pulled.Event:Connect(function(owner)
					if owner ~= 'AutoWin' then return end
					-- the server put you back, so wait before trying again
					pausedUntil = tick() + 1.5
					held = nil
					if not warned then
						warned = true
						notif('AutoWin', 'The server moved you back. Try Glide with a lower speed', 6, 'warning')
					end
				end))
				AutoWin:Clean(runService.Heartbeat:Connect(function(dt)
					if not (entitylib.isAlive and inMatch() and canAct()) or tick() < pausedUntil then
						stop()
						return
					end
					local root = entitylib.character.RootPart
					if not (target and target.Targetable and target.Health > 0 and target.Character.Parent) then
						target = pick(root)
					end
					if not target then
						stop()
						return
					end

					local handler, class = store.handler()
					local state = tribes.State
					if class ~= 'Melee' or (handler and state and state.kind and store.KIND[state.kind] == 'Melee' and state.kind == 'Fists') then
						local tool = meleeTool()
						if tool and not tool.Held then
							store.equip(tool.Tool)
						end
					end
					-- as high as the weapon still reaches, never low enough for their swing to count
					local reach = handler and class == 'Melee' and (handler.tuning.range or 8) + 1.2 or 10.7
					local h = math.max(SAFE, math.min(Height.Value, reach - 0.4))
					local now = tick()
					local strike = store.strikeAt and now >= store.strikeAt - LEAD and now <= store.strikeAt + HOLD
					if strike then
						h = STRIKE
					end
					local lead = target.RootPart.Position + store.velocityOf(target) * (lplr:GetNetworkPing() + 0.05)
					-- a little to the side, so the swing has a direction to face
					local side = (root.Position - target.RootPart.Position) * Vector3.new(1, 0, 1)
					side = side.Magnitude > 0.5 and side.Unit or Vector3.xAxis
					local goal = lead + side * SIDE + Vector3.new(0, h, 0)

					if Travel.Value == 'Glide' then
						local from = held or root.Position
						local step = goal - from
						local move = Speed.Value * dt
						-- the dip is short, so it is always taken at once
						held = (step.Magnitude <= move or strike) and goal or from + step.Unit * move
					else
						held = goal
					end
					store.move('AutoWin', held)
				end))
			else
				stop()
				local aura = vape.Modules.Killaura
				if auraByUs and aura and aura.Enabled then
					aura:Toggle()
				end
				auraByUs = false
			end
		end,
		ExtraText = function()
			return target and target.Player and target.Player.DisplayName or (target and 'Bot') or ''
		end,
		Tooltip = 'Goes to each enemy in turn and stays above them, where your hits land and theirs do not'
	})
	Mode = AutoWin:CreateDropdown({
		Name = 'Target',
		List = {'Nearest', 'Lowest health'},
		Tooltip = 'Nearest - the closest enemy first\nLowest health - the weakest enemy first'
	})
	Height = AutoWin:CreateSlider({
		Name = 'Height',
		Min = 8.3,
		Max = 14,
		Default = 9,
		Decimal = 10,
		Suffix = 'studs',
		Tooltip = 'How far above the target you wait between hits, lowered to what your weapon reaches'
	})
	Travel = AutoWin:CreateDropdown({
		Name = 'Travel',
		List = {'Instant', 'Glide'},
		Tooltip = 'Instant - jumps straight to each target\nGlide - flies there at the speed below',
		Function = function(val)
			if Speed then
				Speed.Object.Visible = val == 'Glide'
			end
		end
	})
	Speed = AutoWin:CreateSlider({
		Name = 'Glide speed',
		Min = 20,
		Max = 300,
		Default = 80,
		Suffix = 'studs/s',
		Darker = true,
		Visible = false
	})
	AuraOn = AutoWin:CreateToggle({
		Name = 'Switch on Killaura',
		Default = true,
		Tooltip = 'Turns Killaura on while AutoWin runs and back off after'
	})
end)

run(function()
	local StaffDetector
	local Leave
	-- the game's group gives mods the same rank as members, so roles are matched by name
	local GROUP = 776581204
	local STAFF = {Mod = true, Admin = true, Dev = true, Analytics = true, Artist = true}
	local checked = setmetatable({}, {__mode = 'k'})

	local function check(plr)
		if plr == lplr or checked[plr] then return end
		checked[plr] = true
		task.spawn(function()
			local ok, role = pcall(plr.GetRoleInGroup, plr, GROUP)
			if not (ok and STAFF[role]) or not StaffDetector.Enabled then return end
			notif('StaffDetector', plr.DisplayName..' (@'..plr.Name..') is '..role..' staff and is in your server', 15, 'alert')
			if Leave.Enabled then
				task.wait(1)
				lplr:Kick('StaffDetector: '..role..' '..plr.Name..' joined')
			end
		end)
	end

	StaffDetector = vape.Categories.Utility:CreateModule({
		Name = 'StaffDetector',
		Function = function(callback)
			if callback then
				table.clear(checked)
				for _, plr in playersService:GetPlayers() do
					check(plr)
				end
				StaffDetector:Clean(playersService.PlayerAdded:Connect(check))
			end
		end,
		Tooltip = 'Warns you when a Tribes moderator, admin or developer is in your server'
	})
	Leave = StaffDetector:CreateToggle({
		Name = 'Leave',
		Tooltip = 'Leaves the game when one is found'
	})
end)

run(function()
	local AutoSkip
	local Words
	local Delay
	local buttons = setmetatable({}, {__mode = 'k'})
	local pressedAt = setmetatable({}, {__mode = 'k'})
	local playerGui = lplr:WaitForChild('PlayerGui', 10)

	local function matches(button)
		local texts = {button.Name}
		if button:IsA('TextButton') then
			table.insert(texts, button.Text)
		end
		for _, child in button:GetChildren() do
			if child:IsA('TextLabel') then
				table.insert(texts, child.Text)
			end
		end
		for _, text in texts do
			local lower = string.lower(text)
			for _, word in Words.ListEnabled do
				if word ~= '' and lower:find(string.lower(word), 1, true) then
					return true
				end
			end
		end
		return false
	end

	-- on screen means every frame above it is visible and its screen is switched on
	local function shown(button)
		local node = button
		while node and node ~= playerGui do
			if node:IsA('GuiObject') and not node.Visible then return false end
			if node:IsA('LayerCollector') and not node.Enabled then return false end
			node = node.Parent
		end
		return node == playerGui
	end

	-- the button's own click handlers, the same ones a real click runs
	local function press(button)
		local fired = false
		if getconnections then
			for _, signal in {button.Activated, button.MouseButton1Click, button.MouseButton1Down} do
				local ok, conns = pcall(getconnections, signal)
				for _, conn in ok and conns or {} do
					if pcall(conn.Fire, conn) then
						fired = true
					end
				end
				if fired then return true end
			end
		end
		if firesignal then
			fired = pcall(firesignal, button.Activated) or pcall(firesignal, button.MouseButton1Click)
		end
		return fired
	end

	local function consider(obj)
		if not obj:IsA('GuiButton') or obj:IsDescendantOf(vape.gui) then return end
		if matches(obj) then
			buttons[obj] = true
		end
	end

	AutoSkip = vape.Categories.Utility:CreateModule({
		Name = 'AutoSkip',
		Function = function(callback)
			if callback then
				if not playerGui then return end
				table.clear(buttons)
				for _, obj in playerGui:GetDescendants() do
					consider(obj)
				end
				AutoSkip:Clean(playerGui.DescendantAdded:Connect(function(obj)
					if obj:IsA('GuiButton') then
						-- its label is usually filled in a moment later
						task.defer(consider, obj)
					elseif obj:IsA('TextLabel') and obj.Parent and obj.Parent:IsA('GuiButton') then
						task.defer(consider, obj.Parent)
					end
				end))
				repeat
					local now = tick()
					for button in buttons do
						if not button.Parent then
							buttons[button] = nil
						elseif shown(button) and now - (pressedAt[button] or 0) > 0.5 then
							pressedAt[button] = now
							task.delay(Delay.Value, function()
								if AutoSkip.Enabled and button.Parent and shown(button) then
									press(button)
								end
							end)
						end
					end
					task.wait(0.2)
				until not AutoSkip.Enabled
			end
		end,
		Tooltip = 'Presses the skip buttons when your chests open at the end of a match'
	})
	Words = AutoSkip:CreateTextList({
		Name = 'Words',
		Default = {'skip'},
		Tooltip = 'Buttons whose name or label has one of these are pressed',
		Function = function()
			if AutoSkip.Enabled and playerGui then
				table.clear(buttons)
				for _, obj in playerGui:GetDescendants() do
					consider(obj)
				end
			end
		end
	})
	Delay = AutoSkip:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 3,
		Default = 0.3,
		Decimal = 10,
		Suffix = 's',
		Tooltip = 'How long a skip button is shown before it is pressed'
	})
end)

run(function()
	local AutoHeal
	local Health
	local Safe
	local SafeRange
	local SwitchBack
	local healingUntil = 0

	local function healer()
		for _, item in store.tools() do
			if item.Kind == 'Herbs' then return item end
		end
	end

	AutoHeal = vape.Categories.Inventory:CreateModule({
		Name = 'AutoHeal',
		Function = function(callback)
			if callback then
				repeat
					local hum = entitylib.isAlive and entitylib.character.Humanoid
					if hum and tick() > healingUntil and inMatch() and canAct() and hum.MaxHealth > 0 and hum.Health / hum.MaxHealth * 100 < Health.Value then
						local clear = true
						if Safe.Enabled then
							local pos = store.body()
							for _, ent in entitylib.List do
								if ent.Targetable and ent.Health > 0 and (ent.RootPart.Position - pos).Magnitude <= SafeRange.Value then
									clear = false
									break
								end
							end
						end
						local item = clear and healer()
						if item then
							local before = not item.Held and tribes.State and tribes.State.tool
							if not item.Held then
								store.equip(item.Tool)
							end
							-- wait for the switch to land, then use it like a click
							local deadline = tick() + 1.5
							local handler, class, kind
							repeat
								task.wait(0.05)
								handler, class, kind = store.handler()
							until kind == 'Herbs' or tick() > deadline
							if kind == 'Herbs' then
								pcall(handler.Input, handler, 'Primary', true)
								pcall(handler.Input, handler, 'Primary', false)
								local time = (handler.tuning.healTime or 3) + 0.3
								healingUntil = tick() + time
								if SwitchBack.Enabled and before then
									task.delay(time, function()
										if before.Parent then
											store.equip(before)
										end
									end)
								end
							else
								healingUntil = tick() + 1
							end
						end
					end
					task.wait(0.25)
				until not AutoHeal.Enabled
			end
		end,
		Tooltip = 'Uses your herbs when your health drops'
	})
	Health = AutoHeal:CreateSlider({
		Name = 'Health',
		Min = 5,
		Max = 95,
		Default = 50,
		Suffix = '%',
		Tooltip = 'Heals below this much health'
	})
	Safe = AutoHeal:CreateToggle({
		Name = 'Only when safe',
		Default = true,
		Tooltip = 'Waits until no enemy is close',
		Function = function(callback)
			if SafeRange then
				SafeRange.Object.Visible = callback
			end
		end
	})
	SafeRange = AutoHeal:CreateSlider({
		Name = 'Safe range',
		Min = 5,
		Max = 60,
		Default = 20,
		Suffix = 'studs',
		Darker = true
	})
	SwitchBack = AutoHeal:CreateToggle({
		Name = 'Switch back',
		Default = true,
		Tooltip = 'Takes your weapon out again once healed'
	})
end)

run(function()
	local AutoRelease
	local Charge

	AutoRelease = vape.Categories.Combat:CreateModule({
		Name = 'AutoRelease',
		Function = function(callback)
			if callback then
				AutoRelease:Clean(runService.Heartbeat:Connect(function()
					local handler, class = store.handler()
					if not handler or not (class == 'Bow' or (class == 'Throw' and handler.winds)) then return end
					if (handler.drawing or handler.winding) and handler.Charge and handler:Charge() >= Charge.Value / 100 then
						store.press(handler, false)
					end
				end))
			end
		end,
		Tooltip = 'Lets go of a bow or javelin the moment it is fully drawn'
	})
	Charge = AutoRelease:CreateSlider({
		Name = 'Charge',
		Min = 10,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)

run(function()
	local AntiHit
	local Melee
	local Range
	local Height
	local Dodge
	local DodgeHeight
	local MaxAir
	local KeepHits
	local shots = {}
	local airSince, restUntil = nil, 0
	-- an enemy's own client only sends a melee hit while your root is less than 8 studs above or below theirs
	local SAFE = 8.3
	local REST = 0.2

	local function pathAt(shot, t)
		return shot.Origin + shot.Velocity * t - Vector3.new(0, 0.5 * shot.Gravity * t * t, 0)
	end

	-- when and how close a shot passes your root, sampled along its flight
	local function closest(shot, pos)
		local best, at = math.huge, nil
		for i = 0, 40 do
			local t = i * 0.05
			local d = (pathAt(shot, t) - pos).Magnitude
			if d < best then
				best, at = d, t
			end
		end
		return best, at
	end

	AntiHit = vape.Categories.Blatant:CreateModule({
		Name = 'AntiHit',
		Function = function(callback)
			if callback then
				AntiHit:Clean(vapeEvents.EnemyShot.Event:Connect(function(shooter, origin, velocity, gravity)
					if not (Dodge.Enabled and entitylib.isAlive and isEnemy(shooter)) then return end
					-- the shot left the shooter about a ping before it reached you
					table.insert(shots, {Origin = origin, Velocity = velocity, Gravity = gravity, Born = tick() - lplr:GetNetworkPing()})
				end))
				AntiHit:Clean(runService.Heartbeat:Connect(function()
					if not (entitylib.isAlive and inMatch() and canAct()) or store.outranked('AntiHit') then
						store.release('AntiHit')
						airSince = nil
						return
					end
					local now = tick()
					local pos = store.body()
					local goal

					if Melee.Enabled then
						for _, ent in entitylib.List do
							if ent.Targetable and ent.Health > 0 then
								local delta = ent.RootPart.Position - pos
								if Vector3.new(delta.X, 0, delta.Z).Magnitude <= Range.Value and store.heldClass(ent.Character) == 'Melee' then
									goal = math.max(goal or -math.huge, ent.RootPart.Position.Y + math.max(Height.Value, SAFE))
								end
							end
						end
					end

					for i = #shots, 1, -1 do
						local shot = shots[i]
						local age = now - shot.Born
						if age > 2 then
							table.remove(shots, i)
						else
							local dist, at = closest(shot, pos)
							-- lift out of its way for the moment it passes, then let it go
							if dist < 4 and at and at - age < 0.35 and at - age > -0.1 then
								goal = math.max(goal or -math.huge, pathAt(shot, at).Y + DodgeHeight.Value)
							end
						end
					end

					-- your own hits only count within 8 studs of the target's height, so the hitbox comes down for them
					if goal and KeepHits.Enabled and store.strikeAt and now >= store.strikeAt - 0.08 and now <= store.strikeAt + 0.1 then
						goal = nil
					end

					if goal and MaxAir.Value > 0 then
						airSince = airSince or now
						if now < restUntil then
							goal = nil
						elseif now - airSince > MaxAir.Value then
							restUntil, airSince = now + REST, nil
							goal = nil
						end
					elseif not goal then
						airSince = nil
					end

					if goal and goal > pos.Y - 0.5 then
						store.lift('AntiHit', goal)
					else
						store.release('AntiHit')
					end
				end))
			else
				store.release('AntiHit')
				table.clear(shots)
				airSince = nil
			end
		end,
		Tooltip = 'Moves only your hitbox above enemies with a melee weapon and out of the path of their shots'
	})
	Melee = AntiHit:CreateToggle({
		Name = 'Melee',
		Default = true,
		Tooltip = 'Raises your hitbox above enemies holding a melee weapon close to you'
	})
	Range = AntiHit:CreateSlider({
		Name = 'Range',
		Min = 4,
		Max = 25,
		Default = 14,
		Suffix = 'studs',
		Tooltip = 'How close an enemy has to be before you rise'
	})
	Height = AntiHit:CreateSlider({
		Name = 'Height',
		Min = 8.3,
		Max = 14,
		Default = 9,
		Decimal = 10,
		Suffix = 'studs',
		Tooltip = 'How far above them you stay. Enemy swings only count under 8, a sword reaches about 10.7'
	})
	Dodge = AntiHit:CreateToggle({
		Name = 'Dodge projectiles',
		Default = true,
		Tooltip = 'Rises over arrows, bolts and throws that would hit you'
	})
	DodgeHeight = AntiHit:CreateSlider({
		Name = 'Dodge height',
		Min = 3,
		Max = 10,
		Default = 5,
		Suffix = 'studs',
		Tooltip = 'How far above a passing shot you rise'
	})
	KeepHits = AntiHit:CreateToggle({
		Name = 'Keep your hits',
		Default = true,
		Tooltip = 'Brings your hitbox down for the moment Killaura lands each hit'
	})
	MaxAir = AntiHit:CreateSlider({
		Name = 'Max air time',
		Min = 0,
		Max = 5,
		Default = 0,
		Decimal = 10,
		Suffix = 's',
		Tooltip = 'Comes down for a moment after this long in the air, 0 to stay up'
	})
end)

run(function()
	local ProjectileAura
	local Targets
	local Range
	local Charge
	local Walls
	local mine = false

	local function find(origin)
		local best, dist
		for _, ent in entitylib.List do
			if ent.Targetable and ent.Health > 0 and ((ent.Player and Targets.Players.Enabled) or (ent.NPC and Targets.NPCs.Enabled)) then
				local d = (ent.RootPart.Position - origin).Magnitude
				if d <= Range.Value and (not dist or d < dist) then
					if not Walls.Enabled or not workspace:Raycast(origin, ent.RootPart.Position - origin, store.worldParams()) then
						best, dist = ent, d
					end
				end
			end
		end
		return best
	end

	ProjectileAura = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAura',
		Function = function(callback)
			if callback then
				ProjectileAura:Clean(runService.Heartbeat:Connect(function()
					local handler, class = store.handler()
					if not (handler and entitylib.isAlive and canAct()) or not (class == 'Bow' or class == 'Gun' or class == 'Throw') then
						mine = false
						return
					end
					local origin = store.body() + Vector3.new(0, 1.5, 0)
					local ent = find(origin)
					if not ent or not store.aimAt(origin, ent) then
						-- let go of a draw it started once nobody is left to shoot
						if mine and (handler.drawing or handler.winding) then
							pcall(handler.Input, handler, 'Primary', false)
						end
						mine = false
						return
					end
					if class == 'Gun' then
						if not handler.reloading and (handler.ammo or 0) > 0 then
							store.press(handler, true, ent)
							store.press(handler, false, ent)
						end
					elseif class == 'Bow' or (class == 'Throw' and handler.winds) then
						if handler.drawing or handler.winding then
							if handler.Charge and handler:Charge() >= Charge.Value / 100 then
								store.press(handler, false, ent)
								mine = false
							end
						else
							store.press(handler, true)
							mine = handler.drawing or handler.winding
						end
					else
						store.press(handler, true, ent)
						store.press(handler, false, ent)
					end
				end))
			else
				local handler = store.handler()
				if mine and handler and (handler.drawing or handler.winding) then
					pcall(handler.Input, handler, 'Primary', false)
				end
				mine = false
			end
		end,
		Tooltip = 'Fires your bow, gun or throwing weapon at the nearest enemy in range'
	})
	Targets = ProjectileAura:CreateTargets({
		Players = true,
		NPCs = true
	})
	Range = ProjectileAura:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 400,
		Default = 120,
		Suffix = 'studs'
	})
	Charge = ProjectileAura:CreateSlider({
		Name = 'Charge',
		Min = 10,
		Max = 100,
		Default = 100,
		Suffix = '%',
		Tooltip = 'How far a bow or javelin is drawn before it is let go'
	})
	Walls = ProjectileAura:CreateToggle({
		Name = 'Wall check',
		Default = true,
		Tooltip = 'Skips enemies behind walls'
	})
end)

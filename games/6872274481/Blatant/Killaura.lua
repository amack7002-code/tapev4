run(function()
	local Killaura
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local AngleSlider
	local Swing
	local ContinueSwinging
	local ContinueSwingTime
	local GUI
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local Limit
	local LegitAura
	local FaceTarget
	local NoSwing
	local AttackCheck
	local kitChecks
	local SwingTime
	local SwingTimeSlider
	local AirHit
	local AirHitsChance
	local FastHits
	local LegitSwitch
	local Kits
	local Arrows
	local Gloops
	local Fireball
	local FastHitsAutoCharge
	local ArrowCharge
	local AttackRemote
	local lastAttackTime = 0
	local lastTargetTime = 0
	local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
	local FROZEN_THRESHOLD = 10
	local SERVER_REACH = 14.4
	pcall(function()
		local combat = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant
		SERVER_REACH = combat.RAYCAST_SWORD_CHARACTER_DISTANCE or SERVER_REACH
	end)
	local TARGET_LOCK_GRACE = 0.18
	local TARGET_QUERY_PADDING = 2
	local kaPeriod = 0.3
	local kaLastSend = 0
	local kaLastSendSrv = 0
	local fhLastShotTime = 0
	local fhEquipBudget = {tokens = 4, stamp = tick()}
	local fhBusySince = 0
	local fhBusyToken = 0
	local fhLastImpact = 0
	local fhSwordPending = false
	local fhSwordPendingSince = 0
	local oldSwingBuffer
	local glueRemote = {InvokeServer = function() end}
	local projectileRemote = {InvokeServer = function() end}
	local frostyGunRemote = {FireServer = function() end}
	local gloopTracker = {}
	local kitWeaponList = {'frost_staff', 'ninja_chakram', 'mage_spellbook'}

	task.spawn(function()
		glueRemote = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('ProjectileFire')
	end)

	task.spawn(function()
		task.wait()
		local _remotes = getgenv().remotes or remotes
		projectileRemote = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('ProjectileFire')
		pcall(function()
			local net = replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged
			frostyGunRemote = net:WaitForChild('FrostyGunFireActionRequest')
		end)
		pcall(function()
			AttackRemote = bedwars.Client:Get(_remotes.AttackEntity).instance
		end)
	end)

	local furyUtil = {}
	task.spawn(function()
		pcall(function()
			local ts = replicatedStorage.TS
			furyUtil.status = require(ts['status-effect']['status-effect-util']).StatusEffectUtil
			furyUtil.kind = require(ts['status-effect']['status-effect-type']).StatusEffectType
			furyUtil.mult = require(ts.balance['black-marketeer-balance']).BlackMarketeerBalance.FURY_POTION_ATTACK_SPEED_MULTIPLIER
		end)
	end)

	local function furyMultiplier()
		local ok, active = pcall(function()
			return furyUtil.status:isActive(lplr.Character, furyUtil.kind.FURY_POTION)
		end)
		if ok and active and type(furyUtil.mult) == 'number' and furyUtil.mult > 0 then
			return furyUtil.mult > 1 and (1 / furyUtil.mult) or furyUtil.mult
		end
		return 1
	end

	local function shouldContinueSwinging()
		if not ContinueSwinging or not ContinueSwinging.Enabled then return false end
		if not ContinueSwingTime or lastTargetTime <= 0 then return false end
		return tick() - lastTargetTime <= ContinueSwingTime.Value
	end

	local function FireAttackRemote(weapon, entityInstance, selfPos, targetPos, aimDir)
		local delta = (targetPos - selfPos).Magnitude
		if delta < 0.01 then return false end

		local ok, remote = pcall(function()
			return bedwars.Client:Get((getgenv().remotes or remotes).AttackEntity)
		end)
		if not ok or not remote then return false end

		local payload = {
			weapon = weapon,
			chargedAttack = {chargeRatio = 0},
			lastSwingServerTimeDelta = 0.5,
			entityInstance = entityInstance,
			validate = {
				raycast = aimDir and {
					cameraPosition = {value = selfPos},
					cursorDirection = {value = aimDir}
				} or nil,
				targetPosition = {value = targetPos},
				selfPosition = {value = selfPos}
			}
		}

		if type(remote.SendToServer) == 'function' then
			local sent, err = pcall(function()
				remote:SendToServer(payload)
			end)

			if sent then
				return true
			end

			warn('killaura send failed: ' .. tostring(err))
		end

		if remote.instance then
			remote.instance:FireServer(payload)
			return true
		end

		if AttackRemote then
			AttackRemote:FireServer(payload)
			return true
		end

		return false
	end

	local function getKnitControllers()
		return (bedwars.KnitClient and bedwars.KnitClient.Controllers) or (bedwars.Knit and bedwars.Knit.Controllers)
	end

	local function isOnTinker()
		local ok, mounted = pcall(function()
			local controllers = getKnitControllers()
			return controllers and controllers.TinkerKitController and controllers.TinkerKitController.mounted
		end)
		return ok and mounted == true
	end

	local _lastTinkerSwing = 0
	local function playTinkerSwing()
		local now = workspace:GetServerTimeNow()
		if now - _lastTinkerSwing < 0.35 then return end
		_lastTinkerSwing = now
		pcall(function()
			local controllers = getKnitControllers()
			local controller = controllers and controllers.TinkerKitController
			if not controller then return end
			local model = controller.userMap[lplr]
			if not model then return end
			local mac = controllers.MountAnimationController
			if not mac then return end
			local animId = bedwars.AnimationType and bedwars.AnimationType.TINKER_ATTACK
			mac:playAnimationInMount(model, animId, 1.85)
		end)
	end

	local _adCacheSword = nil
	local _adCacheMeta = nil
	local _adCacheTime = 0

	local function isMeleeWeapon(toolName)
		if not toolName then return false end
		local lower = toolName:lower()
		if lower:find('hammer') or lower:find('tinker') or lower:find('chainsaw') or lower:find('sword') or lower:find('blade') or lower:find('scythe') or lower:find('dagger') or lower:find('axe') then
			return true
		end
		local meta = bedwars.ItemMeta and bedwars.ItemMeta[toolName]
		return meta and meta.sword ~= nil
	end

	local function getScreenTool()
		local inv = store.inventory
		local slot = inv and inv.hotbarSlot
		local entry = slot and inv.hotbar and inv.hotbar[slot + 1]
		local tool = entry and entry.item and entry.item.tool
		return tool and tool.Parent and tool or nil
	end

	local function getWeaponAttackSpeed(sword, meta)
		if not sword or not sword.tool then return 0.3 end
		local toolName = sword.tool.Name:lower()

		if toolName:find('frosty_hammer') then
			local speedLvl = lplr:GetAttribute('speed') or sword.tool:GetAttribute('speed') or 0
			if speedLvl == 3 then
				return 0.25
			elseif speedLvl == 2 then
				return 0.28
			elseif speedLvl == 1 then
				return 0.32
			end
			return 0.35
		end

		if toolName:find('tinker') or toolName:find('chainsaw') then
			return 0.34
		end

		if meta and meta.sword and type(meta.sword.attackSpeed) == 'number' then
			return meta.sword.attackSpeed
		end

		return 0.3
	end

	local function computeAttackData()
		if not entitylib.isAlive then return false end

		local casting = lplr:GetAttribute('IsCasting')
		if casting ~= nil and casting ~= false and casting ~= 0 and casting ~= '' then
			if casting == true then return false end
			if type(casting) == 'number' and casting > workspace:GetServerTimeNow() then return false end
		end

		if bedwars.SwordController and bedwars.SwordController.disableSwingState then return false end

		local stunned = lplr.Character and lplr.Character:GetAttribute('StunnedUntilTime')
		if stunned and stunned > workspace:GetServerTimeNow() then return false end

		if AttackCheck and AttackCheck.Enabled then
			if kitChecks then
				for _, check in pairs(kitChecks) do
					local ok, res = pcall(check)
					if ok and res then return false end
				end
			end

			if tick() - (store.silasAbilityTime or 0) < 2.2 then return false end
			if tick() - (store.terraStompTime or 0) < 0.7 then return false end
			if tick() - (store.terraKickTime or 0) < 0.5 then return false end
		end

		if GUI and GUI.Enabled then
			if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
		end

		local sword = store.hand
		local fastHitting = fhBusySince > 0 or (tick() - (store._fhRestoreAt or 0)) < 0.6
		if fastHitting and store.tools.sword and store.tools.sword.tool then
			sword = store.tools.sword
		else
			if not sword or not sword.tool or not isMeleeWeapon(sword.tool.Name) then return false end
			if sword.tool ~= getScreenTool() then return false end
		end

		local meta = bedwars.ItemMeta[sword.tool.Name]
		if not meta then return false end

		if Limit and Limit.Enabled then
			if bedwars.DaoController and bedwars.DaoController.chargingMaid then return false end
		end

		if LegitAura and LegitAura.Enabled then
			local lastSwing = bedwars.SwordController and bedwars.SwordController.lastSwing
			if not lastSwing or (tick() - lastSwing) > 0.2 then return false end
		end

		return sword, meta
	end

	local function getAttackData()
		local now = os.clock()
		if now - _adCacheTime < 0.02 and _adCacheSword then
			return _adCacheSword, _adCacheMeta
		end
		_adCacheTime = now
		local sword, meta = computeAttackData()
		_adCacheSword = sword
		_adCacheMeta = meta
		return sword, meta
	end

	local function resetSwordCooldown()
		if bedwars.SwordController then
			bedwars.SwordController.lastAttack = 0
			bedwars.SwordController.lastSwing = 0
			if bedwars.SwordController.lastChargedAttackTimeMap then
				for weaponName in pairs(bedwars.SwordController.lastChargedAttackTimeMap) do
					bedwars.SwordController.lastChargedAttackTimeMap[weaponName] = 0
				end
			end
		end
	end

	local function getAmmo(check)
		if not check.ammoItemTypes then return nil end
		for _, item in store.inventory.inventory.items do
			if not table.find(check.ammoItemTypes, item.itemType) then continue end
			local ok, pt = pcall(check.projectileType, item.itemType)
			if not ok or not pt then continue end
			local pm = bedwars.ProjectileMeta[pt]
			if pm and pm.arrow and pm.launchVelocity and pm.launchVelocity >= 50 then
				return item.itemType
			end
		end
		return nil
	end

	local _projectilesCache = {}
	local _projectilesCacheTime = 0
	local function getProjectiles()
		if not Arrows or not Arrows.Enabled then return {} end
		local now = tick()
		if now - _projectilesCacheTime < 0.2 and #_projectilesCache > 0 then
			return _projectilesCache
		end
		if #_projectilesCache == 0 and now - _projectilesCacheTime < 0.1 then
			return _projectilesCache
		end
		_projectilesCacheTime = now
		table.clear(_projectilesCache)
		for _, item in store.inventory.inventory.items do
			local meta = bedwars.ItemMeta[item.itemType]
			if not meta then continue end
			local proj = meta.projectileSource
			if not proj or not proj.projectileType then continue end
			local ammo = getAmmo(proj)
			if not ammo then continue end
			local projType = proj.projectileType(ammo)
			local pmeta = projType and bedwars.ProjectileMeta[projType]
			if pmeta and pmeta.arrow and pmeta.launchVelocity and pmeta.launchVelocity >= 50 then
				table.insert(_projectilesCache, {item, ammo, projType, proj})
			end
		end
		return _projectilesCache
	end

	local function canShoot(proj)
		local ready = ProjectileDelay[proj[1].itemType] or 0
		return tick() > ready
	end

	local sharedFastHitsRayParams = RaycastParams.new()
	sharedFastHitsRayParams.FilterType = Enum.RaycastFilterType.Exclude
	local _fhFilter = {nil, nil, nil}
	local function setFHFilter(entChar)
		_fhFilter[1] = lplr.Character
		_fhFilter[2] = gameCamera
		_fhFilter[3] = entChar
		sharedFastHitsRayParams.FilterDescendantsInstances = _fhFilter
	end

	local fhBusy = false

	local function setFHBusy()
		fhBusyToken = fhBusyToken + 1
		fhBusy = true
		fhBusySince = workspace:GetServerTimeNow()
		store._fhBusySince = fhBusySince
		return fhBusyToken
	end

	local function clearFHBusy(token)
		if token and token ~= fhBusyToken then return end
		fhBusy = false
		fhBusySince = 0
		store._fhBusySince = nil
	end

	local function fhInAngle(v)
		if not AngleSlider or AngleSlider.Value >= 360 then return true end
		if not v or not v.RootPart then return false end
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return false end
		local look = root.CFrame.LookVector
		local flatLook = look * Vector3.new(1, 0, 1)
		if flatLook.Magnitude < 0.001 then return true end
		local flat = (v.RootPart.Position - root.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude <= 1 then return true end
		return math.acos(math.clamp(flatLook.Unit:Dot(flat.Unit), -1, 1)) <= math.rad(AngleSlider.Value) / 2
	end

	local function fhForceSword()
		local sw = getSword()
		if not sw or not sw.tool or not sw.tool.Parent then return end
		store.tools.sword = sw
		local hand = lplr.Character and lplr.Character:FindFirstChild('HandInvItem')
		if hand then
			hand.Value = sw.tool
		end
		store._fhRestoreAt = tick()
		task.spawn(function()
			pcall(function()
				bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = sw.tool})
			end)
		end)
	end

	local function fhEquipAwait(tool)
		if not tool or not tool.Parent then return false end
		local hand = lplr.Character and lplr.Character:FindFirstChild('HandInvItem')
		if not hand then return false end
		if hand.Value == tool then return true end

		local ok, accepted = pcall(function()
			return bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool}):timeout(0.35):await()
		end)
		if not ok or accepted == false then
			fhForceSword()
			return false
		end

		hand.Value = tool
		return true
	end

	local fhPipe = {fails = 0, offUntil = 0}

	local function fhPipeReady()
		return not (LegitSwitch and LegitSwitch.Enabled) and tick() >= fhPipe.offUntil
	end

	local function fhEquipFast(tool)
		local hand = lplr.Character and lplr.Character:FindFirstChild('HandInvItem')
		if not hand or not tool or not tool.Parent then return false end
		if hand.Value == tool then return true end
		hand.Value = tool
		local remote = bedwars.Client:Get(remotes.EquipItem)
		local inst = remote and remote.instance
		task.spawn(function()
			pcall(function()
				if inst then
					inst:InvokeServer({hand = tool})
				else
					remote:CallServerAsync({hand = tool})
				end
			end)
		end)
		return true
	end

	local function fhRestoreFast()
		local sw = getSword()
		if not sw or not sw.tool or not sw.tool.Parent then return end
		store.tools.sword = sw
		fhEquipFast(sw.tool)
	end

	local fhLog = {buf = {}, started = os.clock(), nextFlush = 0, lastHit = 0}

	local function fhNote(text)
		if #fhLog.buf < 800 then
			table.insert(fhLog.buf, string.format('%.3f ', os.clock() - fhLog.started) .. text)
		end
	end

	local function fhFlush(force)
		local now = os.clock()
		if not force and now < fhLog.nextFlush then return end
		fhLog.nextFlush = now + 1
		pcall(writefile, 'aerov4/fhdebug.txt', '==== fast hits debug ====\n' .. table.concat(fhLog.buf, '\n'))
	end

	local function fhRestoreSword()
		local sw = getSword()
		if not sw or not sw.tool or not sw.tool.Parent then return false end
		store.tools.sword = sw

		local hand = lplr.Character and lplr.Character:FindFirstChild('HandInvItem')
		if not hand then return false end

		if hand.Value == sw.tool then
			store._fhRestoreAt = tick()
			return true
		end

		local ok, accepted = pcall(function()
			return bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = sw.tool}):timeout(0.35):await()
		end)
		if not ok or accepted == false then
			fhForceSword()
			return false
		end

		hand.Value = sw.tool
		store._fhRestoreAt = tick()
		return true
	end

	local function recoverFastHitState()
		if not fhBusy then return end
		if fhBusySince <= 0 then
			clearFHBusy()
			return
		end

		if workspace:GetServerTimeNow() - fhBusySince > 1 then
			fhBusyToken = fhBusyToken + 1
			fhBusy = false
			fhBusySince = 0
			store._fhBusySince = nil
			fhRestoreSword()
		end
	end

	local function fastHitBlocksSword()
		if not fhBusy then return false end

		recoverFastHitState()
		if not fhBusy then return false end

		local sw = store.tools and store.tools.sword
		if not sw or not sw.tool then return true end

		local char = lplr.Character
		local hand = char and char:FindFirstChild('HandInvItem')
		local held = hand and hand.Value or (store.hand and store.hand.tool)

		return held ~= sw.tool
	end

	local _fhVelHistory = {}
	local _fhPing = 0.1
	local _fhPingClock = 0
	local _fhIdChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

	local function fhGenId()
		local out = table.create(8)
		for i = 1, 8 do
			local n = math.random(1, #_fhIdChars)
			out[i] = _fhIdChars:sub(n, n)
		end
		return table.concat(out)
	end

	local function getFHPing()
		if tick() - _fhPingClock < 1 then return _fhPing end
		_fhPingClock = tick()
		local ok, val = pcall(function()
			return game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue() / 1000
		end)
		_fhPing = (ok and val) and math.clamp(val, 0.02, 1) or 0.1
		return _fhPing
	end

	local function fhWindowOpen(ent, meleeRange, cost)
		if not ent or not ent.RootPart then return false end
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return false end

		local distance = (ent.RootPart.Position - root.Position).Magnitude

		if distance > meleeRange then
			return true
		end

		if LegitAura and LegitAura.Enabled then
			return true
		end

		if kaLastSend <= 0 then
			return false
		end

		local sinceSword = tick() - kaLastSend
		if sinceSword < 0.015 then
			return false
		end

		local remaining = kaPeriod - sinceSword
		local guard = math.clamp(0.055 + getFHPing() * 0.5 + (cost or 0), 0.09, 0.18)
		return remaining > guard
	end

	local _fhVelClean = 0
	local function smoothedVelocity(ent, targetPart)
		local rawVel = targetPart.AssemblyLinearVelocity or targetPart.Velocity or Vector3.zero
		local key = tostring(ent)
		local now = tick()

		if now - _fhVelClean > 10 then
			_fhVelClean = now

			for k, v in pairs(_fhVelHistory) do
				if type(v) == 'table' and v.t and (now - v.t) > 8 then
					_fhVelHistory[k] = nil
				end
			end

			for k, v in pairs(gloopTracker) do
				if v.lastShot and (now - v.lastShot) > 20 then
					gloopTracker[k] = nil
				end
			end
		end

		local rec = _fhVelHistory[key]

		if not rec or type(rec) ~= 'table' then
			_fhVelHistory[key] = {v = rawVel, t = now}
			return rawVel, rawVel
		end

		rec.v = rec.v:Lerp(rawVel, 0.35)
		rec.t = now
		return rec.v, rawVel
	end

	local function targetGravity(ent)
		local playerGravity = workspace.Gravity
		local balloons = ent.Character and ent.Character:GetAttribute('InflatedBalloons')

		if balloons and balloons > 0 then
			playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
		end

		if ent.Character and ent.Character.PrimaryPart and ent.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
			playerGravity = 6
		end

		if ent.Player and ent.Player:GetAttribute('IsOwlTarget') then
			local _owls = collectionService:GetTagged('Owl')
			if #_owls > 0 then
				local _uid = ent.Player.UserId
				for _, owl in ipairs(_owls) do
					if owl:GetAttribute('Target') == _uid and owl:GetAttribute('Status') == 2 then
						playerGravity = 0
						break
					end
				end
			end
		end

		return playerGravity
	end

	local function fhGetCooldown(itemMeta)
		local cd = tonumber(itemMeta.fireDelaySec) or 0.5
		pcall(function()
			local ev = bedwars.ClientSyncEvents.ProjectileCooldownModifierCheck:fire(cd)
			if ev and type(ev.cooldown) == 'number' then
				cd = ev.cooldown
			end
		end)
		return cd
	end

	local function shootProjectile(item, ammo, projectile, itemMeta, selfPos, ent, ignoreSwitch, batch)
		local meta = bedwars.ProjectileMeta[projectile]
		if not meta or not ent or not ent.RootPart then return false end

		local combatMeta = meta.combat or {}
		local respectsPrior = not combatMeta.ignoreDamageTakenCooldown
		local blocksNext = not combatMeta.noApplyDamageCooldown
		local fhGap = kaPeriod
		local fhRoot = entitylib.character and entitylib.character.RootPart
		local fhDist = fhRoot and (ent.RootPart.Position - fhRoot.Position).Magnitude or 0
		local estFlight = fhDist / math.max(tonumber(meta.launchVelocity) or 100, 1)
		local inMelee = Killaura.Enabled and fhDist <= AttackRange.Value + 2

		local function fireWait(flight, lead)
			if not respectsPrior or (not ignoreSwitch and fhPipeReady()) then return 0 end
			local now = tick()
			local land = math.max(fhLastImpact + fhGap, now + (lead or 0) + flight)
			if inMelee and kaLastSend > 0 then
				land = math.max(land, kaLastSend + kaPeriod * 0.35)
				if land > kaLastSend + kaPeriod * 0.65 then
					return math.huge
				end
			end
			return land - flight - now
		end

		if fireWait(estFlight, getFHPing()) > 0.35 then return false end

		local busyToken
		local ownsBusy = not batch
		local switched = false
		local pipe = not ignoreSwitch and fhPipeReady()
		local root = entitylib.character and entitylib.character.RootPart

		if not root then
			return false
		end

		selfPos = root.Position

		if not ignoreSwitch and kaLastSend > 0 and ent.RootPart then
			local remaining = math.max(kaPeriod - (tick() - kaLastSend), 0)
			local distance = (ent.RootPart.Position - root.Position).Magnitude
			local safeWindow = math.clamp(0.12 + getFHPing(), 0.14, 0.24)

			if distance <= AttackRange.Value + 2 and remaining <= safeWindow then
				return false
			end
		end

		if not ignoreSwitch then
			if ownsBusy then
				busyToken = setFHBusy()
			end

			if not fhEquipAwait(item.tool) then
				ProjectileDelay[item.itemType] = tick() + 0.3

				if ownsBusy then
					fhRestoreSword()
					clearFHBusy(busyToken)
				end

				return false
			end

			switched = true
		end

		local gravity = tonumber(meta.gravitationalAcceleration)
		if gravity == nil then gravity = 196.2 end
		if gravity < 1 then gravity = 0 end
		local targetPart = ent.RootPart
		local playerGravity = targetGravity(ent)
		local readyAt = ProjectileDelay[item.itemType] or 0
		if readyAt > tick() then
			task.wait(readyAt - tick())
			local rootNow = entitylib.character and entitylib.character.RootPart
			if rootNow then
				selfPos = rootNow.Position
			end
		end
		local preWait = fireWait(estFlight)
		if preWait > 0 and preWait <= 0.35 then
			task.wait(preWait)
			local rootNow = entitylib.character and entitylib.character.RootPart
			if rootNow then
				selfPos = rootNow.Position
			end
		end
		local isFireball = tostring(ammo):find('fireball') ~= nil
		local maxCharge = tonumber(itemMeta.maxStrengthChargeSec) or 0
		local chargePct = FastHitsAutoCharge and FastHitsAutoCharge.Enabled
			and math.clamp(ArrowCharge.Value / 100, 0, 1)
			or 0
		local drawTime = maxCharge * chargePct
		local multiAt = tonumber(itemMeta.multiShotChargeTime)
		if multiAt and maxCharge > 0 and chargePct >= 1 then
			drawTime = math.max(drawTime, multiAt)
		end
		local minScalar = tonumber(itemMeta.minStrengthScalar) or 1
		local chargeRatio = maxCharge > 0 and math.clamp(drawTime / maxCharge, 0, 1) or 1
		local overrides

		if meta.getProjectileOverridesFunction then
			pcall(function()
				overrides = meta.getProjectileOverridesFunction(lplr)
			end)
		end

		overrides = type(overrides) == 'table' and overrides or {}

		local baseSpeed = tonumber(overrides.launchVelocityOverride) or tonumber(meta.launchVelocity) or 100
		local projSpeed = baseSpeed * (minScalar + (1 - minScalar) * chargeRatio)
		local ping = getFHPing()
		local smoothVel, rawVel = smoothedVelocity(ent, targetPart)
		smoothVel = Vector3.new(smoothVel.X, rawVel.Y, smoothVel.Z)
		local solverVel = rawVel
		local hip = ent.HipHeight or 2
		local aimPart = targetPart
		local aimOffset = hip * 0.15

		do
			local itype = tostring(item.itemType)
			local head = ent.Character and ent.Character:FindFirstChild('Head')
			local dist = (targetPart.Position - selfPos).Magnitude

			if itype:find('headhunter') then
				local hspeed = Vector3.new(smoothVel.X, 0, smoothVel.Z).Magnitude

				if head and dist < 90 and hspeed < 28 and math.abs(smoothVel.Y) < 30 then
					aimPart = head
					aimOffset = -0.35
				else
					aimOffset = hip * 0.15
				end
			elseif isFireball then
				aimOffset = 0
			elseif itype:find('bomb') or itype:find('grenade') or itype:find('santa') or itype:find('impulse') then
				aimOffset = -hip * 0.5
			elseif itype:find('rocket') or itype:find('launcher') or itype:find('firework') then
				aimOffset = 0
			elseif meta.arrow then
				aimOffset = hip * 0.15
			elseif itype:find('snowball') or itype:find('chakram') or itype:find('spell') then
				aimOffset = hip * 0.3
			end
		end

		local leadPos = aimPart.Position + Vector3.new(0, aimOffset, 0)
		setFHFilter(ent.Character)
		local originPos = selfPos

		pcall(function()
			local nativeOrigin = bedwars.ProjectileController:getLaunchPosition(item.tool)

			if nativeOrigin then
				originPos = nativeOrigin
			end
		end)

		if typeof(itemMeta.fromPositionOffset) == 'Vector3' then
			originPos += itemMeta.fromPositionOffset
		end

		local solveFrom = originPos + Vector3.new(0, 2, 0)
		local calc, _impact, flightTime = prediction.SolveTrajectory(
			solveFrom,
			projSpeed,
			gravity,
			leadPos,
			solverVel,
			playerGravity,
			ent.HipHeight or 2,
			ent.Jumping and 42.6 or nil,
			sharedFastHitsRayParams,
			(ent.Humanoid and ent.Humanoid.FloorMaterial == Enum.Material.Air) or math.abs(rawVel.Y) > 0.01,
			targetPart.Position,
			targetPart,
			nil,
			true
		)

		if calc then
			local bow = bedwars.BowConstantsTable or {}
			local spawn = prediction.GetSpawnPosition(solveFrom, calc, bow.RelX or 0.8, bow.RelY or -0.6, bow.RelZ or 0)
			local calc2, _, flight2 = prediction.SolveTrajectory(spawn, projSpeed, gravity, leadPos, solverVel, playerGravity, ent.HipHeight or 2, ent.Jumping and 42.6 or nil, sharedFastHitsRayParams, (ent.Humanoid and ent.Humanoid.FloorMaterial == Enum.Material.Air) or math.abs(rawVel.Y) > 0.01, targetPart.Position, targetPart, nil, true)
			if calc2 and flight2 then
				calc = solveFrom + (calc2 - spawn)
				flightTime = flight2
			end
		end
		local lifetime = tonumber(overrides.predictionLifetimeOverride)
			or tonumber(meta.predictionLifetimeSec)
			or tonumber(overrides.lifetimeOverride)
			or tonumber(meta.lifetimeSec)
			or (projSpeed > 0 and math.min(3, 120 / projSpeed) or 3)

		if not calc or (flightTime and flightTime > lifetime) or fireWait(flightTime or estFlight) > 0.35 then
			ProjectileDelay[item.itemType] = tick() + 0.3

			if ownsBusy then
				fhRestoreSword()
				clearFHBusy(busyToken)
			end

			return false
		end

		local waitFor = fireWait(flightTime or estFlight)
		if waitFor > 0 then
			task.wait(waitFor)
			if not ent.RootPart or not ent.RootPart.Parent then
				if ownsBusy then
					fhRestoreSword()
					clearFHBusy(busyToken)
				end
				return false
			end
			local _, freshRaw = smoothedVelocity(ent, targetPart)
			local freshLead = aimPart.Position + Vector3.new(0, aimOffset, 0)
			local c1, _, f1 = prediction.SolveTrajectory(solveFrom, projSpeed, gravity, freshLead, freshRaw, playerGravity, ent.HipHeight or 2, ent.Jumping and 42.6 or nil, sharedFastHitsRayParams, (ent.Humanoid and ent.Humanoid.FloorMaterial == Enum.Material.Air) or math.abs(freshRaw.Y) > 0.01, targetPart.Position, targetPart, nil, true)
			if c1 then
				local bow = bedwars.BowConstantsTable or {}
				local s1 = prediction.GetSpawnPosition(solveFrom, c1, bow.RelX or 0.8, bow.RelY or -0.6, bow.RelZ or 0)
				local c2, _, f2 = prediction.SolveTrajectory(s1, projSpeed, gravity, freshLead, freshRaw, playerGravity, ent.HipHeight or 2, ent.Jumping and 42.6 or nil, sharedFastHitsRayParams, (ent.Humanoid and ent.Humanoid.FloorMaterial == Enum.Material.Air) or math.abs(freshRaw.Y) > 0.01, targetPart.Position, targetPart, nil, true)
				calc = c2 and (solveFrom + (c2 - s1)) or c1
				flightTime = f2 or f1
			end
		end

		local shootPos = solveFrom
		local dir = (calc - solveFrom).Unit

		local launchHandler = {
			gravityMultiplier = 1,
			velocityMultiplier = minScalar + (1 - minScalar) * chargeRatio,
			projectile = projectile,
			targetPoint = calc,
			fromPositionOffset = Vector3.new(0, 2, 0),
			drawDurationSeconds = drawTime,
			player = lplr
		}

		function launchHandler:getProjectileMeta()
			return bedwars.ProjectileMeta[self.projectile]
		end

		local launchValues

		if launchValues
			and launchValues.positionFrom
			and launchValues.initialVelocity
			and launchValues.initialVelocity.Magnitude > 0.001 then

			shootPos = launchValues.positionFrom
			projSpeed = launchValues.initialVelocity.Magnitude
			dir = launchValues.initialVelocity.Unit
		end

		local id = fhGenId()

		local shotMeta = {
			shotId = fhGenId(),
			drawDurationSec = drawTime
		}

		pcall(function()
			targetinfo.Targets[ent] = tick() + 1
		end)

		ProjectileDelay[item.itemType] = tick() + fhGetCooldown(itemMeta)
		if blocksNext then
			fhLastImpact = tick() + (flightTime or estFlight)
		end

		local localProjectile

		if not isFireball then
			pcall(function()
				localProjectile = bedwars.ProjectileController:createLocalProjectile(
					itemMeta,
					ammo,
					projectile,
					shootPos,
					id,
					dir * projSpeed,
					shotMeta,
					nil,
					nil,
					item.tool
				)
			end)
		end

		local requestStarted = false

		task.spawn(function()
			requestStarted = true

			local sentAt = tick()

			local ok, res = pcall(function()
				return projectileRemote:InvokeServer(
					item.tool,
					ammo,
					projectile,
					shootPos,
					selfPos,
					dir * projSpeed,
					id,
					shotMeta,
					workspace:GetServerTimeNow() - 0.045
				)
			end)

			local took = tick() - sentAt

			if took > 0.35 then
				warn('[aerov4] fasthits server took ' .. math.floor(took * 1000) .. 'ms')
			end

			if not ok or not res or not res.PrimaryPart then
				if localProjectile and localProjectile.Parent then
					pcall(function()
						localProjectile:Destroy()
					end)
				end

				local pd = ProjectileDelay[item.itemType] or 0
				local alt = tick() + (tonumber(itemMeta.fireDelaySec) or 0.5) + 0.1

				if alt > pd then
					ProjectileDelay[item.itemType] = alt
				end

				return
			end

			pcall(function()
				res.Parent = replicatedStorage
			end)
			pcall(prediction.trackShot, targetPart)

			local sound = itemMeta.launchSound
			sound = sound and sound[math.random(1, #sound)] or nil

			if sound and bedwars.SoundManager then
				pcall(function()
					bedwars.SoundManager:playSound(sound)
				end)
			end
		end)

		repeat
			task.wait()
		until requestStarted

		if switched and ownsBusy then
			fhRestoreSword()
			clearFHBusy(busyToken)
		end

		return true
	end

	local function shootKitWeapon(item, ammo, projectile, selfPos, ent, batch)
		if not ent or not ent.RootPart then return false end

		local meta = bedwars.ItemMeta[item.itemType]
		if not meta then return false end

		local pmeta = bedwars.ProjectileMeta[projectile]
		if not pmeta then return false end

		local projSpeed = pmeta.launchVelocity
		local gravity = tonumber(pmeta.gravitationalAcceleration)

		if gravity == nil then gravity = 196.2 end
		if gravity < 1 then gravity = 0 end

		local targetPart = ent.RootPart
		local playerGravity = targetGravity(ent)

		local smoothVel, rawVel = smoothedVelocity(ent, targetPart)
		smoothVel = Vector3.new(smoothVel.X, rawVel.Y, smoothVel.Z)

		local chestPos = targetPart.Position + Vector3.new(0, (ent.HipHeight or 2) * 0.15, 0)

		setFHFilter(ent.Character)

		local calc = prediction.SolveTrajectory(
			selfPos,
			projSpeed,
			gravity,
			chestPos,
			rawVel,
			playerGravity,
			ent.HipHeight or 2,
			ent.Jumping and 42.6 or nil,
			sharedFastHitsRayParams,
			(ent.Humanoid and ent.Humanoid.FloorMaterial == Enum.Material.Air) or math.abs(rawVel.Y) > 0.01,
			targetPart.Position,
			targetPart,
			nil,
			true
		)

		if not calc or (calc - targetPart.Position).Magnitude > 50 then
			calc = chestPos
		end

		local muzzlePos = selfPos + Vector3.new(0, 1.5, 0)
		local firePos = selfPos - Vector3.new(0, 0.5, 0)
		local dir = CFrame.lookAt(muzzlePos, calc).LookVector
		local id = httpService:GenerateGUID(true)

		local busyToken
		local ownsBusy = not batch

		if ownsBusy then
			busyToken = setFHBusy()
		end

		if not fhEquipAwait(item.tool) then
			if ownsBusy then
				fhRestoreSword()
				clearFHBusy(busyToken)
			end
			return false
		end

		pcall(function()
			frostyGunRemote:FireServer({keyHold = true})
		end)

		pcall(function()
			frostyGunRemote:FireServer({keyHold = false})
		end)

		local fireDelay = (meta.fireDelaySec or 0.7) + 0.05

		targetinfo.Targets[ent] = tick() + 1
		ProjectileDelay[item.itemType] = tick() + fireDelay

		local drawDur = 0.8 + math.random() * 0.8

		task.spawn(function()
			local res = projectileRemote:InvokeServer(
				item.tool,
				nil,
				projectile,
				muzzlePos,
				firePos,
				dir * projSpeed,
				id,
				{
					shotId = httpService:GenerateGUID(false),
					drawDurationSec = drawDur
				},
				workspace:GetServerTimeNow() - 0.045
			)

			if res then
				pcall(function()
					res.Parent = replicatedStorage
				end)
			else
				ProjectileDelay[item.itemType] = tick() + fireDelay
			end
		end)

		if ownsBusy then
			fhRestoreSword()
			clearFHBusy(busyToken)
		end

		return true
	end

	local mageSpellMap = {
		base = 'mage_spell_base',
		nature = 'mage_spell_nature',
		fire = 'mage_spell_fire',
		ice = 'mage_spell_ice'
	}

	local function getMageSpell()
		local ok, spell = pcall(function()
			local idx = lplr:GetAttribute('MageElementIndex') or 0
			local cycle = bedwars.BalanceFile and bedwars.BalanceFile.MAGE_ELEMENT_CYCLE
			local element = cycle and cycle[idx + 1]

			if not element then
				return 'mage_spell_base'
			end

			local elLower = string.lower(tostring(element))
			local unlocked = lplr:GetAttribute(elLower)

			if not unlocked or unlocked == 0 then
				return 'mage_spell_base'
			end

			return mageSpellMap[elLower] or 'mage_spell_base'
		end)

		return ok and spell or 'mage_spell_base'
	end

	local kitAmmoMap = {
		frost_staff = {
			base = 'frosty_snowball',
			leveled = true
		},
		ninja_chakram = {
			base = 'ninja_chakram',
			leveled = true
		},
		mage_spellbook = {
			dynamic = 'mage'
		}
	}

	local function getKitWeapon()
		for _, item in store.inventory.inventory.items do
			local itype = string.lower(item.itemType or '')

			for _, kw in kitWeaponList do
				if string.find(itype, kw) then
					local info = kitAmmoMap[kw]

					if not info then continue end

					local ammo

					if info.dynamic == 'mage' then
						ammo = getMageSpell()
					elseif info.leveled then
						ammo = info.base .. '_' .. (itype:match('_(%d+)$') or '1')
					else
						ammo = info.base
					end

					return {
						item,
						ammo,
						ammo,
						nil
					}
				end
			end
		end

		return nil
	end

	local function getGloopItem()
		for _, item in store.inventory.inventory.items do
			if item.itemType == 'glue_projectile' then
				return item
			end
		end

		return nil
	end

	local function getFireballItem()
		for _, item in store.inventory.inventory.items do
			local itype = item.itemType or ''

			if itype:find('fireball') then
				local meta = bedwars.ItemMeta[itype]

				if meta and meta.projectileSource then
					return {
						item,
						itype,
						meta.projectileSource.projectileType(itype),
						meta.projectileSource
					}
				end
			end
		end

		return nil
	end

	local function isGlooped(ent)
		local char = ent and ent.Character
		if not char then return false end

		local val = char:GetAttribute('GlueSlow')
		return val ~= nil and val ~= 0
	end

	local function shootGloop(item, ent, batch)
		if not ent or not ent.RootPart then return false end

		local key = tostring(ent)
		local now = tick()
		local tracked = gloopTracker[key]

		if tracked and tracked.target == ent then
			if tracked.gloopedUntil and now < tracked.gloopedUntil then
				return false
			end

			if tracked.lastShot and (now - tracked.lastShot) < 3 then
				return false
			end
		end

		if isGlooped(ent) then
			gloopTracker[key] = {
				target = ent,
				lastShot = now,
				gloopedUntil = now + 8
			}
			return false
		end

		local myRoot = entitylib.character and entitylib.character.RootPart
		if not myRoot then return false end

		if (ent.RootPart.Position - myRoot.Position).Magnitude > 45 then
			return false
		end

		local selfPos = myRoot.Position
		local targetPart = ent.RootPart
		local gmeta = bedwars.ProjectileMeta.glue_trap
		local gSpeed = tonumber(gmeta and gmeta.launchVelocity) or 100
		local gGrav = tonumber(gmeta and gmeta.gravitationalAcceleration) or 85

		if gGrav < 1 then
			gGrav = 0
		end

		local gitem = bedwars.ItemMeta[item.itemType]
		local gMax = tonumber(gitem and gitem.maxStrengthChargeSec) or 0
		local gMin = tonumber(gitem and gitem.minStrengthScalar) or 1
		local gPct = FastHitsAutoCharge and FastHitsAutoCharge.Enabled
			and math.clamp(ArrowCharge.Value / 100, 0, 1)
			or 0
		local gRatio = gMax > 0 and gPct or 1

		gSpeed = gSpeed * (gMin + (1 - gMin) * gRatio)

		local smoothVel, rawVel = smoothedVelocity(ent, targetPart)
		smoothVel = Vector3.new(smoothVel.X, rawVel.Y, smoothVel.Z)

		local playerGravity = targetGravity(ent)
		local aimPos = targetPart.Position

		setFHFilter(ent.Character)

		local originPos = selfPos + Vector3.new(0, 1.5, 0)

		local calc, _gImpact, gFlight = prediction.SolveTrajectory(
			originPos,
			gSpeed,
			gGrav,
			aimPos,
			rawVel,
			playerGravity,
			ent.HipHeight or 2,
			ent.Jumping and 42.6 or nil,
			sharedFastHitsRayParams,
			(ent.Humanoid and ent.Humanoid.FloorMaterial == Enum.Material.Air) or math.abs(rawVel.Y) > 0.01,
			targetPart.Position,
			targetPart,
			nil,
			true
		)

		local gLife = tonumber(gmeta and gmeta.predictionLifetimeSec) or 2

		if not calc or (gFlight and gFlight > gLife) then
			return false
		end

		local dir = CFrame.lookAt(originPos, calc).LookVector
		local busyToken
		local ownsBusy = not batch

		if ownsBusy then
			busyToken = setFHBusy()
		end

		if not fhEquipAwait(item.tool) then
			if ownsBusy then
				fhRestoreSword()
				clearFHBusy(busyToken)
			end
			return false
		end

		local gok, gerr = pcall(function()
			local weaponInst = item.tool
			local inv = replicatedStorage:FindFirstChild('Inventories')
			local mine = inv and inv:FindFirstChild(lplr.Name)
			local w = mine and mine:FindFirstChild(item.itemType)

			if w then
				weaponInst = w
			end

			glueRemote:InvokeServer(
				weaponInst,
				item.itemType,
				'glue_trap',
				originPos,
				selfPos,
				dir * gSpeed,
				httpService:GenerateGUID(true):sub(1, 8):upper(),
				{
					shotId = httpService:GenerateGUID(true):sub(1, 8):upper(),
					drawDurationSec = 0.05
				},
				workspace:GetServerTimeNow() - 0.045
			)
		end)

		if not gok then
			warn('[aerov4] gloop failed: '..tostring(gerr))

			if ownsBusy then
				fhRestoreSword()
				clearFHBusy(busyToken)
			end

			return false
		end

		gloopTracker[key] = {
			target = ent,
			lastShot = now
		}

		if ownsBusy then
			fhRestoreSword()
			clearFHBusy(busyToken)
		end

		return true
	end

	local fhStage = 1
	local fhTurn = 1
	local function doFastHitsNEW(ent, meleeRange)
		if not ent or not ent.RootPart or not entitylib.isAlive then
			return false
		end

		local selfPos = entitylib.character.RootPart.Position
		local burstToken
		local fired = false

		local function beginBurst()
			if not burstToken then
				burstToken = setFHBusy()
			end
		end

		local function canSpend(cost)
			return fhWindowOpen(ent, meleeRange, cost)
		end

		local tries = {}
		if Gloops and Gloops.Enabled then
			table.insert(tries, function()
				if not canSpend(0.055) then return false end
				local gloopItem = getGloopItem()
				if not gloopItem then return false end
				beginBurst()
				return shootGloop(gloopItem, ent, true)
			end)
		end
		if Arrows and Arrows.Enabled then
			table.insert(tries, function()
				if not canSpend(0.055) then return false end
				local src = getProjectiles()
				local ready
				for _i = 1, #src do
					local p = src[_i]
					if p and tick() > (ProjectileDelay[p[1].itemType] or 0) + 0.03 then
						ready = p
						break
					end
				end
				if not ready then return false end
				beginBurst()
				return shootProjectile(ready[1], ready[2], ready[3], ready[4], selfPos, ent, false, true)
			end)
		end
		if Fireball and Fireball.Enabled then
			table.insert(tries, function()
				if not canSpend(0.055) then return false end
				local fb = getFireballItem()
				if not fb or not canShoot(fb) then return false end
				beginBurst()
				return shootProjectile(fb[1], fb[2], fb[3], fb[4], selfPos, ent, false, true)
			end)
		end
		if Kits and Kits.Enabled then
			table.insert(tries, function()
				if not canSpend(0.06) then return false end
				local kw = getKitWeapon()
				if not kw or not canShoot(kw) then return false end
				beginBurst()
				return shootKitWeapon(kw[1], kw[2], kw[3], selfPos, ent, true)
			end)
		end
		local count = #tries
		for i = 0, count - 1 do
			local idx = (fhTurn + i - 1) % count + 1
			if tries[idx]() then
				fired = true
				fhTurn = idx % count + 1
				break
			end
		end

		if burstToken then
			fhRestoreSword()
			clearFHBusy(burstToken)
		end

		return fired
	end

	local function doFastHitsLegitSwitch(ent)
		if not ent or not ent.RootPart or not entitylib.isAlive then
			return false
		end

		local selfPos = entitylib.character.RootPart.Position
		local projectiles = getProjectiles()

		if not projectiles or #projectiles == 0 then
			return false
		end

		local readyProj

		for _, proj in projectiles do
			if proj and canShoot(proj) then
				readyProj = {
					proj[1],
					proj[2],
					proj[3],
					proj[4]
				}
				break
			end
		end

		if not readyProj then
			return false
		end

		local item, ammo, projectile, itemMeta = unpack(readyProj)
		local bowSlot, swordSlot
		local originalSlot = store.inventory.hotbarSlot
		local hotbar = store.inventory.hotbar

		for i = 1, #hotbar do
			local hv = hotbar[i]

			if hv and hv.item and hv.item.itemType then
				if hv.item.itemType == item.itemType and not bowSlot then
					bowSlot = i - 1
				end

				local hm = bedwars.ItemMeta[hv.item.itemType]

				if hm and hm.sword and not swordSlot then
					swordSlot = i - 1
				end
			end
		end

		if not bowSlot then
			return false
		end

		local token = setFHBusy()

		if hotbarSwitch(bowSlot) then
			task.wait(0.03)
		end

		local fired = shootProjectile(
			item,
			ammo,
			projectile,
			itemMeta,
			selfPos,
			ent,
			true,
			true
		)

		hotbarSwitch(swordSlot or originalSlot)
		clearFHBusy(token)

		return fired and true or false
	end

	local function doFastHits()
		if not FastHits or not FastHits.Enabled then return end
		if not Killaura or not Killaura.Enabled then return end
		if not entitylib.isAlive then return end

		recoverFastHitState()

		if Limit and Limit.Enabled then
			if not store.hand or store.hand.toolType ~= 'sword' then
				return
			end

			if bedwars.DaoController and bedwars.DaoController.chargingMaid then
				return
			end
		end

		local srvNow = workspace:GetServerTimeNow()

		if srvNow - fhLastShotTime < 0.2 then
			return
		end

		local selfRoot = entitylib.character and entitylib.character.RootPart
		if not selfRoot then return end

		local meleeRange = AttackRange.Value + 2
		local fhRange = 60
		local ent = store.KillauraTarget

		if not ent
			or not ent.RootPart
			or not ent.Character
			or not ent.Character.Parent
			or not fhInAngle(ent) then
			return
		end

		if (ent.RootPart.Position - selfRoot.Position).Magnitude > fhRange then
			return
		end

		if not fhWindowOpen(ent, meleeRange, 0.05) then
			return
		end

		local budgetNow = tick()
		fhEquipBudget.tokens = math.min(fhEquipBudget.tokens + (budgetNow - fhEquipBudget.stamp) * 4, 4)
		fhEquipBudget.stamp = budgetNow
		if fhEquipBudget.tokens < 2 then
			return
		end
		fhEquipBudget.tokens -= 2

		fhLastShotTime = srvNow
		local fired

		if LegitSwitch and LegitSwitch.Enabled then
			fired = doFastHitsLegitSwitch(ent)
		else
			fired = doFastHitsNEW(ent, meleeRange)
		end
		if fired then
			local kinds = 0
			for _, opt in {Gloops, Arrows, Fireball, Kits} do
				if opt and opt.Enabled then
					kinds += 1
				end
			end
			if kinds > 1 then
				fhLastShotTime = srvNow + 0.5
			end
		end
	end

	local function startAutoShootLoop()
		if autoShootLoop then return end

		if not ProjectileDelay then
			ProjectileDelay = {}
		end

		fhUsageIndex = 1
		fhStage = 1
		table.clear(ProjectileDelay)

		autoShootLoop = task.spawn(function()
			while Killaura and Killaura.Enabled and FastHits and FastHits.Enabled do
				pcall(doFastHits)
				runService.Heartbeat:Wait()
			end

			clearFHBusy()
			autoShootLoop = nil
		end)
	end

	local function stopAutoShootLoop()
		if autoShootLoop then
			pcall(task.cancel, autoShootLoop)
			autoShootLoop = nil
		end

		if ProjectileDelay then
			table.clear(ProjectileDelay)
		end

		table.clear(_fhVelHistory)
		table.clear(gloopTracker)

		fhUsageIndex = 1
		fhStage = 1

		fhBusyToken = fhBusyToken + 1
		fhBusy = false
		fhBusySince = 0
		fhLastImpact = 0
		fhSwordPending = false

		store._fhBusySince = nil
		store._fhShotAt = nil
		store._fhIdle = nil
	end

	local auraBoxes, auraSparks = {}, {}
	local MaxTargets, MouseOnly, ShowBoxes, BoxIdle, BoxHit
	local SparkTexture, SparkStart, SparkEnd, SparkSize
	local swingSaved, scytheSaved

	local budget = {tokens = 4, stamp = os.clock()}
	local function spendToken()
		local now = os.clock()
		budget.tokens = math.min(budget.tokens + (now - budget.stamp) * 4.5, 4)
		budget.stamp = now
		if budget.tokens < 1 then return false end
		budget.tokens -= 1
		return true
	end

	local strike = {nextAt = 0, interval = nil, cooldown = 0.3, lastSrv = 0, used = 0, frame = 1 / 60, minr = 0.982, log = {}, good = 0, total = 0, since = 0}
	local RangeCircle, rangeRing
	local probe = {buf = {}, stats = {}, nextFlush = 0, started = os.clock(), sendTimes = {}, lastLand = nil}

	local function probeLine(text)
		if #probe.buf < 700 then
			table.insert(probe.buf, string.format('%.3f ', os.clock() - probe.started) .. text)
		end
	end

	local function probeCount(key)
		probe.stats[key] = (probe.stats[key] or 0) + 1
	end

	local function probeName(thing)
		if typeof(thing) == 'Instance' then
			return thing.ClassName .. ':' .. thing.Name
		end
		return typeof(thing) .. ':' .. tostring(thing)
	end

	local function probeFlush(force)
		local now = os.clock()
		if not force and now < probe.nextFlush then return end
		probe.nextFlush = now + 1
		while probe.sendTimes[1] and probe.sendTimes[1] < now - 60 do
			table.remove(probe.sendTimes, 1)
		end
		local keys = {}
		for key, value in probe.stats do
			table.insert(keys, key .. '=' .. value)
		end
		table.sort(keys)
		local blade = store.tools.sword
		local info = blade and blade.tool and bedwars.ItemMeta[blade.tool.Name]
		local head = {
			'==== killaura debug ====',
			string.format('running %.1fs  sends in last 60s %d', now - probe.started, #probe.sendTimes),
			string.format('sword %s  cooldown %s  gap %.3f  ping %.3f', blade and blade.tool and blade.tool.Name or 'none', tostring(info and info.sword and info.sword.attackSpeed), strike.interval or 0, lplr:GetNetworkPing()),
			'counts: ' .. table.concat(keys, ', '),
			''
		}
		pcall(writefile, 'aerov4/kadebug.txt', table.concat(head, '\n') .. table.concat(probe.buf, '\n'))
	end

	local function canStrike()
		local character = entitylib.character
		if not entitylib.isAlive or not character or character.Character ~= lplr.Character
			or not character.RootPart or not character.RootPart.Parent then
			return false, 'dead'
		end
		if MouseOnly.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			return false, 'mouse'
		end
		if GUI.Enabled and bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
			return false, 'gui'
		end
		if bedwars.SwordController and bedwars.SwordController.disableSwingState then
			return false, 'swingoff'
		end
		local stunned = lplr.Character and lplr.Character:GetAttribute('StunnedUntilTime')
		if stunned and stunned > workspace:GetServerTimeNow() then
			return false, 'stun'
		end
		if AttackCheck and AttackCheck.Enabled then
			if kitChecks then
				for _, check in pairs(kitChecks) do
					local ok, res = pcall(check)
					if ok and res then return false, 'kit' end
				end
			end
			if tick() - (store.silasAbilityTime or 0) < 2.2 then return false, 'kit' end
			if tick() - (store.terraStompTime or 0) < 0.7 then return false, 'kit' end
			if tick() - (store.terraKickTime or 0) < 0.5 then return false, 'kit' end
		end
		if fastHitBlocksSword() then
			return false, 'fasthits'
		end
		local blade = store.tools.sword
		if not blade or not blade.tool or not blade.tool.Parent then return false, 'nosword' end
		local info = bedwars.ItemMeta[blade.tool.Name]
		if not info or not info.sword then return false, 'nometa' end
		if Limit.Enabled then
			local hand = lplr.Character and lplr.Character:FindFirstChild('HandInvItem')
			if not hand or hand.Value ~= blade.tool or (bedwars.DaoController and bedwars.DaoController.chargingMaid) then
				return false, 'limit'
			end
		end
		return blade, info
	end

	local function noteLanded(target)
		local now = os.clock()
		for _, entry in strike.log do
			if not entry.ok and not entry.done and entry.target == target then
				local age = now - entry.t
				if age > 0.01 and age < 0.8 then
					entry.ok = true
					return
				end
			end
		end
	end

	local function tune()
		local now = os.clock()
		local settle = math.clamp(lplr:GetNetworkPing() * 2 + 0.15, 0.25, 0.6)
		for _, entry in strike.log do
			if not entry.done and now - entry.t > settle then
				entry.done = true
				local body = entry.target
				local hum = body and body.Parent and body:FindFirstChildOfClass('Humanoid')
				if not entry.far and hum and hum.Health > 0 and not body:FindFirstChildOfClass('ForceField') then
					strike.total += 1
					if entry.ok then
						strike.good += 1
					end
				end
			end
		end
		strike.since += 1
		if strike.total < 20 or strike.since < 4 then return end
		strike.since = 0
		local rate = strike.good / strike.total
		if rate >= 0.97 then
			strike.minr = math.max(strike.minr - 0.003, 0.982)
		elseif rate < 0.8 then
			strike.minr = math.min(strike.minr + 0.006, 1.03)
		end
		strike.good *= 0.5
		strike.total *= 0.5
	end

	local function swingReady(cooldown)
		if not LegitAura.Enabled then return true end
		local swung = bedwars.SwordController and bedwars.SwordController.lastSwing or 0
		return swung > strike.used and tick() - swung <= math.max(cooldown, 0.3) + 0.1
	end

	local function nextOpen(info, blade)
		local cooldown = getWeaponAttackSpeed(blade, info) * furyMultiplier()
		strike.cooldown = cooldown
		strike.interval = math.max(cooldown * (strike.minr + 0.008) - strike.frame * 0.5, cooldown * strike.minr)
		local sc = bedwars.SwordController
		local last = sc and sc.lastAttack or 0
		if last > strike.lastSrv + 0.005 then
			strike.lastSrv = last
			local at = os.clock() - math.max(workspace:GetServerTimeNow() - last, 0)
			strike.nextAt = math.max(strike.nextAt, at + strike.interval)
		end

		return strike.nextAt, cooldown
	end

	local function setSwingBuffer(on)
		pcall(function()
			local consts = require(replicatedStorage.TS.combat['combat-constant']).SwordsConstants
			if table.isfrozen(consts) and setreadonly then
				setreadonly(consts, false)
			end
			if on then
				if oldSwingBuffer == nil then
					oldSwingBuffer = consts.swordSwingBufferMultiplier
				end
				consts.swordSwingBufferMultiplier = 0
			elseif oldSwingBuffer ~= nil then
				consts.swordSwingBufferMultiplier = oldSwingBuffer
				oldSwingBuffer = nil
			end
		end)
	end

	local function swapViewmodel(on)
		pcall(function()
			local swingFn = bedwars.SwordController.playSwordEffect
			local scytheFn = bedwars.ScytheController.playLocalAnimation
			if on then
				swingSaved = swingSaved or debug.getupvalue(swingFn, 7)
				scytheSaved = scytheSaved or debug.getupvalue(scytheFn, 3)
				local stand = {
					Controllers = setmetatable({
						ViewmodelController = {
							isVisible = function()
								return not Attacking
							end,
							playAnimation = function(...)
								if not Attacking then
									bedwars.ViewmodelController:playAnimation(select(2, ...))
								end
							end
						}
					}, {__index = swingSaved and swingSaved.Controllers})
				}
				debug.setupvalue(swingFn, 7, stand)
				debug.setupvalue(scytheFn, 3, stand)
			else
				if swingSaved then debug.setupvalue(swingFn, 7, swingSaved) end
				if scytheSaved then debug.setupvalue(scytheFn, 3, scytheSaved) end
			end
		end)
	end

	local function resetAuraCharacter()
		stopAutoShootLoop()
		strike.nextAt, strike.interval = 0, nil
		strike.used, strike.lastSrv = 0, 0
		table.clear(strike.log)
		lastTargetTime, AnimDelay, armC0 = 0, 0, nil
		if AnimTween then AnimTween:Cancel() end
		AnimTween = nil
		Attacking = false
		getgenv().Attacking = false
		store.KillauraTarget = nil
		if rangeRing then rangeRing.Adornee = nil end
		for _, box in auraBoxes do box.Adornee = nil end
		for _, spark in auraSparks do spark.Parent = nil end
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				Killaura:Clean(entitylib.Events.LocalRemoved:Connect(resetAuraCharacter))
				Killaura:Clean(entitylib.Events.LocalAdded:Connect(function()
					resetAuraCharacter()
					if Killaura.Enabled and FastHits.Enabled then startAutoShootLoop() end
				end))
				lastTargetTime = 0
				strike.nextAt, strike.interval = 0, nil
				strike.used, strike.lastSrv = 0, 0
				table.clear(strike.log)
				strike.good, strike.total, strike.since = 0, 0, 0
				Killaura:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(hit)
					local from = hit.fromEntity
					if (from == lplr.Character or from == lplr) and hit.entityInstance and hit.entityInstance ~= lplr.Character and hit.damageType == 0 then
						noteLanded(hit.entityInstance)
					end
				end))
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
					end)
				end

				setSwingBuffer(true)
				if FastHits.Enabled then
					startAutoShootLoop()
				end

				if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
					swapViewmodel(true)
					cleanThread(Killaura, task.spawn(function()
						local going = false
						local lastWrist
						repeat
							local viewmodel = gameCamera and gameCamera:FindFirstChild('Viewmodel')
							local hand = viewmodel and viewmodel:FindFirstChild('RightHand')
							local wrist = hand and hand:FindFirstChild('RightWrist')
							if not entitylib.isAlive or not wrist then
								going, lastWrist = false, nil
								task.wait(0.05)
								continue
							end
							if wrist ~= lastWrist then
								lastWrist, armC0, going = wrist, wrist.C0, false
							end
							if Attacking then
								if not armC0 then
									armC0 = wrist.C0
								end
								local fresh = not going
								going = true
								if AnimationMode.Value == 'Random' then
									anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
								end
								for _, step in anims[AnimationMode.Value] do
									if not entitylib.isAlive or not wrist.Parent or not armC0 or wrist ~= lastWrist then break end
									AnimTween = tweenService:Create(wrist, TweenInfo.new(fresh and (AnimationTween.Enabled and 0.001 or 0.1) or step.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
										C0 = armC0 * step.CFrame
									})
									AnimTween:Play()
									AnimTween.Completed:Wait()
									if not entitylib.isAlive or not armC0 then break end
									fresh = false
									if not Killaura.Enabled or not Attacking then break end
								end
							elseif going and armC0 then
								going = false
								AnimTween = tweenService:Create(wrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
									C0 = armC0
								})
								AnimTween:Play()
							end
							if not going then
								task.wait(1 / 60)
							end
						until not Killaura.Enabled or not Animation.Enabled
					end))
				end

				repeat
					local marked = {}
					local blade, info = canStrike()
					Attacking = false
					getgenv().Attacking = false
					store.KillauraTarget = nil
					if blade and entitylib.isAlive then
						local near = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = MaxTargets.Value,
							Sort = sortmethods[Sort.Value]
						})

						if #near > 0 then
							if not Limit.Enabled and not fhBusy then
								switchItem(blade.tool, 0)
							end
							local myRoot = entitylib.character.RootPart
							local here = myRoot.Position
							local facing = myRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
							local fired = false

							for _, foe in near do
								if not entitylib.isAlive or not myRoot.Parent then break end
								if not foe.RootPart or not foe.RootPart.Parent or not foe.Character or not foe.Character.Parent then continue end
								local gap = foe.RootPart.Position - here
								local flatGap = gap * Vector3.new(1, 0, 1)
								if flatGap.Magnitude > 0.5 and facing.Magnitude > 0.001 then
									local turn = math.acos(math.clamp(facing.Unit:Dot(flatGap.Unit), -1, 1))
									if turn > math.rad(AngleSlider.Value) / 2 then continue end
								end

								table.insert(marked, {
									Entity = foe,
									Check = gap.Magnitude > AttackRange.Value and BoxIdle or BoxHit
								})
								lastTargetTime = tick()
								targetinfo.Targets[foe] = tick() + 1

								if not Attacking then
									Attacking = true
									getgenv().Attacking = true
									store.KillauraTarget = foe
									local furySwing = LegitAura.Enabled and furyMultiplier() < 1
									if not Swing.Enabled and AnimDelay < tick() and (not LegitAura.Enabled or furySwing) and store.hand and store.hand.tool == blade.tool then
										local effectSpeed = (info.sword.respectAttackSpeedForEffects and info.sword.attackSpeed or 0.11) * furyMultiplier()
										AnimDelay = tick() + math.max(effectSpeed, 0.1111111111111111)
										pcall(function()
											bedwars.SwordController:playSwordEffect(info, false)
											if info.displayName and info.displayName:find(' Scythe') then
												bedwars.ScytheController:playLocalAnimation()
											end
										end)
										if vape.ThreadFix then
											setthreadidentity(8)
										end
									end
								end

								if fired or gap.Magnitude > AttackRange.Value then continue end

								local body = foe.Character and (foe.Character.PrimaryPart or foe.RootPart)
								if body then
									local openAt, cooldown = nextOpen(info, blade)
									kaPeriod = cooldown
									if os.clock() >= openAt and swingReady(cooldown) and spendToken() then
										local selfChar = lplr.Character
										local targetChar = foe.Character
										local selfRoot = selfChar and (selfChar.PrimaryPart or entitylib.character.RootPart)
										local targetRoot = targetChar and (targetChar.PrimaryPart or foe.RootPart)
										if not selfRoot or not targetRoot or not targetChar.Parent then continue end

										local selfNow = selfChar:GetPivot().Position
										local targetNow = targetChar:GetPivot().Position
										local liveGap = targetNow - selfNow
										if liveGap.Magnitude > AttackRange.Value then continue end

										local swordRange = info.sword and info.sword.attackRange
										local baseReach = type(swordRange) == 'number' and swordRange > 0 and swordRange or SERVER_REACH
										local reportReach = math.max(baseReach - 0.001, 0.1)
										local rootNow = selfRoot.Position
										local targetAt = targetRoot.Position
										local aimDir = (targetAt - rootNow).Unit
										local selfReport = rootNow + aimDir * math.max((targetAt - rootNow).Magnitude - reportReach, 0)
										local sentAt = os.clock()

										if FireAttackRemote(blade.tool, targetChar, selfReport, targetAt, aimDir) then
											strike.cooldown = cooldown
											strike.nextAt = sentAt + strike.interval
											table.insert(strike.log, {t = sentAt, ok = false, target = targetChar, far = liveGap.Magnitude > SERVER_REACH})
											if #strike.log > 40 then
												table.remove(strike.log, 1)
											end
											tune()

											if LegitAura.Enabled then
												strike.used = bedwars.SwordController.lastSwing or 0
											end
											kaLastSend = tick()
											fired = true
											bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
											strike.lastSrv = bedwars.SwordController.lastAttack
											store.attackReach = (liveGap.Magnitude * 100) // 1 / 100
											store.attackReachUpdate = tick() + 1
										end
									end
								end
							end
						end
					end

					if not Attacking and blade and info and shouldContinueSwinging() then
						Attacking = true
						getgenv().Attacking = true
						if not Limit.Enabled and not fhBusy then
							switchItem(blade.tool, 0)
						end
						if not Swing.Enabled and AnimDelay < tick() and not LegitAura.Enabled then
							local effectSpeed = (info.sword.respectAttackSpeedForEffects and info.sword.attackSpeed or 0.11) * furyMultiplier()
							AnimDelay = tick() + effectSpeed
							pcall(function()
								bedwars.SwordController:playSwordEffect(info, false)
								if info.displayName and info.displayName:find(' Scythe') then
									bedwars.ScytheController:playLocalAnimation()
								end
							end)
						end
					end

					for i, box in auraBoxes do
						box.Adornee = marked[i] and marked[i].Entity.RootPart or nil
						if box.Adornee then
							box.Color3 = Color3.fromHSV(marked[i].Check.Hue, marked[i].Check.Sat, marked[i].Check.Value)
							box.Transparency = 1 - marked[i].Check.Opacity
						end
					end

					for i, spark in auraSparks do
						spark.Position = marked[i] and marked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						spark.Parent = marked[i] and gameCamera or nil
					end

					if FaceTarget.Enabled and marked[1] then
						local look = marked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
						local myRoot = entitylib.character.RootPart
						myRoot.CFrame = CFrame.lookAt(myRoot.Position, Vector3.new(look.X, myRoot.Position.Y + 0.001, look.Z))
					end
					if rangeRing then
						local ringRoot = entitylib.isAlive and entitylib.character.RootPart or nil
						rangeRing.Adornee = ringRoot
						if ringRoot then
							rangeRing.CFrame = CFrame.new(0, 0.1 - entitylib.character.HipHeight, 0) * CFrame.Angles(math.rad(90), 0, 0)
							rangeRing.Radius = AttackRange.Value
							rangeRing.InnerRadius = math.max(AttackRange.Value - 0.25, 0)
						end
					end
					strike.frame = strike.frame * 0.9 + math.clamp(runService.Heartbeat:Wait(), 0.003, 0.05) * 0.1
				until not Killaura.Enabled
			else
				stopAutoShootLoop()
				setSwingBuffer(false)
				if rangeRing then
					rangeRing.Adornee = nil
				end
				lastTargetTime = 0
				store.KillauraTarget = nil
				for _, box in auraBoxes do
					box.Adornee = nil
				end
				for _, spark in auraSparks do
					spark.Parent = nil
				end
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = true
					end)
				end
				swapViewmodel(false)
				Attacking = false
				getgenv().Attacking = false
				local viewmodel = gameCamera and gameCamera:FindFirstChild('Viewmodel')
				local hand = viewmodel and viewmodel:FindFirstChild('RightHand')
				local wrist = hand and hand:FindFirstChild('RightWrist')
				if armC0 and wrist then
					AnimTween = tweenService:Create(wrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					AnimTween:Play()
				end
			end
		end,
		Tooltip = 'hits ppl around u without aimin at em'
	})

	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	local modes = {'Damage', 'Distance'}
	for name in sortmethods do
		if not table.find(modes, name) then
			table.insert(modes, name)
		end
	end
	SwingRange = Killaura:CreateSlider({
		Name = 'swing range',
		Min = 1,
		Max = 24,
		Default = 20,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'attack range',
		Min = 1,
		Max = 22,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	MaxTargets = Killaura:CreateSlider({
		Name = 'max targets',
		Min = 1,
		Max = 5,
		Default = 5
	})
	Sort = Killaura:CreateDropdown({
		Name = 'target mode',
		List = modes
	})
	MouseOnly = Killaura:CreateToggle({
		Name = 'need mouse down',
		Tooltip = 'only hits while u holdin click'
	})
	Swing = Killaura:CreateToggle({
		Name = 'no swing',
		Tooltip = 'hides ur sword swing'
	})
	GUI = Killaura:CreateToggle({
		Name = 'gui check',
		Tooltip = 'wont hit while a menu is open'
	})
	ShowBoxes = Killaura:CreateToggle({
		Name = 'show target',
		Function = function(callback)
			BoxIdle.Object.Visible = callback
			BoxHit.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					auraBoxes[i] = box
				end
			else
				for _, box in auraBoxes do
					box:Destroy()
				end
				table.clear(auraBoxes)
			end
		end
	})
	BoxIdle = Killaura:CreateColorSlider({
		Name = 'target color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxHit = Killaura:CreateColorSlider({
		Name = 'attack color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'target particles',
		Function = function(callback)
			SparkTexture.Object.Visible = callback
			SparkStart.Object.Visible = callback
			SparkEnd.Object.Visible = callback
			SparkSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local emitter = Instance.new('ParticleEmitter')
					emitter.Brightness = 1.5
					emitter.Size = NumberSequence.new(SparkSize.Value)
					emitter.Shape = Enum.ParticleEmitterShape.Sphere
					emitter.Texture = SparkTexture.Value
					emitter.Transparency = NumberSequence.new(0)
					emitter.Lifetime = NumberRange.new(0.4)
					emitter.Speed = NumberRange.new(16)
					emitter.Rate = 128
					emitter.Drag = 16
					emitter.ShapePartial = 1
					emitter.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(SparkStart.Hue, SparkStart.Sat, SparkStart.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(SparkEnd.Hue, SparkEnd.Sat, SparkEnd.Value))
					})
					emitter.Parent = part
					auraSparks[i] = part
				end
			else
				for _, spark in auraSparks do
					spark:Destroy()
				end
				table.clear(auraSparks)
			end
		end
	})
	SparkTexture = Killaura:CreateTextBox({
		Name = 'texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, spark in auraSparks do
				spark.ParticleEmitter.Texture = SparkTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	SparkStart = Killaura:CreateColorSlider({
		Name = 'color begin',
		Function = function(hue, sat, val)
			for _, spark in auraSparks do
				spark.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(SparkEnd.Hue, SparkEnd.Sat, SparkEnd.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	SparkEnd = Killaura:CreateColorSlider({
		Name = 'color end',
		Function = function(hue, sat, val)
			for _, spark in auraSparks do
				spark.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(SparkStart.Hue, SparkStart.Sat, SparkStart.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	SparkSize = Killaura:CreateSlider({
		Name = 'size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, spark in auraSparks do
				spark.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	FaceTarget = Killaura:CreateToggle({
		Name = 'face target',
		Tooltip = 'turns ur body to who ur hittin'
	})
	Animation = Killaura:CreateToggle({
		Name = 'custom animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationTween.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end
	})
	local animList = {}
	for name in anims do
		table.insert(animList, name)
	end
	AnimationMode = Killaura:CreateDropdown({
		Name = 'animation mode',
		List = animList,
		Darker = true,
		Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
		Name = 'animation speed',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
		Name = 'no tween',
		Darker = true,
		Visible = false
	})
	Limit = Killaura:CreateToggle({
		Name = 'limit to items',
		Function = function(callback)
			if inputService.TouchEnabled and Killaura.Enabled then
				pcall(function()
					lplr.PlayerGui.MobileUI['2'].Visible = callback
				end)
			end
		end,
		Tooltip = 'only hits when ur holdin ur sword'
	})
	LegitAura = Killaura:CreateToggle({
		Name = 'swing only',
		Tooltip = 'only hits when u swing it urself'
	})
	ContinueSwinging = Killaura:CreateToggle({
		Name = 'continue swinging',
		Tooltip = 'keeps swingin for a lil after they leave ur range',
		Function = function(callback)
			if ContinueSwingTime then
				ContinueSwingTime.Object.Visible = callback
			end
		end
	})
	ContinueSwingTime = Killaura:CreateSlider({
		Name = 'swing duration',
		Min = 0.1,
		Max = 3,
		Default = 1,
		Decimal = 10,
		Suffix = 's',
		Darker = true,
		Visible = false
	})

	task.spawn(function()
		local wasAvailable = false
		local availSince = 0

		while vape.Loaded do
			task.wait(0.05)

			if bedwars.AbilityController then
				local ok, nowAvailable = pcall(
					bedwars.AbilityController.canUseAbility,
					bedwars.AbilityController,
					'rebellion_shield'
				)

				if ok then
					nowAvailable = nowAvailable == true

					if nowAvailable and not wasAvailable then
						availSince = tick()
					end

					if wasAvailable
						and not nowAvailable
						and availSince > 0
						and tick() - availSince > 1 then

						store.silasAbilityTime = tick()
					end

					wasAvailable = nowAvailable
				end
			end
		end
	end)

	task.spawn(function()
		local wasStomp = false
		local wasKick = false
		local stompSince = 0
		local kickSince = 0

		while vape.Loaded do
			task.wait(0.05)

			if bedwars.AbilityController then
				local ok1, nowStomp = pcall(
					bedwars.AbilityController.canUseAbility,
					bedwars.AbilityController,
					'BLOCK_STOMP'
				)

				local ok2, nowKick = pcall(
					bedwars.AbilityController.canUseAbility,
					bedwars.AbilityController,
					'BLOCK_KICK'
				)

				if ok1 then
					nowStomp = nowStomp == true

					if nowStomp and not wasStomp then
						stompSince = tick()
					end

					if wasStomp
						and not nowStomp
						and stompSince > 0
						and tick() - stompSince > 1 then

						store.terraStompTime = tick()
					end

					wasStomp = nowStomp
				end

				if ok2 then
					nowKick = nowKick == true

					if nowKick and not wasKick then
						kickSince = tick()
					end

					if wasKick
						and not nowKick
						and kickSince > 0
						and tick() - kickSince > 1 then

						store.terraKickTime = tick()
					end

					wasKick = nowKick
				end
			end
		end
	end)

	kitChecks = {
		['Sophia'] = function()
			return isFrozen(nil, FROZEN_THRESHOLD)
		end,
		['Sigrid'] = function()
			return entitylib.isAlive
				and lplr.Character
				and lplr.Character:FindFirstChild('elk') ~= nil
		end
	}

	AttackCheck = Killaura:CreateToggle({
		Name = 'attack check',
		Tooltip = 'stops ka when ur kit shouldnt be attacking',
		Default = false
	})

	FastHits = Killaura:CreateToggle({
		Name = 'fast hits',
		Default = false,
		Tooltip = 'shoots ur projectiles between sword hits so nothin ghosts',
		Function = function(call)
			if FastHitsAutoCharge then
				FastHitsAutoCharge.Object.Visible = call
			end

			if ArrowCharge then
				ArrowCharge.Object.Visible = call and FastHitsAutoCharge and FastHitsAutoCharge.Enabled
			end

			if LegitSwitch then
				LegitSwitch.Object.Visible = call
			end

			if Kits then
				Kits.Object.Visible = call
			end

			if Arrows then
				Arrows.Object.Visible = call
			end

			if Gloops then
				Gloops.Object.Visible = call
			end

			if Fireball then
				Fireball.Object.Visible = call
			end

			if call then
				if Killaura.Enabled then
					startAutoShootLoop()
				end
			else
				stopAutoShootLoop()
			end
		end
	})

	LegitSwitch = Killaura:CreateToggle({
		Name = 'legit switch',
		Darker = true,
		Visible = false,
		Tooltip = 'swaps to ur projectile, waits for it, shoots, then swaps back'
	})

	Kits = Killaura:CreateToggle({
		Name = 'kits',
		Darker = true,
		Visible = false,
		Tooltip = 'uses kit weapons too'
	})

	Arrows = Killaura:CreateToggle({
		Name = 'arrows',
		Default = true,
		Darker = true,
		Visible = false,
		Tooltip = 'shoots arrows between hits'
	})

	Gloops = Killaura:CreateToggle({
		Name = 'gloops',
		Darker = true,
		Visible = false,
		Tooltip = 'throws gloop at who ur fightin'
	})

	Fireball = Killaura:CreateToggle({
		Name = 'fireball',
		Default = false,
		Darker = true,
		Visible = false,
		Tooltip = 'automatically throws an fireball'
	})

	FastHitsAutoCharge = Killaura:CreateToggle({
		Name = 'auto charge',
		Default = true,
		Darker = true,
		Visible = false,
		Function = function(v)
			if ArrowCharge then
				ArrowCharge.Object.Visible = FastHits.Enabled and v
			end
		end
	})

	ArrowCharge = Killaura:CreateSlider({
		Name = 'charge rate',
		Suffix = '%',
		Min = 0,
		Max = 100,
		Default = 100,
		Darker = true,
		Visible = false
	})
	RangeCircle = Killaura:CreateToggle({
		Name = 'range visualiser',
		Tooltip = 'shows ur attack range on the ground',
		Function = function(callback)
			if callback then
				if not rangeRing then
					rangeRing = Instance.new('CylinderHandleAdornment')
					rangeRing.Height = 0.05
					rangeRing.Transparency = 0.4
					rangeRing.Color3 = Color3.fromRGB(120, 170, 255)
					rangeRing.ZIndex = 0
					rangeRing.Parent = gameCamera
				end
			elseif rangeRing then
				rangeRing:Destroy()
				rangeRing = nil
			end
		end
	})

	task.defer(function()
		local on = FastHits.Enabled

		FastHitsAutoCharge.Object.Visible = on
		ArrowCharge.Object.Visible = on and FastHitsAutoCharge.Enabled
		LegitSwitch.Object.Visible = on
		Kits.Object.Visible = on
		Arrows.Object.Visible = on
		Gloops.Object.Visible = on
		Fireball.Object.Visible = on
	end)
end)
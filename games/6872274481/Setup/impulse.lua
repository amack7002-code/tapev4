run(function()
	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit then break end
		task.wait()
	until KnitInit

	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end

	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Client = require(replicatedStorage.TS.remotes).default.Client
	local OldGet, OldBreak = Client.Get

	local rakNet = false
	--[[AEROV4_NESTED_MODULE_001]]

	bedwars = setmetatable({
		RankMeta = require(replicatedStorage.TS.rank['rank-meta']).RankMeta,
        BalanceFile = require(replicatedStorage.TS.balance["balance-file"]).BalanceFile,
        ClientSyncEvents = require(lplr.PlayerScripts.TS['client-sync-events']).ClientSyncEvents,
        SyncEventPriority = require(replicatedStorage.rbxts_include.node_modules['@easy-games']['sync-event'].out),
		AbilityId = require(replicatedStorage.TS.ability['ability-id']).AbilityId,
        IdUtil = require(replicatedStorage.TS.util['id-util']).IdUtil,
		BlockSelector = require(game:GetService("ReplicatedStorage").rbxts_include.node_modules["@easy-games"]["block-engine"].out.client.select["block-selector"]).BlockSelector,
		KnockbackUtilInstance = replicatedStorage.TS.damage['knockback-util'],
		BedwarsKitSkin = require(replicatedStorage.TS.games.bedwars['kit-skin']['bedwars-kit-skin-meta']).BedwarsKitSkinMeta,
		KitController = Knit.Controllers.KitController,
		FishermanUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.fisherman['fisherman-util']).FishermanUtil,
		FishMeta = require(replicatedStorage.TS.games.bedwars.kit.kits.fisherman['fish-meta']),
	 	MatchHistoryApp = require(lplr.PlayerScripts.TS.controllers.global["match-history"].ui["match-history-moderation-app"]).MatchHistoryModerationApp,
	 	MatchHistoryController = Knit.Controllers.MatchHistoryController,
		BlockEngine = require(game:GetService("ReplicatedStorage").rbxts_include.node_modules["@easy-games"]["block-engine"].out).BlockEngine,
		BlockSelectorMode = require(game:GetService("ReplicatedStorage").rbxts_include.node_modules["@easy-games"]["block-engine"].out.client.select["block-selector"]).BlockSelectorMode,
		EntityUtil = require(game:GetService("ReplicatedStorage").TS.entity["entity-util"]).EntityUtil,
		GamePlayer = require(replicatedStorage.TS.player['game-player']),
		OfflinePlayerUtil = require(replicatedStorage.TS.player['offline-player-util']),
		PlayerUtil = require(replicatedStorage.TS.player['player-util']),
		KKKnitController = require(lplr.PlayerScripts.TS.lib.knit['knit-controller']),
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		CooldownController = Flamework.resolveDependency("@easy-games/game-core:client/controllers/cooldown/cooldown-controller@CooldownController"),
		CooldownIDS = require(replicatedStorage.TS.cooldown["cooldown-id"]).CooldownId,		
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BowConstantsTable = (Knit.Controllers.ProjectileController and Knit.Controllers.ProjectileController.enableBeam) and debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 5) or {},
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
		CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
		SharedConstants = require(replicatedStorage.TS['shared-constants']).CpsConstants,
		DamageIndicator = Knit.Controllers.DamageIndicatorController.spawnDamageIndicator,
		DefaultKillEffect = require(lplr.PlayerScripts.TS.controllers.global.locker['kill-effect'].effects['default-kill-effect']),
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		EmoteMeta = require(replicatedStorage.TS.locker.emote['emote-meta']).EmoteMeta,
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		NotificationController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/notification-controller@NotificationController'),
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		MatchHistoryController = require(lplr.PlayerScripts.TS.controllers.global['match-history']['match-history-controller']),
		PlayerProfileUIController = require(lplr.PlayerScripts.TS.controllers.global['player-profile']['player-profile-ui-controller']),
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = (function()
			local fn = require(replicatedStorage.TS.item['item-meta']).getItemMeta
			for i = 1, 6 do
				local v = debug.getupvalue(fn, i)
				if type(v) == 'table' and next(v) then return v end
			end
			return {}
		end)(),
		KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
		KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		NametagController = Knit.Controllers.NametagController,
		PartyController = Flamework.resolveDependency("@easy-games/lobby:client/controllers/party-controller@PartyController"),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).SoundManager,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 2) or {},
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network),
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	getgenv().bedwars = bedwars

	prediction.Raycast = function(origin, direction, params)
		return bedwars.QueryUtil:raycast(origin, direction, params)
	end

	task.spawn(function()
		repeat
			local localPos = entitylib.isAlive and entitylib.character.RootPart.Position or nil
			local gravityNow, now = workspace.Gravity, tick()
			for _, v in entitylib.List do
				local root = v.RootPart
				if root and root.Parent and v.Targetable then
					local vel = root.AssemblyLinearVelocity
					local moving = vel.Magnitude > 1
					if now - (v.PredObserveTick or 0) >= 1 / 60 then
						v.PredObserveTick = now
						local hum = v.Humanoid
						local airborne = (hum and hum.FloorMaterial == Enum.Material.Air) or math.abs(vel.Y) > 0.01
						pcall(prediction.Observe, root, root.Position, vel, airborne, gravityNow, moving and localPos or nil, v.HipHeight, v.Jumping and 42.6 or nil)
					end
				end
			end
			task.wait()
		until vape.Loaded == nil
	end)

	vape:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
		local character = damageTable.entityInstance
		if typeof(character) ~= 'Instance' then return end
		local root = character:IsA('Model') and character.PrimaryPart or character:IsA('BasePart') and character or nil
		local multiplier = damageTable.knockbackMultiplier
		if not (multiplier and multiplier.disabled) then
			local impulse
			local from = damageTable.fromPosition
			if root and typeof(from) == 'Vector3' then
				pcall(function()
					local direction = bedwars.KnockbackUtil.getDirection(root.Position, from)
					if direction.Magnitude > 0 then
						impulse = bedwars.KnockbackUtil.calculateKnockbackVelocity(direction, 1, multiplier)
					end
				end)
			end
			pcall(prediction.markKnockback, character, multiplier, impulse)
		end
		local attacker = damageTable.fromEntity
		if root and (attacker == lplr.Character or attacker == lplr) then
			pcall(prediction.reportHit, root)
		end
	end))

	local remoteNames = {
		AfkStatus = safeGetProto(Knit.Controllers.AfkController.KnitStart, 1),
		AttackEntity = Knit.Controllers.SwordController.sendServerRequest,
		BeePickup = Knit.Controllers.BeeNetController.trigger,
		CannonAim = safeGetProto(Knit.Controllers.CannonController.startAiming, 5),
		CannonLaunch = Knit.Controllers.CannonHandController.launchSelf,
		ConsumeBattery = safeGetProto(Knit.Controllers.BatteryController.onKitLocalActivated, 1),
		ConsumeItem = safeGetProto(Knit.Controllers.ConsumeController.onEnable, 1),
		ConsumeSoul = Knit.Controllers.GrimReaperController.consumeSoul,
		ConsumeTreeOrb = safeGetProto(Knit.Controllers.EldertreeController.createTreeOrbInteraction, 1),
		DepositPinata = safeGetProto(safeGetProto(Knit.Controllers.PiggyBankController.KnitStart, 2), 5),
		DragonBreath = safeGetProto(Knit.Controllers.VoidDragonController.onKitLocalActivated, 5),
		DragonEndFly = safeGetProto(Knit.Controllers.VoidDragonController.flapWings, 1),
		DragonFly = Knit.Controllers.VoidDragonController.flapWings,
		DropItem = Knit.Controllers.ItemDropController.dropItemInHand,
		EquipItem = safeGetProto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 3),
		FireProjectile = safeGetProto(Knit.Controllers.ProjectileController.launchProjectileWithValues, 2) or function() end,
		GroundHit = Knit.Controllers.FallDamageController.KnitStart,
		GuitarHeal = Knit.Controllers.GuitarController.performHeal,
		HannahKill = safeGetProto(Knit.Controllers.HannahController.registerExecuteInteractions, 1),
		HarvestCrop = safeGetProto(safeGetProto(Knit.Controllers.CropController.KnitStart, 4), 1),
		KaliyahPunch = safeGetProto(Knit.Controllers.DragonSlayerController.onKitLocalActivated, 1),
		MageSelect = safeGetProto(Knit.Controllers.MageController.registerTomeInteraction, 1),
		PickupItem = Knit.Controllers.ItemDropController.checkForPickup,
		PickupMetal = safeGetProto(Knit.Controllers.HiddenMetalController.onKitLocalActivated, 4),
		ReportPlayer = require(lplr.PlayerScripts.TS.controllers.global.report['report-controller']).default.reportPlayer,
		ResetCharacter = safeGetProto(Knit.Controllers.ResetController.createBindable, 1),
		SummonerClawAttack = Knit.Controllers.SummonerClawHandController.attack,
		WarlockTarget = safeGetProto(Knit.Controllers.WarlockStaffController.KnitStart, 2)
	}

	local function dumpRemote(tab)
		local ind
		for i, v in tab do
			if v == 'Client' then
				ind = i
				break
			end
		end
		return ind and tab[ind + 1] or ''
	end

	local preDumped = {
		EquipItem = 'SetInvItem',
		ActivateGravestone = 'ActivateGravestone',
		CollectCollectableEntity = 'CollectCollectableEntity',
		DefenderRequestPlaceBlock = 'DefenderRequestPlaceBlock',
		RequestDragonPunch = 'RequestDragonPunch',
		Harvest = 'CropHarvest',
		DepositCoins = 'DepositCoins',
		BedwarsPurchaseItem = 'BedwarsPurchaseItem',
		BedBreakEffectTriggered = 'BedBreakEffectTriggered',
		BloodAssassinSelectContract = 'BloodAssassinSelectContract',
		Mimic = 'MimicBlock',
		StyxPortal = 'UseStyxPortalFromClient',
		StyxExitPortal = 'StyxOpenExitPortalFromServer',
		StyxSpawnExitPortal = 'StyxSpawnExitPortalFromServer',
		StyxSpawnEntrancePortal = 'StyxSpawnEntrancePortalFromServer',
		TryOpenStyxPortalExit = 'StyxTryOpenExitPortalFromClient',
		TeleportToLobby = 'TeletoLobby',
		FishCaught = 'FishCaught',
		BountyHunterTargetChanged = 'BountyHunterTargetChanged',
		SpawnRaven = 'SpawnRaven',
		PaladinAbilityRequest = 'PaladinAbilityRequest',
		OwlActionAbilities = 'OwlActionAbilities',
		DrillAttack = 'DrillAttack',
		UpgradeFrostyHammer = 'UpgradeFrostyHammer',
		UpgradeFlamethrower = 'UpgradeFlamethrower',
		TryBlockKick = 'TryBlockKick',   
		Ranks = 'FetchRanks',
		ResearchEnchant = 'EnchantTableResearch',
		DropDroneItem = 'DropDroneItem',
		AttemptFireOasisProjectiles = 'AttemptFireOasisProjectiles',
		WinEffectTriggered = 'WinEffectTriggered',
		ExtractFromDrill = 'ExtractFromDrill',
		HannahPromptTrigger = 'HannahPromptTrigger',
		DragonFlap = 'DragonFlap',
		DragonBreath = 'DragonBreath',
		AttemptCardThrow = 'AttemptCardThrow',
		LearnElementTome = 'LearnElementTome',
		RequestMoveSlime = 'RequestMoveSlime',
		SummonOwl = 'SummonOwl',
		RemoveOwl = 'RemoveOwl',
		OwlFireProjectile = 'OwlFireProjectile',
		OwlAiming = 'OwlAiming',
		MimicBlockPickPocketPlayer = 'MimicBlockPickPocketPlayer',
		DestroyPetrifiedPlayer = 'DestroyPetrifiedPlayer',
		UseAbility = 'useAbility',
		FishFound = 'FishFound',
	}

	for k, v in pairs(preDumped) do
		if not remotes[k] then
			remotes[k] = v
		end
	end

	for i, v in remoteNames do
		local remote
		if type(v) == "string" then
			remote = v
		elseif type(v) == "function" then
			local consts = debug.getconstants(v)
			remote = dumpRemote(consts)
		else
			remote = ""
		end

		if remote == '' or remote == nil then
			if not preDumped[i] then
				notif('aerov4', 'Failed to grab remote ('..tostring(i)..')', 10, 'alert')
			end
			remote = preDumped[i] or ''
		end
		remotes[i] = remote
	end

	pcall(function()
		local net = game:GetService('ReplicatedStorage').rbxts_include.node_modules['@rbxts'].net.out._NetManaged
		local knownFixes = {
			FireProjectile = 'ProjectileFire',
			AttackEntity = 'SwordHit',
		}
		if net:FindFirstChild('SwordHit') then
			remotes.AttackEntity = 'SwordHit'
		end
		for k, v in pairs(remotes) do
			if type(v) == 'string' and v ~= '' and not net:FindFirstChild(v) then
				if knownFixes[k] and net:FindFirstChild(knownFixes[k]) then
					remotes[k] = knownFixes[k]
				elseif preDumped[k] and net:FindFirstChild(preDumped[k]) then
					remotes[k] = preDumped[k]
				end
			end
		end
	end)

	getgenv().remotes = remotes

	OldBreak = bedwars.BlockController.isBlockBreakable

	Client.Get = function(self, remoteName, ...)
		local call = OldGet(self, remoteName, ...)

		if remoteName == 'SwordHit' or remoteName == remotes.AttackEntity then
			return {
				instance = call.instance,
				SendToServer = function(_, attackTable, ...)
					local suc, plr = pcall(function()
						return playersService:GetPlayerFromCharacter(attackTable.entityInstance)
					end)

					local selfpos = attackTable.validate.selfPosition.value
					local targetpos = attackTable.validate.targetPosition.value
					store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
					store.attackReachUpdate = tick() + 1

					if Reach.Enabled or HitBoxes.Enabled then
						local delta = targetpos - selfpos
						if delta.Magnitude > 14.399 then
							local newself = selfpos + delta.Unit * (delta.Magnitude - 14.399)
							attackTable.validate.selfPosition.value = newself
							attackTable.validate.raycast = {
								cameraPosition = {value = newself},
								cursorDirection = {value = (targetpos - newself).Unit}
							}
						elseif attackTable.validate.raycast and attackTable.validate.raycast.cameraPosition then
							local cam = attackTable.validate.raycast.cameraPosition.value
							attackTable.validate.raycast.cursorDirection = {value = (targetpos - cam).Unit}
						end
					end

					return call:SendToServer(attackTable, ...)
				end
			}
		elseif TrapDisabler and TrapDisabler.Enabled and (
			remoteName == 'StepOnSnapTrap' and TrapSnap.Enabled
			or remoteName == 'TriggerInvisibleLandmine' and TrapMine.Enabled
			or remoteName == 'StepOnTeleportBlock' and TrapTeleport.Enabled
			or remoteName == 'StepOnVoidPortal' and TrapPortal.Enabled
		) then
			return {SendToServer = function() end}
		end

		return call
	end

	local bedtms = {}

	local cache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
	
	local cacheCleanThread = task.spawn(function()
		while vape.Loaded do
			task.wait(60)
			if vape.Loaded then
				table.clear(cache)
				table.clear(bedtms)
			end
		end
	end)
	vape:Clean(function() task.cancel(cacheCleanThread) end)

	store.blockPlacer = bedwars.BlockPlacer.new(bedwars.BlockEngine, 'wool_white')

	local function getBlockHealth(block, blockpos)
		local blockdata = bedwars.BlockController:getStore():getBlockData(blockpos)
		local health = blockdata and (blockdata:GetAttribute('1') or blockdata:GetAttribute('Health'))

		if health == nil then
			health = block:GetAttribute('Health')
		end

		if health ~= nil then
			return health
		end

		local meta = bedwars.ItemMeta[block.Name]
		return (meta and meta.block and meta.block.health) or 10
	end

	local function getBreakType(block)
		if not block then return nil end
		if block.Name == 'gumdrop_bounce_pad' then return 'stone' end
		local meta = bedwars.ItemMeta[block.Name]
		return meta and meta.block and meta.block.breakType
	end

	local function getBlockHits(block, blockpos)
		if not block then return 0 end
		local breaktype = getBreakType(block)
		local tool = breaktype and store.tools[breaktype]
		local toolMeta = tool and bedwars.ItemMeta[tool.itemType]
		local dmg = (toolMeta and toolMeta.breakBlock and toolMeta.breakBlock[breaktype]) or 2
		local health = getBlockHealth(block, bedwars.BlockController:getBlockPosition(blockpos)) or 10
		return health / dmg
	end

	local function calculatePath(target, blockpos, angle, anchor, weight, blockFilter)
		local cached = cache[blockpos]
		if cached then
			local age = tick() - (cached.timestamp or 0)
			local sameAnchor = ((not anchor and not cached.anchor) or (anchor and cached.anchor and (anchor - cached.anchor).Magnitude < 1.5))
				and cached.weight == weight
				and cached.blockFilter == blockFilter
				and cached.shell == (bedwars.breakerShell == true)
			if sameAnchor and age < (anchor and 0.5 or 1) then
				return cached[1], cached[2], cached[3]
			elseif age >= 1 then
				cache[blockpos] = nil
			end
		end
		angle = angle or 360
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return end
		local origin = root.Position
		local camFlat = gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
		local useAngle = angle < 360 and camFlat.Magnitude > 0.01
		local halfAngle = math.rad(angle) / 2
		local visited = {}
		local shell = bedwars.breakerShell == true
		local airMemo = {}
		local function openAir(cell)
			if airMemo[cell] ~= nil then return airMemo[cell] end
			local seen, queue, head, open = {[cell] = true}, {cell}, 1, false
			while queue[head] do
				local cur = queue[head]
				head += 1
				if airMemo[cur] ~= nil then
					open = airMemo[cur]
					break
				end
				if (cur - blockpos).Magnitude > 15 or head > 250 then
					open = true
					break
				end
				for _, side in sides do
					local nxt = cur + side
					if not seen[nxt] and not getPlacedBlock(nxt) then
						seen[nxt] = true
						table.insert(queue, nxt)
					end
				end
			end
			for c in seen do
				airMemo[c] = open
			end
			return open
		end
		local distances = {[blockpos] = 0}
		local open = {blockpos}
		local path = {}
		local pos, cost = nil, math.huge

		for _ = 1, 4000 do
			local bestI, bestD = nil, math.huge
			for i = 1, #open do
				local d = distances[open[i]]
				if d < bestD then
					bestI, bestD = i, d
				end
			end
			if not bestI then break end

			local node = open[bestI]
			open[bestI] = open[#open]
			open[#open] = nil
			if visited[node] then continue end
			visited[node] = true

			if (not anchor or weight) and bestD >= cost then break end

			for _, side in sides do
				local neighbor = node + side
				if visited[neighbor] then continue end

				local block = getPlacedBlock(neighbor)
				if not block and shell and not openAir(neighbor) then
					if bestD < (distances[neighbor] or math.huge) then
						distances[neighbor] = bestD
						path[neighbor] = node
						table.insert(open, neighbor)
					end
					continue
				end
				if not block then
					local score = bestD
					if anchor then
						local delta = node - anchor
						local near = (delta * Vector3.new(1, 0, 1)).Magnitude + math.abs(delta.Y) * 2
						score = weight and (bestD + near * weight) or (near + bestD * 0.02)
					end
					if score < cost then
						pos, cost = node, score
					end
					continue
				end

				if block == target or block:GetAttribute('NoBreak') then continue end

				if blockFilter then
					local ok, allowed = pcall(blockFilter, block)
					if not ok or not allowed then
						continue
					end
				end

				if (neighbor - origin).Magnitude > 30 then continue end

				if useAngle then
					local blockFlat = (neighbor - origin) * Vector3.new(1, 0, 1)
					if blockFlat.Magnitude > 0.01 and math.acos(math.clamp(camFlat.Unit:Dot(blockFlat.Unit), -1, 1)) > halfAngle then
						continue
					end
				end

				local curdist = getBlockHits(block, neighbor) + bestD
				if curdist < (distances[neighbor] or math.huge) then
					distances[neighbor] = curdist
					path[neighbor] = node
					table.insert(open, neighbor)
				end
			end
		end

		if pos then
			cache[blockpos] = {
				pos,
				cost,
				path,
				timestamp = tick(),
				anchor = anchor,
				weight = weight,
				blockFilter = blockFilter,
				shell = shell
			}
			return pos, cost, path
		end
	end
	bedwars.calculatePath = calculatePath
	bedwars.clearPathCache = function()
		table.clear(cache)
	end

	bedwars.placeBlock = function(pos, item)
		if getItem(item) then
			store.blockPlacer.blockType = item
			local ok, result = pcall(function()
				return store.blockPlacer:placeBlock(bedwars.BlockController:getBlockPosition(pos))
			end)
			if ok then return result end
		end
	end

	bedwars.breakBlock = function(block, effects, anim, customHealthbar, visualise, angle, anchor, weight, blockFilter, lockedTarget)
		if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive then return end
		local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		local cost, pos, target, path = math.huge, nil, nil, nil
		local playerPos = entitylib.character.RootPart.Position

		local mag = 9e9
		for _, v in (handler and handler:getContainedPositions(block) or {block.Position / 3}) do
			local worldTarget = v * 3

			if lockedTarget and (worldTarget - lockedTarget).Magnitude > 0.1 then
				continue
			end

			local dpos, dcost, dpath = calculatePath(
				block,
				worldTarget,
				angle or 360,
				anchor,
				weight,
				blockFilter
			)

			local dmag = dpos and (playerPos - dpos).Magnitude or 9e9

			if dpos and (dcost < cost or (dcost == cost and dmag < mag)) then
				cost, pos, target, path, mag = dcost, dpos, worldTarget, dpath, dmag
			end
		end

		if pos then
			if (entitylib.character.RootPart.Position - pos).Magnitude > 30 then return end
			local dblock, dpos = getPlacedBlock(pos)
			if not dblock and target then
				dblock, dpos = getPlacedBlock(target)
			end
			if not dblock then
				dblock, dpos = block, bedwars.BlockController:getBlockPosition(block.Position)
			end
			if not dblock or not dpos then return end

			if blockFilter then
				local ok, allowed = pcall(blockFilter, dblock)

				if not ok or not allowed then
					table.clear(cache)
					return
				end
			end

			local hitType = store.hand and store.hand.tool and store.hand.tool.Name
			if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.4 then
				local breaktype = getBreakType(dblock)
				local tool = breaktype and store.tools[breaktype]
				if tool and visualise then
					local slot
					for i, v in store.inventory.hotbar do
						if v.item and v.item.itemType == tool.itemType then
							slot = i - 1
							break
						end
					end
					if slot then
						hotbarSwitch(slot)
						hitType = tool.itemType
					end
				end
			end

			if blockhealthbar.blockHealth == -1 or dpos ~= blockhealthbar.breakingBlockPosition then
				blockhealthbar.blockHealth = getBlockHealth(dblock, dpos) or 0
				blockhealthbar.breakingBlockPosition = dpos
			end

			if anim and (tick() - (store.lastBreakerAnimation or 0)) >= 0.18 then
				store.lastBreakerAnimation = tick()
				task.spawn(function()
					local animation
					pcall(function()
						animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
					end)
					pcall(function()
						bedwars.ViewmodelController:playAnimation(15)
					end)

					task.wait(0.3)

					if animation then
						pcall(function()
							animation:Stop()
							animation:Destroy()
						end)
					end
				end)
			end

			bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
				blockRef = {blockPosition = dpos},
				hitPosition = pos,
				hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
			}):andThen(function(result)
				if result then
					if result == 'cancelled' then
						table.clear(cache)
						return
					end
					if result == 'destroyed' then
						table.clear(cache) 
					end
					if effects then
						local hmeta = hitType and bedwars.ItemMeta[hitType]
						local btype = getBreakType(dblock)
						local hitdmg = (hmeta and hmeta.breakBlock and btype and hmeta.breakBlock[btype]) or 2
						local predicted = math.max(blockhealthbar.blockHealth - hitdmg, 1)
						local nowHealth = result == 'destroyed' and 0 or math.min(getBlockHealth(dblock, dpos) or predicted, predicted)
						local blockdmg = math.max(blockhealthbar.blockHealth - nowHealth, 0)
						local dmeta = bedwars.ItemMeta[dblock.Name]
						local maxHealth = dblock:GetAttribute('MaxHealth') or (dmeta and dmeta.block and dmeta.block.health) or math.max(blockhealthbar.blockHealth, 1)
						customHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
						pcall(customHealthbar, bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, maxHealth, blockdmg, dblock)
						blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)
						pcall(function()
							if blockhealthbar.blockHealth <= 0 then
								bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr)
								blockhealthbar.breakingBlockPosition = Vector3.zero
								blockhealthbar.blockHealth = -1
								if bedwars.BlockBreaker.healthbarMaid then
									bedwars.BlockBreaker.healthbarMaid:DoCleaning()
								end
							else
								bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr)
							end
						end)
					end
				end
			end)

			return pos, path, target
		end
	end

	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	local function updateStore(new, old)
		if new.Bedwars ~= old.Bedwars then
			store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
		end
		if new.Game ~= old.Game then
			store.matchState = new.Game.matchState
			store.queueType = new.Game.queueType or 'bedwars_test'
		end

		if new.Inventory ~= old.Inventory then
			local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
			local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
			store.inventory = newinv

			if newinv ~= oldinv then
				fireInventoryChanged()
			end

			if newinv.inventory.items ~= oldinv.inventory.items then
				vapeEvents.InventoryAmountChanged:Fire()
				store.tools.sword = getSword()
				local now = tick()
				if not store.lastToolUpdate or now - store.lastToolUpdate > 0.5 then
					store.lastToolUpdate = now
					for _, v in {'stone', 'wood', 'wool'} do
						store.tools[v] = getTool(v)
					end
				elseif not store.toolUpdatePending then
					store.toolUpdatePending = true
					task.delay(0.5, function()
						store.toolUpdatePending = false
						store.lastToolUpdate = tick()
						for _, v in {'stone', 'wood', 'wool'} do
							store.tools[v] = getTool(v)
						end
					end)
				end
			end

			if newinv.inventory.hand ~= oldinv.inventory.hand then
				store.lastToolUpdate = tick()
				store.tools.sword = getSword()
				for _, v in {'stone', 'wood', 'wool'} do
					store.tools[v] = getTool(v)
				end
				local currentHand, toolType = new.Inventory.observedInventory.inventory.hand, ''
				if currentHand then
					local handData = bedwars.ItemMeta[currentHand.itemType]
					toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
				end

				store.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = toolType
				}
			end
		end
	end

	local storeChanged = bedwars.Store.changed:connect(updateStore)
	vape:Clean(function() storeChanged:disconnect() end)
	updateStore(bedwars.Store:getState(), {})

	for _, event in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
		if not vape.Connections then return end
		bedwars.Client:WaitFor(event):andThen(function(connection)
			vape:Clean(connection:Connect(function(...)
				vapeEvents[event]:Fire(...)
			end))
		end)
	end

	local _dmgEventData = {entityInstance=nil,damage=nil,damageType=nil,fromPosition=nil,fromEntity=nil,knockbackMultiplier=nil,knockbackId=nil,disableDamageHighlight=nil}
	vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
		_dmgEventData.entityInstance = ...
		_dmgEventData.damage = select(2, ...)
		_dmgEventData.damageType = select(3, ...)
		_dmgEventData.fromPosition = select(4, ...)
		_dmgEventData.fromEntity = select(5, ...)
		_dmgEventData.knockbackMultiplier = select(6, ...)
		_dmgEventData.knockbackId = select(7, ...)
		_dmgEventData.disableDamageHighlight = select(13, ...)
		_dmgEventData.swingInfo = select(8, ...)
		vapeEvents.EntityDamageEvent:Fire(_dmgEventData)
	end))

	vape:Clean(playersService.PlayerRemoving:Connect(function(plr)
		store.inventories[plr] = nil
	end))

	for _, event in {'PlaceBlockEvent', 'BreakBlockEvent'} do
		vape:Clean(bedwars.ZapNetworking[event..'Zap'].On(function(...)
			local pos = ...
			local plr = select(5, ...)
			task.spawn(function()
				pcall(function()
					vapeEvents[event]:Fire({blockRef = {blockPosition = pos}, player = plr})
				end)
			end)
		end))
	end

	store.blocks = collection('block', vape)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, vape, function(tab, obj)
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, vape, nil, function(tab, obj, tag)
		if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
		obj = table.find(tab, obj)
		if obj then
			table.remove(tab, obj)
		end
	end)

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	local mapname = 'Unknown'
	sessioninfo:AddItem('Map', 0, function()
		return mapname
	end, false)

	task.delay(1, function()
		games:Increment()
	end)

	task.spawn(function()
		pcall(function()
			repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
			if vape.Loaded == nil then return end
			store.map = waitForChildYield(workspace, 9e9, 'Map', 'Worlds'):GetChildren()[1]
			mapname = store.map.Name
			mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
			if store.map then
				vape:Clean(store.map.Blocks.ChildAdded:Connect(function(v) 
					task.delay(0, function()
						if v:GetAttribute('Block') and (v:GetAttribute('PlacedByUserId') or 0) ~= 0 then
							local data = {
								blockRef = {
									blockPosition = v.Position / 3,
								},
								player = playersService:GetPlayerByUserId(v:GetAttribute('PlacedByUserId')),
							}
							for i, v in cache do
								if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
									table.clear(v[3])
									table.clear(v)
									cache[i] = nil
								end
							end
							vapeEvents.PlaceBlockEvent:Fire(data)
						end
					end)
				end))
			end
		end)
	end)

	vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
		if bedTable.player and bedTable.player.UserId == lplr.UserId then
			beds:Increment()
		end
	end))

	vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
		if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
			wins:Increment()
		end
	end))

	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end

		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))

	pcall(function()
		bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
		bedwars.ShopItems = bedwars.Shop.ShopItems
		bedwars.Shop.getShopItem('iron_sword', lplr)
		store.shopLoaded = true
	end)

	vape:Clean(function()
		Client.Get = OldGet
		bedwars.BlockController.isBlockBreakable = OldBreak
		store.blockPlacer:disable()
		for _, v in vapeEvents do
			v:Destroy()
		end
		for _, v in cache do
			table.clear(v[3])
			table.clear(v)
		end
		table.clear(store.blockPlacer)
		table.clear(vapeEvents)
		table.clear(bedwars)
		table.clear(store)
		table.clear(cache)
		table.clear(sides)
		table.clear(remotes)
		storeChanged:disconnect()
		storeChanged = nil

		if entitylib.Connections then
			for _, conn in ipairs(entitylib.Connections) do
				if conn and type(conn) == "userdata" and conn.Connected then
					conn:Disconnect()
				end
			end
			table.clear(entitylib.Connections)
		end

		if entitylib.PlayerConnections then
			for _, plrConns in pairs(entitylib.PlayerConnections) do
				if type(plrConns) == "table" then
					for _, conn in ipairs(plrConns) do
						if conn and type(conn) == "userdata" and conn.Connected then
							conn:Disconnect()
						end
					end
				end
			end
			table.clear(entitylib.PlayerConnections)
		end

		if entitylib.EntityThreads then
			for char, thread in pairs(entitylib.EntityThreads) do
				if thread and task.cancel then
					task.cancel(thread)
				end
			end
			table.clear(entitylib.EntityThreads)
		end

		if entitylib.List then
			for _, ent in ipairs(entitylib.List) do
				if ent.Connections then
					for _, conn in ipairs(ent.Connections) do
						if conn and type(conn) == "userdata" and conn.Connected then
							conn:Disconnect()
						end
					end
					table.clear(ent.Connections)
				end
			end
			table.clear(entitylib.List)
		end
		if entitylib.stop then
			entitylib.stop()
		end
		for playerId, data in pairs(lagConnections) do
			if data and data.connection then
				pcall(function() data.connection:Disconnect() end)
			end
		end
		table.clear(lagConnections)
	end)
end)
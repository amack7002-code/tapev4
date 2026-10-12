run(function()
	local VictoriousKitSkins
	local ItemSkinDropdown
	local SkinTypeDropdown
	local RS = game:GetService('ReplicatedStorage')
	local LocalPlayer = lplr
	local RESKIN_NAME = 'LOCAL_ITEM_RESKIN'
	local state = {
		itemSkin = 'Victorious Lyla',
		skinType = 'Nightmare',
	}
	local ok1, ItemType = pcall(function()
		return require(RS.TS.item['item-type']).ItemType
	end)
	if not ok1 then ItemType = {} end
	local ok2, ItemSkinType = pcall(function()
		return require(RS.TS.games.bedwars['item-skin']['item-skin-types']).ItemSkinType
	end)
	if not ok2 then ItemSkinType = {} end
	local KitSkinCtrl
	pcall(function()
		local KC = require(RS.rbxts_include.node_modules['@easy-games'].knit.src).KnitClient
		KitSkinCtrl = KC.Controllers.KitSkinController
	end)

	local VICTORIOUS_ARCHER_BOW_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(0, -52, math.rad(90))
	local VICTORIOUS_ARCHER_CROSSBOW_ROT = CFrame.new(0.00, 0.00, 0.00) * CFrame.Angles(math.rad(0), math.rad(80), math.rad(0.00))
	local VICTORIOUS_ARCHER_HEADHUNTER_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(0), 0)
	local STAFF_ROT = CFrame.Angles(0, math.rad(90), 0)
	local VIC_ROT = CFrame.new(0, -1.9, 0) * CFrame.Angles(0, math.rad(360), 0)
	local TRIDENT_ROT = CFrame.new(0, 0.5, 0.05) * CFrame.Angles(0, math.rad(180), 0)
	local LYLA_BOW_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(30, -30, 183.56)
	local LYLA_CROSSBOW_ROT = CFrame.Angles(math.rad(0), math.rad(180), math.rad(0))
	local LYLA_HEADHUNTER_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(0), 0)
	local CANNON_HAND_SCALE = 0.34
	local CANNON_PLACED_OFFSET = CFrame.new(0, -1.0, 0)
	local CANNON_TOOL_NAME = "cannon"

	local CANNON_SKIN_NAMES = {
		["Victorious Cannon"] = {
			Gold = "cannon_gold_victorious",
			Platinum = "cannon_platinum_victorious",
			Diamond = "cannon_diamond_victorious",
			Emerald = "cannon_emerald_victorious",
			Nightmare = "cannon_nightmare_victorious",
		},
	}
	local CANNON_SOUND_NAMES = {
		Gold = "CANNON_FIRE_VICTORIOUS_NIGHTMARE",
		Platinum = "CANNON_FIRE_VICTORIOUS_NIGHTMARE",
		Diamond = "CANNON_FIRE_VICTORIOUS_DIAMOND",
		Emerald = "CANNON_FIRE_VICTORIOUS_EMERALD",
		Nightmare = "CANNON_FIRE_VICTORIOUS_NIGHTMARE",
	}
	local SKIN_OFFSETS = {
		["nightmare_victorious_flower_bow"] = LYLA_BOW_ROT,
		["emerald_victorious_flower_bow"] = LYLA_BOW_ROT,
		["diamond_victorious_flower_bow"] = LYLA_BOW_ROT,
		["platinum_victorious_flower_bow"] = LYLA_BOW_ROT,
		["gold_victorious_flower_bow"] = LYLA_BOW_ROT,
		["nightmare_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["emerald_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["diamond_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["platinum_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["gold_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["nightmare_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["emerald_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["diamond_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["platinum_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["gold_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_nightmare"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_emerald"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_diamond"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_platinum"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_gold"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["wood_bow_victorious_nightmare"] = VICTORIOUS_ARCHER_BOW_ROT,
		["wood_bow_victorious_emerald"] = VICTORIOUS_ARCHER_BOW_ROT,
		["wood_bow_victorious_diamond"] = VICTORIOUS_ARCHER_BOW_ROT,
		["wood_bow_victorious_platinum"] = VICTORIOUS_ARCHER_BOW_ROT,
		["wood_bow_victorious_gold"] = VICTORIOUS_ARCHER_BOW_ROT,
		["tactical_crossbow_victorious_nightmare"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["tactical_crossbow_victorious_emerald"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["tactical_crossbow_victorious_diamond"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["tactical_crossbow_victorious_platinum"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["tactical_crossbow_victorious_gold"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["victorious_gold_triton"] = TRIDENT_ROT,
		["victorious_platinum_triton"] = TRIDENT_ROT,
		["victorious_diamond_triton"] = TRIDENT_ROT,
		["victorious_emerald_triton"] = TRIDENT_ROT,
		["victorious_nightmare_triton"] = TRIDENT_ROT,
		["gold_victorious_wizard_staff"] = STAFF_ROT,
		["gold_victorious_wizard_staff_2"] = STAFF_ROT,
		["gold_victorious_wizard_staff_3"] = STAFF_ROT,
		["platinum_victorious_wizard_staff"] = STAFF_ROT,
		["platinum_victorious_wizard_staff_2"] = STAFF_ROT,
		["platinum_victorious_wizard_staff_3"] = STAFF_ROT,
		["diamond_victorious_wizard_staff"] = STAFF_ROT,
		["diamond_victorious_wizard_staff_2"] = STAFF_ROT,
		["diamond_victorious_wizard_staff_3"] = STAFF_ROT,
		["emerald_victorious_wizard_staff"] = STAFF_ROT,
		["emerald_victorious_wizard_staff_2"] = STAFF_ROT,
		["emerald_victorious_wizard_staff_3"] = STAFF_ROT,
		["nightmare_victorious_wizard_staff"] = STAFF_ROT,
		["nightmare_victorious_wizard_staff_2"] = STAFF_ROT,
		["nightmare_victorious_wizard_staff_3"] = STAFF_ROT,
		["wood_dao_victorious"] = VIC_ROT,
		["stone_dao_victorious"] = VIC_ROT,
		["iron_dao_victorious"] = VIC_ROT,
		["diamond_dao_victorious"] = VIC_ROT,
		["emerald_dao_victorious"] = VIC_ROT,
	}
	local KIT_SKIN_MAP = {
		["Victorious Lyla"] = { Gold = "gold_victorious_lyla", Platinum = "platinum_victorious_lyla", Diamond = "diamond_victorious_lyla", Emerald = "emerald_victorious_lyla", Nightmare = "nightmare_victorious_lyla" },
		["Victorious Archer"] = { Gold = "archer_victorious_gold", Platinum = "archer_victorious_platinum", Diamond = "archer_victorious_diamond", Emerald = "archer_victorious_emerald", Nightmare = "archer_victorious_nightmare" },
		["Victorious Yuzi"] = { Default = "yuzi_victorious" },
		["Victorious Zeno"] = { Gold = "gold_victorious_wizard", Platinum = "platinum_victorious_wizard", Diamond = "diamond_victorious_wizard", Emerald = "emerald_victorious_wizard", Nightmare = "nightmare_victorious_wizard" },
		["Victorious Triton"] = { Gold = "victorious_gold_triton", Platinum = "victorious_platinum_triton", Diamond = "victorious_diamond_triton", Emerald = "victorious_emerald_triton", Nightmare = "victorious_nightmare_triton" },
		["Victorious Cannon"] = { Gold = "gold_victorious_davey", Platinum = "platinum_victorious_davey", Diamond = "diamond_victorious_davey", Emerald = "emerald_victorious_davey", Nightmare = "nightmare_victorious_davey" },
	}
	local function yuziDaoMap(suffix)
		return {
			wood_dao = "wood_dao_" .. suffix,
			stone_dao = "stone_dao_" .. suffix,
			iron_dao = "iron_dao_" .. suffix,
			diamond_dao = "diamond_dao_" .. suffix,
			emerald_dao = "emerald_dao_" .. suffix,
		}
	end
	local SKIN_DATA = {
		["Victorious Lyla"] = function(t)
			local lt = t:lower()
			return {
				flower_bow = lt .. "_victorious_flower_bow",
				flower_crossbow = lt .. "_victorious_flower_crossbow",
				flower_headhunter = lt .. "_victorious_flower_headhunter",
			}
		end,
		["Victorious Archer"] = function(t)
			local lt = t:lower()
			return {
				wood_bow = "wood_bow_victorious_" .. lt,
				tactical_crossbow = "tactical_crossbow_victorious_" .. lt,
				tactical_headhunter = "tactical_headhunter_victorious_" .. lt,
			}
		end,
		["Victorious Triton"] = function(t)
			return { harpoon = "victorious_" .. t:lower() .. "_triton" }
		end,
		["Victorious Yuzi"] = function() return yuziDaoMap("victorious") end,
		["Victorious Zeno"] = function(t)
			local lt = t:lower()
			return {
				wizard_staff = lt .. "_victorious_wizard_staff",
				wizard_staff_2 = lt .. "_victorious_wizard_staff_2",
				wizard_staff_3 = lt .. "_victorious_wizard_staff_3",
			}
		end,
	}
	local TIERED_SKINS = {
		["Victorious Lyla"] = true,
		["Victorious Archer"] = true,
		["Victorious Zeno"] = true,
		["Victorious Triton"] = true,
		["Victorious Cannon"] = true,
	}

	local active = {}
	local hideList = {}
	local hookConns = {}
	local renderConn
	local oldGetKitSkin
	local oldFireCannon
	local oldLaunchSelf
	local soundsHooked = false
	local refreshVersion = 0

	local function normalizeName(s)
		return s:lower():gsub('[_%s%-]', '')
	end

	local function isCannonSkin()
		return CANNON_SKIN_NAMES[state.itemSkin] ~= nil
	end

	local function getCannonSkinName()
		local tbl = CANNON_SKIN_NAMES[state.itemSkin]
		if not tbl then return nil end
		return tbl[state.skinType] or tbl.Default
	end

	local function getCurrentMappings()
		local fn = SKIN_DATA[state.itemSkin]
		if not fn then return {} end
		local ok, res = pcall(fn, state.skinType)
		if ok and type(res) == 'table' then return res end
		return {}
	end

	local function getKitSkinValue()
		local m = KIT_SKIN_MAP[state.itemSkin]
		if not m then return nil end
		return m[state.skinType] or m.Default
	end

	local function itemsFolder()
		return RS:FindFirstChild('Items')
	end

	local function blocksFolder()
		local assets = RS:FindFirstChild('Assets')
		return assets and assets:FindFirstChild('Blocks')
	end

	local function firstBasePart(root)
		if root:IsA('BasePart') then return root end
		for _, d in root:GetDescendants() do
			if d:IsA('BasePart') then return d end
		end
		return nil
	end

	local function setNoCollide(model)
		local function strip(p)
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			p.Anchored = false
		end
		if model:IsA('BasePart') then strip(model) end
		for _, d in model:GetDescendants() do
			if d:IsA('BasePart') then strip(d) end
		end
	end

	local function weldAllTo(anchor, container)
		for _, d in container:GetDescendants() do
			if d:IsA('BasePart') and d ~= anchor then
				local wc = Instance.new('WeldConstraint')
				wc.Part0 = anchor
				wc.Part1 = d
				wc.Parent = anchor
			end
		end
	end

	local function getRigScale(root)
		local node = root
		local hum
		for _ = 1, 6 do
			if not node or node == workspace then break end
			hum = node:FindFirstChildOfClass('Humanoid')
			if hum then break end
			node = node.Parent
		end
		if not hum then return 1 end
		local total, count = 0, 0
		for _, name in {'BodyHeightScale', 'BodyWidthScale', 'BodyDepthScale'} do
			local v = hum:FindFirstChild(name)
			if v and v:IsA('NumberValue') and v.Value > 0 then
				total = total + v.Value
				count = count + 1
			end
		end
		if count == 0 then return 1 end
		return math.clamp(total / count, 0.3, 3)
	end

	local function startRenderLoop()
		if renderConn then return end
		renderConn = runService.RenderStepped:Connect(function()
			for i = #hideList, 1, -1 do
				local p = hideList[i]
				if p and p.Parent then
					p.LocalTransparencyModifier = 1
				else
					table.remove(hideList, i)
				end
			end
		end)
	end

	local function stopRenderLoop()
		if renderConn then
			pcall(function() renderConn:Disconnect() end)
			renderConn = nil
		end
	end

	local function hideDescendant(entry, d)
		if d:IsA('BasePart') then
			entry.parts[#entry.parts + 1] = {d, d.Transparency}
			d.Transparency = 1
			d.LocalTransparencyModifier = 1
			hideList[#hideList + 1] = d
		elseif d:IsA('Decal') or d:IsA('Texture') then
			entry.decals[#entry.decals + 1] = {d, d.Transparency}
			d.Transparency = 1
		end
	end

	local function hideOriginal(entry, root)
		for _, d in root:GetDescendants() do
			if not d:IsDescendantOf(entry.clone) then
				hideDescendant(entry, d)
			end
		end
	end

	local function detach(root)
		local entry = active[root]
		if not entry then return end
		active[root] = nil
		for _, c in entry.conns do
			pcall(function() c:Disconnect() end)
		end
		if entry.clone then
			pcall(function() entry.clone:Destroy() end)
		end
		for _, rec in entry.parts do
			local p = rec[1]
			local idx = table.find(hideList, p)
			if idx then table.remove(hideList, idx) end
			pcall(function()
				if p.Parent then
					p.Transparency = rec[2]
					p.LocalTransparencyModifier = 0
				end
			end)
		end
		for _, rec in entry.decals do
			local d = rec[1]
			pcall(function()
				if d.Parent then d.Transparency = rec[2] end
			end)
		end
	end

	local function detachAll()
		for root in active do
			detach(root)
		end
		table.clear(active)
		table.clear(hideList)
	end

	local function attachReskin(root, skinName, source, opts)
		if not root or not root.Parent then return end
		if active[root] or not source then return end
		opts = opts or {}

		local origHandle = root:FindFirstChild('Handle')
		if not (origHandle and origHandle:IsA('BasePart')) then
			origHandle = firstBasePart(root)
		end
		if not origHandle then return end

		local clone = source:Clone()
		clone.Name = RESKIN_NAME
		for _, d in clone:GetDescendants() do
			if d:IsA('LuaSourceContainer') then
				pcall(function() d:Destroy() end)
			end
		end
		setNoCollide(clone)

		local anchor
		local alignByPivot = false
		if clone:IsA('BasePart') then
			anchor = clone
		else
			local handle = clone:FindFirstChild('Handle')
			if handle and handle:IsA('BasePart') then
				anchor = handle
			else
				alignByPivot = true
				anchor = clone:IsA('Model') and clone.PrimaryPart or nil
				anchor = anchor or firstBasePart(clone)
			end
		end
		if not anchor then
			pcall(function() clone:Destroy() end)
			return
		end
		if clone:IsA('Model') and not clone.PrimaryPart then
			pcall(function() clone.PrimaryPart = anchor end)
		end

		local scale = (opts.scale or 1) * getRigScale(root)
		if clone:IsA('Model') and math.abs(scale - 1) > 0.001 then
			pcall(function() clone:ScaleTo(scale) end)
		end

		local entry = {clone = clone, parts = {}, decals = {}, conns = {}}
		active[root] = entry
		clone.Parent = root

		local offset = (SKIN_OFFSETS[skinName] or CFrame.identity) * (opts.offset or CFrame.identity)
		local target = origHandle.CFrame * offset
		pcall(function()
			if not clone:IsA('Model') then
				anchor.CFrame = target
			elseif alignByPivot then
				clone:PivotTo(target)
			else
				clone:PivotTo(target * anchor.CFrame:ToObjectSpace(clone:GetPivot()))
			end
		end)

		weldAllTo(anchor, clone)

		local weld = Instance.new('WeldConstraint')
		weld.Part0 = origHandle
		weld.Part1 = anchor
		weld.Parent = anchor

		hideOriginal(entry, root)
		startRenderLoop()

		entry.conns[#entry.conns + 1] = root.DescendantAdded:Connect(function(d)
			if entry.clone and entry.clone.Parent and d:IsDescendantOf(entry.clone) then return end
			hideDescendant(entry, d)
		end)
		entry.conns[#entry.conns + 1] = root.AncestryChanged:Connect(function(_, parent)
			if not parent then detach(root) end
		end)
	end

	local function track(conn)
		hookConns[#hookConns + 1] = conn
		return conn
	end

	local function clearHooks()
		for _, c in hookConns do
			pcall(function() c:Disconnect() end)
		end
		table.clear(hookConns)
	end

	local function deferCall(fn, ...)
		local args = table.pack(...)
		task.spawn(function()
			task.wait()
			fn(table.unpack(args, 1, args.n))
		end)
	end

	local function skinNameForChild(childName)
		local mappings = getCurrentMappings()
		local skinName = mappings[childName:lower()]
		if not skinName then
			local norm = normalizeName(childName)
			for k, v in mappings do
				if normalizeName(k) == norm then
					skinName = v
					break
				end
			end
		end
		return skinName
	end

	local function applyItem(child)
		if not (VictoriousKitSkins and VictoriousKitSkins.Enabled) then return end
		if isCannonSkin() or not child or not child.Parent then return end
		local skinName = skinNameForChild(child.Name)
		if not skinName then return end
		local folder = itemsFolder()
		if not folder then return end
		attachReskin(child, skinName, folder:FindFirstChild(skinName))
	end

	local function applyCannon(child, placed)
		if not (VictoriousKitSkins and VictoriousKitSkins.Enabled) then return end
		if not isCannonSkin() or not child or not child.Parent then return end
		if child.Name ~= CANNON_TOOL_NAME then return end
		local skinName = getCannonSkinName()
		if not skinName then return end
		local folder = blocksFolder()
		if not folder then return end
		attachReskin(child, skinName, folder:FindFirstChild(skinName), {
			offset = placed and CANNON_PLACED_OFFSET or CFrame.identity,
			scale = placed and 1 or CANNON_HAND_SCALE,
		})
	end

	local function applyProjectile(inst)
		if not (VictoriousKitSkins and VictoriousKitSkins.Enabled) then return end
		if isCannonSkin() or not inst or not inst.Parent then return end
		if not inst:IsA('Model') or inst.Name ~= 'harpoon_projectile' then return end
		local shooter = inst:GetAttribute('ProjectileShooter')
		if not shooter or tostring(shooter) ~= tostring(LocalPlayer.UserId) then return end
		local skinName = getCurrentMappings().harpoon
		if not skinName then return end
		local folder = itemsFolder()
		if not folder then return end
		attachReskin(inst, skinName, folder:FindFirstChild(skinName))
	end

	local function hookItemContainer(container)
		if not container then return end
		for _, child in container:GetChildren() do
			deferCall(applyItem, child)
		end
		track(container.ChildAdded:Connect(function(child)
			deferCall(applyItem, child)
		end))
	end

	local function hookCannonContainer(container, placed)
		if not container then return end
		for _, child in container:GetChildren() do
			deferCall(applyCannon, child, placed)
		end
		track(container.ChildAdded:Connect(function(child)
			deferCall(applyCannon, child, placed)
		end))
	end

	local function hookViewmodel(vm)
		if not vm then return end
		if isCannonSkin() then
			hookCannonContainer(vm, false)
		else
			hookItemContainer(vm)
		end
	end

	local function hookCamera(cam)
		if not cam then return end
		local vm = cam:FindFirstChild('Viewmodel')
		if vm then hookViewmodel(vm) end
		track(cam.ChildAdded:Connect(function(child)
			if child.Name == 'Viewmodel' then
				deferCall(hookViewmodel, child)
			end
		end))
	end

	local function hookWorldCannons()
		local map = workspace:FindFirstChild('Map')
		if not map then return end
		local worlds = map:FindFirstChild('Worlds')
		if not worlds then return end
		local function hookWorld(world)
			local blocks = world:FindFirstChild('Blocks')
			if blocks then hookCannonContainer(blocks, true) end
		end
		for _, world in worlds:GetChildren() do
			hookWorld(world)
		end
		track(worlds.ChildAdded:Connect(function(world)
			deferCall(hookWorld, world)
		end))
	end

	local function hookProjectiles()
		track(workspace.DescendantAdded:Connect(function(inst)
			if inst.Name == 'harpoon_projectile' then
				deferCall(applyProjectile, inst)
			end
		end))
	end

	local function applyKitSkinHook()
		if not KitSkinCtrl then return end
		local val = getKitSkinValue()
		if not val then return end
		if not oldGetKitSkin then oldGetKitSkin = KitSkinCtrl.getKitSkin end
		local base = oldGetKitSkin
		KitSkinCtrl.getKitSkin = function(self, char)
			if char == LocalPlayer.Character then return val end
			return base(self, char)
		end
	end

	local function removeKitSkinHook()
		if KitSkinCtrl and oldGetKitSkin then
			KitSkinCtrl.getKitSkin = oldGetKitSkin
			oldGetKitSkin = nil
		end
	end

	local function hookCannonSounds()
		if soundsHooked then return end
		if not (bedwars and bedwars.CannonHandController) then return end
		soundsHooked = true
		oldFireCannon = bedwars.CannonHandController.fireCannon
		oldLaunchSelf = bedwars.CannonHandController.launchSelf

		local function replaceSound()
			pcall(function()
				local pool = workspace:FindFirstChild('SoundPool')
				if pool then
					for _, v in pool:GetChildren() do
						if v:IsA('Sound') and v.SoundId == 'rbxassetid://7121064180' then
							v:Destroy()
						end
					end
				end
				local key = CANNON_SOUND_NAMES[state.skinType] or CANNON_SOUND_NAMES.Nightmare
				if bedwars.SoundManager and bedwars.SoundList and bedwars.SoundList[key] then
					bedwars.SoundManager:playSound(bedwars.SoundList[key])
				end
			end)
		end

		if oldFireCannon then
			bedwars.CannonHandController.fireCannon = function(...)
				replaceSound()
				return oldFireCannon(...)
			end
		end
		if oldLaunchSelf then
			bedwars.CannonHandController.launchSelf = function(...)
				replaceSound()
				return oldLaunchSelf(...)
			end
		end
	end

	local function unhookCannonSounds()
		if soundsHooked and bedwars and bedwars.CannonHandController then
			if oldFireCannon then bedwars.CannonHandController.fireCannon = oldFireCannon end
			if oldLaunchSelf then bedwars.CannonHandController.launchSelf = oldLaunchSelf end
		end
		oldFireCannon = nil
		oldLaunchSelf = nil
		soundsHooked = false
	end

	local function hookCharacter(char)
		if not char then return end
		local backpack = LocalPlayer:FindFirstChildOfClass('Backpack')
		if isCannonSkin() then
			hookCannonContainer(char, false)
			hookCannonContainer(backpack, false)
		else
			hookItemContainer(char)
			hookItemContainer(backpack)
		end
	end

	local soundItems = {}

	local function applyKitSounds()
		for base, skin in getCurrentMappings() do
			applySkinSounds(base, skin)
			soundItems[base] = true
		end
	end

	local function clearKitSounds()
		for base in soundItems do
			applySkinSounds(base, nil)
		end
		table.clear(soundItems)
	end

	local function setup()
		if not (VictoriousKitSkins and VictoriousKitSkins.Enabled) then return end
		applyKitSkinHook()
		applyKitSounds()
		hookCamera(workspace.CurrentCamera)
		track(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
			if VictoriousKitSkins.Enabled then hookCamera(workspace.CurrentCamera) end
		end))
		if isCannonSkin() then
			hookCannonSounds()
			hookWorldCannons()
		else
			hookProjectiles()
		end
		hookCharacter(LocalPlayer.Character)
		track(LocalPlayer.CharacterAdded:Connect(function(char)
			task.spawn(function()
				task.wait(0.25)
				if not VictoriousKitSkins.Enabled then return end
				applyKitSkinHook()
				hookCharacter(char)
			end)
		end))
	end

	local function teardown()
		clearHooks()
		detachAll()
		stopRenderLoop()
		removeKitSkinHook()
		clearKitSounds()
		unhookCannonSounds()
	end

	local function refresh()
		if not (VictoriousKitSkins and VictoriousKitSkins.Enabled) then return end
		refreshVersion = refreshVersion + 1
		local version = refreshVersion
		teardown()
		task.defer(function()
			if version ~= refreshVersion then return end
			if VictoriousKitSkins.Enabled then setup() end
		end)
	end

	local function syncSkinTypeVisibility()
		if SkinTypeDropdown and SkinTypeDropdown.Object then
			SkinTypeDropdown.Object.Visible = TIERED_SKINS[state.itemSkin] == true
		end
	end

	local skinNames = {}
	local seenNames = {}
	for name in SKIN_DATA do
		if not seenNames[name] then
			seenNames[name] = true
			skinNames[#skinNames + 1] = name
		end
	end
	for name in CANNON_SKIN_NAMES do
		if not seenNames[name] then
			seenNames[name] = true
			skinNames[#skinNames + 1] = name
		end
	end
	table.sort(skinNames)

	VictoriousKitSkins = vape.Categories.Render:CreateModule({
		Name = 'VictoriousKitSkins',
		Function = function(enabled)
			if enabled then
				setup()
			else
				teardown()
			end
		end,
		Tooltip = 'gives u the victorious kit skins with the sounds, only u can see it so dont trip'
	})

	vape:Clean(function() teardown() end)

	ItemSkinDropdown = VictoriousKitSkins:CreateDropdown({
		Name = 'item skin',
		List = skinNames,
		Tooltip = 'which victorious kit u want the skins from',
		Default = state.itemSkin,
		Function = function(val)
			state.itemSkin = val
			if TIERED_SKINS[val] then
				state.skinType = SkinTypeDropdown and SkinTypeDropdown.Value or state.skinType
			else
				state.skinType = 'Default'
			end
			syncSkinTypeVisibility()
			refresh()
		end,
	})

	SkinTypeDropdown = VictoriousKitSkins:CreateDropdown({
		Name = 'skin type',
		List = {'Gold', 'Platinum', 'Diamond', 'Emerald', 'Nightmare', 'Default'},
		Tooltip = 'which tier of the skin u want, nightmare is the hardest one',
		Default = state.skinType,
		Visible = false,
		Function = function(val)
			if not TIERED_SKINS[state.itemSkin] then return end
			state.skinType = val
			refresh()
		end,
	})

	task.spawn(function()
		for _ = 1, 24 do
			syncSkinTypeVisibility()
			task.wait(0.25)
		end
	end)
end)
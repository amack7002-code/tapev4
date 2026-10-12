run(function()
	local SkinChanger
	local Options = {}
	local CategoryToggles = {}
	local skins, families, groups, order = {}, {}, {}, {}
	local names, familyCategory = {}, {}
	local sounds = {}
	local added = setmetatable({}, {__mode = 'k'})
	local watching, lasthand, queued
	local tiers = {leather = true, chainmail = true, wood = true, stone = true, gold = true, iron = true, diamond = true, emerald = true}
	local categories = {'swords', 'projectiles', 'tools', 'misc'}

	local ItemSkinType = {}
	pcall(function()
		ItemSkinType = require(replicatedStorage.TS.games.bedwars['item-skin']['item-skin-types']).ItemSkinType
	end)

	local viewmodelCtrl
	pcall(function()
		viewmodelCtrl = require(replicatedStorage.rbxts_include.node_modules['@easy-games'].knit.src).KnitClient.Controllers.InventoryViewmodelController
	end)

	local function prettyName(text)
		return (tostring(text):gsub('_', ' '):lower())
	end

	local function itemCategory(itemType)
		local meta = bedwars.ItemMeta[itemType]
		if not meta then return 'misc' end
		if meta.sword then return 'swords' end
		if meta.projectileSource then return 'projectiles' end
		if meta.breakBlock then return 'tools' end
		return 'misc'
	end

	for _, v in ItemSkinType do
		local meta = getItemSkinMeta(v)
		local item = meta and meta.itemType and bedwars.ItemMeta[meta.itemType]
		if item and not item.block then
			local label = `_{v}_`
			for i in meta.itemType:gmatch('[^_]+') do
				label = label:gsub(`_{i}_`, '_')
			end
			label = label:gsub('^_+', ''):gsub('_+$', '')
			label = prettyName(label ~= '' and label or v)
			skins[meta.itemType] = skins[meta.itemType] or {}
			skins[meta.itemType][label] = v
		end
	end

	for i in skins do
		local family = i:gsub('_%d+$', '')
		local tier, base = family:match('^([^_]+)_(.+)$')
		family = tier and tiers[tier] and base or family
		if not groups[family] then
			groups[family] = {}
			table.insert(order, family)
			familyCategory[family] = itemCategory(i)
		end
		families[i] = family
		table.insert(groups[family], i)
	end

	for i, v in groups do
		names[i] = prettyName(#v > 1 and i or v[1])
	end
	table.sort(order, function(a, b)
		return names[a] < names[b]
	end)

	local function pickedSkin(itemType)
		local family = SkinChanger.Enabled and families[itemType]
		local option = family and Options[family]
		local label = option and option.Value
		return label and skins[itemType] and skins[itemType][label] or nil
	end

	local function clearModel(accessory)
		local record = added[accessory]
		if not record then return end
		local handle = accessory:FindFirstChild('Handle')
		local template = replicatedStorage.Items:FindFirstChild(accessory.Name)
		for _, v in record.Parts do
			v:Destroy()
		end
		for _, v in handle and handle:GetChildren() or {} do
			local transparency = v:GetAttribute('SkinHidden')
			if transparency then
				v.Transparency = transparency
				v:SetAttribute('SkinHidden', nil)
			end
		end
		added[accessory] = nil
		if handle then
			if template and handle:IsA('MeshPart') and template.Handle:IsA('MeshPart') then
				handle:ApplyMesh(template.Handle)
			end
			handle.Size = record.Size
			local grip = handle:FindFirstChild('RightGripAttachment')
			if grip and record.Grip then
				grip.CFrame = record.Grip
			end
		end
	end

	local function applyModel(accessory)
		local model = pickedSkin(accessory.Name)
		local handle = accessory:FindFirstChild('Handle')
		local template = replicatedStorage.Items:FindFirstChild(model or '')
		if not handle or not template or added[accessory] then return end

		local grip = handle:FindFirstChild('RightGripAttachment')
		local templategrip = template.Handle:FindFirstChild('RightGripAttachment')
		local record = {Parts = {}, Size = handle.Size, Grip = grip and grip.CFrame or nil}
		added[accessory] = record

		for _, v in handle:GetChildren() do
			if v:IsA('BasePart') and v:GetAttribute('SkinHidden') == nil then
				v:SetAttribute('SkinHidden', v.Transparency)
				v.Transparency = 1
			end
		end

		if handle:IsA('MeshPart') and template.Handle:IsA('MeshPart') then
			handle:ApplyMesh(template.Handle)
		end
		handle.Size = template.Handle.Size
		if grip and templategrip then
			grip.CFrame = templategrip.CFrame
		end

		for _, v in template.Handle:GetChildren() do
			if v:IsA('BasePart') then
				local part = v:Clone()
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.Massless = true
				part.CFrame = handle.CFrame * (template.Handle.CFrame:Inverse() * v.CFrame)
				part.Parent = handle
				local weld = Instance.new('WeldConstraint')
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = part
				table.insert(record.Parts, part)
			end
		end
	end

	local function applySounds()
		for i in skins do
			local skin = pickedSkin(i) or false
			if sounds[i] ~= skin then
				sounds[i] = skin
				applySkinSounds(i, skin or nil)
			end
		end
	end

	local function applySkins()
		applySounds()

		local inventory = store.inventory.inventory
		local changed = false
		for _, v in inventory.items do
			local skin = pickedSkin(v.itemType)
			if v.itemSkin ~= skin then
				v.itemSkin = skin
				changed = true
			end
		end
		if inventory.hand then
			local skin = pickedSkin(inventory.hand.itemType)
			if inventory.hand.itemSkin ~= skin then
				inventory.hand.itemSkin = skin
				changed = true
			end
		end

		local hand = inventory.hand and inventory.hand.itemType
		if not changed and hand == lasthand then return end
		lasthand = hand

		if viewmodelCtrl then
			pcall(function()
				viewmodelCtrl:handleStore(bedwars.Store:getState())
			end)
		end
		if not lplr.Character then return end

		for _, v in lplr.Character:GetChildren() do
			if v:IsA('Accessory') then
				clearModel(v)
				applyModel(v)
			end
		end
	end

	local function queueSkins()
		if queued then return end
		queued = true
		task.defer(function()
			queued = false
			applySkins()
		end)
	end

	local function watchCharacter(char)
		if watching then
			watching:Disconnect()
		end
		watching = char.ChildAdded:Connect(function(v)
			if v:IsA('Accessory') and v:WaitForChild('Handle', 3) and SkinChanger.Enabled then
				applyModel(v)
			end
		end)
	end

	SkinChanger = vape.Categories.Render:CreateModule({
		Name = 'SkinChanger',
		Function = function(callback)
			if callback then
				SkinChanger:Clean(vapeEvents.InventoryChanged.Event:Connect(queueSkins))
				SkinChanger:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(queueSkins))
				SkinChanger:Clean(lplr.CharacterAdded:Connect(function(char)
					lasthand = nil
					watchCharacter(char)
					task.spawn(function()
						for _ = 1, 10 do
							task.wait(0.4)
							if not SkinChanger.Enabled then return end
							applySkins()
						end
					end)
				end))
				if lplr.Character then
					watchCharacter(lplr.Character)
				end
			elseif watching then
				watching:Disconnect()
				watching = nil
			end
			lasthand = nil
			applySkins()
		end,
		Tooltip = 'pick a skin for every item u got, sounds too, only u can see it tho'
	})

	for _, category in categories do
		CategoryToggles[category] = SkinChanger:CreateToggle({
			Name = category,
			Default = false,
			Tooltip = 'shows the skins for ur ' .. category,
			Function = function(callback)
				for family, option in Options do
					if familyCategory[family] == category then
						option.Object.Visible = callback
					end
				end
			end
		})

		for _, family in order do
			if familyCategory[family] == category then
				local list, seen = {}, {}
				for _, itemType in groups[family] do
					for label in skins[itemType] do
						if not seen[label] then
							seen[label] = true
							table.insert(list, label)
						end
					end
				end
				table.sort(list)
				table.insert(list, 1, 'none')
				Options[family] = SkinChanger:CreateDropdown({
					Name = names[family],
					List = list,
					Darker = true,
					Visible = false,
					Function = function()
						if SkinChanger.Enabled then
							lasthand = nil
							applySkins()
						end
					end
				})
			end
		end
	end

	task.defer(function()
		for family, option in Options do
			local toggle = CategoryToggles[familyCategory[family]]
			option.Object.Visible = toggle and toggle.Enabled or false
		end
	end)
end)
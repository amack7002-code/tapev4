run(function()
	local ArmorTrims
	local TrimType
	local TrimEffect
	local TrimRank
	local TrimColor

	local RS = game:GetService('ReplicatedStorage')
	local ANCHORS = {
		boots_left_trim = 'LeftFoot',
		boots_right_trim = 'RightFoot',
		chestplate_left_shoulder_trim = 'LeftUpperArm',
		chestplate_right_shoulder_trim = 'RightUpperArm',
		chestplate_trim = 'UpperTorso',
		chestplate_lower_trim = 'LowerTorso',
		helmet_trim = 'Head'
	}
	local EFFECTS = {'default', 'void', 'spirit', 'phoenix', 'bat', 'anniversary', 'frosty', 'fire_warm', 'fire_cold', 'fire_red', 'fire_black', 'fire_purple'}
	local RANKS = {'T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'}
	local COLORS = {'RED', 'ORANGE', 'YELLOW', 'GREEN', 'BLUE', 'INDIGO', 'PURPLE', 'WHITE', 'BLACK', 'BROWN', 'PINK'}
	local TRIMS = {}
	for i = 1, 12 do TRIMS[i] = 'trim_' .. i end

	local spawned = {}
	local cache = {}
	local controller = nil
	local applyToken = 0

	local function cached(path, key)
		local id = path .. '|' .. tostring(key)
		local hit = cache[id]
		if hit ~= nil then
			return hit ~= false and hit or nil
		end
		local ok, mod = pcall(function()
			return require(RS.TS['armor-trim'][path])
		end)
		local value = nil
		if ok and type(mod) == 'table' then
			value = key and mod[key] or mod
		end
		cache[id] = value == nil and false or value
		return value
	end

	local function colorIndex()
		local m = cached('armor-trim-colors', 'ArmorTrimColor')
		return m and m[TrimColor.Value] or 0
	end

	local function rankIndex()
		local m = cached('armor-trim-rank', 'ArmorTrimEffectRank')
		return m and m[TrimRank.Value] or 0
	end

	local function colorValue()
		local m = cached('armor-trim-color-meta', 'ArmorTrimColorMeta')
		local entry = m and m[colorIndex()]
		local value = entry and entry.color
		if typeof(value) == 'Color3' then
			return value
		end
		return Color3.new(1, 1, 1)
	end

	local function rankMaterial()
		local m = cached('armor-trim-rank', 'ArmorTrimEffectRankMeta')
		local entry = m and m[rankIndex()]
		return entry and entry.material or Enum.Material.Plastic
	end

	local function getController()
		if controller then return controller end
		local ok, Knit = pcall(function()
			return require(RS.rbxts_include.node_modules['@easy-games'].knit.src).KnitClient
		end)
		if ok and Knit then
			controller = Knit.Controllers.ArmorTrimController
		end
		return controller
	end

	local function clearAccessories()
		for _, acc in spawned do
			pcall(function() acc:Destroy() end)
		end
		table.clear(spawned)
	end

	local function setAttributes()
		local char = lplr.Character
		local trim, effect, rank, color = TrimType.Value, TrimEffect.Value, rankIndex(), colorIndex()
		for _, target in {lplr, char} do
			if target then
				pcall(function()
					target:SetAttribute('ArmorTrimType', trim)
					target:SetAttribute('ArmorTrimEffectType', effect)
					target:SetAttribute('ArmorTrimEffectRank', rank)
					target:SetAttribute('ArmorTrimColor', color)
				end)
			end
		end
	end

	local function refreshEffects()
		local char = lplr.Character
		local ctrl = getController()
		if not char or not ctrl then return end
		for _, acc in char:GetChildren() do
			if acc:IsA('Accessory') and ANCHORS[acc.Name] then
				if not pcall(function() ctrl:attachArmorTrim(lplr, acc) end) then
					pcall(function() ctrl:attachArmorTrim(acc, lplr) end)
				end
			end
		end
	end

	local function spawnAccessories()
		clearAccessories()
		local char = lplr.Character
		local hum = char and char:FindFirstChildOfClass('Humanoid')
		if not hum then return end
		local folder = RS:FindFirstChild('Assets')
		folder = folder and folder:FindFirstChild('ArmorTrims')
		folder = folder and folder:FindFirstChild(TrimType.Value)
		if not folder then return end

		local col = colorValue()
		local mat = rankMaterial()

		local owned = {}
		for _, existing in char:GetChildren() do
			if existing:IsA('Accessory') and ANCHORS[existing.Name] then
				owned[existing.Name] = true
			end
		end

		for _, acc in folder:GetChildren() do
			if acc:IsA('Accessory') and ANCHORS[acc.Name] and not owned[acc.Name] then
				local clone = acc:Clone()
				for _, d in clone:GetDescendants() do
					if d:IsA('BasePart') then
						d.Color = col
						d.Material = mat
						d.CanCollide = false
						d.CanQuery = false
						d.CanTouch = false
						d.Massless = true
					elseif d:IsA('TouchTransmitter') then
						pcall(function() d:Destroy() end)
					end
				end
				if not pcall(function() hum:AddAccessory(clone) end) then
					local handle = clone:FindFirstChild('Handle')
					local anchor = char:FindFirstChild(ANCHORS[acc.Name])
					if handle and anchor then
						handle.CFrame = anchor.CFrame
						local weld = Instance.new('WeldConstraint')
						weld.Part0 = anchor
						weld.Part1 = handle
						weld.Parent = handle
						clone.Parent = char
					else
						clone:Destroy()
						clone = nil
					end
				end
				if clone then
					table.insert(spawned, clone)
				end
			end
		end
	end

	local function applyAll()
		if not (ArmorTrims and ArmorTrims.Enabled) then return end
		applyToken = applyToken + 1
		local token = applyToken
		task.spawn(function()
			task.wait(0.1)
			if token ~= applyToken then return end
			if not ArmorTrims.Enabled then return end
			setAttributes()
			spawnAccessories()
			refreshEffects()
		end)
	end

	ArmorTrims = vape.Categories.Render:CreateModule({
		Name = 'ArmorTrims',
		Function = function(callback)
			if callback then
				applyAll()
				ArmorTrims:Clean(lplr.CharacterAdded:Connect(function(char)
					task.spawn(function()
						char:WaitForChild('Humanoid', 10)
						task.wait(1)
						if ArmorTrims.Enabled then applyAll() end
					end)
				end))
				ArmorTrims:Clean(clearAccessories)
			else
				applyToken = applyToken + 1
				clearAccessories()
				local char = lplr.Character
				for _, target in {lplr, char} do
					if target then
						pcall(function()
							target:SetAttribute('ArmorTrimEffectType', nil)
							target:SetAttribute('ArmorTrimEffectRank', nil)
						end)
					end
				end
			end
		end,
		Tooltip = 'gives ur armor a trim with effects, only u can see it'
	})

	vape:Clean(clearAccessories)

	TrimType = ArmorTrims:CreateDropdown({
		Name = 'Trim Type',
		List = TRIMS,
		Default = 'trim_1',
		Function = function() applyAll() end
	})
	TrimEffect = ArmorTrims:CreateDropdown({
		Name = 'Effect',
		List = EFFECTS,
		Default = 'void',
		Function = function() applyAll() end,
		Tooltip = 'the particles on ur trim'
	})
	TrimRank = ArmorTrims:CreateDropdown({
		Name = 'Rank',
		List = RANKS,
		Default = 'T7',
		Function = function() applyAll() end,
		Tooltip = 'higher tier looks crazier, T7 is neon'
	})
	TrimColor = ArmorTrims:CreateDropdown({
		Name = 'Color',
		List = COLORS,
		Default = 'RED',
		Function = function() applyAll() end
	})
end)
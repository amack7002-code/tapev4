run(function()
	local PotatoMode
	local Mode
	local originalProperties = {}
	local blockMonitorConnections = {}
	local processedBlocks = {}

	local blockColors = {
		["wool_white"] = Color3.fromRGB(255, 255, 255),
		["wool_red"] = Color3.fromRGB(255, 50, 50),
		["wool_green"] = Color3.fromRGB(50, 255, 50),
		["wool_blue"] = Color3.fromRGB(50, 100, 255),
		["wool_yellow"] = Color3.fromRGB(255, 255, 50),
		["wool_orange"] = Color3.fromRGB(255, 150, 50),
		["wool_purple"] = Color3.fromRGB(180, 50, 255),
		["wool_pink"] = Color3.fromRGB(255, 100, 200),
		["wool_black"] = Color3.fromRGB(50, 50, 50),
		["wool_cyan"] = Color3.fromRGB(50, 255, 255),
		["wool_magenta"] = Color3.fromRGB(255, 50, 150),
		["wool_lime"] = Color3.fromRGB(150, 255, 50),
		["wool_brown"] = Color3.fromRGB(150, 75, 0),
		["wool_light_blue"] = Color3.fromRGB(100, 200, 255),
		["wool_gray"] = Color3.fromRGB(150, 150, 150),
		["wool_builder"] = Color3.fromRGB(200, 200, 200),
		["wool_shear"] = Color3.fromRGB(200, 200, 200),
		["wool"] = Color3.fromRGB(200, 200, 200),
		["clay_white"] = Color3.fromRGB(255, 255, 255),
		["clay_black"] = Color3.fromRGB(50, 50, 50),
		["clay_blue"] = Color3.fromRGB(50, 100, 255),
		["clay_dark_brown"] = Color3.fromRGB(100, 60, 30),
		["clay_dark_green"] = Color3.fromRGB(30, 100, 30),
		["clay_gray"] = Color3.fromRGB(150, 150, 150),
		["clay_green"] = Color3.fromRGB(50, 255, 50),
		["clay_light_brown"] = Color3.fromRGB(200, 170, 120),
		["clay_light_green"] = Color3.fromRGB(150, 255, 150),
		["clay_orange"] = Color3.fromRGB(255, 150, 50),
		["clay_pink"] = Color3.fromRGB(255, 100, 200),
		["clay_purple"] = Color3.fromRGB(180, 50, 255),
		["clay_red"] = Color3.fromRGB(255, 50, 50),
		["clay_tan"] = Color3.fromRGB(210, 180, 140),
		["clay_yellow"] = Color3.fromRGB(255, 255, 50),
		["clay"] = Color3.fromRGB(220, 180, 140),
		["wood_plank_spruce"] = Color3.fromRGB(222, 184, 135),
		["wood_plank_birch"] = Color3.fromRGB(230, 220, 190),
		["wood_plank_maple"] = Color3.fromRGB(200, 140, 90),
		["wood_plank_oak"] = Color3.fromRGB(180, 140, 100),
		["wood_plank_oak_builder"] = Color3.fromRGB(180, 140, 100),
		["oak_log"] = Color3.fromRGB(120, 90, 60),
		["birch_log"] = Color3.fromRGB(220, 210, 180),
		["spruce_log"] = Color3.fromRGB(100, 75, 50),
		["hickory_log"] = Color3.fromRGB(140, 100, 60),
		["wood"] = Color3.fromRGB(180, 140, 100),
		["stone"] = Color3.fromRGB(150, 150, 150),
		["stone_brick"] = Color3.fromRGB(140, 140, 140),
		["stone_brick_builder"] = Color3.fromRGB(140, 140, 140),
		["stone_slab"] = Color3.fromRGB(160, 160, 160),
		["stone_pillar"] = Color3.fromRGB(160, 160, 160),
		["stone_tiles"] = Color3.fromRGB(160, 160, 160),
		["stone_player_block"] = Color3.fromRGB(150, 150, 150),
		["andesite"] = Color3.fromRGB(150, 150, 150),
		["andesite_polished"] = Color3.fromRGB(160, 160, 160),
		["diorite"] = Color3.fromRGB(220, 220, 220),
		["diorite_polished"] = Color3.fromRGB(230, 230, 230),
		["granite"] = Color3.fromRGB(180, 100, 80),
		["granite_polished"] = Color3.fromRGB(190, 110, 90),
		["cobblestone"] = Color3.fromRGB(150, 150, 150),
		["limestone"] = Color3.fromRGB(210, 200, 180),
		["marble"] = Color3.fromRGB(235, 235, 235),
		["marble_pillar"] = Color3.fromRGB(235, 235, 235),
		["slate_brick"] = Color3.fromRGB(90, 95, 100),
		["slate_tiles"] = Color3.fromRGB(90, 95, 100),
		["volatile_stone"] = Color3.fromRGB(150, 150, 150),
		["obsidian"] = Color3.fromRGB(50, 30, 80),
		["bedrock"] = Color3.fromRGB(80, 80, 80),
		["tnt"] = Color3.fromRGB(255, 50, 50),
		["sandstone"] = Color3.fromRGB(220, 200, 150),
		["sandstone_polished"] = Color3.fromRGB(225, 205, 155),
		["sandstone_smooth"] = Color3.fromRGB(225, 205, 155),
		["red_sandstone"] = Color3.fromRGB(190, 110, 60),
		["red_sandstone_polished"] = Color3.fromRGB(195, 115, 65),
		["red_sandstone_smooth"] = Color3.fromRGB(195, 115, 65),
		["sand"] = Color3.fromRGB(220, 200, 150),
		["red_sand"] = Color3.fromRGB(190, 110, 60),
		["glass"] = Color3.fromRGB(200, 230, 230),
		["magic_glass"] = Color3.fromRGB(150, 200, 255),
		["diamond"] = Color3.fromRGB(100, 220, 220),
		["diamond_block"] = Color3.fromRGB(100, 220, 220),
		["diamond_ore"] = Color3.fromRGB(100, 220, 220),
		["emerald"] = Color3.fromRGB(50, 255, 50),
		["emerald_block"] = Color3.fromRGB(50, 255, 50),
		["emerald_ore"] = Color3.fromRGB(50, 255, 50),
		["iron"] = Color3.fromRGB(220, 220, 220),
		["iron_block"] = Color3.fromRGB(220, 220, 220),
		["iron_ore"] = Color3.fromRGB(200, 200, 200),
		["iron_ore_mesh_block"] = Color3.fromRGB(200, 200, 200),
		["gold"] = Color3.fromRGB(255, 215, 0),
		["gold_block"] = Color3.fromRGB(255, 215, 0),
		["copper_block"] = Color3.fromRGB(184, 115, 51),
		["steel_block"] = Color3.fromRGB(170, 170, 180),
		["galactite"] = Color3.fromRGB(100, 80, 160),
		["galactite_brick"] = Color3.fromRGB(100, 80, 160),
		["crystal_ore"] = Color3.fromRGB(180, 150, 255),
		["guilded_iron"] = Color3.fromRGB(230, 200, 100),
		["ceramic"] = Color3.fromRGB(230, 140, 60),
		["aquamarine_lantern"] = Color3.fromRGB(80, 220, 200),
		["barrel"] = Color3.fromRGB(140, 95, 55),
		["bookshelf"] = Color3.fromRGB(150, 100, 60),
		["brick"] = Color3.fromRGB(160, 80, 60),
		["grass"] = Color3.fromRGB(50, 255, 50),
		["moss_block"] = Color3.fromRGB(50, 150, 50),
		["dirt"] = Color3.fromRGB(120, 80, 50),
		["void_dirt"] = Color3.fromRGB(60, 40, 25),
		["void_grass"] = Color3.fromRGB(25, 80, 25),
		["ice"] = Color3.fromRGB(180, 220, 255),
		["snow"] = Color3.fromRGB(255, 255, 255),
		["snow_pile"] = Color3.fromRGB(255, 255, 255),
		["glowstone"] = Color3.fromRGB(255, 240, 150),
		["magma_block"] = Color3.fromRGB(200, 80, 30),
		["slime_block"] = Color3.fromRGB(120, 230, 120),
		["gum_block"] = Color3.fromRGB(255, 150, 200),
		["invisible_block"] = Color3.fromRGB(255, 255, 255),
		["void_block"] = Color3.fromRGB(20, 20, 20),
		["smoke_block"] = Color3.fromRGB(130, 130, 130),
		["cotton_candy_block"] = Color3.fromRGB(255, 200, 230),
		["cotton_candy_block_blue"] = Color3.fromRGB(150, 200, 255),
		["cotton_candy_block_orange"] = Color3.fromRGB(255, 180, 120),
		["cotton_candy_block_pink"] = Color3.fromRGB(255, 150, 200),
		["cotton_candy_block_yellow"] = Color3.fromRGB(255, 240, 150),
		["blue_tile"] = Color3.fromRGB(50, 100, 255),
		["concrete_green"] = Color3.fromRGB(50, 180, 50),
		["concrete"] = Color3.fromRGB(180, 180, 180),
		["bed"] = Color3.fromRGB(200, 50, 50),
		["og_bed"] = Color3.fromRGB(200, 50, 50),
		["royale_bed"] = Color3.fromRGB(200, 50, 50),
		["fake_bed"] = Color3.fromRGB(200, 50, 50),
		["barrier"] = Color3.fromRGB(255, 0, 0),
		["ladder"] = Color3.fromRGB(150, 100, 50),
		["vine_ladder"] = Color3.fromRGB(60, 120, 60),
		["scaffold"] = Color3.fromRGB(180, 140, 100),
		["christmas_scaffold"] = Color3.fromRGB(180, 140, 100),
		["drawbridge"] = Color3.fromRGB(150, 110, 70),
		["christmas_drawbridge"] = Color3.fromRGB(150, 110, 70),
		["haybale"] = Color3.fromRGB(230, 200, 100),
		["purple_hay_bale"] = Color3.fromRGB(180, 50, 255),
	}

	local cachedColors = {}

	local function getBlockColor(blockName)
		if cachedColors[blockName] then
			return cachedColors[blockName]
		end

		if blockColors[blockName] then
			cachedColors[blockName] = blockColors[blockName]
			return blockColors[blockName]
		end

		local lowerName = blockName:lower()

		if blockColors[lowerName] then
			cachedColors[blockName] = blockColors[lowerName]
			return blockColors[lowerName]
		end

		if lowerName:find("wool", 1, true) then
			for key, color in pairs(blockColors) do
				if key:find("wool", 1, true) and lowerName:find(key, 1, true) then
					cachedColors[blockName] = color
					return color
				end
			end
			cachedColors[blockName] = blockColors["wool"]
			return blockColors["wool"]
		end

		if lowerName:find("clay", 1, true) then
			for key, color in pairs(blockColors) do
				if key:find("clay", 1, true) and lowerName:find(key, 1, true) then
					cachedColors[blockName] = color
					return color
				end
			end
			cachedColors[blockName] = blockColors["clay"]
			return blockColors["clay"]
		end

		for name, color in pairs(blockColors) do
			if lowerName:find(name, 1, true) then
				cachedColors[blockName] = color
				return color
			end
		end

		local defaultColor = Color3.fromRGB(150, 150, 150)
		cachedColors[blockName] = defaultColor
		return defaultColor
	end

	local function cleanupDeadReferences()
		for block, _ in pairs(originalProperties) do
			if not block or not block.Parent then
				originalProperties[block] = nil
				processedBlocks[block] = nil
			end
		end
	end

	local function simplifyBlock(block)
		if not block or not block.Parent or processedBlocks[block] then return end

		if not originalProperties[block] then
			originalProperties[block] = {
				Material = block.Material,
				Color = block.Color,
				TextureID = block:IsA("MeshPart") and block.TextureID or nil,
				Textures = {}
			}

			for _, child in block:GetChildren() do
				if child:IsA("Texture") or child:IsA("Decal") then
					table.insert(originalProperties[block].Textures, {
						Class = child.ClassName,
						Texture = child.Texture,
						StudsPerTileU = child:IsA("Texture") and child.StudsPerTileU or nil,
						StudsPerTileV = child:IsA("Texture") and child.StudsPerTileV or nil,
						Face = child.Face,
						Transparency = child.Transparency,
						Color3 = child:IsA("Decal") and child.Color3 or nil
					})
				end
			end
		end

		block.Material = Enum.Material.SmoothPlastic
		block.Color = getBlockColor(block.Name)

		for _, child in block:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				child:Destroy()
			end
		end

		if block:IsA("MeshPart") and block.TextureID ~= "" then
			block.TextureID = ""
		end

		processedBlocks[block] = true
	end

	local function restoreBlock(block)
		if not block or not block.Parent then
			originalProperties[block] = nil
			processedBlocks[block] = nil
			return
		end

		local props = originalProperties[block]
		if not props then return end

		block.Material = props.Material or Enum.Material.Plastic
		block.Color = props.Color or Color3.fromRGB(255, 255, 255)

		if props.TextureID and block:IsA("MeshPart") then
			block.TextureID = props.TextureID
		end

		for _, textureProps in props.Textures do
			local newTexture
			if textureProps.Class == "Texture" then
				newTexture = Instance.new("Texture")
				newTexture.StudsPerTileU = textureProps.StudsPerTileU or 1
				newTexture.StudsPerTileV = textureProps.StudsPerTileV or 1
			else
				newTexture = Instance.new("Decal")
				newTexture.Color3 = textureProps.Color3 or Color3.fromRGB(255, 255, 255)
			end

			newTexture.Texture = textureProps.Texture or ""
			newTexture.Face = textureProps.Face or Enum.NormalId.Front
			newTexture.Transparency = textureProps.Transparency or 0
			newTexture.Parent = block
		end

		originalProperties[block] = nil
		processedBlocks[block] = nil
	end

	local function isTargetBlock(obj)
		if not obj:IsA("BasePart") then return false end

		local name = obj.Name

		if blockColors[name] then return true end

		local lowerName = name:lower()
		return lowerName:find("wool", 1, true) or
		       lowerName:find("clay", 1, true) or
		       lowerName:find("wood", 1, true) or
		       lowerName:find("log", 1, true) or
		       lowerName:find("stone", 1, true) or
		       lowerName:find("brick", 1, true) or
		       lowerName:find("glass", 1, true) or
		       lowerName:find("plank", 1, true) or
		       lowerName:find("bed", 1, true) or
		       lowerName:find("obsidian", 1, true) or
		       lowerName:find("sand", 1, true) or
		       lowerName:find("tnt", 1, true) or
		       lowerName:find("barrier", 1, true) or
		       lowerName:find("magic", 1, true) or
		       lowerName:find("concrete", 1, true) or
		       lowerName:find("diamond", 1, true) or
		       lowerName:find("emerald", 1, true) or
		       lowerName:find("iron", 1, true) or
		       lowerName:find("gold", 1, true) or
		       lowerName:find("copper", 1, true) or
		       lowerName:find("steel", 1, true) or
		       lowerName:find("ore", 1, true) or
		       lowerName:find("marble", 1, true) or
		       lowerName:find("slate", 1, true) or
		       lowerName:find("granite", 1, true) or
		       lowerName:find("andesite", 1, true) or
		       lowerName:find("diorite", 1, true) or
		       lowerName:find("grass", 1, true) or
		       lowerName:find("dirt", 1, true) or
		       lowerName:find("ice", 1, true) or
		       lowerName:find("snow", 1, true) or
		       lowerName:find("moss", 1, true) or
		       lowerName:find("slime", 1, true) or
		       lowerName:find("scaffold", 1, true) or
		       lowerName:find("ladder", 1, true) or
		       lowerName:find("tile", 1, true) or
		       lowerName:find("cotton_candy", 1, true) or
		       lowerName:find("_block", 1, true) or
		       obj:IsA("Seat")
	end

	local function processExistingBlocks(simplify)
		scanDescendants(workspace, function(obj)
			if isTargetBlock(obj) then
				if simplify then
					simplifyBlock(obj)
				else
					restoreBlock(obj)
				end
			end
		end)

		if not simplify then
			task.delay(2, cleanupDeadReferences)
		end
	end

	local function setupBlockMonitor(simplify)
		for _, conn in blockMonitorConnections do
			conn:Disconnect()
		end
		table.clear(blockMonitorConnections)

		if not simplify then return end

		local mainConn = workspace.DescendantAdded:Connect(function(descendant)
			if isTargetBlock(descendant) then
				task.defer(function()
					if descendant and descendant.Parent then
						simplifyBlock(descendant)
					end
				end)
			end
		end)

		table.insert(blockMonitorConnections, mainConn)

		local lastCleanup = 0
		local cleanupConn = runService.Heartbeat:Connect(function()
			local now = tick()
			if now - lastCleanup >= 5 then
				lastCleanup = now
				cleanupDeadReferences()
			end
		end)

		table.insert(blockMonitorConnections, cleanupConn)
	end

	local ntReference = {}
	local function ntRemember(obj, property)
		local props = ntReference[obj]
		if not props then
			props = {}
			ntReference[obj] = props
		end
		if props[property] == nil then
			props[property] = obj[property]
		end
	end
	local function ntStrip(obj)
		if obj:IsA('Decal') then
			ntRemember(obj, 'Transparency')
			obj.Transparency = 1
			return
		end
		if obj:IsA('SurfaceAppearance') then
			ntRemember(obj, 'Parent')
			obj.Parent = nil
			return
		end
		if obj:IsA('SpecialMesh') then
			ntRemember(obj, 'TextureId')
			obj.TextureId = ''
			return
		end
		if obj:IsA('BasePart') then
			if obj:IsA('MeshPart') then
				ntRemember(obj, 'TextureID')
				obj.TextureID = ''
			end
			ntRemember(obj, 'Material')
			obj.Material = Enum.Material.SmoothPlastic
		end
	end
	local function ntRestore()
		for i, v in ntReference do
			pcall(function()
				for property, value in v do
					i[property] = value
				end
			end)
		end
		table.clear(ntReference)
	end
	local function ntScan()
		local descendants = store.map:GetDescendants()
		for i, v in descendants do
			if not PotatoMode.Enabled or Mode.Value ~= 'No Texture' then return end
			ntStrip(v)
			if i % 500 == 0 then
				task.wait()
			end
		end
	end

	PotatoMode = vape.Categories.World:CreateModule({
		Name = 'PotatoMode',
		Function = function(callback)
			if callback then
				if Mode.Value == 'No Texture' then
					repeat task.wait() until store.map or not PotatoMode.Enabled
					if not PotatoMode.Enabled then return end
					PotatoMode:Clean(store.map.DescendantAdded:Connect(function(obj)
						task.defer(ntStrip, obj)
					end))
					ntScan()
				else
					processExistingBlocks(true)
					setupBlockMonitor(true)
				end
			else
				processExistingBlocks(false)
				for _, conn in blockMonitorConnections do
					conn:Disconnect()
				end
				table.clear(blockMonitorConnections)
				table.clear(cachedColors)
				cleanupDeadReferences()
				ntRestore()
			end
		end,
	})
	Mode = PotatoMode:CreateDropdown({
		Name = 'Mode',
		List = {'Original', 'No Texture'},
		Default = 'Original',
		Tooltip = 'Original = flat colored blocks, No Texture = strips everything off the map',
		Function = function(val)
			if PotatoMode.Enabled then
				PotatoMode:Toggle()
				PotatoMode:Toggle()
			end
		end
	})
end)
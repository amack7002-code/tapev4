run(function()
	local NameTags
	local StreamProof
	local Targets
	local Color
	local Background
	local DisplayName
	local Health
	local HealthColorToggle
	local HealthColorFull
	local HealthColorMid
	local HealthColorLow
	local Distance
	local Equipment
	local Loot
	local Potions
	local potionDefs = {
		{name = 'PotSerpent', attr = 'StatusEffect_serpents_touch_potion', item = 'serpents_touch_potion', timed = true},
		{name = 'PotFury', attr = 'StatusEffect_fury_potion', item = 'fury_potion', timed = true},
		{name = 'PotInvis', attr = 'StatusEffect_invisibility', item = 'invisibility_potion', timed = true},
		{name = 'PotJump', attr = 'JumpBoost', item = 'jump_potion', timed = false},
		{name = 'PotPie', attr = 'SpeedPieBuff', item = 'speed_pie', timed = false}
	}
	local function potionActive(char, def)
		if not char then return false end
		local val = char:GetAttribute(def.attr)
		if val == nil then return false end
		if def.timed then
			return type(val) == 'number' and val > workspace:GetServerTimeNow()
		end
		return val ~= false and val ~= 0
	end
	local Boss
	local ShowKits
	local KitTracker
	local Rank
	local DeviceIcon
	local GloopIndicator
	local Enchant
	local Scale
	local FontOption
	local Teammates
	local DistanceCheck
	local DistanceLimit
	local Strings, Sizes, Reference = {}, {}, {}
	local bossNametags = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local methodused
	local Removed
	local lastUpdate = {}
	local kitCache = {}
	local lootCache = {}
	local equipmentCache = {}
	local enchantCache = {}
	local healthCache = {}
	local charCache = {}
	local enchantConnections = {}
	local gloopConnections = {}
	local kitTrackerConnections = {}
	local billboardCache = {}
	local tick = tick
	local math_floor = math.floor
	local math_round = math.round
	local math_clamp = math.clamp
	local math_huge = math.huge
	local string_format = string.format
	local vector2new = Vector2.new
	local vector3new = Vector3.new
	local color3fromHSV = Color3.fromHSV
	local color3new = Color3.new
	
	local function getTeamColor(ent)
		local plr = ent and ent.Player
		if not plr then return nil end
		local theirTeam = tonumber(plr:GetAttribute('Team'))
		if not theirTeam then return nil end
		local myTeam = tonumber(lplr:GetAttribute('Team'))
		if myTeam and myTeam == theirTeam then return nil end
		local entry = getgenv().aeroTeamColors[theirTeam]
		return entry and entry.color
	end
	local udim2fromOffset = UDim2.fromOffset

	local function getChainsawImage(level)
		if not level or level < 1 or level > 5 then return '' end
		local success, img = pcall(function()
			local imageModule = require(game:GetService("ReplicatedStorage"):WaitForChild("TS"):WaitForChild("image"):WaitForChild("image-id"))
			local ids = {
				[1] = imageModule.BedwarsImageId.WOOD_TINKER_MECH,
				[2] = imageModule.BedwarsImageId.IRON_TINKER_MECH,
				[3] = imageModule.BedwarsImageId.DIAMOND_TINKER_MECH,
				[4] = imageModule.BedwarsImageId.EMERALD_TINKER_MECH,
				[5] = imageModule.BedwarsImageId.VOID_TINKER_MECH,
			}
			return ids[level]
		end)
		if success and img then
			return img
		end
		local fallback = {
			[1] = "rbxassetid://1234567890", 
			[2] = "rbxassetid://1234567891", 
			[3] = "rbxassetid://1234567892", 
			[4] = "rbxassetid://1234567893", 
			[5] = "rbxassetid://1234567894", 
		}
		return fallback[level] or ''
	end

	local function splitHealth(ent)
		local shield = ent.Character and getShieldAttribute(ent.Character) or 0
		return math.round((ent.Health or 0) - shield), math.round(shield)
	end

	local function getHealthColor(ent)
		local hp = splitHealth(ent)
		local ratio = math.clamp(hp / (ent.MaxHealth and ent.MaxHealth > 0 and ent.MaxHealth or 1), 0, 1)
		if HealthColorToggle and HealthColorToggle.Enabled then
			local fullC = Color3.fromHSV(HealthColorFull.Hue, HealthColorFull.Sat, HealthColorFull.Value)
			local midC  = Color3.fromHSV(HealthColorMid.Hue,  HealthColorMid.Sat,  HealthColorMid.Value)
			local lowC  = Color3.fromHSV(HealthColorLow.Hue,  HealthColorLow.Sat,  HealthColorLow.Value)
			if ratio >= 0.5 then
				return fullC:Lerp(midC, (1 - ratio) / 0.5)
			else
				return midC:Lerp(lowC, (0.5 - ratio) / 0.5)
			end
		else
			if ratio >= 0.7 then
				return Color3.fromRGB(0, 255, 0)
			elseif ratio >= 0.3 then
				return Color3.fromRGB(255, 255, 0)
			elseif ratio >= 0.1 then
				return Color3.fromRGB(255, 165, 0)
			else
				return Color3.fromRGB(255, 0, 0)
			end
		end
	end

	local function getHealthColorStr(ent)
		local c = getHealthColor(ent)
		return 'rgb('..math.floor(c.R*255)..','..math.floor(c.G*255)..','..math.floor(c.B*255)..')'
	end

	local function healthRich(ent)
		local hp, shield = splitHealth(ent)
		local text = '<font color="'..getHealthColorStr(ent)..'">'..hp..'</font>'
		if shield > 0 then
			text = text..' <font color="rgb(255,255,255)">'..shield..'</font>'
		end
		return text
	end

	local function healthPlain(ent)
		local hp, shield = splitHealth(ent)
		return shield > 0 and (hp..' +'..shield) or tostring(hp)
	end

	local enchantImageMap = nil
	local function buildEnchantMap()
		if enchantImageMap then return enchantImageMap end
		enchantImageMap = {}
		task.spawn(function()
			if vape.ThreadFix then setthreadidentity(8) end
			local ok, meta = pcall(function()
				return require(game:GetService('ReplicatedStorage').TS.enchant['enchant-meta'])
			end)
			if not ok or not meta then return end
			for _, subMeta in pairs({meta.EnchantMeta, meta.ToolEnchantMeta, meta.ArmorEnchantMeta}) do
				if type(subMeta) == 'table' then
					for _, v in pairs(subMeta) do
						if type(v) == 'table' and v.statusEffect and v.image then
							enchantImageMap[v.statusEffect] = v.image
						end
					end
				end
			end
		end)
		return enchantImageMap
	end

	local function getActiveEnchantImage(char)
		if not char then return '' end
		local map = buildEnchantMap()
		for attr, val in pairs(char:GetAttributes()) do
			if attr:sub(1, 13) == 'StatusEffect_' and type(val) == 'number' and val < 0 then
				local effectName = attr:sub(14)
				if not effectName:find('stacks') then
					local img = map[effectName]
					if img and img ~= '' then return img end
				end
			end
		end
		return ''
	end

	local function getBossDisplayName(ent)
		if not ent.NPC or not ent.Character then return nil end
		local char = ent.Character
		if char:GetAttribute("BossType") == "Bhaa" then
			return "Bhaa"
		end
		if char.Name:lower() == "bhaa" then
			return "Bhaa"
		end
		if char:FindFirstChild("BhaaModel") or char:FindFirstChild("BhaaHead") then
			return "Bhaa"
		end
		if char.Name == "Titan" then
			return "Titan"
		end
		return nil
	end

	local function shouldShow(ent)
		if not Targets.Players.Enabled and ent.Player then return false end
		local isBoss = ent.NPC and ent.Character and getBossDisplayName(ent) ~= nil
		if isBoss then
			if not Boss.Enabled then return false end
		else
			if not Targets.NPCs.Enabled and ent.NPC then return false end
			if Teammates.Enabled and (ent.Player and lplr:GetAttribute('Team') and ent.Player:GetAttribute('Team') == lplr:GetAttribute('Team')) and (not ent.Friend) then return false end
		end
		return true
	end

	local Added = {
		Normal = function(ent)
			if Reference[ent] then Removed.Normal(ent) end
			for oldEnt in Reference do
				if oldEnt ~= ent and (not oldEnt.Character or not oldEnt.Character.Parent or (oldEnt.Player and ent.Player and oldEnt.Player == ent.Player)) then
					Removed.Normal(oldEnt)
				end
			end
			if not Targets.Players.Enabled and ent.Player then return end
			local bossDisplayName = ent.NPC and ent.Character and getBossDisplayName(ent) or nil
			local isBoss = bossDisplayName ~= nil
			if isBoss then
				if not Boss.Enabled then return end
			else
				if not Targets.NPCs.Enabled and ent.NPC then return end
				if Teammates.Enabled and (ent.Player and lplr:GetAttribute('Team') and ent.Player:GetAttribute('Team') == lplr:GetAttribute('Team')) and (not ent.Friend) then return end
			end

			local entityName = bossDisplayName or (ent.Player and nil) or ent.Character.Name
			Strings[ent] = ent.Player and (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or entityName

			if Health.Enabled then
				Strings[ent] = Strings[ent]..' '..healthRich(ent)
			end

			if Distance.Enabled then
				Strings[ent] = '[%s] ' .. Strings[ent]
			end
			local textSize = 14 * Scale.Value
			local fontFace = FontOption.Value
			local size = getfontsize(removeTags(Strings[ent]), textSize, fontFace, vector2new(100000, 100000))
			local nametag = Instance.new('TextLabel')
			nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
			nametag.Size = udim2fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = vector2new(0.5, 1)
			nametag.BackgroundColor3 = color3new()
			nametag.BackgroundTransparency = Background.Value
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.Text = Strings[ent]
			nametag.TextColor3 = getTeamColor(ent) or color3fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.RichText = true
			nametag.TextSize = textSize
			nametag.FontFace = fontFace
			nametag.Parent = Folder

			if KitTracker and KitTracker.Enabled and ent.Player then
			  pcall(function()
				local vkRoman = {'I','II','III','IV','V'}
				local ktLabel = Instance.new('TextLabel')
				ktLabel.Name = 'KitTrackerLabel'
				ktLabel.BackgroundTransparency = 1
				ktLabel.TextScaled = false
				ktLabel.TextSize = 13
				ktLabel.FontFace = FontOption.Value
				ktLabel.RichText = true
				ktLabel.AnchorPoint = Vector2.new(1, 0.5)
				ktLabel.Position = UDim2.new(0, -2, 0.5, 0)
				ktLabel.Size = UDim2.new(0, 40, 1, 0)
				ktLabel.ZIndex = 2
				ktLabel.Parent = nametag

				local stroke = Instance.new('UIStroke')
				stroke.Color = Color3.new(0, 0, 0)
				stroke.Thickness = 1.5
				stroke.Parent = ktLabel

				local ktEventsBound = false
				local function waitForWorldBlocks()
					while KitTracker.Enabled and ent.Player.Parent do
						local worldFolder = getWorldFolder()
						local blocks = worldFolder and worldFolder:FindFirstChild('Blocks')
						if blocks then return blocks end
						task.wait(0.1)
					end
					return nil
				end
				local function updateKtLabel()
					if not KitTracker.Enabled then ktLabel.Text = '' return end
					local playerKit = ent.Player:GetAttribute('PlayingAsKits') or 'none'
					if playerKit == 'void_knight' then
						local tier = ent.Player:GetAttribute('VoidKnightTier') or 0
						if tier > 0 then
							ktLabel.Text = '【' .. (vkRoman[tier] or tostring(tier)) .. '】'
							ktLabel.TextColor3 = Color3.fromRGB(180, 80, 255)
						else
							ktLabel.Text = ''
						end
					elseif playerKit == 'block_kicker' then
						local char = ent.Character
						local count = (char and char:GetAttribute('BlockKickerKit_BlockCount')) or ent.Player:GetAttribute('BlockKickerKit_BlockCount') or 0
						ktLabel.Text = count > 0 and '【' .. tostring(count) .. '】' or ''
						ktLabel.TextColor3 = Color3.fromRGB(100, 210, 100)
					elseif playerKit == 'elk_master' then
						local char = ent.Character
						local isMounted = char and char:FindFirstChild('elk') ~= nil
						if isMounted then
							ktLabel.Text = '【🦌】'
							ktLabel.TextColor3 = Color3.fromRGB(160, 220, 80)
						else
							ktLabel.Text = ''
						end
					elseif playerKit == 'summoner' then
						local tier = ent.Player:GetAttribute("Summoner_ClawLevel") or 0
						if not tier or tier == 0 then ktLabel.Text = '' return end
						ktLabel.Text = '【 ' .. (vkRoman[tier] or tostring(tier)) .. ' 】'
						ktLabel.TextColor3 = Color3.fromRGB(191, 0, 255)
					elseif playerKit == 'paladin' then
						ktLabel.Text = '【 🪽 】'
						ktLabel.TextColor3 = Color3.fromRGB(255, 242, 150)
					elseif playerKit == 'davey' then
						local tier = ent.Character and ent.Character:GetAttribute('StatusEffect_powdered_stacks') or 0
						if tier > 0 then
							ktLabel.Text = '【 ' .. tostring(tier) .. ' 】'
						else
							ktLabel.Text = ''
						end
						ktLabel.TextColor3 = Color3.fromRGB(255, 105, 130)
					elseif playerKit == 'airbender' then
						ktLabel.Text = ''
						ktLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
						if not ktEventsBound then
							ktEventsBound = true
							if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
							task.spawn(function()
								table.insert(kitTrackerConnections[ent], bedwars.Client:Get("Airbender_UseTornadoFromServer"):Connect(function(p12)
									if not KitTracker.Enabled then ktLabel.Text = '' return end
									if p12.tornadoData.owner == ent.Player then
										ktLabel.Text = '【 🌪️ 】'
									end
								end))
								table.insert(kitTrackerConnections[ent], bedwars.Client:Get("Airbender_EndTornadoFromServer"):Connect(function(p13)
									if not KitTracker.Enabled then ktLabel.Text = '' return end
									if p13.tornadoData.owner == ent.Player then
										ktLabel.Text = ''
									end
								end))
							end)
						end
					elseif playerKit == 'hatter' then
						ktLabel.Text = ''
						ktLabel.TextColor3 = Color3.fromRGB(45, 15, 80)
						if not ktEventsBound then
							ktEventsBound = true
							if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
							task.spawn(function()
								if vape.ThreadFix then setthreadidentity(8) end
								table.insert(kitTrackerConnections[ent], bedwars.Client:OnEvent("HatterUseTeleport", function(p14)
									if vape.ThreadFix then setthreadidentity(8) end
									if not KitTracker.Enabled then ktLabel.Text = '' return end
									local dtc = p14.arriveTime - workspace:GetServerTimeNow() + 0.05
									if p14.hatterPlayer == ent.Player then
										ktLabel.Text = '【 🎩 】'
										task.wait(dtc)
										if vape.ThreadFix then setthreadidentity(8) end
										ktLabel.Text = ''
									else
										ktLabel.Text = ''
									end
								end))
							end)
						end
					elseif playerKit == 'black_market_trader' then
						ktLabel.Text = ''
						ktLabel.TextColor3 = Color3.fromRGB(30, 10, 60)
						if not ktEventsBound then
							ktEventsBound = true
							if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
							task.spawn(function()
								table.insert(kitTrackerConnections[ent], bedwars.Client:Get("BlackMarketPlaceShop"):Connect(function(p15)
									if not KitTracker.Enabled then ktLabel.Text = '' return end
									if p15.shopOwnerUserId == ent.Player.UserId then
										ktLabel.Text = '【 🏪 】'
									end
								end))
								local blocks = waitForWorldBlocks()
								if not blocks then return end
								table.insert(kitTrackerConnections[ent], blocks.ChildAdded:Connect(function(obj)
									if obj.Name == 'black_market_shop' and obj:GetAttribute('PlacedByUserId') == ent.Player.UserId then
									local billboard = Instance.new('BillboardGui')
									billboard.Parent = obj
									billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
									billboard.Size = UDim2.fromOffset(36, 36)
									billboard.AlwaysOnTop = true
									billboard.ClipsDescendants = false
									local blur = addBlur(billboard)
									blur.Visible = Background.Enabled
									local image = Instance.new('ImageLabel')
									image.Size = UDim2.fromOffset(36, 36)
									image.Position = UDim2.fromScale(0.5, 0.5)
									image.AnchorPoint = Vector2.new(0.5, 0.5)
									image.BackgroundColor3 = Color3.fromHSV(0, 0, 0)
									image.BackgroundTransparency = 0.85
									image.BorderSizePixel = 0
									image.Image = bedwars.getIcon({itemType = 'shadow_coin'}, true)
									image.Parent = billboard
									local uicorner = Instance.new('UICorner')
									uicorner.CornerRadius = UDim.new(0, 4)
									uicorner.Parent = image
									if not billboardCache[ent] then billboardCache[ent] = {} end
									table.insert(billboardCache[ent], billboard)
									end
								end))
							end)
						end
					elseif playerKit == 'wizard' then
						ktLabel.TextColor3 = Color3.fromRGB(100, 70, 220)
						local function getStaffTier(v)
							local inv = store.inventories[v] and store.inventories[v].items or {}
							for _, item in inv do
								local nowstr = string.lower(item.itemType or '')
								if string.find(nowstr, 'wizard_staff') then
									return tonumber(item.itemType:sub(#item.itemType, #item.itemType)) or 1
								end
							end
						end
						local tier = getStaffTier(ent.Player)
						if not tier or tier < 0 then ktLabel.Text = '' return end
						ktLabel.Text = '【' .. (vkRoman[tier] or tostring(tier)) .. '】'
					elseif playerKit == 'aery' then
						ktLabel.TextColor3 = Color3.fromRGB(130, 210, 255)
						local stacks = ent.Player:GetAttribute('AeryStacks') or 0
						ktLabel.Text = '【' .. tostring(stacks) .. '】'
					elseif playerKit == 'mimic' then
						ktLabel.TextColor3 = Color3.fromRGB(180, 210, 60)
						ktLabel.Text = ''
						if not ktEventsBound then
							ktEventsBound = true
							if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
							task.spawn(function()
								if vape.ThreadFix then setthreadidentity(8) end
								table.insert(kitTrackerConnections[ent], bedwars.Client:OnEvent("ValidatedMimicBlock", function(p14)
									if not KitTracker.Enabled then ktLabel.Text = '' return end
									if vape.ThreadFix then setthreadidentity(8) end
									if p14.player == ent.Player then
										ktLabel.Text = '【 👔 】'
									else
										ktLabel.Text = ''
									end
								end))
								local val = workspace:FindFirstChild('DisguisedPlayerBlock_' .. ent.Player.UserId) ~= nil
								if val then ktLabel.Text = '【 👔 】' end
							end)
						end
					elseif playerKit == 'disruptor' then
						ktLabel.TextColor3 = Color3.fromRGB(40, 180, 140)
						if not ktEventsBound then
							ktEventsBound = true
							if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
							task.spawn(function()
								local blocks = waitForWorldBlocks()
								if not blocks then return end
								table.insert(kitTrackerConnections[ent], blocks.ChildAdded:Connect(function(obj)
									if obj.Name == 'satellite_dish' and obj:GetAttribute('PlacedByUserId') == ent.Player.UserId then
									local billboard = Instance.new('BillboardGui')
									billboard.Parent = obj
									billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
									billboard.Size = UDim2.fromOffset(36, 36)
									billboard.AlwaysOnTop = true
									billboard.ClipsDescendants = false
									local blur = addBlur(billboard)
									blur.Visible = Background.Enabled
									local image = Instance.new('ImageLabel')
									image.Size = UDim2.fromOffset(36, 36)
									image.Position = UDim2.fromScale(0.5, 0.5)
									image.AnchorPoint = Vector2.new(0.5, 0.5)
									image.BackgroundColor3 = Color3.fromHSV(0, 0, 0)
									image.BackgroundTransparency = 0.85
									image.BorderSizePixel = 0
									image.Image = bedwars.getIcon({itemType = 'satellite_dish'}, true)
									image.Parent = billboard
									local uicorner = Instance.new('UICorner')
									uicorner.CornerRadius = UDim.new(0, 4)
									uicorner.Parent = image
									if not billboardCache[ent] then billboardCache[ent] = {} end
									table.insert(billboardCache[ent], billboard)
									end
								end))
							end)
						end
						ktLabel.Text = '【 ' .. (ent.Player:GetAttribute('DisruptorTarget') and ent.Player:GetAttribute('DisruptorTarget') .. ' Team' or 'Unknown Team') .. ' 】'
					elseif playerKit == 'winter_lady' then
						ktLabel.TextColor3 = Color3.fromRGB(200, 225, 255)
						local function getWandTier(v)
							local inv = store.inventories[v] and store.inventories[v].items or {}
							for _, item in inv do
								local nowstr = string.lower(item.itemType or '')
								if string.find(nowstr, 'frost_staff') then
									return tonumber(item.itemType:sub(#item.itemType, #item.itemType)) or 1
								end
							end
						end
						local tier = getWandTier(ent.Player)
						if not tier or tier < 0 then ktLabel.Text = '' return end
						ktLabel.Text = '【' .. (vkRoman[tier] or tostring(tier)) .. '】'
					elseif playerKit == 'warrior' then
						ktLabel.TextColor3 = Color3.fromRGB(220, 60, 60)
						local grit = ent.Player:GetAttribute('Grit') or 0
						ktLabel.Text = '【 ' .. tostring(grit) .. '/100】'
					else
						ktLabel.Text = ''
					end
				end

				updateKtLabel()

				if ent.Character then
					if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
					table.insert(kitTrackerConnections[ent], ent.Character.AttributeChanged:Connect(function(attr)
						if attr == 'BlockKickerKit_BlockCount' or attr == 'StatusEffect_powdered_stacks' then
							updateKtLabel()
						end
					end))
					table.insert(kitTrackerConnections[ent], ent.Player.AttributeChanged:Connect(function(attr)
						if attr == 'DisruptorTarget' or attr == 'DisruptorActivation'
						or attr == 'AeryStacks' or attr == 'VoidKnightTier'
						or attr == 'PaladinStartTime' or attr == 'Summoner_ClawLevel'
						or attr == 'Grit' then
							updateKtLabel()
						end
					end))
					table.insert(kitTrackerConnections[ent], ent.Character.ChildAdded:Connect(function(child)
						if child.Name == 'elk' or string.find(child.Name, "wizard_staff") or string.find(child.Name, "frost_staff") then
							updateKtLabel()
						end
					end))
					table.insert(kitTrackerConnections[ent], ent.Character.ChildRemoved:Connect(function(child)
						if child and (child.Name == 'elk' or string.find(child.Name, "wizard_staff") or string.find(child.Name, "frost_staff")) then
							updateKtLabel()
						end
					end))
					table.insert(kitTrackerConnections[ent], workspace.ChildAdded:Connect(function(child)
						if child and child.Name:sub(1, 20) == 'DisguisedPlayerBlock' then
							updateKtLabel()
						end
					end))
					table.insert(kitTrackerConnections[ent], workspace.ChildRemoved:Connect(function(child)
						if child and child.Name:sub(1, 20) == 'DisguisedPlayerBlock' then
							updateKtLabel()
						end
					end))
				end
				if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
				table.insert(kitTrackerConnections[ent], ent.Player:GetAttributeChangedSignal('PlayingAsKits'):Connect(updateKtLabel))
			  end)
			end

			if Potions.Enabled then
				local baseX = Loot.Enabled and 45 or -39
				for i, def in potionDefs do
					local iconSc = Scale.Value
					local Icon = Instance.new('ImageLabel')
					Icon.Name = def.name
					Icon.Size = udim2fromOffset(26 * iconSc, 26 * iconSc)
					Icon.Position = udim2fromOffset((baseX + ((i - 1) * 28)) * iconSc, (Equipment.Enabled and -58 or -30) * iconSc)
					Icon.BackgroundTransparency = 1
					Icon.Image = ''
					Icon.Parent = nametag
				end
			end

			if Loot.Enabled then
				local lootDefs = { LootIron = 'iron', LootDiamond = 'diamond', LootEmerald = 'emerald' }
				for i, v in { 'LootIron', 'LootDiamond', 'LootEmerald' } do
					local iconSc = Scale.Value
					local Icon = Instance.new('ImageLabel')
					Icon.Name = v
					Icon.Size = udim2fromOffset(26 * iconSc, 26 * iconSc)
					Icon.Position = udim2fromOffset((-39 + ((i - 1) * 28)) * iconSc, (Equipment.Enabled and -58 or -30) * iconSc)
					Icon.BackgroundTransparency = 1
					Icon.Image = ''
					Icon.Parent = nametag
					local amt = Instance.new('TextLabel')
					amt.Name = 'Amt'
					amt.AnchorPoint = Vector2.new(0, 1)
					amt.Position = UDim2.new(0, 0, 1, 0)
					amt.Size = UDim2.new(0, 26 * iconSc, 0, 10 * iconSc)
					amt.BackgroundTransparency = 1
					amt.Text = ''
					amt.TextColor3 = Color3.fromRGB(255, 255, 255)
					amt.TextStrokeTransparency = 0.4
					amt.TextSize = 9 * iconSc
					amt.Font = Enum.Font.GothamBold
					amt.TextXAlignment = Enum.TextXAlignment.Center
					amt.TextYAlignment = Enum.TextYAlignment.Bottom
					amt.Parent = Icon
				end

				local function applyLootIcons()
					if not (NameTags.Enabled and Loot.Enabled and nametag and nametag.Parent and ent.Player) then return end
					local inventory = store.inventories[ent.Player]
					if not inventory and bedwars.getInventory then
						inventory = bedwars.getInventory(ent.Player)
						if inventory then store.inventories[ent.Player] = inventory end
					end
					if not inventory then return end
					local counts = { iron = 0, diamond = 0, emerald = 0 }
					for _, it in inventory.items or {} do
						if counts[it.itemType] ~= nil then
							counts[it.itemType] = counts[it.itemType] + (it.amount or 0)
						end
					end
					for slot, nm in lootDefs do
						local ic = nametag:FindFirstChild(slot)
						if ic then
							local c = counts[nm]
							if c > 0 then
								ic.Image = bedwars.getIcon({ itemType = nm }, true)
								if ic.Amt then ic.Amt.Text = tostring(c) end
							else
								ic.Image = ''
								if ic.Amt then ic.Amt.Text = '' end
							end
						end
					end
				end

				applyLootIcons()
				if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
				table.insert(kitTrackerConnections[ent], vapeEvents.InventoryChanged.Event:Connect(function()
					if nametag and nametag.Parent then applyLootIcons() end
				end))
			end

			if Equipment.Enabled then
				for i, v in { 'Hand', 'Helmet', 'Chestplate', 'Boots' } do
					local Icon = Instance.new('ImageLabel')
					Icon.Name = v
					local iconSc = Scale.Value
					Icon.Size = udim2fromOffset(30 * iconSc, 30 * iconSc)
					Icon.Position = udim2fromOffset((-60 + (i * 30)) * iconSc, -30 * iconSc)
					Icon.BackgroundTransparency = 1
					Icon.Image = ''
					Icon.Parent = nametag
					if v == 'Hand' then
						local amt = Instance.new('TextLabel')
						amt.Name = 'Amt'
						amt.AnchorPoint = Vector2.new(0, 1)
						amt.Position = UDim2.new(0, 0, 1, 0)
						amt.Size = UDim2.new(0, 14 * iconSc, 0, 10 * iconSc)
						amt.BackgroundTransparency = 1
						amt.Text = ''
						amt.TextColor3 = Color3.fromRGB(255, 255, 255)
						amt.TextStrokeTransparency = 0.4
						amt.TextSize = 10 * iconSc
						amt.Font = Enum.Font.GothamBold
						amt.TextXAlignment = Enum.TextXAlignment.Left
						amt.TextYAlignment = Enum.TextYAlignment.Bottom
						amt.Parent = Icon
					end
				end

				local equipRetry = nil
				local function applyEquipmentIcons(attempt)
					if not ent.Player then return end
					if not (NameTags.Enabled and Equipment.Enabled and nametag and nametag.Parent) then return end
					local inventory = store.inventories[ent.Player]
					if not inventory and bedwars.getInventory then
						inventory = bedwars.getInventory(ent.Player)
						if inventory then store.inventories[ent.Player] = inventory end
					end
					if not inventory then
						if equipRetry then task.cancel(equipRetry) end
						local wait = math.min(0.1 * (attempt or 1), 1)
						equipRetry = task.delay(wait, function()
							equipRetry = nil
							applyEquipmentIcons((attempt or 1) + 1)
						end)
						return
					end
					local handItem = inventory.hand
					local kit = ent.Player:GetAttribute('PlayingAsKits')
					local handImage = bedwars.getIcon(handItem or { itemType = '' }, true)
					if nametag.Hand then
						nametag.Hand.Image = handImage
						if nametag.Hand.Amt then
							local a = handItem and handItem.amount
							nametag.Hand.Amt.Text = (a and a > 1) and tostring(a) or ''
						end
					end
					if nametag.Helmet then nametag.Helmet.Image = bedwars.getIcon(inventory.armor and inventory.armor[4] or { itemType = '' }, true) end
					local chestImage = bedwars.getIcon(inventory.armor and inventory.armor[5] or { itemType = '' }, true)
					if kit == 'tinker' then
						local level = ent.Player:GetAttribute('TinkerMachineLevel')
						if level and level >= 1 and level <= 5 then
							local mechImg = getChainsawImage(level)
							if mechImg and mechImg ~= '' then
								chestImage = mechImg
							end
						end
					end
					if nametag.Chestplate then nametag.Chestplate.Image = chestImage end
					if nametag.Boots then nametag.Boots.Image = bedwars.getIcon(inventory.armor and inventory.armor[6] or { itemType = '' }, true) end
				end
				applyEquipmentIcons()
				if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
				table.insert(kitTrackerConnections[ent], vapeEvents.InventoryChanged.Event:Connect(function()
					if nametag and nametag.Parent then
						applyEquipmentIcons()
					end
				end))

				if ent.Player then
					local attrConn = ent.Player:GetAttributeChangedSignal('TinkerMachineLevel'):Connect(function()
						if Equipment.Enabled and nametag and nametag.Parent then
							applyEquipmentIcons()
						end
					end)
					if not kitTrackerConnections[ent] then
						kitTrackerConnections[ent] = {}
					end
					table.insert(kitTrackerConnections[ent], attrConn)
				end
			end

			if ShowKits.Enabled and ent.Player then
				local kitIcon = Instance.new('ImageLabel')
				kitIcon.Name = 'KitIcon'
				kitIcon.Size = udim2fromOffset(30, 30)
				kitIcon.AnchorPoint = vector2new(0.5, 0)
				kitIcon.BackgroundTransparency = 1
				kitIcon.Image = ''

				if Equipment.Enabled then
					kitIcon.Position = udim2fromOffset(110, -30)
				else
					kitIcon.Position = UDim2.new(0.5, 0, 0, -35)
				end

				kitIcon.Parent = nametag

				local kit = ent.Player:GetAttribute('PlayingAsKits')
				if kit then
					local kitImage = kitImageIds[kit:lower()]
					kitIcon.Image = kitImage or kitImageIds["none"]
					kitCache[ent] = kitImage or kitImageIds["none"]
				else
					kitIcon.Image = kitImageIds["none"]
					kitCache[ent] = kitImageIds["none"]
				end
			end

			if DeviceIcon and DeviceIcon.Enabled and ent.Player then
				local function getPlayerDevice(plr)
					local val = plr:GetAttribute('UserInputType') or 'Unknown'
					if not val then return 'Unknown' end
					val = val:upper()
					if val == 'MOBILE' then return 'Mobile'
					elseif val == 'GAMEPAD' or val == 'CONTROLLER' then return 'Controller'
					else return 'PC' end
				end
				local deviceType = getPlayerDevice(ent.Player)
				if deviceType then
					local deviceEmoji = {Mobile = '📱', PC = '🖥', Controller = '🎮', Unknown = '❔'}
					local deviceLabel = Instance.new('TextLabel')
					deviceLabel.Name = 'DeviceIcon'
					deviceLabel.Size = udim2fromOffset(22, 22)
					deviceLabel.AnchorPoint = vector2new(0, 0)
					deviceLabel.Position = UDim2.new(1, 10, 0, -1)
					deviceLabel.BackgroundTransparency = 1
					deviceLabel.BorderSizePixel = 0
					deviceLabel.Text = deviceEmoji[deviceType] or ''
					deviceLabel.RichText = false
					deviceLabel.TextScaled = false
					deviceLabel.TextSize = 16
					deviceLabel.FontFace = Font.fromEnum(Enum.Font.Arial)
					deviceLabel.TextColor3 = Color3.new(1, 1, 1)
					deviceLabel.Parent = nametag
				end
			end

			if Rank.Enabled and ent.Player then
				local rankIcon = Instance.new('ImageLabel')
				rankIcon.Name = 'RankIcon'
				rankIcon.Size = udim2fromOffset(30, 30)
				rankIcon.Position = UDim2.new(1, (DeviceIcon and DeviceIcon.Enabled and 42 or 10), 0, -4)
				rankIcon.BackgroundTransparency = 1
				rankIcon.Image = ''
				rankIcon.Parent = nametag

				task.spawn(function()
					task.wait(math.random() * 0.5)
					if not NameTags.Enabled then return end
					if vape.ThreadFix then setthreadidentity(8) end
					local plr = playersService:GetPlayerFromCharacter(ent.Character)
					if not plr then return end
					if not rankIcon or not rankIcon.Parent then return end

					local ok, success, data = pcall(function()
						return bedwars.Client:Get(remotes.Ranks):CallServerAsync({ plr.UserId }):await()
					end)

					if vape.ThreadFix then setthreadidentity(8) end

					if ok and success and type(data) == "table" then
						local division = data[1] and data[1].rankDivision
						if division and bedwars.RankMeta and bedwars.RankMeta[division] then
							if rankIcon and rankIcon.Parent then
								rankIcon.Image = bedwars.RankMeta[division].image
							end
						end
					end
				end)
			end

			if GloopIndicator and GloopIndicator.Enabled and ent.Character then
				local gloopIcon = Instance.new('ImageLabel')
				gloopIcon.Name = 'GloopIcon'
				gloopIcon.Size = udim2fromOffset(24, 24)
				gloopIcon.BackgroundTransparency = 1
				gloopIcon.Image = bedwars.getIcon({itemType = 'glue_projectile'}, true)
				gloopIcon.Visible = false
				if Rank.Enabled and DeviceIcon and DeviceIcon.Enabled then
					gloopIcon.Position = UDim2.new(1, 74, 0, -2)
				elseif Rank.Enabled or (DeviceIcon and DeviceIcon.Enabled) then
					gloopIcon.Position = UDim2.new(1, 42, 0, -2)
				else
					gloopIcon.Position = UDim2.new(1, 10, 0, -2)
				end
				gloopIcon.Parent = nametag
				local gloopTimer = nil
				if gloopConnections[ent] then gloopConnections[ent]:Disconnect() end
				gloopConnections[ent] = ent.Character.AttributeChanged:Connect(function(attr)
					if attr ~= 'GlueSlow' then return end
					local val = ent.Character:GetAttribute('GlueSlow')
					if val ~= nil and val ~= 0 then
						gloopIcon.Visible = true
						if gloopTimer then task.cancel(gloopTimer) end
						gloopTimer = task.delay(10, function()
							gloopIcon.Visible = false
							gloopTimer = nil
						end)
					end
				end)
			end

			if Enchant.Enabled and ent.Player and ent.Character then
				local Icon = Instance.new('ImageLabel')
				Icon.Name = 'EnchantIcon'
				Icon.Size = udim2fromOffset(30, 30)
				Icon.Position = udim2fromOffset(-30, -4)
				Icon.BackgroundTransparency = 1
				Icon.Image = getActiveEnchantImage(ent.Character)
				Icon.Parent = nametag
				enchantCache[ent] = Icon.Image
				if enchantConnections[ent] then enchantConnections[ent]:Disconnect() end
				enchantConnections[ent] = ent.Character.AttributeChanged:Connect(function(attr)
					if attr:sub(1, 13) ~= 'StatusEffect_' then return end
					local val = ent.Character:GetAttribute(attr)
					if type(val) ~= 'number' then return end
					local newImage = getActiveEnchantImage(ent.Character)
					if enchantCache[ent] ~= newImage then
						Icon.Image = newImage
						enchantCache[ent] = newImage
					end
				end)
			end

			Reference[ent] = nametag
			charCache[ent] = ent.Character
			lastUpdate[ent] = 0
		end,

		Drawing = function(ent)
			if not shouldShow(ent) then return end
			if Reference[ent] then return end

			local bg = Drawing.new('Square')
			bg.Filled = true
			bg.Thickness = 0
			bg.Color = color3new(0, 0, 0)
			bg.Transparency = 1 - Background.Value
			bg.ZIndex = 1
			bg.Visible = false

			local text = Drawing.new('Text')
			text.Center = false
			text.Outline = true
			text.OutlineColor = color3new(0, 0, 0)
			text.Size = math_round(14 * Scale.Value)
			text.Font = 2
			text.Color = getTeamColor(ent) or color3fromHSV(Color.Hue, Color.Sat, Color.Value)
			text.ZIndex = 2
			text.Visible = false

			local baseName = ent.Player and (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or (getBossDisplayName(ent) or (ent.Character and ent.Character.Name)) or ''
			local built = baseName
			if Health.Enabled then built = built .. ' ' .. healthPlain(ent) end
			if ShowKits.Enabled and ent.Player then
				local kit = ent.Player:GetAttribute('PlayingAsKits')
				if kit then
					built = built .. ' (' .. (kit:gsub('_', ' '):gsub('^%l', string.upper)) .. ')'
				end
			end
			if Distance.Enabled then
				Strings[ent] = '[%s] ' .. built
			else
				Strings[ent] = built
				text.Text = built
				bg.Size = vector2new(text.TextBounds.X + 8, text.TextBounds.Y + 7)
			end

			Reference[ent] = {Text = text, BG = bg}
			charCache[ent] = ent.Character
		end
	}

	Removed = {
		Normal = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				lastUpdate[ent] = nil
				kitCache = {}
				equipmentCache = {}
				lootCache = {}
				enchantCache = {}
				healthCache[ent] = nil
				charCache[ent] = nil
				if enchantConnections[ent] then
					enchantConnections[ent]:Disconnect()
					enchantConnections[ent] = nil
				end
				if gloopConnections[ent] then
					gloopConnections[ent]:Disconnect()
					gloopConnections[ent] = nil
				end
				if kitTrackerConnections[ent] then
					for _, c in ipairs(kitTrackerConnections[ent]) do
						pcall(function() c:Disconnect() end)
					end
					kitTrackerConnections[ent] = nil
				end
				if billboardCache[ent] then
					for _, b in ipairs(billboardCache[ent]) do
						pcall(function() b:Destroy() end)
					end
					billboardCache[ent] = nil
				end
				v:Destroy()
			end
		end,
		Drawing = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				lastUpdate[ent] = nil
				kitCache[ent] = nil
				healthCache[ent] = nil
				if enchantConnections[ent] then
					enchantConnections[ent]:Disconnect()
					enchantConnections[ent] = nil
				end
				if gloopConnections[ent] then
					gloopConnections[ent]:Disconnect()
					gloopConnections[ent] = nil
				end
				if billboardCache[ent] then
					for _, b in ipairs(billboardCache[ent]) do
						pcall(function() b:Destroy() end)
					end
					billboardCache[ent] = nil
				end
				for _, obj in v do
					pcall(function()
						obj.Visible = false
						obj:Remove()
					end)
				end
			end
		end
	}

	local Updated = {
		Normal = function(ent)
			local nametag = Reference[ent]
			if not nametag then return end

			local now = tick()
			if lastUpdate[ent] and (now - lastUpdate[ent]) < 0.2 then return end
			lastUpdate[ent] = now

			Sizes[ent] = nil
			local bossDisplayName = ent.NPC and ent.Character and getBossDisplayName(ent) or nil
			local entityName = bossDisplayName or (ent.Player and nil) or ent.Character.Name
			Strings[ent] = ent.Player and (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or entityName

			if Health.Enabled then
				Strings[ent] = Strings[ent]..' '..healthRich(ent)
			end

			if Distance.Enabled then
				Strings[ent] = '[%s] ' .. Strings[ent]
			end

			if Equipment.Enabled and ent.Player then
				if not store.inventories[ent.Player] and bedwars.getInventory then
					local fetched = bedwars.getInventory(ent.Player)
					if fetched then store.inventories[ent.Player] = fetched end
				end
				local inventory = store.inventories[ent.Player] or {hand = nil, armor = {}}
				local handItem = inventory.hand
				local kit = ent.Player:GetAttribute('PlayingAsKits')
				local handImage = bedwars.getIcon(handItem or { itemType = '' }, true)
				local chestImage = bedwars.getIcon(inventory.armor and inventory.armor[5] or { itemType = '' }, true)
				if kit == 'tinker' then
					local level = ent.Player:GetAttribute('TinkerMachineLevel')
					if level and level >= 1 and level <= 5 then
						local mechImg = getChainsawImage(level)
						if mechImg and mechImg ~= '' then
							chestImage = mechImg
						end
					end
				end
				local currentEquip = {
					tostring(handItem and handItem.itemType or ''),
					tostring((inventory.armor and inventory.armor[4] and inventory.armor[4].itemType) or ''),
					tostring((inventory.armor and inventory.armor[5] and inventory.armor[5].itemType) or ''),
					tostring((inventory.armor and inventory.armor[6] and inventory.armor[6].itemType) or '')
				}
				local equipKey = table.concat(currentEquip, "|")
				if equipmentCache[ent] ~= equipKey then
					equipmentCache[ent] = equipKey
					if nametag.Hand then
						nametag.Hand.Image = handImage
						if nametag.Hand.Amt then
							local a = handItem and handItem.amount
							nametag.Hand.Amt.Text = (a and a > 1) and tostring(a) or ''
						end
					end
					if nametag.Helmet then
						nametag.Helmet.Image = bedwars.getIcon(inventory.armor and inventory.armor[4] or { itemType = '' }, true)
					end
					if nametag.Chestplate then
						nametag.Chestplate.Image = chestImage
					end
					if nametag.Boots then
						nametag.Boots.Image = bedwars.getIcon(inventory.armor and inventory.armor[6] or { itemType = '' }, true)
					end
				end
			end

			local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, vector2new(100000, 100000))
			nametag.Size = udim2fromOffset(size.X + 8, size.Y + 7)
			nametag.Text = Strings[ent]
			nametag.TextColor3 = getTeamColor(ent) or color3fromHSV(Color.Hue, Color.Sat, Color.Value)
		end,

		Drawing = function(ent)
			local nametag = Reference[ent]
			if nametag then
				if vape.ThreadFix then setthreadidentity(8) end
				Sizes[ent] = nil
				local bossDisplayName = ent.NPC and ent.Character and getBossDisplayName(ent) or nil
				local entityName = bossDisplayName or (ent.Player and nil) or ent.Character.Name
				Strings[ent] = ent.Player and (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or entityName

				if Health.Enabled then
					Strings[ent] = Strings[ent]..' '..healthPlain(ent)
					nametag.Text.Color = getHealthColor(ent)
				end

				if Distance.Enabled then
					Strings[ent] = '[%s] ' .. Strings[ent]
					nametag.Text.Text = entitylib.isAlive and string_format(Strings[ent], math_floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
				else
					nametag.Text.Text = Strings[ent]
				end

				if ShowKits.Enabled and ent.Player then
					local kit = ent.Player:GetAttribute('PlayingAsKits')
					if kit then
						local kitName = kit:gsub("_", " "):gsub("^%l", string.upper)
						nametag.Text.Text = nametag.Text.Text .. ' (' .. kitName .. ')'
					end
				end

				nametag.BG.Size = vector2new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
				if not Health.Enabled then
					nametag.Text.Color = getTeamColor(ent) or color3fromHSV(Color.Hue, Color.Sat, Color.Value)
				end
			end
		end
	}

	local ColorFunc = {
		Normal = function(hue, sat, val)
			local color = color3fromHSV(hue, sat, val)
			for i, v in Reference do
				v.TextColor3 = getTeamColor(i) or color
			end
		end,
		Drawing = function(hue, sat, val)
			local color = color3fromHSV(hue, sat, val)
			for i, v in Reference do
				if not Health.Enabled then
					v.Text.Color = getTeamColor(i) or color
				end
			end
		end
	}

	local frameCounter = 0
	Loop = {
		Normal = function()
			frameCounter = frameCounter + 1
			local skipVisCheck = frameCounter % 2 ~= 0
			local updateDistText = frameCounter % 3 == 0
			local updateEquipment = frameCounter % 30 == 0
			local forceEquip = frameCounter % 150 == 0
			local updateKit = frameCounter % 30 == 0
			local updateDistanceText = frameCounter % 6 == 0
			local myPos = entitylib.isAlive and entitylib.character.RootPart and entitylib.character.RootPart.Position

			for ent, nametag in Reference do
				if not ent.RootPart or not ent.Character or not ent.Character.Parent or (ent.Health ~= nil and ent.Health <= 0) then
					nametag.Visible = false
					continue
				end
				if DistanceCheck.Enabled then
					local distance = myPos and (myPos - ent.RootPart.Position).Magnitude or math_huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						nametag.Visible = false
						continue
					end
				end

				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + vector3new(0, ent.HipHeight + 1, 0))
				if not skipVisCheck then
					nametag.Visible = headVis
				end
				if not nametag.Visible or not headVis then continue end
				nametag.Position = udim2fromOffset(headPos.X, headPos.Y)

				if Health.Enabled and (frameCounter % 2 == 0) then
					local hp = healthRich(ent)
					if healthCache[ent] ~= hp then
						healthCache[ent] = hp
						local baseName = ent.Player and (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or (getBossDisplayName(ent) or (ent.Character and ent.Character.Name)) or ''
						Strings[ent] = baseName..' '..hp
						if Distance.Enabled then
							Strings[ent] = '[%s] ' .. Strings[ent]
						else
							nametag.Text = Strings[ent]
							local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, vector2new(100000, 100000))
							nametag.Size = udim2fromOffset(size.X + 8, size.Y + 7)
						end
						Sizes[ent] = nil
					end
				end

				if Distance.Enabled and updateDistText then
					local mag = myPos and math_floor((myPos - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text = string_format(Strings[ent], mag)
						if updateDistanceText then
							local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, vector2new(100000, 100000))
							nametag.Size = udim2fromOffset(size.X + 8, size.Y + 7)
						end
						Sizes[ent] = mag
					end
				end

				if Equipment.Enabled and (updateEquipment or forceEquip) then
					if ent.Player and not store.inventories[ent.Player] and bedwars.getInventory then
						local fetched = bedwars.getInventory(ent.Player)
						if fetched then store.inventories[ent.Player] = fetched end
					end
					if ent.Player and store.inventories[ent.Player] then
						local inventory = store.inventories[ent.Player]
						local handItem = inventory.hand
						local currentEquip = {
							(handItem and handItem.itemType) or '',
							(inventory.armor and inventory.armor[4] and inventory.armor[4].itemType) or '',
							(inventory.armor and inventory.armor[5] and inventory.armor[5].itemType) or '',
							(inventory.armor and inventory.armor[6] and inventory.armor[6].itemType) or ''
						}
						local equipKey = table.concat(currentEquip, "|")
						local iconsBlank = nametag.Hand and (nametag.Hand.Image == '' or nametag.Hand.Image == nil)
						if equipmentCache[ent] ~= equipKey or forceEquip or (iconsBlank and equipKey ~= "|||") then
							local kit = ent.Player:GetAttribute('PlayingAsKits')
							local handImage = bedwars.getIcon(handItem or { itemType = '' }, true)
							local chestImage = bedwars.getIcon(inventory.armor and inventory.armor[5] or { itemType = '' }, true)
							if kit == 'tinker' then
								local level = ent.Player:GetAttribute('TinkerMachineLevel')
								if level and level >= 1 and level <= 5 then
									local mechImg = getChainsawImage(level)
									if mechImg and mechImg ~= '' then
										chestImage = mechImg
									end
								end
							end
							equipmentCache[ent] = equipKey
							if nametag.Hand then
								nametag.Hand.Image = handImage
								if nametag.Hand.Amt then
									local a = handItem and handItem.amount
									nametag.Hand.Amt.Text = (a and a > 1) and tostring(a) or ''
								end
							end
							if nametag.Helmet then
								nametag.Helmet.Image = bedwars.getIcon(inventory.armor and inventory.armor[4] or { itemType = '' }, true)
							end
							if nametag.Chestplate then
								nametag.Chestplate.Image = chestImage
							end
							if nametag.Boots then
								nametag.Boots.Image = bedwars.getIcon(inventory.armor and inventory.armor[6] or { itemType = '' }, true)
							end
						end
					elseif ent.Player then
						equipmentCache[ent] = nil
					end
				end

				if Loot.Enabled and (updateEquipment or forceEquip) and ent.Player and nametag.LootIron then
					local inv = store.inventories[ent.Player]
					if not inv and bedwars.getInventory then
						inv = bedwars.getInventory(ent.Player)
						if inv then store.inventories[ent.Player] = inv end
					end
					if inv and inv.items then
						local counts = { iron = 0, diamond = 0, emerald = 0 }
						for _, it in inv.items do
							local c = counts[it.itemType]
							if c then
								counts[it.itemType] = c + (it.amount or 0)
							end
						end
						local lootKey = counts.iron .. '|' .. counts.diamond .. '|' .. counts.emerald
						if lootCache[ent] ~= lootKey or forceEquip then
							lootCache[ent] = lootKey
							for slot, nm in { LootIron = 'iron', LootDiamond = 'diamond', LootEmerald = 'emerald' } do
								local ic = nametag:FindFirstChild(slot)
								if ic then
									local c = counts[nm]
									if c > 0 then
										ic.Image = bedwars.getIcon({ itemType = nm }, true)
										if ic.Amt then ic.Amt.Text = tostring(c) end
									else
										ic.Image = ''
										if ic.Amt then ic.Amt.Text = '' end
									end
								end
							end
						end
					end
				end

				if Potions.Enabled and (updateEquipment or forceEquip) then
					local char = ent.Character
					for _, def in potionDefs do
						local ic = nametag:FindFirstChild(def.name)
						if ic then
							local want = potionActive(char, def) and bedwars.getIcon({itemType = def.item}, true) or ''
							if ic.Image ~= want then
								ic.Image = want
							end
						end
					end
				end

				if ShowKits.Enabled and updateKit then
					local kitIcon = nametag:FindFirstChild('KitIcon')
					if kitIcon and ent.Player then
						local kit = ent.Player:GetAttribute('PlayingAsKits')
						local meta = bedwars.BedwarsKitMeta and kit and bedwars.BedwarsKitMeta[kit]
						local newKitImage = (meta and meta.renderImage) or kitImageIds[kit] or kitImageIds['none']
						if kitCache[ent] ~= newKitImage then
							kitIcon.Image = newKitImage
							kitCache[ent] = newKitImage
						end
					end
				end
			end
		end,

		Drawing = function()
			frameCounter = frameCounter + 1
			local skipFrame = frameCounter % 2 ~= 0

			for ent, nametag in Reference do
				if not ent.RootPart or (ent.Health ~= nil and ent.Health <= 0) then
					if not nametag:GetAttribute('DeadHidden') then
						nametag:SetAttribute('DeadHidden', true)
						for _, child in nametag:GetChildren() do
							if child:IsA('GuiObject') then child.Visible = false end
						end
					end
					continue
				end
				if nametag:GetAttribute('DeadHidden') then
					nametag:SetAttribute('DeadHidden', nil)
					for _, child in nametag:GetChildren() do
						if child:IsA('GuiObject') then child.Visible = true end
					end
				end
				if DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math_huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						nametag.Text.Visible = false
						nametag.BG.Visible = false
						continue
					end
				end

				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + vector3new(0, ent.HipHeight + 1, 0))
				nametag.Text.Visible = headVis
				nametag.BG.Visible = headVis
				if not headVis then continue end
				if skipFrame then continue end

				if Health.Enabled then
					nametag.Text.Color = getHealthColor(ent)
					local hp = healthPlain(ent)
					if healthCache[ent] ~= hp then
						healthCache[ent] = hp
						local baseName = ent.Player and (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or (getBossDisplayName(ent) or (ent.Character and ent.Character.Name)) or ''
						local built = baseName..' '..hp
						if ShowKits.Enabled and ent.Player then
							local kit = ent.Player:GetAttribute('PlayingAsKits')
							if kit then
								built = built..' ('..(kit:gsub('_', ' '):gsub('^%l', string.upper))..')'
							end
						end
						if Distance.Enabled then
							Strings[ent] = '[%s] '..built
						else
							Strings[ent] = built
							nametag.Text.Text = built
							nametag.BG.Size = vector2new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
						end
						Sizes[ent] = nil
					end
				end

				if Distance.Enabled then
					local mag = entitylib.isAlive and math_floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text.Text = string_format(Strings[ent], mag)
						nametag.BG.Size = vector2new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
						Sizes[ent] = mag
					end
				end

				nametag.BG.Position = vector2new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
				nametag.Text.Position = nametag.BG.Position + vector2new(4, 3)
			end
		end
	}

	NameTags = vape.Categories.Render:CreateModule({
		Name = 'NameTags',
		Function = function(callback)
			if callback then
				methodused = StreamProof.Enabled and 'Drawing' or 'Normal'
				frameCounter = 0

				if Removed[methodused] then
					NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
				end

				if Added[methodused] then
					for _, v in entitylib.List do
						if Reference[v] then Removed[methodused](v) end
						pcall(Added[methodused], v)
					end
					task.spawn(function()
						task.wait(1)
						if not NameTags.Enabled then return end
						for _, v in entitylib.List do
							if Reference[v] then Removed[methodused](v) end
							pcall(Added[methodused], v)
						end
					end)
					NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
						task.spawn(function()
							task.wait(0.5)
							if not NameTags.Enabled then return end
							if not ent.Character or not ent.Character.Parent then
								if Reference[ent] then Removed[methodused](ent) end
								return
							end
							if Reference[ent] then Removed[methodused](ent) end
							pcall(Added[methodused], ent)
						end)
					end))
					NameTags:Clean(playersService.PlayerAdded:Connect(function(p)
						NameTags:Clean(p.CharacterAdded:Connect(function()
							task.delay(0.3, function()
								if not NameTags.Enabled then return end
								for _, v in entitylib.List do
									if v.Player == p and not Reference[v] then
										pcall(Added[methodused], v)
									end
								end
							end)
						end))
					end))
				end

				if Updated[methodused] then
					NameTags:Clean(entitylib.Events.EntityUpdated:Connect(function(ent)
						local show = shouldShow(ent)
						if show and not Reference[ent] then
							pcall(Added[methodused], ent)
							return
						elseif not show and Reference[ent] then
							Removed[methodused](ent)
							return
						end
						if Reference[ent] and charCache[ent] ~= ent.Character then
							Removed[methodused](ent)
							pcall(Added[methodused], ent)
							return
						end
						Updated[methodused](ent)
					end))
					for _, v in entitylib.List do
						pcall(Updated[methodused], v)
					end
				end

				if ColorFunc[methodused] then
					NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
						ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
					end))
				end

				if Loop[methodused] then
					NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
				end

				if Added[methodused] then
					task.spawn(function()
						while NameTags.Enabled do
							task.wait(0.5)
							if not NameTags.Enabled then break end
							for _, v in entitylib.List do
								if v.Character and v.Character.Parent and shouldShow(v) then
									if not Reference[v] then
										pcall(Added[methodused], v)
									elseif charCache[v] ~= v.Character then
										Removed[methodused](v)
										pcall(Added[methodused], v)
									end
								end
							end
						end
					end)
				end
			else
				if Removed[methodused] then
					for i in Reference do
						Removed[methodused](i)
					end
				end
				lastUpdate = {}
				kitCache = {}
				equipmentCache = {}
				enchantCache = {}
				healthCache = {}
				enchantConnections = {}
				gloopConnections = {}
				kitTrackerConnections = {}
				for _, list in pairs(billboardCache) do
					for _, b in ipairs(list) do
						pcall(function() b:Destroy() end)
					end
				end
				billboardCache = {}
			end
		end,
		Tooltip = 'renders nametags on entities through walls.'
	})

	Targets = NameTags:CreateTargets({
		Players = true,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	FontOption = NameTags:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	Color = NameTags:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if NameTags.Enabled and ColorFunc[methodused] then
				ColorFunc[methodused](hue, sat, val)
			end
		end
	})

	Scale = NameTags:CreateSlider({
		Name = 'Scale',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 1,
		Min = 0.1,
		Max = 1.5,
		Decimal = 10
	})

	Background = NameTags:CreateSlider({
		Name = 'Transparency',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 0.5,
		Min = 0,
		Max = 1,
		Decimal = 10
	})

	Health = NameTags:CreateToggle({
		Name = 'Health',
		Function = function(callback)
			HealthColorToggle.Object.Visible = callback
			HealthColorFull.Object.Visible = callback and HealthColorToggle.Enabled
			HealthColorMid.Object.Visible = callback and HealthColorToggle.Enabled
			HealthColorLow.Object.Visible = callback and HealthColorToggle.Enabled
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	HealthColorToggle = NameTags:CreateToggle({
		Name = 'Custom Health Colors',
		Darker = true,
		Visible = false,
		Function = function(callback)
			HealthColorFull.Object.Visible = callback
			HealthColorMid.Object.Visible = callback
			HealthColorLow.Object.Visible = callback
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	HealthColorFull = NameTags:CreateColorSlider({
		Name = 'Full HP Color',
		Darker = true,
		Visible = false,
		DefaultHue = 0.4,
		DefaultSat = 0.89,
		DefaultValue = 0.75,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	HealthColorMid = NameTags:CreateColorSlider({
		Name = 'Mid HP Color',
		Darker = true,
		Visible = false,
		DefaultHue = 0.15,
		DefaultSat = 0.89,
		DefaultValue = 0.75,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	HealthColorLow = NameTags:CreateColorSlider({
		Name = 'Low HP Color',
		Darker = true,
		Visible = false,
		DefaultHue = 0,
		DefaultSat = 0.89,
		DefaultValue = 0.75,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	Distance = NameTags:CreateToggle({
		Name = 'Distance',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	Loot = NameTags:CreateToggle({
		Name = 'Loot',
		Tooltip = 'shows how much iron/diamond/emerald they got',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Potions = NameTags:CreateToggle({
		Name = 'Potions',
		Tooltip = 'shows if they popped serpent, fury, invis, jump or speed pie',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Equipment = NameTags:CreateToggle({
		Name = 'Equipment',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	ShowKits = NameTags:CreateToggle({
		Name = 'Show Kits',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
	})

	KitTracker = NameTags:CreateToggle({
		Name = 'Kit Tracker',
		Tooltip = 'shows stats for certain kits on a player',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	Rank = NameTags:CreateToggle({
		Name = 'Rank',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	DeviceIcon = NameTags:CreateToggle({
		Name = 'Device Icon',
		Tooltip = 'shows what device the player is using',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	GloopIndicator = NameTags:CreateToggle({
		Name = 'Gloop',
		Default = true,
		Tooltip = 'shows when a player is glooped and not glooped anymore',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	Enchant = NameTags:CreateToggle({
		Name = 'Enchant',
		Tooltip = 'shows the player current enchant',
		Default = true,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	DisplayName = NameTags:CreateToggle({
		Name = 'Use Displayname',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true
	})

	Teammates = NameTags:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true
	})

	StreamProof = NameTags:CreateToggle({
		Name = 'Stream Proof',
		Default = false,
		Tooltip = 'uses drawing api so its stream proof if u record within roblox (text only, no icons)',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	Boss = NameTags:CreateToggle({
		Name = 'Boss',
		Tooltip = 'nametags for titan and bhaa (really good if u use health too!!)',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	DistanceCheck = NameTags:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})

	DistanceLimit = NameTags:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})

	task.defer(function()
		if DistanceLimit and DistanceLimit.Object then
			DistanceLimit.Object.Visible = false
		end
		if HealthColorToggle and HealthColorToggle.Object then
			HealthColorToggle.Object.Visible = false
		end
		if HealthColorFull and HealthColorFull.Object then
			HealthColorFull.Object.Visible = false
		end
		if HealthColorMid and HealthColorMid.Object then
			HealthColorMid.Object.Visible = false
		end
		if HealthColorLow and HealthColorLow.Object then
			HealthColorLow.Object.Visible = false
		end
	end)
end)
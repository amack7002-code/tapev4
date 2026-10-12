run(function()
	local Breaker
	local TargetMode
	local Mode
	local Range
	local BreakSpeed
	local UpdateRate
	local Bed
	local BedCheck
	local OuterShell
	local LuckyBlock
	local IronOre
	local Tesla
	local Hive
	local Pinata
	local Crops
	local Effect
	local CustomHealth = {}
	local Animation
	local SelfBreak
	local LimitItem
	local AutoTool
	local MouseDown
	local Snow
	local YetiBreaker
	local RagnarBreaker
	local ShowPath
	local BlockHighlight
	local BreakerHighlightColor
	local BreakerAngle
	local blockHighlightInstance
	local parts = {}
	local lastYetiUse = 0
	local cachedTeammates = {}
	local cachedTeammatesTime = 0
	local breakabilityCache = setmetatable({}, {__mode = 'k'})
	local BREAK_CACHE_TTL = 0.5
	local legitRoute = {}
	local legitTarget = nil
	local legitAnchor = nil
	local legitPlanTime = 0
	local legitLastHit = 0
	local normalTarget = nil
	local normalAnchor = nil
	local normalEndPos = nil
	local NORMAL_REPATH_DISTANCE = 5
	local _hbMounted = nil
	local _hbPart = nil
	local _hbProgressRef = nil
	local _hbBlock = nil
	local _hbPos = nil
	local _hbMax = 1
	local _hbLast = 0
	local _hbPercent = -1
	local function screenPoint()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
		return inputService:GetMouseLocation()
	end
	local function frontPoint()
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return nil end
		local look = gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude < 0.01 then return root.Position end
		return root.Position + look.Unit * 6
	end
	local function cleanupHealthbar()
		if _hbMounted then
			pcall(bedwars.Roact.unmount, _hbMounted)
			_hbMounted = nil
		end
		if _hbPart then
			pcall(function() _hbPart:Destroy() end)
			_hbPart = nil
		end
		_hbProgressRef = nil
		_hbBlock = nil
		_hbPos = nil
		_hbPercent = -1
		local stray = workspace:FindFirstChild('AeroBreakerHB')
		while stray do
			pcall(function() stray:Destroy() end)
			stray = workspace:FindFirstChild('AeroBreakerHB')
		end
	end
	local function setHealthbarPercent(percent)
		percent = math.clamp(percent, 0, 1)
		if percent <= 0 then
			cleanupHealthbar()
			return
		end
		if math.abs(percent - _hbPercent) < 0.001 then return end
		_hbPercent = percent
		local bar = _hbProgressRef and _hbProgressRef:getValue()
		if bar then
			tweenService:Create(bar, TweenInfo.new(0.15), {
				Size = UDim2.fromScale(percent, 1),
				BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
			}):Play()
		end
	end
	local function customHealthbar(self, blockRef, health, maxHealth, changeHealth, block)
		if not Breaker or not Breaker.Enabled then return end
		if not block or not block.Parent then
			cleanupHealthbar()
			return
		end
		health = math.max((tonumber(health) or 0) - (tonumber(changeHealth) or 0), 0)
		local attrHealth = block:GetAttribute('Health')
		if attrHealth and attrHealth < health then
			health = attrHealth
		end
		maxHealth = block:GetAttribute('MaxHealth') or maxHealth
		if health <= 0 then
			cleanupHealthbar()
			return
		end
		if _hbBlock ~= block then
			cleanupHealthbar()
			_hbBlock = block
			local create = bedwars.Roact.createElement
			local percent = math.clamp(health / maxHealth, 0, 1)
			_hbProgressRef = bedwars.Roact.createRef()
			local part = Instance.new('Part')
			part.Name = 'AeroBreakerHB'
			part.Size = Vector3.one
			part.CFrame = CFrame.new(bedwars.BlockController:getWorldPosition(blockRef.blockPosition))
			part.Transparency = 1
			part.Anchored = true
			part.CanCollide = false
			part.Parent = workspace
			_hbPart = part
			bedwars.QueryUtil:setQueryIgnored(part, true)
			_hbMounted = bedwars.Roact.mount(create('BillboardGui', {
				Size = UDim2.fromOffset(249, 102),
				StudsOffset = Vector3.new(0, 2.5, 0),
				Adornee = part,
				MaxDistance = 40,
				AlwaysOnTop = true
			}, {
				create('Frame', {
					Size = UDim2.fromOffset(160, 50),
					Position = UDim2.fromOffset(44, 32),
					BackgroundColor3 = Color3.new(),
					BackgroundTransparency = 0.5
				}, {
					create('UICorner', {CornerRadius = UDim.new(0, 5)}),
					create('ImageLabel', {
						Size = UDim2.new(1, 89, 1, 52),
						Position = UDim2.fromOffset(-48, -31),
						BackgroundTransparency = 1,
						Image = getcustomasset('aerov4/assets/new/blur.png'),
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(52, 31, 261, 502)
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(13, 12),
						BackgroundTransparency = 1,
						Text = (bedwars.ItemMeta[block.Name] and bedwars.ItemMeta[block.Name].displayName) or block.Name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = Color3.new(),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(12, 11),
						BackgroundTransparency = 1,
						Text = (bedwars.ItemMeta[block.Name] and bedwars.ItemMeta[block.Name].displayName) or block.Name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = color.Dark(uipallet.Text, 0.16),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('Frame', {
						Size = UDim2.fromOffset(138, 4),
						Position = UDim2.fromOffset(12, 32),
						BackgroundColor3 = uipallet.Main
					}, {
						create('UICorner', {CornerRadius = UDim.new(1, 0)}),
						create('Frame', {
							[bedwars.Roact.Ref] = _hbProgressRef,
							Size = UDim2.fromScale(percent, 1),
							BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
						}, {create('UICorner', {CornerRadius = UDim.new(1, 0)})})
					})
				})
			}), part)
		end
		_hbPos = blockRef.blockPosition
		_hbMax = math.max(tonumber(maxHealth) or health, 1)
		_hbLast = tick()
		setHealthbarPercent(health / _hbMax)
	end
	local function refreshHealthbar()
		if not _hbBlock then return end
		if not _hbBlock.Parent or (tick() - _hbLast) > 1.5 then
			cleanupHealthbar()
			return
		end
		local live = _hbBlock:GetAttribute('Health')
		if live and live / _hbMax < _hbPercent then
			setHealthbarPercent(live / _hbMax)
		end
	end
	local function cachedIsBreakable(v)
		local now = tick()
		local cached = breakabilityCache[v]
		if cached and (now - cached.t) < BREAK_CACHE_TTL then
			return cached.v
		end
		local ok, result = pcall(function()
			local blockPos = bedwars.BlockController:getBlockPosition(v.Position)
			return bedwars.BlockController:isBlockBreakable({blockPosition = blockPos}, lplr)
		end)
		local val = ok and result or false
		breakabilityCache[v] = {v = val, t = now}
		return val
	end
	local function teamKey(value)
		if value == nil then return nil end
		if typeof(value) == 'Instance' then
			return tostring(value.Name)
		end
		return tostring(value)
	end
	local function playerTeamKey(plr)
		if not plr then return nil end
		return teamKey(
			plr:GetAttribute('Team')
			or plr:GetAttribute('TeamId')
			or plr:GetAttribute('TeamID')
			or plr.Team
		)
	end
	local function isSameTeam(userId)
		local id = tonumber(userId)
		if not id then return false end
		local plr = playersService:GetPlayerByUserId(id)
		if not plr then return false end
		local mine = playerTeamKey(lplr)
		local theirs = playerTeamKey(plr)
		return mine ~= nil and theirs ~= nil and mine == theirs
	end
	local function myTeamId()
		return lplr:GetAttribute('Team')
			or lplr:GetAttribute('TeamId')
			or lplr:GetAttribute('TeamID')
			or (
				lplr.Character
				and (
					lplr.Character:GetAttribute('Team')
					or lplr.Character:GetAttribute('TeamId')
					or lplr.Character:GetAttribute('TeamID')
				)
			)
			or lplr.Team
	end
	local function isOwnTeamBlock(v)
		if not v then return false end
		local mine = teamKey(myTeamId())
		local blockTeam = teamKey(
			v:GetAttribute('Team')
			or v:GetAttribute('TeamId')
			or v:GetAttribute('TeamID')
		)
		if mine and blockTeam and mine == blockTeam then
			return true
		end
		local placedBy = tonumber(v:GetAttribute('PlacedByUserId'))
		if placedBy == lplr.UserId then
			return true
		end
		if placedBy and isSameTeam(placedBy) then
			return true
		end
		return false
	end
	local function pathBlockAllowed(v)
		if not v or not v.Parent then return false end
		if v:GetAttribute('NoBreak') then return false end
		if SelfBreak and SelfBreak.Enabled then
			return true
		end
		return not isOwnTeamBlock(v)
	end
	local function passesChecks(v)
		if v:GetAttribute('NoBreak') then return false end
		if (v:GetAttribute('BedShieldEndTime') or 0) > workspace:GetServerTimeNow() then
			return false
		end
		local mineNow = myTeamId()
		if mineNow and v:GetAttribute('Team' .. tostring(mineNow) .. 'NoBreak') then
			return false
		end
		if not pathBlockAllowed(v) then
			return false
		end
		if LimitItem.Enabled then
			local hand = store.hand and store.hand.tool
			local hmeta = hand and bedwars.ItemMeta[hand.Name]
			if not (hmeta and hmeta.breakBlock) then
				return false
			end
		end
		return true
	end
	local function ensureParts(count)
		if not (Breaker and Breaker.Enabled) then return end
		while #parts < count do
			local part = Instance.new('Part')
			part.Anchored = true
			part.CanQuery = false
			part.CanCollide = false
			part.Transparency = 1
			part.Position = Vector3.zero
			part.Parent = gameCamera
			local adorn = Instance.new('BoxHandleAdornment')
			adorn.Size = Vector3.one
			adorn.AlwaysOnTop = true
			adorn.ZIndex = 1
			adorn.Transparency = 0.5
			adorn.Adornee = part
			adorn.Parent = part
			table.insert(parts, part)
		end
	end
	local function hideParts()
		for _, p in parts do
			p.Position = Vector3.zero
		end
	end
	local function destroyParts()
		for _, p in parts do
			pcall(function()
				p:ClearAllChildren()
				p:Destroy()
			end)
		end
		table.clear(parts)
	end
	local function highlightColor(fallback)
		if BreakerHighlightColor then
			return Color3.fromHSV(BreakerHighlightColor.Hue, BreakerHighlightColor.Sat, BreakerHighlightColor.Value)
		end
		return fallback
	end
	local function setHighlight(block)
		if not (BlockHighlight and BlockHighlight.Enabled) then
			if blockHighlightInstance then blockHighlightInstance.Adornee = nil end
			return
		end
		if not blockHighlightInstance then
			if not (Breaker and Breaker.Enabled) then return end
			blockHighlightInstance = Instance.new('BoxHandleAdornment')
			blockHighlightInstance.AlwaysOnTop = true
			blockHighlightInstance.ZIndex = 10
			blockHighlightInstance.Transparency = 0.3
			blockHighlightInstance.Parent = gameCamera
		end
		blockHighlightInstance.Color3 = highlightColor(Color3.fromRGB(255, 255, 0))
		if block and block.Parent then
			blockHighlightInstance.Size = block.Size + Vector3.new(0.05, 0.05, 0.05)
			blockHighlightInstance.Adornee = block
		else
			blockHighlightInstance.Adornee = nil
		end
	end
	local function clearVisuals()
		hideParts()
		setHighlight(nil)
	end
	local function clearNormalRoute()
		normalTarget = nil
		normalAnchor = nil
		normalEndPos = nil
	end
	local function clearLegit()
		table.clear(legitRoute)
		legitTarget = nil
		legitAnchor = nil
	end
	local function cleanupAll()
		bedwars.breakerShell = false
		table.clear(breakabilityCache)
		clearNormalRoute()
		clearLegit()
		if blockHighlightInstance then
			pcall(function() blockHighlightInstance:Destroy() end)
			blockHighlightInstance = nil
		end
		destroyParts()
		cleanupHealthbar()
	end
	local function useKitAbilities()
		if RagnarBreaker and RagnarBreaker.Enabled and store.equippedKit == 'berserker' then
			pcall(function()
				if bedwars.AbilityController and bedwars.AbilityController:canUseAbility('berserker_rage') then
					replicatedStorage:WaitForChild('events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'):WaitForChild('useAbility'):FireServer('berserker_rage')
				end
			end)
		end
		if YetiBreaker and YetiBreaker.Enabled and store.equippedKit == 'yeti' and (tick() - lastYetiUse) > 1 then
			lastYetiUse = tick()
			task.spawn(function()
				pcall(function()
					if bedwars.AbilityController and bedwars.AbilityController:canUseAbility('yeti_glacial_roar') then
						replicatedStorage:WaitForChild('events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'):WaitForChild('useAbility'):FireServer('yeti_glacial_roar')
					end
				end)
			end)
		end
	end
	local function holdingCorrectTool(v)
		if AutoTool.Enabled then return true end
		local blockMeta = bedwars.ItemMeta[v.Name]
		local breaktype = v.Name == 'gumdrop_bounce_pad' and 'stone' or (blockMeta and blockMeta.block and blockMeta.block.breakType)
		if not breaktype then return true end
		local correctTool = store.tools[breaktype]
		if not correctTool then return true end
		local hand = store.hand and store.hand.tool
		return hand ~= nil and hand.Name == correctTool.tool.Name
	end
	local function drawPath(target, path, endpos)
		if not (ShowPath and ShowPath.Enabled) or not path or not target then
			hideParts()
			return
		end
		local currentnode = target
		for _, part in parts do
			part.Position = currentnode or Vector3.zero
			if currentnode then
				part.BoxHandleAdornment.Color3 = currentnode == endpos and Color3.new(1, 0.2, 0.2)
					or currentnode == target and Color3.new(0.2, 0.2, 1)
					or Color3.new(0.2, 1, 0.2)
			end
			currentnode = path[currentnode]
		end
	end
	local function drawRoute(activePos)
		if not (ShowPath and ShowPath.Enabled) then
			hideParts()
			return
		end
		for i, part in parts do
			local node = legitRoute[i]
			part.Position = node or Vector3.zero
			if node then
				part.BoxHandleAdornment.Color3 = node == activePos and Color3.new(1, 0.2, 0.2) or Color3.new(0.2, 1, 0.2)
			end
		end
	end
	local damageRemote
	task.spawn(function()
		pcall(function()
			damageRemote = replicatedStorage
				:WaitForChild('rbxts_include'):WaitForChild('node_modules')
				:WaitForChild('@easy-games'):WaitForChild('block-engine')
				:WaitForChild('node_modules'):WaitForChild('@rbxts')
				:WaitForChild('net'):WaitForChild('out')
				:WaitForChild('_NetManaged'):WaitForChild('DamageBlock')
		end)
	end)
	local function rawBreak(block)
		if not damageRemote or not block or not block.Parent then return false end
		local bp = bedwars.BlockController:getBlockPosition(block.Position)
		task.spawn(function()
			local ok, res = pcall(function()
				return damageRemote:InvokeServer({
					blockRef = {blockPosition = bp},
					hitPosition = block.Position + Vector3.new(0, block.Size.Y / 2, 0),
					hitNormal = Vector3.yAxis
				})
			end)
		end)
		return true
	end
	local ignoreList = {}
	local cursorParams = RaycastParams.new()
	cursorParams.FilterType = Enum.RaycastFilterType.Exclude
	local function cursorBlock()
		local sp = screenPoint()
		local unit = gameCamera:ViewportPointToRay(sp.X, sp.Y, 0)
		table.clear(ignoreList)
		if lplr.Character then
			table.insert(ignoreList, lplr.Character)
		end
		for _, plr in playersService:GetPlayers() do
			if plr.Character then
				table.insert(ignoreList, plr.Character)
			end
		end
		for _, ent in entitylib.List do
			if ent.Character then
				table.insert(ignoreList, ent.Character)
			end
		end
		cursorParams.FilterDescendantsInstances = ignoreList
		local result = workspace:Raycast(unit.Origin, unit.Direction * 999, cursorParams)
		if not result then return nil, nil end
		local inst = result.Instance
		return (inst and inst:IsA('BasePart')) and inst or nil, result.Position
	end
	local function containedWorldPositions(block)
		local out = {}
		local ok, handler = pcall(function()
			return bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		end)
		if ok and handler then
			local ok2, cp = pcall(function() return handler:getContainedPositions(block) end)
			if ok2 and cp then
				for _, v in cp do
					table.insert(out, v * 3)
				end
			end
		end
		if #out == 0 then
			table.insert(out, bedwars.BlockController:getBlockPosition(block.Position) * 3)
		end
		return out
	end
	local function buildLegitRoute(target)
		local anchor = frontPoint()
		if not anchor then return false end
		local bestPos, bestPath, bestStart, bestScore = nil, nil, nil, math.huge
		for _, startPos in containedWorldPositions(target) do
			local ok, pos, cost, path = pcall(
				bedwars.calculatePath,
				target,
				startPos,
				BreakerAngle.Value,
				anchor,
				nil,
				pathBlockAllowed
			)
			if ok and pos and cost then
				local score = cost + (pos - anchor).Magnitude * 0.1
				if score < bestScore then
					bestPos, bestPath, bestStart, bestScore = pos, path, startPos, score
				end
			end
		end
		if not bestPos then return false end
		table.clear(legitRoute)
		local cur = bestPos
		local guard = 0
		while cur and guard < 128 do
			guard = guard + 1
			table.insert(legitRoute, cur)
			if cur == bestStart then break end
			cur = bestPath and bestPath[cur]
		end
		legitAnchor = anchor
		legitTarget = target
		legitPlanTime = tick()
		return #legitRoute > 0
	end
	Breaker = vape.Categories.Minigames:CreateModule({
		Name = 'Breaker',
		Function = function(callback)
			if callback then
				local beds = {}
				local function bedAdd(obj)
					if obj.Name ~= 'bed' or not obj:IsA('BasePart') then return end
					if table.find(beds, obj) then return end
					table.insert(beds, obj)
				end
				local function bedRemove(obj)
					local i = table.find(beds, obj)
					if i then table.remove(beds, i) end
				end
				for _, obj in workspace:GetChildren() do
					bedAdd(obj)
				end
				Breaker:Clean(workspace.ChildAdded:Connect(bedAdd))
				Breaker:Clean(workspace.ChildRemoved:Connect(bedRemove))
				task.spawn(function()
					while Breaker.Enabled do
						task.wait(1)
						for i = #beds, 1, -1 do
							if not beds[i] or not beds[i].Parent then
								table.remove(beds, i)
							end
						end
						for _, obj in workspace:GetChildren() do
							bedAdd(obj)
						end
					end
				end)
				local luckyblock = collection('LuckyBlock', Breaker)
				local ironores = collection('iron_ore_mesh_block', Breaker)
				local trackedSpecial = {tesla_trap = {}, beehive = {}, pinata = {}, carrot = {}, melon = {}, pumpkin = {}, snow_pile = {}}
				local _trackedNames = {tesla_trap = true, beehive = true, pinata = true, carrot = true, melon = true, pumpkin = true, snow_pile = true}
				local function trackAdd(obj)
					if not _trackedNames[obj.Name] then return end
					local t = trackedSpecial[obj.Name]
					if not t then return end
					if obj:IsA('BasePart') then
						table.insert(t, obj)
					elseif obj:IsA('Model') then
						local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA('BasePart')
						if part then table.insert(t, part) end
					end
				end
				local function trackRemove(obj)
					if not _trackedNames[obj.Name] then return end
					local t = trackedSpecial[obj.Name]
					if t then
						local part = obj
						if obj:IsA('Model') then
							part = obj.PrimaryPart or obj:FindFirstChildWhichIsA('BasePart')
						end
						if part then
							local i = table.find(t, part)
							if i then table.remove(t, i) end
						end
					end
					breakabilityCache[obj] = nil
				end
				ensureParts(8)
				scanDescendants(workspace, trackAdd, Breaker)
				Breaker:Clean(workspace.DescendantAdded:Connect(trackAdd))
				Breaker:Clean(workspace.DescendantRemoving:Connect(trackRemove))
				local function getBlockHealth(block)
					return block:GetAttribute('Health')
						or (bedwars.ItemMeta[block.Name] and bedwars.ItemMeta[block.Name].block and bedwars.ItemMeta[block.Name].block.health)
						or 0
				end
				local function candidateLists()
					local lists = {}
					if Bed.Enabled then
						table.insert(lists, beds)
					end
					if Tesla and Tesla.Enabled then table.insert(lists, trackedSpecial.tesla_trap) end
					if Hive and Hive.Enabled then table.insert(lists, trackedSpecial.beehive) end
					if LuckyBlock.Enabled then table.insert(lists, luckyblock) end
					if IronOre.Enabled then table.insert(lists, ironores) end
					if Snow and Snow.Enabled then table.insert(lists, trackedSpecial.snow_pile) end
					if Pinata and Pinata.Enabled then table.insert(lists, trackedSpecial.pinata) end
					if Crops and Crops.Enabled then
						table.insert(lists, trackedSpecial.carrot)
						table.insert(lists, trackedSpecial.melon)
						table.insert(lists, trackedSpecial.pumpkin)
					end
					return lists
				end
				local function valid(v, localPosition)
					if not v or not v.Parent then return false end
					local d = (v.Position - localPosition).Magnitude
					if d >= Range.Value then
						return false
					end
					if not passesChecks(v) then
						return false
					end
					if not cachedIsBreakable(v) then
						return false
					end
					return true
				end
				local function pickBestAny(localPosition)
					local best, bestValue = nil, math.huge
					for _, tab in candidateLists() do
						for i = 1, #tab do
							local v = tab[i]
							if v and valid(v, localPosition) then
								local value
								if TargetMode.Value == 'Health' then
									value = getBlockHealth(v)
								else
									value = (v.Position - localPosition).Magnitude
								end
								if value < bestValue then
									best = v
									bestValue = value
								end
							end
						end
					end
					return best
				end
				local function pickClosestAny(localPosition)
					local best, bestDist = nil, math.huge
					for _, tab in candidateLists() do
						for i = 1, #tab do
							local v = tab[i]
							if v and valid(v, localPosition) then
								local dist = (v.Position - localPosition).Magnitude
								if dist < bestDist then
									best, bestDist = v, dist
								end
							end
						end
					end
					return best
				end
				local function pickBest(tab, localPosition)
					local best, bestValue = nil, math.huge
					for i = 1, #tab do
						local v = tab[i]
						if v and valid(v, localPosition) then
							local value = TargetMode.Value == 'Health' and getBlockHealth(v) or (v.Position - localPosition).Magnitude
							if value < bestValue then
								best, bestValue = v, value
							end
						end
					end
					return best
				end
				local function runNormal(localPosition)
					local found = false
					for _, tab in candidateLists() do
						local best = pickBest(tab, localPosition)
						if best then
							found = true
							local breakTarget = best
							bedwars.breakerShell = OuterShell.Enabled and best.Name == 'bed'
							if holdingCorrectTool(breakTarget) then
								useKitAbilities()
								setHighlight(breakTarget)
								local breakWait = BreakSpeed.Value
								local target, path, endpos = bedwars.breakBlock(
									breakTarget,
									Effect.Enabled,
									Animation.Enabled,
									CustomHealth.Enabled and customHealthbar or nil,
									AutoTool.Enabled,
									BreakerAngle.Value,
									TargetMode.Value == 'Distance' and localPosition or nil,
									0.35
								)
								if target and endpos and target == endpos then
									rawBreak(breakTarget)
								end
								if BedCheck
									and BedCheck.Enabled
									and best.Name == 'bed'
									and target
									and (target - best.Position).Magnitude < 3 then
									breakWait = math.max(breakWait, 0.3)
								end
								drawPath(target, path, endpos)
								task.wait(breakWait)
								return true
							end
						end
					end
					return found
				end
				local function runLegit(localPosition)
					local target = pickClosestAny(localPosition)
					if not target then
						clearLegit()
						return false
					end
					bedwars.breakerShell = OuterShell.Enabled and target.Name == 'bed'
					local anchor = frontPoint()
					local stale = legitTarget ~= target
						or legitTarget and not legitTarget.Parent
						or not legitAnchor
						or not anchor
						or #legitRoute == 0
						or (anchor - legitAnchor).Magnitude > 6
						or (tick() - legitPlanTime) > 2
					local frontPos, frontBlock = nil, nil
					local function findFront()
						frontPos, frontBlock = nil, nil
						for _, pos in legitRoute do
							local blk = getPlacedBlock(pos)
							if blk then
								frontPos, frontBlock = pos, blk
								break
							end
						end
					end
					if not stale then
						findFront()
						if not frontBlock then stale = true end
					end
					if stale then
						if not buildLegitRoute(target) then
							clearVisuals()
							return false
						end
						findFront()
					end
					if not frontBlock then
						clearVisuals()
						return false
					end
					local raw, hitPos = cursorBlock()
					local aimed = nil
					if raw and raw.Parent then
						if raw == frontBlock or raw:IsDescendantOf(frontBlock) then
							aimed = frontBlock
						elseif frontBlock:IsA('BasePart') and raw:IsDescendantOf(frontBlock.Parent) and raw.Name == frontBlock.Name then
							aimed = frontBlock
						end
					end
					if not aimed and hitPos and (hitPos - frontBlock.Position).Magnitude <= 4.5 then
						aimed = frontBlock
					end
					drawRoute(aimed and frontPos or nil)
					if not aimed or (aimed.Position - localPosition).Magnitude > Range.Value then
						setHighlight(nil)
						return true
					end
					setHighlight(aimed)
					if (tick() - legitLastHit) >= BreakSpeed.Value then
						legitLastHit = tick()
						if holdingCorrectTool(aimed) then
							useKitAbilities()
							bedwars.breakBlock(
								aimed,
								Effect.Enabled,
								Animation.Enabled,
								CustomHealth.Enabled and customHealthbar or nil,
								AutoTool.Enabled,
								BreakerAngle.Value,
								frontPos,
								nil,
								pathBlockAllowed
							)
						end
					end
					return true
				end
				repeat
					task.wait(1 / UpdateRate.Value)
					if not Breaker.Enabled then break end
					refreshHealthbar()
					if blockHighlightInstance and blockHighlightInstance.Adornee then
						local a = blockHighlightInstance.Adornee
						if not a.Parent or (a:GetAttribute('Health') or 1) <= 0 then
							blockHighlightInstance.Adornee = nil
							hideParts()
						end
					end
					if legitTarget and not legitTarget.Parent then
						clearLegit()
						hideParts()
					end
					if entitylib.isAlive then
						if MouseDown.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
							clearVisuals()
							continue
						end
						local localPosition = entitylib.character.RootPart.Position
						local ok, acted
						if Mode and Mode.Value == 'Legit' then
							ok, acted = pcall(runLegit, localPosition)
						else
							ok, acted = pcall(runNormal, localPosition)
						end
						if not ok then
							table.clear(breakabilityCache)
							acted = false
						end
						if not acted then
							clearVisuals()
						end
					else
						clearVisuals()
					end
				until not Breaker.Enabled
			else
				cleanupAll()
			end
		end,
		Tooltip = 'oh my god nuke the BEDD NOOOO'
	})
	vape:Clean(cleanupAll)
	TargetMode = Breaker:CreateDropdown({
		Name = 'Target Mode',
		List = {'Distance', 'Health'},
		Default = 'Distance',
		Tooltip = 'distance picks the closest block, health picks the weakest one'
	})
	Mode = Breaker:CreateDropdown({
		Name = 'Mode',
		List = {'Normal', 'Legit'},
		Default = 'Normal',
		Tooltip = 'normal digs to the block on its own, legit only breaks what ur cursor is on',
		Function = function(val)
			if TargetMode and TargetMode.Object then
				TargetMode.Object.Visible = val ~= 'Legit'
			end
			clearLegit()
		end
	})
	Range = Breaker:CreateSlider({
		Name = 'Break range',
		Min = 1,
		Max = 30,
		Default = 30,
		Tooltip = 'how far away a block can be for u to hit it'
	})
	BreakerAngle = Breaker:CreateSlider({
		Name = 'Break Angle',
		Min = 0,
		Max = 360,
		Default = 360,
		Tooltip = 'only digs thru blocks inside this cone in front of ur cam'
	})
	BreakSpeed = Breaker:CreateSlider({
		Name = 'Break speed',
		Min = 0,
		Max = 0.3,
		Default = 0.25,
		Decimal = 100,
		Tooltip = 'wait between each hit, lower is faster'
	})
	UpdateRate = Breaker:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Tooltip = 'how often it re checks for blocks, leave it high'
	})
	Bed = Breaker:CreateToggle({
		Name = 'Break Bed',
		Default = true,
		Function = function(callback)
			if BedCheck and BedCheck.Object then
				BedCheck.Object.Visible = callback
			end
			if OuterShell and OuterShell.Object then
				OuterShell.Object.Visible = callback
			end
		end
	})
	BedCheck = Breaker:CreateToggle({
		Name = 'Bed Check',
		Default = false,
		Darker = true,
		Tooltip = 'slows down to normal speed once ur actually on the bed'
	})
	OuterShell = Breaker:CreateToggle({
		Name = 'Layer Break',
		Default = false,
		Darker = true,
		Function = function(callback)
			bedwars.breakerShell = callback and Breaker.Enabled or false
			if bedwars.clearPathCache then bedwars.clearPathCache() end
			clearNormalRoute()
			clearLegit()
		end,
		Tooltip = 'only breaks from the outside in, ignores gaps hidden inside the defense'
	})
	LuckyBlock = Breaker:CreateToggle({
		Name = 'Break Lucky Block',
		Default = true
	})
	IronOre = Breaker:CreateToggle({
		Name = 'Break Iron Ore',
		Default = true
	})
	Snow = Breaker:CreateToggle({
		Name = 'Break Snow',
		Default = false
	})
	Tesla = Breaker:CreateToggle({
		Name = 'Break Tesla',
		Default = true
	})
	Hive = Breaker:CreateToggle({
		Name = 'Break Hive',
		Default = true
	})
	Pinata = Breaker:CreateToggle({
		Name = 'Break Pinata',
		Default = false
	})
	Crops = Breaker:CreateToggle({
		Name = 'Break Crops',
		Default = false,
		Tooltip = 'breaks farmer cletus crops (carrot and etc)'
	})
	Effect = Breaker:CreateToggle({
		Name = 'Show Healthbar & Effects',
		Default = true,
		Function = function(callback)
			if CustomHealth and CustomHealth.Object then
				CustomHealth.Object.Visible = callback
			end
		end
	})
	CustomHealth = Breaker:CreateToggle({
		Name = 'Custom Healthbar',
		Default = true,
		Darker = true
	})
	Animation = Breaker:CreateToggle({
		Name = 'Animation',
		Tooltip = 'plays the swing animation while u dig'
	})
	SelfBreak = Breaker:CreateToggle({
		Name = 'Self Break',
		Tooltip = 'lets it break ur own bed and blocks u or ur team placed',
		Function = function()
			if bedwars.clearPathCache then bedwars.clearPathCache() end
			table.clear(breakabilityCache)
			clearNormalRoute()
			clearLegit()
		end
	})
	AutoTool = Breaker:CreateToggle({
		Name = 'Auto Tool',
		Default = true,
		Tooltip = 'swaps to the right tool on its own, off means it waits till ur holdin it'
	})
	LimitItem = Breaker:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'only works while ur holdin sum that can break blocks'
	})
	MouseDown = Breaker:CreateToggle({
		Name = 'Require Mouse Down',
		Tooltip = 'only digs while u hold left click'
	})
	YetiBreaker = Breaker:CreateToggle({
		Name = 'Yeti Breaker',
		Tooltip = 'pops the yeti roar whenever ur nuking'
	})
	RagnarBreaker = Breaker:CreateToggle({
		Name = 'Ragnar',
		Tooltip = 'pops the ragnar rage whenever ur nuking'
	})
	ShowPath = Breaker:CreateToggle({
		Name = 'Show Path',
		Default = true,
		Tooltip = 'shows u the blocks its diggin thru'
	})
	BlockHighlight = Breaker:CreateToggle({
		Name = 'Block Highlight',
		Default = false,
		Function = function(callback)
			if BreakerHighlightColor and BreakerHighlightColor.Object then
				BreakerHighlightColor.Object.Visible = callback
			end
			if not callback and blockHighlightInstance then
				blockHighlightInstance.Adornee = nil
			end
		end,
		Tooltip = 'boxes the block its hittin rn'
	})
	BreakerHighlightColor = Breaker:CreateColorSlider({
		Name = 'Highlight Color',
		Darker = true,
		Visible = false
	})
	task.defer(function()
		if CustomHealth and CustomHealth.Object and Effect then
			CustomHealth.Object.Visible = Effect.Enabled
		end
		if BedCheck and BedCheck.Object and Bed then
			BedCheck.Object.Visible = Bed.Enabled
		end
		if OuterShell and OuterShell.Object and Bed then
			OuterShell.Object.Visible = Bed.Enabled
		end
		if BreakerHighlightColor and BreakerHighlightColor.Object and BlockHighlight then
			BreakerHighlightColor.Object.Visible = BlockHighlight.Enabled
		end
		if TargetMode and TargetMode.Object and Mode then
			TargetMode.Object.Visible = Mode.Value ~= 'Legit'
		end
	end)
end)
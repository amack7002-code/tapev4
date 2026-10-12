run(function()
	local KitRender
	local LastKitToggle
	local LastKitCount
	local LevelToggle
	local PartyToggle
	local Players = playersService
	local player = Players.LocalPlayer
	local PlayerGui = player:WaitForChild("PlayerGui")
	local scanThread = nil
	local retryThread = nil
	local currentDraft = nil
	local lastKitCache = {}
	local lastKitPending = {}
	local lastKitRetry = {}
	local partyCache = {}
	local currentPartyNumbers = {}

	local function resolveKitImage(kit)
		kit = kit or "none"
		local meta = bedwars.BedwarsKitMeta and (bedwars.BedwarsKitMeta[kit] or bedwars.BedwarsKitMeta.none)
		return (meta and meta.renderImage) or kitImageIds[kit] or kitImageIds["none"] or ""
	end

	local function clearLastKitCache()
		table.clear(lastKitCache)
		table.clear(lastKitPending)
		table.clear(lastKitRetry)
		table.clear(partyCache)
		table.clear(currentPartyNumbers)
	end

	local function destroyNamed(root, name)
		if not root then return end
		for _, obj in root:GetDescendants() do
			if obj.Name == name then
				obj:Destroy()
			end
		end
	end

	local function cleanupVisuals()
		destroyNamed(PlayerGui, "aerov4KitRender")
		destroyNamed(PlayerGui, "aerov4KitIcon")
		destroyNamed(PlayerGui, "aerov4KitLevel")
		destroyNamed(PlayerGui, "aerov4LastKit")
	end

	local function cleanupLastMatch()
		destroyNamed(PlayerGui, "aerov4LastKit")
	end

	local function extractHistory(payload)
		if type(payload) ~= "table" then return nil end

		if type(payload.matchHistory) == "table" then
			return payload.matchHistory
		end

		if type(payload.data) == "table" then
			if type(payload.data.matchHistory) == "table" then
				return payload.data.matchHistory
			end
			if type(payload.data.history) == "table" then
				return payload.data.history
			end
			if next(payload.data) ~= nil then
				return payload.data
			end
		end

		if type(payload.history) == "table" then
			return payload.history
		end

		return payload
	end

	local function getMatchEntry(match, uid)
		if type(match) ~= "table" or type(match.players) ~= "table" then return nil end
		for _, entry in match.players do
			local info = entry and entry.playerInfo
			if info and tostring(info.userId) == tostring(uid) then
				return entry
			end
		end
		return nil
	end

	local function readLastCompletedKit(history, uid)
		if type(history) ~= "table" then return nil end

		local matches = {}
		local order = 0

		if history[1] ~= nil then
			for index, match in ipairs(history) do
				if type(match) == "table" then
					order += 1
					table.insert(matches, {
						match = match,
						time = tonumber(match.matchStartTime) or tonumber(match.startTime) or 0,
						order = order,
						index = index
					})
				end
			end
		else
			for index, match in pairs(history) do
				if type(match) == "table" then
					order += 1
					table.insert(matches, {
						match = match,
						time = tonumber(match.matchStartTime) or tonumber(match.startTime) or 0,
						order = order,
						index = tonumber(index) or order
					})
				end
			end
		end

		table.sort(matches, function(a, b)
			if a.time ~= b.time then
				return a.time > b.time
			end
			if a.index ~= b.index then
				return a.index < b.index
			end
			return a.order < b.order
		end)

		local kits = {}
		local loose = {}

		for _, record in matches do
			local entry = getMatchEntry(record.match, uid)
			if entry then
				local kit = entry.bedwars and entry.bedwars.kit
				if type(kit) == "string" and kit ~= "" then
					local outcome = entry.generic and string.lower(tostring(entry.generic.matchOutcome or "")) or ""
					if outcome == "win"
						or outcome == "loss"
						or outcome == "lose"
						or outcome == "lost"
						or outcome == "defeat"
						or outcome == "victory" then
						table.insert(kits, kit)
						if #kits >= 3 then break end
					elseif #loose < 3 then
						table.insert(loose, kit)
					end
				end
			end
		end

		if #kits == 0 then
			kits = loose
		end

		return #kits > 0 and kits or nil
	end

	local function readTeammates(history, uid)
		local found = {}
		if type(history) ~= "table" then return found end
		local matches = {}
		for _, match in pairs(history) do
			if type(match) == "table" and type(match.players) == "table" then
				table.insert(matches, match)
			end
		end
		table.sort(matches, function(a, b)
			return (tonumber(a.matchStartTime) or 0) > (tonumber(b.matchStartTime) or 0)
		end)
		for i = 1, math.min(5, #matches) do
			local match = matches[i]
			local me = getMatchEntry(match, uid)
			local myTeam = me and (me.teamId or (me.generic and me.generic.team))
			if myTeam then
				for _, entry in match.players do
					local info = entry and entry.playerInfo
					local otherTeam = entry and (entry.teamId or (entry.generic and entry.generic.team))
					if info and info.userId and not entry.observer and tostring(info.userId) ~= tostring(uid) and tostring(otherTeam) == tostring(myTeam) then
						local key = tonumber(info.userId)
						found[key] = (found[key] or 0) + 1
					end
				end
			end
		end
		return found
	end

	local function finishLastKit(uid, payload)
		local history = extractHistory(payload)
		local kit = readLastCompletedKit(history, uid)
		lastKitCache[uid] = kit or false
		partyCache[uid] = readTeammates(history, uid)
		lastKitPending[uid] = nil
		lastKitRetry[uid] = nil
	end

	local function failLastKit(uid)
		lastKitPending[uid] = nil
		lastKitRetry[uid] = tick() + 1.5
	end

	local function consumeHistoryRequest(uid, request)
		if type(request) == "table" and type(request.andThen) == "function" then
			local chained = pcall(function()
				request:andThen(function(data)
					finishLastKit(uid, data)
				end):catch(function()
					failLastKit(uid)
				end)
			end)
			if not chained then
				failLastKit(uid)
			end
			return
		end

		if type(request) == "table" then
			finishLastKit(uid, request)
		else
			failLastKit(uid)
		end
	end

	local function fetchLastKit(plr)
		if not plr then return end
		local uid = plr.UserId
		if lastKitCache[uid] ~= nil or lastKitPending[uid] then return end
		if lastKitRetry[uid] and tick() < lastKitRetry[uid] then return end

		lastKitPending[uid] = true

		task.spawn(function()
			local controllers = (bedwars.KnitClient and bedwars.KnitClient.Controllers)
				or (bedwars.Knit and bedwars.Knit.Controllers)
			local controller = bedwars.MatchHistoryController
				or (controllers and controllers.MatchHistoryController)
				or bedwars.MatchHistoryController

			local request = nil

			if controller and type(controller.requestMatchHistory) == "function" then
				local ok, result = pcall(function()
					return controller:requestMatchHistory(plr.Name)
				end)
				if ok then
					request = result
				end
			end

			if not request then
				pcall(function()
					request = bedwars.Client:Get("RequestMatchHistory"):CallServerAsync(plr.Name)
				end)
			end

			if not request then
				local _remotes = getgenv().remotes or remotes
				pcall(function()
					local remoteName = _remotes and (_remotes.RequestMatchHistory or "RequestMatchHistory") or "RequestMatchHistory"
					request = bedwars.Client:Get(remoteName):CallServerAsync(plr.Name)
				end)
			end

			if not request then
				pcall(function()
					local client = require(replicatedStorage.TS.remotes).default.Client
					request = client:Get("RequestMatchHistory"):CallServerAsync(plr.Name)
				end)
			end

			if not request then
				failLastKit(uid)
				return
			end

			consumeHistoryRequest(uid, request)
		end)
	end

	local function unclip(inst)
		local node = inst
		for _ = 1, 7 do
			if not node then break end
			pcall(function()
				node.ClipsDescendants = false
			end)
			node = node.Parent
		end
	end

	local function findPlayerFromRender(render)
		if not render then return nil end

		local image = tostring(render.Image or "")
		local userId = image:match("id=(%d+)")
			or image:match("userId=(%d+)")
			or image:match("(%d+)")

		if userId then
			local plr = Players:GetPlayerByUserId(tonumber(userId))
			if plr then return plr end
		end

		local node = render.Parent
		for _ = 1, 6 do
			if not node then break end
			local label = node:FindFirstChild("PlayerName", true)
			if label and label:IsA("TextLabel") then
				local text = label.Text
				for _, plr in Players:GetPlayers() do
					if plr.Name == text or plr.DisplayName == text or plr:GetAttribute("DisguiseDisplayName") == text then
						return plr
					end
					local smName = nil
					pcall(function()
						smName = bedwars.KnitClient.Controllers.StreamerModeController:getDisplayName(plr)
					end)
					if smName and smName == text then
						return plr
					end
				end
			end
			node = node.Parent
		end

		return nil
	end

	local function findHost(render)
		local node = render
		local fallback = nil

		for _ = 1, 8 do
			node = node and node.Parent
			if not node then break end

			if node.Name == "MatchDraftPlayerCard" then
				return node
			end

			if not fallback and node:FindFirstChild("PlayerName", true) and node:FindFirstChild("PlayerRender", true) then
				fallback = node
			end
		end

		return fallback or render.Parent
	end

	local function isEnemy(plr)
		if not plr or plr == player then return false end
		local myTeam = player:GetAttribute("Team")
		local theirTeam = plr:GetAttribute("Team")
		if not myTeam or not theirTeam then return false end
		return myTeam ~= theirTeam
	end

	local function ensureCurrentKit(host, plr)
		if not host or not host.Parent then return end
		unclip(host)

		local icon = host:FindFirstChild("aerov4KitRender")
		if not icon then
			icon = Instance.new("ImageLabel")
			icon.Name = "aerov4KitRender"
			icon.AnchorPoint = Vector2.new(1, 0.5)
			icon.Position = UDim2.new(1.05, 0, 0.5, 0)
			icon.Size = UDim2.new(1.5, 0, 1.5, 0)
			icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
			icon.BackgroundTransparency = 1
			icon.BorderSizePixel = 0
			icon.ImageTransparency = 0.4
			icon.ScaleType = Enum.ScaleType.Crop
			icon.ZIndex = 5

			local ratio = Instance.new("UIAspectRatioConstraint")
			ratio.AspectRatio = 1
			ratio.AspectType = Enum.AspectType.FitWithinMaxSize
			ratio.DominantAxis = Enum.DominantAxis.Width
			ratio.Parent = icon

			icon.Parent = host
		end

		local kit = plr:GetAttribute("PlayingAsKits") or "none"
		local image = resolveKitImage(kit)
		if icon.Image ~= image then
			icon.Image = image
		end
	end

	local function ensureLevel(host, plr)
		if not host or not host.Parent then return end
		local nameLabel = host:FindFirstChild("PlayerName", true)
		if not nameLabel then return end
		unclip(nameLabel)

		local levelLabel = nameLabel:FindFirstChild("aerov4KitLevel")
		if not levelLabel then
			levelLabel = Instance.new("TextLabel")
			levelLabel.Name = "aerov4KitLevel"
			levelLabel.AnchorPoint = Vector2.new(0, 0.5)
			levelLabel.Position = UDim2.new(1, 5, 0.5, 0)
			levelLabel.Size = UDim2.fromOffset(44, 15)
			levelLabel.BackgroundTransparency = 1
			levelLabel.TextColor3 = Color3.fromRGB(255, 214, 51)
			levelLabel.TextSize = 12
			levelLabel.Font = Enum.Font.GothamBold
			levelLabel.TextStrokeTransparency = 0.25
			levelLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			levelLabel.TextXAlignment = Enum.TextXAlignment.Left
			levelLabel.TextYAlignment = Enum.TextYAlignment.Center
			levelLabel.ZIndex = 10001
			levelLabel.Parent = nameLabel
		end

		local level = plr:GetAttribute("PlayerLevel") or 0
		local text = "[" .. tostring(level) .. "]"
		if levelLabel.Text ~= text then
			levelLabel.Text = text
		end
	end

	local function createLastMatchBadge(host, plr, slot)
		slot = slot or 1
		local badge = Instance.new("Frame")
		badge.Name = "aerov4LastKit"
		badge:SetAttribute("UserId", plr.UserId)
		badge:SetAttribute("Slot", slot)
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.new(0.41, (slot - 1) * 58, 0.5, 0)
		badge.Size = UDim2.fromOffset(54, 56)
		badge.BackgroundTransparency = 1
		badge.BorderSizePixel = 0
		badge.ClipsDescendants = false
		badge.ZIndex = 10000
		badge.Visible = false

		local tag = Instance.new("TextLabel")
		tag.Name = "Tag"
		tag.AnchorPoint = Vector2.new(0.5, 0)
		tag.Position = UDim2.new(0.5, 0, 0, -1)
		tag.Size = UDim2.new(1.1, 0, 0, 14)
		tag.BackgroundTransparency = 1
		tag.Text = slot == 1 and "last game" or (slot .. " games ago")
		tag.TextColor3 = Color3.fromRGB(255, 64, 64)
		tag.TextSize = 10
		tag.Font = Enum.Font.FredokaOne
		tag.TextStrokeTransparency = 0.35
		tag.TextStrokeColor3 = Color3.new(0, 0, 0)
		tag.TextXAlignment = Enum.TextXAlignment.Center
		tag.ZIndex = 10002
		tag.Parent = badge

		local img = Instance.new("ImageLabel")
		img.Name = "Render"
		img.AnchorPoint = Vector2.new(0.5, 1)
		img.Position = UDim2.new(0.5, 0, 1, 1)
		img.Size = UDim2.fromOffset(44, 41)
		img.BackgroundTransparency = 1
		img.BorderSizePixel = 0
		img.ImageTransparency = 0.05
		img.ScaleType = Enum.ScaleType.Fit
		img.ZIndex = 10001
		img.Parent = badge

		badge.Parent = host
		return badge
	end

	local function ensureLastMatch(host, plr)
		if not host or not host.Parent then return end

		if not (LastKitToggle and LastKitToggle.Enabled) then
			for _, old in host:GetChildren() do
				if old.Name == "aerov4LastKit" then
					old:Destroy()
				end
			end
			return
		end

		unclip(host)

		local count = LastKitCount and LastKitCount.Value or 1
		local badges = {}
		for _, obj in host:GetChildren() do
			if obj.Name == "aerov4LastKit" then
				local slot = obj:GetAttribute("Slot") or 1
				if slot > count or badges[slot] then
					obj:Destroy()
				else
					badges[slot] = obj
				end
			end
		end

		local cached = lastKitCache[plr.UserId]
		if cached == nil then
			fetchLastKit(plr)
		end

		for slot = 1, count do
			local badge = badges[slot] or createLastMatchBadge(host, plr, slot)
			local kit = type(cached) == "table" and cached[slot]
			if kit then
				local img = badge:FindFirstChild("Render")
				local image = resolveKitImage(kit)
				if img and img.Image ~= image then
					img.Image = image
				end
				badge.Visible = true
			else
				badge.Visible = false
			end
		end
	end

	local function getPartyNumbers()
		local list = {}
		for _, plr in Players:GetPlayers() do
			if partyCache[plr.UserId] then
				table.insert(list, plr)
			end
		end
		table.sort(list, function(a, b)
			return a.UserId < b.UserId
		end)
		local parent = {}
		local function find(x)
			while parent[x] ~= x do
				x = parent[x]
			end
			return x
		end
		for _, plr in list do
			parent[plr.UserId] = plr.UserId
		end
		for i, a in list do
			for j = i + 1, #list do
				local b = list[j]
				if a:GetAttribute("Team") == b:GetAttribute("Team") then
					local ab = partyCache[a.UserId][b.UserId] or 0
					local ba = partyCache[b.UserId][a.UserId] or 0
					if math.max(ab, ba) >= 2 then
						parent[find(b.UserId)] = find(a.UserId)
					end
				end
			end
		end
		local groups, order = {}, {}
		for _, plr in list do
			local root = find(plr.UserId)
			if not groups[root] then
				groups[root] = {}
				table.insert(order, root)
			end
			table.insert(groups[root], plr.UserId)
		end
		local numbers = {}
		local n = 0
		for _, root in order do
			if #groups[root] >= 2 then
				n += 1
				for _, id in groups[root] do
					numbers[id] = n
				end
			end
		end
		return numbers
	end

	local function ensureParty(host, plr)
		local icon = host and host:FindFirstChild("aerov4KitRender")
		if not icon then return end
		local badge = icon:FindFirstChild("aerov4Party")
		local num = PartyToggle and PartyToggle.Enabled and currentPartyNumbers[plr.UserId]
		if not num then
			if badge then
				badge.Visible = false
			end
			return
		end
		if not badge then
			badge = Instance.new("TextLabel")
			badge.Name = "aerov4Party"
			badge.AnchorPoint = Vector2.new(1, 0)
			badge.Position = UDim2.new(1, 2, 0, -2)
			badge.Size = UDim2.fromOffset(16, 16)
			badge.BackgroundColor3 = Color3.fromRGB(40, 120, 255)
			badge.BorderSizePixel = 0
			badge.TextColor3 = Color3.new(1, 1, 1)
			badge.TextSize = 11
			badge.Font = Enum.Font.GothamBold
			badge.ZIndex = 10003
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = badge
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Thickness = 1
			stroke.Color = Color3.new(0, 0, 0)
			stroke.Parent = badge
			badge.Parent = icon
		end
		local text = tostring(num)
		if badge.Text ~= text then
			badge.Text = text
		end
		badge.Visible = true
	end

	local function processRender(render)
		if not KitRender.Enabled or not render or not render.Parent then return end
		if render.Name ~= "PlayerRender" or not render:IsA("ImageLabel") then return end

		local plr = findPlayerFromRender(render)
		if not plr then return end
		if not isEnemy(plr) then
			local mine, theirs = player:GetAttribute("Team"), plr:GetAttribute("Team")
			if mine and theirs and mine == theirs then
				local mateHost = findHost(render)
				destroyNamed(mateHost, "aerov4KitRender")
				destroyNamed(mateHost, "aerov4KitLevel")
				destroyNamed(mateHost, "aerov4LastKit")
			end
			return
		end

		local host = findHost(render)
		if not host or not host.Parent then return end

		ensureCurrentKit(host, plr)
		if LevelToggle and LevelToggle.Enabled then
			ensureLevel(host, plr)
		else
			destroyNamed(host, "aerov4KitLevel")
		end
		ensureLastMatch(host, plr)
		if PartyToggle and PartyToggle.Enabled and lastKitCache[plr.UserId] == nil then
			fetchLastKit(plr)
		end
		ensureParty(host, plr)
	end

	local function scanDraft(app)
		if not app or not app.Parent then return end
		currentPartyNumbers = getPartyNumbers()
		for _, obj in app:GetDescendants() do
			if obj.Name == "PlayerRender" and obj:IsA("ImageLabel") then
				pcall(processRender, obj)
			end
		end
	end

	local function startScanner()
		if scanThread then return end

		scanThread = task.spawn(function()
			while KitRender and KitRender.Enabled do
				local app = PlayerGui:FindFirstChild("MatchDraftApp")

				if app ~= currentDraft then
					cleanupVisuals()
					clearLastKitCache()
					currentDraft = app
				end

				if app then
					pcall(scanDraft, app)
				end

				task.wait(0.25)
			end

			scanThread = nil
		end)
	end

	local function stopScanner()
		if scanThread then
			pcall(task.cancel, scanThread)
			scanThread = nil
		end

		if retryThread then
			pcall(task.cancel, retryThread)
			retryThread = nil
		end

		currentDraft = nil
		clearLastKitCache()
		cleanupVisuals()
	end

	KitRender = vape.Categories.Utility:CreateModule({
		Name = "KitRender",
		Tooltip = "renders enemy kits during draft and shows their last match kit",
		Function = function(callback)
			if callback then
				cleanupVisuals()
				clearLastKitCache()
				startScanner()

				if not PlayerGui:FindFirstChild("MatchDraftApp") then
					retryThread = task.spawn(function()
						while KitRender.Enabled and not PlayerGui:FindFirstChild("MatchDraftApp") do
							task.wait(0.25)
						end
						if KitRender.Enabled then
							startScanner()
						end
						retryThread = nil
					end)
				end
			else
				stopScanner()
			end
		end
	})

	LastKitToggle = KitRender:CreateToggle({
		Name = "Show Last Match",
		Default = true,
		Tooltip = "shows the kit they used in their last completed match",
		Function = function(callback)
			if LastKitCount then
				LastKitCount.Object.Visible = callback
			end

			if not callback then
				cleanupLastMatch()
				return
			end

			clearLastKitCache()
			if KitRender and KitRender.Enabled then
				local app = PlayerGui:FindFirstChild("MatchDraftApp")
				if app then
					pcall(scanDraft, app)
				end
			end
		end
	})

	LastKitCount = KitRender:CreateSlider({
		Name = "last match count",
		Min = 1,
		Max = 3,
		Default = 1,
		Tooltip = "how many of they old kits u tryna see gng, 1 is they last game and 3 is 3 games ago",
		Function = function()
			if KitRender and KitRender.Enabled then
				local app = PlayerGui:FindFirstChild("MatchDraftApp")
				if app then
					pcall(scanDraft, app)
				end
			end
		end
	})
	LastKitCount.Object.Visible = LastKitToggle.Enabled

	LevelToggle = KitRender:CreateToggle({
		Name = "show level",
		Default = true,
		Tooltip = "shows they level next to they name so u know if they a sweat or not",
		Function = function()
			if KitRender and KitRender.Enabled then
				local app = PlayerGui:FindFirstChild("MatchDraftApp")
				if app then
					pcall(scanDraft, app)
				end
			end
		end
	})

	PartyToggle = KitRender:CreateToggle({
		Name = "show party",
		Default = true,
		Tooltip = "puts a number on ppl who queue together, same number means same party",
		Function = function()
			if KitRender and KitRender.Enabled then
				local app = PlayerGui:FindFirstChild("MatchDraftApp")
				if app then
					pcall(scanDraft, app)
				end
			end
		end
	})
end)
run(function()
	local AutoDrill
	local DrillESP
	local TeamCheck
	local ShowOwn
	local Background
	local BackgroundColor
	local AutoAttack
	local Targets
	local AttackRange
	local AttackDelay
	local SilentMount
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local Reference = {}
	local espConnections = {}
	local attackRunning = false
	local lastAttackTime = 0
	local mountedDrill = nil
	local drillRemote, attackRemote

	task.spawn(function()
		pcall(function()
			local net = replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged
			drillRemote = net:WaitForChild('PlayerUseDrillController', 10)
			attackRemote = net:WaitForChild('DrillAttack', 10)
		end)
	end)

	local function isDrill(obj)
		return obj and obj:IsA('Model') and obj.Name == 'Drill'
	end

	local function getDrillHead(drill)
		return drill:FindFirstChild('Head') or drill.PrimaryPart or drill:FindFirstChildWhichIsA('BasePart')
	end

	local function isOwnDrill(drill)
		if not drill then return false end
		return drill:GetAttribute('PlacedByUserId') == lplr.UserId
	end

	local function isTeammateDrill(drill)
		local placerId = drill:GetAttribute('PlacedByUserId')
		if not placerId then return false end
		if placerId == lplr.UserId then return false end
		local placer = playersService:GetPlayerByUserId(placerId)
		return placer ~= nil and placer.Team == lplr.Team
	end

	local function shouldShowDrill(drill)
		if isOwnDrill(drill) then
			return ShowOwn == nil or ShowOwn.Enabled
		end
		if TeamCheck and TeamCheck.Enabled and isTeammateDrill(drill) then
			return false
		end
		return true
	end

	local drillSet = {}
	local drillTracking = false
	local function getAllDrills()
		if not drillTracking then
			drillTracking = true
			for _, obj in workspace:GetDescendants() do
				if isDrill(obj) then
					drillSet[obj] = true
				end
			end
			vape:Clean(workspace.DescendantAdded:Connect(function(obj)
				if isDrill(obj) then
					drillSet[obj] = true
				end
			end))
			vape:Clean(workspace.DescendantRemoving:Connect(function(obj)
				drillSet[obj] = nil
			end))
		end
		local found = {}
		for drill in drillSet do
			if drill.Parent then
				table.insert(found, drill)
			else
				drillSet[drill] = nil
			end
		end
		return found
	end

	local function getDrillInfo(drill)
		local itemType = drill:GetAttribute('ItemType')
		local health = drill:GetAttribute('Health') or 0
		local maxHealth = drill:GetAttribute('MaxHealth') or 750
		local amount = 0
		if itemType then
			amount = drill:GetAttribute(itemType) or 0
		end
		return itemType, amount, health, maxHealth
	end

	local function getProperIcon(iconType)
		if not iconType or iconType == '' then return '' end
		local ok, icon = pcall(function()
			return bedwars.getIcon({itemType = iconType}, true)
		end)
		if not ok or not icon then return '' end
		return icon
	end

	local function updateESP(drill)
		local ref = Reference[drill]
		if not ref or not ref.billboard or not ref.billboard.Parent then return end

		local itemType, amount, health, maxHealth = getDrillInfo(drill)

		if ref.healthLabel then
			ref.healthLabel.Text = tostring(math.floor(health))
			local pct = maxHealth > 0 and (health / maxHealth) or 0
			if pct > 0.6 then
				ref.healthLabel.TextColor3 = Color3.fromRGB(80, 235, 80)
			elseif pct > 0.3 then
				ref.healthLabel.TextColor3 = Color3.fromRGB(255, 175, 60)
			else
				ref.healthLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
			end
		end

		if ref.resourceImage then
			local icon = itemType and getProperIcon(itemType) or ''
			if ref.lastIcon ~= icon then
				ref.lastIcon = icon
				ref.resourceImage.Image = icon
			end
			ref.resourceImage.Visible = icon ~= ''
		end

		if ref.amountLabel then
			ref.amountLabel.Text = tostring(math.floor(amount))
		end

		if ref.ownLabel then
			ref.ownLabel.Visible = isOwnDrill(drill)
		end
	end

	local function removeESP(drill)
		local ref = Reference[drill]
		if not ref then return end
		Reference[drill] = nil
		if ref.attrConn then pcall(function() ref.attrConn:Disconnect() end) end
		if ref.billboard then pcall(function() ref.billboard:Destroy() end) end
	end

	local function createESP(drill)
		if Reference[drill] then return end
		if not shouldShowDrill(drill) then return end

		local head = getDrillHead(drill)
		if not head then return end

		local billboard = Instance.new('BillboardGui')
		billboard.Name = 'drill-esp'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(124, 26)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = head
		billboard.Parent = Folder

		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled

		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(BackgroundColor.Hue, BackgroundColor.Sat, BackgroundColor.Value)
		frame.BackgroundTransparency = 1 - (Background.Enabled and (BackgroundColor.Opacity or 0.3) or 1)
		frame.BorderSizePixel = 0
		frame.Parent = billboard

		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = frame

		local drillImage = Instance.new('ImageLabel')
		drillImage.Name = 'DrillIcon'
		drillImage.Size = UDim2.fromOffset(18, 18)
		drillImage.Position = UDim2.new(0, 4, 0.5, 0)
		drillImage.AnchorPoint = Vector2.new(0, 0.5)
		drillImage.BackgroundTransparency = 1
		drillImage.Image = getProperIcon('drill')
		drillImage.Parent = frame

		local healthLabel = Instance.new('TextLabel')
		healthLabel.Name = 'Health'
		healthLabel.Size = UDim2.new(0, 34, 1, 0)
		healthLabel.Position = UDim2.new(0, 25, 0, 0)
		healthLabel.BackgroundTransparency = 1
		healthLabel.Text = '0'
		healthLabel.TextColor3 = Color3.new(1, 1, 1)
		healthLabel.TextSize = 12
		healthLabel.Font = Enum.Font.GothamBold
		healthLabel.TextStrokeTransparency = 0.5
		healthLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		healthLabel.TextXAlignment = Enum.TextXAlignment.Left
		healthLabel.Parent = frame

		local resourceImage = Instance.new('ImageLabel')
		resourceImage.Name = 'ResourceIcon'
		resourceImage.Size = UDim2.fromOffset(16, 16)
		resourceImage.Position = UDim2.new(0, 64, 0.5, 0)
		resourceImage.AnchorPoint = Vector2.new(0, 0.5)
		resourceImage.BackgroundTransparency = 1
		resourceImage.Image = ''
		resourceImage.Visible = false
		resourceImage.Parent = frame

		local amountLabel = Instance.new('TextLabel')
		amountLabel.Name = 'Amount'
		amountLabel.Size = UDim2.new(0, 30, 1, 0)
		amountLabel.Position = UDim2.new(0, 84, 0, 0)
		amountLabel.BackgroundTransparency = 1
		amountLabel.Text = '0'
		amountLabel.TextColor3 = Color3.new(1, 1, 1)
		amountLabel.TextSize = 12
		amountLabel.Font = Enum.Font.GothamBold
		amountLabel.TextStrokeTransparency = 0.5
		amountLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		amountLabel.TextXAlignment = Enum.TextXAlignment.Left
		amountLabel.Parent = frame

		local ownLabel = Instance.new('TextLabel')
		ownLabel.Name = 'Own'
		ownLabel.Size = UDim2.fromOffset(12, 12)
		ownLabel.Position = UDim2.new(1, -14, 0, 1)
		ownLabel.BackgroundTransparency = 1
		ownLabel.Text = '★'
		ownLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
		ownLabel.TextSize = 12
		ownLabel.Font = Enum.Font.GothamBold
		ownLabel.Visible = isOwnDrill(drill)
		ownLabel.Parent = frame

		Reference[drill] = {
			billboard = billboard,
			frame = frame,
			healthLabel = healthLabel,
			resourceImage = resourceImage,
			amountLabel = amountLabel,
			ownLabel = ownLabel,
			lastIcon = nil
		}

		Reference[drill].attrConn = drill.AttributeChanged:Connect(function()
			if Reference[drill] then updateESP(drill) end
		end)

		updateESP(drill)
	end

	local function refreshESP()
		for drill in Reference do
			removeESP(drill)
		end
		table.clear(Reference)
		if DrillESP and DrillESP.Enabled and AutoDrill and AutoDrill.Enabled then
			for _, drill in getAllDrills() do
				createESP(drill)
			end
		end
	end

	local function disconnectESP()
		for _, conn in espConnections do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(espConnections)
		for drill in Reference do
			removeESP(drill)
		end
		table.clear(Reference)
	end

	local function setupESPConnections()
		disconnectESP()

		table.insert(espConnections, workspace.DescendantAdded:Connect(function(obj)
			if not (DrillESP and DrillESP.Enabled) then return end
			if not isDrill(obj) then return end
			task.spawn(function()
				task.wait(0.2)
				if DrillESP.Enabled and obj.Parent then
					createESP(obj)
				end
			end)
		end))

		table.insert(espConnections, workspace.DescendantRemoving:Connect(function(obj)
			if Reference[obj] then removeESP(obj) end
		end))

		local lastScan = 0
		table.insert(espConnections, runService.Heartbeat:Connect(function()
			if not (DrillESP and DrillESP.Enabled) then return end
			local now = tick()
			if now - lastScan < 0.5 then return end
			lastScan = now

			for drill, ref in Reference do
				if not drill.Parent then
					removeESP(drill)
				elseif not shouldShowDrill(drill) then
					removeESP(drill)
				else
					updateESP(drill)
				end
			end

			for _, drill in getAllDrills() do
				if not Reference[drill] and shouldShowDrill(drill) then
					createESP(drill)
				end
			end
		end))

		for _, drill in getAllDrills() do
			createESP(drill)
		end
	end

	local function releaseClientLock()
		pcall(function()
			local Knit = require(replicatedStorage.rbxts_include.node_modules['@easy-games'].knit.src).KnitClient
			local tablet = Knit.Controllers.DrillTabletController
			if tablet then
				if tablet.sessionMaid and tablet.sessionMaid.DoCleaning then
					tablet.sessionMaid:DoCleaning()
				end
				tablet.enabled = false
				tablet.lastAttackTime = 0
			end
			local item = Knit.Controllers.DrillItemController
			if item and item.sessionMaid and item.sessionMaid.DoCleaning then
				item.sessionMaid:DoCleaning()
			end
			if gameCamera then
				gameCamera.CameraSubject = entitylib.character and entitylib.character.Humanoid or gameCamera.CameraSubject
				gameCamera.CameraType = Enum.CameraType.Custom
			end
		end)
	end

	local lockedEnt = nil
	local lockedAt = 0

	local function targetStillGood(ent, drill)
		if not ent or not ent.RootPart or not ent.Character or not ent.Character.Parent then return false end
		if ent.Health ~= nil and ent.Health <= 0 then return false end
		local head = getDrillHead(drill)
		if not head then return false end
		return (head.Position - ent.RootPart.Position).Magnitude <= AttackRange.Value + 4
	end

	local function getTargetNearDrill(drill)
		local head = getDrillHead(drill)
		if not head then return nil end

		if lockedEnt and targetStillGood(lockedEnt, drill) then
			return lockedEnt
		end

		if lockedEnt and tick() - lockedAt < 0.4 then
			return nil
		end

		local list = entitylib.AllPosition({
			Origin = head.Position,
			Range = AttackRange.Value,
			Wallcheck = Targets.Walls.Enabled or nil,
			Part = 'RootPart',
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Limit = 1,
			Sort = sortmethods['Distance']
		})
		local pick = list and list[1] or nil
		if pick then
			lockedEnt = pick
			lockedAt = tick()
		else
			lockedEnt = nil
		end
		return pick
	end

	local function mountDrill(drill)
		if not drillRemote then return false end
		if mountedDrill == drill then return true end
		local ok = pcall(function()
			drillRemote:InvokeServer({drill = drill})
		end)
		if ok then
			mountedDrill = drill
			if SilentMount and SilentMount.Enabled then
				releaseClientLock()
			end
		end
		return ok
	end

	local function unmountDrill()
		if not drillRemote or not mountedDrill then return end
		pcall(function() drillRemote:InvokeServer({}) end)
		mountedDrill = nil
	end

	local function startAutoAttack()
		if attackRunning then return end
		attackRunning = true
		task.spawn(function()
			while attackRunning and AutoDrill.Enabled and AutoAttack.Enabled do
				local acted = false

				if entitylib.isAlive and attackRemote and tick() - lastAttackTime >= AttackDelay.Value then
					for _, drill in getAllDrills() do
						if isOwnDrill(drill) and drill.Parent then
							local ent = getTargetNearDrill(drill)
							if ent and ent.RootPart then
								local aimPos = ent.RootPart.Position
								pcall(function() drillRemote:InvokeServer({drill = drill}) end)
								if SilentMount and SilentMount.Enabled then
									releaseClientLock()
								end
								pcall(function()
									attackRemote:FireServer({targetPosition = aimPos})
								end)
								pcall(function() drillRemote:InvokeServer({}) end)
								if SilentMount and SilentMount.Enabled then
									releaseClientLock()
								end
								mountedDrill = nil
								lastAttackTime = tick()
								acted = true
								break
							end
						end
					end
				end

				task.wait(acted and 0.05 or 0.15)
			end
			attackRunning = false
			unmountDrill()
		end)
	end

	AutoDrill = vape.Categories.Kits:CreateModule({
		Name = 'AutoDrill',
		Tooltip = 'esp for drills n makes ur drill shoot people by itself',
		Function = function(callback)
			if callback then
				if DrillESP.Enabled then
					setupESPConnections()
				end
				if AutoAttack.Enabled then
					startAutoAttack()
				end
			else
				attackRunning = false
				unmountDrill()
				disconnectESP()
			end
		end
	})

	DrillESP = AutoDrill:CreateToggle({
		Name = 'Drill ESP',
		Default = false,
		Function = function(callback)
			if TeamCheck and TeamCheck.Object then TeamCheck.Object.Visible = callback end
			if ShowOwn and ShowOwn.Object then ShowOwn.Object.Visible = callback end
			if Background and Background.Object then Background.Object.Visible = callback end
			if BackgroundColor and BackgroundColor.Object then
				BackgroundColor.Object.Visible = callback and Background.Enabled
			end
			if not AutoDrill.Enabled then return end
			if callback then
				setupESPConnections()
			else
				disconnectESP()
			end
		end
	})

	TeamCheck = AutoDrill:CreateToggle({
		Name = 'Team Check',
		Default = true,
		Darker = true,
		Visible = false,
		Tooltip = 'hides drills placed by ur teammates (esp only)',
		Function = function()
			if AutoDrill.Enabled and DrillESP.Enabled then refreshESP() end
		end
	})

	ShowOwn = AutoDrill:CreateToggle({
		Name = 'Show Own Drill',
		Default = true,
		Darker = true,
		Visible = false,
		Function = function()
			if AutoDrill.Enabled and DrillESP.Enabled then refreshESP() end
		end
	})

	Background = AutoDrill:CreateToggle({
		Name = 'Background',
		Default = true,
		Darker = true,
		Visible = false,
		Function = function(callback)
			if BackgroundColor and BackgroundColor.Object then
				BackgroundColor.Object.Visible = callback and DrillESP.Enabled
			end
			for _, ref in Reference do
				if ref.frame then
					ref.frame.BackgroundTransparency = 1 - (callback and (BackgroundColor.Opacity or 0.3) or 1)
				end
				if ref.billboard then
					local blur = ref.billboard:FindFirstChild('Blur')
					if blur then blur.Visible = callback end
				end
			end
		end
	})

	BackgroundColor = AutoDrill:CreateColorSlider({
		Name = 'Background Color',
		Darker = true,
		Visible = false,
		DefaultValue = 0,
		DefaultOpacity = 0.3,
		Function = function(hue, sat, val, opacity)
			for _, ref in Reference do
				if ref.frame then
					ref.frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					ref.frame.BackgroundTransparency = 1 - (Background.Enabled and opacity or 1)
				end
			end
		end
	})

	AutoAttack = AutoDrill:CreateToggle({
		Name = 'Auto Attack',
		Default = false,
		Function = function(callback)
			if Targets and Targets.Object then Targets.Object.Visible = callback end
			if AttackRange and AttackRange.Object then AttackRange.Object.Visible = callback end
			if AttackDelay and AttackDelay.Object then AttackDelay.Object.Visible = callback end
			if SilentMount and SilentMount.Object then SilentMount.Object.Visible = callback end
			if callback then
				if AutoDrill.Enabled then startAutoAttack() end
			else
				attackRunning = false
				unmountDrill()
			end
		end
	})

	Targets = AutoDrill:CreateTargets({
		Players = true,
		NPCs = true
	})

	AttackRange = AutoDrill:CreateSlider({
		Name = 'Attack Range',
		Min = 5,
		Max = 18,
		Default = 16,
		Darker = true,
		Visible = false,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end
	})

	AttackDelay = AutoDrill:CreateSlider({
		Name = 'Attack Delay',
		Min = 0.1,
		Max = 2,
		Default = 0.3,
		Decimal = 100,
		Suffix = 's',
		Darker = true,
		Visible = false
	})

	SilentMount = AutoDrill:CreateToggle({
		Name = 'Silent Mount',
		Default = true,
		Darker = true,
		Visible = false,
		Tooltip = 'tries to keep u movin while da drill shoots'
	})

	task.defer(function()
		local espOn = DrillESP.Enabled
		local atkOn = AutoAttack.Enabled
		if TeamCheck.Object then TeamCheck.Object.Visible = espOn end
		if ShowOwn.Object then ShowOwn.Object.Visible = espOn end
		if Background.Object then Background.Object.Visible = espOn end
		if BackgroundColor.Object then BackgroundColor.Object.Visible = espOn and Background.Enabled end
		if Targets.Object then Targets.Object.Visible = atkOn end
		if AttackRange.Object then AttackRange.Object.Visible = atkOn end
		if AttackDelay.Object then AttackDelay.Object.Visible = atkOn end
		if SilentMount.Object then SilentMount.Object.Visible = atkOn end
	end)
end)
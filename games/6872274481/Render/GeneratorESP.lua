run(function()
	local GeneratorESP
	DiamondToggle = nil
	EmeraldToggle = nil
	TeamGenToggle = nil
	ShowOwnTeamGen = nil
	ShowEnemyTeamGen = nil
	local UIStyle
	local CompactDiamondToggle
	local CompactEmeraldToggle
	local CollectionService = collectionService
	local RunService = runService
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local CompactFolder = Instance.new('Folder')
	CompactFolder.Parent = vape.gui
	local teamColors = getgenv().aeroTeamColors

	local generatorTypes = {
		diamond = {
			keywords = {'diamond'},
			color = Color3.fromRGB(85, 200, 255),
			icon = 'diamond',
			displayName = 'Diamond',
			isTeamGen = false
		},
		emerald = {
			keywords = {'emerald'},
			color = Color3.fromRGB(0, 255, 100),
			icon = 'emerald',
			displayName = 'Emerald',
			isTeamGen = false
		}
	}

	local compactUI = Instance.new('ScreenGui')
	compactUI.Name = 'GeneratorCompactUI'
	compactUI.Parent = vape.gui
	compactUI.Enabled = false
	compactUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	compactUI.DisplayOrder = 10
	compactUI.ResetOnSpawn = false

	local mainFrame = Instance.new('Frame')
	mainFrame.Name = 'MainFrame'
	mainFrame.Parent = compactUI
	mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	mainFrame.BackgroundTransparency = 0.3
	mainFrame.BorderSizePixel = 0
	mainFrame.Position = UDim2.new(1, -8, 1, -8)
	mainFrame.Size = UDim2.new(0, 120, 0, 100)
	mainFrame.AnchorPoint = Vector2.new(1, 1)

	local uicorner = Instance.new('UICorner')
	uicorner.CornerRadius = UDim.new(0, 8)
	uicorner.Parent = mainFrame

	local title = Instance.new('TextLabel')
	title.Name = 'Title'
	title.Parent = mainFrame
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 25)
	title.Position = UDim2.new(0, 0, 0, 5)
	title.Text = "GEN ESP"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 14
	title.Font = Enum.Font.GothamBold
	title.TextStrokeTransparency = 0.5
	title.TextStrokeColor3 = Color3.new(0, 0, 0)

	local diamondFrame = Instance.new('Frame')
	diamondFrame.Name = 'DiamondFrame'
	diamondFrame.Parent = mainFrame
	diamondFrame.BackgroundTransparency = 1
	diamondFrame.Size = UDim2.new(1, -20, 0, 25)
	diamondFrame.Position = UDim2.new(0, 10, 0, 35)

	local diamondIcon = Instance.new('ImageLabel')
	diamondIcon.Name = 'DiamondIcon'
	diamondIcon.Parent = diamondFrame
	diamondIcon.BackgroundTransparency = 1
	diamondIcon.Size = UDim2.new(0, 18, 0, 18)
	diamondIcon.Position = UDim2.new(0, 0, 0.5, -9)
	diamondIcon.Image = bedwars.getIcon({itemType = 'diamond'}, true)

	local diamondTimer = Instance.new('TextLabel')
	diamondTimer.Name = 'DiamondTimer'
	diamondTimer.Parent = diamondFrame
	diamondTimer.BackgroundTransparency = 1
	diamondTimer.Size = UDim2.new(1, -25, 1, 0)
	diamondTimer.Position = UDim2.new(0, 25, 0, 0)
	diamondTimer.Text = "00"
	diamondTimer.TextColor3 = Color3.fromRGB(85, 200, 255)
	diamondTimer.TextSize = 18
	diamondTimer.Font = Enum.Font.GothamBold
	diamondTimer.TextXAlignment = Enum.TextXAlignment.Left

	local emeraldFrame = Instance.new('Frame')
	emeraldFrame.Name = 'EmeraldFrame'
	emeraldFrame.Parent = mainFrame
	emeraldFrame.BackgroundTransparency = 1
	emeraldFrame.Size = UDim2.new(1, -20, 0, 25)
	emeraldFrame.Position = UDim2.new(0, 10, 0, 65)

	local emeraldIcon = Instance.new('ImageLabel')
	emeraldIcon.Name = 'EmeraldIcon'
	emeraldIcon.Parent = emeraldFrame
	emeraldIcon.BackgroundTransparency = 1
	emeraldIcon.Size = UDim2.new(0, 18, 0, 18)
	emeraldIcon.Position = UDim2.new(0, 0, 0.5, -9)
	emeraldIcon.Image = bedwars.getIcon({itemType = 'emerald'}, true)

	local emeraldTimer = Instance.new('TextLabel')
	emeraldTimer.Name = 'EmeraldTimer'
	emeraldTimer.Parent = emeraldFrame
	emeraldTimer.BackgroundTransparency = 1
	emeraldTimer.Size = UDim2.new(1, -25, 1, 0)
	emeraldTimer.Position = UDim2.new(0, 25, 0, 0)
	emeraldTimer.Text = "00"
	emeraldTimer.TextColor3 = Color3.fromRGB(0, 255, 100)
	emeraldTimer.TextSize = 18
	emeraldTimer.Font = Enum.Font.GothamBold
	emeraldTimer.TextXAlignment = Enum.TextXAlignment.Left

	local diamondTimes = {}
	local emeraldTimes = {}

	local function getMyTeamId()
		local myTeam = lplr:GetAttribute('Team')
		if myTeam == nil then return nil end
		return tonumber(myTeam)
	end

	local function getGeneratorTeamId(generatorId)
		local teamNum = string.match(generatorId, "^(%d+)_generator")
		if teamNum then
			return tonumber(teamNum)
		end
		return nil
	end

	local function isTeamGenerator(generatorId)
		return string.match(generatorId, "^%d+_generator") ~= nil
	end

	local function getGeneratorType(generatorId)
		local idLower = string.lower(generatorId)

		if isTeamGenerator(generatorId) then
			return 'teamgen', {
				color = Color3.fromRGB(200, 200, 200),
				icon = 'iron',
				displayName = 'Team Gen',
				isTeamGen = true
			}
		end

		for genType, config in pairs(generatorTypes) do
			for _, keyword in ipairs(config.keywords) do
				if idLower:find(keyword) then
					return genType, config
				end
			end
		end
		return nil, nil
	end

	local function isGeneratorEnabled(genType, teamId)
		if genType == 'diamond' then
			return DiamondToggle.Enabled
		elseif genType == 'emerald' then
			return EmeraldToggle.Enabled
		elseif genType == 'teamgen' then
			if not TeamGenToggle.Enabled then return false end
			local myTeamId = getMyTeamId()
			if not myTeamId or not teamId then return TeamGenToggle.Enabled end
			if teamId == myTeamId then
				return ShowOwnTeamGen.Enabled
			else
				return ShowEnemyTeamGen.Enabled
			end
		end
		return false
	end

	local function getProperIcon(iconType)
		local icon = bedwars.getIcon({itemType = iconType}, true)
		if not icon or icon == "" then return nil end
		return icon
	end

	local function getTierText(generatorAdornee)
		if not generatorAdornee then return nil end
		if generatorAdornee.Name ~= 'GeneratorAdornee' then return nil end
		local reactTree = generatorAdornee:FindFirstChild('RoactTree')
		if not reactTree then return nil end
		local teamApp = reactTree:FindFirstChild('TeamOreGeneratorApp')
		if not teamApp then return nil end
		local globalGen = teamApp:FindFirstChild('GlobalOreGenerator')
		if globalGen then
			for _, child in pairs(globalGen:GetDescendants()) do
				if child:IsA('TextLabel') then
					local text = child.Text
					if text:find("Tier") or text:match("^[IVX]+$") or text == "0" then
						return child
					end
				end
			end
		end
		local teamGenMain = teamApp:FindFirstChild('TeamGenMain')
		if teamGenMain then
			for _, child in pairs(teamGenMain:GetDescendants()) do
				if child:IsA('TextLabel') then
					local text = child.Text
					if text:find("Tier") or text:match("^[IVX]+$") or text == "0" then
						return child
					end
				end
			end
		end
		return nil
	end

	local function extractTierLevel(tierText)
		if not tierText or tierText == "" then return "0" end
		if tierText == "0" then return "0" end
		local tierMatch = tierText:match("Tier%s+([IVX]+)")
		if tierMatch then return tierMatch end
		if tierText:match("^[IVX]+$") then return tierText end
		local numTier = tierText:match("Tier%s+(%d+)")
		if numTier then
			local num = tonumber(numTier)
			if num == 0 then return "0"
			elseif num == 1 then return "I"
			elseif num == 2 then return "II"
			elseif num == 3 then return "III"
			end
		end
		return "0"
	end

	local function getCountdownText(generatorAdornee)
		if not generatorAdornee then return nil end
		if generatorAdornee.Name ~= 'GeneratorAdornee' then return nil end
		local reactTree = generatorAdornee:FindFirstChild('RoactTree')
		if not reactTree then return nil end
		local teamApp = reactTree:FindFirstChild('TeamOreGeneratorApp')
		if not teamApp then return nil end
		local globalGen = teamApp:FindFirstChild('GlobalOreGenerator')
		if not globalGen then return nil end
		local countdown = globalGen:FindFirstChild('Countdown')
		if not countdown then return nil end
		local textLabel = countdown:FindFirstChild('Text')
		if not textLabel then
			if countdown:IsA('TextLabel') then return countdown end
			return nil
		end
		return textLabel
	end

	local function extractSecondsFromText(text)
		if not text or text == "" then return 0 end
		local seconds = text:match("%[(%d+)%]")
		if seconds then return tonumber(seconds) or 0 end
		local justNumber = text:match("(%d+)")
		if justNumber then return tonumber(justNumber) or 0 end
		return 0
	end

	local function getResourceCount(position, resourceType)
		local count = 0
		for _, drop in pairs(CollectionService:GetTagged('ItemDrop')) do
			if drop:FindFirstChild('Handle') then
				local dropName = drop.Name:lower()
				if dropName:find(resourceType) then
					local dist = (drop.Handle.Position - position).Magnitude
					if dist <= 10 then
						local amount = drop:GetAttribute('Amount') or 1
						count = count + amount
					end
				end
			end
		end
		return count
	end

	local CompactGenerators = {}

	local function rebuildCompactGenerators()
		table.clear(CompactGenerators)
		scanDescendants(workspace, function(obj)
			if obj.Name == 'GeneratorAdornee' then
				local ok, generatorId = pcall(function() return obj:GetAttribute('Id') end)
				if ok and generatorId and type(generatorId) == 'string' and generatorId ~= '' then
					local genType = getGeneratorType(generatorId)
					if genType == 'diamond' or genType == 'emerald' then
						table.insert(CompactGenerators, {obj = obj, genType = genType})
					end
				end
			end
		end)
	end

	local function updateCompactUI()
		if not GeneratorESP.Enabled or UIStyle.Value ~= 'Compact' then
			compactUI.Enabled = false
			return
		end
		compactUI.Enabled = true
		local bestDiamondTime = math.huge
		local bestEmeraldTime = math.huge
		for i = #CompactGenerators, 1, -1 do
			local entry = CompactGenerators[i]
			if not entry.obj or not entry.obj.Parent then
				table.remove(CompactGenerators, i)
				continue
			end
			local countdownText = getCountdownText(entry.obj)
			if countdownText and countdownText.Text then
				local timeLeft = extractSecondsFromText(countdownText.Text)
				if entry.genType == 'diamond' and timeLeft > 0 and timeLeft < bestDiamondTime then
					bestDiamondTime = timeLeft
				elseif entry.genType == 'emerald' and timeLeft > 0 and timeLeft < bestEmeraldTime then
					bestEmeraldTime = timeLeft
				end
			end
		end
		local showDiamond = CompactDiamondToggle and CompactDiamondToggle.Enabled
		local showEmerald = CompactEmeraldToggle and CompactEmeraldToggle.Enabled

		if not showDiamond and not showEmerald then
			compactUI.Enabled = false
			return
		end

		diamondFrame.Visible = showDiamond
		emeraldFrame.Visible = showEmerald

		if showDiamond then
			diamondFrame.Position = UDim2.new(0, 10, 0, 35)
		end
		if showEmerald then
			emeraldFrame.Position = UDim2.new(0, 10, 0, showDiamond and 65 or 35)
		end

		diamondTimes[1] = bestDiamondTime ~= math.huge and bestDiamondTime or 0
		emeraldTimes[1] = bestEmeraldTime ~= math.huge and bestEmeraldTime or 0
		if bestDiamondTime == math.huge then
			diamondTimer.Text = "00"
		else
			diamondTimer.Text = string.format("%02d", bestDiamondTime)
			if bestDiamondTime <= 5 then
				diamondTimer.TextColor3 = Color3.fromRGB(255, 50, 50)
			elseif bestDiamondTime <= 10 then
				diamondTimer.TextColor3 = Color3.fromRGB(255, 165, 0)
			else
				diamondTimer.TextColor3 = Color3.fromRGB(85, 200, 255)
			end
		end
		if bestEmeraldTime == math.huge then
			emeraldTimer.Text = "00"
		else
			emeraldTimer.Text = string.format("%02d", bestEmeraldTime)
			if bestEmeraldTime <= 5 then
				emeraldTimer.TextColor3 = Color3.fromRGB(255, 50, 50)
			elseif bestEmeraldTime <= 10 then
				emeraldTimer.TextColor3 = Color3.fromRGB(255, 165, 0)
			else
				emeraldTimer.TextColor3 = Color3.fromRGB(0, 255, 100)
			end
		end
	end

	local function clearAllESP()
		Folder:ClearAllChildren()
		table.clear(Reference)
		compactUI.Enabled = false
	end

	local function createESP(generatorAdornee, genType, config, position, teamId)
		if not isGeneratorEnabled(genType, teamId) then return end
		if Reference[generatorAdornee] then return end

		if UIStyle.Value == 'Compact' then
			Reference[generatorAdornee] = {
				genType = genType,
				position = position,
				teamId = teamId,
				isTeamGen = config.isTeamGen
			}
			return
		end
		if not generatorAdornee or not generatorAdornee.Parent then return end

		local displayColor = config.color
		local teamName = nil
		if config.isTeamGen and teamId and teamColors[teamId] then
			displayColor = teamColors[teamId].color
			teamName = teamColors[teamId].name
		end

		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'generator-esp-' .. genType
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = generatorAdornee
		billboard.Enabled = true  

		if config.isTeamGen then
			billboard.Size = UDim2.fromOffset(180, 55)
			billboard.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
		else
			billboard.Size = UDim2.fromOffset(80, 30)
			billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		end

		local blur = pcall(function()
			return addBlur(billboard)
		end) and blur or nil
		if blur then
			blur.Visible = true
		end

		if config.isTeamGen and teamName then
			local dot = Instance.new('Frame')
			dot.Name = 'TeamDot'
			dot.Parent = billboard
			dot.Size = UDim2.fromOffset(8, 8)
			dot.Position = UDim2.new(0, 10, 0, 5)
			dot.BackgroundColor3 = displayColor
			dot.BorderSizePixel = 0
			local dotCorner = Instance.new('UICorner')
			dotCorner.CornerRadius = UDim.new(1, 0)
			dotCorner.Parent = dot

			local teamLabel = Instance.new('TextLabel')
			teamLabel.Name = 'TeamLabel'
			teamLabel.Parent = billboard
			teamLabel.BackgroundTransparency = 1
			teamLabel.Size = UDim2.new(1, 0, 0, 18)
			teamLabel.Position = UDim2.new(0, 0, 0, 0)
			teamLabel.Text = teamName
			teamLabel.TextColor3 = displayColor
			teamLabel.TextSize = 13
			teamLabel.Font = Enum.Font.GothamBold
			teamLabel.TextStrokeTransparency = 0.4
			teamLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			teamLabel.TextXAlignment = Enum.TextXAlignment.Center
		end

		local frame = Instance.new('Frame')
		frame.Size = config.isTeamGen and UDim2.new(1, 0, 0, 35) or UDim2.fromScale(1, 1)
		frame.Position = config.isTeamGen and UDim2.new(0, 0, 0, 20) or UDim2.new(0, 0, 0, 0)
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BackgroundTransparency = 0.3
		frame.BorderSizePixel = 0
		frame.Parent = billboard

		if config.isTeamGen and teamId and teamColors[teamId] then
			local stripe = Instance.new('Frame')
			stripe.Name = 'TeamStripe'
			stripe.Parent = frame
			stripe.Size = UDim2.new(0, 3, 1, 0)
			stripe.Position = UDim2.new(0, 0, 0, 0)
			stripe.BackgroundColor3 = displayColor
			stripe.BorderSizePixel = 0
			local stripeCorner = Instance.new('UICorner')
			stripeCorner.CornerRadius = UDim.new(0, 3)
			stripeCorner.Parent = stripe
		end

		local uicorner2 = Instance.new('UICorner')
		uicorner2.CornerRadius = UDim.new(0, 6)
		uicorner2.Parent = frame

		if config.isTeamGen then
			local tierLabel = Instance.new('TextLabel')
			tierLabel.Name = 'Tier'
			tierLabel.Size = UDim2.new(0, 25, 1, 0)
			tierLabel.Position = UDim2.new(0, 8, 0, 0)
			tierLabel.BackgroundTransparency = 1
			tierLabel.Text = "0"
			tierLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
			tierLabel.TextSize = 16
			tierLabel.Font = Enum.Font.GothamBold
			tierLabel.TextStrokeTransparency = 0.5
			tierLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			tierLabel.Parent = frame

			local resources = {
				{name = 'iron',    color = Color3.fromRGB(200, 200, 200), icon = 'iron',    xOffset = 35},
				{name = 'diamond', color = Color3.fromRGB(85, 200, 255),  icon = 'diamond', xOffset = 85},
				{name = 'emerald', color = Color3.fromRGB(0, 255, 100),   icon = 'emerald', xOffset = 135}
			}

			local resourceLabels = {}
			for _, resource in ipairs(resources) do
				local iconImage = getProperIcon(resource.icon)
				if iconImage then
					local image = Instance.new('ImageLabel')
					image.Size = UDim2.fromOffset(18, 18)
					image.Position = UDim2.new(0, resource.xOffset, 0.5, 0)
					image.AnchorPoint = Vector2.new(0, 0.5)
					image.BackgroundTransparency = 1
					image.Image = iconImage
					image.Parent = frame
				end
				local countLabel = Instance.new('TextLabel')
				countLabel.Name = resource.name .. '_count'
				countLabel.Size = UDim2.new(0, 25, 1, 0)
				countLabel.Position = UDim2.new(0, resource.xOffset + 20, 0, 0)
				countLabel.BackgroundTransparency = 1
				countLabel.Text = "0"
				countLabel.TextColor3 = resource.color
				countLabel.TextSize = 16
				countLabel.Font = Enum.Font.GothamBold
				countLabel.TextStrokeTransparency = 0.5
				countLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
				countLabel.TextXAlignment = Enum.TextXAlignment.Left
				countLabel.Parent = frame
				resourceLabels[resource.name] = countLabel
			end

			Reference[generatorAdornee] = {
				billboard = billboard,
				tierLabel = tierLabel,
				ironLabel = resourceLabels.iron,
				diamondLabel = resourceLabels.diamond,
				emeraldLabel = resourceLabels.emerald,
				genType = genType,
				position = position,
				teamId = teamId,
				isTeamGen = true
			}
		else
			local iconImage = getProperIcon(config.icon)
			if iconImage then
				local image = Instance.new('ImageLabel')
				image.Size = UDim2.fromOffset(20, 20)
				image.Position = UDim2.new(0, 5, 0.5, 0)
				image.AnchorPoint = Vector2.new(0, 0.5)
				image.BackgroundTransparency = 1
				image.Image = iconImage
				image.Parent = frame
			end
			local timerLabel = Instance.new('TextLabel')
			timerLabel.Name = 'Timer'
			timerLabel.Size = UDim2.new(0, 30, 1, 0)
			timerLabel.Position = UDim2.new(0.5, 0, 0, 0)
			timerLabel.AnchorPoint = Vector2.new(0.5, 0)
			timerLabel.BackgroundTransparency = 1
			timerLabel.Text = "00"
			timerLabel.TextColor3 = displayColor
			timerLabel.TextSize = 18
			timerLabel.Font = Enum.Font.GothamBold
			timerLabel.TextStrokeTransparency = 0.5
			timerLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			timerLabel.Parent = frame
			local amountLabel = Instance.new('TextLabel')
			amountLabel.Name = 'Amount'
			amountLabel.Size = UDim2.new(0, 20, 1, 0)
			amountLabel.Position = UDim2.new(1, -20, 0, 0)
			amountLabel.BackgroundTransparency = 1
			amountLabel.Text = "0"
			amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			amountLabel.TextSize = 16
			amountLabel.Font = Enum.Font.GothamBold
			amountLabel.TextStrokeTransparency = 0.5
			amountLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			amountLabel.Parent = frame
			Reference[generatorAdornee] = {
				billboard = billboard,
				timerLabel = timerLabel,
				amountLabel = amountLabel,
				genType = genType,
				position = position,
				teamId = teamId,
				isTeamGen = false
			}
		end
		billboard.Enabled = true
	end

	local function updateESP(generatorAdornee)
		local ref = Reference[generatorAdornee]
		if not ref then return end
		if UIStyle.Value == 'Compact' then return end

		if ref.isTeamGen then
			if ref.tierLabel then
				local tierTextLabel = getTierText(generatorAdornee)
				if tierTextLabel and tierTextLabel.Text then
					ref.tierLabel.Text = extractTierLevel(tierTextLabel.Text)
				else
					ref.tierLabel.Text = "0"
				end
			end
			if ref.ironLabel then
				ref.ironLabel.Text = tostring(getResourceCount(ref.position, 'iron'))
			end
			if ref.diamondLabel then
				ref.diamondLabel.Text = tostring(getResourceCount(ref.position, 'diamond'))
			end
			if ref.emeraldLabel then
				ref.emeraldLabel.Text = tostring(getResourceCount(ref.position, 'emerald'))
			end
		else
			local countdownText = getCountdownText(generatorAdornee)
			if countdownText and countdownText.Text then
				local timeLeft = extractSecondsFromText(countdownText.Text)
				if ref.timerLabel then
					ref.timerLabel.Text = string.format("%02d", timeLeft)
					if timeLeft <= 5 then
						ref.timerLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
					elseif timeLeft <= 10 then
						ref.timerLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
					else
						ref.timerLabel.TextColor3 = generatorTypes[ref.genType].color
					end
				end
			else
				if ref.timerLabel then
					ref.timerLabel.Text = "00"
					ref.timerLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
				end
			end
			if ref.amountLabel then
				ref.amountLabel.Text = tostring(getResourceCount(ref.position, ref.genType))
			end
		end
	end

	local function processGeneratorAdornee(obj)
		if obj.Name ~= 'GeneratorAdornee' then return end
		local ok, generatorId = pcall(function() return obj:GetAttribute('Id') end)
		if not ok then return end
		if generatorId == nil then return end
		if type(generatorId) ~= 'string' then return end
		if generatorId == '' then return end

		local position = obj:GetPivot().Position
		local genType, config = getGeneratorType(generatorId)
		if not genType or not config then return end

		local teamId = getGeneratorTeamId(generatorId)
		if isGeneratorEnabled(genType, teamId) then
			createESP(obj, genType, config, position, teamId)
		end
	end

	local function findAllGenerators()
		scanDescendants(workspace, function(obj)
			pcall(processGeneratorAdornee, obj)
		end)
	end

	local function refreshESP()
		clearAllESP()
		if GeneratorESP.Enabled then
			findAllGenerators()
		end
	end

	local updateTimer = 0

	GeneratorESP = vape.Categories.Render:CreateModule({
		Name = 'GeneratorESP',
		Function = function(callback)
			if callback then
				findAllGenerators()
				rebuildCompactGenerators()

				GeneratorESP:Clean(workspace.DescendantAdded:Connect(function(obj)
					if not GeneratorESP.Enabled or obj.Name ~= 'GeneratorAdornee' then return end
					task.wait(0.2)
					if not GeneratorESP.Enabled or not obj.Parent then return end
					pcall(processGeneratorAdornee, obj)
					rebuildCompactGenerators()
				end))

				GeneratorESP:Clean(runService.Heartbeat:Connect(function(dt)
					if not GeneratorESP.Enabled then return end
					updateTimer = updateTimer + dt
					if updateTimer < 0.2 then return end
					updateTimer = 0
					for generatorAdornee, ref in pairs(Reference) do
						if generatorAdornee and generatorAdornee.Parent then
							updateESP(generatorAdornee)
						else
							if ref.billboard then ref.billboard:Destroy() end
							Reference[generatorAdornee] = nil
						end
					end
					updateCompactUI()
				end))

				GeneratorESP:Clean(workspace.DescendantRemoving:Connect(function(obj)
					if not GeneratorESP.Enabled then return end
					if Reference[obj] then
						if Reference[obj].billboard then Reference[obj].billboard:Destroy() end
						Reference[obj] = nil
					end
				end))
			else
				clearAllESP()
			end
		end,
		Tooltip = 'esp for generators showing timer and items count'
	})

	UIStyle = GeneratorESP:CreateDropdown({
		Name = 'UI Style',
		List = {'Original', 'Compact'},
		Default = 'Original',
		Function = function(val)
			local isOriginal = val == 'Original'
			if DiamondToggle then DiamondToggle.Object.Visible = isOriginal end
			if EmeraldToggle then EmeraldToggle.Object.Visible = isOriginal end
			if TeamGenToggle then TeamGenToggle.Object.Visible = isOriginal end
			if ShowOwnTeamGen then ShowOwnTeamGen.Object.Visible = isOriginal and TeamGenToggle.Enabled end
			if ShowEnemyTeamGen then ShowEnemyTeamGen.Object.Visible = isOriginal and TeamGenToggle.Enabled end
			if CompactDiamondToggle then CompactDiamondToggle.Object.Visible = not isOriginal end
			if CompactEmeraldToggle then CompactEmeraldToggle.Object.Visible = not isOriginal end
			refreshESP()
		end,
		Tooltip = 'pick between the norm billboard esp on generators or a ui with timers for generators '
	})

	DiamondToggle = GeneratorESP:CreateToggle({
		Name = 'Diamond',
		Function = function() refreshESP() end,
		Default = false,
		Visible = true
	})

	EmeraldToggle = GeneratorESP:CreateToggle({
		Name = 'Emerald',
		Function = function() refreshESP() end,
		Default = false,
		Visible = true
	})

	CompactDiamondToggle = GeneratorESP:CreateToggle({
		Name = 'Compact Diamond',
		Default = false,
		Visible = false,
		Function = function()
			refreshESP()
		end
	})

	CompactEmeraldToggle = GeneratorESP:CreateToggle({
		Name = 'Compact Emerald',
		Default = false,
		Visible = false,
		Function = function()
			refreshESP()
		end
	})

	TeamGenToggle = GeneratorESP:CreateToggle({
		Name = 'Team Generators',
		Function = function(callback)
			if ShowOwnTeamGen then ShowOwnTeamGen.Object.Visible = callback end
			if ShowEnemyTeamGen then ShowEnemyTeamGen.Object.Visible = callback end
			refreshESP()
		end,
		Default = true
	})

	ShowOwnTeamGen = GeneratorESP:CreateToggle({
		Name = 'Show Own Team',
		Function = function() refreshESP() end,
		Default = false,
		Visible = true
	})

	ShowEnemyTeamGen = GeneratorESP:CreateToggle({
		Name = 'Show Enemy Teams',
		Function = function() refreshESP() end,
		Default = true,
		Visible = true
	})
end)
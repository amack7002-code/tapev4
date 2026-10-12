run(function()
    local BedPlates
    local Background
    local TeamColor
    local Color = {}
    local Reference = {}
    local BlockCache = {}
	local LayerCounter
	local LayerColor
	local UIStyle
	local PositionDropdown
	local IgnoreTeam
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local compactUI = Instance.new('ScreenGui')
    compactUI.Name = 'BedPlatesCompactUI'
    compactUI.Parent = vape.gui
    compactUI.Enabled = false
    compactUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    compactUI.DisplayOrder = 10
    compactUI.ResetOnSpawn = false
    local compactMainFrame = Instance.new('Frame')
    compactMainFrame.Name = 'MainFrame'
    compactMainFrame.Parent = compactUI
    compactMainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    compactMainFrame.BackgroundTransparency = 0.3
    compactMainFrame.BorderSizePixel = 0
    compactMainFrame.Position = UDim2.new(1, -8, 1, -8)
    compactMainFrame.Size = UDim2.new(0, 150, 0, 0)
    compactMainFrame.AutomaticSize = Enum.AutomaticSize.Y
    compactMainFrame.AnchorPoint = Vector2.new(1, 1)
    local compactCorner = Instance.new('UICorner')
    compactCorner.CornerRadius = UDim.new(0, 8)
    compactCorner.Parent = compactMainFrame
    local compactListLayout = Instance.new('UIListLayout')
    compactListLayout.Padding = UDim.new(0, 4)
    compactListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    compactListLayout.Parent = compactMainFrame
    local compactPadding = Instance.new('UIPadding')
    compactPadding.PaddingTop = UDim.new(0, 6)
    compactPadding.PaddingBottom = UDim.new(0, 6)
    compactPadding.PaddingLeft = UDim.new(0, 6)
    compactPadding.PaddingRight = UDim.new(0, 6)
    compactPadding.Parent = compactMainFrame
    
	local teamColors = getgenv().aeroTeamColors
    
    local function getBedTeamColor(bed)
        local teamId = bed:GetAttribute('TeamID') or bed:GetAttribute('Team') or bed:GetAttribute('TeamId')
        teamId = tonumber(teamId)
        if teamId and teamColors[teamId] then
            return teamColors[teamId]
        end
        return {name = 'Enemy', color = Color3.new(1, 1, 1)}
    end
    
    local function isMyBed(bed)
        local myTeam = lplr.Character and (lplr.Character:GetAttribute('Team') or lplr.Character:GetAttribute('TeamId'))
        local bedTeam = bed:GetAttribute('TeamID') or bed:GetAttribute('Team') or bed:GetAttribute('TeamId')
        if not myTeam or not bedTeam then return false end
        return tonumber(myTeam) == tonumber(bedTeam)
    end
    
	local function updateLayerTextColor()
		for _, ref in pairs(Reference) do
			for _, img in ref.billboard.Frame:GetChildren() do
				if img:IsA('ImageLabel') then
					local txt = img:FindFirstChild('Amount')
					if txt then
						txt.TextColor3 = LayerColor and Color3.fromHSV(LayerColor.Hue, LayerColor.Sat, LayerColor.Value) or Color3.fromRGB(250,250,250)
					end
				end
			end
		end
	end

	local layerDirs = {
		Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
		Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
		Vector3.new(0, 1, 0),
	}

	local function getBedCells(bed)
		local ok, cells = pcall(function()
			local handler = bedwars.BlockController:getHandlerRegistry():getHandler(bed.Name)
			return handler and handler:getContainedPositions(bed)
		end)
		if ok and type(cells) == 'table' and #cells > 0 then
			return cells
		end
		local start = bedwars.BlockController:getBlockPosition(bed.Position)
		return {start, start + Vector3.new(0, 0, 1)}
	end
    
    local BedTotals = {}

	local function getBedLayers(bed)
		local store = bedwars.BlockController:getStore()
		local seen, frontier, layerList = {}, {}, {}
		for _, cell in getBedCells(bed) do
			seen[cell] = true
			table.insert(frontier, cell)
		end
		local emptyRings = 0
		for _ = 1, 8 do
			local nextFrontier, total, filled, counts = {}, 0, 0, {}
			for _, cell in frontier do
				for _, dir in layerDirs do
					local n = cell + dir
					if not seen[n] then
						seen[n] = true
						table.insert(nextFrontier, n)
						total += 1
						local blk = store:getBlockAt(n)
						if blk then
							filled += 1
							if blk.Name ~= 'bed' and not blk:GetAttribute('NoBreak') then
								counts[blk.Name] = (counts[blk.Name] or 0) + 1
							end
						end
					end
				end
			end
			frontier = nextFrontier
			if filled == 0 then
				emptyRings += 1
				if emptyRings >= 2 then break end
			else
				emptyRings = 0
				if filled == total then
					local best, bestCount = nil, 0
					for name, count in counts do
						if count > bestCount then
							best, bestCount = name, count
						end
					end
					if best then
						table.insert(layerList, best)
					end
				end
			end
		end
		local founded = {}
		for i = #layerList, 1, -1 do
			local last = founded[#founded]
			if last and last[1] == layerList[i] then
				last[2] += 1
			else
				table.insert(founded, {layerList[i], 1})
			end
		end
		return founded, #layerList
	end

    local function renderLayers(frame, founded)
		for _, obj in frame:GetChildren() do
			if obj and (obj:IsA("ImageLabel") and obj.Name ~= 'Blur') then
				obj:Destroy()
			end
		end
		for i, data in founded do
			local block, amt = data[1], data[2]
			local image = Instance.new('ImageLabel')
			image.LayoutOrder = i
			image.Size = UDim2.fromOffset(32,32)
			image.BackgroundTransparency = 1
			image.Image = bedwars.getIcon({itemType=block}, true)
			image.Parent = frame
			if amt >= 2 and (not LayerCounter or LayerCounter.Enabled) then
				local txt = Instance.new('TextLabel')
				txt.Name = 'Amount'
				txt.Size = UDim2.fromScale(1,1)
				txt.BackgroundTransparency = 1
				local newamt = amt
				txt.Text = tostring(newamt)
				txt.TextColor3 = LayerColor and Color3.fromHSV(LayerColor.Hue, LayerColor.Sat, LayerColor.Value) or Color3.fromRGB(250,250,250)
				txt.TextSize = 24
				txt.TextStrokeTransparency = 0.3
				txt.Font = Enum.Font.Arial
				txt.Parent = image
			end
		end
    end

    local function refreshAdornee(v)
		local bed = v.Adornee
		local founded, total = getBedLayers(bed)
		BedTotals[bed] = total
		local sig = (LayerCounter and LayerCounter.Enabled) and '1' or '0'
		for _, data in founded do
			sig ..= data[1] .. data[2] .. ','
		end
		local changed = BlockCache[bed] ~= sig
		BlockCache[bed] = sig
		local mine = isMyBed(bed)
		v.Enabled = #founded > 0 and UIStyle.Value == 'Original' and not mine
		if changed then
			renderLayers(v.Frame, founded)
		end
		if Reference[bed] and Reference[bed].compactRow then
			if changed then
				renderLayers(Reference[bed].compactRow.iconsFrame, founded)
			end
			Reference[bed].compactRow.countLabel.Text = tostring(total)
			Reference[bed].compactRow.frame.Visible = #founded > 0 and not (mine and IgnoreTeam and IgnoreTeam.Enabled)
		end
    end
    
    local function Added(v)
        if Reference[v] then return end
        local _bpUserId = v:GetAttribute('PlacedByUserId')
        if _bpUserId then
            local _bpOk, _bpOwner = pcall(function() return playersService:GetPlayerByUserId(_bpUserId) end)
        end
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = 'bed'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
        billboard.Size = UDim2.fromOffset(36, TeamColor.Enabled and 50 or 36)
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = v
        billboard.Enabled = UIStyle.Value == 'Original'
        
        local blur = addBlur(billboard)
        blur.Visible = Background.Enabled
        
        local frame = Instance.new('Frame')
        frame.Size = TeamColor.Enabled and UDim2.new(1, 0, 1, -16) or UDim2.fromScale(1, 1)
        frame.Position = TeamColor.Enabled and UDim2.new(0, 0, 0, 16) or UDim2.new(0, 0, 0, 0)
        frame.BackgroundColor3 = TeamColor.Enabled and getBedTeamColor(v).color or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
        frame.BackgroundTransparency = 1 - (Background.Enabled and (TeamColor.Enabled and 0.5 or Color.Opacity) or 0)
        frame.Parent = billboard

        local teamLabel = Instance.new('TextLabel')
        teamLabel.Name = 'TeamLabel'
        teamLabel.Size = UDim2.new(1, 0, 0, 14)
        teamLabel.Position = UDim2.new(0, 0, 0, 0)
        teamLabel.BackgroundTransparency = 1
        teamLabel.Text = getBedTeamColor(v).name
        teamLabel.TextColor3 = getBedTeamColor(v).color
        teamLabel.TextSize = 13
        teamLabel.Font = Enum.Font.GothamBold
        teamLabel.TextStrokeTransparency = 0.4
        teamLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        teamLabel.Visible = TeamColor.Enabled
        teamLabel.Parent = billboard
        
        local layout = Instance.new('UIListLayout')
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.Padding = UDim.new(0, 4)
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), TeamColor.Enabled and 50 or 36)
        end)
        layout.Parent = frame
        
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = frame

        local rowFrame = Instance.new('Frame')
        rowFrame.BackgroundTransparency = 1
        rowFrame.Size = UDim2.new(1, 0, 0, 50)
        rowFrame.LayoutOrder = #compactMainFrame:GetChildren()
        rowFrame.Visible = false
        rowFrame.Parent = compactMainFrame

        local rowTeamLabel = Instance.new('TextLabel')
        rowTeamLabel.Size = UDim2.new(1, 0, 0, 14)
        rowTeamLabel.BackgroundTransparency = 1
        rowTeamLabel.Text = getBedTeamColor(v).name
        rowTeamLabel.TextColor3 = getBedTeamColor(v).color
        rowTeamLabel.TextSize = 13
        rowTeamLabel.Font = Enum.Font.GothamBold
        rowTeamLabel.TextStrokeTransparency = 0.4
        rowTeamLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        rowTeamLabel.Parent = rowFrame

        local rowBG = Instance.new('Frame')
        rowBG.Position = UDim2.new(0, 0, 0, 16)
        rowBG.Size = UDim2.new(1, 0, 0, 34)
        rowBG.BackgroundColor3 = Color3.new(0, 0, 0)
        rowBG.BackgroundTransparency = 0.3
        rowBG.Parent = rowFrame

        local rowCorner = Instance.new('UICorner')
        rowCorner.CornerRadius = UDim.new(0, 4)
        rowCorner.Parent = rowBG

        local rowIcons = Instance.new('Frame')
        rowIcons.BackgroundTransparency = 1
        rowIcons.Size = UDim2.new(1, -30, 1, 0)
        rowIcons.Parent = rowBG

        local rowIconLayout = Instance.new('UIListLayout')
        rowIconLayout.FillDirection = Enum.FillDirection.Horizontal
        rowIconLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rowIconLayout.Padding = UDim.new(0, 2)
        rowIconLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        rowIconLayout.Parent = rowIcons

        local rowCount = Instance.new('TextLabel')
        rowCount.Size = UDim2.new(0, 28, 1, 0)
        rowCount.Position = UDim2.new(1, -28, 0, 0)
        rowCount.BackgroundTransparency = 1
        rowCount.Text = "0"
        rowCount.TextColor3 = Color3.fromRGB(255, 255, 255)
        rowCount.TextSize = 14
        rowCount.Font = Enum.Font.GothamBold
        rowCount.Parent = rowBG

        Reference[v] = {
            billboard = billboard,
            compactRow = {
                frame = rowFrame,
                iconsFrame = rowIcons,
                countLabel = rowCount
            }
        }
        BlockCache[v] = ""
        refreshAdornee(billboard)
    end
    
	local pendingBeds = {}
	local _refreshNearPending = false
	local function refreshNear(data)
		local blockPos = data and data.blockRef and data.blockRef.blockPosition
		if not blockPos then return end
		blockPos *= 3
		for bed in pairs(Reference) do
			if bed.Parent and (blockPos - bed.Position).Magnitude <= 30 then
				pendingBeds[bed] = true
			end
		end
		if _refreshNearPending or not next(pendingBeds) then return end
		_refreshNearPending = true
		task.delay(0.1, function()
			_refreshNearPending = false
			for bed in pairs(pendingBeds) do
				pendingBeds[bed] = nil
				local ref = Reference[bed]
				if ref and bed.Parent then
					refreshAdornee(ref.billboard)
				end
			end
		end)
	end

    local currentCorner = 'Bottom Right'

    local function updateCompactPosition()
        local genUI = vape.gui:FindFirstChild('GeneratorCompactUI')
        local offset = 8
        if genUI and genUI.Enabled and currentCorner == 'Bottom Right' then
            offset = offset + 128
        end
        local invHost = (gethui and gethui()) or game:GetService('CoreGui')
        if invHost:FindFirstChild('InventoryESP') and (currentCorner == 'Bottom Right' or currentCorner == 'Top Right') then
            offset = offset + 200
        end
        if currentCorner == 'Top Right' then
            compactMainFrame.AnchorPoint = Vector2.new(1, 0)
            compactMainFrame.Position = UDim2.new(1, -offset, 0, 8)
        elseif currentCorner == 'Top Left' then
            compactMainFrame.AnchorPoint = Vector2.new(0, 0)
            compactMainFrame.Position = UDim2.new(0, 8, 0, 8)
        elseif currentCorner == 'Bottom Left' then
            compactMainFrame.AnchorPoint = Vector2.new(0, 1)
            compactMainFrame.Position = UDim2.new(0, 8, 1, -8)
        else
            compactMainFrame.AnchorPoint = Vector2.new(1, 1)
            compactMainFrame.Position = UDim2.new(1, -offset, 1, -8)
        end
    end
    
    BedPlates = vape.Categories.Minigames:CreateModule({
        Name = 'BedPlates',
        Function = function(callback)
            if callback then
                table.clear(BlockCache)
                compactUI.Enabled = UIStyle.Value == 'Compact'
                
                local tagged = collectionService:GetTagged('bed')
                for _, v in ipairs(tagged) do 
                    Added(v)
                end
                
                BedPlates:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(refreshNear))
                BedPlates:Clean(vapeEvents.BreakBlockEvent.Event:Connect(refreshNear))
                BedPlates:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(Added))

                local worldFolder = getWorldFolder()
                local blocksFolder = worldFolder and worldFolder:FindFirstChild('Blocks')
                if blocksFolder then
                    local function onBlockChange(obj)
                        if not (obj:IsA('BasePart')) then return end
                        refreshNear({blockRef = {blockPosition = obj.Position / 3}})
                    end
                    BedPlates:Clean(blocksFolder.ChildAdded:Connect(onBlockChange))
                    BedPlates:Clean(blocksFolder.ChildRemoved:Connect(onBlockChange))
                end
                BedPlates:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(v)
                    if Reference[v] then
                        Reference[v].billboard:Destroy()
                        Reference[v].compactRow.frame:Destroy()
                        Reference[v] = nil
                        BlockCache[v] = nil
                    end
                end))
				local lastCompact = 0
				BedPlates:Clean(runService.Heartbeat:Connect(function()
					if compactUI.Enabled and tick() - lastCompact > 0.5 then
						lastCompact = tick()
						updateCompactPosition()
					end
				end))
            else
                for _, v in pairs(Reference) do
                    v.billboard:Destroy()
                    v.compactRow.frame:Destroy()
                end
                table.clear(Reference)
                table.clear(BlockCache)
                compactUI.Enabled = false
            end
        end,
        Tooltip = 'shows enemys bed defence'
    })

    UIStyle = BedPlates:CreateDropdown({
        Name = 'UI Style',
        List = {'Original', 'Compact'},
        Default = 'Original',
        Function = function(val)
            local isOriginal = val == 'Original'
            compactUI.Enabled = BedPlates.Enabled and not isOriginal
            for bed, ref in pairs(Reference) do
                ref.billboard.Enabled = isOriginal
                refreshAdornee(ref.billboard)
            end
            if PositionDropdown.Object then
                PositionDropdown.Object.Visible = not isOriginal
            end
            if IgnoreTeam and IgnoreTeam.Object then
                IgnoreTeam.Object.Visible = not isOriginal
            end
        end,
        Tooltip = 'pick between the floating world esp or a corner panel'
    })

    PositionDropdown = BedPlates:CreateDropdown({
        Name = 'Position',
        List = {'Top Right', 'Top Left', 'Bottom Left', 'Bottom Right'},
        Default = 'Bottom Right',
        Function = function(val)
            currentCorner = val
            updateCompactPosition()
        end,
        Tooltip = 'pick w corner u want the panel chillin in'
    })

    task.defer(function()
        if PositionDropdown and PositionDropdown.Object then
            PositionDropdown.Object.Visible = (UIStyle.Value == 'Compact')
        end
        if IgnoreTeam and IgnoreTeam.Object then
            IgnoreTeam.Object.Visible = (UIStyle.Value == 'Compact')
        end
    end)
    
    IgnoreTeam = BedPlates:CreateToggle({
        Name = 'Ignore Team',
        Default = false,
        Function = function(callback)
            for bed, ref in pairs(Reference) do
                refreshAdornee(ref.billboard)
            end
        end,
        Tooltip = 'wont show ur own team bed on the compact panel'
    })
    
    Background = BedPlates:CreateToggle({
        Name = 'Background',
        Function = function(callback)
            if Color.Object then 
                Color.Object.Visible = callback and not TeamColor.Enabled
            end
            for _, v in pairs(Reference) do
                v.billboard.Frame.BackgroundTransparency = 1 - (callback and (TeamColor.Enabled and 0.5 or Color.Opacity) or 0)
                local blur = v.billboard:FindFirstChild('Blur')
                if blur then
                    blur.Visible = callback
                end
            end
        end,
        Default = true
    })

    Color = BedPlates:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for bed, v in pairs(Reference) do
                if not TeamColor.Enabled then
                    v.billboard.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                end
                if Background.Enabled and not TeamColor.Enabled then
                    v.billboard.Frame.BackgroundTransparency = 1 - opacity
                end
            end
        end,
        Visible = false,
        Darker = true
    })
    
    TeamColor = BedPlates:CreateToggle({
        Name = 'Team Color',
        Default = true,
        Function = function(callback)
            if Color.Object then
                Color.Object.Visible = Background.Enabled and not callback
            end
            for bed, ref in pairs(Reference) do
                ref.billboard.Frame.BackgroundColor3 = callback and getBedTeamColor(bed).color or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                ref.billboard.Frame.BackgroundTransparency = 1 - (Background.Enabled and (callback and 0.5 or Color.Opacity) or 0)
            end
        end
    })

	LayerCounter = BedPlates:CreateToggle({
		Name = 'Layer Counter',
		Function = function(callback)
			if LayerColor and LayerColor.Object then
				LayerColor.Object.Visible = callback
			end
			for _, ref in pairs(Reference) do
				refreshAdornee(ref.billboard)
			end
		end,
		Default = true
	})
	LayerColor = BedPlates:CreateColorSlider({
		Name = 'Counter Text Color',
		DefaultSat = 1,
		DefaultValue = 1,
		Function = function()
			updateLayerTextColor()
		end,
		Visible = LayerCounter.Enabled
	})	
end)
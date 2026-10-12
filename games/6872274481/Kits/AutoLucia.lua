run(function()
    local Lucia
    local AutoDepositToggle
    local RangeSlider
    local DelayToggle
    local DelaySlider
    local LuciaESPToggle
    local CandyESPToggle
    local IgnoreTeammatesESP
    local ESPBackground
    local ESPColor = {}
    local LuciaSpyToggle
    local IgnoreTeammatesSpy
    local DisplayNameToggle
    local Players = playersService
    local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local Reference = {}
	local collectedPinatas = {}
	local trackedPinatas = {}

    local function kitCollection(id, func, range, specific)
        repeat
            if entitylib.isAlive then
                local objs = type(id) == 'table' and id or collection(id, Lucia)
                local localPosition = entitylib.character.RootPart.Position
                for _, v in objs do
                    if not Lucia.Enabled then break end
                    local part = not v:IsA('Model') and v or v.PrimaryPart
                    if part and (part.Position - localPosition).Magnitude <= range then
                        local success, err = pcall(func, v)
                        if not success then
                            warn("lucia deposit error:", err)
                        end
                        if DelayToggle.Enabled then
                            task.wait(DelaySlider.Value)
                        else
                            task.wait(0.05)
                        end
                    end
                end
            end
            task.wait(0.1)
        until not Lucia.Enabled
    end

    local function isTeammateESP(pinataPart)
        if not IgnoreTeammatesESP.Enabled then return false end

        local placerId = pinataPart:GetAttribute("PlacedByUserId") or pinataPart:GetAttribute("PlacerId")
        if not placerId then
            local parent = pinataPart.Parent
            if parent then
                placerId = parent:GetAttribute("PlacedByUserId") or parent:GetAttribute("PlacerId")
            end
        end

        if placerId then
            if placerId == lplr.UserId then
                return true
            end

            local placer = playersService:GetPlayerByUserId(placerId)
            if placer and placer.Team == lplr.Team then
                return true
            end
        end

        return false
    end

    local function isTeammateSpy(pinataPart)
        if not IgnoreTeammatesSpy.Enabled then return false end

        local placerId = pinataPart:GetAttribute("PlacedByUserId") or pinataPart:GetAttribute("PlacerId")
        if not placerId then
            local parent = pinataPart.Parent
            if parent then
                placerId = parent:GetAttribute("PlacedByUserId") or parent:GetAttribute("PlacerId")
            end
        end

        if placerId then
            if placerId == lplr.UserId then
                return true
            end

            local placer = playersService:GetPlayerByUserId(placerId)
            if placer and placer.Team == lplr.Team then
                return true
            end
        end

        return false
    end

    local function getCandyAmount(pinataPart)
        local coins = pinataPart:GetAttribute("Coin")
        return coins or 0
    end

    local function getProperIcon(iconType)
        local icon = bedwars.getIcon({itemType = iconType}, true)
        if not icon or icon == "" then
            return nil
        end
        return icon
    end

    local function Added(pinataPart)
        if isTeammateESP(pinataPart) then
            return
        end

        if Reference[pinataPart] then return end

        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = 'pinata'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
        billboard.Size = UDim2.fromOffset(CandyESPToggle.Enabled and 80 or 36, 36)
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = pinataPart

        local blur = addBlur(billboard)
        blur.Visible = ESPBackground.Enabled

        local frame = Instance.new('Frame')
        frame.Size = UDim2.fromScale(1, 1)
        frame.BackgroundColor3 = Color3.fromHSV(ESPColor.Hue, ESPColor.Sat, ESPColor.Value)
        frame.BackgroundTransparency = 1 - (ESPBackground.Enabled and ESPColor.Opacity or 0)
        frame.BorderSizePixel = 0
        frame.Parent = billboard

        local uicorner = Instance.new('UICorner')
        uicorner.CornerRadius = UDim.new(0, 4)
        uicorner.Parent = frame

        local pinataIcon = getProperIcon('pinata')
        if pinataIcon then
            local image = Instance.new('ImageLabel')
            image.Name = 'PinataIcon'
            image.Size = UDim2.fromOffset(36, 36)
            image.Position = UDim2.new(0, 0, 0.5, 0)
            image.AnchorPoint = Vector2.new(0, 0.5)
            image.BackgroundTransparency = 1
            image.Image = pinataIcon
            image.Parent = frame
        end

        local candyAmount = nil
        local candyIcon = nil

        if CandyESPToggle.Enabled then
            candyAmount = Instance.new('TextLabel')
            candyAmount.Name = 'CandyAmount'
            candyAmount.Size = UDim2.fromOffset(25, 20)
            candyAmount.Position = UDim2.new(0, 40, 0.5, 0)
            candyAmount.AnchorPoint = Vector2.new(0, 0.5)
            candyAmount.BackgroundTransparency = 1
            candyAmount.Text = tostring(getCandyAmount(pinataPart))
            candyAmount.TextColor3 = Color3.fromRGB(255, 255, 255)
            candyAmount.TextSize = 16
            candyAmount.Font = Enum.Font.GothamBold
            candyAmount.TextStrokeTransparency = 0.5
            candyAmount.TextStrokeColor3 = Color3.new(0, 0, 0)
            candyAmount.Parent = frame

            local candyIconImage = getProperIcon('candy')
            if candyIconImage then
                candyIcon = Instance.new('ImageLabel')
                candyIcon.Name = 'CandyIcon'
                candyIcon.Size = UDim2.fromOffset(18, 18)
                candyIcon.Position = UDim2.new(0, 65, 0.5, 0)
                candyIcon.AnchorPoint = Vector2.new(0, 0.5)
                candyIcon.BackgroundTransparency = 1
                candyIcon.Image = candyIconImage
                candyIcon.Parent = frame
            end
        end

        Reference[pinataPart] = {
            billboard = billboard,
            frame = frame,
            candyAmount = candyAmount,
            candyIcon = candyIcon
        }
    end

    local function Removed(pinataPart)
        if Reference[pinataPart] then
            Reference[pinataPart].billboard:Destroy()
            Reference[pinataPart] = nil
        end
    end

    local function updateCandyDisplay(pinataPart)
        local ref = Reference[pinataPart]
        if not ref then return end

        if CandyESPToggle.Enabled then
            if not ref.candyAmount then
                ref.candyAmount = Instance.new('TextLabel')
                ref.candyAmount.Name = 'CandyAmount'
                ref.candyAmount.Size = UDim2.fromOffset(25, 20)
                ref.candyAmount.Position = UDim2.new(0, 40, 0.5, 0)
                ref.candyAmount.AnchorPoint = Vector2.new(0, 0.5)
                ref.candyAmount.BackgroundTransparency = 1
                ref.candyAmount.TextColor3 = Color3.fromRGB(255, 255, 255)
                ref.candyAmount.TextSize = 16
                ref.candyAmount.Font = Enum.Font.GothamBold
                ref.candyAmount.TextStrokeTransparency = 0.5
                ref.candyAmount.TextStrokeColor3 = Color3.new(0, 0, 0)
                ref.candyAmount.Parent = ref.frame

                local candyIconImage = getProperIcon('candy')
                if candyIconImage and not ref.candyIcon then
                    ref.candyIcon = Instance.new('ImageLabel')
                    ref.candyIcon.Name = 'CandyIcon'
                    ref.candyIcon.Size = UDim2.fromOffset(18, 18)
                    ref.candyIcon.Position = UDim2.new(0, 65, 0.5, 0)
                    ref.candyIcon.AnchorPoint = Vector2.new(0, 0.5)
                    ref.candyIcon.BackgroundTransparency = 1
                    ref.candyIcon.Image = candyIconImage
                    ref.candyIcon.Parent = ref.frame
                end

                ref.billboard.Size = UDim2.fromOffset(80, 36)
            end

            if ref.candyAmount then
                ref.candyAmount.Text = tostring(getCandyAmount(pinataPart))
            end
        else
            if ref.candyAmount then
                ref.candyAmount:Destroy()
                ref.candyAmount = nil
            end
            if ref.candyIcon then
                ref.candyIcon:Destroy()
                ref.candyIcon = nil
            end
            ref.billboard.Size = UDim2.fromOffset(36, 36)
        end
    end

    local function findExistingPinatas()
        scanDescendants(workspace, function(obj)
            if obj:IsA("BasePart") and obj.Name == "pinata" then
                if not Reference[obj] and not isTeammateESP(obj) then
                    Added(obj)
                end
            end
        end)
    end

    local function refreshESP()
        Folder:ClearAllChildren()
        table.clear(Reference)
        findExistingPinatas()
    end

    local function getLuciaPlayerName(player)
		return getPlayerName(player, DisplayNameToggle and DisplayNameToggle.Enabled)
	end

    local function getTeamName(player)
		return player.Team and player.Team.Name or "Unknown"
	end

    local function setupLuciaSpy()
        local util = require(game:GetService("ReplicatedStorage").TS.games.bedwars.kit.kits['piggy-bank']['piggy-bank-util']).PiggyBankUtil

        scanDescendants(workspace, function(obj)
            if obj:IsA("BasePart") and obj.Name == "pinata" then
                if not isTeammateSpy(obj) then
                    local placerId = obj:GetAttribute("PlacedByUserId") or obj:GetAttribute("PlacerId")

                    if placerId then
                        local placer = playersService:GetPlayerByUserId(placerId)
                        local initialCandy = getCandyAmount(obj)

                        trackedPinatas[obj] = {
                            player = placer,
                            lastCandy = initialCandy,
                            exists = true,
                            placedTime = tick()
                        }
                    end
                end
            end
        end)

        Lucia:Clean(workspace.DescendantAdded:Connect(function(obj)
            if not LuciaSpyToggle.Enabled then return end

            if obj:IsA("BasePart") and obj.Name == "pinata" then
                task.wait(0.2)

                if not isTeammateSpy(obj) then
                    local placerId = obj:GetAttribute("PlacedByUserId") or obj:GetAttribute("PlacerId")

                    if placerId then
                        local placer = playersService:GetPlayerByUserId(placerId)
                        local initialCandy = getCandyAmount(obj)

                        trackedPinatas[obj] = {
                            player = placer,
                            lastCandy = initialCandy,
                            exists = true,
                            placedTime = tick()
                        }
                    end
                end
            end
        end))

        Lucia:Clean(bedwars.Client:Get("PiggyBankPop"):Connect(function(self)
            if not LuciaSpyToggle.Enabled then return end
            local plr = self.awardedPlayer
            if not plr then return end
            if IgnoreTeammatesSpy.Enabled then
                if plr == lplr or (plr.Team and plr.Team == lplr.Team) then
                    return
                end
            end

            local rewards = util:getRewardsFromCoins(self.coins)
            local I, D, E = 0, 0, 0
            for _, reward in ipairs(rewards) do
                if reward.itemType == "iron" then
                    I = I + (reward.amount or 0)
                elseif reward.itemType == "diamond" then
                    D = D + (reward.amount or 0)
                elseif reward.itemType == "emerald" then
                    E = E + (reward.amount or 0)
                end
            end

            local playerName = getLuciaPlayerName(plr)
            local teamName = getTeamName(plr)
            local loot = string.format("%d irons, %d diamonds, %d emeralds", I, D, E)

            vape:CreateNotification(
                "Lucia Spy",
                string.format("%s (%s) opened their pinata and got %s", playerName, teamName, loot),
                8
            )

            for pinataPart, data in pairs(trackedPinatas) do
                if data.player and data.player.UserId == plr.UserId then
                    trackedPinatas[pinataPart] = nil
                end
            end
        end))

        local luciaSpyCounter = 0
        Lucia:Clean(runService.Heartbeat:Connect(function()
            if not LuciaSpyToggle.Enabled then return end
            luciaSpyCounter = luciaSpyCounter + 1
            if luciaSpyCounter % 6 ~= 0 then return end
            local toRemove = {}
            for pinataPart, data in pairs(trackedPinatas) do
                if pinataPart and pinataPart.Parent then
                    local currentCandy = getCandyAmount(pinataPart)

                    if currentCandy ~= data.lastCandy then
                        local difference = currentCandy - data.lastCandy

                        if difference > 0 and data.player then
                                local playerName = getLuciaPlayerName(data.player)
                                local teamName = getTeamName(data.player)

                                vape:CreateNotification(
                                    "Lucia Spy",
                                    string.format("%s (%s) has just deposited %d candy and now has %d candy",
                                        playerName, teamName, difference, currentCandy),
                                    5
                                )
                            end
                            data.lastCandy = currentCandy
                        end
                else
                    if data.exists and data.player then
                        local timeSincePlaced = tick() - (data.placedTime or tick())

                        if timeSincePlaced > 2 then
                                local playerName = getLuciaPlayerName(data.player)
                                local teamName = getTeamName(data.player)

                                vape:CreateNotification(
                                    "Lucia Spy",
                                    string.format("%s (%s) has just broken their pinata with %d candy",
                                        playerName, teamName, data.lastCandy),
                                    5
                                )
                            end
                        end

                    table.insert(toRemove, pinataPart)
                end
            end

            for _, pinataPart in ipairs(toRemove) do
                trackedPinatas[pinataPart] = nil
            end
        end))
    end

    Lucia = vape.Categories.Kits:CreateModule({
        Name = 'AutoLucia',
        Function = function(callback)
            if callback then
                if LuciaESPToggle.Enabled then
                    findExistingPinatas()
                end

                Lucia:Clean(workspace.DescendantAdded:Connect(function(obj)
                    if Lucia.Enabled and LuciaESPToggle.Enabled and obj:IsA("BasePart") and obj.Name == "pinata" then
                        task.wait(0.1)
                        if not isTeammateESP(obj) then
                            Added(obj)
                        end
                    end
                end))

                Lucia:Clean(workspace.DescendantRemoving:Connect(function(obj)
                    if obj:IsA("BasePart") and obj.Name == "pinata" and Reference[obj] then
                        Removed(obj)
                    end
                end))

                local luciaESPCounter = 0
                Lucia:Clean(runService.Heartbeat:Connect(function()
                    if not Lucia.Enabled or not LuciaESPToggle.Enabled then return end
                    luciaESPCounter = luciaESPCounter + 1
                    if luciaESPCounter % 6 ~= 0 then return end
                    for pinataPart, ref in pairs(Reference) do
                        if pinataPart and pinataPart.Parent then
                            updateCandyDisplay(pinataPart)
                        else
                            if ref.billboard then
                                ref.billboard:Destroy()
                            end
                            Reference[pinataPart] = nil
                        end
                    end
                end))

                if AutoDepositToggle.Enabled then
                    task.spawn(function()
                        local r = RangeSlider.Value
                        kitCollection(lplr.Name .. ':pinata', function(v)
                            if getItem('candy') then
                                bedwars.Client:Get(remotes.DepositCoins):CallServer(v)
                            end
                        end, r, true)
                    end)
                end

                if LuciaSpyToggle.Enabled then
                    setupLuciaSpy()
                end
            else
                Folder:ClearAllChildren()
                table.clear(Reference)
                table.clear(collectedPinatas)
                table.clear(trackedPinatas)
            end
        end,
    })

    AutoDepositToggle = Lucia:CreateToggle({
        Name = 'Auto Deposit',
        Default = false,
        Function = function(callback)
            if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = callback end
            if DelayToggle and DelayToggle.Object then DelayToggle.Object.Visible = callback end
            if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = (callback and DelayToggle.Enabled) end

            if not callback then
                if DelaySlider and DelaySlider.Object then
                    DelaySlider.Object.Visible = false
                end
            else
                if DelayToggle and DelayToggle.Enabled then
                    if DelaySlider and DelaySlider.Object then
                        DelaySlider.Object.Visible = true
                    end
                end
            end
        end
    })

    RangeSlider = Lucia:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 18,
        Default = 8,
        Suffix = ' studs',
        Visible = false
    })

    DelayToggle = Lucia:CreateToggle({
        Name = 'Delay',
        Default = false,
        Visible = false,
        Function = function(callback)
            if DelaySlider and DelaySlider.Object then
                DelaySlider.Object.Visible = callback
            end
        end
    })

    DelaySlider = Lucia:CreateSlider({
        Name = 'Delay Amount',
        Min = 0,
        Max = 2,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
        Visible = false
    })

    LuciaESPToggle = Lucia:CreateToggle({
        Name = 'Pinata ESP',
        Function = function(callback)
            if CandyESPToggle and CandyESPToggle.Object then
                CandyESPToggle.Object.Visible = callback
            end
            if IgnoreTeammatesESP and IgnoreTeammatesESP.Object then
                IgnoreTeammatesESP.Object.Visible = callback
            end
            if ESPBackground and ESPBackground.Object then
                ESPBackground.Object.Visible = callback
            end
            if ESPColor and ESPColor.Object then
                ESPColor.Object.Visible = callback
            end

            if not callback then
                if ESPColor and ESPColor.Object then
                    ESPColor.Object.Visible = false
                end
            else
                if ESPBackground and ESPBackground.Enabled then
                    if ESPColor and ESPColor.Object then
                        ESPColor.Object.Visible = true
                    end
                end
            end

            if Lucia.Enabled then
                if callback then
                    findExistingPinatas()
                else
                    Folder:ClearAllChildren()
                    table.clear(Reference)
                end
            end
        end
    })

    CandyESPToggle = Lucia:CreateToggle({
        Name = 'Candy ESP',
        Visible = false,
        Tooltip = 'show amount of candy in pinatas',
        Function = function(callback)
            for pinataPart in pairs(Reference) do
                updateCandyDisplay(pinataPart)
            end
        end
    })

    IgnoreTeammatesESP = Lucia:CreateToggle({
        Name = 'Ignore Teammates',
        Visible = false,
        Function = function(callback)
            if Lucia.Enabled and LuciaESPToggle.Enabled then
                refreshESP()
            end
        end
    })

    ESPBackground = Lucia:CreateToggle({
        Name = 'Background',
        Visible = false,
        Function = function(callback)
            if ESPColor and ESPColor.Object then
                ESPColor.Object.Visible = callback
            end
            for _, ref in pairs(Reference) do
                if ref.frame then
                    ref.frame.BackgroundTransparency = 1 - (callback and ESPColor.Opacity or 0)
                    if ref.billboard.Blur then
                        ref.billboard.Blur.Visible = callback
                    end
                end
            end
        end
    })

    ESPColor = Lucia:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Visible = false,
        Function = function(hue, sat, val, opacity)
            ESPColor.Hue = hue
            ESPColor.Sat = sat
            ESPColor.Value = val
            ESPColor.Opacity = opacity

            for _, ref in pairs(Reference) do
                if ref.frame then
                    ref.frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                    ref.frame.BackgroundTransparency = 1 - opacity
                end
            end
        end,
        Darker = true
    })

    LuciaSpyToggle = Lucia:CreateToggle({
        Name = 'Lucia Spy',
        Default = false,
        Tooltip = 'notifies you varius info for lucia kits for players (amount of loot and etc)',
        Function = function(callback)
            if IgnoreTeammatesSpy and IgnoreTeammatesSpy.Object then
                IgnoreTeammatesSpy.Object.Visible = callback
            end
            if DisplayNameToggle and DisplayNameToggle.Object then
                DisplayNameToggle.Object.Visible = callback
            end

            if Lucia.Enabled and callback then
                setupLuciaSpy()
            else
                table.clear(trackedPinatas)
            end
        end
    })

    IgnoreTeammatesSpy = Lucia:CreateToggle({
        Name = 'Ignore Teammates',
        Default = true,
        Visible = false
    })

    DisplayNameToggle = Lucia:CreateToggle({
        Name = 'Display Name',
        Default = false,
        Visible = false,
    })

    task.defer(function()
        if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = false end
        if DelayToggle and DelayToggle.Object then DelayToggle.Object.Visible = false end
        if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = false end
        if CandyESPToggle and CandyESPToggle.Object then CandyESPToggle.Object.Visible = false end
        if IgnoreTeammatesESP and IgnoreTeammatesESP.Object then IgnoreTeammatesESP.Object.Visible = false end
        if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = false end
        if ESPColor and ESPColor.Object then ESPColor.Object.Visible = false end
        if IgnoreTeammatesSpy and IgnoreTeammatesSpy.Object then IgnoreTeammatesSpy.Object.Visible = false end
        if DisplayNameToggle and DisplayNameToggle.Object then DisplayNameToggle.Object.Visible = false end
    end)
end)
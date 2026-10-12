run(function()
    local EggESP
    local ShowName
    local ShowLuck
    local ShowDistance
    local Highlight
    local MaxDistance
    local MinLuck
    local renderedEggs = workspace:WaitForChild('RenderedEggs')
    local tracked = {}

    local function getPart(egg)
        local handle = egg:FindFirstChild('Handle', true)

        if handle and handle:IsA('BasePart') then
            return handle
        end

        return egg:FindFirstChildWhichIsA('BasePart', true)
    end

    local function getLuck(egg)
        local eggLuck = egg:FindFirstChild('EggLuck', true)
        local luck = eggLuck and eggLuck:FindFirstChild('Luck', true)

        if luck and luck:IsA('TextLabel') then
            return luck.Text
        end

        return '?'
    end

    local function getLuckValue(egg)
        local text = string.lower(getLuck(egg))
        local number = tonumber(text:match('[%d%.]+')) or 0
        local suffix = text:match('[kmbt]')

        if suffix == 'k' then
            number *= 1e3
        elseif suffix == 'm' then
            number *= 1e6
        elseif suffix == 'b' then
            number *= 1e9
        elseif suffix == 't' then
            number *= 1e12
        end

        return number
    end

    local function removeEgg(egg)
        local data = tracked[egg]

        if data then
            if data.Gui then
                data.Gui:Destroy()
            end

            if data.Highlight then
                data.Highlight:Destroy()
            end

            tracked[egg] = nil
        end
    end

    local function addEgg(egg)
        if tracked[egg] or not egg:IsA('Model') then
            return
        end

        local part = getPart(egg)

        if not part then
            return
        end

        local gui = Instance.new('BillboardGui')
        gui.Name = 'aeroeggesp'
        gui.Adornee = part
        gui.AlwaysOnTop = true
        gui.Size = UDim2.fromOffset(200, 50)
        gui.StudsOffset = Vector3.new(0, 3, 0)
        gui.Parent = part

        local text = Instance.new('TextLabel')
        text.Name = 'text'
        text.Size = UDim2.fromScale(1, 1)
        text.BackgroundTransparency = 1
        text.TextColor3 = Color3.new(1, 1, 1)
        text.RichText = true
        text.TextStrokeTransparency = 0
        text.TextSize = 14
        text.Font = Enum.Font.GothamMedium
        text.TextWrapped = true
        text.Parent = gui

        local highlight = Instance.new('Highlight')
        highlight.Name = 'aeroegghighlight'
        highlight.Adornee = egg
        highlight.FillTransparency = 0.75
        highlight.OutlineTransparency = 0
        highlight.Enabled = Highlight.Enabled
        highlight.Parent = egg

        tracked[egg] = {
            Gui = gui,
            Text = text,
            Highlight = highlight,
            Part = part
        }
    end

    local function updateEgg(egg, data)
        if not egg.Parent or not data.Part or not data.Part.Parent then
            removeEgg(egg)
            return
        end

        local root = lplr.Character and lplr.Character:FindFirstChild('HumanoidRootPart')

        if not root then
            data.Gui.Enabled = false
            data.Highlight.Enabled = false
            return
        end

        local distance = (root.Position - data.Part.Position).Magnitude
        local luckValue = getLuckValue(egg)
        local visible = distance <= MaxDistance.Value and luckValue >= parseLuck(MinLuck.Value)

        data.Gui.Enabled = visible
        data.Highlight.Enabled = visible and Highlight.Enabled

        if not visible then
            return
        end

        local lines = {}

        if ShowName.Enabled then
            lines[#lines + 1] = '<font color="#4DA6FF">' .. string.lower(egg.Name) .. '</font>'
        end

        if ShowLuck.Enabled then
            lines[#lines + 1] = '<font color="#4DFF88">luck ' .. getLuck(egg) .. '</font>'
        end

        if ShowDistance.Enabled then
            lines[#lines + 1] = '<font color="#FFFFFF">' .. math.floor(distance) .. ' studs</font>'
        end

        data.Text.Text = table.concat(lines, '\n')
    end

    EggESP = vape.Categories.Render:CreateModule({
        Name = 'EggESP',
        Function = function(callback)
            if callback then
                for _, egg in renderedEggs:GetChildren() do
                    addEgg(egg)
                end

                EggESP:Clean(renderedEggs.ChildAdded:Connect(function(egg)
                    task.wait()
                    addEgg(egg)
                end))

                EggESP:Clean(renderedEggs.ChildRemoved:Connect(function(egg)
                    removeEgg(egg)
                end))

                EggESP:Clean(runService.RenderStepped:Connect(function()
                    for egg, data in pairs(tracked) do
                        updateEgg(egg, data)
                    end
                end))
            else
                for egg in pairs(tracked) do
                    removeEgg(egg)
                end
            end
        end,
        Tooltip = 'shows egg info through the map gng'
    })

    ShowName = EggESP:CreateToggle({
        Name = 'show name',
        Default = true,
        Function = function() end,
        Tooltip = 'shows what egg it is'
    })

    ShowLuck = EggESP:CreateToggle({
        Name = 'show luck',
        Default = true,
        Function = function() end,
        Tooltip = 'shows the eggs luck'
    })

    ShowDistance = EggESP:CreateToggle({
        Name = 'show distance',
        Default = true,
        Function = function() end,
        Tooltip = 'shows how far the egg is'
    })

    Highlight = EggESP:CreateToggle({
        Name = 'highlight',
        Default = true,
        Function = function(callback)
            for _, data in pairs(tracked) do
                if data.Highlight then
                    data.Highlight.Enabled = callback
                end
            end
        end,
        Tooltip = 'makes eggs easier to see'
    })

    MaxDistance = EggESP:CreateSlider({
        Name = 'max distance',
        Min = 50,
        Max = 5000,
        Default = 1500,
        Function = function() end,
        Suffix = 'studs'
    })
    MinLuck = EggESP:CreateTextBox({
        Name = 'min luck',
        Default = '1',
        Function = function() end
    })
end)
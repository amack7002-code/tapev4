run(function()
    local AutoFarm
    local Priority
    local MinLuck
    local BlackholeOnly

    local renderedEggs = workspace:WaitForChild('RenderedEggs')
    local eggPlaced = replicatedStorage.Remotes.Game.EggPlaced

    local function getPart(egg)
        local handle = egg:FindFirstChild('Handle', true)

        if handle and handle:IsA('BasePart') then
            return handle
        end

        return egg:FindFirstChildWhichIsA('BasePart', true)
    end

    local function getPrompt(egg)
        for _, obj in ipairs(egg:GetDescendants()) do
            if obj:IsA('ProximityPrompt') and obj.Name == 'Pickup' then
                return obj
            end
        end
    end

    local function getLuck(egg)
        local eggLuck = egg:FindFirstChild('EggLuck', true)
        local luck = eggLuck and eggLuck:FindFirstChild('Luck', true)

        if not luck or not luck:IsA('TextLabel') then
            return 0
        end

        return parseLuck(luck.Text)
    end

    local function getPlot()
        local plots = workspace:FindFirstChild('Plots')

        if not plots then
            return
        end

        for _, plot in ipairs(plots:GetChildren()) do
            local data = plot:FindFirstChild('Data')
            local owner = data and data:FindFirstChild('Owner')

            if owner and owner:IsA('ObjectValue') and owner.Value == lplr then
                return plot
            end
        end
    end

    local function getBasePosition()
        local plot = getPlot()
        local baseplate = plot and plot:FindFirstChild('Baseplate')

        if not baseplate or not baseplate:IsA('BasePart') then
            return
        end

        return baseplate.CFrame:PointToWorldSpace(Vector3.new(
            0,
            baseplate.Size.Y / 2,
            0
        ))
    end

    local function teleport(position)
        local char = lplr.Character
        local root = char and char:FindFirstChild('HumanoidRootPart')

        if not root then
            return false
        end

        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))

        return true
    end

    local function isCarryingEgg()
        local playerGui = lplr:FindFirstChild('PlayerGui')
        local main = playerGui and playerGui:FindFirstChild('Main')
        local basketTracker = main and main:FindFirstChild('BasketTracker')
        local capacity = basketTracker and basketTracker:FindFirstChild('Capacity')

        if capacity and capacity:IsA('TextLabel') then
            local current = tonumber(capacity.Text:match('^(%d+)'))

            if current and current > 0 then
                return true
            end
        end

        local char = lplr.Character

        if char then
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA('Tool') and string.find(string.lower(tool.Name), 'egg', 1, true) then
                    return true
                end
            end
        end

        return false
    end

    local function validEgg(egg)
        if BlackholeOnly.Enabled then
            if not string.find(string.lower(egg.Name), 'blackhole', 1, true) then
                return false
            end
        end

        if getLuck(egg) < parseLuck(MinLuck.Value) then
            return false
        end

        return true
    end

    local function getTarget()
        local char = lplr.Character
        local root = char and char:FindFirstChild('HumanoidRootPart')

        if not root then
            return
        end

        local best
        local bestValue

        for _, egg in ipairs(renderedEggs:GetChildren()) do
            if egg:IsA('Model') and validEgg(egg) then
                local part = getPart(egg)
                local prompt = getPrompt(egg)

                if part and prompt and prompt.Enabled then
                    local distance = (root.Position - part.Position).Magnitude
                    local luck = getLuck(egg)

                    if Priority.Value == 'highest luck' then
                        if not bestValue or luck > bestValue then
                            best = egg
                            bestValue = luck
                        end
                    else
                        if not bestValue or distance < bestValue then
                            best = egg
                            bestValue = distance
                        end
                    end
                end
            end
        end

        return best
    end

    AutoFarm = vape.Categories.Blatant:CreateModule({
        Name = 'AutoFarm',
        Function = function(callback)
            if callback then
                task.spawn(function()
                    repeat
                        if isCarryingEgg() then
                            local basePosition = getBasePosition()

                            if basePosition then
                                teleport(basePosition)
                                task.wait(0.5)

                                eggPlaced:FireServer({
                                    PlantPosition = basePosition
                                })

                                task.wait(0.7)
                            else
                                task.wait(0.2)
                            end
                        else
                            local egg = getTarget()

                            if egg then
                                local part = getPart(egg)
                                local prompt = getPrompt(egg)

                                if part and prompt then
                                    teleport(part.Position)
                                    task.wait(0.2)

                                    if fireproximityprompt then
                                        fireproximityprompt(prompt)
                                    end

                                    task.wait(0.35)
                                end
                            else
                                task.wait(0.25)
                            end
                        end
                    until not AutoFarm.Enabled
                end)
            end
        end,
        Tooltip = 'collects and places eggs for u'
    })

    Priority = AutoFarm:CreateDropdown({
        Name = 'priority',
        List = {'nearest', 'highest luck'},
        Function = function() end,
        Tooltip = 'choose which matching egg gets farmed'
    })

    MinLuck = AutoFarm:CreateTextBox({
        Name = 'min luck',
        Default = '1',
        Function = function() end
    })

    BlackholeOnly = AutoFarm:CreateToggle({
        Name = 'blackhole only',
        Default = false,
        Function = function() end,
        Tooltip = 'only farms blackhole eggs'
    })
end)
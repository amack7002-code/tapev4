run(function()
    local AutoCollectEgg
    local Priority
    local MaxDistance
    local renderedEggs = workspace:WaitForChild('RenderedEggs')

    local function getPart(egg)
        local handle = egg:FindFirstChild('Handle', true)

        if handle and handle:IsA('BasePart') then
            return handle
        end

        return egg:FindFirstChildWhichIsA('BasePart', true)
    end

    local function getPrompt(egg)
        for _, obj in egg:GetDescendants() do
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

        local text = string.lower(luck.Text)
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

    local function isCarryingEgg()
        local playerGui = lplr:FindFirstChild('PlayerGui')
        local main = playerGui and playerGui:FindFirstChild('Main')
        local basketTracker = main and main:FindFirstChild('BasketTracker')
        local capacity = basketTracker and basketTracker:FindFirstChild('Capacity')

        if capacity and capacity:IsA('TextLabel') then
            local current, max = capacity.Text:match('(%d+)%s*/%s*(%d+)')

            current = tonumber(current)
            max = tonumber(max)

            if current and max then
                return current >= max
            end
        end

        return false
    end

    local function getTarget()
        if isCarryingEgg() then
            return
        end

        local char = lplr.Character
        local root = char and char:FindFirstChild('HumanoidRootPart')

        if not root then
            return
        end

        local best
        local bestValue

        for _, egg in renderedEggs:GetChildren() do
            if egg:IsA('Model') then
                local part = getPart(egg)
                local prompt = getPrompt(egg)

                if part and prompt and prompt.Enabled then
                    local distance = (root.Position - part.Position).Magnitude

                    if distance <= MaxDistance.Value then
                        if Priority.Value == 'best luck' then
                            local luck = getLuck(egg)

                            if not bestValue or luck > bestValue then
                                best = prompt
                                bestValue = luck
                            end
                        else
                            if not bestValue or distance < bestValue then
                                best = prompt
                                bestValue = distance
                            end
                        end
                    end
                end
            end
        end

        return best
    end

    AutoCollectEgg = vape.Categories.Blatant:CreateModule({
        Name = 'AutoCollectEgg',
        Function = function(callback)
            if callback then
                task.spawn(function()
                    repeat
                        local prompt = getTarget()

                        if prompt and fireproximityprompt then
                            fireproximityprompt(prompt)
                        end

                        task.wait(0.1)
                    until not AutoCollectEgg.Enabled
                end)
            end
        end,
        Tooltip = 'auto picks up eggs for u gng'
    })

    Priority = AutoCollectEgg:CreateDropdown({
        Name = 'priority',
        List = {'nearest', 'best luck'},
        Function = function() end,
        Tooltip = 'choose which egg gets picked first'
    })

    MaxDistance = AutoCollectEgg:CreateSlider({
        Name = 'max distance',
        Min = 15,
        Max = 100,
        Default = 100,
        Function = function() end,
        Suffix = 'studs'
    })
end)
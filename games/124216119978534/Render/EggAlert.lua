run(function()
    local EggAlert
    local MinLuck
    local BlackholeOnly
    local renderedEggs = workspace:WaitForChild('RenderedEggs')
    local alerted = {}

    local function getLuck(egg)
        local eggLuck = egg:FindFirstChild('EggLuck', true)
        local luck = eggLuck and eggLuck:FindFirstChild('Luck', true)

        if not luck or not luck:IsA('TextLabel') then
            return 0, '?'
        end

        local text = luck.Text
        local lower = string.lower(text)
        local number = tonumber(lower:match('[%d%.]+')) or 0
        local suffix = lower:match('[kmbt]')

        if suffix == 'k' then
            number *= 1e3
        elseif suffix == 'm' then
            number *= 1e6
        elseif suffix == 'b' then
            number *= 1e9
        elseif suffix == 't' then
            number *= 1e12
        end

        return number, text
    end

    local function checkEgg(egg)
        if not EggAlert.Enabled or alerted[egg] or not egg:IsA('Model') then
            return
        end

        if BlackholeOnly.Enabled and not string.find(string.lower(egg.Name), 'blackhole', 1, true) then
            return
        end

        task.wait(0.1)

        if not egg.Parent then
            return
        end

        local value, display = getLuck(egg)

        if value >= parseLuck(MinLuck.Value) then
            alerted[egg] = true

            notif(
                'EggAlert',
                egg.Name .. ' | luck ' .. display,
                6
            )
        end
    end

    EggAlert = vape.Categories.Render:CreateModule({
        Name = 'EggAlert',
        Function = function(callback)
            if callback then
                for _, egg in ipairs(renderedEggs:GetChildren()) do
                    task.spawn(checkEgg, egg)
                end

                EggAlert:Clean(renderedEggs.ChildAdded:Connect(function(egg)
                    task.spawn(checkEgg, egg)
                end))

                EggAlert:Clean(renderedEggs.ChildRemoved:Connect(function(egg)
                    alerted[egg] = nil
                end))
            else
                table.clear(alerted)
            end
        end,
        Tooltip = 'alerts u when good eggs spawn'
    })

    MinLuck = EggAlert:CreateTextBox({
        Name = 'min luck',
        Default = '1K',
        Function = function() end
    })

    BlackholeOnly = EggAlert:CreateToggle({
        Name = 'blackhole only',
        Default = false,
        Function = function() end,
        Tooltip = 'only alerts for blackhole eggs'
    })
end)
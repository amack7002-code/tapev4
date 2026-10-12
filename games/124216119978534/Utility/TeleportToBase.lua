run(function()
    local TeleportToBase

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

    TeleportToBase = vape.Categories.Utility:CreateModule({
        Name = 'TeleportToBase',
        Function = function(callback)
            if callback then
                local char = lplr.Character
                local root = char and char:FindFirstChild('HumanoidRootPart')
                local plot = getPlot()
                local baseplate = plot and plot:FindFirstChild('Baseplate')

                if root and baseplate and baseplate:IsA('BasePart') then
                    root.CFrame = baseplate.CFrame + Vector3.new(0, 5, 0)
                end

                task.wait()
                TeleportToBase:Toggle()
            end
        end,
        Tooltip = 'teleports u straight to ur base'
    })
end)
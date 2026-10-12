run(function()
    local AutoPlaceEgg
    local eggPlaced = replicatedStorage.Remotes.Game.EggPlaced

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

    local function getPlacementPosition()
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

    local function getHeldEgg()
        local char = lplr.Character

        if not char then
            return
        end

        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA('Tool') and string.find(string.lower(tool.Name), 'egg', 1, true) then
                return tool
            end
        end
    end

    AutoPlaceEgg = vape.Categories.Blatant:CreateModule({
        Name = 'AutoPlaceEgg',
        Function = function(callback)
            if callback then
                task.spawn(function()
                    repeat
                        local egg = getHeldEgg()

                        if egg then
                            local position = getPlacementPosition()

                            if position then
                                eggPlaced:FireServer({
                                    PlantPosition = position
                                })

                                task.wait(0.5)
                            else
                                task.wait(0.1)
                            end
                        else
                            task.wait(0.1)
                        end
                    until not AutoPlaceEgg.Enabled
                end)
            end
        end,
        Tooltip = 'auto places ur egg'
    })
end)
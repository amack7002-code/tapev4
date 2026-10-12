run(function()
    local AutoHatch
    local eggPlaced = replicatedStorage.Remotes.Game.EggPlaced
    local requestPlotEggs = replicatedStorage.Remotes.Game.RequestPlotEggs
    local hatch = replicatedStorage.Remotes.Game.Hatch
    local eggs = {}

    local function addEgg(data)
        if typeof(data) ~= 'table' then
            return
        end

        if data.Snapshot and data.Owner == lplr then
            table.clear(eggs)

            for _, egg in pairs(data.Placements or {}) do
                if egg.EggKey then
                    eggs[egg.EggKey] = true
                end
            end

            return
        end

        if data.Owner == lplr and data.EggKey then
            eggs[data.EggKey] = true
        end
    end

    AutoHatch = vape.Categories.Blatant:CreateModule({
        Name = 'AutoHatch',
        Function = function(callback)
            if callback then
                AutoHatch:Clean(eggPlaced.OnClientEvent:Connect(addEgg))

                requestPlotEggs:FireServer(false)

                task.spawn(function()
                    repeat
                        for eggKey in pairs(eggs) do
                            hatch:FireServer({
                                EggKey = eggKey
                            })

                            task.wait(0.15)
                        end

                        requestPlotEggs:FireServer(false)
                        task.wait(0.5)
                    until not AutoHatch.Enabled
                end)
            else
                table.clear(eggs)
            end
        end,
        Tooltip = 'auto hatches ur ready eggs'
    })
end)
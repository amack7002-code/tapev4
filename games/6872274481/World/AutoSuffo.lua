run(function()
    local AutoSuffo
    local Range
    local LimitItem
    local Targets

    local function fixPosition(pos)
        return bedwars.BlockController:getBlockPosition(pos) * 3
    end

    local ring = {
        Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0),
        Vector3.new(0, 0, 3), Vector3.new(0, 0, -3),
    }

    local function getBlockItem()
        if store.hand.toolType == 'block' then
            return store.hand.tool.Name
        elseif not LimitItem.Enabled then
            return (getWool())
        end
        return nil
    end

    local function predict(part)
        local vel = part.AssemblyLinearVelocity or Vector3.zero
        return part.Position + vel * lplr:GetNetworkPing()
    end

    local function buildCells(ent)
        local root = predict(ent.RootPart)
        local head = predict(ent.Head)
        local cells = {}
        table.insert(cells, fixPosition(head))
        table.insert(cells, fixPosition(head + Vector3.new(0, 3, 0)))
        for _, o in ring do
            table.insert(cells, fixPosition(head + o))
            table.insert(cells, fixPosition(root + o))
        end
        return cells
    end

    AutoSuffo = vape.Categories.World:CreateModule({
        Name = 'AutoSuffo',
        Function = function(callback)
            if callback then
                repeat
                    local item = entitylib.isAlive and getBlockItem()

                    if item then
                        for _, ent in entitylib.AllPosition({
                            Part = 'RootPart',
                            Range = Range.Value,
                            Players = Targets.Players.Enabled,
                            NPCs = Targets.NPCs.Enabled,
                        }) do
                            if ent.Targetable and ent.Head then
                                for _, pos in buildCells(ent) do
                                    if not getPlacedBlock(pos) and checkFaceAdjacent(pos) then
                                        task.spawn(bedwars.placeBlock, pos, item)
                                    end
                                end
                            end
                        end
                    end

                    task.wait(0.05)
                until not AutoSuffo.Enabled
            end
        end,
    })
    Range = AutoSuffo:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 20,
        Default = 14,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    Targets = AutoSuffo:CreateTargets({Players = true})
    LimitItem = AutoSuffo:CreateToggle({
        Name = 'Limit to Items',
    })
end)
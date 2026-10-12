run(function()
    local BlockIn
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude
    local PlaceSpeed
    local LimitItem
    local Blacklist

    local function isBlacklisted(itemType)
        return Blacklist and table.find(Blacklist.ListEnabled, itemType)
    end

    local function getBlocks()
        local blocks = {}

        if LimitItem and LimitItem.Enabled then
            local itemType = store.hand.toolType == 'block' and store.hand.tool and store.hand.tool.Name
            local meta = itemType and bedwars.ItemMeta[itemType]
            local block = meta and meta.block
            if block and not isBlacklisted(itemType) and (store.hand.amount or 0) > 0 then
                table.insert(blocks, { itemType, block.health or 0, store.hand.tool, store.hand.amount })
            end
            return blocks
        end

        for _, item in store.inventory.inventory.items do
            local itemType = item.itemType
            local meta = itemType and bedwars.ItemMeta[itemType]
            local block = meta and meta.block
            if block and not isBlacklisted(itemType) and (item.amount or 0) > 0 then
                table.insert(blocks, { itemType, block.health or 0, item.tool, item.amount })
            end
        end
        table.sort(blocks, function(a, b)
            return a[2] > b[2]
        end)
        return blocks
    end

    local function getPyramid()
        return {
            Vector3.new(0, 0, 3),
            Vector3.new(0, 3, 3),
            Vector3.new(-3, 0, 0),
            Vector3.new(-3, 3, 0),
            Vector3.new(0, 0, -3),
            Vector3.new(0, 3, -3),
            Vector3.new(3, 0, 0),
            Vector3.new(3, 3, 0),
            Vector3.new(3, 6, 0),
            Vector3.new(0, 6, 0),
        }
    end

    local function isMoving()
        if not entitylib.isAlive then return false end
        local vel = entitylib.character.RootPart.AssemblyLinearVelocity
        return Vector3.new(vel.X, 0, vel.Z).Magnitude > 2
    end

    local function doBuild()
        local basePos = bedwars.BlockController:getBlockPosition(entitylib.character.RootPart.Position) * 3
        rayCheck.FilterDescendantsInstances = { lplr.Character, gameCamera }
        local oldPlaceCPS = bedwars.SharedConstants.BLOCK_PLACE_CPS
        bedwars.SharedConstants.BLOCK_PLACE_CPS = 20
        local blocks = getBlocks()
        if #blocks < 1 then
            notif('BlockIn', 'Missing blocks', 4, 'warning')
        end
        local pattern = getPyramid()
        local aborted = false
        for attempt = 1, 4 do
            if not BlockIn.Enabled or not entitylib.isAlive then break end
            for _, block in blocks do
                if not BlockIn.Enabled or not entitylib.isAlive then break end
                if (block[4] or 0) <= 0 then continue end
                local switched = false
                for _, pos in pattern do
                    if not BlockIn.Enabled or not entitylib.isAlive then break end
                    if isMoving() then
                        aborted = true
                        break
                    end
                    local target = basePos + pos
                    if getPlacedBlock(target) then continue end
                    if not switched then
                        for index, v in store.inventory.hotbar do
                            if v.item and v.item.tool == block[3] and index ~= (store.inventory.hotbarSlot + 1) then
                                hotbarSwitch(index - 1)
                                break
                            end
                        end
                        switched = true
                    end
                    bedwars.placeBlock(target, block[1])
                    local delay = PlaceSpeed.Value
                    if delay > 0 then task.wait(delay) end
                end
                if aborted then break end
            end
            if aborted then break end
            local complete = true
            for _, pos in pattern do
                if not getPlacedBlock(basePos + pos) then
                    complete = false
                    break
                end
            end
            if complete then break end
            task.wait(0.08)
        end
        bedwars.SharedConstants.BLOCK_PLACE_CPS = oldPlaceCPS or 12
        return aborted
    end

    BlockIn = vape.Categories.World:CreateModule({
        Name = 'BlockIn',
        Function = function(callback)
            if callback then
                if not entitylib.isAlive then
                elseif LimitItem and LimitItem.Enabled and store.hand.toolType ~= 'block' then
                    notif('BlockIn', 'Hold a block first', 2, 'warning')
                else
                    doBuild()
                end
                if BlockIn.Enabled then
                    BlockIn:Toggle()
                end
            end
        end,
        Tooltip = 'auto places blocks around yo self'
    })

    PlaceSpeed = BlockIn:CreateSlider({
        Name = 'Placement Speed',
        Min = 0,
        Max = 0.5,
        Default = 0.07,
        Decimal = 100,
        Suffix = 'seconds',
    })
    LimitItem = BlockIn:CreateToggle({
        Name = 'Limit to items',
    })
    Blacklist = BlockIn:CreateTextList({
        Name = 'Blacklists',
        Placeholder = 'block',
        Default = {
            'cannon',
            'tnt',
            'siege_tnt',
        }
    })
end)
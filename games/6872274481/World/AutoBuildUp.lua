run(function()
    local AutoBuildUp
    local LimitItem
    
    local function getScaffoldBlock()
        return getScaffoldBlockForModule(LimitItem)
    end

    local function canPlaceAtPosition(blockpos)
        if not checkFaceAdjacent(blockpos) then
            return false
        end
        
        local checkBelow = blockpos - Vector3.new(0, 3, 0)
        local hasSupport = false
        
        for i = 1, 10 do
            if getPlacedBlock(checkBelow) then
                hasSupport = true
                break
            end
            checkBelow = checkBelow - Vector3.new(0, 3, 0)
        end
        
        return hasSupport or hasFaceBelowOrSide(blockpos)
    end
    
    AutoBuildUp = vape.Categories.World:CreateModule({
        Name = 'AutoBuildUp',
        Function = function(callback)
            
            if callback then
                repeat
                    if entitylib.isAlive then
                        local wool = getScaffoldBlock()
                        
                        if wool then
                            local root = entitylib.character.RootPart
                            
                            local hum = entitylib.character.Humanoid
                            local jumping = inputService:IsKeyDown(Enum.KeyCode.Space) or (hum and hum.Jump)
                            if jumping and (not inputService:GetFocusedTextBox()) then
                                local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + 1.5, 0))
                                
                                local block, blockpos = getPlacedBlock(currentpos)
                                if not block then
                                    blockpos = blockpos * 3
                                    
                                    if hasFaceBelowOrSide(blockpos) then
                                        if canPlaceAtPosition(blockpos) then
                                            task.spawn(bedwars.placeBlock, blockpos, wool, false)
                                        end
                                    else
                                        local nearestBlock = blockProximity(currentpos)
                                        if nearestBlock and canPlaceAtPosition(nearestBlock) then
                                            task.spawn(bedwars.placeBlock, nearestBlock, wool, false)
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    task.wait(0.03)
                until not AutoBuildUp.Enabled
            end
        end,
    })
    LimitItem = AutoBuildUp:CreateToggle({
        Name = 'Limit to items',
        Default = false,
    })
end)
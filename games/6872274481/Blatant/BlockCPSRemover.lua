run(function()
    local BCR
    local Value
    local CpsConstants = nil
    
    BCR = vape.Categories.Blatant:CreateModule({
        Name = "BlockCPSRemover",
        Function = function(callback)
            
            if callback then
                task.wait(1)
                
                pcall(function()
                    CpsConstants = require(replicatedStorage.TS['shared-constants']).CpsConstants
                end)
                
                if not CpsConstants then
                    pcall(function()
                        CpsConstants = bedwars.CpsConstants
                    end)
                end
                
                if CpsConstants then
                    local newCPS = Value.Value == 0 and 1000 or Value.Value
                    CpsConstants.BLOCK_PLACE_CPS = newCPS
                    
                    if isMobile then
                        for _, v in {'2', '5'} do
                            pcall(function()
                                BCR:Clean(lplr.PlayerGui.MobileUI[v].MouseButton1Down:Connect(function()
                                    if CpsConstants then
                                        local currentValue = Value.Value == 0 and 1000 or Value.Value
                                        CpsConstants.BLOCK_PLACE_CPS = currentValue
                                    end
                                end))
                            end)
                        end
                    end
                    
                    task.spawn(function()
                        while BCR.Enabled do
                            local currentValue = Value.Value == 0 and 1000 or Value.Value
                            if CpsConstants.BLOCK_PLACE_CPS ~= currentValue then
                                CpsConstants.BLOCK_PLACE_CPS = currentValue
                            end
                            task.wait(0.3)
                        end
                    end)
                end
                
            else
                if CpsConstants then
                    CpsConstants.BLOCK_PLACE_CPS = 12
                end
            end
        end,
        Tooltip = 'place blocks faster'
    })
    
    Value = BCR:CreateSlider({
        Name = "CPS Limit",
        Suffix = "CPS",
        Default = 12,
        Min = 12,
        Max = 20,
        Function = function()
            if BCR.Enabled and CpsConstants then
                local newCPS = Value.Value == 0 and 1000 or Value.Value
                CpsConstants.BLOCK_PLACE_CPS = newCPS
            end
        end,
    })
end)
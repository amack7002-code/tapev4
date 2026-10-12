run(function()
    local AutoRebirth

    AutoRebirth = vape.Categories.Blatant:CreateModule({
        Name = 'AutoRebirth',
        Function = function(callback)
            if callback then
                task.spawn(function()
                    repeat
                        local playerGui = lplr:FindFirstChild('PlayerGui')
                        local main = playerGui and playerGui:FindFirstChild('Main')
                        local rebirthGui = main and main:FindFirstChild('Rebirth')
                        local button = rebirthGui and rebirthGui:FindFirstChild('Rebirth')

                        if button and button:IsA('GuiButton') and firesignal then
                            firesignal(button.Activated)
                        end

                        task.wait(1)
                    until not AutoRebirth.Enabled
                end)
            end
        end,
        Tooltip = 'auto rebirths when u can'
    })
end)
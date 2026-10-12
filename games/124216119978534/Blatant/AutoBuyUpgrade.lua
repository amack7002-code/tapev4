run(function()
    local AutoBuyUpgrade
    local BuyMode

    local function buyOne()
        local playerGui = lplr:FindFirstChild('PlayerGui')
        local upgrade = playerGui and playerGui:FindFirstChild('Upgrade')
        local purchase = upgrade and upgrade:FindFirstChild('Purchase')

        if purchase and purchase:IsA('GuiButton') and firesignal then
            firesignal(purchase.Activated)
            return true
        end
    end

    local function buyMax()
        local playerGui = lplr:FindFirstChild('PlayerGui')
        local upgrade = playerGui and playerGui:FindFirstChild('MaxUpgrade')
        local purchase = upgrade and upgrade:FindFirstChild('Purchase')

        if purchase and purchase:IsA('GuiButton') and firesignal then
            firesignal(purchase.Activated)
            return true
        end
    end

    AutoBuyUpgrade = vape.Categories.Blatant:CreateModule({
        Name = 'AutoBuyUpgrade',
        Function = function(callback)
            if callback then
                task.spawn(function()
                    repeat
                        if BuyMode.Value == 'max' then
                            buyMax()
                        else
                            buyOne()
                        end

                        task.wait(0.5)
                    until not AutoBuyUpgrade.Enabled
                end)
            end
        end,
        Tooltip = 'auto buys hatch luck upgrades'
    })

    BuyMode = AutoBuyUpgrade:CreateDropdown({
        Name = 'buy mode',
        List = {'one', 'max'},
        Function = function() end,
        Tooltip = 'buy one or max upgrade'
    })
end)
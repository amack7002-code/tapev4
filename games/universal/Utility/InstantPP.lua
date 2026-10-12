run(function()
    local PromptButtonHoldBegan = nil
    local ProximityPromptService = cloneref(game:GetService('ProximityPromptService'))

    local InstantPP = vape.Categories.Utility:CreateModule({
        Name = 'InstantPP',
        Function = function(callback)
            if callback then
                if fireproximityprompt then
                    PromptButtonHoldBegan = ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
                        fireproximityprompt(prompt)
                    end)
                else
                    errorNotification('InstantPP', 'Your executer does not support this command (missing fireproximityprompt)', 5)
                    InstantPP:Toggle()
                end
            else
                if PromptButtonHoldBegan ~= nil then
                    PromptButtonHoldBegan:Disconnect()
                    PromptButtonHoldBegan = nil
                end
            end
        end,
        Tooltip = 'Instantly activates proximity prompts.'
    })
end)
run(function()
    local SetPlayerLevel
    local originalLevel = nil
    local customLevel = 1
    local levelEnabled = false
    local writingLevel = false

    local function applyLevel()
        if not levelEnabled then return end
        writingLevel = true
        lplr:SetAttribute('PlayerLevel', customLevel)
        writingLevel = false
    end

    SetPlayerLevel = vape.Categories.Render:CreateModule({
        Name = "SetPlayerLevel",
        Function = function(state)
            if state then
                originalLevel = lplr:GetAttribute("PlayerLevel")
                levelEnabled = true
                SetPlayerLevel:Clean(lplr:GetAttributeChangedSignal('PlayerLevel'):Connect(function()
                    if not levelEnabled or writingLevel then return end
                    local incoming = lplr:GetAttribute('PlayerLevel')
                    if incoming == customLevel then return end
                    originalLevel = incoming
                    applyLevel()
                end))
                applyLevel()
            else
                levelEnabled = false
                lplr:SetAttribute("PlayerLevel", originalLevel)
                originalLevel = nil
            end
        end,
        Tooltip = "Spoof your player level (client-sided)"
    })

    SetPlayerLevel:CreateSlider({
        Name = "Level",
        Min = 1,
        Max = 1000,
        Default = 1,
        Decimal = 1,
        Function = function(val)
            customLevel = math.floor(val)
            applyLevel()
        end
    })
end)
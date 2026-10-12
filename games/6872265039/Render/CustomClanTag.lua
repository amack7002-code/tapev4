run(function()
    local ok, err = pcall(function()
        repeat task.wait() until vape and vape.Categories and vape.Categories.Render
        local ClanModule
        local ClanColor = Color3.new(1, 1, 1)
        local enabledFlag = false
        local EquippedTag = nil
    
        local SavedTags = {}
        local TagToggles = {}
        local originalTag
        local writingTag = false
        
        local function safeSet(attr, value)
            local lp = game.Players.LocalPlayer
            if lp and lp.SetAttribute then
                pcall(function()
                    lp:SetAttribute(attr, value)
                end)
            end
        end
        
        local function buildTag()
            if not EquippedTag then return "" end
            local hex = string.format("#%02X%02X%02X",
                math.round(ClanColor.R * 255),
                math.round(ClanColor.G * 255),
                math.round(ClanColor.B * 255)
            )
            local escaped = EquippedTag:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'):gsub('"', '&quot;'):gsub("'", '&apos;')
            return "<font color='"..hex.."'>"..escaped.."</font>"
        end
        
        local function updateClanTag()
            if not enabledFlag then return end
            writingTag = true
            safeSet("ClanTag", buildTag())
            writingTag = false
        end
        
        local function createTagToggles()
            for tag, toggle in pairs(TagToggles) do
                local present = table.find(SavedTags, tag) ~= nil
                toggle.Object.Visible = present
                if not present and toggle.Enabled then toggle:Toggle() end
            end
            
            for i, tag in ipairs(SavedTags) do
                if tag and tag ~= "" and not TagToggles[tag] then
                    TagToggles[tag] = ClanModule:CreateToggle({
                        Name = tag,
                        Function = function(callback)
                            if callback then
                                EquippedTag = tag
                                for j, otherToggle in pairs(TagToggles) do
                                    if j ~= tag and otherToggle and otherToggle.Enabled then
                                        otherToggle:Toggle()
                                    end
                                end
                            else
                                if EquippedTag == tag then
                                    EquippedTag = nil
                                end
                            end
                            updateClanTag()
                        end
                    })
                end
            end
        end
        
        ClanModule = vape.Categories.Render:CreateModule({
            Name = "CustomClanTag",
            HoverText = "Click tags to equip/unequip",
            Function = function(state)
                if state then
                    originalTag = lplr:GetAttribute('ClanTag')
                    enabledFlag = true
                    ClanModule:Clean(lplr:GetAttributeChangedSignal('ClanTag'):Connect(function()
                        if not enabledFlag or writingTag then return end
                        local incoming = lplr:GetAttribute('ClanTag')
                        if incoming == buildTag() then return end
                        originalTag = incoming
                        updateClanTag()
                    end))
                    createTagToggles()
                    updateClanTag()
                else
                    enabledFlag = false
                    safeSet('ClanTag', originalTag)
                    originalTag = nil
                end
            end
        })
        
        ClanModule:CreateColorSlider({
            Name = "Tag Color",
            Function = function(h, s, v)
                ClanColor = Color3.fromHSV(h, s, v)
                updateClanTag()
            end
        })
        
        ClanModule:CreateTextList({
            Name = "Clan Tags",
            Placeholder = "Add tags here",
            Function = function(list)
                SavedTags = {}
                for i, tag in ipairs(list) do
                    if tag and tag ~= "" then
                        table.insert(SavedTags, tag)
                    end
                end
                createTagToggles()
            end
        })
        
    end)
    if not ok then
        warn("CustomClanTag error:", err)
    end
end)
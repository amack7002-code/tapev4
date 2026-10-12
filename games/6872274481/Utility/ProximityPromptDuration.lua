run(function()
    local moduleData = {
        Connection = nil,
        CurrentDuration = 1,
        CachedPrompts = {}
    }
    
    local function updatePrompt(prompt, duration)
        if prompt and prompt:IsA("ProximityPrompt") then
            prompt.HoldDuration = duration
        end
    end
    
    local function updateAllPrompts(duration)
        for prompt in pairs(moduleData.CachedPrompts) do
            if prompt and prompt.Parent then
                prompt.HoldDuration = duration
            else
                moduleData.CachedPrompts[prompt] = nil
            end
        end
    end
    
    local function cacheExistingPrompts()
        moduleData.CachedPrompts = {}
        
        scanDescendants(workspace, function(descendant)
            if descendant:IsA("ProximityPrompt") then
                moduleData.CachedPrompts[descendant] = true
                descendant.HoldDuration = moduleData.CurrentDuration
            end
        end)
    end
    
	ProximityPromptDuration = vape.Categories.Utility:CreateModule({
		Name = 'ProximityPromptDuration',
		Function = function(callback)
			if callback then
				cacheExistingPrompts()
				ProximityPromptDuration:Clean(workspace.DescendantAdded:Connect(function(descendant)
					if descendant:IsA("ProximityPrompt") then
						moduleData.CachedPrompts[descendant] = true
						descendant.HoldDuration = moduleData.CurrentDuration
					end
				end))
			else
				moduleData.CachedPrompts = {}
			end
		end,
		Tooltip = 'customize proximity prompts'
	})
    
    local ProximityDurationSlider = ProximityPromptDuration:CreateSlider({
        Name = 'Duration',
        Min = 0,
        Max = 10,
        Default = 1,
        Decimal = 100,
        Suffix = 's',
        Function = function(value)
            moduleData.CurrentDuration = value
            if ProximityPromptDuration.Enabled then
                updateAllPrompts(value)
            end
        end
    })
end)
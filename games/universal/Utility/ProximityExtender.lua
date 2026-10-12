run(function()
    local ProximityMaxDistance
    local MaxDistance
    local oldDistances = {}
    local addedConnection
    local removedConnection
    local trackedPrompts = {}
    
    ProximityMaxDistance = vape.Categories.Utility:CreateModule({
        Name = "ProximityExtender",
        Function = function(callback)
            
            if callback then
                table.clear(oldDistances)
                table.clear(trackedPrompts)
                
                local function applyToPrompt(prompt)
                    if not prompt:IsA("ProximityPrompt") then return end
                    if trackedPrompts[prompt] then return end 
                    
                    trackedPrompts[prompt] = true
                    oldDistances[prompt] = prompt.MaxActivationDistance
                    prompt.MaxActivationDistance = MaxDistance.Value
                end
                
                local function scanForPrompts(parent)
                    for _, obj in ipairs(parent:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") then
                            applyToPrompt(obj)
                        end
                    end
                end
                
                scanForPrompts(workspace)
                
                addedConnection = workspace.DescendantAdded:Connect(function(obj)
                    if obj:IsA("ProximityPrompt") then
                        applyToPrompt(obj)
                    end
                end)
                
                removedConnection = workspace.DescendantRemoving:Connect(function(obj)
                    if obj:IsA("ProximityPrompt") then
                        oldDistances[obj] = nil
                        trackedPrompts[obj] = nil
                    end
                end)
                
                MaxDistance.Function = function(value)
                    for prompt in pairs(trackedPrompts) do
                        if prompt and prompt.Parent then
                            prompt.MaxActivationDistance = value
                        end
                    end
                end
            else
                if addedConnection then
                    addedConnection:Disconnect()
                    addedConnection = nil
                end
                
                if removedConnection then
                    removedConnection:Disconnect()
                    removedConnection = nil
                end
                
                for prompt, dist in pairs(oldDistances) do
                    if prompt and prompt.Parent then
                        pcall(function()
                            prompt.MaxActivationDistance = dist
                        end)
                    end
                end
                
                table.clear(oldDistances)
                table.clear(trackedPrompts)
                MaxDistance.Function = function() end
            end
        end,
        Tooltip = "increase the range of proximity"
    })
    
    MaxDistance = ProximityMaxDistance:CreateSlider({
        Name = 'Max Distance',
        Min = 10,
        Max = 20,
        Default = 20,
    })
end)
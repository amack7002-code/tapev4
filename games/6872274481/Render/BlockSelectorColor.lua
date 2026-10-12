run(function()
    local BlockSelectorColor
    local Fill
    local Outline
    local RunService = game:GetService("RunService")
    local updateConnection
    local boxes = {}

    local function applyBox(box)
        box.Color3 = Color3.fromHSV(Outline.Hue, Outline.Sat, Outline.Value)
        box.Transparency = 1 - Outline.Opacity
        box.SurfaceColor3 = Color3.fromHSV(Fill.Hue, Fill.Sat, Fill.Value)
        box.SurfaceTransparency = 1 - Fill.Opacity
    end

    local function UpdateAllBoxes()
        for box in pairs(boxes) do
            if box.Parent then
                applyBox(box)
            else
                boxes[box] = nil
            end
        end
    end

    BlockSelectorColor = vape.Categories.Render:CreateModule({
        Name = 'BlockSelectorColor',
        Function = function(callback)
            if callback then
                table.clear(boxes)
                scanDescendants(workspace, function(box)
                    if box:IsA("SelectionBox") then
                        boxes[box] = true
                    end
                end, BlockSelectorColor)
                BlockSelectorColor:Clean(workspace.DescendantAdded:Connect(function(v)
                    if v:IsA("SelectionBox") then
                        boxes[v] = true
                        applyBox(v)
                    end
                end))
                BlockSelectorColor:Clean(workspace.DescendantRemoving:Connect(function(v)
                    if v:IsA("SelectionBox") then
                        boxes[v] = nil
                    end
                end))
                updateConnection = RunService.RenderStepped:Connect(UpdateAllBoxes)
            else
                if updateConnection then
                    updateConnection:Disconnect()
                    updateConnection = nil
                end
                table.clear(boxes)
            end
        end,
        Tooltip = 'change your block placement outline color'
    })

    Fill = BlockSelectorColor:CreateColorSlider({
        Name = 'Overlay Color',
        DefaultOpacity = 0.5
    })
    Outline = BlockSelectorColor:CreateColorSlider({
        Name = 'Outline Color',
        DefaultOpacity = 1
    })
end)
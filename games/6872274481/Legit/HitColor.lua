run(function()
	local HitColor
	local Color
	local done = {}
	
	HitColor = vape.Categories.Legit:CreateModule({
		Name = 'HitColor',
		Function = function(callback)
			if callback then
				local function hookHighlight(v)
					local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
					if highlight and not done[highlight] then
						highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
						highlight.FillTransparency = Color.Opacity
						done[highlight] = true
					end
				end
				for _, v in entitylib.List do hookHighlight(v) end
				HitColor:Clean(entitylib.Events.EntityAdded:Connect(hookHighlight))
			else
				for highlight in pairs(done) do
					if highlight and highlight.Parent then
						pcall(function()
							highlight.FillColor = Color3.new(1, 0, 0)
							highlight.FillTransparency = 0.4
						end)
					end
				end
				table.clear(done)
			end
		end,
		Tooltip = 'customize hit color'
	})
	Color = HitColor:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.4
	})
end)
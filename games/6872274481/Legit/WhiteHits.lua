run(function()
	local WhiteHits
	WhiteHits = vape.Categories.Legit:CreateModule({
		Name = "WhiteHits",
		Function = function(callback)
			if callback then
				local function killHighlight(obj)
					if obj and obj.Name == '_DamageHighlight_' then
						pcall(function()
							obj.Enabled = false
							obj:Destroy()
						end)
					end
				end
				local function sweep(model)
					if not model then return end
					for _, obj in model:GetDescendants() do
						killHighlight(obj)
					end
				end
				WhiteHits:Clean(workspace.DescendantAdded:Connect(killHighlight))
				repeat
					for _, plr in playersService:GetPlayers() do
						sweep(plr.Character)
					end
					for i, v in entitylib.List do 
						sweep(v.Character)
					end
					task.wait(0.1)
				until not WhiteHits.Enabled
			end
		end,
		Tooltip = 'stops that red flash when ppl get hit so hits stay "white"'
	})
end)
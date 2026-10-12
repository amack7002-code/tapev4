run(function()
	local AntiLasso
	local Chance
	local watching = setmetatable({}, {__mode = 'k'})
	
	local function Added(ent)
		if watching[ent] then return end
	
		watching[ent] = ent.ChildAdded:Connect(function(v)
			if not AntiLasso.Enabled then return end
			if v:IsA('Accessory') and v:FindFirstChild('Rope') and Random.new(os.clock()):NextNumber(1, 100) < Chance.Value then
				ent.PrimaryPart.Anchored = true
				v.Destroying:Once(function()
					task.wait(0.5)
					ent.PrimaryPart.Anchored = false
				end)
			end
		end)
	end
	
	AntiLasso = vape.Categories.Kits:CreateModule({
		Name = 'AntiLasso',
		Function = function(callback)
			if callback then
				AntiLasso:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
					task.delay(1, function()
						Added(ent.Character)
					end)
				end))
				if entitylib.isAlive then
					Added(lplr.Character)
				end
			else
				local char = lplr.Character
				local root = char and char.PrimaryPart
				if root then
					pcall(function() root.Anchored = false end)
				end
			end
		end,
		Tooltip = 'stops u gettin yanked by the lasso'
	})
	
	Chance = AntiLasso:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)
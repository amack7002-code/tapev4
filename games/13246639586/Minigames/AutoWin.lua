run(function()
	local AutoWin

	local Minigames = vape.Categories and vape.Categories.Minigames
	if not Minigames or not Minigames.CreateModule then
		return
	end

	AutoWin = Minigames:CreateModule({
		Name = 'AutoWin',
		Function = function(callback)
			if callback then
				for _, win in pairs(workspace.BlockContainer.Map.Portals:GetDescendants()) do
					if win:IsA("TouchInterest") then
						firetouchinterest(win.Parent, win, 1)
						firetouchinterest(win.Parent, win, 0)
					end
				end
			end
		end,
		Tooltip = 'Automatically wins for you'
	})
end)
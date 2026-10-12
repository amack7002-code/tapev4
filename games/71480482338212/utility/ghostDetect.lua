run(function()
	local GhostDetector
	local seen = {}

	GhostDetector = vape.Categories.Utility:CreateModule({
		Name = 'GhostDetector',
		Function = function(callback)
			if callback then
				-- staff watch matches as ghosts, the game hides them from everyone else
				local function check(plr)
					if plr ~= lplr and plr:GetAttribute('Ghost') == true and not seen[plr] then
						seen[plr] = true
						notif('GhostDetector', plr.Name..' is watching this server as an invisible ghost.', 20, 'alert')
					end
				end
				local function watch(plr)
					GhostDetector:Clean(plr:GetAttributeChangedSignal('Ghost'):Connect(function()
						check(plr)
					end))
					check(plr)
				end
				GhostDetector:Clean(playersService.PlayerAdded:Connect(watch))
				for _, plr in playersService:GetPlayers() do
					watch(plr)
				end
			else
				table.clear(seen)
			end
		end,
		Tooltip = 'Warns you when someone joins or turns into a hidden spectator'
	})
end)

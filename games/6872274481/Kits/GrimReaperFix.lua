run(function()
	local GrimReaperFix
	GrimReaperFix = vape.Categories.Kits:CreateModule({
		Name = 'GrimReaperFix',
		Function = function(callback)
			if callback then
				GrimReaperFix:Clean(runService.Heartbeat:Connect(function()
					if not entitylib.isAlive then return end
					local humanoid = entitylib.character.Humanoid
					if humanoid.HipHeight > 2.1 then
						humanoid.HipHeight = 2.05
					end
				end))
			end
		end,
		Tooltip = 'fixes grim height (prevents being too tall)'
	})
end)
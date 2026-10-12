run(function()
	local AutoRedeemCodex

	AutoRedeemCodex = vape.Categories.Blatant:CreateModule({
		Name = 'AutoRedeemCodex',
		Function = function(callback)
			if callback then
				repeat
					task.wait(1)
					Remotes.Codex.AskRedeemAll:InvokeServer()
				until not AutoRedeemCodex.Enabled
			end
		end,
		Tooltip = 'auto claims everything in ur codex '
	})
end)
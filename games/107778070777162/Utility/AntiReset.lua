run(function()
	local AntiReset

	AntiReset = vape.Categories.Utility:CreateModule({
		Name = 'AntiReset',
		Function = function(callback)
			if callback then
				if rigSyncRemote and getconnections then
					local conns = getconnections(rigSyncRemote.OnClientEvent)
					for _, c in conns do
						c:Disconnect()
					end
				end
			end
		end,
		Tooltip = 'stops the game from resetting stuff back on u '
	})
end)
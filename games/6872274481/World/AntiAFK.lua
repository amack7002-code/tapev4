run(function()
	local AntiAfk

	AntiAfk = vape.Categories.World:CreateModule({
		Name = 'AntiAFK',
		Function = function(callback)
			if callback then
				pcall(function()
					for _, v in getconnections(lplr.Idled) do
						v:Disconnect()
					end
				end)

				pcall(function()
					for _, v in getconnections(runService.Heartbeat) do
						if type(v.Function) == 'function' then
							local constants = debug.getconstants(v.Function)
							if constants and table.find(constants, remotes.AfkStatus) then
								v:Disconnect()
							end
						end
					end
				end)

				pcall(function()
					local afkRemote = bedwars.Client:Get(remotes.AfkStatus)
					if afkRemote then
						afkRemote:SendToServer({
							afk = false
						})
					end
				end)
			end
		end,
	})
end)
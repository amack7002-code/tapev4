run(function()
	local AutoQueue
	local Join
	local Hop

	AutoQueue = vape.Categories.Utility:CreateModule({
		Name = 'AutoQueue',
		Function = function(callback)
			if callback then
				local sent = 0
				repeat
					local status, timer = bedfight.GameInfo:FindFirstChild('Status'), bedfight.GameInfo:FindFirstChild('Timer')
					if not inMatch() and status and timer and status.Value == 'Started' and tick() - sent > 8 then
						-- the game lets you in for the first three minutes, after that it offers another server
						if timer.Value <= 180 then
							if Join.Enabled and lplr:GetAttribute('CanJoinGame') then
								sent = tick()
								fireRemote('Join')
							end
						elseif Hop.Enabled then
							sent = tick()
							fireRemote('QueueToOpenServer')
						end
					end
					task.wait(1)
				until not AutoQueue.Enabled
			end
		end,
		Tooltip = 'Gets you back into a match while you sit in the lobby or spectate'
	})
	Join = AutoQueue:CreateToggle({
		Name = 'Join running match',
		Default = true,
		Tooltip = 'Presses Join for you while the match is under three minutes old'
	})
	Hop = AutoQueue:CreateToggle({
		Name = 'Find open server',
		Default = true,
		Tooltip = 'Asks the game for a server with an open match once this one is closed'
	})
end)

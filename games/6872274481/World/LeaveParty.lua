run(function()
	local a = {Enabled = false}
	a = vape.Categories.World:CreateModule({
		Name = "LeaveParty",
		Function = function(call)
			if call then
				a:Toggle(false)
				game:GetService("ReplicatedStorage"):WaitForChild("events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events"):WaitForChild("leaveParty"):FireServer()
			end
		end
	})
end)
run(function()
	local InstantCarry
	local conn = nil
	InstantCarry = vape.Categories.Blatant:CreateModule({
		Name = 'InstantCarry',
		Function = function(callback)
			if callback then
				conn = game:GetService('ProximityPromptService').PromptButtonHoldBegan:Connect(function(prompt, player)
					if player == lplr and tostring(prompt) == 'CarryAreaEgg' then
						prompt.HoldDuration = 0
					end
				end)
			else
				if conn then
					conn:Disconnect()
					conn = nil
				end
			end
		end,
		Tooltip = 'grabs the egg instantly with no hold time '
	})
end)
run(function()
	local InfiniteJump

	InfiniteJump = vape.Categories.Utility:CreateModule({
		Name = 'InfiniteJump',
		Function = function(callback)
			if callback then
				InfiniteJump:Clean(inputService.JumpRequest:Connect(function()
					if not InfiniteJump.Enabled then return end
					if not entitylib.isAlive then return end
					local character = lplr.Character
					if not character then return end
					local humanoid = character:FindFirstChildOfClass('Humanoid')
					if not humanoid then return end
					humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end))
			end
		end
	})
end)
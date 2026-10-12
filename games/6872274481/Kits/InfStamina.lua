run(function()
	local InfStamina
	local dismountRemote

	task.spawn(function()
		local net = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged')
		dismountRemote = net:WaitForChild('CatWallClimbDismount')
	end)

	InfStamina = vape.Categories.Kits:CreateModule({
		Name = 'InfStamina',
		Function = function(callback)
			if callback then
				cleanThread(InfStamina, task.spawn(function()
					repeat
						if entitylib.isAlive and dismountRemote then
							pcall(function()
								dismountRemote:FireServer({direction = vector.create(-0, -0, -1)})
							end)
						end
						task.wait(0.25)
					until not InfStamina.Enabled
				end))
			end
		end,
		Tooltip = 'infinite stamina with yamini kit'
	})
end)
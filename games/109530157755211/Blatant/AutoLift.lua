run(function()
	AutoLift = vape.Categories.Blatant:CreateModule({
		Name = 'AutoLift',
		Function = function(callback)
			if callback then
				repeat
					task.wait(0.05)
					local ctrl = getControllers()
					local cubesFolder = getCubesFolder()
					local char = lplr.Character
					local hrp = char and char:FindFirstChild('HumanoidRootPart')
					local hum = char and char:FindFirstChildOfClass('Humanoid')
					if ctrl and ctrl.Cubes and cubesFolder and hrp and hum and hum.Health > 0 then
						local index = getBestLiftableCube()
						local cubePart = cubesFolder:FindFirstChild(tostring(index))
						if cubePart then
							local strength = getStrength()
							local scale = cubeRollLib.Scale(cubesFolder, index)
							local mass = cubeRollLib.Mass(index, scale)
							if liftingLib.Possible(strength, mass) then
								local minTime = liftingLib.MinimumTime(strength, mass)
								if (hrp.Position - cubePart.Position).Magnitude > 8 then
									hrp.CFrame = cubePart.CFrame + Vector3.new(0, 3, 2.5)
									task.wait(0.08)
								end
								hum:UnequipTools()
								ctrl.Cubes:Start(index, cubePart)
								task.wait(minTime <= 0 and 0.02 or minTime + 0.04)
								if ctrl.Cubes.active then
									ctrl.Cubes.active.Progress = 1
									ctrl.Cubes:_Finish(true)
								end
							end
						end
					end
				until not AutoLift.Enabled
			end
		end,
		Tooltip = 'auto lifts the best cube it can find for free cash'
	})
end)
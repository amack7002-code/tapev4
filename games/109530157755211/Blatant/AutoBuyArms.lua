run(function()
	AutoBuyArms = vape.Categories.Blatant:CreateModule({
		Name = 'AutoBuyArms',
		Function = function(callback)
			if callback then
				repeat
					task.wait(3)
					local armsFolder = workspace:FindFirstChild('World')
					armsFolder = armsFolder and armsFolder:FindFirstChild('Shared')
					armsFolder = armsFolder and armsFolder:FindFirstChild('Arms')
					local char = lplr.Character
					local hrp = char and char:FindFirstChild('HumanoidRootPart')
					if armsFolder and hrp then
						local currentArms = getEquippedArms()
						local currentCash = getCash()
						for tier = #armsSchematic, currentArms + 1, -1 do
							local data = armsSchematic[tier]
							if data and currentCash >= data.Price then
								local pad = armsFolder:FindFirstChild(tostring(tier))
								if pad and pad:FindFirstChild('Main') then
									local oldPos = hrp.CFrame
									hrp.CFrame = CFrame.new(pad.Main.Position + Vector3.new(0, 3, 0))
									task.wait(0.35)
									hrp.CFrame = oldPos
									break
								end
							end
						end
					end
				until not AutoBuyArms.Enabled
			end
		end,
		Tooltip = 'auto buys the best arms u can afford'
	})
end)
run(function()
	local NetworkTP
	NetworkTP = vape.Categories.Utility:CreateModule({
		Name = 'NetworkTP',
		Function = function(callback)
			if callback then
				local items = collection('ItemDrop', NetworkTP)
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						local humanoidHealth = entitylib.character.Humanoid.Health
						local currentTime = tick()

						for _, v in pairs(items) do
							local dropTime = v:GetAttribute('ClientDropTime')
							if not dropTime then continue end
							if (currentTime - dropTime) < 2 then continue end
							if isnetworkowner(v) and humanoidHealth > 0 then
								v.CFrame = CFrame.new(localPosition - Vector3.new(0, 3, 0))
							end
						end
					end
					task.wait(0.1)
				until not NetworkTP.Enabled
			end
		end,
		Tooltip = 'network ownership teleports item drops to you'
	})
end)
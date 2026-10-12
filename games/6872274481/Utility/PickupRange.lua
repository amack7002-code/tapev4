run(function()
	local PickupRange
	local Range
	local Lower
	local Network
	local PickupDelay
	local lastPickupTime = 0
	
	PickupRange = vape.Categories.Utility:CreateModule({
		Name = 'PickupRange',
		Function = function(callback)
			if callback then
				local items = collection('ItemDrop', PickupRange)
				local rangeSquared = Range.Value * Range.Value
				
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						local humanoidHealth = entitylib.character.Humanoid.Health
						local currentTime = tick()
						local pickupDelaySeconds = PickupDelay.Value / 1000
						rangeSquared = Range.Value * Range.Value

						for _, v in pairs(items) do
							if (currentTime - (v:GetAttribute('ClientDropTime') or 0)) < 2 then continue end
							if (currentTime - lastPickupTime) < pickupDelaySeconds then continue end

							local offset = v.Position - localPosition
							local distanceSquared = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z

							if distanceSquared <= rangeSquared then
								if Lower.Enabled and (localPosition.Y - v.Position.Y) < (entitylib.character.HipHeight - 1) then continue end

								bedwars.Client:Get(remotes.PickupItem):CallServerAsync({
									itemDrop = v
								}):andThen(function(suc)
									if suc then
										lastPickupTime = tick()
										local soundManager = bedwars.SoundManager
										local playSound = soundManager and soundManager.playSound
										if type(playSound) == 'function' then
											local soundList = bedwars.SoundList
											local pickupSound = soundList and soundList.PICKUP_ITEM_DROP
											if pickupSound then
												pcall(playSound, soundManager, pickupSound)
											end
											local itemMeta = bedwars.ItemMeta and bedwars.ItemMeta[v.Name]
											local sound = itemMeta and itemMeta.pickUpOverlaySound
											if sound then
												pcall(playSound, soundManager, sound, {
													position = v.Position,
													volumeMultiplier = 0.9
												})
											end
										end
									end
								end)
							end
						end
					end
					task.wait(0.1)
				until not PickupRange.Enabled
			else
				lastPickupTime = 0
			end
		end,
		Tooltip = 'Picks up items from a farther distance'
	})

	Range = PickupRange:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 10,
		Default = 10,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	PickupDelay = PickupRange:CreateSlider({
		Name = 'Pickup Delay',
		Min = 0,
		Max = 500,
		Default = 0,
		Suffix = 'ms'
	})
	Lower = PickupRange:CreateToggle({
		Name = 'Feet Check'
	})
end)
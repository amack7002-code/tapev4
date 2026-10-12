run(function()
	local AutoVoidDrop
	local OwlCheck
	local PearlCheck
	local AutoReset
	local pearlLastInHandTickVoid = 0
	local DropToggles = {
		iron = nil,
		diamond = nil,
		emerald = nil,
		gold = nil
	}
	local cachedLowestPoint
	
	AutoVoidDrop = vape.Categories.Utility:CreateModule({
		Name = 'AutoVoidDrop',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AutoVoidDrop.Enabled)
				if not AutoVoidDrop.Enabled then return end

				cachedLowestPoint = nil
				local worldFolder = getWorldFolder()
				local blocksFolder = worldFolder and worldFolder:FindFirstChild('Blocks')
				for _, v in (blocksFolder and blocksFolder:GetChildren() or store.blocks or {}) do
					if v:IsA('BasePart') then
						local point = v.Position.Y - (v.Size.Y / 2)
						if not cachedLowestPoint or point < cachedLowestPoint then
							cachedLowestPoint = point
						end
					end
				end

				local droppedThisLife = false
				local learnedDeathY, lastVoidY
				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart

						local handItem = store.inventory and store.inventory.inventory and store.inventory.inventory.hand
						if handItem and handItem.itemType == 'telepearl' then
							pearlLastInHandTickVoid = tick()
						end

						local vy = root.AssemblyLinearVelocity.Y
						if vy < -50 and isAboveVoid(root.Position) then
							lastVoidY = root.Position.Y
						else
							lastVoidY = nil
						end

						if droppedThisLife then
							if not isAboveVoid(root.Position) and root.AssemblyLinearVelocity.Y > -5 then
								droppedThisLife = false
							end
						else
							local deathLine = learnedDeathY or (cachedLowestPoint and cachedLowestPoint - 25) or (workspace.FallenPartsDestroyHeight + 20)
							if lastVoidY and (root.Position.Y + vy * 0.3) < deathLine + 5 and (lplr.Character:GetAttribute('InflatedBalloons') or 0) <= 0 and not getItem('balloon') then
								local pearlBlock = PearlCheck.Enabled and (tick() - pearlLastInHandTickVoid) < 4
								if (not OwlCheck.Enabled or not root:FindFirstChild('OwlLiftForce')) and not pearlBlock then
									droppedThisLife = true
									for _, item in pairs(store.inventory.inventory.items) do
										local toggle = item and DropToggles[item.itemType]
										if toggle and toggle.Enabled and item.tool then
											task.spawn(function()
												local dropped = bedwars.Client:Get(remotes.DropItem):CallServer({
													item = item.tool,
													amount = item.amount
												})
												if dropped then
													dropped:SetAttribute('ClientDropTime', tick() + 100)
												end
											end)
										end
									end
									if AutoReset.Enabled then
										task.delay(0.2, function()
											local hum = root.Parent and root.Parent:FindFirstChildOfClass('Humanoid')
											if hum then
												hum.Health = 0
											end
										end)
									end
								end
							end
						end
					else
						if lastVoidY and (not cachedLowestPoint or lastVoidY < cachedLowestPoint) then
							learnedDeathY = lastVoidY
						end
						lastVoidY = nil
						droppedThisLife = false
					end

					task.wait(0.05)
				until not AutoVoidDrop.Enabled
			end
		end,
		Tooltip = 'drops ur loot right before u die to the void'
	})
	
	OwlCheck = AutoVoidDrop:CreateToggle({
		Name = 'Owl check',
		Default = true,
		Tooltip = 'doesnt drop items if being picked up by an owl'
	})
	PearlCheck = AutoVoidDrop:CreateToggle({
		Name = 'Pearl check',
		Default = false,
		Tooltip = 'does not drop if holding a pearl or recently threw one (4 sec cooldown)'
	})
	AutoReset = AutoVoidDrop:CreateToggle({
		Name = 'Auto Reset',
		Default = false,
		Tooltip = 'resets ur character right after dropping all the loot gng'
	})
	DropToggles.iron = AutoVoidDrop:CreateToggle({
		Name = 'Drop Iron',
		Default = true
	})
	DropToggles.diamond = AutoVoidDrop:CreateToggle({
		Name = 'Drop Diamond',
		Default = true
	})
	DropToggles.emerald = AutoVoidDrop:CreateToggle({
		Name = 'Drop Emerald',
		Default = true
	})
	DropToggles.gold = AutoVoidDrop:CreateToggle({
		Name = 'Drop Gold',
		Default = true
	})
end)
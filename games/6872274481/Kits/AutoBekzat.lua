run(function()
	local AutoBekzat
	local Targets
	local Range
	local Delay
	local useAbilityEvent
	local sendFalconRemote
	local falconOut = false
	local lastSend = 0
	local lastStrike = 0

	task.spawn(function()
		task.wait()
		pcall(function()
			useAbilityEvent = replicatedStorage:WaitForChild('events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'):WaitForChild('useAbility')
		end)
		pcall(function()
			sendFalconRemote = replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged:WaitForChild('SendFalconRequested')
		end)
	end)

	local function sendFalcon(pos)
		if useAbilityEvent then
			pcall(function() useAbilityEvent:FireServer('SEND_FALCON', {target = pos}) end)
		end
	end

	local function strikeFalcon(pos)
		if sendFalconRemote then
			pcall(function() sendFalconRemote:FireServer({strikeZoneEpicenter = pos}) end)
		end
	end

	local function recallFalcon()
		if useAbilityEvent then
			pcall(function() useAbilityEvent:FireServer('RECALL_FALCON') end)
		end
	end

	AutoBekzat = vape.Categories.Kits:CreateModule({
		Name = 'AutoBekzat',
		Function = function(callback)
			if callback then
				falconOut = false
				lastSend = 0
				lastStrike = 0
				AutoBekzat:Clean(runService.Heartbeat:Connect(function()
					if not entitylib.isAlive then return end
					local target = entitylib.AllPosition({
						Range = Range.Value,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Limit = 1,
						Sort = sortmethods['Distance']
					})[1]

					local now = tick()
					if target and target.Character and target.RootPart then
						local exactPos = target.Character:GetPivot().Position
						if not falconOut then
							if (now - lastSend) >= 5 then
								sendFalcon(exactPos)
								falconOut = true
								lastSend = now
								lastStrike = 0
							end
						else
							if (now - lastStrike) >= Delay.Value then
								strikeFalcon(exactPos)
								lastStrike = now
							end
						end
					else
						if falconOut then
							recallFalcon()
							falconOut = false
						end
					end
				end))
			else
				if falconOut then
					recallFalcon()
					falconOut = false
				end
			end
		end,
		Tooltip = 'auto yeets ur falcon at enemies n keeps the strike right on em so it hits instant, calls it back when no ones around gng'
	})

	Targets = AutoBekzat:CreateTargets({
		Players = true,
		NPCs = true
	})

	Range = AutoBekzat:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 300,
		Default = 150,
		Suffix = 'studs'
	})

	Delay = AutoBekzat:CreateSlider({
		Name = 'Strike Delay',
		Min = 0.1,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Suffix = 's'
	})
end)
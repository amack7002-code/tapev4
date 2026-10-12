run(function()
	local AutoWin
	local previousStates
	local worker
	local status = 'Idle'

	local Minigames = vape.Categories and vape.Categories.Minigames
	if not Minigames or not Minigames.CreateModule then
		return
	end

	AutoWin = Minigames:CreateModule({
		Name = 'AutoWin',
		Function = function(callback)
			if callback then
				local Breaker = vape.Modules.Breaker
				local Killaura = vape.Modules.Killaura
				if not (Breaker and Killaura) then
					AutoWin:Toggle()
					notif('AutoWin', 'Breaker or Killaura is unavailable.', 5, 'alert')
					return
				end

				previousStates = {
					Breaker = Breaker.Enabled,
					Killaura = Killaura.Enabled
				}
				if not previousStates.Breaker then
					Breaker:Toggle()
				end
				if not previousStates.Killaura then
					Killaura:Toggle()
				end

				local eggs = collection('egg', AutoWin)
				local warnedNoTargets = false
				worker = task.spawn(function()
					while AutoWin.Enabled do
						if not entitylib.isAlive then
							status = 'Waiting for respawn'
							task.wait()
							continue
						end

						local root = entitylib.character and entitylib.character.RootPart
						if not root or not root.Parent then
							status = 'Waiting for character'
							task.wait()
							continue
						end
						local localTeamId = lplr:GetAttribute('TeamId')
						if localTeamId == nil then
							status = 'Waiting for team'
							task.wait()
							continue
						end
						local foundTarget = false
						local targetEgg
						local lowestHealth = math.huge
						for _, egg in eggs do
							if not egg.Parent or egg:GetAttribute('TeamId') == nil or egg:GetAttribute('TeamId') == localTeamId then
								continue
							end
							local health = egg:GetAttribute('Health')
							local eggRoot = egg:IsA('Model') and (egg.PrimaryPart or egg:FindFirstChildWhichIsA('BasePart')) or egg
							if eggRoot and eggRoot.Parent and typeof(health) == 'number' and health > 0 and health < lowestHealth then
								lowestHealth = health
								targetEgg = eggRoot
							end
						end

						if targetEgg then
							foundTarget = true
							status = 'Targeting egg'
							local targetPosition = targetEgg.Position
							if (root.Position - targetPosition).Magnitude > 6 then
								local destination = targetPosition - Vector3.new(0, 8, 0) -- under them
								root.CFrame = CFrame.lookAt(destination, targetPosition)
							end
						else
							local target
							local nearestDistance = math.huge
							for _, entity in entitylib.List do
								if entity.Player and entity.Targetable and (entity.Health or 0) > 0 and entity.RootPart and entity.RootPart.Parent then
									local targetPosition = entity.RootPart.Position
									if entity.Player:GetAttribute('InVoid') or entity.Player:GetAttribute('PlayerConnected') == false then continue end
									local distance = (root.Position - targetPosition).Magnitude
									if distance < nearestDistance then
										nearestDistance = distance
										target = entity.RootPart
									end
								end
							end
							if target then
								foundTarget = true
								status = 'Targeting player'
							end
							if target and nearestDistance > 6 then
								local targetPosition = target.Position
								local destination = targetPosition + Vector3.new(0, 10, 0) -- above them
								root.CFrame = CFrame.lookAt(destination, targetPosition)
							end
						end

						if foundTarget then
							warnedNoTargets = false
						else
							status = 'No eligible targets'
							if not warnedNoTargets then
								warnedNoTargets = true
								notif('AutoWin', 'No eligible targets. Waiting for enemy players or eggs to spawn.', 5, 'alert')
							end
						end
						task.wait(.00001) -- faster TP
					end
				end)
				local activeWorker = worker
				AutoWin:Clean(function()
					if coroutine.status(activeWorker) ~= 'dead' then task.cancel(activeWorker) end
				end)
			else
				if worker and coroutine.status(worker) ~= 'dead' then task.cancel(worker) end
				worker = nil
				status = 'Idle'
				if previousStates then
					local Breaker = vape.Modules.Breaker
					local Killaura = vape.Modules.Killaura
					if Breaker and not previousStates.Breaker and Breaker.Enabled then
						Breaker:Toggle()
					end
					if Killaura and not previousStates.Killaura and Killaura.Enabled then
						Killaura:Toggle()
					end
					previousStates = nil
				end
			end
		end,
		ExtraText = function() return status end,
		Tooltip = 'Automatically wins for you'
	})
end)
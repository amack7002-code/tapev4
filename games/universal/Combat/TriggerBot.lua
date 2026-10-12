run(function()
	local TriggerBot
	local Targets
	local ShootDelay
	local Distance
	local delayCheck = tick()
	local mouseClicked = false
	local inputService = game:GetService("UserInputService")

	local function getTriggerBotTarget()
		local char = lplr.Character
		if not char then return nil end
		local mousePos = inputService:GetMouseLocation()
		local ray = gameCamera:ViewportPointToRay(mousePos.X, mousePos.Y)

		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = {char, gameCamera}
		rayParams.FilterType = Enum.RaycastFilterType.Blacklist

		local hit = workspace:Raycast(ray.Origin, ray.Direction * Distance.Value, rayParams)
		if hit and hit.Instance then
			for _, v in ipairs(entitylib.List) do
				if v.Targetable and v.Character then
					local isTarget = (Targets.Players.Enabled and v.Player) or (Targets.NPCs.Enabled and v.NPC)
					if isTarget and entitylib.isVulnerable(v) then
						if hit.Instance:IsDescendantOf(v.Character) then
							return v
						end
					end
				end
			end
		end
		return nil
	end

	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				repeat
					if mouse1click and (isrbxactive or iswindowactive)() then
						local target = getTriggerBotTarget()
						if target and canClick() then
							if delayCheck < tick() then
								if mouseClicked then
									mouse1release()
									delayCheck = tick() + ShootDelay.Value
								else
									mouse1press()
								end
								mouseClicked = not mouseClicked
							end
						else
							if mouseClicked then
								mouse1release()
							end
							mouseClicked = false
						end
					end
					task.wait()
				until not TriggerBot.Enabled
			else
				if mouse1click and (isrbxactive or iswindowactive)() then
					if mouseClicked then
						mouse1release()
					end
				end
				mouseClicked = false
			end
		end,
		Tooltip = 'Shoots people that enter your crosshair'
	})

	Targets = TriggerBot:CreateTargets({
		Players = true,
		NPCs = true
	})
	ShootDelay = TriggerBot:CreateSlider({
		Name = 'Next Shot Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'The delay set after shooting a target'
	})
	Distance = TriggerBot:CreateSlider({
		Name = 'Distance',
		Min = 0,
		Max = 1000,
		Default = 1000,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
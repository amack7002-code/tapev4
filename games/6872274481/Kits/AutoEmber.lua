run(function()
	local AutoEmber
	local Targets
	local Range
	local SpinCooldown
	local HoldRange = 32
	local old = 0
	local isCharging = false
	local chargeAnim, FpChargeAnim = nil,nil
	AutoEmber = vape.Categories.Kits:CreateModule({
		Name = 'AutoEmber',
		Tooltip = 'automatically uses the ember ability',
		Function = function(call)
			if call then
				repeat
					if not entitylib.isAlive and isCharging then
						isCharging = false
						bedwars.HellSaberController.animationMaid:DoCleaning()
						chargeAnim = nil
						FpChargeAnim = nil
					end
					if entitylib.isAlive then 
						local tool = getItem('infernal_saber') 
						if tool then
							local ent = entitylib.EntityPosition({
								Range = HoldRange,
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Part = 'RootPart'
							}) 

							if not ent then
								if isCharging then
									isCharging = false
									bedwars.HellSaberController.animationMaid:DoCleaning()
									chargeAnim = nil
									FpChargeAnim = nil
									task.wait(0.3)
									continue
								end
							end

							if ent then
								if not isCharging then
									isCharging = true
									pcall(function()
										local hsc = bedwars.HellSaberController
										if hsc and type(hsc.playChargeSound) == 'function' then
											hsc:playChargeSound(lplr)
										end
									end)
									local animer = lplr.Character
									if animer ~= nil then
										animer = animer:FindFirstChild("Humanoid")
										if animer ~= nil then
											animer = animer:FindFirstChild("Animator")
										end
									end
									if not animer then
										isCharging = false
										task.wait(0.1)
										continue
									end
									chargeAnim = animer:LoadAnimation(bedwars.GameAnimationUtil:getAnimation(bedwars.AnimationType.INFERNO_SWORD_CHARGE))
									chargeAnim:Play()
									chargeAnim:AdjustSpeed(1.83)
									chargeAnim:GetMarkerReachedSignal("end"):Connect(function()
										local newChargeAnim = chargeAnim
										if newChargeAnim ~= nil then
											newChargeAnim:AdjustSpeed(0)
										end
									end)
									FpChargeAnim = bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_INFERNO_SWORD_CHARGE)
									if FpChargeAnim then
										FpChargeAnim:GetMarkerReachedSignal("end"):Connect(function()
											local newFpChargeAnim = FpChargeAnim
											if newFpChargeAnim ~= nil then
												newFpChargeAnim:AdjustSpeed(0)
											end
										end)
									end
									bedwars.HellSaberController.animationMaid:GiveTask(function()
										local MaidCA1 = chargeAnim
										if MaidCA1 ~= nil then
											MaidCA1:Stop()
										end
										local MaidCA2 = chargeAnim
										if MaidCA2 ~= nil then
											MaidCA2:Destroy()
										end
										local MaidFCA1 = FpChargeAnim
										if MaidFCA1 ~= nil then
											MaidFCA1:Stop()
										end
										local MaidFCA2 = FpChargeAnim
										if MaidFCA2 ~= nil then
											MaidFCA2:Destroy()
										end
									end)
								end
								local DeltaPos = (ent.RootPart.Position - lplr.Character.HumanoidRootPart.Position).Magnitude
								if DeltaPos <= Range.Value then
									if (os.clock() - old) >= SpinCooldown.Value then
										bedwars.HellSaberController.animationMaid:DoCleaning()
										switchItem(tool)
										bedwars.Client:Get('HellBladeRelease'):SendToServer({
											chargeTime = 1 + tick() - (0.045 + (math.random() - math.random())), 
											weapon = tool,
											player = lplr
										})
										old = os.clock()
										bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_INFERNO_SWORD_SPIN)										
										isCharging = false
										
									end
								end
							end
						end
					end
					task.wait(0.03)
				until not AutoEmber.Enabled
				isCharging = false
				bedwars.HellSaberController.animationMaid:DoCleaning()
				chargeAnim = nil
				FpChargeAnim = nil 
			end
		end
	})
	Targets = AutoEmber:CreateTargets({
		Players = true,
		NPCs = false
	})
	SpinCooldown = AutoEmber:CreateSlider({
		Name = 'Spin Cooldown',
		Min = 0,
		Max = 4,
		Default = 1.12,
		Decimal = 100,
		Tooltip = 'how long it waits b4 spinning again. keep it above 0.2 or u finna get banned'
	})
	Range = AutoEmber:CreateSlider({
		Name = 'Release Range',
		Min = 1,
		Max = 22,
		Default = 22,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
end)
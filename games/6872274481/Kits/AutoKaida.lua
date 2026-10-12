run(function()
	local KaidaKillaura	
	local Targets
	local AttackRange
	local UpdateRate
	local MouseDown
	local GUICheck
	local ShowAnimation
	local AutoAbility
	local AbilityDistance
	local SwingDuringAbility
	local lastAttackTime = 0
	local lastAbilityTime = 0
	local attackCooldown = 0.55
	local abilityCooldown = 22
	local isChargingAbility = false
	manualCharging = false
	local currentTarget = nil
	local AutoStopAbility
	local SummonerKitController = nil
	local function getSummonerController()
		if SummonerKitController then return SummonerKitController end
		pcall(function()
			SummonerKitController = bedwars.KnitClient.Controllers.SummonerKitController
		end)
		return SummonerKitController
	end

	local function isActuallyCharging()
		if isChargingAbility then return true end
		if manualCharging then return true end
		local result = false
		pcall(function()
			local btns = lplr.PlayerGui
				:FindFirstChild("ActionBarScreenGui")
				and lplr.PlayerGui.ActionBarScreenGui:FindFirstChild("ActionBar")
				and lplr.PlayerGui.ActionBarScreenGui.ActionBar:FindFirstChild("AbilityButtons")
			if btns and btns:FindFirstChild("summoner_finish_charging") then
				result = true
			end
		end)
		return result
	end

	local function getSpellLevel()
		local level = 1
		pcall(function()
			local util = require(game:GetService("ReplicatedStorage").TS.games.bedwars.kit.kits.summoner['summoner-kit-util'])
			local result = util.summoner_getPlayerSpellLevel(lplr)
			if result then level = result end
		end)
		return level
	end

	local function getCastTime(level)
		local castTime = 2
		pcall(function()
			local util = require(game:GetService("ReplicatedStorage").TS.games.bedwars.kit.kits.summoner['summoner-kit-util'])
			local result = util.summoner_getTotalCastTimeRequired(level)
			if result then castTime = result end
		end)
		return castTime
	end

	local function fireUseAbility(abilityName)
		pcall(function()
			game:GetService("ReplicatedStorage")
				:WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events")
				:WaitForChild("useAbility"):FireServer(abilityName)
		end)
	end

	local function doAutoAbility()
		if isChargingAbility then return end
		isChargingAbility = true

		pcall(function()
			local remote = game:GetService("ReplicatedStorage")
				:WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events")
				:WaitForChild("useAbility")

			remote:FireServer(unpack({"summoner_start_charging"}))

			if AutoStopAbility.Enabled then
				task.wait(0.5)
				remote:FireServer(unpack({"summoner_finish_charging"}))
			else
				local level = getSpellLevel()
				local castTime = getCastTime(level)
				task.wait(math.max(castTime, 0.5))
				if isChargingAbility then
					remote:FireServer(unpack({"summoner_finish_charging"}))
					if currentTarget and currentTarget.RootPart then
						local myPos = entitylib.character.RootPart.Position
						local shootDir = CFrame.lookAt(myPos, currentTarget.RootPart.Position).LookVector
						local localPosition = myPos + shootDir * math.max((myPos - currentTarget.RootPart.Position).Magnitude - 16, 0)
						bedwars.Client:Get(remotes.SummonerClawAttack):SendToServer({
							position = localPosition,
							direction = shootDir,
							clientTime = workspace:GetServerTimeNow()
						})
					end
				end
			end
		end)

		lastAbilityTime = tick()
		isChargingAbility = false
	end

	local function getPlayerClawLevel()
		local handItem = lplr.Character and lplr.Character:FindFirstChild('HandInvItem')
		if handItem and handItem.Value then
			local itemType = handItem.Value.Name
			if itemType == 'summoner_claw_1' then return 1 end
			if itemType == 'summoner_claw_2' then return 2 end
			if itemType == 'summoner_claw_3' then return 3 end
			if itemType == 'summoner_claw_4' then return 4 end
		end
		if store and store.inventory and store.inventory.hotbar then
			for _, v in pairs(store.inventory.hotbar) do
				if v.item then
					local itemType = v.item.itemType
					if itemType == 'summoner_claw_1' then return 1 end
					if itemType == 'summoner_claw_2' then return 2 end
					if itemType == 'summoner_claw_3' then return 3 end
					if itemType == 'summoner_claw_4' then return 4 end
				end
			end
		end
		return 1
	end

	KaidaKillaura = vape.Categories.Kits:CreateModule({
		Name = 'AutoKaida',
		Function = function(callback)
			if callback then
				lastAttackTime = 0
				lastAbilityTime = 0
				isChargingAbility = false
				manualCharging = false   
				pcall(function()
					local abilityButtons = lplr.PlayerGui
						:WaitForChild("ActionBarScreenGui", 10)
						:WaitForChild("ActionBar", 10)
						:WaitForChild("AbilityButtons", 10)

					KaidaKillaura:Clean(abilityButtons.ChildRemoved:Connect(function(child)
						if child.Name == "summoner_start_charging" then
							manualCharging = true
						end
						if child.Name == "summoner_finish_charging" then
							manualCharging = false
						end
					end))

					KaidaKillaura:Clean(abilityButtons.ChildAdded:Connect(function(child)
						if child.Name == "summoner_start_charging" then
							manualCharging = false
						end
					end))

					if abilityButtons:FindFirstChild("summoner_finish_charging") then
						manualCharging = true
					end
				end)

				repeat
					if not entitylib.isAlive then
						task.wait(0.1)
						continue
					end

					if GUICheck.Enabled then
						if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
							task.wait(0.1)
							continue
						end
					end

					local handItem = lplr.Character:FindFirstChild('HandInvItem')
					local hasClaw = handItem and handItem.Value and handItem.Value.Name:find('summoner_claw') ~= nil

					if MouseDown.Enabled then
						if not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
							task.wait(1.2)
							continue
						end
					end

					local plr = nil
					do
						local bestDot = -math.huge
						local camCF = workspace.CurrentCamera.CFrame
						local myPos = entitylib.character.RootPart.Position
						for _, ent in ipairs(entitylib.List) do
							local validType = (Targets.Players.Enabled and ent.Player) or (Targets.NPCs.Enabled and ent.NPC)
							if validType and ent.Targetable and ent.RootPart and ent.Health > 0 then
								local dist = (myPos - ent.RootPart.Position).Magnitude
								if dist <= AttackRange.Value then
									local toEnt = (ent.RootPart.Position - camCF.Position).Unit
									local dot = camCF.LookVector:Dot(toEnt)
									if dot <= 0 then continue end
									if dot > bestDot then
										bestDot = dot
										plr = ent
									end
								end
							end
						end
					end

					if plr and plr.Health > 0 then
						local localPosition = entitylib.character.RootPart.Position
						local targetDistance = (localPosition - plr.RootPart.Position).Magnitude
						local now = tick()

						if AutoAbility.Enabled and targetDistance <= AbilityDistance.Value * 1.25 then
							if not isChargingAbility and (now - lastAbilityTime) >= abilityCooldown then
								currentTarget = plr
								task.spawn(doAutoAbility)
							end
						end

						if not SwingDuringAbility.Enabled then
							local active = false
							for _, v in workspace:QueryDescendants('#Summoner_SummonCircle') do
								local pivot = v:FindFirstChild('Pivot')
								if pivot and math.floor(pivot.Position.X) == math.floor(entitylib.character.RootPart.Position.X) and math.floor(pivot.Position.Z) == math.floor(entitylib.character.RootPart.Position.Z) then
									active = true
									break
								end
							end
							if active then
								task.wait()
								continue
							end
						end

						if not SwingDuringAbility.Enabled and isChargingAbility then
							task.wait(0.05)
							continue
						end

						if hasClaw then
							local charging = isActuallyCharging()

							if not SwingDuringAbility.Enabled and charging then
								task.wait(0.05)
								continue
							end

							if (now - lastAttackTime) >= attackCooldown and targetDistance <= AttackRange.Value then
								local shootDir = CFrame.lookAt(localPosition, plr.RootPart.Position).LookVector
								localPosition += shootDir * math.max((localPosition - plr.RootPart.Position).Magnitude - 16, 0)
								lastAttackTime = now

								if ShowAnimation.Enabled then
									task.spawn(function()
										pcall(function()
											local clawLevel = getPlayerClawLevel()
											bedwars.AnimationUtil:playAnimation(lplr, bedwars.GameAnimationUtil:getAssetId(bedwars.AnimationType.SUMMONER_CHARACTER_SWIPE), {
												looped = false
											})
											local clawModel = replicatedStorage.Assets.Misc.Kaida.Summoner_DragonClaw:Clone()
											local clawColors = {
												Color3.fromRGB(75, 75, 75),
												Color3.fromRGB(255, 255, 255),
												Color3.fromRGB(43, 229, 229),
												Color3.fromRGB(49, 229, 94)
											}
											local nailMesh = clawModel:FindFirstChild("dragon_claw_nail_mesh")
											if nailMesh and nailMesh:IsA("MeshPart") then
												nailMesh.Color = clawColors[clawLevel] or clawColors[1]
											end
											if bedwars.KnightClient and bedwars.KnightClient.Controllers.SummonerKitSkinController then
												if bedwars.KnightClient.Controllers.SummonerKitSkinController:isPrismaticSkin(lplr) then
													bedwars.KnightClient.Controllers.SummonerKitSkinController:applyClawRGB(clawModel)
												end
											end
											clawModel.Parent = workspace
											local camera = workspace.CurrentCamera
											if camera and (camera.CFrame.Position - entitylib.character.RootPart.Position).Magnitude < 1 then
												for _, part in clawModel:GetDescendants() do
													if part:IsA('MeshPart') then
														part.Transparency = 0.6
													end
												end
											end
											local rootPart = entitylib.character.RootPart
											local Unit = Vector3.new(shootDir.X, 0, shootDir.Z).Unit
											local startPos = rootPart.Position + Unit:Cross(Vector3.new(0, 1, 0)).Unit * -1 * 5 + Unit * 6
											local direction = (startPos + shootDir * 13 - startPos).Unit
											local cframe = CFrame.new(startPos, startPos + direction)
											clawModel:PivotTo(cframe)
											clawModel.PrimaryPart.Anchored = true
											local portalConn = nil
											if clawModel:FindFirstChild("Portal1") then
												portalConn = runService.Heartbeat:Connect(function()
													if not clawModel or not clawModel.Parent then
														portalConn:Disconnect()
														portalConn = nil
														return
													end
													local foreArmCF = clawModel.RootPart.root.fore_arm.TransformedWorldCFrame
													if clawModel.Portal1 then
														clawModel.Portal1:PivotTo(foreArmCF)
													end
													if clawModel.Portal2 then
														clawModel.Portal2:PivotTo(foreArmCF * CFrame.Angles(math.pi, 0, 0))
													end
												end)
											end
											if clawModel:FindFirstChild('AnimationController') then
												local animator = clawModel.AnimationController:FindFirstChildOfClass('Animator')
												if animator then
													bedwars.AnimationUtil:playAnimation(animator, bedwars.GameAnimationUtil:getAssetId(bedwars.AnimationType.SUMMONER_CLAW_ATTACK), {
														looped = false,
														speed = 1
													})
												end
											end
											pcall(function()
												local sounds = {
													bedwars.SoundList.SUMMONER_CLAW_ATTACK_1,
													bedwars.SoundList.SUMMONER_CLAW_ATTACK_2,
													bedwars.SoundList.SUMMONER_CLAW_ATTACK_3,
													bedwars.SoundList.SUMMONER_CLAW_ATTACK_4
												}
												bedwars.SoundManager:playSound(sounds[math.random(1, #sounds)], {
													position = rootPart.Position
												})
											end)
											task.wait(0.5)
											if portalConn then
												portalConn:Disconnect()
												portalConn = nil
											end
											clawModel:Destroy()
										end)
									end)
								end

								bedwars.Client:Get(remotes.SummonerClawAttack):SendToServer({
									position = localPosition,
									direction = shootDir,
									clientTime = workspace:GetServerTimeNow()
								})
							end
						end
					else
						if isChargingAbility then
							isChargingAbility = false
							fireUseAbility("summoner_finish_charging")
						end
					end

					task.wait(1 / UpdateRate.Value)
				until not KaidaKillaura.Enabled

				isChargingAbility = false
			end
		end,
		Tooltip = 'auto attacks players with kaida claw'
	})

	Targets = KaidaKillaura:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})

	AttackRange = KaidaKillaura:CreateSlider({
		Name = 'Attack Range',
		Min = 1,
		Max = 32,
		Default = 22,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	UpdateRate = KaidaKillaura:CreateSlider({
		Name = 'Update Rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})

	MouseDown = KaidaKillaura:CreateToggle({
		Name = 'Require Mouse Down',
	})

	GUICheck = KaidaKillaura:CreateToggle({
		Name = 'GUI Check'
	})

	ShowAnimation = KaidaKillaura:CreateToggle({
		Name = 'Show Animation',
		Default = true
	})

	SwingDuringAbility = KaidaKillaura:CreateToggle({
		Name = 'Swing During Ability',
		Default = true,
	})

	AutoAbility = KaidaKillaura:CreateToggle({
		Name = 'Auto Ability',
		Default = false,
		Function = function(callback)
			if not callback then
				isChargingAbility = false
			end
			AbilityDistance.Object.Visible = callback
			AutoStopAbility.Object.Visible = callback
		end
	})

	AbilityDistance = KaidaKillaura:CreateSlider({
		Name = 'Ability Distance',
		Min = 3,
		Max = 15,
		Default = 6,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	AutoStopAbility = KaidaKillaura:CreateToggle({
		Name = 'Auto Stop Ability',
		Default = true,
		Visible = false,
	})

	task.defer(function()
		if AbilityDistance and AbilityDistance.Object then
			AbilityDistance.Object.Visible = false   
		end
	end)
end)
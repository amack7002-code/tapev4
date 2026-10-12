run(function()
	local ProjectileAura
	local Targets
	local Range
	local List
	local HandCheck
	local FireSpeed
    local rayCheck = cloneRaycast()
	local projectileRemote = {InvokeServer = function() end}
	local FireDelays = {}
	task.spawn(function()
		projectileRemote = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('ProjectileFire')
	end)
	
	local function getAmmo(check)
		for _, item in store.inventory.inventory.items do
			if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
				return item.itemType
			end
		end
	end
	
	local function getProjectiles()
		local items = {}
		for _, item in store.inventory.inventory.items do
			local proj = bedwars.ItemMeta[item.itemType].projectileSource
			local ammo = proj and getAmmo(proj)
			if ammo and table.find(List.ListEnabled, ammo) then
				table.insert(items, {
					item,
					ammo,
					proj.projectileType(ammo),
					proj
				})
			end
		end
		return items
	end
	
	ProjectileAura = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAura',
		Function = function(callback)
			if callback then
				repeat
					local holdingCrossbow = store.hand and store.hand.tool and store.hand.tool.Name:find('crossbow')
					local holdingBow = store.hand and store.hand.tool and store.hand.tool.Name:find('bow')
					
					if HandCheck.Enabled and not holdingCrossbow and not holdingBow then
						task.wait(0.1)
						continue
					end
					
					if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.5 then
						local ent = entitylib.EntityPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						})
	
						if ent then
							local pos = entitylib.character.RootPart.Position
							for _, data in getProjectiles() do
								local item, ammo, projectile, itemMeta = unpack(data)
								if (FireDelays[item.itemType] or 0) < tick() then
									rayCheck.FilterDescendantsInstances = {workspace.Map}
									local meta = bedwars.ProjectileMeta[projectile]
									local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
									local lifetime = tonumber(meta.predictionLifetimeSec) or tonumber(meta.lifetimeSec) or (projSpeed > 0 and math.min(3, 120 / projSpeed) or 3)
									local entGravity = workspace.Gravity
									local balloons = ent.Character and ent.Character:GetAttribute('InflatedBalloons')
									if balloons and balloons > 0 then
										entGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
									end
									local entVel = ent.RootPart.AssemblyLinearVelocity or ent.RootPart.Velocity or Vector3.zero
									local entAirborne = (ent.Humanoid and ent.Humanoid.FloorMaterial == Enum.Material.Air) or math.abs(entVel.Y) > 0.01
									local calc = prediction.SolveTrajectory(pos, projSpeed, gravity, ent.RootPart.Position, entVel, entGravity, ent.HipHeight, ent.Jumping and 42.6 or nil, rayCheck, entAirborne, ent.RootPart.Position, ent.RootPart, nil, true)
									if calc then
										targetinfo.Targets[ent] = tick() + 1
										local switched = switchItem(item.tool)
	
										task.spawn(function()
											local shootPosition = (CFrame.new(pos, calc) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
											local aimFromShoot = prediction.SolveTrajectory(shootPosition, projSpeed, gravity, ent.RootPart.Position, entVel, entGravity, ent.HipHeight, ent.Jumping and 42.6 or nil, rayCheck, entAirborne, ent.RootPart.Position, ent.RootPart, nil, true) or calc
											local dir, id = CFrame.lookAt(shootPosition, aimFromShoot).LookVector, httpService:GenerateGUID(true)
											
											if holdingCrossbow then
												bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_CROSSBOW_FIRE)
												bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.CROSSBOW_FIRE)
											elseif holdingBow then
												bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_CROSSBOW_FIRE)
												bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.BOW_FIRE)
											else
												local shootAnim = bedwars.ItemMeta[item.tool.Name].thirdPerson and bedwars.ItemMeta[item.tool.Name].thirdPerson.shootAnimation
												if shootAnim then
													bedwars.GameAnimationUtil:playAnimation(lplr, shootAnim)
												end
											end
											
											bedwars.ProjectileController:createLocalProjectile(meta, ammo, projectile, shootPosition, id, dir * projSpeed, {drawDurationSeconds = 1})
											local res = projectileRemote:InvokeServer(item.tool, ammo, projectile, shootPosition, pos, dir * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
											if not res then
												FireDelays[item.itemType] = tick()
											else
												pcall(prediction.trackShot, ent.RootPart)
												local shoot = itemMeta.launchSound
												shoot = shoot and shoot[math.random(1, #shoot)] or nil
												if shoot then
													bedwars.SoundManager:playSound(shoot)
												end
											end
										end)
	
										FireDelays[item.itemType] = tick() + ((tonumber(itemMeta.fireDelaySec) or 0.5) / FireSpeed.Value)
										if switched then
											task.wait(0.05)
										end
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not ProjectileAura.Enabled
			end
		end,
		Tooltip = 'Shoots people around you with viewmodel animations'
	})
	Targets = ProjectileAura:CreateTargets({
		Players = true,
		Walls = true
	})
	List = ProjectileAura:CreateTextList({
		Name = 'Projectiles',
		Default = {'arrow', 'snowball'}
	})
	Range = ProjectileAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 50,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	FireSpeed = ProjectileAura:CreateSlider({
		Name = 'Fire Speed',
		Min = 0.5,
		Max = 3,
		Default = 1,
		Decimal = 10,
	})
	HandCheck = ProjectileAura:CreateToggle({
		Name = 'Hand Check',
		Default = false,
		Tooltip = 'Only shoot when holding a bow or crossbow'
	})
end)
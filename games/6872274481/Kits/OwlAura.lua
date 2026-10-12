run(function()
	local OwlAura
	local OwlTargets
	local RangeSlider
	local PROJECTILE_SPEED = 220
	local SHOOT_COOLDOWN = 0.87
	local lastOwlShot = 0

	local function getOwlModel()
		return workspace:FindFirstChild("ClientOwl")
	end

	local function getBulletOrigin(owl)
		local primary = owl and owl.PrimaryPart
		if not primary then return nil end
		local bo = primary:FindFirstChild("bulletOrigin")
		return bo and bo.WorldPosition or primary.Position
	end

	local function fireOwlProjectile(fromPos, targetPos)
		local owl = getOwlModel()
		if not owl then return end
		local owlHandle = owl:FindFirstChild("Handle") or owl.PrimaryPart
		if not owlHandle then return end

		local rbxts = replicatedStorage:FindFirstChild("rbxts_include")
		local netManaged = rbxts
			and rbxts:FindFirstChild("node_modules")
			and rbxts.node_modules:FindFirstChild("@rbxts")
			and rbxts.node_modules["@rbxts"]:FindFirstChild("net")
			and rbxts.node_modules["@rbxts"].net:FindFirstChild("out")
			and rbxts.node_modules["@rbxts"].net.out:FindFirstChild("_NetManaged")
		if not netManaged then return end

		local owlAiming = netManaged:FindFirstChild("OwlAiming")
		local owlFire = netManaged:FindFirstChild("OwlFireProjectile")
		if not owlAiming or not owlFire then return end

		local direction = (targetPos - fromPos).Unit * PROJECTILE_SPEED
		local refId = httpService:GenerateGUID(false):sub(1, 8):upper()

		owlAiming:FireServer({ owl = owlHandle, starting = true })
		task.wait(0.05)
		owlAiming:FireServer({ owl = owlHandle, starting = false })
		owlFire:FireServer({
			fromPosition = fromPos,
			direction = direction,
			offset = nil,
			ProjectileRefId = refId,
			initialVelocity = direction
		})
	end

	OwlAura = vape.Categories.Kits:CreateModule({
		Name = 'OwlAura',
		Function = function(callback)
			if callback then
				lastOwlShot = 0
				OwlAura:Clean(runService.Heartbeat:Connect(function()
					if tick() - lastOwlShot < SHOOT_COOLDOWN then return end
					if not entitylib.isAlive then return end

					local owl = getOwlModel()
					local myRoot = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")
					if not myRoot then return end
					local fromPos = owl and getBulletOrigin(owl) or myRoot.Position

					local ent = entitylib.EntityPosition({
						Range = RangeSlider and RangeSlider.Value or 40,
						Part = 'RootPart',
						Wallcheck = OwlTargets and OwlTargets.Walls and OwlTargets.Walls.Enabled,
						Players = OwlTargets and OwlTargets.Players and OwlTargets.Players.Enabled,
						NPCs = OwlTargets and OwlTargets.NPCs and OwlTargets.NPCs.Enabled,
					})

					if not ent or not ent.RootPart then return end

					local rootPos = ent.RootPart.Position
					local vel = ent.RootPart.AssemblyLinearVelocity or ent.RootPart.Velocity or Vector3.zero
					local dist = (fromPos - rootPos).Magnitude
					local predictedPos = rootPos + vel * (dist / PROJECTILE_SPEED)

					lastOwlShot = tick()
					fireOwlProjectile(fromPos, predictedPos)
				end))
			end
		end
	})

	OwlTargets = OwlAura:CreateTargets({
		Players = true,
		NPCs = false,
		Walls = true
	})
	RangeSlider = OwlAura:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 60,
		Default = 40,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
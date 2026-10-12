run(function()
	local AutoExplode
	local Explosives = setmetatable({}, {__mode = 'k'})
	local LastDetonate = 0

	local UseAbility = replicatedStorage
		:WaitForChild('events-@easy-games/game-core:shared/game-core-networking@getEvents.Events')
		:WaitForChild('useAbility')

	local function GetTrapType(Trap)
		local Type = tostring(
			Trap:GetAttribute('trapType')
				or Trap:GetAttribute('TrapType')
				or Trap:GetAttribute('Type')
				or ''
		):lower()

		if Type:find('explosive', 1, true)
			or Trap.Name:lower():find('explosive', 1, true)
			or Trap:FindFirstChild('explosive_trap', true) then
			return 'explosive_trap'
		end
	end

	local function IsMine(Trap)
		local Owner = tonumber(
			Trap:GetAttribute('PlacedByUserId')
				or Trap:GetAttribute('OwnerUserId')
				or Trap:GetAttribute('PlayerUserId')
				or Trap:GetAttribute('ownerId')
		)

		if Owner then
			return Owner == lplr.UserId
		end

		local Team = Trap:GetAttribute('TrapperTeamId')
			or Trap:GetAttribute('TeamId')

		if Team ~= nil then
			return tostring(Team) == tostring(lplr:GetAttribute('Team'))
				or lplr.Team and tostring(Team) == tostring(lplr.Team.Name)
		end

		return false
	end

	local function GetPart(Trap)
		if Trap:IsA('BasePart') then
			return Trap
		end

		if Trap:IsA('Model') then
			return Trap.PrimaryPart
				or Trap:FindFirstChild('RootPart', true)
				or Trap:FindFirstChildWhichIsA('BasePart', true)
		end

		return Trap:FindFirstChildWhichIsA('BasePart', true)
	end

	local function GetRadius(Trap)
		for _, Name in {
			'TriggerRadius',
			'DetonationRadius',
			'ExplosionRadius',
			'ActivationRadius',
			'Radius'
		} do
			local Value = tonumber(Trap:GetAttribute(Name))

			if Value and Value > 0 then
				return Value
			end
		end

		local Radius = 0

		for _, Part in Trap:GetDescendants() do
			if not Part:IsA('BasePart') then
				continue
			end

			local Name = Part.Name:lower()

			if Name:find('radius', 1, true)
				or Name:find('range', 1, true)
				or Name:find('circle', 1, true)
				or Name:find('trigger', 1, true)
				or Name:find('hitbox', 1, true) then

				Radius = math.max(
					Radius,
					math.max(Part.Size.X, Part.Size.Z) / 2
				)
			end
		end

		return Radius > 0 and Radius or 8
	end

	local function Track(Trap)
		task.wait()

		if not Trap.Parent then
			return
		end

		if GetTrapType(Trap) ~= 'explosive_trap' then
			return
		end

		if IsMine(Trap) then
			Explosives[Trap] = true
		end
	end

	local function SameTeam(Player)
		local Team = lplr:GetAttribute('Team')
		local Other = Player:GetAttribute('Team')

		if Team ~= nil and Other ~= nil then
			return Team == Other
		end

		return lplr.Team and Player.Team == lplr.Team
	end

	local function EnemyInside(Position, Radius)
		for _, Player in playersService:GetPlayers() do
			if Player == lplr or SameTeam(Player) then
				continue
			end

			local Character = Player.Character
			local Root = Character and Character:FindFirstChild('HumanoidRootPart')
			local Humanoid = Character and Character:FindFirstChildOfClass('Humanoid')

			if Root
				and Humanoid
				and Humanoid.Health > 0
				and (Root.Position - Position).Magnitude <= Radius then
				return true
			end
		end

		return false
	end

	AutoExplode = vape.Categories.Kits:CreateModule({
		Name = 'AutoExplode',
		Function = function(Callback)
			if Callback then
				table.clear(Explosives)
				LastDetonate = 0

				AutoExplode:Clean(
					collectionService:GetInstanceAddedSignal('trapper_trap'):Connect(Track)
				)

				AutoExplode:Clean(
					collectionService:GetInstanceRemovedSignal('trapper_trap'):Connect(function(Trap)
						Explosives[Trap] = nil
					end)
				)

				for _, Trap in collectionService:GetTagged('trapper_trap') do
					task.spawn(Track, Trap)
				end

				repeat
					if tick() >= LastDetonate then
						for Trap in Explosives do
							if not Trap.Parent then
								Explosives[Trap] = nil
								continue
							end

							local Part = GetPart(Trap)

							if not Part then
								continue
							end

							if EnemyInside(Part.Position, GetRadius(Trap)) then
								LastDetonate = tick() + 0.25

								pcall(function()
									UseAbility:FireServer('trapper_detonate')
								end)

								break
							end
						end
					end

					task.wait(0.03)
				until not AutoExplode.Enabled
			else
				table.clear(Explosives)
			end
		end,
		Tooltip = 'explodes ur trap when somebody walks into its circle - trapper kit'
	})
end)
run(function()
	local Velocity
	local Horizontal
	local Vertical
	local Chance
	local Targeting
	local connection, old
	local attribute
	local rand = Random.new()

	local function scaled(velocity)
		if rand:NextNumber(0, 100) > Chance.Value then return velocity end
		if Targeting.Enabled and not entitylib.EntityPosition({Range = 50, Part = 'RootPart', Players = true}) then return velocity end
		local hort, vert = Horizontal.Value / 100, Vertical.Value / 100
		if hort == 0 and vert == 0 then return nil end
		return Vector3.new(velocity.X * hort, velocity.Y * vert, velocity.Z * hort)
	end

	local function handler(part, velocity, ...)
		if typeof(velocity) == 'Vector3' then
			velocity = scaled(velocity)
			if not velocity then return end
		end
		return old(part, velocity, ...)
	end

	-- the game's own knockback listener, picked out by the script it lives in
	local function knockbackConnection()
		local list = getconnections(remotes.Knockback.OnClientEvent)
		for _, v in list do
			local ok, source = pcall(debug.info, v.Function, 's')
			if ok and type(source) == 'string' and source:find('KnockbackScript') then
				return v
			end
		end
		return #list == 1 and list[1] or nil
	end

	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Function = function(callback)
			if callback then
				if hookfunction and getconnections then
					connection = knockbackConnection()
					if connection and connection.Function then
						old = hookfunction(connection.Function, function(...)
							return handler(...)
						end)
						return
					end
					connection = nil
				end

				-- no hooks: the game skips knockback while this attribute is set, so it is all or nothing
				notif('Velocity', 'Your executor cannot hook the knockback handler, so knockback is removed completely instead of scaled.', 8, 'warning')
				attribute = true
				repeat
					if entitylib.isAlive and not entitylib.character.Humanoid:GetAttribute('KnockbackDisabled') then
						entitylib.character.Humanoid:SetAttribute('KnockbackDisabled', true)
					end
					task.wait(0.2)
				until not Velocity.Enabled
			else
				if old and connection then
					hookfunction(connection.Function, old)
				end
				old, connection = nil, nil
				if attribute then
					attribute = nil
					if entitylib.isAlive then
						entitylib.character.Humanoid:SetAttribute('KnockbackDisabled', nil)
					end
				end
			end
		end,
		Tooltip = 'Reduces knockback taken'
	})
	Horizontal = Velocity:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%'
	})
	Vertical = Velocity:CreateSlider({
		Name = 'Vertical',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%'
	})
	Chance = Velocity:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	Targeting = Velocity:CreateToggle({Name = 'Only when targeting'})
end)

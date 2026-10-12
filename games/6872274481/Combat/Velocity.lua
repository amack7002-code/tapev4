run(function()
	local Velocity
	local Vertical
	local Horizontal
	local Mode
	local DelayGround
	local DelayAir
	local Targetting
	local Chance
	local old = nil
	local rand = Random.new()
	local hook
	local generation = 0

	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Tooltip = 'control you to edit ur knockback',
		Function = function(callback)
			if callback then
				old = bedwars.KnockbackUtil.applyKnockback
				generation += 1
				local currentGeneration = generation
				local original = old
				Velocity:Clean(vapeEvents.TakeKnockback.Event:Connect(function(root, mass, dir, knockback, ...)
					local args = table.pack(...)
					local clone = table.clone(knockback)
					local function delayedComponent(component, delay)
						task.delay(delay / 1000, function()
							local character = entitylib.character
							if generation ~= currentGeneration or not Velocity.Enabled or not entitylib.isAlive
								or not root or not root.Parent or not character or character.RootPart ~= root then return end
							local delayed = table.clone(clone)
							delayed.horizontal = component == 'horizontal' and (clone.horizontal or 1) or 0
							delayed.vertical = component == 'vertical' and (clone.vertical or 1) or 0
							original(root, mass, dir, delayed, table.unpack(args, 1, args.n))
						end)
					end
					delayedComponent('horizontal', DelayAir.Value)
					delayedComponent('vertical', DelayGround.Value)
				end))

				hook = function(root, mass, dir, knockback, ...)
					local character = entitylib.character
					if not entitylib.isAlive or not character or character.RootPart ~= root then
						return original(root, mass, dir, knockback, ...)
					end
					local chance = rand:NextNumber(0, 100)
					if Mode.Value == 'Default' then
						if chance >= Chance.Value then return original(root, mass, dir, knockback, ...) end
					end
						
					local check = (not Targetting.Enabled) or entitylib.EntityPosition({
						Range = 20,
						Part = 'RootPart',
						Players = true
					})
		
					if check then
						knockback = table.clone(knockback or {})
						if Mode.Value == 'Lag' then
							if chance < Chance.Value then
								return vapeEvents.TakeKnockback:Fire(root, mass, dir, knockback, ...)
							end
						else
							if Horizontal.Value == 0 and Vertical.Value == 0 then return end
							knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
							knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
						end
					end
						
					return original(root, mass, dir, knockback, ...)
				end
				bedwars.KnockbackUtil.applyKnockback = hook
			else
				generation += 1
				if bedwars.KnockbackUtil.applyKnockback == hook then
					bedwars.KnockbackUtil.applyKnockback = old
				end
				old, hook = nil, nil
			end
		end
	})
	Mode = Velocity:CreateDropdown({
		Name = "Mode",
		List = {'Lag','Default'},
		Function = function(val)
			local isDefault = val == 'Default'
			if Horizontal then Horizontal.Object.Visible = isDefault end
			if Vertical then Vertical.Object.Visible = isDefault end
			if DelayGround then DelayGround.Object.Visible = not isDefault end
			if DelayAir then DelayAir.Object.Visible = not isDefault end
		end
	})
	Vertical = Velocity:CreateSlider({
		Name = "Vertical",
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 1,
		Visible = (Mode.Value == 'Default')
	})
	Horizontal = Velocity:CreateSlider({
		Name = "Horizontal",
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 1,
		Visible = (Mode.Value == 'Default')
	})
	DelayGround = Velocity:CreateSlider({
		Name = "Delay Ground",
		Min = 0,
		Max = 3000,
		Default = 1000,
		Suffix = 'ms',
		Decimal = 1,
		Visible = (Mode.Value == 'Lag')
	})
	DelayAir = Velocity:CreateSlider({
		Name = "Delay Air",
		Min = 0,
		Max = 3000,
		Default = 1000,
		Suffix = 'ms',
		Decimal = 1,
		Visible = (Mode.Value == 'Lag')
	})
	Targetting = Velocity:CreateToggle({
		Name = 'Only when targetting',
		Default = false
	})
	Chance = Velocity:CreateSlider({
		Name = "Chance",
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 1,
		Suffix = '%',
		Tooltip = 'how often it actually changes ur knockback, 100 means every hit'
	})
end)
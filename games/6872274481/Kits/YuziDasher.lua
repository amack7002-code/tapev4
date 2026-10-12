run(function()
	local YuziDasher
	local ImpulseSlider
	local JumpHeightSlider
	local CurrentKeybind = Enum.KeyCode.Q

	local canDash = true

	local function PerformDash()
		if not canDash then return end
		if not entitylib.isAlive then return end

		local heldItem = store.hand.tool
		if not heldItem or not (heldItem.Name:find("dao") or heldItem.Name:find("yuzi") or heldItem.Name == "jade_hammer" or heldItem.Name == "void_axe") then return end

		local abilityId = (heldItem.Name == "jade_hammer" and "JADE_HAMMER_JUMP") or (heldItem.Name == "void_axe" and "VOID_AXE_JUMP") or nil

		local character = lplr.Character
		if not (character and character.PrimaryPart) then return end

		canDash = false

		task.spawn(function()
			local originalJumpHeight = character.Humanoid.JumpHeight

			pcall(function() character:SetAttribute('CanDash', 0) end)

			local lookVector = gameCamera.CFrame.LookVector
			local origin = character.PrimaryPart.Position

			pcall(function()
				local n = game:GetService("ReplicatedStorage"):FindFirstChild("rbxts_include")
				if n then n = n:FindFirstChild("node_modules") end
				if n then n = n:FindFirstChild("@rbxts") end
				if n then n = n:FindFirstChild("net") end
				if n then n = n:FindFirstChild("out") end
				if n then n = n:FindFirstChild("_NetManaged") end
				if n then n = n:FindFirstChild("SwordSwingMiss") end
				if n then n:FireServer({ weapon = heldItem, chargeRatio = 0 }) end
			end)

			task.wait(0.05)

			local useDash = abilityId == nil
			local canUse = useDash and bedwars.AbilityController:canUseAbility('dash') or (abilityId and bedwars.AbilityController:canUseAbility(abilityId))

			if canUse then
				if useDash then
					bedwars.AbilityController:useAbility('dash', nil, {
						direction = lookVector,
						origin = origin,
						weapon = heldItem.Name
					})
				else
					bedwars.AbilityController:useAbility(abilityId)
				end

				pcall(function()
					bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.DAO_DASH)
				end)

				pcall(function()
					local hrp = character.HumanoidRootPart
					local mass = hrp.AssemblyMass or 5
					hrp:ApplyImpulse(lookVector.Unit * Vector3.new(1, 0, 1) * mass * ImpulseSlider.Value)
					character.Humanoid.JumpHeight = JumpHeightSlider.Value
					character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end)

				task.delay(0.5, function()
					if character and character.Humanoid then
						pcall(function()
							character.Humanoid.JumpHeight = originalJumpHeight
							if bedwars.JumpHeightController then
								bedwars.JumpHeightController:setJumpHeight(game:GetService("StarterPlayer").CharacterJumpHeight)
							end
						end)
					end
				end)
			end

			task.wait(0.3)
			canDash = true
		end)
	end

	YuziDasher = vape.Categories.Kits:CreateModule({
		Name = 'YuziDasher',
		Function = function(callback)
			if callback then
				YuziDasher:Clean(inputService.InputBegan:Connect(function(input, gameProcessed)
					if gameProcessed then return end
					if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == CurrentKeybind then
						PerformDash()
					end
				end))
			else
				canDash = true
			end
		end,
	})

	local keybindOptions = {
		"Q", "E", "R", "F", "G", "X", "Z", "V", "B",
		"LeftAlt", "LeftControl", "LeftShift", "RightAlt", "RightControl", "RightShift",
		"Space", "CapsLock", "Tab"
	}

	YuziDasher:CreateDropdown({
		Name = 'Keybind',
		List = keybindOptions,
		Default = "Q",
		Function = function(value)
			CurrentKeybind = Enum.KeyCode[value]
		end
	})

	ImpulseSlider = YuziDasher:CreateSlider({
		Name = 'Impulse Multiplier',
		Min = 10,
		Max = 500,
		Default = 100,
		Tooltip = 'Controls dash speed'
	})

	JumpHeightSlider = YuziDasher:CreateSlider({
		Name = 'Jump Height',
		Min = 0,
		Max = 50,
		Default = 10,
	})
end)
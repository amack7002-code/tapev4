run(function()
	local Killaura
	local Targets, CPS, SwingRange, AttackRange, AngleSlider, Max
	local Mouse, Swing, Block, AutoBlock
	local BoxSwingColor, BoxAttackColor
	local ParticleTexture, ParticleColor1, ParticleColor2, ParticleSize
	local LegitAura

	local Boxes, Particles = {}, {}
	local AttackDelay, SwingDelay, ClickDelay = tick(), tick(), tick()
	local lMouse = cloneref(lplr:GetMouse())

	local function getAttackData()
		if Mouse.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			return nil
		end
		if LegitAura.Enabled and ClickDelay < tick() then
			return nil
		end
		return getTool()
	end

	local function clearVisuals()
		for _, box in Boxes do
			box.Adornee = nil
		end
		for _, part in Particles do
			part.Parent = nil
		end
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = "Killaura",
		Function = function(callback)
			if callback then
				if LegitAura.Enabled then
					Killaura:Clean(inputService.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							ClickDelay = tick() + 0.1
						end
					end))
				end

				repeat
					local tool = getAttackData()
					local attacked = {}

					if tool and tool:HasTag("Sword") then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = "RootPart",
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = Max.Value
						})

						if #plrs > 0 then
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

							-- AutoBlock
							if AutoBlock.Enabled and not bd.Entity.LocalEntity.IsBlocking then
								pcall(firesignal, lMouse.Button2Down)
							end

							for _, ent in plrs do
								local delta = ent.RootPart.Position - selfpos
								local flatDelta = (delta * Vector3.new(1, 0, 1)).Unit
								local angle = math.acos(localfacing:Dot(flatDelta))

								if angle > (math.rad(AngleSlider.Value) / 2) then
									continue
								end

								local isInAttackRange = delta.Magnitude <= AttackRange.Value
								table.insert(attacked, {
									Entity = ent,
									Check = isInAttackRange and BoxAttackColor or BoxSwingColor
								})

								targetinfo.Targets[ent] = os.clock() + 1

								if Block.Enabled and bd.Entity.LocalEntity.IsBlocking then
									continue
								end

								-- Swing animation
								if not Swing.Enabled and SwingDelay < tick() then
									SwingDelay = tick() + 0.25
									pcall(function()
										entitylib.character.Humanoid.Animator:LoadAnimation(tool.Animations.Swing):Play()
									end)

									if vape.ThreadFix then
										setthreadidentity(2)
									end
									pcall(function()
										bd.ViewmodelController:PlayAnimation(tool.Name)
									end)
									if vape.ThreadFix then
										setthreadidentity(8)
									end
								end

								-- Actual attack
								if isInAttackRange and AttackDelay < tick() then
									AttackDelay = tick() + (1 / CPS.GetRandomValue())

									local bdent = bd.Entity.FindByCharacter(ent.Character)
									if bdent then
										pcall(function()
											bd.Blink.item_action.attack_entity.fire({
												target_entity_id = bdent.Id,
												is_crit = entitylib.character.RootPart.AssemblyLinearVelocity.Y < 0,
												weapon_name = tool.Name,
												extra = {
													rizz = "Bro.",
													owo = "What's this? OwO",
													those = workspace.Name == "Okay" and true or nil
												}
											})
										end)
									end
								end
							end
						else
							if AutoBlock.Enabled and bd.Entity.LocalEntity.IsBlocking then
								pcall(firesignal, lMouse.Button2Up)
							end
						end
					end

					-- Update boxes
					for i, box in Boxes do
						local data = attacked[i]
						box.Adornee = data and data.Entity.RootPart or nil
						if data then
							box.Color3 = Color3.fromHSV(data.Check.Hue, data.Check.Sat, data.Check.Value)
							box.Transparency = 1 - data.Check.Opacity
						end
					end

					-- Update particles
					for i, part in Particles do
						local data = attacked[i]
						if data then
							part.Position = data.Entity.RootPart.Position
							part.Parent = gameCamera
						else
							part.Parent = nil
						end
					end

					task.wait()
				until not Killaura.Enabled
			else
				if AutoBlock.Enabled and bd.Entity.LocalEntity.IsBlocking then
					pcall(firesignal, lMouse.Button2Up)
				end
				clearVisuals()
			end
		end,
		Tooltip = "Attack players around you\nwithout aiming at them."
	})

	--======= Options =======--

	Targets = Killaura:CreateTargets({Players = true})

	CPS = Killaura:CreateTwoSlider({
		Name = "Attacks per Second",
		Min = 1,
		Max = 20,
		DefaultMin = 12,
		DefaultMax = 12
	})

	SwingRange = Killaura:CreateSlider({
		Name = "Swing range",
		Min = 1,
		Max = 16,
		Default = 16,
		Suffix = function(val)
			return val == 1 and "stud" or "studs"
		end
	})

	AttackRange = Killaura:CreateSlider({
		Name = "Attack range",
		Min = 1,
		Max = 16,
		Default = 16,
		Suffix = function(val)
			return val == 1 and "stud" or "studs"
		end
	})

	AngleSlider = Killaura:CreateSlider({
		Name = "Max angle",
		Min = 1,
		Max = 360,
		Default = 360
	})

	Max = Killaura:CreateSlider({
		Name = "Max targets",
		Min = 1,
		Max = 10,
		Default = 10
	})

	Mouse = Killaura:CreateToggle({Name = "Require mouse down"})
	Swing = Killaura:CreateToggle({Name = "No Swing"})
	Block = Killaura:CreateToggle({Name = "No Block"})
	AutoBlock = Killaura:CreateToggle({Name = "AutoBlock"})

	-- Target Box
	Killaura:CreateToggle({
		Name = "Show target",
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback

			if callback then
				for i = 1, 10 do
					local box = Instance.new("BoxHandleAdornment")
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.holder
					Boxes[i] = box
				end
			else
				for _, box in Boxes do
					box:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})

	BoxSwingColor = Killaura:CreateColorSlider({
		Name = "Target Color",
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})

	BoxAttackColor = Killaura:CreateColorSlider({
		Name = "Attack Color",
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})

	-- Particles
	Killaura:CreateToggle({
		Name = "Target particles",
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback

			if callback then
				for i = 1, 10 do
					local part = Instance.new("Part")
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil

					local particles = Instance.new("ParticleEmitter")
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, part in Particles do
					part:Destroy()
				end
				table.clear(Particles)
			end
		end
	})

	ParticleTexture = Killaura:CreateTextBox({
		Name = "Texture",
		Default = "rbxassetid://14736249347",
		Function = function()
			for _, part in Particles do
				if part:FindFirstChildOfClass("ParticleEmitter") then
					part.ParticleEmitter.Texture = ParticleTexture.Value
				end
			end
		end,
		Darker = true,
		Visible = false
	})

	ParticleColor1 = Killaura:CreateColorSlider({
		Name = "Color Begin",
		Function = function(hue, sat, val)
			for _, part in Particles do
				local emitter = part:FindFirstChildOfClass("ParticleEmitter")
				if emitter then
					emitter.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
				end
			end
		end,
		Darker = true,
		Visible = false
	})

	ParticleColor2 = Killaura:CreateColorSlider({
		Name = "Color End",
		Function = function(hue, sat, val)
			for _, part in Particles do
				local emitter = part:FindFirstChildOfClass("ParticleEmitter")
				if emitter then
					emitter.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
					})
				end
			end
		end,
		Darker = true,
		Visible = false
	})

	ParticleSize = Killaura:CreateSlider({
		Name = "Size",
		Min = 0,
		Max = 1,
		Default = 0.14,
		Decimal = 100,
		Function = function(val)
			for _, part in Particles do
				local emitter = part:FindFirstChildOfClass("ParticleEmitter")
				if emitter then
					emitter.Size = NumberSequence.new(val)
				end
			end
		end,
		Darker = true,
		Visible = false
	})

	LegitAura = Killaura:CreateToggle({
		Name = "Swing only",
		Function = function()
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end,
		Tooltip = "Only attacks while swinging manually"
	})
end)
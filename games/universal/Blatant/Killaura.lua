run(function()
	local Killaura
	local Targets
	local CPS
	local SwingRange
	local AttackRange
	local AngleSlider
	local Max
	local Mouse
	local Lunge
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Overlay = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	local Particles, Boxes, AttackDelay = {}, {}, tick()
	
	local function getAttackData()
		local character = entitylib.character
		if not entitylib.isAlive or not character or character.Character ~= lplr.Character
			or not character.RootPart or not character.RootPart.Parent then return false end
		if Mouse.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			return false
		end
	
		local tool = getTool()
		return tool and tool:FindFirstChildWhichIsA('TouchTransmitter', true) or nil, tool
	end
	
	local function resetAuraCharacter()
		AttackDelay = 0
		for _, box in Boxes do box.Adornee = nil end
		for _, particle in Particles do particle.Parent = nil end
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				Killaura:Clean(entitylib.Events.LocalRemoved:Connect(resetAuraCharacter))
				Killaura:Clean(entitylib.Events.LocalAdded:Connect(resetAuraCharacter))
				repeat
					local interest, tool = getAttackData()
					local attacked = {}
					local character = entitylib.isAlive and entitylib.character
					local rootPart = character and character.RootPart
					if interest and tool and rootPart and rootPart.Parent then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = Max.Value
						})

						if #plrs > 0 then
							local selfpos = rootPart.Position
							local localfacing = rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
							if localfacing.Magnitude > 0.001 then localfacing = localfacing.Unit end

							for _, v in plrs do
								local targetRoot = v.RootPart
								if not targetRoot or not targetRoot.Parent then continue end
								local delta = targetRoot.Position - selfpos
								local flatDelta = delta * Vector3.new(1, 0, 1)
								local angle = 0
								if localfacing.Magnitude > 0.001 and flatDelta.Magnitude > 0.001 then
									angle = math.acos(math.clamp(localfacing:Dot(flatDelta.Unit), -1, 1))
								end
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end
	
								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1
	
								if AttackDelay < tick() then
									AttackDelay = tick() + (1 / CPS.GetRandomValue())
									tool:Activate()
								end
	
								if Lunge.Enabled and tool.GripUp.X == 0 then break end
								if delta.Magnitude > AttackRange.Value then continue end
	
								local touchInterest = interest.Parent
								if touchInterest and touchInterest.Parent and firetouchinterest then
									Overlay.FilterDescendantsInstances = {v.Character}
									for _, part in workspace:GetPartBoundsInBox(targetRoot.CFrame, Vector3.new(4, 4, 4), Overlay) do
										firetouchinterest(touchInterest, part, 1)
										firetouchinterest(touchInterest, part, 0)
									end
								end
							end
						end
					end
	
					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
						end
					end
	
					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end
	
					if Face.Enabled and attacked[1] and rootPart.Parent then
						local targetRoot = attacked[1].Entity.RootPart
						if targetRoot and targetRoot.Parent then
							local faceTarget = true
							if AngleSlider.Value < 360 then
								local camLook = (gameCamera and gameCamera.CFrame.LookVector or rootPart.CFrame.LookVector) * Vector3.new(1, 0, 1)
								local flatDelta = (targetRoot.Position - rootPart.Position) * Vector3.new(1, 0, 1)
								if camLook.Magnitude > 0.001 and flatDelta.Magnitude > 1 then
									local camAngle = math.acos(math.clamp(camLook.Unit:Dot(flatDelta.Unit), -1, 1))
									faceTarget = camAngle <= math.rad(AngleSlider.Value) / 2
								end
							end
							if faceTarget then
								local vec = targetRoot.Position * Vector3.new(1, 0, 1)
								rootPart.CFrame = CFrame.lookAt(rootPart.Position, Vector3.new(vec.X, rootPart.Position.Y + 0.01, vec.Z))
							end
						end
					end
	
					task.wait()
				until not Killaura.Enabled
			else
				for _, v in Boxes do
					v.Adornee = nil
				end
				for _, v in Particles do
					v.Parent = nil
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({Players = true})
	CPS = Killaura:CreateTwoSlider({
		Name = 'Attacks per Second',
		Min = 1,
		Max = 20,
		DefaultMin = 12,
		DefaultMax = 12
	})
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 30,
		Default = 13,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 30,
		Default = 13,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 90
	})
	Max = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 10,
		Default = 10
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Lunge = Killaura:CreateToggle({Name = 'Sword lunge only'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
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
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
end)
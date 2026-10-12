run(function()
	local Killaura
	local Targets
	local AttackRange
	local AngleCheck
	local Mouse
	local Limit
	local Swing
	local Face
	local BoxColor
	local TargetColor
	local BoxAnimation
	local BoxStart
	local BoxEnd
	local SwingRange
	local AirChance
	local MaxTargets
	local Sort
	local ContinueSwing
	local AFK
	local GUICheck
	local ParticleTexture
	local ParticleBegin
	local ParticleEnd
	local ParticleSize
	local boxes, shown = {}, {}
	local particles, emitting = {}, {}
	local rng = Random.new()
	local lastInput = tick()
	local nextAnim, continueUntil = 0, 0
	local Custom
	local AttackSpeed
	local Reset
	local SwingOnly
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local AnimTween
	local Attacking = false
	local animId = 0
	local anims = vape.Libraries.auraanims
	-- never parented, it only carries the pose the animation is at
	local pose = Instance.new('Motor6D')
	-- where the game holds its first person arms
	local VIEW = CFrame.new(2.5, -3, -4) * CFrame.fromOrientation(math.rad(15), 0, 0)
	local tracks, viewTracks = {}, {}
	local nextSwing = 0
	local combo = 1
	-- the server counts the first hit that arrives once the sword's cooldown is over, so one goes out every frame
	local FASTEST, BURST = 1 / 60, 0.05
	local FLAT = Vector3.new(1, 0, 1)
	local burstUntil, turn = 0, 0
	local rolls = setmetatable({}, {__mode = 'k'})

	local function play(cache, animator, anim)
		if not (anim and animator) then return end
		if cache.Animator ~= animator then
			table.clear(cache)
			cache.Animator = animator
		end
		cache[anim] = cache[anim] or animator:LoadAnimation(anim)
		cache[anim]:Play()
	end

	-- one swing per hit sent, on the body and on the first person arms
	local function swing(sword)
		local data = bedfight.SwordsData[sword]
		if type(data) ~= 'table' then return end
		local set = data.Animations or bedfight.SwordsData.DefaultAnimation
		local anim = set and set.Swing
		if data.AnimationCombo and set then
			-- katanas and the like walk through a set of swings, the same way the game does
			anim = set[combo] or anim
			combo = (combo + 2) % data.AnimationCombo + 1
		end
		if not anim then return end
		play(tracks, entitylib.character.Humanoid:FindFirstChildOfClass('Animator'), anim.Animation)
		-- the arms only show the sword while it is the item in your hand
		if heldName() == sword then
			play(viewTracks, bedfight.ViewModelHandler.ViewModelAnimator, anim.ViewModel)
		end
	end

	local function swordCooldown(sword)
		local data = sword and bedfight.SwordsData[sword]
		return type(data) == 'table' and data.DamageCooldown or 0.3
	end

	-- how often the swing plays. the game itself never swings faster than the sword's AnimationCooldown
	local function swingPace(sword)
		if Custom.Enabled then
			local data = bedfight.SwordsData[sword]
			return math.max(AttackSpeed.Value, type(data) == 'table' and data.AnimationCooldown or 0.1)
		end
		return swordCooldown(sword)
	end

	-- how far a plain swing of this sword lands, root to root
	local function legitReach(sword)
		local data = sword and bedfight.SwordsData[sword]
		if type(data) ~= 'table' or not data.Range then return 10.5 end
		return data.Range + (data.HitboxSize and data.HitboxSize.Z / 2 or 2.5) + 2.75
	end

	-- a shop, chest, kit or settings screen of the game is up
	local function guiOpen()
		local gui = lplr:FindFirstChildOfClass('PlayerGui')
		for _, name in {'ItemShopGui', 'TeamUpgradesGui', 'TeamChestGui', 'SettingsGui', 'KitsGui', 'LockerGui'} do
			local screen = gui and gui:FindFirstChild(name)
			if screen and screen:IsA('LayerCollector') and screen.Enabled then
				return true
			end
		end
		return false
	end

	local function particleColor()
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleBegin.Hue, ParticleBegin.Sat, ParticleBegin.Value)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleEnd.Hue, ParticleEnd.Sat, ParticleEnd.Value))
		})
	end

	-- rolled once per cooldown, not for every hit sent
	local function airPass(ent, sword, now)
		if not (ent.Humanoid and ent.Humanoid.FloorMaterial == Enum.Material.Air) then return true end
		local roll = rolls[ent]
		if not roll then
			roll = {At = -1, Pass = true}
			rolls[ent] = roll
		end
		if now - roll.At >= swordCooldown(sword) then
			roll.At = now
			roll.Pass = rng:NextNumber(0, 100) <= AirChance:GetRandomValue()
		end
		return roll.Pass
	end

	local function getSwordName()
		if Limit.Enabled then
			local held = heldName()
			return held and type(bedfight.SwordsData[held]) == 'table' and held or nil
		end
		return store.tools.sword
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				lastInput = tick()
				Killaura:Clean(inputService.InputChanged:Connect(function()
					lastInput = tick()
				end))
				-- a click with a sword out is a swing of your own
				Killaura:Clean(inputService.InputBegan:Connect(function(input, processed)
					lastInput = tick()
					if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
					local held = heldName()
					if held and type(bedfight.SwordsData[held]) == 'table' then
						store.swung = tick()
					end
				end))

				if Animation.Enabled then
					local name = 'AetherAuraPose'
					runService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
						if pose.C0 == CFrame.identity then return end
						local handler = bedfight.ViewModelHandler
						local model = handler and handler.Visible and handler.CurrentViewModel
						local root = model and model.PrimaryPart
						if root then
							root.CFrame = gameCamera.CFrame * VIEW * pose.C0
						end
					end)
					Killaura:Clean(function()
						runService:UnbindFromRenderStep(name)
					end)
					animId += 1
					local id = animId
					task.spawn(function()
						local started = false
						repeat
							if Attacking then
								local first = not started
								started = true
								if AnimationMode.Value == 'Random' then
									anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
								end
								for _, v in anims[AnimationMode.Value] or anims.Normal do
									AnimTween = tweenService:Create(pose, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / math.max(AnimationSpeed.Value, 0.05), Enum.EasingStyle.Linear), {
										C0 = v.CFrame
									})
									AnimTween:Play()
									AnimTween.Completed:Wait()
									first = false
									if (not Killaura.Enabled) or (not Attacking) or id ~= animId then break end
								end
							elseif started then
								started = false
								AnimTween = tweenService:Create(pose, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
									C0 = CFrame.identity
								})
								AnimTween:Play()
							end

							if not started then
								task.wait(1 / 60)
							end
						until (not Killaura.Enabled) or (not Animation.Enabled) or id ~= animId
					end)
				end

				repeat
					local list = {}
					local fighting = false
					local sword = canFight() and getSwordName()
					local idle = not sword
						or (Mouse.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1))
						or (SwingOnly.Enabled and tick() - (store.swung or 0) > 0.35)
						or (AFK.Enabled and tick() - lastInput > 30)
						or (GUICheck.Enabled and guiOpen())
					if not idle then
						local root = entitylib.character.RootPart
						-- AntiHit brings the hitbox into reach for each hit by itself
						local managed = store.antiHit and tick() - (store.antiHitAt or 0) < 0.1
						-- the server measures from the hitbox, which may not be where the body is
						local from = managed and root.Position or realRoot().Position
						-- what you see of someone is a ping old by the time your hit reaches the server
						local lead = managed and 0 or math.clamp(lplr:GetNetworkPing() + 0.05, 0, 0.45)
						local reach = AttackRange.Value
						local plrs = store.targets({
							Range = math.max(SwingRange.Value, reach + lead * 40),
							Walls = Targets.Walls.Enabled,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = Sort.Value,
							Limit = 10
						})
						local facing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
						local hits = {}

						for _, v in plrs do
							local pos = v.RootPart.Position
							local delta = (pos - root.Position) * FLAT
							if AngleCheck.Value < 360 and delta.Magnitude > 0.5 and facing.Magnitude > 0.01 then
								local angle = math.acos(math.clamp(facing.Unit:Dot(delta.Unit), -1, 1))
								if angle > math.rad(AngleCheck.Value) / 2 then continue end
							end
							local close = (pos - from).Magnitude <= reach
							if lead > 0 then
								-- someone running at you is in reach for the server before they look it
								local ahead = pos + store.motion(v) * FLAT * lead
								close = close or (ahead - from).Magnitude <= reach
							end
							if not close and (pos - root.Position).Magnitude > SwingRange.Value then continue end
							table.insert(list, {Entity = v, Check = close and BoxColor or TargetColor})
							if close then
								table.insert(hits, v)
							end
							targetinfo.Targets[v] = tick() + 1
							if #list >= MaxTargets.Value then break end
						end

						if hits[1] then
							fighting = true
							store.melee = tick()
							store.meleeTarget, store.meleeRange = hits[1], reach
							if targetinfo.Focus then
								targetinfo.Focus[hits[1]] = tick() + 1
							end

							local now = os.clock()
							-- the server only has to hold the sword, the hotbar is left alone. it takes the
							-- switch and the hits in the order they were sent, so nothing waits for the switch to show
							equipServer(sword, 'Killaura')
							local wait = math.max(Custom.Enabled and AttackSpeed.Value or managed and swordCooldown(sword) or 0, FASTEST)
							store.meleeDue = tick() + nextSwing - now
							local fire = now < burstUntil
							-- AntiHit keeps the hitbox out of reach and brings it in for the hit
							if not fire and now >= nextSwing and (not store.strikeGate or store.strikeGate(hits[1])) then
								store.struckAt = tick()
								-- timed from the last slot, not from this frame, so no hit is lost to frame timing
								nextSwing = now - nextSwing > wait and now + wait or nextSwing + wait
								-- the hitbox is only down for a moment, and every frame of it gets a hit
								burstUntil = managed and now + BURST or 0
								fire = true
							end
							if fire then
								-- one hit a frame at most. several targets take turns unless hits are spaced out
								local all = managed or wait > 1 / 30
								turn += 1
								for i, v in hits do
									if (all or (turn - 1) % #hits + 1 == i) and airPass(v, sword, now) then
										fireRemote('SwordHit', v.Character, sword)
									end
								end
							end
						end

						if list[1] and Face.Enabled then
							local pos = list[1].Entity.RootPart.Position
							root.CFrame = CFrame.lookAt(root.Position, Vector3.new(pos.X, root.Position.Y, pos.Z))
						end
					end

					-- the swing runs on its own clock, so it also plays for someone who is only close
					if list[1] then
						continueUntil = tick() + ContinueSwing:GetRandomValue() / 1000
					end
					if sword and (list[1] or tick() < continueUntil) and tick() >= nextAnim and not Swing.Enabled and not SwingOnly.Enabled and entitylib.isAlive then
						nextAnim = tick() + swingPace(sword)
						swing(sword)
					end

					Attacking = list[1] ~= nil
					-- someone stepping out of reach for a moment does not cost a switch each way
					if not fighting and tick() - (store.melee or 0) > 0.25 then
						syncTool('Killaura')
					end
					for i, v in boxes do
						local entry = list[i]
						if entry and not shown[v] then
							v.Size = Vector3.zero
							tweenService:Create(v, TweenInfo.new(BoxStart.Value, Enum.EasingStyle[BoxAnimation.Value]), {Size = Vector3.new(3, 5, 3)}):Play()
						elseif shown[v] and not entry then
							tweenService:Create(v, TweenInfo.new(BoxEnd.Value, Enum.EasingStyle[BoxAnimation.Value]), {Size = Vector3.zero}):Play()
						end
						shown[v] = entry and true or nil
						if entry then
							v.Adornee = entry.Entity.RootPart
							v.Color3 = Color3.fromHSV(entry.Check.Hue, entry.Check.Sat, entry.Check.Value)
							v.Transparency = 1 - entry.Check.Opacity
						end
					end
					for i, v in particles do
						local entry = list[i]
						if entry then
							v.Position = entry.Entity.RootPart.Position
							if not emitting[v] then
								v.Parent = gameCamera
								emitting[v] = true
							end
						elseif emitting[v] then
							v.Parent = nil
							emitting[v] = nil
						end
					end

					runService.Heartbeat:Wait()
				until not Killaura.Enabled
			else
				Attacking = false
				if AnimTween then
					AnimTween:Cancel()
				end
				pose.C0 = CFrame.identity
				syncTool('Killaura')
				for _, v in boxes do
					v.Adornee = nil
					v.Size = Vector3.zero
					shown[v] = nil
				end
				for _, v in particles do
					v.Parent = nil
					emitting[v] = nil
				end
			end
		end,
		Tooltip = 'Attacks players around you without aiming at them.\nYour hotbar is never touched, so you can hold and switch items while it fights.'
	})
	Targets = Killaura:CreateTargets({Players = true})
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 22,
		Default = 14,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How close someone has to be before you start swinging. Hits are only sent inside Attack range'
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 14,
		Default = 14,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'As far as a normal swing can reach'
	})
	Killaura:CreateButton({
		Name = 'Sync to legit ranges',
		Function = function()
			local reach = math.clamp(math.floor(legitReach(store.tools.sword) * 10) / 10, 1, 14)
			SwingRange:SetValue(reach)
			AttackRange:SetValue(reach)
		end,
		Tooltip = 'Drops both ranges down to what a plain swing of your sword reaches'
	})
	AngleCheck = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	AirChance = Killaura:CreateTwoSlider({
		Name = 'Air hit chance',
		Min = 0,
		Max = 100,
		DefaultMin = 100,
		DefaultMax = 100,
		Tooltip = 'Chance to send a hit while the target is off the ground, rolled fresh between the two values on every hit'
	})
	MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 5,
		Default = 1,
		Tooltip = 'How many players are sent a hit with each swing'
	})
	Sort = Killaura:CreateDropdown({
		Name = 'Target Mode',
		List = store.sortList,
		Tooltip = 'Distance - the nearest\nCursor - nearest your cursor on screen\nAngle - nearest to where your camera looks\nLowest Health / Highest Health'
	})
	Custom = Killaura:CreateToggle({
		Name = 'Custom Attack Speed',
		Function = function(callback)
			AttackSpeed.Object.Visible = callback
			Reset.Object.Visible = callback
			nextSwing, nextAnim = 0, 0
		end,
		Tooltip = 'Sets how often hits are sent and how fast you swing.\nOff, a hit goes out every frame and the server counts the first one it can after each sword cooldown (0.3s for most swords), which is as many hits as it allows. Only switch this on to hit slower.'
	})
	AttackSpeed = Killaura:CreateSlider({
		Name = 'Time between hits',
		Min = 0,
		Max = 1,
		Default = 0.3,
		Decimal = 100,
		Suffix = 's',
		Darker = true,
		Visible = false,
		Function = function()
			nextSwing, nextAnim = 0, 0
		end,
		Tooltip = '0 sends a hit every frame, the same as with Custom Attack Speed off, and swings as fast as the game allows. 1 is one hit and one swing a second'
	})
	Reset = Killaura:CreateButton({
		Name = 'Reset to default',
		Function = function()
			AttackSpeed:SetValue(swordCooldown(store.tools.sword))
		end,
		Darker = true,
		Visible = false,
		Tooltip = 'Back to the cooldown of the sword you carry'
	})
	ContinueSwing = Killaura:CreateTwoSlider({
		Name = 'Continue swing',
		Min = 0,
		Max = 1000,
		DefaultMin = 0,
		DefaultMax = 0,
		Tooltip = 'Keeps playing the swing animation for a random amount of ms after you stop targeting'
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	AFK = Killaura:CreateToggle({
		Name = 'AFK check',
		Tooltip = 'Stops attacking once you have not touched your mouse or keyboard for 30 seconds'
	})
	GUICheck = Killaura:CreateToggle({
		Name = 'GUI check',
		Tooltip = 'Stops attacking while a shop, chest, kit or settings screen is open'
	})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only attacks while you hold a sword'
	})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	SwingOnly = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while swinging manually'
	})
	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationTween.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end,
		Tooltip = 'Animates your first person arms while attacking'
	})
	local animnames = {}
	for name in anims do
		if name ~= 'Normal' then
			table.insert(animnames, name)
		end
	end
	table.sort(animnames)
	table.insert(animnames, 1, 'Normal')
	AnimationMode = Killaura:CreateDropdown({
		Name = 'Animation Mode',
		List = animnames,
		Darker = true,
		Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
		Name = 'No Tween',
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({
		Name = 'Face target',
		Tooltip = 'Turns your character toward the target'
	})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxColor.Object.Visible = callback
			TargetColor.Object.Visible = callback
			BoxAnimation.Object.Visible = callback
			BoxStart.Object.Visible = callback
			BoxEnd.Object.Visible = callback
			if callback then
				for i = 1, 5 do
					local box = Instance.new('BoxHandleAdornment')
					box.AlwaysOnTop = true
					box.Size = Vector3.zero
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					boxes[i] = box
				end
			else
				for _, v in boxes do
					v:Destroy()
				end
				table.clear(boxes)
				table.clear(shown)
			end
		end
	})
	local easings = {'Bounce'}
	for _, v in Enum.EasingStyle:GetEnumItems() do
		if not table.find(easings, v.Name) then
			table.insert(easings, v.Name)
		end
	end
	BoxAnimation = Killaura:CreateDropdown({
		Name = 'Box Animation',
		List = easings,
		Darker = true,
		Visible = false
	})
	BoxStart = Killaura:CreateSlider({
		Name = 'Start Animation Speed',
		Min = 0,
		Max = 10,
		Default = 0.9,
		Decimal = 30,
		Darker = true,
		Visible = false
	})
	BoxEnd = Killaura:CreateSlider({
		Name = 'End Animation Speed',
		Min = 0,
		Max = 10,
		Default = 1.4,
		Decimal = 30,
		Darker = true,
		Visible = false
	})
	TargetColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleBegin.Object.Visible = callback
			ParticleEnd.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 5 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.Transparency = 1
					local emitter = Instance.new('ParticleEmitter')
					emitter.Brightness = 1.5
					emitter.Size = NumberSequence.new(ParticleSize.Value)
					emitter.Shape = Enum.ParticleEmitterShape.Sphere
					emitter.Texture = ParticleTexture.Value
					emitter.Transparency = NumberSequence.new(0)
					emitter.Lifetime = NumberRange.new(0.4)
					emitter.Speed = NumberRange.new(16)
					emitter.Rate = 128
					emitter.Drag = 16
					emitter.ShapePartial = 1
					emitter.Color = particleColor()
					emitter.Parent = part
					particles[i] = part
				end
			else
				for _, v in particles do
					v:Destroy()
				end
				table.clear(particles)
				table.clear(emitting)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Function = function()
			for _, v in particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Default = 'rbxassetid://14736249347',
		Darker = true,
		Visible = false
	})
	ParticleBegin = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function()
			if not ParticleEnd then return end
			for _, v in particles do
				v.ParticleEmitter.Color = particleColor()
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleEnd = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function()
			for _, v in particles do
				v.ParticleEmitter.Color = particleColor()
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Function = function(val)
			for _, v in particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Default = 0.2,
		Darker = true,
		Visible = false
	})
end)

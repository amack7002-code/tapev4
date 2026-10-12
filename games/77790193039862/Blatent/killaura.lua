local Killaura
local Targets
local AttackRange
local AngleSlider
local Max
local Mouse
local BoxAttackColor
local ParticleTexture
local ParticleColor1
local ParticleColor2
local ParticleSize
local Face
local Sort
local GUICheck
local generation = 0
local restoreCamera
local guiService = cloneref(game:GetService('GuiService'))
local Particles, Boxes, AttackDelay = {}, {}, tick()

local function getAttackData()
	if not (entitylib.isAlive and entitylib.character and entitylib.character.RootPart and entitylib.character.RootPart.Parent and gameCamera) then return false end
	if inputService:GetFocusedTextBox() then return false end
	if Mouse.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return false end
	local scaled = vape.gui and vape.gui:FindFirstChild('ScaledGui')
	local menu = scaled and scaled:FindFirstChild('ClickGui')
	if GUICheck.Enabled and (guiService.MenuIsOpen or menu and menu.Visible) then return false end
	return true
end

local function selectTargets(origin, facing)
	local entries = {}
	local flat = Vector3.new(facing.X, 0, facing.Z)
	for _, ent in entitylib.List do
		local root = ent.RootPart
		if not (root and root.Parent and ent.Character and ent.Character.Parent and ent.Targetable) then continue end
		if ent.Player == lplr or ent.Friend or (ent.Health and ent.Health <= 0) then continue end
		if ent.Player and not Targets.Players.Enabled or ent.NPC and not Targets.NPCs.Enabled then continue end
		if not entitylib.targetCheck(ent) or not entitylib.isVulnerable(ent) then continue end
		local delta = root.Position - origin
		local distance = delta.Magnitude
		if distance <= 0.001 or distance > AttackRange.Value then continue end
		local horizontal = Vector3.new(delta.X, 0, delta.Z)
		local angle = 0
		if flat.Magnitude > 0.001 and horizontal.Magnitude > 0.001 then angle = math.acos(math.clamp(flat.Unit:Dot(horizontal.Unit), -1, 1)) end
		if angle > math.rad(AngleSlider.Value) / 2 then continue end
		if Targets.Walls.Enabled and entitylib.Wallcheck(origin, root.Position) then continue end
		local score = distance
		if Sort.Value == 'Angle' then score = angle
		elseif Sort.Value == 'Lowest Health' then score = ent.Health or 100
		elseif Sort.Value == 'Highest Health' then score = -(ent.Health or 100) end
		table.insert(entries, {Entity = ent, Angle = angle, Distance = distance, Score = score})
	end
	table.sort(entries, function(a, b)
		local aTarget, bTarget = a.Entity.Target == true, b.Entity.Target == true
		if aTarget ~= bTarget then return aTarget end
		if a.Score == b.Score then return a.Distance < b.Distance end
		return a.Score < b.Score
	end)
	while #entries > Max.Value do table.remove(entries) end
	return entries
end

Killaura = vape.Categories.Blatant:CreateModule({
	Name = 'Killaura',
	Function = function(callback)
		generation += 1
		local currentGeneration = generation
		if restoreCamera then restoreCamera(); restoreCamera = nil end
		if callback then
			local customvec
			local originalCamera = readUpvalue(arena.TickFunction, 13)
			if originalCamera == nil then
				notif('Killaura', 'Camera hook unavailable; cannot enable safely.', 8, 'warning')
				task.defer(function() if Killaura.Enabled and generation == currentGeneration then Killaura:Toggle() end end)
				return
			end
			local proxy = setmetatable({}, {})
			local blockfunc = oldhit or arena.Client.startHit
			getmetatable(proxy).__index = function(self, key)
				if key == 'CFrame' then
					return customvec or gameCamera.CFrame
				end
				return gameCamera[key]
			end

			local restored = false
			local function cleanup()
				if restored then return end
				restored = true
				if readUpvalue(arena.TickFunction, 13) == proxy then
					local ok, err = pcall(debug.setupvalue, arena.TickFunction, 13, originalCamera)
					if not ok then warn('[tapev4/Killaura] Restore failed: '..tostring(err)) end
				end
				if generation == currentGeneration then
					for _, box in Boxes do box.Adornee = nil end
					for _, part in Particles do part.Parent = nil end
				end
			end
			restoreCamera = cleanup
			Killaura:Clean(cleanup)
			local succeeded, err = xpcall(function()
			debug.setupvalue(arena.TickFunction, 13, proxy)
			assert(readUpvalue(arena.TickFunction, 13) == proxy, 'Camera hook installation failed')
			repeat
				customvec = nil
				local interest = getAttackData()
				local attacked = {}

				if interest then
					local plrs = selectTargets(entitylib.character.RootPart.Position, gameCamera.CFrame.LookVector)

					if #plrs > 0 then
						blockfunc = oldhit or arena.Client.startHit
						local selfpos = entitylib.character.RootPart.Position
						local reblock = false
						local hitsOK, hitsError = xpcall(function()
						for _, entry in plrs do
							local v, angle = entry.Entity, entry.Angle
							if not (v.RootPart.Parent and v.Character.Parent) then continue end

							table.insert(attacked, {
								Entity = v,
								Check = BoxAttackColor
							})
							if targetinfo and targetinfo.Targets then targetinfo.Targets[v] = tick() + 1 end

							if readUpvalue(blockfunc, 6) == true then
								arena.Client.endBlockEvent:FireServer()
								reblock = true
								debug.setupvalue(blockfunc, 6, false)
							end

							if AttackDelay < tick() then
								arena.SwingFunction()
								AttackDelay = tick() + 0.11
							end

							local vec = CFrame.lookAt(selfpos, v.RootPart.Position)
							if angle > math.rad(65) then
								customvec = vec
							end

							replicatedStorage.Remotes.HitRequest:FireServer(selfpos, vec.LookVector, v.Character, v.Player)
						end

						end, debug and debug.traceback or tostring)
						if reblock then
							local sent, sendError = pcall(function() arena.Client.beginBlockEvent:FireServer() end)
							local reset, resetError = pcall(debug.setupvalue, blockfunc, 6, true)
							if not sent or not reset then error('Block restoration failed: '..tostring(sendError or resetError)) end
						end
						if not hitsOK then error(hitsError, 0) end
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

				if Face.Enabled and attacked[1] then
					local root = entitylib.character.RootPart
					local delta = (attacked[1].Entity.RootPart.Position - root.Position) * Vector3.new(1, 0, 1)
					if delta.Magnitude > 0.001 then root.CFrame = CFrame.lookAt(root.Position, root.Position + delta) end
				end

				task.wait(#attacked > 0 and #attacked * 0.07 or 0.016)
			until not Killaura.Enabled or generation ~= currentGeneration
			end, debug and debug.traceback or tostring)
			cleanup()
			if not succeeded then
				warn('[tapev4/Killaura] '..tostring(err))
				notif('Killaura', 'Stopped after a runtime error; check the tapev4 warning.', 8, 'warning')
				if Killaura.Enabled and generation == currentGeneration then Killaura:Toggle() end
			end
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
AttackRange = Killaura:CreateSlider({
	Name = 'Attack range',
	Min = 1,
	Max = 16,
	Default = 16,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
AngleSlider = Killaura:CreateSlider({
	Name = 'Max angle',
	Min = 1,
	Max = 360,
	Default = 360
})
Max = Killaura:CreateSlider({
	Name = 'Max targets',
	Min = 1,
	Max = 10,
	Default = 10
})
Sort = Killaura:CreateDropdown({Name = 'Target Mode', List = {'Distance', 'Angle', 'Lowest Health', 'Highest Health'}, Default = 'Distance', Tooltip = 'Sorts eligible targets before Max targets is applied. Marked targets have priority.'})
GUICheck = Killaura:CreateToggle({Name = 'GUI check', Default = true, Tooltip = 'Pauses while the tapev4 or Roblox menu is open. Typing always pauses attacks.'})
Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
Killaura:CreateToggle({
	Name = 'Show target',
	Function = function(callback)
		if BoxAttackColor then BoxAttackColor.Object.Visible = callback end
		if callback then
			for i = 1, 10 do
				local box = Instance.new('BoxHandleAdornment')
				box.Adornee = nil
				box.AlwaysOnTop = true
				box.Size = Vector3.new(3, 7, 3)
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
BoxAttackColor = Killaura:CreateColorSlider({
	Name = 'Attack Color',
	Darker = true,
	DefaultOpacity = 0.5,
	Visible = false
})
Killaura:CreateToggle({
	Name = 'Target particles',
	Function = function(callback)			ParticleTexture.Object.Visible = callback
		ParticleColor1.Object.Visible = callback
		ParticleColor2.Object.Visible = callback
		ParticleSize.Object.Visible = callback
		if callback then
			for i = 1, 10 do
				local part = Instance.new('Part')
				part.Size = Vector3.new(2, 4, 2)
				part.Anchored = true
				part.CanCollide = false
				part.CanTouch = false
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
			if ParticleTexture then v.ParticleEmitter.Texture = ParticleTexture.Value end
		end
	end,
	Darker = true,
	Visible = false
})
ParticleColor1 = Killaura:CreateColorSlider({
	Name = 'Color Begin',
	Function = function(hue, sat, val)
		if not ParticleColor2 then return end
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
		if not ParticleColor1 then return end
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
Face = Killaura:CreateToggle({Name = 'Face target', Tooltip = 'Turns horizontally toward the first selected target.'})
vape:Clean(function()
	generation += 1
	if restoreCamera then restoreCamera(); restoreCamera = nil end
	for _, box in Boxes do box:Destroy() end
	for _, part in Particles do part:Destroy() end
	table.clear(Boxes)
	table.clear(Particles)
end)
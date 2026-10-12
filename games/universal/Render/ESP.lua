run(function()
	local ESP
	local Targets
	local Color
	local Method
	local BoundingBox
	local Filled
	local HealthBar
	local Name
	local DisplayName
	local Background
	local Teammates
	local Distance
	local DistanceLimit
	local Reference = {}
	local methodused
	local Draw = {}
	do
		local layer
		local function getLayer()
			if layer and layer.Parent then return layer end
			layer = Instance.new('ScreenGui')
			layer.Name = 'ESPLayer'
			layer.IgnoreGuiInset = true
			layer.ResetOnSpawn = false
			layer.ZIndexBehavior = Enum.ZIndexBehavior.Global
			layer.Parent = vape.gui and vape.gui.Parent or game:GetService('CoreGui')
			return layer
		end
		local function apply(self)
			local p, inst = self.props, self.inst
			if not inst then return end
			inst.Visible = p.Visible
			inst.ZIndex = math.max(p.ZIndex, 0) + 1
			if self.kind == 'Square' then
				inst.Position = UDim2.fromOffset(p.Position.X, p.Position.Y)
				inst.Size = UDim2.fromOffset(p.Size.X, p.Size.Y)
				if p.Filled then
					inst.BackgroundColor3 = p.Color
					inst.BackgroundTransparency = 1 - p.Transparency
					self.stroke.Enabled = false
				else
					inst.BackgroundTransparency = 1
					self.stroke.Enabled = true
					self.stroke.Color = p.Color
					self.stroke.Thickness = p.Thickness
					self.stroke.Transparency = 1 - p.Transparency
				end
			elseif self.kind == 'Line' then
				local delta = p.To - p.From
				local mid = (p.From + p.To) / 2
				inst.Position = UDim2.fromOffset(mid.X, mid.Y)
				inst.Size = UDim2.fromOffset(delta.Magnitude, p.Thickness)
				inst.Rotation = math.deg(math.atan2(delta.Y, delta.X))
				inst.BackgroundColor3 = p.Color
				inst.BackgroundTransparency = 1 - p.Transparency
			else
				inst.Text = p.Text
				inst.TextSize = p.Size
				inst.TextColor3 = p.Color
				inst.TextTransparency = 1 - p.Transparency
				inst.AnchorPoint = Vector2.new(p.Center and 0.5 or 0, 0)
				inst.Position = UDim2.fromOffset(p.Position.X, p.Position.Y)
			end
		end
		local mt = {}
		mt.__index = function(self, key)
			if key == 'Remove' or key == 'Destroy' then
				return function(obj)
					if obj.inst then
						obj.inst:Destroy()
						obj.inst = nil
					end
				end
			elseif key == 'TextBounds' then
				return self.inst and self.inst.TextBounds or Vector2.zero
			end
			return self.props[key]
		end
		mt.__newindex = function(self, key, value)
			self.props[key] = value
			apply(self)
		end
		function Draw.new(kind)
			local obj = {kind = kind, props = {Visible = false, Transparency = 1, Color = Color3.new(1, 1, 1), Thickness = 1, ZIndex = 1, Filled = false, Position = Vector2.zero, Size = kind == 'Text' and 13 or Vector2.zero, From = Vector2.zero, To = Vector2.zero, Text = '', Center = false}}
			if kind == 'Text' then
				local label = Instance.new('TextLabel')
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.GothamMedium
				label.AutomaticSize = Enum.AutomaticSize.XY
				label.Size = UDim2.fromOffset(0, 0)
				label.Parent = getLayer()
				obj.inst = label
			else
				local frame = Instance.new('Frame')
				frame.BorderSizePixel = 0
				frame.AnchorPoint = kind == 'Line' and Vector2.new(0.5, 0.5) or Vector2.zero
				frame.Parent = getLayer()
				obj.inst = frame
				if kind == 'Square' then
					local stroke = Instance.new('UIStroke')
					stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					stroke.Parent = frame
					obj.stroke = stroke
				end
			end
			setmetatable(obj, mt)
			apply(obj)
			return obj
		end
	end
	
	local function ESPWorldToViewport(pos)
		local newpos = gameCamera:WorldToViewportPoint(gameCamera.CFrame:pointToWorldSpace(gameCamera.CFrame:PointToObjectSpace(pos)))
		return Vector2.new(newpos.X, newpos.Y)
	end
	
	local ESPAdded = {
		Drawing2D = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			local EntityESP = {}
			EntityESP.Main = Draw.new('Square')
			EntityESP.Main.Transparency = BoundingBox.Enabled and 1 or 0
			EntityESP.Main.ZIndex = 2
			EntityESP.Main.Filled = false
			EntityESP.Main.Thickness = 1
			EntityESP.Main.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	
			if BoundingBox.Enabled then
				EntityESP.Border = Draw.new('Square')
				EntityESP.Border.Transparency = 0.35
				EntityESP.Border.ZIndex = 1
				EntityESP.Border.Thickness = 1
				EntityESP.Border.Filled = false
				EntityESP.Border.Color = Color3.new()
				EntityESP.Border2 = Draw.new('Square')
				EntityESP.Border2.Transparency = 0.35
				EntityESP.Border2.ZIndex = 1
				EntityESP.Border2.Thickness = 1
				EntityESP.Border2.Filled = Filled.Enabled
				EntityESP.Border2.Color = Color3.new()
			end
	
			if HealthBar.Enabled then
				EntityESP.HealthLine = Draw.new('Line')
				EntityESP.HealthLine.Thickness = 1
				EntityESP.HealthLine.ZIndex = 2
				EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				EntityESP.HealthBorder = Draw.new('Line')
				EntityESP.HealthBorder.Thickness = 3
				EntityESP.HealthBorder.Transparency = 0.35
				EntityESP.HealthBorder.ZIndex = 1
				EntityESP.HealthBorder.Color = Color3.new()
			end
			
			if Name.Enabled then
				if Background.Enabled then
					EntityESP.TextBKG = Draw.new('Square')
					EntityESP.TextBKG.Transparency = 0.35
					EntityESP.TextBKG.ZIndex = 0
					EntityESP.TextBKG.Thickness = 1
					EntityESP.TextBKG.Filled = true
					EntityESP.TextBKG.Color = Color3.new()
				end
				EntityESP.Drop = Draw.new('Text')
				EntityESP.Drop.Color = Color3.new()
				EntityESP.Drop.Text = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
				EntityESP.Drop.ZIndex = 1
				EntityESP.Drop.Center = true
				EntityESP.Drop.Size = 20
				EntityESP.Text = Draw.new('Text')
				EntityESP.Text.Text = EntityESP.Drop.Text
				EntityESP.Text.ZIndex = 2
				EntityESP.Text.Color = EntityESP.Main.Color
				EntityESP.Text.Center = true
				EntityESP.Text.Size = 20
			end
			Reference[ent] = EntityESP
		end,
		Drawing3D = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			local EntityESP = {}
			EntityESP.Line1 = Draw.new('Line')
			EntityESP.Line2 = Draw.new('Line')
			EntityESP.Line3 = Draw.new('Line')
			EntityESP.Line4 = Draw.new('Line')
			EntityESP.Line5 = Draw.new('Line')
			EntityESP.Line6 = Draw.new('Line')
			EntityESP.Line7 = Draw.new('Line')
			EntityESP.Line8 = Draw.new('Line')
			EntityESP.Line9 = Draw.new('Line')
			EntityESP.Line10 = Draw.new('Line')
			EntityESP.Line11 = Draw.new('Line')
			EntityESP.Line12 = Draw.new('Line')
	
			local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			for _, v in EntityESP do
				v.Thickness = 1
				v.Color = color
			end
	
			Reference[ent] = EntityESP
		end,
		DrawingSkeleton = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			local EntityESP = {}
			EntityESP.Head = Draw.new('Line')
			EntityESP.HeadFacing = Draw.new('Line')
			EntityESP.Torso = Draw.new('Line')
			EntityESP.UpperTorso = Draw.new('Line')
			EntityESP.LowerTorso = Draw.new('Line')
			EntityESP.LeftArm = Draw.new('Line')
			EntityESP.RightArm = Draw.new('Line')
			EntityESP.LeftLeg = Draw.new('Line')
			EntityESP.RightLeg = Draw.new('Line')
	
			local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			for _, v in EntityESP do
				v.Thickness = 2
				v.Color = color
			end
	
			Reference[ent] = EntityESP
		end
	}
	
	local ESPRemoved = {
		Drawing2D = function(ent)
			local EntityESP = Reference[ent]
			if EntityESP then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Reference[ent] = nil
				for _, v in EntityESP do
					pcall(function()
						v.Visible = false
						v:Remove()
					end)
				end
			end
		end
	}
	ESPRemoved.Drawing3D = ESPRemoved.Drawing2D
	ESPRemoved.DrawingSkeleton = ESPRemoved.Drawing2D
	
	local ESPUpdated = {
		Drawing2D = function(ent)
			local EntityESP = Reference[ent]
			if EntityESP then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				
				if EntityESP.HealthLine then
					EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				end
	
				if EntityESP.Text then
					EntityESP.Text.Text = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
					EntityESP.Drop.Text = EntityESP.Text.Text
				end
			end
		end
	}
	
	local ColorFunc = {
		Drawing2D = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.Main.Color = entitylib.getEntityColor(i) or color
				if v.Text then
					v.Text.Color = v.Main.Color
				end
			end
		end,
		Drawing3D = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				local playercolor = entitylib.getEntityColor(i) or color
				for _, v2 in v do
					v2.Color = playercolor
				end
			end
		end
	}
	ColorFunc.DrawingSkeleton = ColorFunc.Drawing3D
	
	local ESPLoop = {
		Drawing2D = function()
			for ent, EntityESP in Reference do
				if not ent.RootPart or not ent.RootPart.Parent then
					for _, obj in EntityESP do obj.Visible = false end
					continue
				end
				if Distance.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						for _, obj in EntityESP do
							obj.Visible = false
						end
						continue
					end
				end
	
				if not ent.RootPart or not ent.RootPart.Parent then
					for _, obj in EntityESP do obj.Visible = false end
					continue
				end
				local rootPos, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
				for _, obj in EntityESP do
					obj.Visible = rootVis
				end
				if not rootVis then continue end
	
				local topPos = gameCamera:WorldToViewportPoint((CFrame.lookAlong(ent.RootPart.Position, gameCamera.CFrame.LookVector) * CFrame.new(1.4, 2.6, 0)).p)
				local bottomPos = gameCamera:WorldToViewportPoint((CFrame.lookAlong(ent.RootPart.Position, gameCamera.CFrame.LookVector) * CFrame.new(-1.4, -3.2, 0)).p)
				local sizex, sizey = math.abs(topPos.X - bottomPos.X), math.abs(topPos.Y - bottomPos.Y)
				local posx, posy = (rootPos.X - sizex / 2),  ((rootPos.Y - sizey / 2))
				EntityESP.Main.Position = Vector2.new(posx, posy) // 1
				EntityESP.Main.Size = Vector2.new(sizex, sizey) // 1
				if EntityESP.Border then
					EntityESP.Border.Position = Vector2.new(posx - 1, posy + 1) // 1
					EntityESP.Border.Size = Vector2.new(math.max(sizex + 2, 0), math.max(sizey - 2, 0)) // 1
					EntityESP.Border2.Position = Vector2.new(posx + 1, posy - 1) // 1
					EntityESP.Border2.Size = Vector2.new(math.max(sizex - 2, 0), math.max(sizey + 2, 0)) // 1
				end
	
				if EntityESP.HealthLine then
					local healthposy = sizey * math.clamp(ent.Health / ent.MaxHealth, 0, 1)
					EntityESP.HealthLine.Visible = ent.Health > 0
					EntityESP.HealthLine.From = Vector2.new(posx - 6, posy + (sizey - (sizey - healthposy))) // 1
					EntityESP.HealthLine.To = Vector2.new(posx - 6, posy) // 1
					EntityESP.HealthBorder.From = Vector2.new(posx - 6, posy + 1) // 1
					EntityESP.HealthBorder.To = Vector2.new(posx - 6, (posy + sizey) - 1) // 1
				end
	
				if EntityESP.Text then
					EntityESP.Text.Position = Vector2.new(posx + (sizex / 2), posy + (sizey - 28)) // 1
					EntityESP.Drop.Position = EntityESP.Text.Position + Vector2.new(1, 1)
					if EntityESP.TextBKG then
						EntityESP.TextBKG.Size = EntityESP.Text.TextBounds + Vector2.new(8, 4)
						EntityESP.TextBKG.Position = EntityESP.Text.Position - Vector2.new(4 + (EntityESP.Text.TextBounds.X / 2), 0)
					end
				end
			end
		end,
		Drawing3D = function()
			for ent, EntityESP in Reference do
				if not ent.RootPart or not ent.RootPart.Parent then
					for _, obj in EntityESP do obj.Visible = false end
					continue
				end
				if Distance.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						for _, obj in EntityESP do
							obj.Visible = false
						end
						continue
					end
				end
	
				local _, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
				for _, obj in EntityESP do
					obj.Visible = rootVis
				end
				if not rootVis then continue end
	
				local point1 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, ent.HipHeight, 1.5))
				local point2 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, -ent.HipHeight, 1.5))
				local point3 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, ent.HipHeight, 1.5))
				local point4 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, -ent.HipHeight, 1.5))
				local point5 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, ent.HipHeight, -1.5))
				local point6 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, -ent.HipHeight, -1.5))
				local point7 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, ent.HipHeight, -1.5))
				local point8 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, -ent.HipHeight, -1.5))
				EntityESP.Line1.From = point1
				EntityESP.Line1.To = point2
				EntityESP.Line2.From = point3
				EntityESP.Line2.To = point4
				EntityESP.Line3.From = point5
				EntityESP.Line3.To = point6
				EntityESP.Line4.From = point7
				EntityESP.Line4.To = point8
				EntityESP.Line5.From = point1
				EntityESP.Line5.To = point3
				EntityESP.Line6.From = point1
				EntityESP.Line6.To = point5
				EntityESP.Line7.From = point5
				EntityESP.Line7.To = point7
				EntityESP.Line8.From = point7
				EntityESP.Line8.To = point3
				EntityESP.Line9.From = point2
				EntityESP.Line9.To = point4
				EntityESP.Line10.From = point2
				EntityESP.Line10.To = point6
				EntityESP.Line11.From = point6
				EntityESP.Line11.To = point8
				EntityESP.Line12.From = point8
				EntityESP.Line12.To = point4
			end
		end,
		DrawingSkeleton = function()
			for ent, EntityESP in Reference do
				if not ent.RootPart or not ent.RootPart.Parent then
					for _, obj in EntityESP do obj.Visible = false end
					continue
				end
				if Distance.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						for _, obj in EntityESP do
							obj.Visible = false
						end
						continue
					end
				end
	
				local _, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
				for _, obj in EntityESP do
					obj.Visible = rootVis
				end
				if not rootVis then continue end
				
				local rigcheck = ent.Humanoid.RigType == Enum.HumanoidRigType.R6
				pcall(function()
					local offset = rigcheck and CFrame.new(0, -0.8, 0) or CFrame.identity
					local head = ESPWorldToViewport((ent.Head.CFrame).p)
					local headfront = ESPWorldToViewport((ent.Head.CFrame * CFrame.new(0, 0, -0.5)).p)
					local toplefttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-1.5, 0.8, 0)).p)
					local toprighttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(1.5, 0.8, 0)).p)
					local toptorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, 0.8, 0)).p)
					local bottomtorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, -0.8, 0)).p)
					local bottomlefttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-0.5, -0.8, 0)).p)
					local bottomrighttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0.5, -0.8, 0)).p)
					local leftarm = ESPWorldToViewport((ent.Character[(rigcheck and 'Left Arm' or 'LeftHand')].CFrame * offset).p)
					local rightarm = ESPWorldToViewport((ent.Character[(rigcheck and 'Right Arm' or 'RightHand')].CFrame * offset).p)
					local leftleg = ESPWorldToViewport((ent.Character[(rigcheck and 'Left Leg' or 'LeftFoot')].CFrame * offset).p)
					local rightleg = ESPWorldToViewport((ent.Character[(rigcheck and 'Right Leg' or 'RightFoot')].CFrame * offset).p)
					EntityESP.Head.From = toptorso
					EntityESP.Head.To = head
					EntityESP.HeadFacing.From = head
					EntityESP.HeadFacing.To = headfront
					EntityESP.UpperTorso.From = toplefttorso
					EntityESP.UpperTorso.To = toprighttorso
					EntityESP.Torso.From = toptorso
					EntityESP.Torso.To = bottomtorso
					EntityESP.LowerTorso.From = bottomlefttorso
					EntityESP.LowerTorso.To = bottomrighttorso
					EntityESP.LeftArm.From = toplefttorso
					EntityESP.LeftArm.To = leftarm
					EntityESP.RightArm.From = toprighttorso
					EntityESP.RightArm.To = rightarm
					EntityESP.LeftLeg.From = bottomlefttorso
					EntityESP.LeftLeg.To = leftleg
					EntityESP.RightLeg.From = bottomrighttorso
					EntityESP.RightLeg.To = rightleg
				end)
			end
		end
	}
	
	ESP = vape.Categories.Render:CreateModule({
		Name = 'ESP',
		Function = function(callback)
			if callback then
				methodused = 'Drawing'..Method.Value
				if ESPRemoved[methodused] then
					ESP:Clean(entitylib.Events.EntityRemoved:Connect(ESPRemoved[methodused]))
				end
				if ESPAdded[methodused] then
					for _, v in entitylib.List do
						if Reference[v] then
							ESPRemoved[methodused](v)
						end
						ESPAdded[methodused](v)
					end
					ESP:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
						if Reference[ent] then
							ESPRemoved[methodused](ent)
						end
						ESPAdded[methodused](ent)
					end))
				end
				if ESPUpdated[methodused] then
					ESP:Clean(entitylib.Events.EntityUpdated:Connect(ESPUpdated[methodused]))
					for _, v in entitylib.List do
						ESPUpdated[methodused](v)
					end
				end
				if ColorFunc[methodused] then
					ESP:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
						ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
					end))
				end
				if ESPLoop[methodused] then
					ESP:Clean(runService.RenderStepped:Connect(ESPLoop[methodused]))
				end
			else
				if ESPRemoved[methodused] then
					for i in Reference do
						ESPRemoved[methodused](i)
					end
				end
			end
		end,
		Tooltip = 'Extra Sensory Perception\nRenders an ESP on players.'
	})
	Targets = ESP:CreateTargets({
		Players = true,
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end
	})
	Method = ESP:CreateDropdown({
		Name = 'Mode',
		List = {'2D', '3D', 'Skeleton'},
		Function = function(val)
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
			BoundingBox.Object.Visible = (val == '2D')
			Filled.Object.Visible = (val == '2D')
			HealthBar.Object.Visible = (val == '2D')
			Name.Object.Visible = (val == '2D')
			DisplayName.Object.Visible = Name.Object.Visible and Name.Enabled
			Background.Object.Visible = Name.Object.Visible and Name.Enabled
		end,
	})
	Color = ESP:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if ESP.Enabled and ColorFunc[methodused] then
				ColorFunc[methodused](hue, sat, val)
			end
		end
	})
	BoundingBox = ESP:CreateToggle({
		Name = 'Bounding Box',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Default = true,
		Darker = true
	})
	Filled = ESP:CreateToggle({
		Name = 'Filled',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Darker = true
	})
	HealthBar = ESP:CreateToggle({
		Name = 'Health Bar',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Darker = true
	})
	Name = ESP:CreateToggle({
		Name = 'Name',
		Function = function(callback)
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
			DisplayName.Object.Visible = callback
			Background.Object.Visible = callback
		end,
		Darker = true
	})
	DisplayName = ESP:CreateToggle({
		Name = 'Use Displayname',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Default = true,
		Darker = true
	})
	Background = ESP:CreateToggle({
		Name = 'Show Background',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Darker = true
	})
	Teammates = ESP:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
	Distance = ESP:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = ESP:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)
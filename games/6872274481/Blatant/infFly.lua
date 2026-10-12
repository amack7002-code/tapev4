run(function()
	local v2 = httpService
	local v3 = playersService
	local v4 = replicatedStorage
	local v5 = runService
	local v6 = inputService
	local v7 = tweenService
	local v8 = collectionService
	local v9 = guiService
	local v10 = game:GetService('TeleportService')
	local obj = debug
	local currentCamera = gameCamera
	local localPlayer = lplr
	local entity = entitylib
	local getfontbounds = getfontsize
	local getvapeasset = getcustomasset
	if AetherMatchRuntime and AetherMatchRuntime.Movement and aetherPortAddMovementOwner then
		aetherPortAddMovementOwner('InfiniteFly')
	end
	local function queryBaseParts(model)
		local ok, list = pcall(function()
			return model:QueryDescendants("BasePart")
		end)
		if ok and type(list) == "table" then return list end
		local out = {}
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then table.insert(out, part) end
		end
		return out
	end

		local v12 = nil
		local v13 = nil
		local textLabel = nil
		local clone = nil
		local n = 0
		local n2 = 0
		local flag = false
		local part = Instance.new("Part")
		part.Parent = workspace
		part.Transparency = 1
		part.CanQuery = false
		part.CanTouch = false
		part.CanCollide = false
		part.Anchored = true
		vape:Clean(part)
		local obj2 = setmetatable({}, { __mode = "k" })

		local function fn5()
			for _, v14 in {
				entity.character.Humanoid.MoveDirection,
				Vector3.new(1, 0, 0),
				Vector3.new(0, 0, 1),
				Vector3.new(-1, 0, 0),
				Vector3.new(0, 0, -1),
			}, nil, nil do
				for i = 1, 4 do
					local v15 = workspace:Blockcast(entity.character.RootPart.CFrame + Vector3.new(0, 200, 0) + v14 * i, Vector3.new(3, 3, 3), Vector3.new(0, -1000, 0), store.airRay)
					if v15 then
						return v15
					end
				end
			end

			return false
		end

		v12 = vape.Categories.Blatant:CreateModule({
			Name = "InfiniteFly",
			Function = function(visible)
				if textLabel and clone then
					textLabel.Visible = visible
					clone.Visible = visible
				end

				if visible then
					if not entity.isAlive or flag or workspace:Raycast(entity.character.RootPart.Position, Vector3.new(0, -1000, 0), store.airRay) then
						notif("InfiniteFly", "Cannot fly at this state.", 8, "warning")
						v12:Toggle()
						return
					end

					if entity.isAlive then
						currentCamera.CameraSubject = part

						for _, v14 in queryBaseParts(entity.character.Character) do
							obj2[v14] = v14.Transparency
							v14.Transparency = 1
						end
					end

					part.CFrame = entity.character.Character.Head.CFrame
					store.infinitefly = true
					vape.MovementOwner = "InfiniteFly"
					flag = true
					local rootPart = entity.character.RootPart
					local cframe = CFrame.new(rootPart.Position)
					rootPart.CFrame = cframe

					v12:Clean(v6.InputBegan:Connect(function(input)
						if not v6:GetFocusedTextBox() then
							if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
								n = 1
							elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
								n2 = -1
							end
						end
					end))

					v12:Clean(v6.InputEnded:Connect(function(input)
						if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
							n = 0
						elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
							n2 = 0
						end
					end))

					v12:Clean(v5.PreSimulation:Connect(function(deltaTime)
						if not entity.isAlive or not rootPart or not isnetworkowner(rootPart) then
							notif("InfiniteFly", "Network ownership disowned", 10, "alert")
							v12:Toggle()
							return
						end

						if workspace:Raycast(rootPart.Position, Vector3.new(0, -1000, 0), store.airRay) then
							notif("InfiniteFly", "Landing", 3.5, "alert")
							v12:Toggle()
							return
						end

						local cframe2 = CFrame.new(Vector3.new(rootPart.Position.X, part.CFrame.Y, rootPart.Position.Z))
						part.CFrame = cframe2 + Vector3.new(0, deltaTime * (n + n2) * v13.Value, 0)

						if textLabel and clone then
							textLabel.Text = ("%* blocks"):format(math.round((cframe.Position - cframe2.Position).Magnitude / 3))
							clone.Text = textLabel.Text
						end

						if rootPart.CFrame.Y <= part.CFrame.Y + 4 or fn5() then
							local lookVector = rootPart.CFrame.LookVector
							rootPart.CFrame = CFrame.lookAlong(Vector3.new(rootPart.CFrame.X, part.CFrame.Y + 4 + 125, rootPart.CFrame.Z), lookVector)
						end
					end))
				elseif store.infinitefly then
					store.infinitefly = false
					-- drop the fall speed before landing
					local hold = v5.PreSimulation:Connect(function()
						if entity.isAlive then
							local velocity = entity.character.RootPart.AssemblyLinearVelocity
							entity.character.RootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
						end
					end)
					task.wait(0.3)
					local isAlive = entity.isAlive and fn5()

					if isAlive then
						entity.character.RootPart.CFrame = CFrame.new(isAlive.Position + Vector3.new(0, 3.5, 0))
					end
					hold:Disconnect()

					notif("InfiniteFly", "Landed", 2.5, "info")
					flag = false

					if entity.isAlive then
						for _, v14 in queryBaseParts(entity.character.Character) do
							v14.Transparency = obj2[v14] or v14.Transparency
						end

						currentCamera.CameraSubject = entity.character.Character
					end

					if vape.MovementOwner == "InfiniteFly" then
						vape.MovementOwner = nil
					end
				end
			end,
			Tooltip = "Makes you go zoom. Fly, InfiniteJump, HighJump, LongJump and the other movement modules except Speed stop working until it has fully landed",
			ExtraText = function()
				return "Heatseeker"
			end,
		})

		v13 = v12:CreateSlider({
			Name = "Vertical Speed",
			Min = 1,
			Max = 150,
			Default = 50,
			Suffix = function(arg)
				return arg <= 1 and "stud" or "studs"
			end,
		})

		v12:CreateToggle({
			Name = "Show distance",
			Function = function(arg)
				if arg then
					textLabel = Instance.new("TextLabel")
					textLabel.Size = UDim2.fromOffset(100, 20)
					textLabel.Position = UDim2.new(0.5, 6, 0.5, 60)
					textLabel.BackgroundTransparency = 1
					textLabel.AnchorPoint = Vector2.new(0.5, 0)
					textLabel.Text = "0 blocks"
					textLabel.ZIndex = 6
					textLabel.TextColor3 = Color3.new(1, 1, 1)
					textLabel.TextSize = 18
					textLabel.RichText = true
					textLabel.FontFace = vape.Libraries.uipallet.FontDisplay
					textLabel.Visible = v12.Enabled
					textLabel.Parent = vape.gui
					clone = textLabel:Clone()
					clone.ZIndex = 5
					clone.AnchorPoint = Vector2.new(0.5, 0)
					clone.Position = clone.Position + UDim2.fromOffset(1, 1)
					clone.Text = textLabel.ContentText
					clone.TextColor3 = Color3.new()
					clone.Parent = vape.gui
				else
					if clone then
						clone:Destroy()
						clone = nil
					end

					if textLabel then
						textLabel:Destroy()
						textLabel = nil
					end
				end
			end,
			Default = true,
		})
	end)

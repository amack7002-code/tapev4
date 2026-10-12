run(function()
	local Scaffold
	local Expand
	local Tower
	local Downwards
	local Diagonal
	local LimitItem
	local Mouse
	local FillColor
	local OutlineColor
	local label, visualBlock, visualTween, visualPos
	local nextId = 500000
	local lastPlace = 0
	local lastpos = Vector3.zero

	-- the game's own two steps: a local stand-in block, then the request with its id
	local function place(name, position)
		local template = bedfight.Blocks:FindFirstChild(name)
		local container = workspace:FindFirstChild('FakeBlocksContainer')
		if not (template and container) then return end
		nextId += 1
		local id, queue = nextId, bedfight.Block.BlocksInQueue
		local fake = template:Clone()
		fake:PivotTo(CFrame.new(position))
		fake.Parent = container
		queue[id] = {Block = fake, LastTime = time()}
		fireRemote('PlaceBlock', name, id, position)
		-- the server answers by removing it. unanswered ones go after a while
		task.delay(3, function()
			if queue[id] then
				queue[id] = nil
			end
			fake:Destroy()
		end)
	end

	-- the game's own answer to "may a block go here"
	local function buildable(position)
		local ok, info = bedfight.Block.GetBuildResult(nil, position, 3)
		return ok and info and not info.InsideAntiBuild and info.InBounds ~= false, info
	end

	local function clearVisual()
		if visualTween then
			visualTween:Cancel()
			visualTween = nil
		end
		if visualBlock then
			visualBlock.Parent = nil
		end
		visualPos = nil
	end

	local function showVisual(position)
		if not visualBlock or visualPos == position then return end
		if visualTween then
			visualTween:Cancel()
			visualTween = nil
		end
		if visualBlock.Parent == gameCamera then
			visualTween = tweenService:Create(visualBlock, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = CFrame.new(position)})
			visualTween:Play()
		else
			visualBlock.CFrame = CFrame.new(position)
			visualBlock.Parent = gameCamera
		end
		visualPos = position
	end

	Scaffold = vape.Categories.Utility:CreateModule({
		Name = 'Scaffold',
		ExtraText = function()
			return tostring(Expand.Value)
		end,
		Function = function(callback)
			if label then
				label.Visible = callback
			end
			if callback then
				local switched = false
				repeat
					local placed = false
					local amount = 0
					if canFight() then
						local held = heldName()
						local block = LimitItem.Enabled and (held and bedfight.Blocks:FindFirstChild(held) and getItem(held) and held) or (not LimitItem.Enabled and getBlock())
						amount = block and getItem(block) or 0
						if block and Mouse.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
							block = nil
						end
						if block then
							local hum, root = entitylib.character.Humanoid, entitylib.character.RootPart
							local sneak = Downwards.Enabled and inputService:IsKeyDown(Enum.KeyCode.LeftShift) and not inputService:GetFocusedTextBox()
							if Tower.Enabled and inputService:IsKeyDown(Enum.KeyCode.Space) and not inputService:GetFocusedTextBox() and hum.MoveDirection.Magnitude < 0.1 then
								root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 32, root.AssemblyLinearVelocity.Z)
							end

							local feet = root.Position - Vector3.new(0, entitylib.character.HipHeight + (sneak and 4.5 or 1.5), 0)
							local move = hum.MoveDirection
							for i = 0, Expand.Value - 1 do
								local position = snap(feet + move * (i * 3))
								local previous = lastpos
								if i == 0 then
									-- walking at 45 degrees, the block stays put until the next one touches it corner to corner
									if Diagonal.Enabled and move.Magnitude > 0.1 and math.abs(math.round(math.deg(math.atan2(-move.X, -move.Z)) / 45) * 45) % 90 == 45 then
										local dt = lastpos - position
										if ((dt.X == 0 and dt.Z ~= 0) or (dt.X ~= 0 and dt.Z == 0)) and ((lastpos - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 then
											position = lastpos
										end
									end
									lastpos = position
									showVisual(position)
								end

								local ok, info = buildable(position)
								if not ok and i == 0 and info and not info.Collided and not info.Connected and previous.Y == position.Y then
									-- nothing next to it yet: fill the corner between the last block and this one first
									for _, filler in {Vector3.new(previous.X, position.Y, position.Z), Vector3.new(position.X, position.Y, previous.Z)} do
										if filler ~= position and buildable(filler) then
											position, ok = filler, true
											break
										end
									end
								end
								if ok then
									placed = true
									switched = true
									if tick() - lastPlace >= bedfight.BlocksData.Default.Cooldown and (equipServer(block, 'Scaffold') or (store.sentAt and tick() - store.sentAt > 0.6)) then
										lastPlace = tick()
										place(block, position)
									end
									break
								end
							end
						else
							clearVisual()
						end
					else
						clearVisual()
					end

					if label then
						label.Text = amount..' <font color="rgb(170, 170, 170)">(Scaffold)</font>'
						label.TextColor3 = Color3.fromHSV(math.clamp(amount / 128, 0, 1) / 2.8, 0.86, 1)
					end
					if switched and not placed and tick() - lastPlace > 0.4 then
						switched = false
						syncTool('Scaffold')
					end
					task.wait(0.03)
				until not Scaffold.Enabled
				clearVisual()
			else
				syncTool('Scaffold')
				clearVisual()
			end
		end,
		Tooltip = 'Places blocks under you as you walk'
	})
	Expand = Scaffold:CreateSlider({
		Name = 'Expand',
		Min = 1,
		Max = 5,
		Default = 1,
		Tooltip = 'How many blocks ahead it builds'
	})
	Tower = Scaffold:CreateToggle({
		Name = 'Tower',
		Default = true,
		Tooltip = 'Hold Space while standing still to build straight up'
	})
	Downwards = Scaffold:CreateToggle({
		Name = 'Downwards',
		Default = true,
		Tooltip = 'Hold Shift to build one block lower'
	})
	Diagonal = Scaffold:CreateToggle({
		Name = 'Diagonal',
		Tooltip = 'Walking diagonally builds a straight diagonal line instead of a staircase. Where the game refuses a block that only touches by its corner, the corner is filled in first'
	})
	LimitItem = Scaffold:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only while you hold a block'
	})
	Mouse = Scaffold:CreateToggle({Name = 'Require mouse down'})
	Scaffold:CreateToggle({
		Name = 'Visual',
		Function = function(callback)
			FillColor.Object.Visible = callback
			OutlineColor.Object.Visible = callback
			if callback then
				visualBlock = Instance.new('Part')
				visualBlock.Size = Vector3.new(3, 3, 3)
				visualBlock.Anchored = true
				visualBlock.CanCollide = false
				visualBlock.CanQuery = false
				visualBlock.CanTouch = false
				visualBlock.CastShadow = false
				visualBlock.Transparency = 1
				local selection = Instance.new('SelectionBox')
				selection.Adornee = visualBlock
				selection.LineThickness = 0.04
				selection.Color3 = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
				selection.Transparency = 1 - OutlineColor.Opacity
				selection.SurfaceColor3 = Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
				selection.SurfaceTransparency = 1 - FillColor.Opacity
				selection.Parent = visualBlock
			else
				clearVisual()
				if visualBlock then
					visualBlock:Destroy()
					visualBlock = nil
				end
			end
		end,
		Tooltip = 'Renders an overlay on the block about to be placed'
	})
	FillColor = Scaffold:CreateColorSlider({
		Name = 'Fill colour',
		DefaultSat = 0,
		DefaultOpacity = 0.4,
		Darker = true,
		Visible = false,
		Function = function(hue, sat, val, opacity)
			if visualBlock then
				visualBlock.SelectionBox.SurfaceColor3 = Color3.fromHSV(hue, sat, val)
				visualBlock.SelectionBox.SurfaceTransparency = 1 - opacity
			end
		end
	})
	OutlineColor = Scaffold:CreateColorSlider({
		Name = 'Outline colour',
		DefaultValue = 0,
		Darker = true,
		Visible = false,
		Function = function(hue, sat, val, opacity)
			if visualBlock then
				visualBlock.SelectionBox.Color3 = Color3.fromHSV(hue, sat, val)
				visualBlock.SelectionBox.Transparency = 1 - opacity
			end
		end
	})
	Scaffold:CreateToggle({
		Name = 'Block Count',
		Function = function(callback)
			if callback then
				label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 60)
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Text = '0'
				label.TextColor3 = Color3.new(0, 1, 0)
				label.TextSize = 18
				label.RichText = true
				label.Font = Enum.Font.Arial
				label.Visible = Scaffold.Enabled
				label.Parent = vape.gui
			elseif label then
				label:Destroy()
				label = nil
			end
		end
	})
end)

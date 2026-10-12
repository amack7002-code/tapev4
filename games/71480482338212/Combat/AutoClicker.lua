run(function()
	local AutoClicker
	local Attack
	local CPS
	local Place
	local BlockCPS = {Object = {}}

	local function canClick()
		if inputService:GetFocusedTextBox() then return false end
		local menu = vape.gui:FindFirstChild('ScaledGui')
		menu = menu and menu:FindFirstChild('ClickGui')
		return not (menu and menu.Visible)
	end

	-- what the held item is to the game, a sword, a block or neither
	local function heldKind()
		local name = heldName()
		if not name then return nil end
		if type(bedfight.SwordsData[name]) == 'table' then
			return Attack.Enabled and 'sword' or nil
		end
		local data = bedfight.ItemsData and bedfight.ItemsData[name]
		if data and data.Class == 'Blocks' then
			return Place.Enabled and 'block' or nil
		end
		return nil
	end

	AutoClicker = vape.Categories.Combat:CreateModule({
		Name = 'AutoClicker',
		Function = function(callback)
			if callback then
				local nextClick
				repeat
					local kind = entitylib.isAlive and inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and canClick() and heldKind()
					if kind then
						local now = os.clock()
						local cps = math.max((kind == 'block' and BlockCPS or CPS):GetRandomValue(), 1)
						if not nextClick then
							-- the press itself is the game's own first click
							nextClick = now + 1 / cps
						elseif now >= nextClick then
							nextClick = now + 1 / cps
							local signals = bedfight.Signals
							if kind == 'sword' then
								store.swung = tick()
								if signals and signals.MobileSword then
									signals.MobileSword:Fire()
								end
							elseif signals and signals.MobileBuild then
								signals.MobileBuild:Fire()
							end
						end
					else
						nextClick = nil
					end
					task.wait()
				until not AutoClicker.Enabled
			end
		end,
		Tooltip = 'Hold attack button to automatically click'
	})
	Attack = AutoClicker:CreateToggle({
		Name = 'Attack',
		Default = true,
		Function = function(callback)
			if CPS and CPS.Object then
				CPS.Object.Visible = callback
			end
		end,
		Tooltip = 'Swings your sword while the attack button is held'
	})
	CPS = AutoClicker:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 20,
		DefaultMin = 9,
		DefaultMax = 9
	})
	Place = AutoClicker:CreateToggle({
		Name = 'Place Blocks',
		Function = function(callback)
			if BlockCPS.Object then
				BlockCPS.Object.Visible = callback
			end
		end,
		Tooltip = 'Places through the game\'s build button, which builds where you are walking'
	})
	BlockCPS = AutoClicker:CreateTwoSlider({
		Name = 'Block CPS',
		Min = 1,
		Max = 20,
		DefaultMin = 12,
		DefaultMax = 12,
		Darker = true,
		Visible = false
	})
end)

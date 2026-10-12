run(function()
	local AutoConsume
	local Health
	local SpeedPotion
	local Apple
	local ShieldPotion
	local SerpentsTouch
	local JumpPotion
	local LimitToItem
	local Delay
	local NoSlow
	local consuming = false
	local heldTrack
	local GoldenApple
	local GoldenAppleHealth
	local SpeedPie
	
	local function consumeCheck(attribute)
		if entitylib.isAlive then
			if SpeedPotion.Enabled and (not attribute or attribute == 'StatusEffect_speed') then
				local speedpotion = getItem('speed_potion')
				if speedpotion and (not lplr.Character:GetAttribute('StatusEffect_speed')) then
					task.spawn(function()
						for _ = 1, 4 do
							local result = false
							bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({item = speedpotion.tool}):andThen(function(r)
								result = r
							end):await()
							if result then break end
						end
					end)
				end
			end
	
			if Apple.Enabled and (not attribute or attribute:find('Health')) then
				if (lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) <= (Health.Value / 100) then
					local inv = replicatedStorage:FindFirstChild('Inventories') and replicatedStorage.Inventories:FindFirstChild(lplr.Name)
					local appleItem = inv and (inv:FindFirstChild('orange') or inv:FindFirstChild('apple'))
					if appleItem then
						replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = appleItem})
					end
				end
			end

			if GoldenApple and GoldenApple.Enabled and (not attribute or attribute:find('Health')) then
				local gaHealth = GoldenAppleHealth and GoldenAppleHealth.Value or 50
				local currentHPPct = (lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth') * 100)
				local inv = replicatedStorage:FindFirstChild('Inventories') and replicatedStorage.Inventories:FindFirstChild(lplr.Name)
				local gaItem = inv and inv:FindFirstChild('golden_apple')
				if currentHPPct <= gaHealth and gaItem then
					replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = gaItem})
				end
			end

			if SpeedPie and SpeedPie.Enabled then
				local speedPieActive = false
				local statusHud = lplr.PlayerGui:FindFirstChild('StatusEffectHudScreen')
				if statusHud then
					local hud = statusHud:FindFirstChild('StatusEffectHud')
					if hud then
						local speedPieFrame = hud:FindFirstChild('Speed Pie')
						if speedPieFrame then
							local timer = speedPieFrame:FindFirstChild('4')
							if timer and timer:IsA('TextLabel') then
								local val = tonumber(timer.Text)
								speedPieActive = val and val > 0
							end
						end
					end
				end
				if not speedPieActive then
					local inv = replicatedStorage:FindFirstChild('Inventories') and replicatedStorage.Inventories:FindFirstChild(lplr.Name)
					local pieItem = inv and inv:FindFirstChild('pie')
					if pieItem then
						replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = pieItem})
					end
				end
			end

			if ShieldPotion.Enabled and (not attribute or attribute:find('Shield')) then
				if (lplr.Character:GetAttribute('Shield_POTION') or 0) == 0 then
					local shield = getItem('big_shield') or getItem('mini_shield')
	
					if shield then
						replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = shield.tool})
					end
				end
			end
		end
	end
	
	local function heldConsume()
		if consuming then return end
		local tool = store.hand.tool
		if not tool then return end
		local item = getItem(tool.Name)
		if not item then return end
		local meta = bedwars.ItemMeta[item.itemType]
		if not meta or not meta.consumable then return end

		consuming = true
		local humanoid = lplr.Character and lplr.Character:FindFirstChildOfClass('Humanoid')
		local anim = Instance.new('Animation')
		anim.AnimationId = 'rbxassetid://4968114448'
		if humanoid then
			heldTrack = humanoid:LoadAnimation(anim)
			heldTrack:Play()
		end

		if NoSlow.Enabled and humanoid then
			local normalSpeed = humanoid.WalkSpeed
			task.spawn(function()
				while consuming and NoSlow.Enabled do
					humanoid.WalkSpeed = normalSpeed
					task.wait()
				end
			end)
		end

		task.wait(Delay.Value)

		if heldTrack then
			heldTrack:Stop()
			heldTrack = nil
		end

		if consuming and store.hand.tool and store.hand.tool.Name == tool.Name then
			local currentItem = getItem(tool.Name)
			if currentItem then
				replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = currentItem.tool})
			end
		end
		consuming = false
	end

	AutoConsume = vape.Categories.Inventory:CreateModule({
		Name = 'AutoConsume',
		Function = function(callback)
			if callback then
				local throttle = 0
				local throttledCheck = function()
					local now = tick()
					if now - throttle < 0.2 then return end
					throttle = now
					consumeCheck()
				end
				AutoConsume:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(throttledCheck))
				AutoConsume:Clean(vapeEvents.AttributeChanged.Event:Connect(function(attribute)
					if attribute:find('Shield') or attribute:find('Health') then
						throttledCheck()
					end
				end))
				consumeCheck()
				task.spawn(function()
					local lastTool
					while AutoConsume.Enabled do
						if LimitToItem.Enabled then
							local tool = store.hand.tool
							if tool and tool.Name ~= lastTool then
								lastTool = tool.Name
								heldConsume()
							elseif not tool then
								lastTool = nil
							end
						end
						task.wait(0.2)
					end
				end)
				task.spawn(function()
					while AutoConsume.Enabled do
						task.wait(0.3)
						if SerpentsTouch.Enabled then
							local serpent = getItem('serpents_touch_potion')
							if serpent then
								replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = serpent.tool})
							end
						end
						if JumpPotion.Enabled then
							local jumppotion = getItem('jump_potion')
							if jumppotion then
								replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = jumppotion.tool})
							end
						end
						if ShieldPotion.Enabled and (lplr.Character:GetAttribute('Shield_POTION') or 0) == 0 then
							local shield = getItem('big_shield') or getItem('mini_shield')
							if shield then
								replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = shield.tool})
							end
						end
					end
				end)
				task.spawn(function()
					while AutoConsume.Enabled do
						task.wait(0.5)
						if not SpeedPie or not SpeedPie.Enabled then continue end
						local speedPieActive = false
						local statusHud = lplr.PlayerGui:FindFirstChild('StatusEffectHudScreen')
						if statusHud then
							local hud = statusHud:FindFirstChild('StatusEffectHud')
							if hud then
								local speedPieFrame = hud:FindFirstChild('Speed Pie')
								if speedPieFrame then
									local timer = speedPieFrame:FindFirstChild('4')
									if timer and timer:IsA('TextLabel') then
										local val = tonumber(timer.Text)
										speedPieActive = val and val > 0
									end
								end
							end
						end
						if not speedPieActive then
							local inv = replicatedStorage:FindFirstChild('Inventories') and replicatedStorage.Inventories:FindFirstChild(lplr.Name)
							local pieItem = inv and inv:FindFirstChild('pie')
							if pieItem then
								replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = pieItem})
							end
						end
					end
				end)
			end
		end,
		Tooltip = 'Automatically heals for you when health or shield is under threshold.'
	})
	SpeedPotion = AutoConsume:CreateToggle({
		Name = 'Speed Potions',
		Default = true
	})
	Apple = AutoConsume:CreateToggle({
		Name = 'Apple',
		Default = true,
		Function = function(callback)
			if Health then
				Health.Object.Visible = callback
			end
		end
	})
	Health = AutoConsume:CreateSlider({
		Name = 'Health Percent',
		Min = 1,
		Max = 99,
		Default = 70,
		Suffix = '%',
		Visible = false
	})
	ShieldPotion = AutoConsume:CreateToggle({
		Name = 'Shield Potions',
		Default = true
	})
	GoldenApple = AutoConsume:CreateToggle({
		Name = 'Golden Apple',
		Default = false,
		Function = function(callback)
			if GoldenAppleHealth then
				GoldenAppleHealth.Object.Visible = callback
			end
		end
	})
	GoldenAppleHealth = AutoConsume:CreateSlider({
		Name = 'Eat At HP%',
		Min = 1,
		Max = 99,
		Default = 50,
		Suffix = '%',
		Visible = false
	})
	SpeedPie = AutoConsume:CreateToggle({
		Name = 'Speed Pie',
		Default = false
	})
	SerpentsTouch = AutoConsume:CreateToggle({
		Name = 'Serpents Potion',
		Default = true,
		Tooltip = 'auto drinks ur serpents touch potion when u got one'
	})
	JumpPotion = AutoConsume:CreateToggle({
		Name = 'Jump Potion',
		Default = true,
		Tooltip = 'auto chugs jump potions for u'
	})
	LimitToItem = AutoConsume:CreateToggle({
		Name = 'Limit To Item',
		Default = false,
		Function = function(callback)
			if Delay then
				Delay.Object.Visible = callback
			end
		end,
		Tooltip = 'only consumes stuff when ur actually holding it, waits the delay first'
	})
	Delay = AutoConsume:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 3,
		Default = 1,
		Suffix = 's',
		Visible = false,
		Tooltip = 'how long to wait before it actually eats it'
	})
	NoSlow = AutoConsume:CreateToggle({
		Name = 'No Slow',
		Default = false,
		Tooltip = 'stops u from getting slowed down while eating/drinking stuff'
	})
end)
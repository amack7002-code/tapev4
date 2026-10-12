run(function()
	local ShopClicker
	local HoldDelay
	local CPS
	local guiService = cloneref(game:GetService('GuiService'))
	local holding = false
	local clickThread
	local catalog

	-- every blacksmith item by the name its card carries, with the call that buys it
	local function items()
		if catalog then return catalog end
		local shop = skywars.Shop and skywars.Shop.Blacksmith
		if type(shop) ~= 'table' then return {} end
		catalog = {}
		for _, upgrade in shop.ItemUpgrades or {} do
			for _, item in upgrade.Items or {} do
				if item.ItemType then
					catalog[item.ItemType] = {Remote = 'purchaseItemUpgrade', Index = upgrade.ItemIndex, Item = item}
				end
			end
		end
		for _, item in shop.Items or {} do
			if item.ItemType then
				catalog[item.ItemType] = {Remote = 'purchaseItem', Index = item.ItemIndex, Item = item}
			end
		end
		return catalog
	end

	local function getHoveredItem()
		local list = items()
		local mouse = inputService:GetMouseLocation() - guiService:GetGuiInset()
		for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y) do
			local obj = v
			while obj and obj ~= lplr.PlayerGui do
				-- the card is the one frame that holds both the picture and the buy button
				if list[obj.Name] and obj:FindFirstChild('ButtonClipping', true) then
					return obj.Name
				end
				obj = obj.Parent
			end
		end
		return nil
	end

	local function purchase(name)
		local entry = items()[name]
		if not (entry and entry.Index) then return end
		local currency = skywars.Store:getState().GameCurrency
		local have = currency and currency.Quantities and currency.Quantities[entry.Item.CurrencyType] or 0
		if entry.Item.Price and have < entry.Item.Price then return end
		fireRemote(entry.Remote, 'Blacksmith', entry.Index)
	end

	local function startClicking(name)
		if clickThread then
			task.cancel(clickThread)
		end
		clickThread = task.spawn(function()
			repeat
				-- the card is only under the cursor while the shop is open
				if getHoveredItem() == name then
					purchase(name)
				end
				task.wait(1 / CPS.Value)
			until not holding
			clickThread = nil
		end)
	end

	ShopClicker = vape.Categories.Utility:CreateModule({
		Name = 'ShopClicker',
		Function = function(callback)
			if callback then
				ShopClicker:Clean(inputService.InputBegan:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
					local name = getHoveredItem()
					if not name then return end

					holding = true
					task.delay(HoldDelay.Value, function()
						if holding and getHoveredItem() == name then
							startClicking(name)
						end
					end)
				end))

				ShopClicker:Clean(inputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						holding = false
					end
				end))
			else
				holding = false
				if clickThread then
					task.cancel(clickThread)
					clickThread = nil
				end
			end
		end,
		Tooltip = 'Hold on a blacksmith item to rapidly buy or upgrade it'
	})
	HoldDelay = ShopClicker:CreateSlider({
		Name = 'Hold Delay',
		Min = 0,
		Max = 1,
		Default = 0.15,
		Decimal = 20,
		Suffix = 'seconds'
	})
	CPS = ShopClicker:CreateSlider({
		Name = 'CPS',
		Min = 1,
		Max = 20,
		Default = 20,
		Darker = true
	})
end)

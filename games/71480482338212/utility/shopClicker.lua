run(function()
	local ShopClicker
	local HoldDelay
	local CPS
	local guiService = cloneref(game:GetService('GuiService'))
	local holding = false
	local clickThread
	local shopList, shopKit

	local function shopGui()
		local gui = lplr.PlayerGui:FindFirstChild('ItemShopGui')
		return gui and gui:IsA('LayerCollector') and gui.Enabled and gui or nil
	end

	-- every item button sits in a category frame inside the shop's list, named after its item
	local function getHoveredItem(gui)
		local list = gui:FindFirstChild('ItemsListFrame', true)
		if not list then return nil end
		local mouse = inputService:GetMouseLocation() - guiService:GetGuiInset()
		for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y) do
			local obj = v
			while obj and obj ~= gui do
				local category = obj.Parent
				if category and category.Parent == list then
					return obj.Name
				end
				obj = category
			end
		end
		return nil
	end

	local function find(name)
		local value = lplr:FindFirstChild('Kit')
		local kit = value and value.Value or ''
		if not shopList or shopKit ~= kit then
			shopList, shopKit = bedfight.ItemShopData.GetItemShop(false, kit), kit
		end
		for _, entry in shopList do
			for _, data in entry.List do
				if data.Name == name then
					return entry.Category, data
				end
			end
		end
	end

	-- the stand of the shop that is open, the way the game's own buy button finds it
	local function stand(gui)
		local module = gui:FindFirstChild('InfoFrameHandler')
		local ok, handler = pcall(function()
			return module and require(module)
		end)
		local part = ok and type(handler) == 'table' and handler.Prompt
		if typeof(part) == 'Instance' and part:IsDescendantOf(workspace) then
			return part
		end
		local best, dist = nil, 10
		for _, v in collectionService:GetTagged('ItemShopPrompt') do
			if v:IsA('BasePart') and v:IsDescendantOf(workspace) then
				local mag = (v.Position - entitylib.character.RootPart.Position).Magnitude
				if mag <= dist then
					best, dist = v, mag
				end
			end
		end
		return best
	end

	local function purchase(gui, name)
		if not entitylib.isAlive then return end
		local category, data = find(name)
		if not category then return end
		-- the game's own "can I buy this" answer
		local module = gui:FindFirstChild('ItemShopHandler')
		local ok, result = pcall(function()
			return require(module).GetBuyResult(name, data)
		end)
		if not ok or result ~= 'Buy' then return end
		local part = stand(gui)
		if part then
			fireRemote('PurchaseItemShopItem', part, category, name)
		end
	end

	local function startClicking(name)
		if clickThread then
			task.cancel(clickThread)
		end
		clickThread = task.spawn(function()
			repeat
				local gui = shopGui()
				if gui then
					purchase(gui, name)
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
					local gui = shopGui()
					local name = gui and getHoveredItem(gui)
					if not name then return end

					holding = true
					task.delay(HoldDelay.Value, function()
						local open = shopGui()
						if holding and open and getHoveredItem(open) == name then
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
		Tooltip = 'Hold on a shop item to rapidly buy it'
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

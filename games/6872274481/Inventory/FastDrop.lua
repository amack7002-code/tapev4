run(function()
	local FastDrop
	local DropDelay
	local ItemList
	local UseBind
	local BBind
	local CurrentBind = Enum.KeyCode.H

	local function getInputEnum(inputName)
		if string.find(inputName, "MouseButton") then
			return Enum.UserInputType[inputName]
		else
			return Enum.KeyCode[inputName]
		end
	end

	local function isInputDown(input)
		if typeof(input) == "EnumItem" then
			if input.EnumType == Enum.KeyCode then
				return inputService:IsKeyDown(input)
			elseif input.EnumType == Enum.UserInputType then
				return inputService:IsMouseButtonPressed(input)
			end
		end
		return false
	end

	FastDrop = vape.Categories.Inventory:CreateModule({
		Name = 'FastDrop',
		Function = function(callback)
			if callback then

				repeat
					if entitylib.isAlive and (not store.inventory.opened) and (isInputDown(CurrentBind)) and inputService:GetFocusedTextBox() == nil then
						if tick() - store.lastDropTime >= (DropDelay.Value / 1000) then
							local handItem = store.hand and store.hand.tool
							if handItem then
								local itemType = handItem.Name
								local listEnabled = ItemList.ListEnabled
								
								local shouldDrop = true
								if #listEnabled > 0 then
									shouldDrop = table.find(listEnabled, itemType) ~= nil
								end
								
								if shouldDrop then
									task.spawn(bedwars.ItemDropController.dropItemInHand)
									store.lastDropTime = tick()
								end
							end
							task.wait()
						else
							task.wait(0.01)
						end
					else
						task.wait(0.1)
					end
				until not FastDrop.Enabled
			else
				store.lastDropTime = tick() + DropDelay.Value
			end
		end,
		Tooltip = 'Drops items fast'
	})

	DropDelay = FastDrop:CreateSlider({
		Name = 'Drop Delay',
		Min = 0,
		Max = 500,
		Default = 0,
		Suffix = 'ms'
	})
	
	ItemList = FastDrop:CreateTextList({
		Name = 'Item Whitelist',
		Placeholder = 'Item name (e.g., wool_blue)',
	})
end)
run(function()
    local ShopAutoClicker 
    local CPS
    local holding = false
    local clickThread
    
    local function getShopId()
        if not entitylib.isAlive then return nil end
        local localPosition = entitylib.character.RootPart.Position
        local id
        for _, v in store.shop do
            if v.Shop and (v.RootPart.Position - localPosition).Magnitude <= 20 then
                id = v.Id
            end
        end
        return id
    end
    
    local function getHoveredItem(pos)
        local mousepos = (pos or inputService:GetMouseLocation()) - guiService:GetGuiInset()
        for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
            local obj = v
            while obj and obj ~= lplr.PlayerGui do
                local itemType = obj.Name:match('^(.+)_ShopItemCard$')
                if itemType then
                    return itemType
                end
                obj = obj.Parent
            end
        end
    end
    
    local function canBuy(item)
        if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
        if item.lockedByForge or item.disabled then return false end
        if item.require and item.require.teamUpgrade then
            if (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
                return false
            end
        end
        local currency = getItem(item.currency)
        return (currency and currency.amount or 0) >= item.price
    end
    
    local function purchase(itemType, shopId)
        if bedwars.BedwarsShopController.alreadyPurchasedMap[itemType] ~= nil then return end
    
        local item = bedwars.Shop.getShopItem(itemType, lplr, {shopId = shopId})
        if not item or not canBuy(item) then return end
    
        bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({
            shopItem = item,
            shopId = shopId
        }):andThen(function(suc)
            if not suc then return end
            bedwars.SoundManager:playSound(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
            bedwars.Store:dispatch({
                type = 'BedwarsAddItemPurchased',
                itemType = itemType
            })
            if item.tiered then
                bedwars.BedwarsShopController.alreadyPurchasedMap[itemType] = true
            end
        end)
    end
    
    local function startClicking(itemType)
        if clickThread then
            task.cancel(clickThread)
        end
        clickThread = task.spawn(function()
            repeat
                local shopId = bedwars.AppController:isAppOpen('BedwarsItemShopApp') and store.shopLoaded and getShopId()
                if shopId then
                    purchase(itemType, shopId)
                end
                task.wait(1 / CPS.Value)
            until not holding
            clickThread = nil
        end)
    end
    
    ShopAutoClicker = vape.Categories.Combat:CreateModule({
        Name = 'ShopAutoClicker',
        Tooltip = 'hold on a shop item to buy - idea from seven (cv)',
        Function = function(callback)
            if callback then
                ShopAutoClicker:Clean(inputService.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
                    if not bedwars.AppController:isAppOpen('BedwarsItemShopApp') then return end
    
                    local pos
                    if input.UserInputType == Enum.UserInputType.Touch then
                        pos = Vector2.new(input.Position.X, input.Position.Y)
                    end
                    local itemType = getHoveredItem(pos)
                    if not itemType then return end
    
                    holding = true
                    task.delay(0.1, function() 
                        if holding and getHoveredItem(pos) == itemType then
                            startClicking(itemType)
                        end
                    end)
                end))
    
                ShopAutoClicker:Clean(inputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
        end
    })
    CPS = ShopAutoClicker:CreateSlider({
        Name = 'CPS',
        Min = 1,
        Max = 20,
        Default = 20
    })
end)
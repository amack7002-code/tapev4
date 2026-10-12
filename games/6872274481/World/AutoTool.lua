run(function()
    local AutoTool

    local function switchHotbarItem(block)
        if not AutoTool.Enabled or not entitylib.isAlive or not block or not block.Parent then return end
        if block:GetAttribute('NoBreak') or block:GetAttribute('Team'..(lplr:GetAttribute('Team') or 0)..'NoBreak') then return end
        local meta = bedwars.ItemMeta and bedwars.ItemMeta[block.Name]
        local breakType = block.Name == 'gumdrop_bounce_pad' and 'stone' or (meta and meta.block and meta.block.breakType)
        if not breakType then return end
        local tool = store.tools and store.tools[breakType]
        if not tool or not tool.tool or not tool.tool.Parent then return end
        local inventory = store.inventory
        if not inventory then return end
        local slot
        for i, v in (inventory.hotbar or {}) do
            if v.item and v.item.itemType == tool.itemType then
                slot = i - 1
                break
            end
        end
        if slot == nil then return end
        if inventory.hotbarSlot ~= slot then
            bedwars.Store:dispatch({type = 'InventorySelectHotbarSlot', slot = slot})
        end
        -- Equip without waiting for InventoryChanged or recursively restarting mining.
        switchItem(tool.tool, 0)
    end
    
    AutoTool = vape.Categories.World:CreateModule({
        Name = 'AutoTool',
        Function = function(callback)
            if callback then
                registerHitBlockPatch('AutoTool', function(self, maid, raycastparams, ...)
                    local ok, block = pcall(function()
                        return self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
                    end)
                    if not ok then return nil end
                    local inst = block and block.target and block.target.blockInstance or nil
                    switchHotbarItem(inst)
                    return nil
                end)
            else
                unregisterHitBlockPatch('AutoTool')
            end
        end,
        Tooltip = 'auto selects the correct tool'
    })
end)
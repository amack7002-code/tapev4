run(function()
    local _sharedHitBlock = nil
    local _hitBlockPatchers = {}

    getgenv().registerHitBlockPatch = function(key, fn)
        _hitBlockPatchers[key] = fn
        if not _sharedHitBlock and bedwars.BlockBreaker then
            _sharedHitBlock = bedwars.BlockBreaker.hitBlock
        end
        if not bedwars.BlockBreaker then return end
        bedwars.BlockBreaker.hitBlock = function(self, maid, raycastparams, ...)
            for _, patcher in _hitBlockPatchers do
                local result = patcher(self, maid, raycastparams, ...)
                if result ~= nil then return result end
            end
            if _sharedHitBlock then return _sharedHitBlock(self, maid, raycastparams, ...) end
        end
    end

    getgenv().unregisterHitBlockPatch = function(key)
        _hitBlockPatchers[key] = nil
        if not next(_hitBlockPatchers) then
            if bedwars.BlockBreaker then
                bedwars.BlockBreaker.hitBlock = _sharedHitBlock
            end
            _sharedHitBlock = nil
        end
    end

    local FastBreak
    local Time
    local BedCheck
    local Blacklist
    local blocks
    local string_lower = string.lower
    local string_find = string.find
    local task_wait = task.wait
    local currentBlock = nil
    local oldHitBlock = nil
    local lastHotbarSlot = nil
    local bedCache = {}
    local blacklistCache = {}
    local lastCacheClean = 0
    local cacheCleanInterval = 5 
    
    local function isBed(block)
        if not block then return false end
        local cached = bedCache[block]
        if cached ~= nil then return cached end
        
        local result = false
        pcall(function()
            if collectionService:HasTag(block, 'bed') or (block.Parent and collectionService:HasTag(block.Parent, 'bed')) then
                result = true
            elseif string_find(string_lower(block.Name), 'bed', 1, true) then
                result = true
            end
        end)
        
        if result then bedCache[block] = true end
        return result
    end
    
    local cachedBlacklistLower = {}
    local function updateBlacklistCache()
        if not blocks or not blocks.ListEnabled then return end
        
        cachedBlacklistLower = {}
        for _, v in pairs(blocks.ListEnabled) do
            table.insert(cachedBlacklistLower, string_lower(v))
        end
    end
    
    local function isBlacklisted(block)
        if not block or #cachedBlacklistLower == 0 then return false end
        local cached = blacklistCache[block]
        if cached ~= nil then return cached end
        
        local name = string_lower(block.Name)
        local result = false
        for i = 1, #cachedBlacklistLower do
            if string_find(name, cachedBlacklistLower[i], 1, true) then
                result = true
                break
            end
        end
        
        blacklistCache[block] = result
        return result
    end
    
    local function shouldSkip(block)
        if not block then return false end
        if BedCheck and BedCheck.Enabled and isBed(block) then return true end
        if Blacklist and Blacklist.Enabled and isBlacklisted(block) then return true end
        return false
    end
    
    local lastBreakUpdate = 0
    local breakUpdateCooldown = 0.05
    local pendingUpdate = false
    
    local function updateBreakSpeed()
        if not FastBreak or not FastBreak.Enabled then return end
        local now = tick()
        if now - lastBreakUpdate < breakUpdateCooldown then
            pendingUpdate = true
            return
        end
        lastBreakUpdate = now
        pendingUpdate = false
        
        pcall(function()
            local cooldown = (shouldSkip(currentBlock)) and 0.3 or Time.Value
            bedwars.BlockBreakController.blockBreaker:setCooldown(cooldown)
        end)
    end
    
    FastBreak = vape.Categories.Blatant:CreateModule({
        Name = 'FastBreak',
        Function = function(callback)
            if callback then
                lastHotbarSlot = nil

				registerHitBlockPatch('FastBreak', function(self, maid, raycastparams, ...)
					local block = nil
					pcall(function()
						local blockInfo = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
						if blockInfo and blockInfo.target and blockInfo.target.blockInstance then
							block = blockInfo.target.blockInstance
						end
					end)
					
					local currentSlot = store.inventory and store.inventory.hotbarSlot
					local slotChanged = currentSlot ~= lastHotbarSlot
					if slotChanged then
						lastHotbarSlot = currentSlot
					end

					if block ~= currentBlock or slotChanged then
						currentBlock = block
						updateBreakSpeed()
					end
					end)
                
                updateBlacklistCache()
                
                task.spawn(function()
                    while FastBreak.Enabled do
                        if tick() - lastCacheClean > cacheCleanInterval then
                            lastCacheClean = tick()
                            bedCache = {}
                            blacklistCache = {}
                        end
                        if pendingUpdate then updateBreakSpeed() end
                        task_wait(0.05) 
                    end
                end)
			else
				pcall(function() bedwars.BlockBreakController.blockBreaker:setCooldown(0.3) end)
				unregisterHitBlockPatch('FastBreak')
				currentBlock = nil
				lastHotbarSlot = nil
				bedCache, blacklistCache, cachedBlacklistLower = {}, {}, {}
			end
        end,
        Tooltip = 'mine faster'
    })
    
    Time = FastBreak:CreateSlider({
        Name = 'Break speed',
        Min = 0, Max = 0.3, Default = 0.25, Decimal = 100, Suffix = 'seconds',
        Function = function() updateBreakSpeed() end
    })
    
    BedCheck = FastBreak:CreateToggle({
        Name = 'Bed Check',
        Default = false,
        Tooltip = 'mining is normal when breaking beds',
        Function = function() bedCache = {}; updateBreakSpeed() end
    })
    
    Blacklist = FastBreak:CreateToggle({
        Name = 'Blacklist Blocks',
        Default = false,
        Tooltip = 'mining is normal for blacklisted blocks',
        Function = function(v)
            if blocks then blocks.Object.Visible = v end
            blacklistCache = {}
            if v then updateBlacklistCache() end
            updateBreakSpeed()
        end
    })
    
    blocks = FastBreak:CreateTextList({
        Name = 'Blacklisted Blocks',
        Placeholder = 'bed',
        Visible = false,
        Function = function()
            updateBlacklistCache()
            blacklistCache = {}
            updateBreakSpeed()
        end
    })
end)
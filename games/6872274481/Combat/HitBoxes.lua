run(function()
    local Mode
    local Expand
    local AutoToggle
    local Visible
    local VisibleColor
    local Targets
    local objects = {}
    local set = false
    local hitboxesActive = false
    local autoToggleConnection = nil
    local autoToggleFrameCounter = 0

    local vector3new = Vector3.new
    local vector3one = Vector3.one

    local colorList = {
        Red = Color3.fromRGB(255, 0, 0),
        Blue = Color3.fromRGB(0, 100, 255),
        Green = Color3.fromRGB(0, 255, 0),
        Yellow = Color3.fromRGB(255, 255, 0),
        Orange = Color3.fromRGB(255, 140, 0),
        Purple = Color3.fromRGB(180, 0, 255),
        White = Color3.fromRGB(255, 255, 255),
        Cyan = Color3.fromRGB(0, 255, 255),
        Pink = Color3.fromRGB(255, 50, 150),
        Black = Color3.fromRGB(0, 0, 0)
    }

    local function shouldCreateHitbox(ent)
        if not ent.Targetable then return false end
        if ent.Player and Targets and Targets.Players and Targets.Players.Enabled then return true end
        if not ent.Player and Targets and Targets.NPCs and Targets.NPCs.Enabled then return true end
        return false
    end

    local _wallRayParams = RaycastParams.new()
    _wallRayParams.FilterType = Enum.RaycastFilterType.Exclude
    local function isTargetBehindWall(ent)
        if not Targets or not Targets.Walls or not Targets.Walls.Enabled then return false end
        if not ent.RootPart then return false end
        if not entitylib.isAlive or not entitylib.character or not entitylib.character.RootPart then return false end
        local origin = entitylib.character.RootPart.Position
        local target = ent.RootPart.Position
        local direction = target - origin
        _wallRayParams.FilterDescendantsInstances = {entitylib.character, ent.Character}
        local result = workspace:Raycast(origin, direction, _wallRayParams)
        if result then
            local hitDist = (result.Position - origin).Magnitude
            local targetDist = direction.Magnitude
            if hitDist < targetDist - 0.5 then return true end
        end
        return false
    end

    local cachedExpandSize = vector3new(3, 6, 3)
    local lastExpandValue = 0
    local function updateExpandSize(val)
        if val ~= lastExpandValue then
            lastExpandValue = val
            cachedExpandSize = vector3new(3, 6, 3) + vector3one * (val / 5)
        end
    end

    local function createHitbox(ent)
        if not shouldCreateHitbox(ent) then return end
        if isTargetBehindWall(ent) then return end
        if objects[ent] then return end
        for _, old in ent.Character:GetChildren() do
            if old.Name == 'AeroHitbox' then old:Destroy() end
        end
        local hitbox = Instance.new('Part')
        hitbox.Name = 'AeroHitbox'
        hitbox.Archivable = false
        hitbox.Size = cachedExpandSize
        hitbox.Position = ent.RootPart.Position
        hitbox.CanCollide = false
        hitbox.Massless = true
        hitbox.Transparency = Visible and Visible.Enabled and 0.5 or 1
        hitbox.LocalTransparencyModifier = Visible and Visible.Enabled and 0 or 1
        if Visible and Visible.Enabled and VisibleColor then
            hitbox.Color = colorList[VisibleColor.Value] or colorList.Red
        end
        hitbox.Parent = ent.Character
        local weld = Instance.new('Motor6D')
        weld.Part0 = hitbox
        weld.Part1 = ent.RootPart
        weld.Parent = hitbox
        local ev = Instance.new('ObjectValue')
        ev.Name = 'EntityValue'
        ev.Value = ent.Character
        ev.Parent = hitbox
        game:GetService('CollectionService'):AddTag(hitbox, 'Hitbox')
        hitbox:GetPropertyChangedSignal('Transparency'):Connect(function()
            local want = Visible and Visible.Enabled and 0.5 or 1
            if hitbox.Transparency ~= want then
                hitbox.Transparency = want
            end
        end)
        hitbox:GetPropertyChangedSignal('LocalTransparencyModifier'):Connect(function()
            local want = Visible and Visible.Enabled and 0 or 1
            if hitbox.LocalTransparencyModifier ~= want then
                hitbox.LocalTransparencyModifier = want
            end
        end)
        objects[ent] = hitbox
    end

    local function clearHitboxes()
        for _, part in pairs(objects) do part:Destroy() end
        table.clear(objects)
        for _, plr in playersService:GetPlayers() do
            local char = plr.Character
            if char then
                for _, old in char:GetChildren() do
                    if old.Name == 'AeroHitbox' then old:Destroy() end
                end
            end
        end
        for _, ent in entitylib.List do
            local char = ent.Character
            if char then
                for _, old in char:GetChildren() do
                    if old.Name == 'AeroHitbox' then old:Destroy() end
                end
            end
        end
    end

    local function refreshAllHitboxes()
        clearHitboxes()
        local entityList = entitylib.List
        for i = 1, #entityList do
            createHitbox(entityList[i])
        end
    end

    local function handleAutoToggle()
        if not AutoToggle or not AutoToggle.Enabled then return end
        if not HitBoxes.Enabled or Mode.Value ~= 'Player' then return end
        local holdingSword = isSword()
        if holdingSword and not hitboxesActive then
            hitboxesActive = true
            refreshAllHitboxes()
        elseif not holdingSword and hitboxesActive then
            hitboxesActive = false
            clearHitboxes()
        end
    end

    HitBoxes = vape.Categories.Combat:CreateModule({
        Name = 'HitBoxes',
        Function = function(callback)
            if callback then
                updateExpandSize(Expand.Value)
                if Mode.Value == 'Sword' then
                    debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Expand.Value / 3))
                    set = true
                else
                    HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
                        if AutoToggle and AutoToggle.Enabled then
                            if hitboxesActive then createHitbox(ent) end
                        else
                            createHitbox(ent)
                        end
                    end))
                    HitBoxes:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
                        local obj = objects[ent]
                        if obj then obj:Destroy() objects[ent] = nil end
                    end))
                    if AutoToggle and AutoToggle.Enabled then
                        handleAutoToggle()
                        if not autoToggleConnection or not autoToggleConnection.Connected then
                            autoToggleFrameCounter = 0
                            autoToggleConnection = runService.Heartbeat:Connect(function()
                                autoToggleFrameCounter = autoToggleFrameCounter + 1
                                if autoToggleFrameCounter % 5 == 0 then
                                    handleAutoToggle()
                                end
                            end)
                            HitBoxes:Clean(autoToggleConnection)
                        end
                    else
                        refreshAllHitboxes()
                    end
                    local hitboxThrottleCounter = 0
                    HitBoxes:Clean(runService.Heartbeat:Connect(function()
                        if not Targets or not Targets.Walls or not Targets.Walls.Enabled then return end
                        hitboxThrottleCounter = hitboxThrottleCounter + 1
                        if hitboxThrottleCounter % 20 ~= 0 then return end
                        for ent, part in pairs(objects) do
                            if isTargetBehindWall(ent) then
                                part:Destroy()
                                objects[ent] = nil
                            end
                        end
                        local entityList = entitylib.List
                        for i = 1, #entityList do
                            local ent = entityList[i]
                            if not objects[ent] then
                                if AutoToggle and AutoToggle.Enabled then
                                    if hitboxesActive then createHitbox(ent) end
                                else
                                    createHitbox(ent)
                                end
                            end
                        end
                    end))
                end
            else
                hitboxesActive = false
                if set then
                    debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
                    set = false
                end
                clearHitboxes()
            end
        end,
        Tooltip = 'increases attack hitbox'
    })

    Targets = HitBoxes:CreateTargets({
        Players = true,
        Walls = false,
        NPCs = false,
        Function = function()
            if HitBoxes.Enabled and Mode.Value == 'Player' then
                if AutoToggle and AutoToggle.Enabled then
                    if hitboxesActive then refreshAllHitboxes() end
                else
                    refreshAllHitboxes()
                end
            end
        end
    })

    Mode = HitBoxes:CreateDropdown({
        Name = 'Mode',
        List = {'Sword', 'Player'},
        Function = function(val)
            local isPlayer = val == 'Player'
            if AutoToggle then AutoToggle.Object.Visible = isPlayer end
            if Visible then Visible.Object.Visible = isPlayer end
            if VisibleColor then VisibleColor.Object.Visible = isPlayer and Visible.Enabled end
            if HitBoxes.Enabled then HitBoxes:Toggle() HitBoxes:Toggle() end
        end,
    })

    Expand = HitBoxes:CreateSlider({
        Name = 'Expand amount',
        Min = 0,
        Max = 30,
        Default = 14.4,
        Decimal = 10,
        Function = function(val)
            updateExpandSize(val)
            if HitBoxes.Enabled then
                if Mode.Value == 'Sword' then
                    debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (val / 3))
                else
                    for _, part in pairs(objects) do part.Size = cachedExpandSize end
                end
            end
        end,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })

    AutoToggle = HitBoxes:CreateToggle({
        Name = 'Auto Toggle',
        Default = false,
        Tooltip = 'enables hitbox when holding sword, disable when not',
        Function = function(callback)
            if callback then
                if autoToggleConnection then autoToggleConnection:Disconnect() end
                hitboxesActive = false
                autoToggleFrameCounter = 0
                autoToggleConnection = runService.Heartbeat:Connect(function()
                    autoToggleFrameCounter = autoToggleFrameCounter + 1
                    if autoToggleFrameCounter % 5 == 0 then
                        handleAutoToggle()
                    end
                end)
                HitBoxes:Clean(autoToggleConnection)
                handleAutoToggle()
            else
                if autoToggleConnection then
                    autoToggleConnection:Disconnect()
                    autoToggleConnection = nil
                end
                hitboxesActive = false
                if HitBoxes.Enabled and Mode.Value == 'Player' then
                    refreshAllHitboxes()
                end
            end
        end
    })

    Visible = HitBoxes:CreateToggle({
        Name = 'Visible',
        Default = false,
        Function = function(callback)
            if VisibleColor then VisibleColor.Object.Visible = callback end
            if HitBoxes.Enabled and Mode.Value == 'Player' then
                local transparency = callback and 0.5 or 1
                local col = callback and VisibleColor and (colorList[VisibleColor.Value] or colorList.Red) or nil
                for _, part in pairs(objects) do
                    part.LocalTransparencyModifier = callback and 0 or 1
                    part.Transparency = transparency
                    if col then part.Color = col end
                end
            end
        end
    })

    VisibleColor = HitBoxes:CreateDropdown({
        Name = 'Hitbox Color',
        List = {'Red', 'Blue', 'Green', 'Yellow', 'Orange', 'Purple', 'White', 'Cyan', 'Pink', 'Black'},
        Default = 'Red',
        Visible = false,
        Function = function(val)
            if HitBoxes.Enabled and Mode.Value == 'Player' and Visible.Enabled then
                local col = colorList[val] or colorList.Red
                for _, part in pairs(objects) do part.Color = col end
            end
        end
    })

    task.spawn(function()
        repeat task.wait() until Mode and Mode.Value
        local isPlayer = Mode.Value == 'Player'
        AutoToggle.Object.Visible = isPlayer
        Visible.Object.Visible = isPlayer
    end)

    task.defer(function()
        if VisibleColor and VisibleColor.Object then
            VisibleColor.Object.Visible = false
        end
    end)
end)
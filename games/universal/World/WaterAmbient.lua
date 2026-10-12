run(function()
    local WaterAmbient
    local WaterColor
    local WaterExpand
    local WaterDepth
    local WaterHeight
    local terrain = workspace:FindFirstChildOfClass('Terrain')
    local generation = 0
    local savedChunks
    local originalWaterSettings
    local MAX_CHUNK_STUDS = 512
    local MAX_HALF_EXTENT = 2048
    local MAX_DEPTH_STUDS = 32

    local function getExpand()
        return (WaterExpand and WaterExpand.Value) or 256
    end

    local function getDepth()
        local d = (WaterDepth and WaterDepth.Value) or 12
        return math.clamp(d, 4, MAX_DEPTH_STUDS)
    end

    local function getHeight()
        local h = (WaterHeight and WaterHeight.Value) or -12
        -- Older profiles may contain positive heights; never flood the ground.
        return math.clamp(h, -100, -4)
    end

    local function groundUnderPlayer()
        local character = entitylib.isAlive and entitylib.character
        local rootPart = character and character.RootPart
        if not rootPart or not rootPart.Parent then return nil end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local characters = {}
        for _, player in playersService:GetPlayers() do
            if player.Character then table.insert(characters, player.Character) end
        end
        params.FilterDescendantsInstances = characters
        params.IgnoreWater = true
        params.RespectCanCollide = true
        local hit = workspace:Raycast(rootPart.Position + Vector3.new(0, 4, 0), Vector3.new(0, -2000, 0), params)
        if hit then return hit.Position.Y end
        return nil
    end

    local function findMapBounds()
        local lowest, minX, maxX, minZ, maxZ
        for _, v in collectionService:GetTagged('block') do
            if v and v.Parent and v:IsA('BasePart') and v:IsDescendantOf(workspace) then
                local pos = v.Position
                local half = v.Size / 2
                lowest = math.min(lowest or (pos.Y - half.Y), pos.Y - half.Y)
                minX, maxX = math.min(minX or (pos.X - half.X), pos.X - half.X), math.max(maxX or (pos.X + half.X), pos.X + half.X)
                minZ, maxZ = math.min(minZ or (pos.Z - half.Z), pos.Z - half.Z), math.max(maxZ or (pos.Z + half.Z), pos.Z + half.Z)
            end
        end
        if lowest then
            local groundY = groundUnderPlayer()
            if groundY then lowest = math.min(lowest, groundY) end
            local expand = getExpand()
            local cx = (minX + maxX) / 2
            local cz = (minZ + maxZ) / 2
            minX = math.max(minX - 512 - expand, cx - MAX_HALF_EXTENT)
            maxX = math.min(maxX + 512 + expand, cx + MAX_HALF_EXTENT)
            minZ = math.max(minZ - 512 - expand, cz - MAX_HALF_EXTENT)
            maxZ = math.min(maxZ + 512 + expand, cz + MAX_HALF_EXTENT)
            return {
                minX = minX,
                maxX = maxX,
                minZ = minZ,
                maxZ = maxZ,
                waterY = lowest + getHeight()
            }
        end

        local character = entitylib.isAlive and entitylib.character
        local rootPart = character and character.RootPart
        if not rootPart or not rootPart.Parent then return nil end
        local floorY = groundUnderPlayer()
        -- Do not anchor water to an airborne character when no floor is loaded.
        if not floorY then return nil end
        local radius = math.min(768 + getExpand(), MAX_HALF_EXTENT)
        return {
            minX = rootPart.Position.X - radius,
            maxX = rootPart.Position.X + radius,
            minZ = rootPart.Position.Z - radius,
            maxZ = rootPart.Position.Z + radius,
            waterY = floorY + getHeight()
        }
    end

    local function makeWaterRegions(bounds, depth)
        local regions = {}
        -- ExpandToGrid rounds upper bounds upward; snap the surface down first.
        local y1 = math.floor(bounds.waterY / 4) * 4
        local y0 = y1 - depth
        local x = bounds.minX
        while x < bounds.maxX do
            local x2 = math.min(x + MAX_CHUNK_STUDS, bounds.maxX)
            local z = bounds.minZ
            while z < bounds.maxZ do
                local z2 = math.min(z + MAX_CHUNK_STUDS, bounds.maxZ)
                table.insert(regions, Region3.new(
                    Vector3.new(x, y0, z),
                    Vector3.new(x2, y1, z2)
                ):ExpandToGrid(4))
                z = z2
            end
            x = x2
        end
        return regions
    end

    local function restoreWater()
        if terrain and savedChunks then
            for _, chunk in ipairs(savedChunks) do
                local ok, err = pcall(function()
                    terrain:WriteVoxels(chunk.Region, 4, chunk.Materials, chunk.Occupancy)
                end)
                if not ok then warn('[WaterAmbient] failed to restore terrain: ' .. tostring(err)) end
                task.wait()
            end
        end
        if terrain and originalWaterSettings then
            pcall(function()
                terrain.WaterColor = originalWaterSettings.Color
                terrain.WaterTransparency = originalWaterSettings.Transparency
                terrain.WaterReflectance = originalWaterSettings.Reflectance
                terrain.WaterWaveSize = originalWaterSettings.WaveSize
                terrain.WaterWaveSpeed = originalWaterSettings.WaveSpeed
            end)
        end
        savedChunks = nil
        originalWaterSettings = nil
    end

    local function applyWater(currentGeneration)
        if not terrain or not WaterAmbient.Enabled or generation ~= currentGeneration then return end
        local bounds = findMapBounds()
        if not bounds then return end

        local depth = getDepth()
        local regions = makeWaterRegions(bounds, depth)
        originalWaterSettings = {
            Color = terrain.WaterColor,
            Transparency = terrain.WaterTransparency,
            Reflectance = terrain.WaterReflectance,
            WaveSize = terrain.WaterWaveSize,
            WaveSpeed = terrain.WaterWaveSpeed
        }
        local chunks = {}
        local ok, err = pcall(function()
            for _, region in ipairs(regions) do
                if not WaterAmbient.Enabled or generation ~= currentGeneration then break end
                local materials, occupancy = terrain:ReadVoxels(region, 4)
                table.insert(chunks, {Region = region, Materials = materials, Occupancy = occupancy})
                task.wait()
            end
        end)
        if not ok or not WaterAmbient.Enabled or generation ~= currentGeneration then
            savedChunks = chunks
            restoreWater()
            if not ok then warn('[WaterAmbient] failed to create terrain water: ' .. tostring(err)) end
            return
        end
        savedChunks = chunks
        local okFill, errFill = pcall(function()
            for _, chunk in ipairs(chunks) do
                if not WaterAmbient.Enabled or generation ~= currentGeneration then break end
                terrain:FillBlock(chunk.Region.CFrame, chunk.Region.Size, Enum.Material.Water)
                task.wait()
            end
        end)
        if not okFill then
            restoreWater()
            warn('[WaterAmbient] failed to create terrain water: ' .. tostring(errFill))
            return
        end
        if not WaterAmbient.Enabled or generation ~= currentGeneration then
            restoreWater()
            return
        end
        pcall(function()
            terrain.WaterColor = Color3.fromHSV(WaterColor.Hue, WaterColor.Sat, WaterColor.Value)
            terrain.WaterTransparency = 0.25
            terrain.WaterReflectance = 0.7
            terrain.WaterWaveSize = 0.13
            terrain.WaterWaveSpeed = 8
        end)
    end

    WaterAmbient = vape.Categories.World:CreateModule({
        Name = 'WaterAmbient',
        Tooltip = 'Fills the lower map with animated Terrain water.',
        Function = function(callback)
            generation += 1
            local currentGeneration = generation
            if callback then
                task.spawn(function()
                    for _ = 1, 40 do
                        if not WaterAmbient.Enabled or generation ~= currentGeneration then return end
                        if findMapBounds() then
                            applyWater(currentGeneration)
                            return
                        end
                        task.wait(0.25)
                    end
                    if WaterAmbient.Enabled and generation == currentGeneration then
                        applyWater(currentGeneration)
                    end
                end)
            else
                restoreWater()
            end
        end
    })

    WaterColor = WaterAmbient:CreateColorSlider({
        Name = 'Water Color',
        Tooltip = 'Color of the water.',
        Function = function(h, s, v)
            if WaterAmbient.Enabled and terrain and originalWaterSettings then
                terrain.WaterColor = Color3.fromHSV(h, s, v)
            end
        end
    })

    WaterExpand = WaterAmbient:CreateSlider({
        Name = 'Expand Size',
        Min = 0,
        Max = 1024,
        Default = 256,
        Tooltip = 'Extra padding around the water area. Re-toggle to apply.'
    })

    WaterDepth = WaterAmbient:CreateSlider({
        Name = 'Water Depth',
        Min = 4,
        Max = 32,
        Default = 12,
        Tooltip = 'How deep the water is. Re-toggle to apply.'
    })

    WaterHeight = WaterAmbient:CreateSlider({
        Name = 'Water Height',
        Min = -100,
        Max = -4,
        Default = -12,
        Tooltip = 'Water surface offset below the lowest ground. More negative = lower water. Re-toggle to apply.'
    })
end)
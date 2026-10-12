run(function()
    local AntiFall
    local Mode
    local Material
    local Color
	local rayCheck = cloneRaycast()
    rayCheck.RespectCanCollide = true

    local math_huge = math.huge
    local tick = tick
    local task_wait = task.wait
    local vector3new = Vector3.new
    local vector3zero = Vector3.zero
    
    local cachedLowGround = math_huge
    local lastGroundScan = 0
    local groundScanInterval = 2 
    
    local function getLowGround()
        local now = tick()
        if now - lastGroundScan < groundScanInterval and cachedLowGround ~= math_huge then
            return cachedLowGround
        end
        
        lastGroundScan = now
        local mag = math_huge
        local blockStore = bedwars.BlockController:getStore()
        local allPositions = blockStore:getAllBlockPositions()
        
        for i = 1, #allPositions do
            local pos = allPositions[i] * 3
            if pos.Y < mag and not getPlacedBlock(pos + vector3new(0, 3, 0)) then
                mag = pos.Y
            end
        end
        
        cachedLowGround = mag
        return mag
    end

    AntiFall = vape.Categories.Blatant:CreateModule({
        Name = 'AntiFall',
        Function = function(callback)
            if callback then
                repeat task_wait() until store.matchState ~= 0 or (not AntiFall.Enabled)
                if not AntiFall.Enabled then return end

                local pos, debounce = getLowGround(), tick()
                if pos ~= math_huge then
                    AntiFallPart = Instance.new('Part')
                    AntiFallPart.Size = vector3new(10000, 1, 10000)
                    AntiFallPart.Transparency = 1 - Color.Opacity
                    AntiFallPart.Material = Enum.Material[Material.Value]
                    AntiFallPart.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                    AntiFallPart.Position = vector3new(0, pos - 2, 0)
                    AntiFallPart.CanCollide = Mode.Value == 'Collide'
                    AntiFallPart.Anchored = true
                    AntiFallPart.CanQuery = false
                    AntiFallPart.Parent = workspace
                    AntiFall:Clean(AntiFallPart)
                    
                    AntiFall:Clean(AntiFallPart.Touched:Connect(function(touched)
                        if touched.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
                            debounce = tick() + 0.1
                            
                            if Mode.Value == 'Normal' then
                                local top = getNearGround()
                                if top then
                                    local lastTeleport = lplr:GetAttribute('LastTeleported')
                                    local connection
                                    local frameCounter = 0
                                    
                                    local vapeModules = vape.Modules
                                    local flyEnabled = vapeModules.Fly
                                    local infFlyEnabled = vapeModules.InfiniteFly
                                    local longJumpEnabled = vapeModules.LongJump
                                    
                                    local yMask = vector3new(1, 0, 1)
                                    local yOnly = vector3new(0, 1, 0)
                                    
                                    connection = runService.PreSimulation:Connect(function()
                                        frameCounter = frameCounter + 1
                                        
                                        if frameCounter % 5 == 0 then
                                            if flyEnabled.Enabled or infFlyEnabled.Enabled or longJumpEnabled.Enabled then
                                                connection:Disconnect()
                                                AntiFallDirection = nil
                                                return
                                            end
                                        end

                                        if entitylib.isAlive and lplr:GetAttribute('LastTeleported') == lastTeleport then
                                            local root = entitylib.character.RootPart
                                            local rootPos = root.Position
                                            local delta = (top - rootPos) * yMask
                                            
                                            AntiFallDirection = delta.Unit == delta.Unit and delta.Unit or vector3zero
                                            root.Velocity *= yMask
                                            
                                            if frameCounter % 3 == 0 then
                                                rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
                                                rayCheck.CollisionGroup = root.CollisionGroup

                                                local ray = workspace:Raycast(rootPos, AntiFallDirection, rayCheck)
                                                if ray then
                                                    for i = 1, 5 do
                                                        local dpos = roundPos(ray.Position + ray.Normal * 1.5) + vector3new(0, 3, 0)
                                                        if not getPlacedBlock(dpos) then
                                                            top = vector3new(top.X, pos.Y, top.Z)
                                                            break
                                                        end
                                                    end
                                                end
                                            end

                                            local yDiff = top.Y - rootPos.Y
                                            root.CFrame += vector3new(0, yDiff, 0)
                                            
                                            if not frictionTable.Speed then
                                                local speed = getSpeed()
                                                local newVelocity = (AntiFallDirection * speed) + vector3new(0, root.AssemblyLinearVelocity.Y, 0)
                                                root.AssemblyLinearVelocity = newVelocity
                                            end

                                            if delta.Magnitude < 1 then
                                                connection:Disconnect()
                                                AntiFallDirection = nil
                                            end
                                        else
                                            connection:Disconnect()
                                            AntiFallDirection = nil
                                        end
                                    end)
                                    AntiFall:Clean(connection)
                                end
                            elseif Mode.Value == 'Velocity' then
                                local rootVel = entitylib.character.RootPart.Velocity
                                entitylib.character.RootPart.Velocity = vector3new(rootVel.X, 100, rootVel.Z)
                            end
                        end
                    end))
                end
            else
                AntiFallDirection = nil
                cachedLowGround = math_huge
                lastGroundScan = 0
            end
        end,
        Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
    })
    
    Mode = AntiFall:CreateDropdown({
        Name = 'Move Mode',
        List = {'Normal', 'Collide', 'Velocity'},
        Function = function(val)
            if AntiFallPart then
                AntiFallPart.CanCollide = val == 'Collide'
            end
        end,
        Tooltip = 'Normal - Smoothly moves you towards the nearest safe point\nVelocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
    })
    
    local materials = {'ForceField'}
    for _, v in Enum.Material:GetEnumItems() do
        if v.Name ~= 'ForceField' then
            table.insert(materials, v.Name)
        end
    end
    
    Material = AntiFall:CreateDropdown({
        Name = 'Material',
        List = materials,
        Function = function(val)
            if AntiFallPart then
                AntiFallPart.Material = Enum.Material[val]
            end
        end
    })
    
    Color = AntiFall:CreateColorSlider({
        Name = 'Color',
        DefaultOpacity = 0.5,
        Function = function(h, s, v, o)
            if AntiFallPart then
                AntiFallPart.Color = Color3.fromHSV(h, s, v)
                AntiFallPart.Transparency = 1 - o
            end
        end
    })
end)
run(function()
    local DronePhase
    local modified = {}

    DronePhase = vape.Categories.Kits:CreateModule({
        Name = 'DronePhase',
        Function = function(callback)
            if callback then
                local lastDroneScan = 0
                DronePhase:Clean(runService.Stepped:Connect(function()
                    local now = os.clock()
                    if now - lastDroneScan < 0.25 then return end
                    lastDroneScan = now
                    local myDrone
                    for _, drone in collectionService:GetTagged('Drone') do
                        if drone:GetAttribute('PlayerUserId') == lplr.UserId then
                            myDrone = drone
                            break
                        end
                    end

                    for part, was in modified do
                        if not part.Parent or not myDrone or not part:IsDescendantOf(myDrone) then
                            modified[part] = nil
                            if part.Parent then
                                part.CanCollide = was
                            end
                        end
                    end

                    if myDrone then
                        for _, part in myDrone:GetDescendants() do
                            if part:IsA('BasePart') and part.CanCollide then
                                modified[part] = part.CanCollide
                                part.CanCollide = false
                            end
                        end
                    end
                end))
            else
                for part, was in modified do
                    if part.Parent then
                        part.CanCollide = was
                    end
                end
                table.clear(modified)

                for _, drone in collectionService:GetTagged('Drone') do
                    if drone:GetAttribute('PlayerUserId') == lplr.UserId then
                        for _, part in drone:GetDescendants() do
                            if part:IsA('BasePart') and not part.CanCollide then
                                part.CanCollide = true
                            end
                        end
                    end
                end
            end
        end,
        Tooltip = 'turns off collision for your drone - allowing you to phase through walls :D',
    })
end)
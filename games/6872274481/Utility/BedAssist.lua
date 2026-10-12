run(function()
    local BedAssist = {Enabled = false}
    local bedassistrange = {Value = 30}
    local bedassistsmoothness = {Value = 6}
    local bedassistangle = {Value = 70}
    local bedassistfirstperson = {Enabled = false}
    local bedassistshopcheck = {Enabled = false}
	local bedassisthandcheck = {Enabled = false}
	local bedassistlowestblock = {Enabled = false}
	
	local function getBedAimSpeed(speedVal, dt)
		local baseSpeed = 0.01
		local multiplier = 1.35
		local speed = baseSpeed * (multiplier ^ speedVal)
		return math.min(speed, 0.95) * (dt * 60)
	end

	local function checkHand()
		return isHoldingPickaxe() or isHoldingItem({'axe'})
	end

    local camera = gameCamera
    local beds = {}
    local Connections = {}

    local function isFirstPerson()
        if not (lplr.Character and lplr.Character:FindFirstChild("Head")) then return false end
        return (lplr.Character.Head.Position - camera.CFrame.Position).Magnitude < 2
    end

    local function getClosestEnemyBed(playerPos)
        local closestBed = nil
        local closestDistance = bedassistrange.Value
        local lowestY = math.huge

        for _, bed in pairs(beds) do
            if not bed.Parent then continue end

            if tostring(bed:GetAttribute("TeamId")) == tostring(lplr:GetAttribute("Team")) then
                continue
            end

            if bed:GetAttribute("BedShieldEndTime") and bed:GetAttribute("BedShieldEndTime") > workspace:GetServerTimeNow() then
                continue
            end

            local distance = (playerPos - bed.Position).Magnitude
            if distance > bedassistrange.Value then continue end

            local delta = (bed.Position - playerPos)
            local char = lplr.Character
            local localfacing = Vector3.new(1, 0, 0)
            if char and char:FindFirstChild("HumanoidRootPart") then
                localfacing = char.HumanoidRootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
                if localfacing.Magnitude < 0.001 then
                    localfacing = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
                end
                localfacing = localfacing.Unit
            else
                localfacing = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
                if localfacing.Magnitude > 0.001 then
                    localfacing = localfacing.Unit
                else
                    localfacing = Vector3.new(1, 0, 0)
                end
            end

            local flatDelta = delta * Vector3.new(1, 0, 1)
            local angle = math.huge
            if flatDelta.Magnitude > 0.1 then
                angle = math.acos(math.clamp(localfacing:Dot(flatDelta.Unit), -1, 1))
            else
                angle = 0
            end

            if angle <= math.rad(bedassistangle.Value) then
                if bedassistlowestblock.Enabled then
                    if bed.Position.Y < lowestY then
                        lowestY = bed.Position.Y
                        closestBed = bed
                    end
                else
                    if distance < closestDistance then
                        closestDistance = distance
                        closestBed = bed
                    end
                end
            end
        end

        return closestBed
    end

    BedAssist = vape.Categories.Utility:CreateModule({
        Name = "BedAssist",
        Function = function(callback)
            if callback then
                table.clear(beds)
                for _, bed in ipairs(collectionService:GetTagged("bed")) do
                    table.insert(beds, bed)
                end

                table.insert(Connections, collectionService:GetInstanceAddedSignal("bed"):Connect(function(bed)
                    table.insert(beds, bed)
                end))

                table.insert(Connections, collectionService:GetInstanceRemovedSignal("bed"):Connect(function(bed)
                    local i = table.find(beds, bed)
                    if i then
                        table.remove(beds, i)
                    end
                end))

                local heartbeatConn
                heartbeatConn = runService.Heartbeat:Connect(function(dt)
                    if not BedAssist.Enabled then
                        heartbeatConn:Disconnect()
                        camera.CameraType = Enum.CameraType.Custom
                        return
                    end
                    if not lplr.Character or not lplr.Character:FindFirstChild("HumanoidRootPart") then
                        return
                    end
					if bedassisthandcheck.Enabled and not checkHand() then 
						return
					end
                    if bedassistfirstperson.Enabled and not isFirstPerson() then
                        return
                    end
                    if bedassistshopcheck.Enabled then
                        local isShop = lplr:FindFirstChild("PlayerGui") and lplr.PlayerGui:FindFirstChild("ItemShop")
                        if isShop then return end
                    end

                    if #beds == 0 then return end

                    local playerPos = lplr.Character.HumanoidRootPart.Position
                    local closestBed = getClosestEnemyBed(playerPos)

                    if closestBed then
                        local bedPos = closestBed.Position
                        local currentCFrame = camera.CFrame
                        local targetCFrame = CFrame.lookAt(currentCFrame.Position, bedPos)
                        local lerpAmount = bedassistsmoothness.Value / 15
                        camera.CFrame = currentCFrame:Lerp(targetCFrame, math.min(getBedAimSpeed(bedassistsmoothness.Value, dt), 0.95))
                    end
                end)
                table.insert(Connections, heartbeatConn)
            else
                for _, v in pairs(Connections) do
                    pcall(function()
                        v:Disconnect()
                    end)
                end
                Connections = {}
                table.clear(beds)
                camera.CameraType = Enum.CameraType.Custom
            end
        end,
        Tooltip = "aa for beds lol"
    })

    bedassistrange = BedAssist:CreateSlider({
        Name = "Assist Range",
        Min = 10,
        Max = 100,
        Function = function(val) end,
        Default = 30,
        Suffix = function(val) 
            return val == 1 and "stud" or "studs" 
        end
    })

    bedassistsmoothness = BedAssist:CreateSlider({
        Name = "Aim Speed",
        Min = 1,
        Max = 20,
        Function = function(val) end,
        Default = 6
    })

    bedassistangle = BedAssist:CreateSlider({
        Name = "Max Angle",
        Min = 10,
        Max = 360,
        Function = function(val) end,
        Default = 70
    })

    bedassistfirstperson = BedAssist:CreateToggle({
        Name = "First Person Only",
        Function = function() end,
        Default = false,
    })

    bedassistshopcheck = BedAssist:CreateToggle({
        Name = "Shop Check",
        Function = function() end,
        Default = false,
    })

	bedassisthandcheck = BedAssist:CreateToggle({
		Name = "Hand Check",
		Function = function() end,
		Default = true,
	})

	bedassistlowestblock = BedAssist:CreateToggle({
		Name = "Target Lowest Block",
		Function = function() end,
		Default = false,
	})
end)
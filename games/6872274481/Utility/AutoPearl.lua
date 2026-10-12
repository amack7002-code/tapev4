run(function()
    local AutoPearl
    local Limit
    
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    rayCheck.FilterType = Enum.RaycastFilterType.Include
    local groundCheck = RaycastParams.new()
    groundCheck.RespectCanCollide = true
    groundCheck.FilterType = Enum.RaycastFilterType.Include
    local projectileRemote = {InvokeServer = function(self, ...) end}
    task.spawn(function()
    	projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
    end)
    
    local function firePearl(pos, spot, item)
    	for _, v in store.selfProjectiles or {} do
    		if v.Name == 'telepearl' then
    			return
    		end
    	end

    	local originalSlot = store.inventory.hotbarSlot
    	local pearlSlot = getHotbar(item.tool)
    	if not pearlSlot then
    		switchItem(item.tool)
    	else
    		if hotbarSwitch(pearlSlot) then
    			task.wait(0.05)
    		end
    	end
    
    	local meta = bedwars.ProjectileMeta.telepearl
    	local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
    
    	if calc then
    		local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
    		local projectile = bedwars.ProjectileController:createLocalProjectile(meta, 'telepearl', 'telepearl', pos, nil, dir, {drawDurationSeconds = 1})
    		local res = projectileRemote:InvokeServer(
    			item.tool,
    			'telepearl',
    			'telepearl',
    			pos,
    			pos,
    			dir,
    			httpService:GenerateGUID(true),
    			{ 
                    drawDurationSeconds = 1, 
                    shotId = httpService:GenerateGUID(false) 
                },
    			workspace:GetServerTimeNow() - 0.045
    		)
    		if res then
    			pcall(function()
    				res.Parent = replicatedStorage
    			end)
    		end
    	end
    
    	if pearlSlot then
    		task.wait(0.05)
    		local swordSlot
    		for i, hv in store.inventory.hotbar do
    			if hv and hv.item and hv.item.itemType then
    				local hm = bedwars.ItemMeta[hv.item.itemType]
    				if hm and hm.sword then
    					swordSlot = i - 1
    					break
    				end
    			end
    		end
    		hotbarSwitch(swordSlot or originalSlot)
    	end
    end
    
    local function findNearGround(origin)
    	for _, v in {Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1)} do
    		for i = 1, 24 do
    			local ray = workspace:Raycast((origin.Position + (Vector3.yAxis * 3)) + (v * i), Vector3.new(0, -60, 0), groundCheck)
    			if ray then
    				return ray.Position + Vector3.new(0, 2, 0)
    			end
    		end
    	end
    	return nil
    end
    
    AutoPearl = vape.Categories.Utility:CreateModule({
    	Name = 'AutoPearl',
    	Function = function(callback)
    		if callback then
    			local check, lasty
    			repeat
    				if entitylib.isAlive and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'telepearl') then
    					local root = entitylib.character.RootPart
    					local pearl = getItem('telepearl')
    					local mapFolder = workspace:FindFirstChild('Map') or workspace
    					rayCheck.FilterDescendantsInstances = {mapFolder}
    					rayCheck.CollisionGroup = root.CollisionGroup
    					groundCheck.FilterDescendantsInstances = {mapFolder}
    					groundCheck.CollisionGroup = 'Default'
    
    					if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
    						lasty = root.CFrame
    					end
    
    					if pearl and root.Velocity.Y < -100 and not workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayCheck) then
    						if not check then
    							check = true
    							local ground = findNearGround(root.CFrame + Vector3.new(0, 40, 0)) or findNearGround(lasty and lasty + Vector3.new(0, 5, 0) or root.CFrame)
    							if ground then
    								firePearl(root.Position, ground, pearl)
    							end
    						end
    					else
    						check = false
    					end
    				end
    				task.wait(0.1)
    			until not AutoPearl.Enabled
    		end
    	end,
    	Tooltip = 'auto throws yo pearl when falling in the void'
    })
    
    Limit = AutoPearl:CreateToggle({
    	Name = 'Limit to pearl',
    	Tooltip = 'only throws when ur already holding a pearl'
    })
end)
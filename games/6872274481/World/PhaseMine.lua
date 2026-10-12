run(function()
	local PhaseMine
	local connections = {}
	local trackedParts = {}
	local lastWeaponState = nil
	local weaponCheckCounter = 0
	
	local function removeCollision(character)
		if not character then return end
		
		local charParts = trackedParts[character]
		if not charParts then
			charParts = {}
			trackedParts[character] = charParts
			
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					table.insert(charParts, {part = part, origCollide = part.CanCollide, origQuery = part.CanQuery})
					part.CanCollide = false
					part.CanQuery = false
				end
			end
		else
			for _, entry in charParts do
				if entry.part and entry.part.Parent then
					entry.part.CanCollide = false
					entry.part.CanQuery = false
				end
			end
		end
	end
	
	local function restoreCollision(character)
		if not character then return end
		
		local charParts = trackedParts[character]
		if charParts then
			for _, entry in charParts do
				if entry.part and entry.part.Parent then
					entry.part.CanCollide = entry.origCollide
					entry.part.CanQuery = entry.origQuery
				end
			end
		end
	end

	local function updateAllCollisions(forceUpdate)
		weaponCheckCounter = weaponCheckCounter + 1
		local shouldCheck = forceUpdate or (weaponCheckCounter % 3 == 0)
		
		if not shouldCheck then return end
		
		local isWeaponEquipped = hasValidWeapon()
		
		if not forceUpdate and lastWeaponState == isWeaponEquipped then
			return
		end
		
		lastWeaponState = isWeaponEquipped
		
		for _, entity in entitylib.List do
			if entity.Character and entity.Character.Parent then
				if isWeaponEquipped then
					restoreCollision(entity.Character)
				else
					removeCollision(entity.Character)
				end
			end
		end
	end
	
	local motorParts = {}
	local function updateMotorParts()
		for _, entity in entitylib.List do
			if entity.Character then
				local charMotors = motorParts[entity.Character]
				
				if not charMotors then
					charMotors = {}
					motorParts[entity.Character] = charMotors
					
					for _, part in entity.Character:GetChildren() do
						if part:IsA("BasePart") and part.Name == "Part" and part:FindFirstChildOfClass("Motor6D") then
							table.insert(charMotors, part)
						end
					end
				end
				
				for _, part in charMotors do
					if part and part.Parent then
						part.CanCollide = false
					end
				end
			end
		end
	end
	
	local tracked = {}
	local descConnections = {}

	PhaseMine = vape.Categories.World:CreateModule({
		Name = 'PhaseMine',
		Function = function(callback)
			if callback then

				local function ignorePart(part)
					pcall(function()
						bedwars.QueryUtil:setQueryIgnored(part, true)
					end)
				end

				local function onPartAdded(char, part)
					if not PhaseMine.Enabled or not char or char == lplr.Character then return end
					if not part:IsA('BasePart') then return end
					local list = tracked[char]
					if not list then
						list = {}
						tracked[char] = list
					end
					if not list[part] then
						list[part] = true
						ignorePart(part)
					end
				end

				local function applyToChar(char)
					if not char or char == lplr.Character then return end
					for _, part in char:GetDescendants() do
						onPartAdded(char, part)
					end
				end

				local function setupCharacter(char)
					if not char then return end
					if char == lplr.Character then return end
					if descConnections[char] then
						descConnections[char]:Disconnect()
						descConnections[char] = nil
					end
					applyToChar(char)
					local conn = char.DescendantAdded:Connect(function(part)
						onPartAdded(char, part)
					end)
					descConnections[char] = conn
				end

				local function cleanupCharacter(char)
					if descConnections[char] then
						descConnections[char]:Disconnect()
						descConnections[char] = nil
					end
					tracked[char] = nil
				end

				local function applyToAll(remove)
					for _, entity in ipairs(entitylib.List) do
						if entity.Character then
							applyToChar(entity.Character, remove)
						end
					end
					for _, obj in ipairs(workspace:GetChildren()) do
						if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
							if obj ~= lplr.Character then
								applyToChar(obj, remove)
							end
						end
					end
				end

				local function updateCollision()
					if not PhaseMine.Enabled then return end
					applyToAll()
				end

				local function setupAllCharacters()
					for _, entity in ipairs(entitylib.List) do
						if entity.Character then
							setupCharacter(entity.Character)
						end
					end
					for _, obj in ipairs(workspace:GetChildren()) do
						if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
							if obj ~= lplr.Character then
								setupCharacter(obj)
							end
						end
					end
				end

				task.wait(0.2)
				setupAllCharacters()
				updateCollision()

				local entityAdded = entitylib.Events.EntityAdded:Connect(function(entity)
					if entity.Character then
						task.wait(0.1)
						setupCharacter(entity.Character)
					end
				end)
				table.insert(connections, entityAdded)

				local workspaceChildAdded = workspace.ChildAdded:Connect(function(obj)
					if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
						if obj ~= lplr.Character then
							task.wait(0.1)
							setupCharacter(obj)
						end
					end
				end)
				table.insert(connections, workspaceChildAdded)

				local entityRemoved = entitylib.Events.EntityRemoved:Connect(function(entity)
					if entity.Character then
						cleanupCharacter(entity.Character)
					end
				end)
				table.insert(connections, entityRemoved)

				local workspaceChildRemoved = workspace.ChildRemoved:Connect(function(obj)
					if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
						if obj ~= lplr.Character then
							cleanupCharacter(obj)
						end
					end
				end)
				table.insert(connections, workspaceChildRemoved)

				local localAdded = lplr.CharacterAdded:Connect(function(char)
					if PhaseMine.Enabled then
						if lplr.Character and lplr.Character ~= char then
							cleanupCharacter(lplr.Character)
						end
						task.wait(0.2)
						updateCollision()
						setupAllCharacters()
					end
				end)
				table.insert(connections, localAdded)

			else
				for _, conn in ipairs(connections) do
					conn:Disconnect()
				end
				table.clear(connections)

				for char, conn in pairs(descConnections) do
					conn:Disconnect()
				end
				table.clear(descConnections)

				for char, list in pairs(tracked) do
					for part in pairs(list) do
						if part.Parent then
							pcall(function()
								bedwars.QueryUtil:setQueryIgnored(part, false)
							end)
						end
					end
				end
				table.clear(tracked)
			end
		end,
		Tooltip = 'mine OR build through players and npcs'
	})
end)
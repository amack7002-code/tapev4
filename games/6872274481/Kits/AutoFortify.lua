run(function()
	local AutoFortify
	local LayerSlider
	local fortified = {}
	local fortifyRemote

	local function getRemote()
		if not fortifyRemote then
			fortifyRemote = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('FortifyBlock')
		end
		return fortifyRemote
	end

	local function getPyramid(size, grid)
		local positions = {}
		for h = size, 0, -1 do
			for w = h, 0, -1 do
				table.insert(positions, Vector3.new(w, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w, (size - h), (h - w) * -1) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), (h - w) * -1) * grid)
			end
		end
		return positions
	end

	local function getMyBedCFrame()
		local myTeam = lplr:GetAttribute('Team')
		if not myTeam then return nil end
		for _, bed in collectionService:GetTagged('bed') do
			if bed and bed.Parent and bed:GetAttribute('Team'..myTeam..'NoBreak') then
				return bed:IsA('BasePart') and bed.CFrame or (bed.PrimaryPart and bed.PrimaryPart.CFrame or bed:GetPivot())
			end
		end
		return nil
	end

	local function fortifyPass(bedCFrame)
		if not LayerSlider then return end
		local remote = getRemote()
		if not remote then return end
		for layer = 0, LayerSlider.Value - 1 do
			local positions = getPyramid(layer + 1, 3)
			local pending = false
			for _, pos in positions do
				if not AutoFortify.Enabled then return end
				local worldPos = (bedCFrame * CFrame.new(pos)).Position
				local block, roundedPos = getPlacedBlock(worldPos)
				if block and block.Name ~= 'bed' then
					local key = tostring(roundedPos)
					if fortified[key] ~= block then
						pcall(function() remote:FireServer(roundedPos) end)
						fortified[key] = block
						pending = true
						task.wait(0.05)
					end
				end
			end
			if pending then return end
		end
	end

	AutoFortify = vape.Categories.Kits:CreateModule({
		Name = 'AutoFortify',
		Function = function(callback)
			if not callback then
				table.clear(fortified)
				return
			end
			task.spawn(function()
				table.clear(fortified)
				repeat
					pcall(function()
						local bedCFrame = getMyBedCFrame()
						if bedCFrame then
							fortifyPass(bedCFrame)
						end
					end)
					task.wait(0.1)
				until not AutoFortify or not AutoFortify.Enabled
			end)
		end,
		Tooltip = 'auto fortifies the blocks stacked on ur bed from anywhere'
	})

	LayerSlider = AutoFortify:CreateSlider({
		Name = 'Layers',
		Min = 1,
		Max = 10,
		Default = 3,
		Suffix = ' layers',
		Tooltip = 'how tall the pyramid it checks goes. more layers covers more of ur stack but ts takes a lil longer'
	})
end)
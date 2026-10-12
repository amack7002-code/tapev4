run(function()
	local NametagSpoof
	local SpoofRankDropdown
	local lplr = game.Players.LocalPlayer
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CollectionService = game:GetService("CollectionService")
	local BedwarsImageId = require(ReplicatedStorage.TS.image["image-id"]).BedwarsImageId
	local RANK_MAP = {
		Bronze = "BRONZE_RANK",
		Silver = "SILVER_RANK",
		Gold = "GOLD_RANK",
		Platinum = "PLATINUM_RANK",
		Diamond = "DIAMOND_RANK",
		Emerald = "EMERALD_RANK",
		Nightmare = "NIGHTMARE_RANK"
	}

	local loop
	local generation = 0
	local originalGui, spoofGui, originalEnabled

	local function findNametag(char)
		local head = char:FindFirstChild("Head")
		if not head then return nil end

		for _, gui in ipairs(CollectionService:GetTagged("EntityNameTag")) do
			if gui.Name ~= 'NSSpoofGui' and gui:IsA("BillboardGui") and (gui.Adornee == head or gui:IsDescendantOf(char)) then
				return gui
			end
		end

		local direct = head:FindFirstChild("Nametag")
		if direct and direct:IsA("BillboardGui") then
			return direct
		end

		return nil
	end

	local function restoreNametag()
		if spoofGui then spoofGui:Destroy() end
		if originalGui and originalGui.Parent then originalGui.Enabled = originalEnabled end
		originalGui, spoofGui, originalEnabled = nil, nil, nil
	end

	local function applySpoof(char)
		local head = char:FindFirstChild("Head")
		if not head then return end

		local original = findNametag(char)
		if not original then return end
		local old = head:FindFirstChild("NSSpoofGui")
		if old then old:Destroy() end
		local clone = original:Clone()
		clone.Name = "NSSpoofGui"
		clone.Adornee = head
		clone.Parent = head

		originalGui, spoofGui, originalEnabled = original, clone, original.Enabled
		original.Enabled = false
		clone.Enabled = originalEnabled

		return clone
	end

	local function updateRank(spoof)
		if not spoof or not SpoofRankDropdown then return end
		local selectedImage = BedwarsImageId[RANK_MAP[SpoofRankDropdown.Value]]
		if not selectedImage or selectedImage == '' then return end

		for _, d in ipairs(spoof:GetDescendants()) do
			if d:IsA("ImageLabel") then
				for _, rankKey in pairs(RANK_MAP) do
					if BedwarsImageId[rankKey] and d.Image == BedwarsImageId[rankKey] then
						d.Image = selectedImage
						break
					end
				end
			end
		end
	end

	local function startLoop()
		generation += 1
		local currentGeneration = generation
		loop = task.spawn(function()
			local activeCharacter
			while NametagSpoof.Enabled and generation == currentGeneration do
				local char = lplr.Character
				if char ~= activeCharacter or not (originalGui and originalGui.Parent and spoofGui and spoofGui.Parent) then
					restoreNametag()
					activeCharacter = char
					if char and char.Parent then applySpoof(char) end
				end
				if spoofGui then updateRank(spoofGui) end
				task.wait(0.1)
			end
		end)
	end

	local function cleanup()
		generation += 1
		if loop then
			task.cancel(loop)
			loop = nil
		end
		restoreNametag()
	end

	NametagSpoof = vape.Categories.Render:CreateModule({
		Name = "NametagSpoof",
		Function = function(callback)
			if callback then
				cleanup()
				startLoop()
			else
				cleanup()
			end
		end
	})

	SpoofRankDropdown = NametagSpoof:CreateDropdown({
		Name = "Rank",
		List = {"Bronze","Silver","Gold","Platinum","Diamond","Emerald","Nightmare"},
		Default = "Nightmare",
		Function = function()
			if NametagSpoof.Enabled and spoofGui then updateRank(spoofGui) end
		end
	})
end)
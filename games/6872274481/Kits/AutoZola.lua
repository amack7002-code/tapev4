run(function()
	local AutoZola
	local Range
	local Delay
	local soulLinkRemote
	local useAbilityRemote

	local function getRemotes()
		if not soulLinkRemote then
			pcall(function()
				soulLinkRemote = replicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("AttemptSoulLink")
			end)
		end
		if not useAbilityRemote then
			pcall(function()
				useAbilityRemote = replicatedStorage:WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events"):WaitForChild("useAbility")
			end)
		end
	end

	local function startLoop()
		task.spawn(function()
			repeat task.wait() until Range and Delay
			getRemotes()
			local linkedTargets = {}
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end
				local plr = entitylib.EntityPosition({
					Range = Range.Value,
					Part = "RootPart",
					Players = true,
					NPCs = true,
					Wallcheck = false
				})
				local linkCount = 0
				for _ in linkedTargets do linkCount += 1 end
				if plr and plr.Character and linkCount < 8 and soulLinkRemote then
					local char = plr.Character
					if not linkedTargets[char] then
						if useAbilityRemote then
							pcall(function() useAbilityRemote:FireServer("soul_link") end)
						end
						task.wait(0.1)
						local ok, result = pcall(function()
							return soulLinkRemote:InvokeServer(char)
						end)
						if ok and result and result.result then
							linkedTargets[char] = true
							char.AncestryChanged:Connect(function()
								if not char.Parent then
									linkedTargets[char] = nil
								end
							end)
						end
					end
				end
				task.wait(Delay.Value)
			until not AutoZola.Enabled
			linkedTargets = {}
		end)
	end

	AutoZola = vape.Categories.Kits:CreateModule({
		Name = 'AutoZola',
		Function = function(callback)
			if callback then startLoop() end
		end,
		Tooltip = 'auto soul links enemies for zola'
	})

	Range = AutoZola:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 50
	})
	Delay = AutoZola:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.3,
		Decimal = 10,
		Suffix = 's'
	})
end)
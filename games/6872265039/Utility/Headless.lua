run(function()
	local Headless
	local headlessLoop = nil

	local headAttachments = {HatAttachment=true,HairAttachment=true,FaceFrontAttachment=true,FaceCenterAttachment=true,FaceBackAttachment=true}
	local removeAccs = false
	local bodyTransparency = 0
	local bodyTransparencyEnabled = false
	local originalBody = setmetatable({}, {__mode = 'k'})

	local function restoreBody()
		for part, transparency in originalBody do
			if part.Parent then part.Transparency = transparency end
		end
		table.clear(originalBody)
	end

	local function applyHeadless(char)
		if not char then return end
		if bodyTransparencyEnabled then
			for _, part in char:GetChildren() do
				if part:IsA('BasePart') and part.Name ~= 'Head' and part.Name ~= 'HumanoidRootPart' then
					if originalBody[part] == nil then originalBody[part] = part.Transparency end
					part.Transparency = math.max(originalBody[part], bodyTransparency)
				end
			end
		end
		local head = char:FindFirstChild("Head")
		if not head then return end
		head.Transparency = 1
		local face = head:FindFirstChild('face')
		if face and face:IsA("Decal") then
			face.Transparency = 1
		end
		if removeAccs then
			for _, acc in ipairs(char:GetChildren()) do
				if acc:IsA("Accessory") then
					local handle = acc:FindFirstChild("Handle")
					if handle then
						for _, att in ipairs(handle:GetChildren()) do
							if att:IsA("Attachment") and headAttachments[att.Name] then
								handle.Transparency = 1
								for _, d in ipairs(handle:GetChildren()) do
									if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
								end
								break
							end
						end
					end
				end
			end
		end
	end

	Headless = vape.Categories.Utility:CreateModule({
		PerformanceModeBlacklisted = true,
		Name = 'Headless',
		Tooltip = 'free headless 2026',
		Function = function(callback)
			if callback then
				if headlessLoop then task.cancel(headlessLoop) end
				headlessLoop = task.spawn(function()
					while Headless.Enabled do
						applyHeadless(lplr.Character)
						task.wait(0.1)
					end
				end)
				Headless:Clean(lplr.CharacterAdded:Connect(function(char)
					applyHeadless(char)
				end))
			else
				if headlessLoop then
					task.cancel(headlessLoop)
					headlessLoop = nil
				end
				restoreBody()
				local char = lplr.Character
				if char then
					local head = char:FindFirstChild("Head")
					if head then
						head.Transparency = 0
						local face = head:FindFirstChild('face')
						if face and face:IsA("Decal") then
							face.Transparency = 0
						end
					end
					for _, acc in ipairs(char:GetChildren()) do
						if acc:IsA("Accessory") then
							local handle = acc:FindFirstChild("Handle")
							if handle then
								handle.Transparency = 0
								for _, d in ipairs(handle:GetChildren()) do
									if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 0 end
								end
							end
						end
					end
				end
			end
		end,
		Default = false
	})

	Headless:CreateToggle({
		Name = 'Enable Body Transparency',
		Default = false,
		Tooltip = 'Apply the body transparency slider while keeping Headless enabled.',
		Function = function(state)
			bodyTransparencyEnabled = state
			if not state then restoreBody() end
			if Headless.Enabled then applyHeadless(lplr.Character) end
		end
	})

	Headless:CreateSlider({
		Name = 'Body Transparency',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%',
		Tooltip = 'Used when Enable Body Transparency is on. 0% keeps your body visible, 100% hides it locally',
		Function = function(value)
			bodyTransparency = value / 100
			if Headless.Enabled then applyHeadless(lplr.Character) end
		end
	})

	Headless:CreateToggle({
		Name = "Remove Accessories",
		Default = false,
		Function = function(state)
			removeAccs = state
			if Headless.Enabled then
				applyHeadless(lplr.Character)
			end
		end
	})
end)
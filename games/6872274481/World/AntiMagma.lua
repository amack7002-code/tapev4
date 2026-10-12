run(function()
	local AntiMagma

	AntiMagma = vape.Categories.World:CreateModule({
		Name = "AntiMagma",
		Tooltip = 'allows you not to be instantly killed by magma',
		Function = function(callback)
			if callback then
				local function disableMagmaPart(v)
					if not v:IsA("BasePart") then return end
					if not string.find(string.lower(v.Name), 'magma') then return end
					for _, stuff in v:GetDescendants() do
						if stuff:IsA("TouchTransmitter") then
							pcall(function() stuff:Destroy() end)
						end
					end
				end

				scanDescendants(workspace, disableMagmaPart, AntiMagma)

				AntiMagma:Clean(workspace.DescendantAdded:Connect(function(v)
					disableMagmaPart(v)
				end))
				local worldFolder = getWorldFolder()
				if not worldFolder then return end
				local blocks = worldFolder:WaitForChild("Blocks", 1)
				if not blocks then return end
				AntiMagma:Clean(blocks.ChildAdded:Connect(function(v)
					disableMagmaPart(v)
				end))
			end
		end
	})
end)
run(function()
	local UIS = game:GetService('UserInputService')
	local CustomCursor = {Enabled = false}
	local mouseDropdown = {Value = 'Arrow'}
	local mouseIcons = {
		['CS:GO'] = 'rbxassetid://14789879068',
		['Old Roblox Mouse'] = 'rbxassetid://13546344315',
		['dx9ware'] = 'rbxassetid://12233942144',
		['Aimbot'] = 'rbxassetid://8680062686',
		['Triangle'] = 'rbxassetid://14790304072',
		['Arrow'] = 'rbxassetid://14790316561'
	}
	local customMouseIcon = {Enabled = false}
	local customIcon = {Value = ''}
	CustomCursor = vape.Categories.Utility:CreateModule({
		Name = 'CustomCursor',
		Tooltip = 'changes your cursor\'s image.',
		Function = function(callback)
			if callback then
				local function applyIcon()
					if customMouseIcon.Enabled then
						UIS.MouseIcon = 'rbxassetid://' .. customIcon.Value
					else
						UIS.MouseIcon = mouseIcons[mouseDropdown.Value]
					end
				end
				applyIcon()
				CustomCursor:Clean(UIS:GetPropertyChangedSignal('MouseIcon'):Connect(function()
					if CustomCursor.Enabled then
						applyIcon()
					end
				end))
				local playerGui = lplr:FindFirstChildOfClass('PlayerGui')
				if playerGui then
					for _, obj in ipairs(playerGui:GetDescendants()) do
						pcall(function()
							if obj:IsA('GuiButton') and obj.MouseIcon ~= '' then
								obj.MouseIcon = ''
							end
						end)
					end
					CustomCursor:Clean(playerGui.DescendantAdded:Connect(function(obj)
						pcall(function()
							if obj:IsA('GuiButton') then
								obj.MouseIcon = ''
							end
						end)
					end))
				end
				CustomCursor:Clean(runService.Heartbeat:Connect(applyIcon))
			else
				UIS.MouseIcon = ''
				task.wait()
				UIS.MouseIcon = ''
			end
		end
	})
	mouseDropdown = CustomCursor:CreateDropdown({
		Name = 'Mouse Icon',
		List = {
			'CS:GO',
			'Old Roblox Mouse',
			'dx9ware',
			'Aimbot',
			'Triangle',
			'Arrow'
		},
		Function = function() end
	})
	customMouseIcon = CustomCursor:CreateToggle({
		Name = 'Custom Icon',
		Function = function(callback) end
	})
	customIcon = CustomCursor:CreateTextBox({
		Name = 'Custom Mouse Icon',
		TempText = 'Image ID (not decal)',
		FocusLost = function(enter) 
			if CustomCursor.Enabled then 
				CustomCursor:Toggle(false)
				CustomCursor:Toggle(false)
			end
		end
	})
end)
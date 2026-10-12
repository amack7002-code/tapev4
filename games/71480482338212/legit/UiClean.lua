run(function()
	local UICleanup
	local groups = {
		Popups = {'KitPopupsGui', 'AnnouncementGui', 'NotificationGui', 'AchievementGui', 'OfflineRewardsGui', 'GiftedKitGui', 'GroupVerificationGui', 'UpdateLogGui'},
		['Purchase effects'] = {'PurchaseEffectGui', 'PurchasingEffectGui2'},
		['Damage flash'] = {'DamageScreenEffectGui'},
		['Shift lock icon'] = {'ShiftlockDisplayGui'}
	}
	local toggles = {}
	local TopBar
	local saved = {}

	local function hide(obj, prop)
		if obj[prop] then
			saved[obj] = saved[obj] or prop
			obj[prop] = false
		end
	end

	local function restore(filter)
		for obj, prop in saved do
			if not filter or filter(obj) then
				saved[obj] = nil
				pcall(function()
					obj[prop] = true
				end)
			end
		end
	end

	UICleanup = vape.Categories.Legit:CreateModule({
		Name = 'UICleanup',
		Function = function(callback)
			if callback then
				repeat
					local gui = lplr:FindFirstChildOfClass('PlayerGui')
					if gui then
						for group, names in groups do
							if toggles[group].Enabled then
								for _, name in names do
									local screen = gui:FindFirstChild(name)
									if screen and screen:IsA('ScreenGui') then
										hide(screen, 'Enabled')
									end
								end
							end
						end
						if TopBar.Enabled then
							local list = gui:FindFirstChild('TopbarButtonsGui') and gui.TopbarButtonsGui:FindFirstChild('ButtonsList')
							for _, name in {'UpdateLog', 'Codes'} do
								local button = list and list:FindFirstChild(name)
								if button and button:IsA('GuiObject') then
									hide(button, 'Visible')
								end
							end
						end
					end
					task.wait(0.25)
				until not UICleanup.Enabled
			else
				restore()
			end
		end,
		Tooltip = 'Keeps the game\'s popups and extra buttons off your screen'
	})
	for group in groups do
		toggles[group] = UICleanup:CreateToggle({
			Name = group,
			Default = true,
			Function = function(callback)
				if not callback then
					restore(function(obj)
						return table.find(groups[group], obj.Name) ~= nil
					end)
				end
			end
		})
	end
	TopBar = UICleanup:CreateToggle({
		Name = 'Top bar buttons',
		Default = true,
		Function = function(callback)
			if not callback then
				restore(function(obj)
					return obj.Name == 'UpdateLog' or obj.Name == 'Codes'
				end)
			end
		end,
		Tooltip = 'The update log and codes buttons'
	})
end)

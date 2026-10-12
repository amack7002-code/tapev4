run(function()
	local AutoWhim
	local Range
	local collectionActive = false

	local function startLoop()
		if collectionActive then return end
		collectionActive = true
		task.spawn(function()
			repeat task.wait() until Range
			while AutoWhim.Enabled and collectionActive do
				if not entitylib.isAlive then
					task.wait(0.5)
					continue
				end
				local localPosition = entitylib.character.RootPart.Position
				local range = Range.Value
				for _, obj in collectionService:GetTagged('ElementTome') do
					if not AutoWhim.Enabled or not collectionActive then break end
					local part = not obj:IsA('Model') and obj or obj.PrimaryPart
					if part and (localPosition - part.Position).Magnitude <= range then
						local secret = obj:GetAttribute('TomeSecret')
						if secret then
							pcall(function()
								bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.PUNCH)
							end)
							pcall(function()
								bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
							end)
							local ok, result = pcall(function()
								return bedwars.Client:Get(remotes.LearnElementTome).instance:InvokeServer({ secret = secret })
							end)
							if ok and result and result.success then
								pcall(function() obj:Destroy() end)
								task.wait(0.5)
							end
						end
					end
				end
				task.wait(0.1)
			end
			collectionActive = false
		end)
	end

	AutoWhim = vape.Categories.Kits:CreateModule({
		Name = 'AutoWhim',
		Function = function(callback)
			if callback then
				startLoop()
			else
				collectionActive = false
			end
		end,
		Tooltip = 'auto learns the element tomes for u'
	})

	Range = AutoWhim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 18
	})
end)
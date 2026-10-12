run(function()
	local AutoGrimReaper
	local Range
	local Delay
	local collectionActive = false

	local function startLoop()
		if collectionActive then return end
		collectionActive = true
		task.spawn(function()
			repeat task.wait() until Range and Delay
			while AutoGrimReaper.Enabled and collectionActive do
				if not entitylib.isAlive then
					task.wait(0.5)
					continue
				end
				local controller = bedwars.GrimReaperController
				if not controller or not controller.soulsByPosition then
					task.wait(0.2)
					continue
				end
				local localPosition = entitylib.character.RootPart.Position
				local range = Range.Value
				local char = lplr.Character
				local health = char and char:GetAttribute('Health')
				local maxHealth = char and char:GetAttribute('MaxHealth')
				local lowHealth = health and maxHealth and health <= (maxHealth / 4) and not char:GetAttribute('GrimReaperChannel')
				if lowHealth then
					for _, v in controller.soulsByPosition do
						if not AutoGrimReaper.Enabled or not collectionActive then break end
						if typeof(v) == 'Instance' then
							local part = not v:IsA('Model') and v or v.PrimaryPart
							if part and (localPosition - part.Position).Magnitude <= range then
								local secret = v:GetAttribute('GrimReaperSoulSecret')
								if secret then
									pcall(function()
										bedwars.Client:Get(remotes.ConsumeSoul):CallServer({ secret = secret })
									end)
									if Delay.Value > 0 then
										task.wait(Delay.Value)
									end
								end
							end
						end
					end
				end
				task.wait(0.1)
			end
			collectionActive = false
		end)
	end

	AutoGrimReaper = vape.Categories.Kits:CreateModule({
		Name = 'AutoGrimReaper',
		Function = function(callback)
			if callback then
				startLoop()
			else
				collectionActive = false
			end
		end,
		Tooltip = 'auto eats souls when ur hp is low'
	})
	Range = AutoGrimReaper:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 150,
		Default = 120
	})
	Delay = AutoGrimReaper:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100,
		Suffix = 's'
	})
end)
run(function()
	local AutoEvelynn
	local Range
	local Delay
	local collectionActive = false

	local function startLoop()
		if collectionActive then return end
		collectionActive = true
		task.spawn(function()
			repeat task.wait() until Range and Delay
			while AutoEvelynn.Enabled and collectionActive do
				if not entitylib.isAlive then
					task.wait(0.5)
					continue
				end
				local localPosition = entitylib.character.RootPart.Position
				local range = Range.Value
				for _, obj in collectionService:GetTagged('EvelynnSoul') do
					if not AutoEvelynn.Enabled or not collectionActive then break end
					local part = not obj:IsA('Model') and obj or obj.PrimaryPart
					if part and (localPosition - part.Position).Magnitude <= range then
						pcall(function()
							bedwars.SpiritAssassinController:useSpirit(lplr, obj)
						end)
						if Delay.Value > 0 then
							task.wait(Delay.Value)
						end
					end
				end
				task.wait(0.1)
			end
			collectionActive = false
		end)
	end

	AutoEvelynn = vape.Categories.Kits:CreateModule({
		Name = 'AutoEvelynn',
		Function = function(callback)
			if callback then
				startLoop()
			else
				collectionActive = false
			end
		end,
		Tooltip = 'auto grabs the evelynn souls for u'
	})

	Range = AutoEvelynn:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 150,
		Default = 120
	})
	Delay = AutoEvelynn:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100,
		Suffix = 's'
	})
end)
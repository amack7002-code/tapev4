run(function()
	local AutoWarden
	local Targets
	local Range
	local Delay
	local collectionActive = false

	local function startLoop()
		if collectionActive then return end
		collectionActive = true
		task.spawn(function()
			repeat task.wait() until Targets and Range and Delay
			while AutoWarden.Enabled and collectionActive do
				if not entitylib.isAlive then
					task.wait(0.5)
					continue
				end
				local localPosition = entitylib.character.RootPart.Position
				local range = Range.Value
				for _, obj in collectionService:GetTagged('jailor_soul') do
					if not AutoWarden.Enabled or not collectionActive then break end
					local part = not obj:IsA('Model') and obj or obj.PrimaryPart
					if part and (localPosition - part.Position).Magnitude <= range then
						pcall(function()
							bedwars.JailorController:collectEntity(lplr, obj, 'JailorSoul')
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

	AutoWarden = vape.Categories.Kits:CreateModule({
		Name = 'AutoWarden',
		Function = function(callback)
			if callback then
				startLoop()
			else
				collectionActive = false
			end
		end,
		Tooltip = 'auto grabs the jailor souls for u'
	})

	Targets = AutoWarden:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	Range = AutoWarden:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 40,
		Default = 20
	})
	Delay = AutoWarden:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100,
		Suffix = 's'
	})
end)
run(function()
	local Reach
	local Range
	local Width
	local Place
	local PlaceRange
	local Break
	local BreakRange
	local original = {}
	local placeOld
	local mineOld = {}

	local function writable(data)
		if not table.isfrozen(data) then return true end
		if not setreadonly then return false end
		setreadonly(data, false)
		return true
	end

	local function apply(enabled)
		for name, data in bedfight.SwordsData do
			if type(data) ~= 'table' or not (data.Range and data.HitboxSize) then continue end
			if not writable(data) then continue end
			original[name] = original[name] or {data.Range, data.HitboxSize}
			local range, size = original[name][1], original[name][2]
			if enabled then
				-- the game puts its hit box one Range ahead, so half the reach each way covers all of it
				data.Range = Range.Value / 2
				data.HitboxSize = Vector3.new(math.max(size.X, Width.Value), math.max(size.Y, Width.Value), Range.Value)
			else
				data.Range, data.HitboxSize = range, size
			end
		end

		-- tools pick a new block range up the next time they are selected
		local place = bedfight.BlocksData and bedfight.BlocksData.Default
		if type(place) == 'table' and place.Range and writable(place) then
			placeOld = placeOld or place.Range
			place.Range = enabled and Place.Enabled and PlaceRange.Value or placeOld
		end
		for name, data in bedfight.MiningData do
			if type(data) == 'table' and data.Range and writable(data) then
				mineOld[name] = mineOld[name] or data.Range
				data.Range = enabled and Break.Enabled and BreakRange.Value or mineOld[name]
			end
		end
	end

	local function refresh()
		if Reach.Enabled and BreakRange then
			apply(true)
		end
	end

	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			apply(callback)
		end,
		Tooltip = 'Makes your own swings hit from further away, and lets you place and mine blocks further away.\nTools pick a new block range up the next time you select them.'
	})
	Range = Reach:CreateSlider({
		Name = 'Range',
		Min = 10.5,
		Max = 14,
		Default = 14,
		Decimal = 10,
		Suffix = 'studs',
		Function = refresh,
		Tooltip = 'How far ahead a swing looks for a player. The game\'s own is 10.5, and 14 is as far as a swing can connect.'
	})
	Width = Reach:CreateSlider({
		Name = 'Width',
		Min = 4,
		Max = 12,
		Default = 4,
		Decimal = 10,
		Suffix = 'studs',
		Function = refresh,
		Tooltip = 'How far off your crosshair a swing still lands'
	})
	Place = Reach:CreateToggle({
		Name = 'Place',
		Function = function(callback)
			if PlaceRange and PlaceRange.Object then
				PlaceRange.Object.Visible = callback
			end
			refresh()
		end,
		Tooltip = 'Lets you place blocks further away than the game\'s 18 studs'
	})
	PlaceRange = Reach:CreateSlider({
		Name = 'Place range',
		Min = 18,
		Max = 200,
		Default = 50,
		Suffix = 'studs',
		Darker = true,
		Visible = false,
		Function = refresh
	})
	Break = Reach:CreateToggle({
		Name = 'Break',
		Function = function(callback)
			if BreakRange and BreakRange.Object then
				BreakRange.Object.Visible = callback
			end
			refresh()
		end,
		Tooltip = 'Gives pickaxes and axes a longer mining range than the game\'s 18 studs'
	})
	BreakRange = Reach:CreateSlider({
		Name = 'Break range',
		Min = 18,
		Max = 200,
		Default = 50,
		Suffix = 'studs',
		Darker = true,
		Visible = false,
		Function = refresh
	})
end)

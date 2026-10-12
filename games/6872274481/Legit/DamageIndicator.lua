run(function()
	local DamageIndicator
	local FontOption
	local Color
	local Size
	local Anchor
	local Stroke

	local fn = bedwars.DamageIndicator

	local suc, tab = pcall(function()
		return debug.getupvalue(fn, 2)
	end)
	tab = suc and tab or {}

	local fontIndices = {}
	local strokeIndex
	do
		local ok, consts = pcall(debug.getconstants, fn)
		if ok and consts then
			for i, v in consts do
				if typeof(v) == 'EnumItem' and v.EnumType == Enum.Font then
					table.insert(fontIndices, i)
				elseif v == 'Thickness' or v == 'Enabled' then
					strokeIndex = i
				end
			end
		end
	end
	if #fontIndices == 0 then fontIndices = {86} end
	if not strokeIndex then strokeIndex = 119 end

	local oldvalues = {}
	local oldfonts = {}

	local function applyFont(fontName)
		local font = Enum.Font[fontName]
		if not font then return end
		for _, i in fontIndices do
			pcall(debug.setconstant, fn, i, font)
		end
	end

	local function applyStroke(on)
		pcall(debug.setconstant, fn, strokeIndex, on and 'Thickness' or 'Enabled')
		tab.strokeThickness = on and 1 or false
	end
	
	DamageIndicator = vape.Categories.Legit:CreateModule({
		Name = 'DamageIndicator',
		Function = function(callback)
			if callback then
				oldvalues = table.clone(tab)
				oldfonts = {}
				for _, i in fontIndices do
					oldfonts[i] = debug.getconstant(fn, i)
				end
				applyFont(FontOption.Value)
				applyStroke(Stroke.Enabled)
				tab.textSize = Size.Value
				tab.blowUpSize = Size.Value
				tab.blowUpDuration = 0
				tab.baseColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				tab.blowUpCompleteDuration = 0
				tab.anchoredDuration = Anchor.Value
			else
				for i, v in oldvalues do
					tab[i] = v
				end
				for i, v in oldfonts do
					pcall(debug.setconstant, fn, i, v)
				end
				pcall(debug.setconstant, fn, strokeIndex, 'Thickness')
			end
		end,
		Tooltip = 'customize the damage indicator'
	})
	local fontitems = {'GothamBlack'}
	for _, v in Enum.Font:GetEnumItems() do
		if v.Name ~= 'GothamBlack' then
			table.insert(fontitems, v.Name)
		end
	end
	FontOption = DamageIndicator:CreateDropdown({
		Name = 'Font',
		List = fontitems,
		Function = function(val)
			if DamageIndicator.Enabled then
				applyFont(val)
			end
		end
	})
	Color = DamageIndicator:CreateColorSlider({
		Name = 'Color',
		DefaultHue = 0,
		Function = function(hue, sat, val)
			if DamageIndicator.Enabled then
				tab.baseColor = Color3.fromHSV(hue, sat, val)
			end
		end
	})
	Size = DamageIndicator:CreateSlider({
		Name = 'Size',
		Min = 1,
		Max = 32,
		Default = 32,
		Function = function(val)
			if DamageIndicator.Enabled then
				tab.textSize = val
				tab.blowUpSize = val
			end
		end
	})
	Anchor = DamageIndicator:CreateSlider({
		Name = 'Anchor',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Function = function(val)
			if DamageIndicator.Enabled then
				tab.anchoredDuration = val
			end
		end
	})
	Stroke = DamageIndicator:CreateToggle({
		Name = 'Stroke',
		Function = function(callback)
			if DamageIndicator.Enabled then
				applyStroke(callback)
			end
		end
	})
end)
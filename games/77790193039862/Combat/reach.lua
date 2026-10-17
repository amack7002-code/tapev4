local Reach
local Value
local old

run(function()
Reach = vape.Categories.Combat:CreateModule({
	Name = 'Reach',
	Function = function(callback)
		local hitFunction = oldhit or arena.Client.startHit
		if callback then
			old = readUpvalue(hitFunction, 4)
			if type(old) ~= 'number' then
				old = nil
				notif('Reach', 'Reach is unavailable in this game version.', 6, 'warning')
				Reach:Toggle()
				return
			end

			local ok = pcall(debug.setupvalue, hitFunction, 4, old + Value.Value)
			if not ok then
				old = nil
				notif('Reach', 'Could not update reach in this game version.', 6, 'warning')
				Reach:Toggle()
			end
		elseif old ~= nil then
			pcall(debug.setupvalue, hitFunction, 4, old)
			old = nil
		end
	end,
	Tooltip = 'Extends attack reach'
})
Value = Reach:CreateSlider({
	Name = 'Range',
	Min = 0,
	Max = 6,
	Default = 6,
	Decimal = 10,
	Function = function(val)
		if Reach.Enabled and old ~= nil then
			pcall(debug.setupvalue, oldhit or arena.Client.startHit, 4, old + val)
		end
	end,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
end)
run(function()
	local InstantJade
	local old = nil
	
    InstantJade = vape.Categories.Kits:CreateModule({
		Name = "InstantJade",
		Tooltip = "no cooldown on the jade hammer",
		Function = function(callback)
			if callback then
				if old then return end
				old = bedwars.CooldownController.isOnCooldown
				bedwars.CooldownController.isOnCooldown = function(self, id)
					if id ~= nil and string.find(tostring(id):lower(), 'jade', 1, true) then
						return false
					end
					if type(old) ~= 'function' then return false end
					return old(self, id)
				end
			else
				if old then
					bedwars.CooldownController.isOnCooldown = old
					old = nil
				end
			end
		end
	})
end)
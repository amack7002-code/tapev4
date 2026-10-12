run(function()
	local InstantRegent
	local old = nil
	
	InstantRegent = vape.Categories.Kits:CreateModule({
		Name = "InstantRegent",
		Tooltip = "no cooldown on the void axe spam",
		Function = function(callback)
			if callback then
				if old then return end
				old = bedwars.CooldownController.isOnCooldown
				bedwars.CooldownController.isOnCooldown = function(self, id)
					if id ~= nil and string.find(tostring(id):lower(), 'void_axe', 1, true) then
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
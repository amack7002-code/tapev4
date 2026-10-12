run(function()
	local NoFall
	local oldFire = nil

	NoFall = vape.Categories.Blatant:CreateModule({
		Name = "NoFall",
		Function = function(callback)
			local success, fallDamageFunc = pcall(function()
				return bd.Blink.player_state.take_fall_damage.fire
			end)

			if not success or typeof(fallDamageFunc) ~= "function" then
				return
			end

			if callback then
				if not oldFire then
					oldFire = hookfunction(fallDamageFunc, function()
						return task.wait(9e9)
					end)
				end
			else
				if oldFire then
					hookfunction(fallDamageFunc, oldFire)
					oldFire = nil
				end
			end
		end,
		Tooltip = "Prevents taking fall damage"
	})
end)
run(function()
	local NoSlowdown
	local oldConstants = {}
	local connection

	local function getTargetFunc()
		local success, func = pcall(function()
			return debug.getproto(bd.MovementController.KnitStart, 7)
		end)
		return success and func or nil
	end

	local function applyNoSlow()
		local func = getTargetFunc()
		if not func then return end

		if not next(oldConstants) then
			oldConstants = debug.getconstants(func)
		end

		for i, v in pairs(oldConstants) do
			if type(v) == "string" and (v:find("Client") or v == "IsChargingBow") and v ~= "ClientSneaking" then
				debug.setconstant(func, i, "IsSpectating")
			end
		end
	end

	NoSlowdown = vape.Categories.Blatant:CreateModule({
		Name = "NoSlowdown",
		Function = function(callback)
			if callback then
				applyNoSlow()
				connection = task.spawn(function()
					while task.wait(1) do
						if not NoSlowdown.Enabled then break end
						applyNoSlow()
					end
				end)
			else
				if connection then
					task.cancel(connection)
					connection = nil
				end

				local func = getTargetFunc()
				if func and next(oldConstants) then
					for i, v in pairs(oldConstants) do
						debug.setconstant(func, i, v)
					end
					table.clear(oldConstants)
				end
			end
		end,
		Tooltip = "Prevents slowing down when using items"
	})
end)
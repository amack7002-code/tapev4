run(function()
	local Disabler
	local conn = nil
	local hookedFunc = nil
	local isCarrying = false

	local function findSpeedFunction()
		if not getgc then
			return nil
		end
		for _, f in getgc(true) do
			if typeof(f) == 'function' and islclosure(f) then
				local upvs = debug.getupvalues(f)
				local line = debug.info(f, 'l')
				if upvs and #upvs == 19 and line == 634 then
					return f
				end
			end
		end
		return nil
	end

	Disabler = vape.Categories.Blatant:CreateModule({
		Name = 'Disabler',
		Function = function(callback)
			if callback then
				if getgc and hookfunction and islclosure and not hookedFunc then
					local func = findSpeedFunction()
					if func then
						local target = debug.getupvalue(func, 2)
						if target then
							hookedFunc = hookfunction(target, newlclosure(function(p1, p2)
								if p2 and typeof(p2) == 'table' then
									setmetatable(p2, {})
								end
								return hookedFunc(p1, p2)
							end))
						end
					end
				end
				task.spawn(function()
					repeat
						task.wait(1)
						local carrying = false
						for _, record in EggState.ReadFieldEggs().Records do
							if record.State == 'Carried' and record.CarrierUserId == lplr.UserId then
								carrying = true
								break
							end
						end
						isCarrying = carrying
					until not Disabler.Enabled
				end)
				conn = runService.Heartbeat:Connect(function()
					local char = lplr.Character
					local hum = char and char:FindFirstChildOfClass('Humanoid')
					if hum then
						hum.WalkSpeed = isCarrying and 16 or 500
					end
				end)
			else
				if conn then
					conn:Disconnect()
					conn = nil
				end
			end
		end,
		Tooltip = 'makes u run way faster than normal gng'
	})
end)
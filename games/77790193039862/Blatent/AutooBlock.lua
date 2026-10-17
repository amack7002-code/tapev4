local AutoBlock

run(function()
	AutoBlock = vape.Categories.Blatant:CreateModule({
		Name = 'AutoBlock',
		Function = function(callback)
			if callback then
				oldhit = hookfunction(arena.Client.startHit, function(...)
					if readUpvalue(oldhit, 6) == true then
						arena.Client.endBlockEvent:FireServer()
						debug.setupvalue(oldhit, 6, false)
						local results = table.pack(oldhit(...))
						arena.Client.beginBlockEvent:FireServer()
						debug.setupvalue(oldhit, 6, true)
						return unpack(results, 1, results.n)
					end
					return oldhit(...)
				end)
			else
				if oldhit then
					hookfunction(arena.Client.startHit, oldhit)
					oldhit = nil
				end
			end
		end,
		Tooltip = 'Automatically unblock and reblock before hitting'
	})
end)
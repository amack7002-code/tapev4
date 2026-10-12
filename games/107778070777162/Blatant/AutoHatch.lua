run(function()
	local AutoHatch

	AutoHatch = vape.Categories.Blatant:CreateModule({
		Name = 'AutoHatch',
		Function = function(callback)
			if callback then
				repeat
					task.wait(1)
					local owned = EggState.ReadOwnedEggs()
					for _, row in owned do
						if row.OwnerUserId == lplr.UserId then
							for uid in pairs(row.Records) do
								if EggState.IsReadyToHatch(uid) then
									local ok = EggState.BeginHatch(uid)
									if ok then
										EggState.FinishHatch(uid)
									end
								end
							end
						end
					end
				until not AutoHatch.Enabled
			end
		end,
		Tooltip = 'auto hatches ur eggs the second theyre ready '
	})
end)
run(function()
	local ViewMatchHistory

	ViewMatchHistory = vape.Categories.Utility:CreateModule({
		Name = "ViewMatchHistory",
		Function = function(callback)
			if callback then
				ViewMatchHistory:Toggle(false)
				local d = nil
				bedwars.MatchHistoryController:requestMatchHistory(lplr.Name):andThen(function(Data)
					if Data then
						bedwars.AppController:openApp({app = bedwars.MatchHistoryApp,appId = "MatchHistoryApp",},Data)
					end
				end)
			else
				return
			end
		end,
	})																								
end)
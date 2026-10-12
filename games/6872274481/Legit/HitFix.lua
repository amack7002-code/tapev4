run(function()
	local Hitfix 

    HitFix = vape.Categories.Legit:CreateModule({
        Name = 'HitFix',
        Function = function(callback)
            local func = bedwars.SwordController.swingSwordAtMouse
            if not func then return end
            local foundIndex = nil
            pcall(function()
                for i = 1, 50 do
                    local constant = debug.getconstant(func, i)
                    if constant == 'Raycast' or constant == 'raycast' then
                        foundIndex = i
                        break
                    end
                end
            end)
            
            if foundIndex then
                pcall(function()
                    debug.setconstant(func, foundIndex, callback and 'raycast' or 'Raycast')
                end)
            end
            
            pcall(function()
                debug.setupvalue(func, 4, callback and bedwars.QueryUtil or workspace)
            end)
        end,
    })
end)
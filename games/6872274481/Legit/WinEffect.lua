run(function()
    local WinEffect
    local List
    local NameToId = {}
    
    WinEffect = vape.Categories.Legit:CreateModule({
        Name = "WinEffect",
        Function = function(callback)
            if callback then
                WinEffect:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
                    local remote = bedwars.Client:Get(remotes.WinEffectTriggered).instance
                    local payload = {
                        winEffectType = NameToId[List.Value],
                        winningPlayer = lplr
                    }
                    local ok = pcall(function()
                        remote.OnClientEvent:Fire(payload)
                    end)
                    if not ok then
                        for _, v in getconnections(remote.OnClientEvent) do
                            local fn = v.Function or v.Callback or v[1]
                            if fn then pcall(fn, payload) end
                        end
                    end
                end))
            end
        end,
        Tooltip = "select any clientside win effect"
    })
    
    local WinEffectName = {}
    for i, v in bedwars.WinEffectMeta do
        table.insert(WinEffectName, v.name)
        NameToId[v.name] = i
    end
    table.sort(WinEffectName)
    
    List = WinEffect:CreateDropdown({
        Name = "Effects",
        List = WinEffectName
    })
end)
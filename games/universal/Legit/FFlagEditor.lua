run(function()
    local FFlag
    local Flags
    local hasSetFFlag = pcall(function() return type(setfflag) == 'function' end)

    local function ChangeFFlag(suc)
        if not suc or not FFlag.Enabled then
            return
        end

        if not hasSetFFlag then
            notif('FFlag Editor', 'ur executor doesnt support setfflag gng', 8, 'warning')
            FFlag:Toggle(false)
            return
        end

        local success, json = pcall(function()
            return httpService:JSONDecode(Flags.Value)
        end)

        if not success or typeof(json) ~= 'table' then
            notif('FFlag Editor', 'invalid json format bruh – check ur brackets n commas', 8, 'warning')
            return
        end

        local applied = 0
        for i, v in json do
            local flagName = i:gsub('DFInt', '')
                :gsub('DFFlag', '')
                :gsub('FFlag', '')
                :gsub('FInt', '')
                :gsub('DFString', '')
                :gsub('FString', '')
            
            local ok = pcall(setfflag, flagName, tostring(v))
            if ok then
                applied = applied + 1
            end
        end

        if applied > 0 then
            notif('FFlag Editor', 'applied ' .. applied .. ' fflags – rejoin to take effect gng', 10, 'info')
        else
            notif('FFlag Editor', 'none of the flags applied – maybe theyre patched or typod', 10, 'warning')
        end
    end

    FFlag = vape.Categories.Legit:CreateModule({
        Name = 'FFlag Editor',
        Disabled = not hasSetFFlag,
        DisabledTooltip = 'ur executor (' .. ({identifyexecutor()})[1] .. ') doesnt have setfflag – module disabled',
        Function = function(call)
            if call then
                if not hasSetFFlag then
                    notif('FFlag Editor', 'ur executor doesnt support setfflag – disabling', 8, 'warning')
                    FFlag:Toggle(false)
                    return
                end
                ChangeFFlag(true)
            else
                notif('FFlag Editor', 'fflags will stay active until u rejoin the game', 10, 'info')
            end
        end,
        Tooltip = 'apply custom fflags using json format – works if ur executor supports setfflag'
    })

    Flags = FFlag:CreateTextBox({
        Name = 'FFlags',
        Placeholder = '{"FFlagDebugDisplayFPS": "True"}',
        Function = ChangeFFlag,
        Tooltip = 'json format only gng – flags get applied when u enable the module'
    })
end)
run(function()
    local AutoQueue
    local QueueType
    local Leave
    
    local Categories = {}
    
    AutoQueue = vape.Categories.Utility:CreateModule({
        Name = 'Auto Queue',
        Function = function(call)
            if call then
                repeat
                    local partyData = bedwars.Store:getState().Party
                    if partyData.leader.userId == lplr.UserId then
                        if partyData.queueState == 3 and partyData.queueState ~= Categories[QueueType.Value] then
                            replicatedStorage['events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events'].leaveQueue:FireServer()
                        elseif partyData.queueState < 2 then
                            replicatedStorage['events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events'].joinQueue:FireServer({
                                queueType = Categories[QueueType.Value]
                            })
                            task.wait(1)
                        end
                    elseif Leave.Enabled then
                        replicatedStorage['events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events'].leaveParty:FireServer()
                    end
                    task.wait(0.1)
                until not AutoQueue.Enabled
    
            else
                replicatedStorage['events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events'].leaveQueue:FireServer()
            end
        end
    })
    
    local list = {}
    for i,v in bedwars.QueueMeta do
        if not v.disabled then
            Categories[v.title] = i
            table.insert(list, v.title)
        end
    end
    QueueType = AutoQueue:CreateDropdown({
        Name = 'Queue Type',
        List = list,
        Default = 'Duels (2v2)'
    })
    Leave = AutoQueue:CreateToggle({
        Name = 'Leave Party',
        Default = true
    })
end)
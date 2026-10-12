run(function()
    local AntiSuffo
    
    AntiSuffo = vape.Categories.Utility:CreateModule({
    	Name = 'AntiSuffo',
    	Function = function(call)
    		if call then
    			repeat
    				if entitylib.isAlive then
    					if
    						getPlacedBlock(entitylib.character.RootPart.Position)
    						and (
    							getPlacedBlock(entitylib.character.RootPart.Position + Vector3.new(0, 2, 0))
    							and getPlacedBlock(entitylib.character.RootPart.Position - Vector3.new(0, 2, 0))
    						)
    					then
    						entitylib.character.RootPart.CFrame += Vector3.new(0, 0.5, 0)
    						if entitylib.character.RootPart.AssemblyLinearVelocity.Y < -1 then
    							entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.zero
    						end
    					end
    				end
    				task.wait()
    			until not AntiSuffo.Enabled
    		end
    	end,
    	Tooltip = 'no more suffocating in blocks',
    })
end)
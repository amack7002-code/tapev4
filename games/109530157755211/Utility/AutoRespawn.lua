run(function()
	AutoRespawn = vape.Categories.Utility:CreateModule({
		Name = 'AutoRespawn',
		Function = function(callback)
			if callback then
				repeat
					task.wait(1)
					local char = lplr.Character
					local hum = char and char:FindFirstChildOfClass('Humanoid')
					if hum and hum.Health <= 0 then
						local GlobalReplicator = require(replicatedStorage.Modules.GlobalReplicator)
						GlobalReplicator.StreamToServer('Systems', {Path = 'Spawn', Function = 'RequestSpawn', Args = {}})
					end
				until not AutoRespawn.Enabled
			end
		end,
		Tooltip = 'respawns u right away when u die'
	})
end)
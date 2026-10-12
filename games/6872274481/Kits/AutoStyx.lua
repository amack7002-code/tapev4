run(function()
	local AutoStyx
	local Range

	local function enemyInRange()
		if not entitylib.isAlive then return false end
		local root = entitylib.character.RootPart.Position
		for _, ent in entitylib.List do
			if ent.Targetable and ent.RootPart then
				if (ent.RootPart.Position - root).Magnitude <= Range.Value then
					return true
				end
			end
		end
		return false
	end

	AutoStyx = vape.Categories.Kits:CreateModule({
		Name = 'AutoStyx',
		Function = function(callback)
			if callback then
				repeat task.wait() until Range
				local exitPortalUUID = ""
				local entrancePortalData = nil

				AutoStyx:Clean(bedwars.Client:Get(remotes.StyxSpawnEntrancePortal):Connect(function(v1)
					if v1.entrancePortalData.player == lplr then
						entrancePortalData = v1.entrancePortalData
					end
				end))

				AutoStyx:Clean(bedwars.Client:Get(remotes.StyxSpawnExitPortal):Connect(function(v1)
					exitPortalUUID = v1.exitPortalData.uuid
					task.spawn(function()
						repeat task.wait(0.1) until not AutoStyx.Enabled or enemyInRange()
						if not AutoStyx.Enabled then return end
						if exitPortalUUID == '' then return end
						replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.StyxTryOpenExitPortalFromClient:InvokeServer(exitPortalUUID)
					end)
				end))

				AutoStyx:Clean(bedwars.Client:Get(remotes.StyxExitPortal):Connect(function(v1)
					if entrancePortalData then
						task.wait(0.1)
						bedwars.Client:Get(remotes.StyxPortal):SendToServer({
							entrancePortalData = entrancePortalData
						})
					end
				end))
			end
		end,
		Tooltip = 'auto opens styx portal when a enemy is close'
	})

	Range = AutoStyx:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 10,
		Default = 10
	})
end)
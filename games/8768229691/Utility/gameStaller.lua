run(function()
	local GameStaller
	local Height
	local Hidden
	local Notify
	local home
	local announced = false

	local function stop()
		local position = home
		home = nil
		store.staller = nil
		if store.split then
			mergeRoot('GameStaller')
		elseif position and entitylib.isAlive then
			sendRoot(position)
		end
	end

	GameStaller = vape.Categories.Utility:CreateModule({
		Name = 'GameStaller',
		Function = function(callback)
			if callback then
				GameStaller:Clean(entitylib.Events.LocalRemoved:Connect(function()
					home = nil
					store.staller = nil
				end))
				GameStaller:Clean(runService.Heartbeat:Connect(function()
					if not entitylib.isAlive or skywars.Store:getState().GameState ~= 'InGame' then
						if home then
							stop()
						end
						announced = false
						return
					end
					if not home then
						home = bodyRoot().Position
					end
					if Hidden.Enabled then
						splitRoot('GameStaller')
					elseif store.split then
						mergeRoot('GameStaller')
					end
					store.staller = true
					sendRoot(Vector3.new(home.X, home.Y + Height.Value, home.Z))
					if Notify.Enabled and not announced then
						announced = true
						notif('GameStaller', 'Your hitbox is '..Height.Value..' studs above the map until the game ends.', 6)
					end
				end))
			else
				stop()
			end
		end,
		Tooltip = 'Parks the hitbox the server uses far above the map from the start\nof the game until it ends, so nobody can reach you.'
	})
	Height = GameStaller:CreateSlider({
		Name = 'Height',
		Min = 200,
		Max = 5000,
		Default = 1500,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Hidden = GameStaller:CreateToggle({
		Name = 'Keep my view',
		Default = true,
		Tooltip = 'Only the hitbox goes up. Your character and camera stay on the map, on your screen only.'
	})
	Notify = GameStaller:CreateToggle({
		Name = 'Notify',
		Default = true
	})
end)

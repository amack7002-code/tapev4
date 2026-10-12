run(function()
	local NoSlowdown

	-- the speed the game would give you with nothing drawn
	local function normalSpeed(hum)
		local sprint = bedfight.ButtonProperties.new('Sprint')
		local speed = (hum:GetAttribute('DefaultSpeed') or 16) + (hum:GetAttribute('SpeedBoost') or 0) + (sprint.Active.Value and 4 or 0)
		-- the game flags 25 and over
		return math.min(speed, 24)
	end

	NoSlowdown = vape.Categories.Blatant:CreateModule({
		Name = 'NoSlowdown',
		Function = function(callback)
			if callback then
				local function hook(ent)
					local hum = ent.Humanoid
					NoSlowdown:Clean(hum:GetPropertyChangedSignal('WalkSpeed'):Connect(function()
						if hum:GetAttribute('SpeedLock') and hum.WalkSpeed < normalSpeed(hum) then
							hum.WalkSpeed = normalSpeed(hum)
						end
					end))
				end
				NoSlowdown:Clean(entitylib.Events.LocalAdded:Connect(hook))
				if entitylib.isAlive then
					hook(entitylib.character)
				end
			end
		end,
		Tooltip = 'Keeps your normal speed while a bow or crossbow is drawn'
	})
end)

run(function()
	local AutoShoot
	local shotCounter = 0

	AutoShoot = vape.Categories.Combat:CreateModule({
		Name = 'AutoShoot',
		Function = function(callback)
			if callback then
				repeat
					task.wait(0.5)
					local char = lplr.Character
					local hrp = char and char:FindFirstChild('HumanoidRootPart')
					if not hrp then
						local _, targetPart = getClosestDuck(hrp)
						if Network and Network.Fire then
							local direction = (targetPart.Position - hrp.Position).Unit
							shotCounter = shotCounter + 1
							Network.Fire('WeaponController_Shoot', vector.create(hrp.Position.X, hrp.Position.Y, hrp.Position.Z), vector.create(direction.X, direction.Y, direction.Z), shotCounter, workspace:GetServerTimeNow(), 'Shoot')
						end
					end
				until not AutoShoot.Enabled
			end
		end,
		Tooltip = 'auto shoots the closest duck for u'
	})
end)
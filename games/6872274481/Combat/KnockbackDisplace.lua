run(function()
	local KnockbackDisplace
	local KBDirection
	local originalApplyKnockback
	local hookedUtil
	local installedHook
	local hooked = false

	local _cachedKnockbackUtil = nil
	local function findKnockbackUtil()
		if _cachedKnockbackUtil and rawget(_cachedKnockbackUtil, 'applyKnockback') then
			return _cachedKnockbackUtil
		end
		for _, v in getgc(true) do
			if type(v) == 'table' and rawget(v, 'applyKnockback') and rawget(v, 'getDirection') and rawget(v, 'applyKnockbackDirection') then
				_cachedKnockbackUtil = v
				return v
			end
		end
	end

	local function unhookKnockback()
		if hookedUtil and originalApplyKnockback then
			pcall(function()
				if rawget(hookedUtil, 'applyKnockback') == installedHook then
					hookedUtil.applyKnockback = originalApplyKnockback
				end
			end)
		end
		hookedUtil = nil
		installedHook = nil
		originalApplyKnockback = nil
		hooked = false
	end

	KnockbackDisplace = vape.Categories.Combat:CreateModule({
		Name = 'KnockbackDisplace',
		Function = function(callback)
			if callback then
				if hooked then return end
				local util = findKnockbackUtil()
				if not util then
					notif('KnockbackDisplace', 'Failed to hook knockback!', 3)
					KnockbackDisplace:Toggle()
					return
				end
				originalApplyKnockback = util.applyKnockback
				local capturedOriginal = originalApplyKnockback
				local hookFn = function(hrp, mass, sourcePos, modifier)
					if not capturedOriginal then return end
					if not KnockbackDisplace.Enabled then
						return capturedOriginal(hrp, mass, sourcePos, modifier)
					end
					local dir = KBDirection.Value
					if dir == 'Default' then
						return capturedOriginal(hrp, mass, sourcePos, modifier)
					elseif dir == 'Void' then
						hrp:ApplyImpulse(Vector3.new(0, -mass * 60, 0))
						return
					elseif dir == 'Up' then
						hrp:ApplyImpulse(Vector3.new(0, mass * 48, 0))
						return
					else
						local hrpPos = hrp.Position
						local cf = hrp.CFrame
						local fakeSource
						if dir == 'Left' then
							fakeSource = hrpPos + cf.RightVector * 10
						elseif dir == 'Right' then
							fakeSource = hrpPos - cf.RightVector * 10
						elseif dir == 'Reverse' then
							if sourcePos then
								fakeSource = Vector3.new(2 * hrpPos.X - sourcePos.X, sourcePos.Y, 2 * hrpPos.Z - sourcePos.Z)
							end
						end
						return capturedOriginal(hrp, mass, fakeSource or sourcePos, modifier)
					end
				end
				util.applyKnockback = hookFn
				hookedUtil = util
				installedHook = hookFn
				hooked = true
			else
				unhookKnockback()
			end
		end,
		Tooltip = 'changes your knockback direction'
	})

	vape:Clean(unhookKnockback)

	KBDirection = KnockbackDisplace:CreateDropdown({
		Name = 'KBDirection',
		List = {'Default', 'Backwards', 'Up', 'Left', 'Right', 'Reverse'},
		Default = 'Default',
		Tooltip = 'Choose which direction to redirect your knockback'
	})
end)
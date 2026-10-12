run(function()
	local AntiEffects
	local AntiDizzy
	local AntiSleep
	local AntiTrap
	local AntiFear
	local old = nil
	local oldAdd = nil
	local sleepModifier = nil

	local function applyEffects()
		if AntiDizzy and AntiDizzy.Enabled then
			if not old then
				old = bedwars.ForestEnvironmentCollectibleEntityController.canPickupEntity
			end
			bedwars.ForestEnvironmentCollectibleEntityController.canPickupEntity = function(a, b, c)
				local selfRef, plr, mushroom = a, b, c
				if c == nil then
					selfRef, plr, mushroom = nil, a, b
				end
				if typeof(mushroom) == 'Instance' then
					local mush = mushroom:GetAttribute('MushroomType')
					if mush == 'Dizzy' then return false end
					if mush then return true end
				end
				if selfRef == nil then
					return old(plr, mushroom)
				end
				return old(selfRef, plr, mushroom)
			end
			runService:BindToRenderStep('antieffects_dizzy', Enum.RenderPriority.Character.Value + 2, function()
				runService:UnbindFromRenderStep('dizzy-status')
			end)
		else
			if old then
				bedwars.ForestEnvironmentCollectibleEntityController.canPickupEntity = old
				old = nil
			end
			runService:UnbindFromRenderStep('antieffects_dizzy')
		end

		if AntiTrap and AntiTrap.Enabled then
			runService:BindToRenderStep('antieffects_trap', Enum.RenderPriority.Character.Value + 2, function()
				local char = lplr.Character
				if not char then return end
				local hum = char:FindFirstChildOfClass('Humanoid')
				if char:GetAttribute('SnapTrapMarked') then
					char:SetAttribute('SnapTrapMarked', nil)
				end
				if hum then
					if hum.JumpPower == 0 then hum.JumpPower = 50 end
					if hum.JumpHeight == 0 then hum.JumpHeight = 7.2 end
					if hum.WalkSpeed < 10 then hum.WalkSpeed = 16 end
				end
			end)
		else
			runService:UnbindFromRenderStep('antieffects_trap')
		end

		if AntiFear and AntiFear.Enabled then
			runService:UnbindFromRenderStep('werewolf-fear-status')
			runService:BindToRenderStep('antieffects_fear', Enum.RenderPriority.Character.Value + 2, function()
				runService:UnbindFromRenderStep('werewolf-fear-status')
			end)
		else
			runService:UnbindFromRenderStep('antieffects_fear')
		end

		if AntiSleep and AntiSleep.Enabled then
			local char = lplr.Character
			if char then
				sleepModifier = bedwars.SprintController:getMovementStatusModifier()
				oldAdd = sleepModifier.addModifier
				sleepModifier.addModifier = function(self, tab)
					if tab and tab.moveSpeedMultiplier and tab.moveSpeedMultiplier <= 0 then
						return oldAdd(self, { moveSpeedMultiplier = 1 })
					end
					return oldAdd(self, tab)
				end
				runService:BindToRenderStep('antieffects_sleep', Enum.RenderPriority.Character.Value + 2, function()
					local stunTime = char:GetAttribute('StunnedUntilTime')
					local now = workspace:GetServerTimeNow()
					if stunTime and stunTime > now then
						char:SetAttribute('StunnedUntilTime', -1)
					end
					for mod, _ in sleepModifier.modifiers do
						if type(mod) == 'table' and (mod.moveSpeedMultiplier or 1) <= 0 then
							sleepModifier:removeModifier(mod)
						end
					end
					local hum = char:FindFirstChildOfClass('Humanoid')
					if hum then
						if hum.JumpPower == 0 then hum.JumpPower = 50 end
						if hum.JumpHeight == 0 then hum.JumpHeight = 7.2 end
					end
				end)
			end
		else
			runService:UnbindFromRenderStep('antieffects_sleep')
			if sleepModifier and oldAdd then
				sleepModifier.addModifier = oldAdd
				oldAdd = nil
				sleepModifier = nil
			end
		end
	end

	AntiEffects = vape.Categories.World:CreateModule({
		Name = 'AntiEffects',
		Tooltip = 'blocks negative effects',
		Function = function(callback)
			if callback then
				applyEffects()
			else
				if old then
					bedwars.ForestEnvironmentCollectibleEntityController.canPickupEntity = old
					old = nil
				end
				runService:UnbindFromRenderStep('antieffects_dizzy')
				runService:UnbindFromRenderStep('antieffects_sleep')
				runService:UnbindFromRenderStep('antieffects_fear')
				runService:UnbindFromRenderStep('antieffects_trap')
				if sleepModifier and oldAdd then
					sleepModifier.addModifier = oldAdd
					oldAdd = nil
					sleepModifier = nil
				end
			end
		end
	})
	AntiDizzy = AntiEffects:CreateToggle({
		Name = 'Dizzy',
		Tooltip = 'blocks dizzy effects from mushrooms and toads',
		Default = true,
		Function = function()
			if AntiEffects.Enabled then applyEffects() end
		end
	})
	AntiSleep = AntiEffects:CreateToggle({
		Name = 'Sleep',
		Tooltip = 'blocks sleep splash potion effect',
		Default = true,
		Function = function()
			if AntiEffects.Enabled then applyEffects() end
		end
	})
	AntiTrap = AntiEffects:CreateToggle({
		Name = 'Trap',
		Tooltip = 'allows you to move when snapped by a trap',
		Default = true,
		Function = function()
			if AntiEffects.Enabled then applyEffects() end
		end
	})
	AntiFear = AntiEffects:CreateToggle({
		Name = 'Fear',
		Tooltip = 'stops werewolf fear from walkin u away from them',
		Default = true,
		Function = function()
			if AntiEffects.Enabled then applyEffects() end
		end
	})
end)
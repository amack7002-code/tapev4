run(function()
	local AutoXurot
	local AutoBreath
	local Targets
	local Range
	local Delay
	local FastFly
	local breathActive = false
	local oldFlap
	local breathRemote

	local function getBreathRemote()
		if not breathRemote then
			pcall(function()
				breathRemote = replicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("DragonBreath")
			end)
		end
		return breathRemote
	end

	local function installHook()
		if oldFlap then return end
		if not bedwars.VoidDragonController then return end
		oldFlap = bedwars.VoidDragonController.flapWings
		bedwars.VoidDragonController.flapWings = function(self, ...)
			local result = oldFlap(self, ...)
			if result ~= false and self.inDragonForm then
				local modifier = bedwars.SprintController:getMovementStatusModifier():addModifier({
					blockSprint = true,
					constantSpeedMultiplier = 2
				})
				self.SpeedMaid:GiveTask(modifier)
			end
			return result
		end
	end

	local function removeHook()
		if oldFlap and bedwars.VoidDragonController then
			bedwars.VoidDragonController.flapWings = oldFlap
		end
		oldFlap = nil
	end

	local function startBreath()
		if breathActive then return end
		breathActive = true
		task.spawn(function()
			repeat task.wait() until Targets and Range and Delay
			while AutoXurot.Enabled and AutoBreath.Enabled and breathActive do
				if entitylib.isAlive and bedwars.VoidDragonController and bedwars.VoidDragonController.inDragonForm then
					local target = entitylib.EntityPosition({
						Range = Range.Value,
						Part = 'RootPart',
						Players = true,
						NPCs = false,
						Wallcheck = false,
						Sort = sortmethods.Distance
					})
					if target and target.RootPart then
						local remote = getBreathRemote()
						if remote then
							pcall(function()
								remote:FireServer({ player = lplr })
							end)
							task.wait(Delay.Value)
						end
					end
				end
				task.wait(0.1)
			end
			breathActive = false
		end)
	end

	AutoXurot = vape.Categories.Kits:CreateModule({
		Name = 'AutoXurot',
		Function = function(callback)
			if callback then
				if AutoBreath.Enabled then startBreath() end
				if FastFly.Enabled then installHook() end
			else
				breathActive = false
				removeHook()
			end
		end,
		Tooltip = 'auto dragon breath + faster flying'
	})

	AutoBreath = AutoXurot:CreateToggle({
		Name = 'Auto Breath',
		Tooltip = 'breathes on enemies while ur a dragon',
		Function = function(callback)
			if Targets and Targets.Object then Targets.Object.Visible = callback end
			if Range and Range.Object then Range.Object.Visible = callback end
			if Delay and Delay.Object then Delay.Object.Visible = callback end
			if AutoXurot.Enabled then
				if callback then startBreath() else breathActive = false end
			end
		end
	})
	Targets = AutoXurot:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	Range = AutoXurot:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30,
		Visible = false
	})
	Delay = AutoXurot:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Suffix = 's',
		Visible = false
	})

	FastFly = AutoXurot:CreateToggle({
		Name = 'Fast Fly',
		Tooltip = 'makes u fly way faster as a dragon',
		Function = function(callback)
			if AutoXurot.Enabled then
				if callback then installHook() else removeHook() end
			end
		end
	})

	task.defer(function()
		local breathOn = AutoBreath and AutoBreath.Enabled
		if Targets and Targets.Object then Targets.Object.Visible = breathOn end
		if Range and Range.Object then Range.Object.Visible = breathOn end
		if Delay and Delay.Object then Delay.Object.Visible = breathOn end
	end)
end)
run(function()
    local Fisherman
    local AutoMinigameToggle
    local CompleteDelaySlider
    local PullAnimationToggle
    local MinigameAnimationToggle
    local BlacklistOption
    local Blacklist
    local ESPToggle
	local AutoCastDelay
	local AutoCast
    local ESPNotifyToggle
    local Players = playersService
	local RunService = runService
	local lplr = Players.LocalPlayer
	local RandomizeToggle
    local RandomRange
	local waitTime
    local fishNames = {
		fish_iron = "Iron Fish",
		fish_diamond = "Diamond Fish",
		fish_gold = "Gold Fish",
		fish_special = "Special Fish",
		fish_emerald = "Emerald Fish",
	}

    local function buildMessage(fishModel, drops)
        local fishName = fishNames[fishModel] or fishModel

        if not drops or #drops == 0 then
            if fishModel == "fish_special" then
                return "You caught a " .. fishName .. "! (special item incoming)"
            end
            return "You caught a " .. fishName .. "!"
        end

        local totals = {}
        local order = {}
        for _, drop in ipairs(drops) do
            local item = tostring(drop.itemType) or 'unknown'
            local amount = tonumber(drop.amount) or 0
            if not totals[item] then
                totals[item] = 0
                table.insert(order, item)
            end
            totals[item] = totals[item] + amount
        end

        if fishModel == "fish_special" then
            return "You caught a " .. fishName .. "! You will receive a " .. table.concat(order, ", ")
        end

        local parts = {}
        for _, item in ipairs(order) do
            table.insert(parts, math.ceil(totals[item] * 1.4) .. "x " .. item)
        end

        return "You caught a " .. fishName .. "! Receiving " .. table.concat(parts, ", ")
    end

    local notifQueue = {}
	local function safeNotif(title, msg, dur)
		table.insert(notifQueue, {title=title, message=msg, duration=dur or 5})
	end
	local heartbeatConn = nil

    local autoMinigameActive    = false
    local pullAnimationTrack    = nil
    local successAnimationTrack = nil
    local espOld                = nil

	local function getBait()
		for _, v in workspace:GetChildren() do
			if v.Name == "fisherman_bobber" and v:GetAttribute("ProjectileShooter") == lplr.UserId then
				return v
			end
		end

		return
	end

    local function stopAllAnimations()
        if pullAnimationTrack then
            pcall(function() pullAnimationTrack:Stop() end)
            pullAnimationTrack = nil
        end
        if successAnimationTrack then
            pcall(function() successAnimationTrack:Stop() end)
            successAnimationTrack = nil
        end
    end

    local function setupESP()
        if not bedwars or not bedwars.FishingMinigameController then
            warn("[AutoFisher] FishingMinigameController not found")
            return
        end
        if espOld then return end 
        espOld = bedwars.FishingMinigameController.startMinigame

        bedwars.FishingMinigameController.startMinigame = function(self, dropData, result)
            if ESPToggle.Enabled and ESPNotifyToggle.Enabled and dropData and dropData.fishModel then
                safeNotif("Fisherman ESP", buildMessage(dropData.fishModel, dropData.drops), 8)
            end
            return espOld(self, dropData, result)
        end

        Fisherman:Clean(function()
            if espOld then
                bedwars.FishingMinigameController.startMinigame = espOld
                espOld = nil
            end
        end)
    end

    local function cleanupESP()
        if espOld then
            bedwars.FishingMinigameController.startMinigame = espOld
            espOld = nil
        end
    end

    local function setupAutoMinigame()
        if not bedwars or not bedwars.FishingMinigameController then
            warn("[AutoFisher] FishingMinigameController not found")
            return
        end

        local old = bedwars.FishingMinigameController.startMinigame

        bedwars.FishingMinigameController.startMinigame = function(self, dropData, result)
            if not AutoMinigameToggle.Enabled then
                return old(self, dropData, result)
            end

            if BlacklistOption.Enabled and dropData and dropData.fishModel then
                if table.find(Blacklist.ListEnabled, dropData.fishModel) then
                    local hum = lplr.Character and lplr.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum:GetState() ~= Enum.HumanoidStateType.Jumping then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                    return old(self, dropData, result)
                end
            end

            autoMinigameActive = true
            stopAllAnimations()

            local waitTime = 0
            if RandomizeToggle and RandomizeToggle.Enabled then
                local min = RandomRange.ValueMin
                local max = RandomRange.ValueMax
                waitTime = min + (max - min) * math.random()
            else
                waitTime = CompleteDelaySlider.Value
            end

            task.spawn(function()
                if PullAnimationToggle.Enabled and waitTime > 0 then
                    local ok, track = pcall(function()
                        return bedwars.GameAnimationUtil:playAnimation(
                            lplr, bedwars.AnimationType.FISHING_ROD_PULLING
                        )
                    end)
                    if ok and track then pullAnimationTrack = track end
                end

                if waitTime > 0 then
                    task.wait(waitTime)
                end

                if pullAnimationTrack then
                    pcall(function() pullAnimationTrack:Stop() end)
                    pullAnimationTrack = nil
                end

                if MinigameAnimationToggle.Enabled then
                    local ok, track = pcall(function()
                        return bedwars.GameAnimationUtil:playAnimation(
                            lplr, bedwars.AnimationType.FISHING_ROD_CATCH_SUCCESS
                        )
                    end)
                    if ok and track then successAnimationTrack = track end
                end

                if result then
                    pcall(function() result({ win = true }) end)
                end

                task.wait(0.5)

                if successAnimationTrack then
                    pcall(function() successAnimationTrack:Stop() end)
                    successAnimationTrack = nil
                end

                autoMinigameActive = false
            end)
        end

        Fisherman:Clean(function()
            bedwars.FishingMinigameController.startMinigame = old
            stopAllAnimations()
        end)
    end

	local function setupAutoCast()
		task.spawn(function()
			repeat
				if entitylib.isAlive and AutoCast.Enabled and (store.hand.tool and store.hand.tool.Name == 'fishing_rod') then
					local position = workspace.CurrentCamera.ViewportSize / 2
					local ray = cloneref(lplr:GetMouse()).UnitRay

					if not getBait() and not workspace:Raycast(entitylib.character.Head.Position + (ray.Direction * 6), Vector3.new(0, -20, 0)) then
						task.wait(AutoCastDelay:GetRandomValue())

						for _, v in {true, false} do
							VirtualInputManager:SendMouseButtonEvent(position.X, position.Y, 0, v, game, 1)
							task.wait()
						end
						task.wait(0.5)
					end
				end
				task.wait(0.1)
			until not Fisherman.Enabled
		end)
	end

    Fisherman = vape.Categories.Kits:CreateModule({
		Name = "AutoFisher",
		Function = function(callback)
            if callback then
                if ESPToggle.Enabled then setupESP() end
                if AutoMinigameToggle.Enabled then setupAutoMinigame() end
                setupAutoCast()

                heartbeatConn = RunService.Heartbeat:Connect(function()
                    if #notifQueue == 0 then return end
                    local entry = table.remove(notifQueue, 1)
                    pcall(notif, entry.title, entry.message, entry.duration)
                end)
                Fisherman:Clean(heartbeatConn)

            else
                autoMinigameActive = false
                stopAllAnimations()
                cleanupESP()
                notifQueue = {} 
            end
        end
    })

    AutoMinigameToggle = Fisherman:CreateToggle({
		Name = "Auto Minigame",
		Default = false,
		Function = function(cv)
			if CompleteDelaySlider and CompleteDelaySlider.Object then
				CompleteDelaySlider.Object.Visible = cv and not (RandomizeToggle and RandomizeToggle.Enabled)
			end
			if PullAnimationToggle and PullAnimationToggle.Object then PullAnimationToggle.Object.Visible = cv end
			if MinigameAnimationToggle and MinigameAnimationToggle.Object then MinigameAnimationToggle.Object.Visible = cv end
			if RandomizeToggle and RandomizeToggle.Object then RandomizeToggle.Object.Visible = cv end
			if RandomRange and RandomRange.Object then RandomRange.Object.Visible = cv and RandomizeToggle.Enabled end
			if Fisherman.Enabled and cv then setupAutoMinigame() end
		end
	})

	CompleteDelaySlider = Fisherman:CreateSlider({
		Name = "Complete Delay",
		Min = 0,
		Max = 5,
		Default = 1,
		Decimal = 10,
		Suffix = "s",
		Visible = false,
	})

	RandomizeToggle = Fisherman:CreateToggle({
		Name = "Randomize Timing",
		Default = false,
		Function = function(cv)
			if RandomRange and RandomRange.Object then RandomRange.Object.Visible = cv end
			if CompleteDelaySlider and CompleteDelaySlider.Object then CompleteDelaySlider.Object.Visible = not cv end
		end
	})

	RandomRange = Fisherman:CreateTwoSlider({
		Name = "Random Delay Range",
		Min = 0.1,
		Max = 5,
		DefaultMin = 0.5,
		DefaultMax = 2,
		Decimal = 10,
		Visible = false,
	})

	PullAnimationToggle = Fisherman:CreateToggle({
		Name = "Pull Animation",
		Default = true,
		Visible = false,
	})

	MinigameAnimationToggle = Fisherman:CreateToggle({
		Name = "Success Animation",
		Default = true,
		Visible = false,
	})

	BlacklistOption = Fisherman:CreateToggle({
		Name = "Blacklist",
		Default = false,
		Function = function(cv)
			if Blacklist and Blacklist.Object then Blacklist.Object.Visible = cv end
		end
	})

	Blacklist = Fisherman:CreateTextList({
		Name = "Blacklist Fish",
		Default = {"fish_iron"}
	})

	AutoCast = Fisherman:CreateToggle({
		Name 	= "AutoCast",
		Default = false,
		Function = function(callback)
			if callback then
				if AutoCastDelay and AutoCastDelay.Object then AutoCastDelay.Object.Visible = callback end
				if AutoCast.Enabled and callback then setupAutoCast() end
			end
		end
	})

	AutoCastDelay = Fisherman:CreateTwoSlider({
		Name 	= "Cast Delay",
		Min 	= 0,
		Max 	= 5,
		Decimal = 5,
		DefaultMin = 0.3,
		DefaultMax = 1.2,
		Darker 	= true,
		Visible = AutoCast.Enabled
	})	

    ESPToggle = Fisherman:CreateToggle({
		Name = "Fisherman ESP",
		Default = false,
		Function = function(cv)
			if ESPNotifyToggle and ESPNotifyToggle.Object then ESPNotifyToggle.Object.Visible = cv end
			if Fisherman.Enabled then
				if cv then setupESP() else cleanupESP() end
			end
		end
	})

	ESPNotifyToggle = Fisherman:CreateToggle({
		Name = "Notify Loot",
		Default = true,
		Visible = false,
	})

	task.defer(function()
		local minigameOn = AutoMinigameToggle and AutoMinigameToggle.Enabled
		local randomOn = RandomizeToggle and RandomizeToggle.Enabled
		if Blacklist and Blacklist.Object then Blacklist.Object.Visible = BlacklistOption and BlacklistOption.Enabled or false end
		if AutoCastDelay and AutoCastDelay.Object then AutoCastDelay.Object.Visible = AutoCast and AutoCast.Enabled or false end
		if ESPNotifyToggle and ESPNotifyToggle.Object then ESPNotifyToggle.Object.Visible = ESPToggle and ESPToggle.Enabled or false end
		if PullAnimationToggle and PullAnimationToggle.Object then PullAnimationToggle.Object.Visible = minigameOn or false end
		if MinigameAnimationToggle and MinigameAnimationToggle.Object then MinigameAnimationToggle.Object.Visible = minigameOn or false end
		if RandomizeToggle and RandomizeToggle.Object then RandomizeToggle.Object.Visible = minigameOn or false end
		if RandomRange and RandomRange.Object then RandomRange.Object.Visible = (minigameOn and randomOn) or false end
		if CompleteDelaySlider and CompleteDelaySlider.Object then CompleteDelaySlider.Object.Visible = (minigameOn and not randomOn) or false end
	end)
end)
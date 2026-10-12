run(function()
	local MotionBlur
	local Intensity
	local blur
	local lastLook
	local lastPos
	local currentSize = 0

	local function makeBlur()
		if blur and blur.Parent then return blur end
		local cam = workspace.CurrentCamera
		if not cam then return nil end
		blur = Instance.new('BlurEffect')
		blur.Name = 'AeroMotionBlur'
		blur.Size = 0
		blur.Enabled = true
		blur.Parent = cam
		return blur
	end

	local function killBlur()
		if blur then
			pcall(function() blur:Destroy() end)
			blur = nil
		end
		lastLook = nil
		lastPos = nil
		currentSize = 0
	end

	MotionBlur = vape.Categories.Render:CreateModule({
		Name = 'MotionBlur',
		Function = function(callback)
			if callback then
				makeBlur()

				MotionBlur:Clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
					killBlur()
					makeBlur()
				end))

				MotionBlur:Clean(runService.RenderStepped:Connect(function(dt)
					if dt <= 0 or dt > 0.5 then return end
					local cam = workspace.CurrentCamera
					if not cam then return end
					if not (blur and blur.Parent) then
						if not makeBlur() then return end
					end

					local cf = cam.CFrame
					local look = cf.LookVector
					local pos = cf.Position
					local target = 0

					if lastLook then
						local dot = math.clamp(lastLook:Dot(look), -1, 1)
						local turn = math.deg(math.acos(dot)) / dt
						target = target + turn * 0.02
					end

					if lastPos then
						local travel = (pos - lastPos).Magnitude / dt
						target = target + math.max(travel - 22, 0) * 0.07
					end

					lastLook = look
					lastPos = pos

					target = math.clamp(target * (Intensity.Value / 10), 0, 42)

					local speed = target > currentSize and 20 or 8
					currentSize = currentSize + (target - currentSize) * math.clamp(dt * speed, 0, 1)
					if currentSize < 0.05 then currentSize = 0 end
					blur.Size = currentSize
				end))

				MotionBlur:Clean(killBlur)
			else
				killBlur()
			end
		end,
		Tooltip = 'blurs ur screen when u spin the cam or move fast'
	})

	Intensity = MotionBlur:CreateSlider({
		Name = 'Intensity',
		Min = 1,
		Max = 25,
		Default = 8,
		Tooltip = 'how heavy the blur hits, crank it for that edit look'
	})
end)
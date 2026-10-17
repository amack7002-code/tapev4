local AutoClicker
local CPS
local Thread
local mouseDown = false

run(function()
local function stopClicking()
	mouseDown = false
	if Thread then
		task.cancel(Thread)
		Thread = nil
	end
end

local function AutoClick()
	if Thread then return end
	Thread = task.spawn(function()
		task.wait(1 / CPS.GetRandomValue())
		while AutoClicker.Enabled and mouseDown do
			task.spawn(arena.Client.startHit)
			task.wait(1 / CPS.GetRandomValue())
		end
		Thread = nil
	end)
end

AutoClicker = vape.Categories.Combat:CreateModule({
	Name = 'AutoClicker',
	Function = function(callback)
		if callback then
			mouseDown = false
			AutoClicker:Clean(inputService.InputBegan:Connect(function(input, gameProcessed)
				if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
					mouseDown = true
					AutoClick()
				end
			end))

			AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					stopClicking()
				end
			end))
		else
			stopClicking()
		end
	end,
	Tooltip = 'Hold attack button to automatically click'
})
CPS = AutoClicker:CreateTwoSlider({
	Name = 'CPS',
	Min = 1,
	Max = 9,
	DefaultMin = 7,
	DefaultMax = 7
})
end)
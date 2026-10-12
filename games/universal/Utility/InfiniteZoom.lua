run(function()
	local InfiniteZoom
	local ZoomSlider

	local originalZoom = lplr.CameraMaxZoomDistance
	InfiniteZoom = vape.Categories.Utility:CreateModule({
		Name = 'InfiniteZoom',
		Function = function(callback)
			if callback then
				lplr.CameraMaxZoomDistance = ZoomSlider.Value
			else
				lplr.CameraMaxZoomDistance = originalZoom
			end
		end,
		Tooltip = 'Allows you to zoom out further than normal'
	})

	ZoomSlider = InfiniteZoom:CreateSlider({
		Name = 'Max Distance',
		Min = 128,
		Max = 2000,
		Default = 500,
		Suffix = 'studs',
		Function = function(val)
			if InfiniteZoom.Enabled then
				lplr.CameraMaxZoomDistance = val
			end
		end
	})
end)
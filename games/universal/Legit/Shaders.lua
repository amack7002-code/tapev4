run(function()
	local Shaders
	local Lighting = lightingService
	local snapshot = {}
	local createdEffects = {}
	local hiddenChildren = {}
	local isEnabled = false

	local VISUAL_TYPES = {
		BloomEffect           = true,
		BlurEffect            = true,
		ColorCorrectionEffect = true,
		DepthOfFieldEffect    = true,
		SunRaysEffect         = true,
		Atmosphere            = true,
		Sky                   = true,
	}

	local function saveSnapshot()
		snapshot = {
			Technology               = Lighting.Technology,
			GlobalShadows            = Lighting.GlobalShadows,
			ShadowSoftness           = Lighting.ShadowSoftness,
			Brightness               = Lighting.Brightness,
			ExposureCompensation     = Lighting.ExposureCompensation,
			EnvironmentDiffuseScale  = Lighting.EnvironmentDiffuseScale,
			EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
			ClockTime                = Lighting.ClockTime,
			OutdoorAmbient           = Lighting.OutdoorAmbient,
		}
	end

	local function restoreSnapshot()
		if not next(snapshot) then return end
		pcall(function()
			Lighting.Technology              = snapshot.Technology
			Lighting.GlobalShadows           = snapshot.GlobalShadows
			Lighting.ShadowSoftness          = snapshot.ShadowSoftness
			Lighting.Brightness              = snapshot.Brightness
			Lighting.ExposureCompensation    = snapshot.ExposureCompensation
			Lighting.EnvironmentDiffuseScale  = snapshot.EnvironmentDiffuseScale
			Lighting.EnvironmentSpecularScale = snapshot.EnvironmentSpecularScale
			Lighting.ClockTime               = snapshot.ClockTime
			Lighting.OutdoorAmbient          = snapshot.OutdoorAmbient
		end)
		snapshot = {}
	end

	local function stashLightingChildren()
		hiddenChildren = {}
		for _, v in ipairs(Lighting:GetChildren()) do
			if VISUAL_TYPES[v.ClassName] then
				v.Parent = nil
				table.insert(hiddenChildren, v)
			end
		end
	end

	local function restoreLightingChildren()
		for _, v in ipairs(hiddenChildren) do
			pcall(function() v.Parent = Lighting end)
		end
		hiddenChildren = {}
	end

	local function makeEffect(className)
		local inst = Instance.new(className)
		table.insert(createdEffects, inst)
		return inst
	end

	local function destroyCreatedEffects()
		for _, v in ipairs(createdEffects) do
			pcall(function() v:Destroy() end)
		end
		createdEffects = {}
	end

	local function applyLighting()
		pcall(function()
			Lighting.Technology              = Enum.Technology.Future
			Lighting.GlobalShadows           = true
			Lighting.ShadowSoftness          = 0.7
			Lighting.Brightness              = Brightness.Value
			Lighting.ExposureCompensation    = ExposureComp.Value
			Lighting.EnvironmentDiffuseScale  = DiffuseScale.Value
			Lighting.EnvironmentSpecularScale = SpecularScale.Value
			Lighting.ClockTime               = TimeOfDay.Value
			Lighting.OutdoorAmbient          = Color3.fromRGB(160, 160, 160)
		end)
	end

	local function buildEffects()
		if BloomToggle.Enabled then
			local Bloom = makeEffect("BloomEffect")
			Bloom.Intensity = BloomIntensity.Value
			Bloom.Size      = 32
			Bloom.Threshold = 0.9
			Bloom.Parent    = Lighting
		end

		if ColorToggle.Enabled then
			local Color = makeEffect("ColorCorrectionEffect")
			Color.Brightness = 0.05
			Color.Contrast   = -0.05
			Color.Saturation = Saturation.Value
			Color.TintColor  = Color3.fromRGB(255, 242, 230)
			Color.Parent     = Lighting
		end

		if DoFToggle.Enabled then
			local DoF = makeEffect("DepthOfFieldEffect")
			DoF.FarIntensity  = 0.15
			DoF.NearIntensity = 0
			DoF.FocusDistance = DoFFocus.Value
			DoF.InFocusRadius = 50
			DoF.Parent        = Lighting
		end

		if BlurToggle.Enabled then
			local Blur = makeEffect("BlurEffect")
			Blur.Size   = BlurSize.Value
			Blur.Parent = Lighting
		end

		if AtmosphereToggle.Enabled then
			local Atmo = makeEffect("Atmosphere")
			Atmo.Density = AtmoDensity.Value
			Atmo.Offset  = 0.25
			Atmo.Glare   = 0
			Atmo.Haze    = 1.2
			Atmo.Color   = Color3.fromRGB(245, 235, 225)
			Atmo.Parent  = Lighting
		end

		if SunRaysToggle.Enabled then
			local Sun = makeEffect("SunRaysEffect")
			Sun.Intensity = 0.25
			Sun.Spread    = 0.5
			Sun.Parent    = Lighting
		end
	end

	local function enable()
		if isEnabled then return end
		isEnabled = true
		saveSnapshot()
		stashLightingChildren()
		applyLighting()
		buildEffects()
	end

	local function disable()
		if not isEnabled then return end
		isEnabled = false
		destroyCreatedEffects()
		restoreSnapshot()
		restoreLightingChildren()
	end

	Shaders = vape.Categories.Legit:CreateModule({
		Name = "Shaders",
		Function = function(callback)
			if callback then enable() else disable() end
		end,
		Tooltip = "Post-processing shaders with customisable effects"
	})

	Brightness = Shaders:CreateSlider({
		Name    = "Brightness",
		Min     = 0,
		Max     = 5,
		Default = 1.5,
		Decimal = 1,
		Function = function(val)
			if isEnabled then pcall(function() Lighting.Brightness = val end) end
		end,
		Tooltip = "Scene brightness"
	})

	ExposureComp = Shaders:CreateSlider({
		Name    = "Exposure",
		Min     = -1,
		Max     = 1,
		Default = -0.15,
		Decimal = 2,
		Function = function(val)
			if isEnabled then pcall(function() Lighting.ExposureCompensation = val end) end
		end,
		Tooltip = "Exposure compensation"
	})

	DiffuseScale = Shaders:CreateSlider({
		Name    = "Diffuse Scale",
		Min     = 0,
		Max     = 1,
		Default = 0.6,
		Decimal = 2,
		Function = function(val)
			if isEnabled then pcall(function() Lighting.EnvironmentDiffuseScale = val end) end
		end
	})

	SpecularScale = Shaders:CreateSlider({
		Name    = "Specular Scale",
		Min     = 0,
		Max     = 1,
		Default = 0.4,
		Decimal = 2,
		Function = function(val)
			if isEnabled then pcall(function() Lighting.EnvironmentSpecularScale = val end) end
		end
	})

	TimeOfDay = Shaders:CreateSlider({
		Name    = "Time of Day",
		Min     = 0,
		Max     = 24,
		Default = 14,
		Decimal = 1,
		Function = function(val)
			if isEnabled then pcall(function() Lighting.ClockTime = val end) end
		end,
		Tooltip = "0 = midnight, 12 = noon, 24 = midnight"
	})

	BloomToggle = Shaders:CreateToggle({
		Name    = "Bloom",
		Default = true,
		Function = function()
			if isEnabled then disable() enable() end
		end
	})

	BloomIntensity = Shaders:CreateSlider({
		Name    = "Bloom Intensity",
		Min     = 0,
		Max     = 2,
		Default = 0.45,
		Decimal = 2,
		Darker  = true,
		Function = function(val)
			if not isEnabled then return end
			for _, v in ipairs(Lighting:GetChildren()) do
				if v:IsA("BloomEffect") then v.Intensity = val end
			end
		end
	})

	ColorToggle = Shaders:CreateToggle({
		Name    = "Color Correction",
		Default = true,
		Function = function()
			if isEnabled then disable() enable() end
		end
	})

	Saturation = Shaders:CreateSlider({
		Name    = "Saturation",
		Min     = -1,
		Max     = 1,
		Default = 0.12,
		Decimal = 2,
		Darker  = true,
		Function = function(val)
			if not isEnabled then return end
			for _, v in ipairs(Lighting:GetChildren()) do
				if v:IsA("ColorCorrectionEffect") then v.Saturation = val end
			end
		end
	})

	DoFToggle = Shaders:CreateToggle({
		Name    = "Depth of Field",
		Default = true,
		Function = function()
			if isEnabled then disable() enable() end
		end,
		Tooltip = "Blurs distant objects. Disable if it hurts visibility."
	})

	DoFFocus = Shaders:CreateSlider({
		Name    = "DoF Focus Distance",
		Min     = 10,
		Max     = 200,
		Default = 60,
		Darker  = true,
		Function = function(val)
			if not isEnabled then return end
			for _, v in ipairs(Lighting:GetChildren()) do
				if v:IsA("DepthOfFieldEffect") then v.FocusDistance = val end
			end
		end
	})

	BlurToggle = Shaders:CreateToggle({
		Name    = "Blur",
		Default = true,
		Function = function()
			if isEnabled then disable() enable() end
		end
	})

	BlurSize = Shaders:CreateSlider({
		Name    = "Blur Size",
		Min     = 0,
		Max     = 10,
		Default = 2,
		Darker  = true,
		Function = function(val)
			if not isEnabled then return end
			for _, v in ipairs(Lighting:GetChildren()) do
				if v:IsA("BlurEffect") then v.Size = val end
			end
		end
	})

	AtmosphereToggle = Shaders:CreateToggle({
		Name    = "Atmosphere",
		Default = true,
		Function = function()
			if isEnabled then disable() enable() end
		end
	})

	AtmoDensity = Shaders:CreateSlider({
		Name    = "Atmosphere Density",
		Min     = 0,
		Max     = 1,
		Default = 0.35,
		Decimal = 2,
		Darker  = true,
		Function = function(val)
			if not isEnabled then return end
			for _, v in ipairs(Lighting:GetChildren()) do
				if v:IsA("Atmosphere") then v.Density = val end
			end
		end,
		Tooltip = "Higher = more fog/haze. Lower for better visibility."
	})

	SunRaysToggle = Shaders:CreateToggle({
		Name    = "Sun Rays",
		Default = false,
		Function = function()
			if isEnabled then disable() enable() end
		end,
		Tooltip = "God rays effect through objects"
	})
end)
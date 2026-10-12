run(function()
    local lightingService = cloneref(game:GetService('Lighting'))
    local lightingsettings = {}
    local Fullbright = {Enabled = false}
    local BrightnessSlider
    
    local lastLightingChange = 0
    local DEBOUNCE_TIME = 0.016 
    
    Fullbright = vape.Categories.World:CreateModule({
        Name = "Fullbright",
        Function = function(callback)
            if callback then
                lightingsettings = {
                    Brightness = lightingService.Brightness,
                    ClockTime = lightingService.ClockTime,
                    FogEnd = lightingService.FogEnd,
                    GlobalShadows = lightingService.GlobalShadows,
                    OutdoorAmbient = lightingService.OutdoorAmbient,
                    Ambient = lightingService.Ambient,
                    ExposureCompensation = lightingService.ExposureCompensation
                }
                
                local brightnessValue = BrightnessSlider and BrightnessSlider.Value or 5
                
                lastLightingChange = tick()
                lightingService.Brightness = brightnessValue
                lightingService.ClockTime = 14  
                lightingService.FogEnd = 100000 
                lightingService.GlobalShadows = false  
                lightingService.OutdoorAmbient = Color3.fromRGB(255, 255, 255)  
                lightingService.Ambient = Color3.fromRGB(255, 255, 255)  
                lightingService.ExposureCompensation = 1  
                
                local function protectProperty(propertyName, value)
                    return lightingService:GetPropertyChangedSignal(propertyName):Connect(function()
                        local now = tick()
                        if now - lastLightingChange > DEBOUNCE_TIME then
                            lastLightingChange = now
                            lightingService[propertyName] = value
                        end
                    end)
                end
                
                Fullbright:Clean(protectProperty("Brightness", brightnessValue))
                Fullbright:Clean(protectProperty("Ambient", Color3.fromRGB(255, 255, 255)))
                Fullbright:Clean(protectProperty("ExposureCompensation", 1))
                
            else
                lastLightingChange = tick()
                
                for property, value in pairs(lightingsettings) do
                    if value ~= nil then
                        lightingService[property] = value
                    end
                end
                
                table.clear(lightingsettings)
            end
        end,
        HoverText = "Makes everything bright and removes shadows"
    })
    
    BrightnessSlider = Fullbright:CreateSlider({
        Name = "Brightness",
        Min = 1,
        Max = 10,
        Default = 5,
        Function = function(value)
            if Fullbright.Enabled then
                lastLightingChange = tick()
                lightingService.Brightness = value
            end
        end
    })
    
    local ExtraBright = Fullbright:CreateToggle({
        Name = "Extra Bright",
        Function = function(callback)
            if Fullbright.Enabled then
                lastLightingChange = tick()
                if callback then
                    lightingService.Brightness = 10
                    lightingService.Ambient = Color3.fromRGB(255, 255, 255)
                    lightingService.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
                    lightingService.ExposureCompensation = 2
                    
                    if not lightingService:FindFirstChild("VapeSun") then
                        local sun = Instance.new("SunRaysEffect")
                        sun.Name = "VapeSun"
                        sun.Intensity = 0.1
                        sun.Spread = 1
                        sun.Parent = lightingService
                    end
                else
                    lightingService.Brightness = BrightnessSlider.Value
                    lightingService.Ambient = Color3.fromRGB(255, 255, 255)
                    lightingService.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
                    lightingService.ExposureCompensation = 1
                    
                    local sun = lightingService:FindFirstChild("VapeSun")
                    if sun then
                        sun:Destroy()
                    end
                end
            end
        end
    })
    
    local NoShadows = Fullbright:CreateToggle({
        Name = "No Shadows",
        Function = function(callback)
            if Fullbright.Enabled then
                lastLightingChange = tick()
                lightingService.GlobalShadows = not callback
            end
        end,
        Default = true
    })
end)
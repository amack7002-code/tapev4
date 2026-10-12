run(function()
    local DamageTexts = {Enabled = false}
	local Color
    local connection
	local Fonts
	local customMSG
	local DamageMessages = {
		'fuck',
		'shit',
		'damn',
		'hell',
		'bitch',
		'ass',
		'piss',
		'cock',
		'motherfucker',
		'fucker',
		'shitter',
		'bastard',
		'asshole',
		'get fucked',
		'eat shit',
		'suck it',
		'die',
		'kill',
		'smash',
		'crush',
		'break',
		'wreck',
		'destroy',
		'annihilate',
		'obliterate',
		'decimate',
		'massacre',
		'slaughter',
		'fuck you',
		'shithead',
		'dick',
		'pussy',
		'twat',
		'wanker',
		'bugger',
		'bloody hell',
		'goddamn',
		'holy shit',
		'what the fuck',
		'oh fuck',
		'fucking hell',
		'shitty',
		'crappy',
		'lousy',
		'motherfucking',
		'goddamn shit',
		'fuckface',
		'dipshit',
		'dumbshit',
		'jackass',
		'prick',
		'cocksucker',
		'asshat',
		'buttfuck',
		'fucknut',
		'shitbag',
		'hellfire',
		'fuckshit',
		'damnass',
		'piss off',
		'screw you',
		'bastard shit',
		'fucktard',
		'shitfuck',
		'cunt',
	    'bitchass nigga',
		'nigga',
		'die pls',
		'desire is some ass',
	}
	
	local RGBColors = {
		Color3.fromRGB(255, 255, 255), 
		Color3.fromRGB(0, 0, 0),       
		Color3.fromRGB(128, 0, 128), 
		Color3.fromRGB(0, 0, 255),  
		Color3.fromRGB(75, 0, 130),    
		Color3.fromRGB(0, 100, 255), 
		Color3.fromRGB(200, 200, 255),
		Color3.fromRGB(30, 30, 30)  
	}
	
	local function randomizer(tbl)
	    if not typeof(tbl) == "table" then return end
	    local index = math.random(1,#tbl)
	    local value = tbl[index]
	    return value,index
	end
	local font  = 'Arial'
    DamageTexts = vape.Categories.Render:CreateModule({
        Name = "DamageTexts",
        Function = function(call)
			if call then
				DamageTexts:Clean(workspace.DescendantAdded:Connect(function(part)
				    if part.Name == "DamageIndicatorPart" and part:IsA("BasePart") then
				        for i, v in part:GetDescendants() do
				            if v:IsA("TextLabel") then
				                local txt = randomizer(DamageMessages)
				                local clr = randomizer(RGBColors)
								if customMSG.Enabled then
				                	v.Text = txt
								end
								if Color.Enabled then
				              	  	v.TextColor3 = clr
								end
				            end
				        end
				    end
				end))
			else

			end
        end,
        Tooltip = "Customizes Damage Affects"
    })
	customMSG = DamageTexts:CreateToggle({
		Name = "Custom Messages",
		Default = true
	})
	Color = DamageTexts:CreateToggle({
		Name = "Custom Colors",
		Default = true
	})
	Fonts = DamageTexts:CreateFont({
		Name = 'Font',
		Function = function(val)
			font = val
		end
	})
end)
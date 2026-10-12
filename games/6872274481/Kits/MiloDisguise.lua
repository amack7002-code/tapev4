run(function()
	local MiloDisguse
	local Blocks
	local old
	MiloDisguse = vape.Categories.Kits:CreateModule({
		Name = "MiloDisguise",
		Tooltip = 'allows you to change to any block u want to hide as',
		Function = function(callback)
			if not callback then
				return
			end
			MiloDisguse:Toggle(false)
			local v88 = {
				["data"] = {
					["blockType"] = Blocks.Value or 'wool_red'
				}
			}

			bedwars.Client:Get(remotes.Mimic):SendToServer(v88)
		end
	})
	Blocks = MiloDisguse:CreateTextBox({
		Name = "Blocks",
		Default = 'wool_brown',
		Visible = true
	})
	
end)
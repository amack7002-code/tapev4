run(function()
	local PlayEmote
	local Emote
	local Loop
	local Others
	local Mute
	local sounds = {}

	local function wheel()
		local folder, list = lplr:FindFirstChild('EmoteWheel'), {}
		for _, v in folder and folder:GetChildren() or {} do
			if v:IsA('StringValue') and v.Value ~= '' then
				table.insert(list, v)
			end
		end
		table.sort(list, function(a, b)
			return a.Name < b.Name
		end)
		return list
	end

	local function play()
		for _, slot in wheel() do
			if slot.Value == Emote.Value then
				bedfight.Signals.PlayEmote:Fire(slot.Name)
				if Others.Enabled then
					fireRemote('PlayEmote', tonumber(slot.Name) or slot.Name)
				end
				return
			end
		end
	end

	local function mute(enabled)
		for _, emote in bedfight.EmotesData do
			if type(emote) == 'table' and type(emote.FrameConfigs) == 'table' then
				for _, frame in emote.FrameConfigs do
					for _, config in frame do
						if type(config) == 'table' and config.Id then
							sounds[config] = sounds[config] or config.Id
							config.Id = enabled and 'rbxassetid://0' or sounds[config]
						end
					end
				end
			end
		end
	end

	PlayEmote = vape.Categories.Utility:CreateModule({
		Name = 'PlayEmote',
		Function = function(callback)
			mute(callback and Mute.Enabled)
			if callback then
				repeat
					play()
					-- the game allows one emote every three seconds
					task.wait(3.1)
				until not (PlayEmote.Enabled and Loop.Enabled)
			end
		end,
		Tooltip = 'Plays an emote from your wheel without opening it'
	})
	local names = {}
	for _, slot in wheel() do
		table.insert(names, slot.Value)
	end
	Emote = PlayEmote:CreateDropdown({
		Name = 'Emote',
		List = names
	})
	Loop = PlayEmote:CreateToggle({
		Name = 'Loop',
		Tooltip = 'Plays it again every three seconds'
	})
	Others = PlayEmote:CreateToggle({
		Name = 'Show to others',
		Default = true
	})
	Mute = PlayEmote:CreateToggle({
		Name = 'Mute',
		Function = function(callback)
			if PlayEmote.Enabled then
				mute(callback)
			end
		end,
		Tooltip = 'Silences emote sounds on your side'
	})
end)

run(function()
	local StreamerMode
	local NameBox
	local restored = setmetatable({}, {__mode = 'k'})
	local hooked = setmetatable({}, {__mode = 'k'})
	local textClasses = {TextLabel = true, TextButton = true, TextBox = true}
	local needles = {}
	local minLength = math.huge
	local alias = 'hidden'
	local writing
	local playerClass
	local savedUsername, savedDisplay, savedTag, savedLevel
	local queued = false

	local function readAlias()
		local value = NameBox and NameBox.Value
		if type(value) == 'string' and value ~= '' then
			return value
		end
		return 'hidden'
	end

	local function buildNeedles()
		table.clear(needles)
		minLength = math.huge
		local seen = {}
		for _, name in {lplr.Name, lplr.DisplayName} do
			if type(name) == 'string' and name ~= '' and not seen[name] then
				seen[name] = true
				minLength = math.min(minLength, #name)
				table.insert(needles, {
					plain = name:lower(),
					forms = {name, name:lower(), name:upper()}
				})
			end
		end
	end

	local function maskText(text)
		local out = text
		for _, needle in needles do
			for _, form in needle.forms do
				if form ~= '' and out:find(form, 1, true) then
					out = out:gsub((form:gsub('%W', '%%%0')), alias)
				end
			end
		end
		return out
	end

	local function keepText(object, value)
		writing = object
		object.Text = value
		writing = nil
	end

	local function watchText(object, apply)
		if hooked[object] then return end
		hooked[object] = object:GetPropertyChangedSignal('Text'):Connect(apply)
	end

	local function nearbyName(object)
		local parent = object.Parent
		for _ = 1, 3 do
			if not parent then return nil end
			local label = parent:FindFirstChild('PlayerName', true)
			if label then return label end
			parent = parent.Parent
		end
		return nil
	end

	local function blankLevel(object)
		if writing == object or not textClasses[object.ClassName] then return end
		if not object.Name:lower():find('level', 1, true) then return end
		local owner = nearbyName(object)
		if not owner or not owner.Text:find(alias, 1, true) then return end

		local function apply()
			if writing == object or not object.Parent then return end
			local text = object.Text
			if type(text) ~= 'string' or text == '' then return end
			if restored[object] == nil then
				restored[object] = text
			end
			keepText(object, '')
		end

		apply()
		watchText(object, apply)
	end

	local function sweepLevels(object)
		if not object then return end
		for _, child in object:GetDescendants() do
			blankLevel(child)
		end
	end

	local function maskObject(object)
		if not textClasses[object.ClassName] then return end

		local function apply()
			if writing == object or not object.Parent then return end
			local text = object.Text
			if type(text) ~= 'string' or #text < minLength then return end

			local lower = text:lower()
			local found = false
			for _, needle in needles do
				if lower:find(needle.plain, 1, true) then
					found = true
					break
				end
			end
			if not found then return end

			local masked = maskText(text)
			if masked == text then return end

			if restored[object] == nil then
				restored[object] = text
			end
			keepText(object, masked)
			watchText(object, apply)
			sweepLevels(object.Parent)
		end

		apply()
	end

	local function sweep(root)
		if not root then return end
		if vape.ThreadFix and setthreadidentity then
			pcall(setthreadidentity, 8)
		end

		StreamerMode:Clean(root.DescendantAdded:Connect(function(object)
			if not StreamerMode.Enabled then return end
			maskObject(object)
			blankLevel(object)
		end))

		local clock = os.clock()
		for _, object in root:GetDescendants() do
			maskObject(object)
			blankLevel(object)
			if os.clock() - clock > 0.002 then
				task.wait()
				if not StreamerMode.Enabled then return end
				clock = os.clock()
				if vape.ThreadFix and setthreadidentity then
					pcall(setthreadidentity, 8)
				end
			end
		end
	end

	local function findPlayerClass()
		if playerClass then return playerClass end
		pcall(function()
			local util = bedwars.GamePlayerUtil
			if not util then
				for _, module in replicatedStorage.TS:GetDescendants() do
					if module:IsA('ModuleScript') and module.Name:lower():find('game%-player%-util') then
						local ok, res = pcall(require, module)
						if ok and type(res) == 'table' and type(res.GamePlayerUtil) == 'table' then
							util = res.GamePlayerUtil
							break
						end
					end
				end
			end
			local holder = util and util.getGamePlayer and util.getGamePlayer(lplr)
			local meta = holder and getmetatable(holder)
			playerClass = meta and meta.__index or nil
		end)
		return playerClass
	end

	local function isMe(holder)
		local ok, player = pcall(function()
			return holder:getPlayer()
		end)
		return ok and player ~= nil and player.UserId == lplr.UserId
	end

	local function hookClass()
		local class = findPlayerClass()
		if not class or savedUsername then return end

		savedUsername, savedDisplay = class.getUsername, class.getDisplayName
		savedTag, savedLevel = class.getClanTag, class.getLevel

		class.getUsername = function(self, ...)
			return isMe(self) and alias or savedUsername(self, ...)
		end
		class.getDisplayName = function(self, ...)
			return isMe(self) and alias or savedDisplay(self, ...)
		end
		class.getClanTag = function(self, ...)
			return isMe(self) and '' or savedTag(self, ...)
		end
		class.getLevel = function(self, ...)
			return isMe(self) and -1 or savedLevel(self, ...)
		end
	end

	local function unhookClass()
		local class = playerClass
		if not class or not savedUsername then return end
		class.getUsername, class.getDisplayName = savedUsername, savedDisplay
		class.getClanTag, class.getLevel = savedTag, savedLevel
		savedUsername, savedDisplay, savedTag, savedLevel = nil, nil, nil, nil
	end

	local function reload()
		if queued or not StreamerMode or not StreamerMode.Enabled then return end
		queued = true
		task.delay(0.3, function()
			queued = false
			if StreamerMode.Enabled then
				StreamerMode:Toggle()
				StreamerMode:Toggle()
			end
		end)
	end

	StreamerMode = vape.Categories.Render:CreateModule({
		Name = 'StreamerMode',
		Function = function(callback)
			if callback then
				buildNeedles()
				alias = readAlias()
				for _, needle in needles do
					for _, form in needle.forms do
						if form ~= '' and alias:find(form, 1, true) then
							alias = 'hidden'
						end
					end
				end

				hookClass()

				for _, root in {lplr:FindFirstChildOfClass('PlayerGui'), cloneref(game:GetService('CoreGui')), gethui and gethui() or nil, lplr.Character} do
					sweep(root)
				end

				StreamerMode:Clean(lplr.CharacterAdded:Connect(function(char)
					if StreamerMode.Enabled then
						sweep(char)
					end
				end))
			else
				unhookClass()

				if vape.ThreadFix and setthreadidentity then
					pcall(setthreadidentity, 8)
				end

				for object, conn in hooked do
					pcall(function()
						conn:Disconnect()
					end)
				end
				table.clear(hooked)

				for object, text in restored do
					if object.Parent then
						keepText(object, text)
					end
				end
				writing = nil
				table.clear(restored)
			end
		end,
		Tooltip = 'changes ur name everywhere on ur screen so u can screenshare and etc without leaking it',
		ExtraText = function()
			return readAlias()
		end
	})

	NameBox = StreamerMode:CreateTextBox({
		Name = 'name',
		Default = 'motion is some ass gng',
		Placeholder = 'type a name...',
		Function = reload
	})
end)
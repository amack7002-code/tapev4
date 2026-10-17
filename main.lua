repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

local LOADER_URL = "https://raw.githubusercontent.com/amack7002-code/tapev4/main/downloader.lua" 
local _initArgs = ...
if type(_initArgs) ~= "table" then _initArgs = {} end
shared.aerov4User = "spookers 👻"

if identifyexecutor then
	if table.find({'Wave', 'Seliware', 'Volt'}, ({identifyexecutor()})[1]) then
		getgenv().setthreadidentity = nil
	end
end

local args = _initArgs
if type(args) == "table" and args.Closet then
	getgenv().Closet = true
else
	if getgenv().Closet == nil then
		getgenv().Closet = false
	end
end

local vape
local compile = loadstring
local loadstring = function(...)
	local res, err = compile(...)
	if err and vape then
		vape:CreateNotification('tape v4', 'Failed to load : '..err, 30, 'alert')
	end
	return res, err
end
local queue_on_teleport = queue_on_teleport or function() end
local clear_teleport_queue = clear_teleport_queue or clearteleportqueue or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end

if identifyexecutor and table.find({'Madium', 'Medium'}, ({identifyexecutor()})[1]) then
	local realgca = getcustomasset or getsynasset
	if realgca then
		getgenv().getcustomasset = function(path, ...)
			local args = {...}
			local function try()
				if not isfile(path) then return nil end
				local ok, res = pcall(function() return realgca(path, table.unpack(args)) end)
				if ok and res and res ~= '' then return res end
				return nil
			end
			local res = try()
			if res then return res end
			for _ = 1, 60 do
				task.wait(0.05)
				res = try()
				if res then return res end
			end
			return 'rbxassetid://0'
		end
	end
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))
local httpService = cloneref(game:GetService('HttpService'))
local teleportService = cloneref(game:GetService('TeleportService'))

local function ensureParentFolders(path)
	local current = ''
	local parts = path:gsub('\\', '/'):split('/')
	for i = 1, #parts - 1 do
		local part = parts[i]
		if part ~= '' then
			current = current == '' and part or (current .. '/' .. part)
			if not isfolder(current) then
				makefolder(current)
			end
		end
	end
end

local function downloadFile(path, func, repositoryPath)
	if not isfile(path) then
		local res
		local success = false
		repositoryPath = repositoryPath or select(1, path:gsub('^aerov4/', ''))
		for attempt = 1, 3 do
			local suc, result = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/amack7002-code/tapev4/' .. readfile('aerov4/profiles/commit.txt') .. '/' .. repositoryPath, true)
			end)
			if suc and result ~= '404: Not Found' then
				res = result
				success = true
				break
			end
			task.wait(1)
		end
		if not success then
			error('Failed to download ' .. path .. ' after 3 attempts')
		end
		if path:find('%.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
		end
		ensureParentFolders(path)
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local WATERMARK_PREFIX = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'

local function stripWatermark(src)
	if src:sub(1, #WATERMARK_PREFIX) == WATERMARK_PREFIX then
		return src:sub(#WATERMARK_PREFIX + 1)
	end
	return src
end

local function fetchOptionalFile(localPath, repositoryPath)
	if isfile(localPath) then
		return readfile(localPath)
	end
	if shared.VapeDeveloper then
		return nil
	end
	repositoryPath = repositoryPath or select(1, localPath:gsub('^aerov4/', ''))
	for attempt = 1, 3 do
		local suc, result = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/amack7002-code/tapev4/' .. readfile('aerov4/profiles/commit.txt') .. '/' .. repositoryPath, true)
		end)
		if suc and type(result) == 'string' and result ~= '' then
			if result == '404: Not Found' or result:find('^404:') then
				return nil
			end
			if localPath:find('%.lua$') then
				result = WATERMARK_PREFIX .. result
			end
			ensureParentFolders(localPath)
			writefile(localPath, result)
			return result
		end
		task.wait(1)
	end
	return nil
end

local function compileGameSource(gameSrc, label, moduleEntries)
	local gameFunc, gameErr = loadstring(gameSrc, tostring(label))
	if gameFunc then
		return gameFunc
	end

	local ls = gameSrc:split('\n')
	local msg = gameErr and tostring(gameErr) or 'executor didnt say why'
	local n = tonumber(msg:match(':(%d+):'))
	local where = ''
	if moduleEntries then
		for _, entry in ipairs(moduleEntries) do
			local modFunc, modErr = loadstring(entry.source, entry.path)
			if not modFunc then
				where = '\nbroken module is ' .. entry.path .. ': ' .. tostring(modErr)
				break
			end
		end
	end
	if where == '' and not n then
		local starts = {1}
		for i = 2, #ls do
			if ls[i]:match('^run%(function%(%)') then
				table.insert(starts, i)
			end
		end
		for idx, s in starts do
			local e = (starts[idx + 1] or (#ls + 1)) - 1
			if not loadstring(table.concat(ls, '\n', s, e), 'check') then
				local name
				for i = s, e do
					name = ls[i]:match("Name = '([^']+)'")
					if name then break end
				end
				where = '\nbroken part is lines ' .. s .. ' to ' .. e .. (name and ' in ' .. name or '')
				break
			end
		end
		if where == '' then
			where = '\ncouldnt find the broken part, prob a missing end between 2 modules'
		end
	end
	local ctx = ''
	if n then
		local parts = {}
		for i = math.max(1, n - 3), math.min(#ls, n + 3) do
			table.insert(parts, (i == n and '>>> ' or '    ') .. i .. ': ' .. (ls[i] or ''):gsub('\r', ''))
		end
		ctx = '\n\naround here:\n' .. table.concat(parts, '\n')
	end
	error('[aerov4] syntax error in ' .. tostring(label) .. '\n' .. msg .. where .. ctx)
end

local function loadGameModules(gameId, ...)
	local gameFolder = 'aerov4/games/' .. tostring(gameId)
	local repoFolder = 'games/' .. tostring(gameId)
	local orderJson = fetchOptionalFile(gameFolder .. '/module-order.json', repoFolder .. '/module-order.json')

	if not orderJson and isfolder(gameFolder) and isfile(gameFolder .. '/base.lua') then
		local baseCheck = readfile(gameFolder .. '/base.lua')
		local discovered = {}
		for _, sub in ipairs(listfiles(gameFolder)) do
			if isfolder(sub) then
				for _, modFile in ipairs(listfiles(sub)) do
					local rel = modFile:gsub('\\', '/'):match('^' .. gameFolder .. '/(.+%.lua)$')
					if rel and rel ~= 'base.lua' and rel ~= 'main.lua' then
						table.insert(discovered, rel)
					end
				end
			end
		end
		table.sort(discovered)
		local markerCount = 0
		for _ in baseCheck:gmatch('%-%-%[%[AEROV4_GAME_MODULE_%d+%]%]') do
			markerCount += 1
		end
		if #discovered > 0 and #discovered == markerCount then
			orderJson = httpService:JSONEncode(discovered)
		end
	end

	if orderJson then
		local ok, moduleOrder = pcall(function()
			return httpService:JSONDecode(orderJson)
		end)
		if ok and type(moduleOrder) == 'table' then
			local baseSource = downloadFile(gameFolder .. '/base.lua', nil, repoFolder .. '/base.lua')
			local missingFiles = {}
			for _, relPath in ipairs(moduleOrder) do
				local localModPath = gameFolder .. '/' .. relPath
				if not isfile(localModPath) then
					table.insert(missingFiles, {
						localPath = localModPath,
						repoPath = repoFolder .. '/' .. relPath
					})
				end
			end

			if #missingFiles > 0 then
				local remaining = #missingFiles
				local downloadErr = nil
				local doneEvent = Instance.new('BindableEvent')
				for _, item in ipairs(missingFiles) do
					task.spawn(function()
						local suc, err = pcall(downloadFile, item.localPath, nil, item.repoPath)
						if not suc and not downloadErr then
							downloadErr = err
						end
						remaining -= 1
						if remaining == 0 then
							doneEvent:Fire()
						end
					end)
				end
				if remaining > 0 then
					doneEvent.Event:Wait()
				end
				doneEvent:Destroy()
				if downloadErr then
					error(downloadErr)
				end
			end

			local assembled = baseSource
			local moduleEntries = {}
			for idx, relPath in ipairs(moduleOrder) do
				local localModPath = gameFolder .. '/' .. relPath
				local modSource = stripWatermark(readfile(localModPath))
				table.insert(moduleEntries, {
					path = repoFolder .. '/' .. relPath,
					source = modSource
				})
				local marker = string.format('--[[AEROV4_GAME_MODULE_%03d]]', idx)
				local startPos, endPos = assembled:find(marker, 1, true)
				if startPos then
					assembled = assembled:sub(1, startPos - 1) .. modSource .. assembled:sub(endPos + 1)
				else
					assembled = assembled .. '\n' .. modSource
				end
			end

			local chunk = compileGameSource(assembled, repoFolder .. '/base.lua', moduleEntries)
			return chunk(...)
		end
	end

	local legacyFile = 'aerov4/games/' .. tostring(gameId) .. '.lua'
	local mainFile = gameFolder .. '/main.lua'
	local repoMain = repoFolder .. '/main.lua'

	if isfile(mainFile) then
		local chunk = compileGameSource(readfile(mainFile), repoMain)
		return chunk(...)
	elseif isfile(legacyFile) then
		local chunk = compileGameSource(readfile(legacyFile), repoMain)
		return chunk(...)
	else
		local src = fetchOptionalFile(mainFile, repoMain) or fetchOptionalFile(legacyFile, 'games/' .. tostring(gameId) .. '.lua')
		if src then
			local chunk = compileGameSource(src, repoMain)
			return chunk(...)
		end
	end
end

local function migrateProfiles()
	if isfile('aerov4/profiles/migrated_placeid.txt') then return end

	local oldId = tostring(game.GameId)
	local newId = tostring(game.PlaceId)

	if oldId == newId then
		pcall(writefile, 'aerov4/profiles/migrated_placeid.txt', 'done')
		return
	end

	local suffix = oldId .. '.txt'
	for _, path in ipairs(listfiles('aerov4/profiles')) do
		local name = path:gsub('\\', '/')
		if name:sub(-#suffix) == suffix then
			local newPath = name:sub(1, -#suffix - 1) .. newId .. '.txt'
			if not isfile(newPath) then
				pcall(function() writefile(newPath, readfile(path)) end)
			end
		end
	end

	if isfolder('aerov4/profiles/premade') then
		for _, path in ipairs(listfiles('aerov4/profiles/premade')) do
			local name = path:gsub('\\', '/')
			if name:sub(-#suffix) == suffix then
				local newPath = name:sub(1, -#suffix - 1) .. newId .. '.txt'
				if not isfile(newPath) then
					pcall(function() writefile(newPath, readfile(path)) end)
				end
			end
		end
	end

	pcall(writefile, 'aerov4/profiles/migrated_placeid.txt', 'done')
end

pcall(migrateProfiles)

local function finishLoading()
	vape.Init = nil
	if not vape.Load then
		warn('[aerov4] vape.Load is nil skipping load')
		return
	end
	vape:Load()
	vape:Clean(task.spawn(function()
		repeat
			pcall(vape.Save, vape)
			task.wait(10)
		until vape.Loaded == nil
	end))

	local function buildTeleportScript()
		if shared.VapeIndependent then return nil end

		local closetArg = getgenv().Closet and '({Closet=true})' or '()'
		local teleportScript = 'shared.vapereload = true\nloadstring(game:HttpGet("' .. LOADER_URL .. '", true), "loader")' .. closetArg

		if identifyexecutor and ({identifyexecutor()})[1] == 'Potassium' then
			teleportScript = 'task.wait(12)\n' .. teleportScript
		end
		if shared.VapeDeveloper then
			teleportScript = 'shared.VapeDeveloper = true\n' .. teleportScript
		end
		if shared.VapeCustomProfile then
			teleportScript = 'shared.VapeCustomProfile = "' .. shared.VapeCustomProfile .. '"\n' .. teleportScript
		end
		return teleportScript
	end

	local function queueTeleport()
		local teleportScript = buildTeleportScript()
		if not teleportScript then return end
		pcall(clear_teleport_queue)
		pcall(queue_on_teleport, teleportScript)
	end

	queueTeleport()

	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function(state)
		if state == Enum.TeleportState.Failed then return end
		pcall(function() vape:Save() end)
		queueTeleport()
	end))

	vape:Clean(function()
		pcall(clear_teleport_queue)
	end)

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
			vape:CreateNotification('[tape v4] Finished Loading', 'wsg ' .. shared.aerov4User .. ' ' .. (vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press ' .. table.concat(vape.Keybind, ' + '):upper() .. ' to open GUI'), 5)
		end
	end
end

if not isfile('aerov4/profiles/gui.txt') then
	writefile('aerov4/profiles/gui.txt', 'new')
end
local gui = readfile('aerov4/profiles/gui.txt')

if not isfolder('aerov4/assets/' .. gui) then
	makefolder('aerov4/assets/' .. gui)
end

local guiSource = downloadFile('aerov4/guis/' .. gui .. '.lua')
local guiFunc, guiErr = loadstring(guiSource, 'gui')
if not guiFunc then
	local errMsg = tostring(guiErr)
	local lineNum = errMsg:match(':(%d+):')
	local context = ''
	if lineNum then
		local n = tonumber(lineNum)
		local lines = guiSource:split('\n')
		local from = math.max(1, n - 2)
		local to   = math.min(#lines, n + 2)
		local parts = {}
		for i = from, to do
			local marker = i == n and '>>> ' or '    '
			table.insert(parts, marker .. i .. ': ' .. (lines[i] or ''))
		end
		context = '\n\nContext:\n' .. table.concat(parts, '\n')
	end
	error('[aerov4] syntax error in ' .. gui .. '.lua' .. '\n' .. errMsg .. context)
end
vape = guiFunc()
if not vape then
	error('[aerov4] GUI returned nil file may be corrupted try deleting aerov4/guis/' .. gui .. '.lua and reinjecting.')
end
if not vape.Load then
	if delfile then pcall(function() delfile('aerov4/guis/' .. gui .. '.lua') end) end
	error('[aerov4] gui file corrupted (missing load) reinject..')
end
if not vape.Init and not vape.Load then
	error('[aerov4] failed to initialize properly reinject to fix this bs')
end
shared.vape = vape
task.wait(0.1)

if getgenv().Closet then
	local LogService = cloneref(game:GetService('LogService'))
	local originals = {}
	local function hook(funcName)
		if typeof(getgenv()[funcName]) == 'function' then
			local original = hookfunction(getgenv()[funcName], function() end)
			originals[funcName] = original
		end
	end
	hook('print')
	hook('warn')
	hook('error')
	hook('info')
	pcall(function() LogService:ClearOutput() end)
	local conn = LogService.MessageOut:Connect(function()
		LogService:ClearOutput()
	end)
	getgenv()._vape_log_connection = conn
	getgenv()._vape_originals = originals
end

if not shared.VapeIndependent then
	loadGameModules('universal')
	local gameFileId = (game.GameId == 2619619496) and (game.PlaceId == 6872265039 and 6872265039 or 6872274481) or (game.GameId == 10516888336 and 10516888336 or game.PlaceId)
	loadGameModules(gameFileId, ...)
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end

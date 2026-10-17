local _args = ...
if type(_args) ~= "table" then _args = {} end

local isfile = isfile or function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file) writefile(file, '') end

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/amack7002-code/tapev4/'..readfile('aerov4/profiles/commit.txt')..'/'..select(1, path:gsub('aerov4/', '')), true)
		end)
		if not suc or res == '404: Not Found' then error(res) end
		if path:find('%.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('loader') then continue end
		if isfolder(file) then
			wipeFolder(file)
		elseif isfile(file) and (select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 or file:find('module%-order%.json$')) then
			delfile(file)
		end
	end
end

for _, folder in {'aerov4', 'aerov4/games', 'aerov4/profiles', 'aerov4/assets', 'aerov4/libraries', 'aerov4/guis'} do
	if not isfolder(folder) then makefolder(folder) end
end

if not isfile('aerov4/profiles/commit.txt') then
	writefile('aerov4/profiles/commit.txt', 'main')
end

local function getPremadeProfileId()
	return game.PlaceId == 6872265039 and game.PlaceId or game.GameId
end

local function hasPremadeProfiles(profileId)
	local folder = 'aerov4/profiles/premade'
	if not isfolder(folder) then return false end

	local suffix = tostring(profileId)
	for _, file in listfiles(folder) do
		local name = file:gsub('\\', '/'):match('([^/]+)$')
		local stem = name and name:match('^(.*)%.txt$')
		if stem and #stem > #suffix and stem:sub(-#suffix) == suffix then
			return true
		end
	end
	return false
end

local function downloadPremadeProfiles(commit)
	local httpService = game:GetService('HttpService')
	local folder = 'aerov4/profiles/premade'
	if not isfolder(folder) then
		makefolder(folder)
	end

	local success, response = pcall(function()
		return game:HttpGet('https://api.github.com/repos/amack7002-code/tapev4/contents/profiles/premade?ref=' .. commit)
	end)
	if not success or type(response) ~= 'string' then
		return false, tostring(response)
	end

	local ok, files = pcall(function() return httpService:JSONDecode(response) end)
	if not ok or type(files) ~= 'table' then
		return false, 'GitHub returned an invalid premade profile listing'
	end

	local profileId = tostring(getPremadeProfileId())
	local downloaded = 0
	local failed = 0
	for _, file in pairs(files) do
		if type(file) == 'table' and type(file.name) == 'string' and file.name:match('%.txt$') and type(file.download_url) == 'string' then
			local baseName = (file.name:match('^(.-)%.txt$') or file.name):gsub('%d+$', '')
			if baseName ~= '' then
				local filePath = folder .. '/' .. baseName .. profileId .. '.txt'
				local ds, contents = pcall(function() return game:HttpGet(file.download_url, true) end)
				if ds and type(contents) == 'string' and contents ~= '' and contents ~= '404: Not Found' then
					local wrote, writeErr = pcall(writefile, filePath, contents)
					if wrote then
						downloaded += 1
					else
						failed += 1
						warn('[aerov4] failed to save premade profile ' .. filePath .. ': ' .. tostring(writeErr))
					end
				else
					failed += 1
					warn('[aerov4] failed to fetch premade profile ' .. file.name .. ': ' .. tostring(contents))
				end
			end
		end
	end

	if downloaded == 0 or failed > 0 then
		return false, string.format('downloaded %d profiles; %d failed', downloaded, failed)
	end
	return true, downloaded
end

if not shared.VapeDeveloper then
	local commit = isfile('aerov4/profiles/commit.txt') and readfile('aerov4/profiles/commit.txt') or ''
	local latest = isfile('aerov4/profiles/latest.txt') and readfile('aerov4/profiles/latest.txt') or ''
	if #commit ~= 40 then
		local ok, res = pcall(function()
			return game:HttpGet('https://api.github.com/repos/amack7002-code/tapev4/commits/main', true)
		end)
		if ok and res then
			local h = res:match('"sha":"([a-f0-9]+)"')
			if h and #h == 40 then commit = h end
		end
		if #commit ~= 40 then commit = 'main' end
		latest = commit
		pcall(writefile, 'aerov4/profiles/latest.txt', latest)
	elseif #latest == 40 and latest ~= commit then
		commit = latest
	end
	task.spawn(function()
		local ok, res = pcall(function()
			return game:HttpGet('https://api.github.com/repos/amack7002-code/tapev4/commits/main', true)
		end)
		if ok and res then
			local h = res:match('"sha":"([a-f0-9]+)"')
			if h and #h == 40 then
				pcall(writefile, 'aerov4/profiles/latest.txt', h)
			end
		end
	end)
	if commit ~= 'main' and (isfile('aerov4/profiles/commit.txt') and readfile('aerov4/profiles/commit.txt') or '') ~= commit then
		wipeFolder('aerov4')
		wipeFolder('aerov4/games')
		wipeFolder('aerov4/guis')
		pcall(function() if isfile('aerov4/guis/new.lua') then delfile('aerov4/guis/new.lua') end end)
		wipeFolder('aerov4/libraries')
	end
	local oldCommit = isfile('aerov4/profiles/commit.txt') and readfile('aerov4/profiles/commit.txt') or ''
	writefile('aerov4/profiles/commit.txt', commit)
	local profileId = tostring(getPremadeProfileId())
	local profileMarker = 'aerov4/profiles/premade_' .. profileId .. '.commit'
	local premadesAreCurrent = isfile(profileMarker) and readfile(profileMarker) == commit and hasPremadeProfiles(profileId)
	if not premadesAreCurrent then
		local ok, downloaded, countOrErr = pcall(downloadPremadeProfiles, commit)
		if ok and downloaded then
			pcall(writefile, profileMarker, commit)
		else
			local reason = ok and countOrErr or downloaded
			warn('[aerov4] failed to download premade profiles: ' .. tostring(reason))
		end
	end
end

local mainSource = downloadFile('aerov4/main.lua')
local mainChunk, mainErr = loadstring(mainSource, 'main')
if not mainChunk then
	error('[aerov4] failed to compile main.lua: ' .. tostring(mainErr))
end

return mainChunk({
	Closet = _args.Closet,
})

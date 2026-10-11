local gameScriptId = 8768229691
local gameScriptPath = 'aerov4/games/'..gameScriptId..'.lua'
local isfile = isfile or function(path)
	local ok, contents = pcall(function()
		return readfile(path)
	end)
	return ok and contents ~= nil and contents ~= ''
end

local function compileGameScript(source)
	local chunk, err = loadstring(source, 'skywars')
	if not chunk then
		error('Failed to compile game script '..gameScriptId..': '..tostring(err))
	end
	return chunk()
end

if isfile(gameScriptPath) then
	return compileGameScript(readfile(gameScriptPath))
end

if shared.VapeDeveloper then
	error('Missing local game script: '..gameScriptPath)
end

local commit = readfile('aerov4/profiles/commit.txt')
local source
for attempt = 1, 3 do
	local ok, result = pcall(function()
		return game:HttpGet('https://raw.githubusercontent.com/amack7002-code/tapev4/'..commit..'/games/'..gameScriptId..'.lua', true)
	end)
	if ok and result and result ~= '404: Not Found' then
		source = result
		break
	end
	task.wait(1)
end

if not source then
	error('Failed to download game script '..gameScriptId..' from tapev4 commit '..commit)
end

writefile(gameScriptPath, '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..source)
return compileGameScript(readfile(gameScriptPath))

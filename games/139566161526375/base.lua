--bridge duels
local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local collectionService = cloneref(game:GetService('CollectionService'))
local runService = cloneref(game:GetService('RunService'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local prediction = vape.Libraries.prediction

local bd = {}
local store = {
	blocks = {},
	serverBlocks = {}
}

local function getTool()
	return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function parsePositions(v, func)
	if v:IsA('Part') then
		local start = -(v.Size / 2) + Vector3.new(1.5, 1.5, 1.5)
		for x = 0, v.Size.X - 1, 3 do
			for y = 0, v.Size.Y - 1, 3 do
				for z = 0, v.Size.Z - 1, 3 do
					local vec = start + Vector3.new(x, y, z)
					vec = v.CFrame:PointToWorldSpace(vec)
					vec = Vector3.new(math.round(vec.X), math.round(vec.Y), math.round(vec.Z))
					func(vec)
				end
			end
		end
	end
end

--[[AEROV4_GAME_MODULE_001]]

for _, v in {'Reach', 'SilentAim', 'Disabler', 'HitBoxes', 'MurderMystery', 'AutoRejoin'} do
	vape:Remove(v)
end


--[[AEROV4_GAME_MODULE_002]]

--[[AEROV4_GAME_MODULE_003]]

--[[AEROV4_GAME_MODULE_004]]

--[[AEROV4_GAME_MODULE_005]]

--[[AEROV4_GAME_MODULE_006]]

--[[AEROV4_GAME_MODULE_007]]

--[[AEROV4_GAME_MODULE_008]]

--[[AEROV4_GAME_MODULE_009]]

--[[AEROV4_GAME_MODULE_010]]

--[[AEROV4_GAME_MODULE_011]]

--[[AEROV4_GAME_MODULE_012]]

--[[AEROV4_GAME_MODULE_013]]
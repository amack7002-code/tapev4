-- bedwars lobby

local run = function(func) func() end
local cloneref = cloneref or function(obj) return obj end
local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local runService = cloneref(game:GetService('RunService')) 
local httpService = cloneref(game:GetService('HttpService'))
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local sessioninfo = vape.Libraries.sessioninfo
local bedwars = {}

local function notif(...)
	return vape:CreateNotification(...)
end

--[[AEROV4_GAME_MODULE_001]]

for _, v in {'AntiRagdoll', 'TriggerBot', 'SilentAim', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'MouseTP', 'MurderMystery', 'NameTags', 'Killaura', 'AimAssist', 'AutoClicker', 'Reach', 'AntiFall', 'Fly', 'HitBoxes', 'LongJump', 'Speed', 'Swim', 'PlayerModel', 'Search', 'Waypoints', 'Blink', 'StaffDetector', ''} do
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

--[[AEROV4_GAME_MODULE_014]]

--[[AEROV4_GAME_MODULE_015]]

--[[AEROV4_GAME_MODULE_016]]

--[[AEROV4_GAME_MODULE_017]]

--[[AEROV4_GAME_MODULE_018]]

--[[AEROV4_GAME_MODULE_019]]

--[[AEROV4_GAME_MODULE_020]]

--[[AEROV4_GAME_MODULE_021]]

--[[AEROV4_GAME_MODULE_022]]

--[[AEROV4_GAME_MODULE_023]]

--[[AEROV4_GAME_MODULE_024]]

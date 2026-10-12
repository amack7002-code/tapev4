-- RIDE A PET

local run = function(func) func() end
local cloneref = cloneref or function(obj) return obj end
local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local runService = cloneref(game:GetService('RunService'))
local httpService = cloneref(game:GetService('HttpService'))
local virtualUser = cloneref(game:GetService('VirtualUser'))
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local sessioninfo = vape.Libraries.sessioninfo
local gameapi = {}

local function notif(...) return
	vape:CreateNotification(...)
end

for _, v in {'PlayerModel','AimAssist', 'Search', 'Waypoints', 'StaffDetector', 'AutoClicker', 'Reach', 'Disabler', 'MurderMystery', 'Killaura', 'TriggerBot', 'SilentAim', 'Gravity', 'Parkour', 'LongJump', 'HitBoxes', 'TargetStrafe' } do
    vape:Remove(v)
end

local function parseLuck(text)
    text = tostring(text or ''):lower():gsub('%s+', ''):gsub(',', '')

    local number = tonumber(text:match('[%d%.]+'))

    if not number then
        return 0
    end

    local suffix = text:match('[kmbt]')

    if suffix == 'k' then
        number *= 1e3
    elseif suffix == 'm' then
        number *= 1e6
    elseif suffix == 'b' then
        number *= 1e9
    elseif suffix == 't' then
        number *= 1e12
    end

    return number
end

--[[AEROV4_GAME_MODULE_001]]

--[[AEROV4_GAME_MODULE_002]]

--[[AEROV4_GAME_MODULE_003]]

--[[AEROV4_GAME_MODULE_004]]

--[[AEROV4_GAME_MODULE_005]]

--[[AEROV4_GAME_MODULE_006]]

--[[AEROV4_GAME_MODULE_007]]

--[[AEROV4_GAME_MODULE_008]]

--[[AEROV4_GAME_MODULE_009]]
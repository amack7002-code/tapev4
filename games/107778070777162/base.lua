-- STEAL AN EGG

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
local gameapi = {}

local function notif(...)
	return vape:CreateNotification(...)
end

for _, v in {'PlayerModel','AimAssist', 'Search', 'Waypoints', 'StaffDetector', 'AutoClicker', 'Reach', 'Disabler', 'MurderMystery', 'Killaura', 'TriggerBot', 'SilentAim', 'Gravity', 'Parkour', 'LongJump', 'HitBoxes', 'TargetStrafe' } do
	vape:Remove(v)
end

local packages = replicatedStorage:FindFirstChild('Packages')
local networking = packages and packages:FindFirstChild('Networking')
local clientFolder = replicatedStorage:FindFirstChild('Client')
local toolGuard = clientFolder and require(clientFolder:FindFirstChild('ToolGameplayGuard'))
local batSwingRemote = networking and networking:FindFirstChild('RE/BatSwing/Trigger')
local rigSyncRemote = networking and networking:FindFirstChild('RE/RigSync/Refresh')
local Save = require(replicatedStorage.Shared.Save)
local Remotes = require(replicatedStorage.Shared.Remotes)
local Treadmills = require(replicatedStorage.Data.Treadmills)
local EggState = require(replicatedStorage.Client.EggState)
local EggToolDisplay = require(replicatedStorage.Shared.Eggs.EggToolDisplay)
local PlotState = require(replicatedStorage.Client.PlotState)
local Assets = require(replicatedStorage.Data.Assets)
local AssetItems = require(replicatedStorage.Shared.Util.AssetItems)
local AssetEarnings = require(replicatedStorage.Shared.Util.AssetEarnings)
local carryState = {carrying = false}

local function createSeed()
	return ('%*:%*:%*'):format(lplr.UserId, 100, math.floor(workspace:GetServerTimeNow() * 1000))
end

local function canUseTool()
	local char = lplr.Character
	if not char then
		return false
	end
	local tool = char:FindFirstChildOfClass('Tool')
	if not tool or tool:GetAttribute('ItemType') ~= 'Gear' then
		return false
	end
	local hrp = char:FindFirstChild('HumanoidRootPart')
	if not hrp then
		return false
	end
	if not toolGuard or not toolGuard.IsLocalInsideArena() then
		return false
	end
	if workspace:GetAttribute('Event_MonsterEvent') then
		return hrp.Position.Z > -268
	end
	return true
end

local function getClosestPlayer()
	local closest = nil
	local closestDist = math.huge
	for _, p in playersService:GetPlayers() do
		if p ~= lplr then
			local char = p.Character
			local hrp = char and char:FindFirstChild('HumanoidRootPart')
			if hrp then
				local dist = lplr:DistanceFromCharacter(hrp.Position)
				if dist < closestDist and dist <= 16.5 then
					closestDist = dist
					closest = p
				end
			end
		end
	end
	return closest
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

--[[AEROV4_GAME_MODULE_010]]

--[[AEROV4_GAME_MODULE_011]]
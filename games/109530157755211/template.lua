-- LIFT A CUBE

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
local bridgenet2 = require(replicatedStorage.Packages.bridgenet2)
local liftingRaw = require(replicatedStorage.Schematics.Lifting)
local liftingLib = require(replicatedStorage.Modules.Lifting)
local cubeRollLib = require(replicatedStorage.Modules.CubeRoll)
local armsSchematic = require(replicatedStorage.Schematics.Arms)
local speedSchematic = require(replicatedStorage.Schematics.SpeedUpgrades)
local materialsSchematic = require(replicatedStorage.Schematics.Materials)
local cleanId = (tostring(lplr.UserId)):gsub('-', '')
local bridges = {
	Training = bridgenet2.ReferenceBridge(cleanId..'_Training'),
	Cubes = bridgenet2.ReferenceBridge(cleanId..'_Cubes'),
	Pops = bridgenet2.ReferenceBridge(cleanId..'_Pops'),
	GroupReward = bridgenet2.ReferenceBridge(cleanId..'_GroupReward'),
	AFK = bridgenet2.ReferenceBridge(cleanId..'_AFK')
}
local cachedControllers = nil
local function getControllers()
	if cachedControllers then
		return cachedControllers
	end
	if getgc then
		for _, obj in getgc(true) do
			if type(obj) == 'table' and rawget(obj, 'name') == 'Cubes' and rawget(obj, 'controllers') then
				cachedControllers = obj.controllers
				return cachedControllers
			end
		end
	end
	return nil
end

local function notif(...)
	return vape:CreateNotification(...)
end

for _, v in {'PlayerModel','AimAssist', 'Search', 'Waypoints', 'StaffDetector', 'AutoClicker', 'Reach', 'Disabler', 'MurderMystery', 'Killaura', 'TriggerBot', 'SilentAim', 'Gravity', 'Parkour', 'LongJump', 'HitBoxes', 'TargetStrafe' } do
	vape:Remove(v)
end

local function getStrength()
	return lplr:GetAttribute('Strength') or 0
end

local function getCash()
	return lplr:GetAttribute('Cash') or 0
end

local function getEquippedArms()
	return lplr:GetAttribute('EquippedArms') or 0
end

local function getCubesFolder()
	local folder = workspace:FindFirstChild('World')
	folder = folder and folder:FindFirstChild('Shared')
	folder = folder and folder:FindFirstChild('Cubes')
	return folder
end

local function getBestLiftableCube()
	local str = getStrength()
	local cubesFolder = getCubesFolder()
	if not cubesFolder then
		return 1
	end
	local best = 1
	for i = 1, #cubesFolder:GetChildren() do
		local scale = cubeRollLib.Scale(cubesFolder, i)
		local mass = cubeRollLib.Mass(i, scale)
		if liftingLib.Possible(str, mass) then
			local minTime = liftingLib.MinimumTime(str, mass)
			if minTime <= 1.5 then
				best = i
			end
		end
	end
	return best
end

local function ensureTrainToolEquipped()
	local char = lplr.Character
	if not char then
		return false
	end
	local hum = char:FindFirstChildOfClass('Humanoid')
	if not hum or hum.Health <= 0 then
		return false
	end
	local toolInChar = char:FindFirstChild('Train')
	if toolInChar then
		local ctrl = getControllers()
		if ctrl and ctrl.Training and not ctrl.Training.locked then
			ctrl.Training:SetLocked(true)
		end
		return true
	end
	local backpack = lplr:FindFirstChildOfClass('Backpack')
	local toolInBp = backpack and backpack:FindFirstChild('Train')
	if toolInBp then
		toolInBp.Parent = char
		local ctrl = getControllers()
		if ctrl and ctrl.Training then
			ctrl.Training:SetLocked(true)
		end
		return true
	end
	return false
end

--[[AEROV4_GAME_MODULE_001]]

--[[AEROV4_GAME_MODULE_002]]

--[[AEROV4_GAME_MODULE_003]]

--[[AEROV4_GAME_MODULE_004]]

--[[AEROV4_GAME_MODULE_005]]

--[[AEROV4_GAME_MODULE_006]]

--[[AEROV4_GAME_MODULE_007]]
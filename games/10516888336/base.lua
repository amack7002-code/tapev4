-- 1 BILLION DUCKS

local run = function(func)
	local ok, err = pcall(func)
	if not ok then
		warn('[aerov4] module failed: '..tostring(err))
	end
end
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

local umePointer = replicatedStorage:WaitForChild('UmePointer', 10)
local UmeValue = umePointer and umePointer.Value and require(umePointer.Value)
local Network = UmeValue and UmeValue.Network

local function fireNetwork(name, ...)
	if Network and Network.Fire then
		Network.Fire(name, nil, ...)
	end
end

local function getClosestDuck(hrp)
	local umeFolder = workspace:FindFirstChild('Ume')
	if not umeFolder then
		return nil
	end
	local closest = nil
	local closestPart = nil
	local closestDist = math.huge
	for _, duck in umeFolder:GetChildren() do
		if duck:IsA('Model') and duck.Name:match('^DuckController_Client_') then
			local part = duck.PrimaryPart
			if not part then
				for _, desc in duck:GetDescendants() do
					if desc:IsA('BasePart') then
						part = desc
						break
					end
				end
			end
			if part then
				local dist = (part.Position - hrp.Position).Magnitude
				if dist < closestDist then
					closestDist = dist
					closest = duck
					closestPart = part
				end
			end
		end
	end
	return closest, closestPart
end

for _, v in {'PlayerModel','AimAssist', 'Search', 'Waypoints', 'StaffDetector', 'AutoClicker', 'Reach', 'Disabler', 'MurderMystery', 'Killaura', 'TriggerBot', 'SilentAim', 'Gravity', 'Parkour', 'LongJump', 'HitBoxes', 'TargetStrafe'} do
	vape:Remove(v)
end

--[[AEROV4_GAME_MODULE_001]]

--[[AEROV4_GAME_MODULE_002]]
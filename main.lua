--TODO TESTING:add birthright, wait a frame, get stats, then remove birthright
--TODO TESTING: savegame_reader
---TODO:HUD customization
local mod = RegisterMod("Tainted Lazarus Alt Stats", 1)

local json = require("json")

mod.initialized = false

---@return boolean
function mod:shouldDeHook()
	local reqs = {
		not mod.initialized,
		not Game():GetHUD():IsVisible(),
		Game():GetLevel():GetAbsoluteStage() == LevelStage.STAGE8, -- Home for Dogma/Beast
		Game():GetSeeds():HasSeedEffect(SeedEffect.SEED_NO_HUD),
		(Game():GetNumPlayers() > 1 and not mod.storage.hasBirthright) or (Game():GetNumPlayers() > 2 and mod.storage.hasBirthright),
		(Isaac.GetPlayer(0):GetPlayerType() ~= PlayerType.PLAYER_LAZARUS_B) and (Isaac.GetPlayer(0):GetPlayerType() ~= PlayerType.PLAYER_LAZARUS2_B),
	}
	return reqs[1] or reqs[2] or reqs[3] or reqs[4] or reqs[5] or reqs[6]
end

function mod:exit()
	mod:SaveData(json.encode(mod.storage))
	mod.initialized = false
	if(mod:shouldDeHook()) then
		return
	end
end

function mod:drawStatStrings(altChar)
	local textCoords = mod.topCoord + Game().ScreenShakeOffset
	mod.font:DrawString(string.format(mod.format, altChar.speed), textCoords.X + 37, textCoords.Y + 1, KColor(1, 1, 1, mod.fontAlpha), 0, true)
	mod.font:DrawString(string.format(mod.format, altChar.tears), textCoords.X + 37, textCoords.Y + 1 + mod.spacingInterval.Y, KColor(1, 1, 1, mod.fontAlpha), 0, true)
	mod.font:DrawString(string.format(mod.format, altChar.damage), textCoords.X + 37, textCoords.Y + 1 + mod.spacingInterval.Y * 2, KColor(1, 1, 1, mod.fontAlpha), 0, true)
	mod.font:DrawString(string.format(mod.format, altChar.range), textCoords.X + 37, textCoords.Y + 1 + mod.spacingInterval.Y * 3, KColor(1, 1, 1, mod.fontAlpha), 0, true)
	mod.font:DrawString(string.format(mod.format, altChar.shotspeed), textCoords.X + 37, textCoords.Y + 1 + mod.spacingInterval.Y * 4, KColor(1, 1, 1, mod.fontAlpha), 0, true)
	mod.font:DrawString(string.format(mod.format, altChar.luck), textCoords.X + 37, textCoords.Y + 1 + mod.spacingInterval.Y * 5, KColor(1, 1, 1, mod.fontAlpha), 0, true)
end

function mod:updateCheck()
	local updatePos = false

	local activePlayers = Game():GetNumPlayers()

	for i = 0, activePlayers do
		local player = Isaac.GetPlayer(i)
		if(player.FrameCount == 0 or mod.playerTypeJustChanged) then
			updatePos = true
		end
	end

	if(mod.numplayers ~= activePlayers) then
		updatePos = true
		mod.numplayers = activePlayers
	end

	-- Certain seed effects block achievements
	if(mod.NumSeedEffects ~= Game():GetSeeds():CountSeedEffects()) then
		updatePos = true
		mod.NumSeedEffects = Game():GetSeeds():CountSeedEffects()
	end

	if(updatePos) then
		mod:updatePosition()
	end
end

---@param shaderName any
function mod:onRender(shaderName)
	if(mod:shouldDeHook()) then
		return
	end

	local isShader = shaderName == "UI_DisplayTaintedLazarusAltStats_DummyShader" and true or false

	if((not (Game():IsPaused() and Isaac.GetPlayer(0).ControlsEnabled)) and (not isShader)) then
		return -- no render when unpaused
	end
	if((Game():IsPaused() and Isaac.GetPlayer(0).ControlsEnabled) and isShader) then
		return -- no shader when paused
	end

	if((shaderName ~= nil) and (not isShader)) then
		return
	end

	mod:updateCheck()

	local playerMain = Isaac.GetPlayer(0)
	local playerMainType = playerMain:GetPlayerType()

	if(playerMainType == PlayerType.PLAYER_LAZARUS_B) then
		mod:drawStatStrings(mod.storage.taintedLazDead)
	elseif(playerMainType == PlayerType.PLAYER_LAZARUS2_B) then
		mod:drawStatStrings(mod.storage.taintedLazAlive)
	end
end

-- Written by Xalum
---@return boolean
function mod:CanRunUnlockAchievements()
	local machine = Isaac.Spawn(6, 11, 0, Vector.Zero, Vector.Zero, nil)
	local achievementsEnabled = machine:Exists()
	machine:Remove()

	return achievementsEnabled
end

function mod:updatePosition()
	mod.topCoord = Vector(0, 79.5)
	mod.spacingInterval = Vector(0, 12)

	-- Check for Hard Mode (icon), Seeded/Challenge (achievement disabled icon) or Daily (destination icon)
	if((Game().Difficulty == Difficulty.DIFFICULTY_HARD) or (Game():IsGreedMode()) or (not mod:CanRunUnlockAchievements())) then
		mod.topCoord = mod.topCoord + Vector(0, 16)
	end
end

-- See:https://stackoverflow.com/questions/18313171/lua-rounding-numbers-and-then-truncate
--- 100 for the 2 decimal places. Note: At exactly .5 it can go up or down randomly
---@param num integer
---@return number
function mod:round(num)
	return ((num * 100) + (2^52 + 2^51) - (2^52 + 2^51)) / 100
end

---@param range integer
---@return number
function mod:convertTearRange(range)
	return range / 40
end

---@param tears integer
---@return number
function mod:convertMaxFireDelay(tears)
	return 30 / (tears + 1)
end

---@param player EntityPlayer
---@return table
function mod:getStats(player)
	return {
		speed = mod:round(player.MoveSpeed),
		tears = mod:round(mod:convertMaxFireDelay(player.MaxFireDelay)),
		damage = mod:round(player.Damage),
		shotspeed = mod:round(player.ShotSpeed),
		range = mod:round(mod:convertTearRange(player.TearRange)),
		luck = mod:round(player.Luck)
	}
end

function mod:updateStats()
	local playerMain = Isaac.GetPlayer(0)
	local playerMainType = playerMain:GetPlayerType()
	local playerAlt = Isaac.GetPlayer(1)
	local playerAltType = playerAlt:GetPlayerType()

	if(not mod.lastPlayerType) then
		mod.lastPlayerType = playerMainType
	elseif(mod.lastPlayerType ~= playerMainType) then
		mod.playerTypeJustchanged = true;
		mod.lastPlayerType = playerMainType
	else
		mod.playerTypeJustchanged = false;
	end

	if((playerMainType ~= playerAltType) and (playerMain:GetCollectibleNum(CollectibleType.COLLECTIBLE_BIRTHRIGHT) == 1 or playerAlt:GetCollectibleNum(CollectibleType.COLLECTIBLE_BIRTHRIGHT)  == 1)) then
		mod.storage.hasBirthright = true
		mod.fontAlpha = 0.4
	else
		mod.storage.hasBirthright = false
		mod.fontAlpha = 0.2
	end

	if(playerMainType == PlayerType.PLAYER_LAZARUS_B) then
		mod.storage.taintedLazAlive = mod:getStats(playerMain)
		--[[if(playerAltType == PlayerType.PLAYER_LAZARUS2_B and mod.storage.hasBirthright) then
			mod.storage.taintedLazDead = mod:getStats(playerAlt) -- This sets the speeds to the same value since they actually are when playing, along with the reduced damage amount.
		end]]
	elseif(playerMainType == PlayerType.PLAYER_LAZARUS2_B) then
		mod.storage.taintedLazDead = mod:getStats(playerMain)
		--[[if(playerAltType == PlayerType.PLAYER_LAZARUS_B and mod.storage.hasBirthright) then
			mod.storage.taintedLazAlive = mod:getStats(playerAlt)
		end]]
	end
end

---@param isContinued boolean
function mod:init(isContinued)
	if(isContinued and mod:HasData()) then
		mod.storage = json.decode(mod:LoadData())
	else
		mod.storage = mod.defaultData
		mod:SaveData(json.encode(mod.storage))
	end

	mod.font = Font()
	mod.font:Load("font/luaminioutlined.fnt")
	mod.fontAlpha = 0.2

	mod:updateStats()
	mod:updatePosition()

	mod.initialized = true
end

function mod:initStore()
	mod.storage = {}
	mod.topCoord = Vector(0, 79.5)
	mod.format = "%.2f"
	mod.playerTypeJustchanged = false
	mod.defaultData = {
		lastPlayerType = nil,
		hasBirthright = false,
		taintedLazAlive = {
			speed = 1,
			tears = 2.73,
			damage = 3.5,
			shotspeed = 1,
			range = 4.5,
			luck = 0
		},
		taintedLazDead = {
			speed = .9,
			tears = 2.5,
			damage = 5.25,
			shotspeed = 1,
			range = 6.5,
			luck = -2
		}
	}
end

mod:initStore()

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.init)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.exit)

mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, mod.updateStats)

mod:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, mod.onRender)
mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.onRender)
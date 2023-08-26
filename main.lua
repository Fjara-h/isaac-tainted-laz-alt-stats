local json = require("json")

local MOD_NAME = "Tainted Lazarus Alt Stats"
local MOD_NAME_SHORT = "T.Laz Alt Stats"
local mod = RegisterMod(MOD_NAME, 1)
local MAJOR_VERSION = "2"
local MINOR_VERSION = "0"

local Transparencies = { 0.1, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.75, 0.8, 0.9, 1 }

mod.DefaultSettings = {
	stats = {
		display = true,
		x = 36,
		y = 80,
		xShift = 0,
		yShift = 16,
		interval = 12,
		scale = 1,
		alpha = 2,
		alphaBirthright = 4,
	},
}

mod.DefaultPlayerData = {
	hasBirthright = false,
	deadLaz = {
		stats = {
			speed = 0.9,
			tears = 2.5,
			damage = 5.25,
			range = 6.5,
			shotspeed = 1,
			luck = -2,
		}
	},
	aliveLaz = {
		stats = {
			speed = 1,
			tears = 2.73,
			damage = 3.5,
			range = 4.5,
			shotspeed = 1,
			luck = 0,
		},
	},
}

mod.font = Font()
mod.font:Load("font/luaminioutlined.fnt")
mod.format = "%.2f"
mod.statShift = Vector(0, 0)
mod.isTaintedLaz = false
mod.hasFlippedOnceSinceStart = false
mod.subPlayerHashMap = {}

-- Birthright: Speed and damage after card use will be wrong because they can't be stored beforehand, no PRE_CARD_USE callback, and they persist between flips until a new room
--- Calculations cannot be done based on the flipped or pre-flipped value because of a damage minimum and speed maximum that make it unreliable.

-- what if only do calcs if base dmg > 2 or speed < 2 and  on card use just check cards see if doing teh calc wil be right
--- will 200 damage be reduced to 50 and will be mean it is 200?

-- ClearTemporaryEffects on PreSpawnCleanReward callback does not work because flip occurs before

-- Iterate through tables and subtables to overwrite existing keys and add new keys
--- Also iterates through key-val pairs of tableTemplate (Defaults), storing keys only if they exist in the default and setting non-default keys to nil
---@param oldTable table
---@param newTable table
---@param tableTemplate table
function mod:tableMerge(oldTable, newTable, tableTemplate) --tableTemplate isn't being given the right values?
	for key, val in pairs(newTable) do
		if(type(val) == "table" and type(tableTemplate[key]) == "table") then
			oldTable[key] = mod:tableMerge(oldTable[key] or {}, newTable[key] or {}, tableTemplate[key] or {})
		elseif(val ~= nil and tableTemplate[key] ~= nil) then -- Existant, expected entries get overwritten
			oldTable[key] = newTable[key]
		elseif(val == nil and oldTable[key] == nil and tableTemplate[key] ~= nil) then -- Missing entries get default values
			oldTable[key] = tableTemplate[key]
		elseif(tableTemplate[key] == nil) then
			oldTable[key] = nil
		end
	end
	return oldTable
end

function mod:save()
	local jsonString = json.encode( { playerData = mod.playerData, settings = mod.settings } )
	mod:SaveData(jsonString)
end

---@param shouldSave boolean
function mod:onExit(shouldSave)
	mod.subPlayerHashMap = {}
	if(shouldSave and mod.isTaintedLaz) then
		mod:save()
	end
end

---@param player EntityPlayer
---@return boolean
function mod:isDeadTaintedLazarus(player)
	return (player:GetPlayerType() == PlayerType.PLAYER_LAZARUS2_B)
end

---@param player EntityPlayer
---@return boolean
function mod:isAliveTaintedLazarus(player)
	return (player:GetPlayerType() == PlayerType.PLAYER_LAZARUS_B)
end

---@param player EntityPlayer
function mod:setIsTaintedLazarus(player)
	mod.isTaintedLaz = (mod:isAliveTaintedLazarus(player) or mod:isDeadTaintedLazarus(player))
end

---@param tearRange integer
---@return number
function mod:convertTearRange(tearRange)
	return tearRange / 40
end

---@param maxFireDelay integer
---@return number
function mod:convertMaxFireDelay(maxFireDelay)
	return 30 / (maxFireDelay + 1)
end

-- See:https://stackoverflow.com/questions/18313171/lua-rounding-numbers-and-then-truncate
--- 100 for the 2 decimal places. Note: At exactly .5 it can go up or down randomly
---@param num integer
---@return number
function mod:round(num)
	return ((num * 100) + (2^52 + 2^51) - (2^52 + 2^51)) / 100
end

---@param player EntityPlayer
---@return table
function mod:updatePlayerStats(player)
	local stats = {}
	-- Only update speed and damage if neither Lazarus has birthright or if one does, only update the currently active Lazarus
	--- Speed for alt with birthright is temporarily set to the same speed as the active Lazarus
	--- Damage for alt with birthright is temporarily reduced to 25% and cannot be accurately calculated 
	---- Both of these values will be wrong for the next flip if the player uses a stat-up card with birthright
	if((mod.playerData.hasBirthright == false) or (mod.playerData.hasBirthright and Isaac.GetPlayer(0):GetPlayerType() == player:GetPlayerType())) then
		stats.speed = mod:round(player.MoveSpeed)
		stats.damage = mod:round(player.Damage)
	end
	stats.tears = mod:round(mod:convertMaxFireDelay(player.MaxFireDelay))
	stats.range = mod:round(mod:convertTearRange(player.TearRange))
	stats.shotspeed = mod:round(player.ShotSpeed)
	stats.luck = mod:round(player.Luck)
	return stats
end

function mod:updatePlayerData()
	local player = Isaac.GetPlayer(0)
	mod:setIsTaintedLazarus(player)
	if(not mod.isTaintedLaz) then
		return
	end
	local alt = mod:getTaintedLazarusSubPlayer(player)
	-- alt stats cannot be accessed prior to the first flip, instead use saved or default
	if(alt == nil or not mod.hasFlippedOnceSinceStart) then
		return
	end
	mod.playerData.hasBirthright = player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT, true) or alt:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT, true)
	local stats = mod:updatePlayerStats(player)
	local altstats = mod:updatePlayerStats(alt)

	if(mod:isAliveTaintedLazarus(player)) then
		mod.playerData.aliveLaz.stats = stats
		mod.playerData.deadLaz.stats = mod:tableMerge(mod.playerData.deadLaz.stats, altstats, mod.DefaultPlayerData.deadLaz.stats)
	elseif(mod:isDeadTaintedLazarus(player)) then
		mod.playerData.deadLaz.stats = stats
		mod.playerData.aliveLaz.stats = mod:tableMerge(mod.playerData.aliveLaz.stats, altstats, mod.DefaultPlayerData.aliveLaz.stats)
	end
end

function mod:renderStats()
	local statsToRender
	local player = Isaac.GetPlayer(0)
	if(mod:isAliveTaintedLazarus(player)) then
		statsToRender = mod.playerData.deadLaz.stats
	elseif(mod:isDeadTaintedLazarus(player)) then
		statsToRender = mod.playerData.aliveLaz.stats
	else
		return
	end
	local statCoordsX = mod.settings.stats.x - Game().ScreenShakeOffset.X + mod.statShift.X
	local statCoordsY = mod.settings.stats.y - Game().ScreenShakeOffset.Y + mod.statShift.Y
	local alpha = mod.playerData.hasBirthright and Transparencies[mod.settings.stats.alphaBirthright] or Transparencies[mod.settings.stats.alpha]
	mod.font:DrawStringScaled(string.format(mod.format, statsToRender.speed), statCoordsX, statCoordsY, mod.settings.stats.scale, mod.settings.stats.scale, KColor(1, 1, 1, alpha), 0, true)
	mod.font:DrawStringScaled(string.format(mod.format, statsToRender.tears), statCoordsX, statCoordsY + mod.settings.stats.interval, mod.settings.stats.scale, mod.settings.stats.scale, KColor(1, 1, 1, alpha), 0, true)
	mod.font:DrawStringScaled(string.format(mod.format, statsToRender.damage), statCoordsX, statCoordsY + mod.settings.stats.interval * 2, mod.settings.stats.scale, mod.settings.stats.scale, KColor(1, 1, 1, alpha), 0, true)
	mod.font:DrawStringScaled(string.format(mod.format, statsToRender.range), statCoordsX, statCoordsY + mod.settings.stats.interval * 3, mod.settings.stats.scale, mod.settings.stats.scale, KColor(1, 1, 1, alpha), 0, true)
	mod.font:DrawStringScaled(string.format(mod.format, statsToRender.shotspeed), statCoordsX, statCoordsY + mod.settings.stats.interval * 4, mod.settings.stats.scale, mod.settings.stats.scale, KColor(1, 1, 1, alpha), 0, true)
	mod.font:DrawStringScaled(string.format(mod.format, statsToRender.luck), statCoordsX, statCoordsY + mod.settings.stats.interval * 5, mod.settings.stats.scale, mod.settings.stats.scale, KColor(1, 1, 1, alpha), 0, true)
end

---@return boolean
function mod:isMultiplayer()
	local players = {}
	for i = 0, Game():GetNumPlayers() - 1, 1 do
		local player = Isaac.GetPlayer(i)
		players[#players + 1] = player
	end
	local controllerIndices = {}
	local indicesFound = {}
	for _, player in ipairs(players) do
		if(not indicesFound[player.ControllerIndex]) then
			controllerIndices[#controllerIndices + 1] = player.ControllerIndex
			indicesFound[player.ControllerIndex] = true
		end
	end
	return #controllerIndices > 1
end

---@return boolean
function mod:shouldRender()
	return (Game():GetHUD():IsVisible()) and (Game():GetLevel() ~= LevelStage.STAGE8) and (not Game():GetSeeds():HasSeedEffect(SeedEffect.SEED_NO_HUD)) and (not mod:isMultiplayer()) and (mod.isTaintedLaz)
end

function mod:postRender()
	if(mod:shouldRender() and mod.settings.stats.display) then
		mod:renderStats()
	end
end

---@param player EntityPlayer
---@return EntityPlayer
function mod:getTaintedLazarusSubPlayer(player)
	local ptrHash = GetPtrHash(player)
	return mod.subPlayerHashMap[ptrHash]
end

function mod:postPlayerUpdate()
	mod:updatePlayerData()
end

---@param player EntityPlayer
function mod:onFlip(_, __, player)
	-- After flipping once or starting with birthright, alt stats become initialized
	if(mod.isTaintedLaz and (mod.hasFlippedOnceSinceStart == false or mod.playerData.hasBirthright)) then
		mod.hasFlippedOnceSinceStart = true
	end
end

---@param player EntityPlayer
function mod:preFlip(_, __, player)
	if(mod.isTaintedLaz and not mod.playerData.hasBirthright) then
		player:ClearTemporaryEffects() -- Clears effects only for non-birthright becase they don't persist on flip
	end
	if(mod.hasFlippedOnceSinceStart and mod.isTaintedLaz and mod.playerData.hasBirthright) then
		if(mod:isAliveTaintedLazarus(player)) then
			mod.playerData.aliveLaz.stats.speed = player.MoveSpeed
			mod.playerData.aliveLaz.stats.damage = player.Damage
		elseif(mod:isDeadTaintedLazarus(player)) then
			mod.playerData.deadLaz.stats.speed = player.MoveSpeed
			mod.playerData.deadLaz.stats.damage = player.Damage
		end
	end
end

function mod:load()
	if(mod:HasData()) then
		local data = json.decode(mod:LoadData())
		mod.playerData = mod:tableMerge(mod.DefaultPlayerData, data.playerData, mod.DefaultPlayerData)
		mod.settings = mod:tableMerge(mod.DefaultSettings, data.settings, mod.DefaultSettings)
	end
	if(mod.playerData == nil) then
		mod.playerData = mod.DefaultPlayerData
	end
	if(mod.settings == nil) then
		mod.settings = mod.DefaultSettings
	end
end

-- This also covers victory laps
---@return boolean
function mod:canRunUnlockAchievements()
	local greedDonationMachine = Isaac.Spawn(EntityType.ENTITY_SLOT, 11, 0, Vector.Zero, Vector.Zero, nil)
	local canUnlockAchievements = greedDonationMachine:Exists()
	greedDonationMachine:Remove()
	return canUnlockAchievements
end

function mod:setStatShift()
	if((Game().Difficulty == Difficulty.DIFFICULTY_HARD) or (Game():IsGreedMode()) or (not mod:canRunUnlockAchievements())) then
		mod.statShift = Vector(mod.settings.stats.xShift, mod.settings.stats.yShift)
	else
		mod.statShift = Vector(0, 0)
	end
end

---@param isContinued boolean
function mod:postGameStarted(isContinued)
	if(not isContinued) then
		mod.playerData = mod.DefaultPlayerData
	end
	local player = Isaac.GetPlayer(0)
	mod:setStatShift()
	mod:setIsTaintedLazarus(player)
	mod.hasFlippedOnceSinceStart = false
end

local queuedTaintedLazarus = {}
local queuedDeadTaintedLazarus = {}

-- Check that this works, need to set onfirstflip 
---@param player EntityPlayer
function mod:onUseClicker(_, _, player)
	mod:taintedLazarusPlayers(player)
end

--There is MC_POST_PLAYER_INIT on start/continue for each verison of tainted lazarus
---@param player EntityPlayer
function mod:taintedLazarusPlayers(player)
	mod:setIsTaintedLazarus(player)
	if(not mod.isTaintedLaz) then
		return
	end
	if(mod:isAliveTaintedLazarus(player)) then
		queuedTaintedLazarus[#queuedTaintedLazarus + 1] = player
	elseif(mod:isDeadTaintedLazarus(player)) then
		queuedDeadTaintedLazarus[#queuedDeadTaintedLazarus + 1] = player
	else
		return
	end

    if((#queuedTaintedLazarus == 0) or (#queuedDeadTaintedLazarus == 0)) then
        return
    end
    local taintedLazarus = table.remove(queuedTaintedLazarus, 1)
    local deadTaintedLazarus = table.remove(queuedDeadTaintedLazarus, 1)
    if((taintedLazarus == nil) or (deadTaintedLazarus == nil)) then
        return
    end
    local taintedLazarusPtrHash = GetPtrHash(taintedLazarus)
    local deadTaintedLazarusPtrHash = GetPtrHash(deadTaintedLazarus)
    if(taintedLazarusPtrHash == deadTaintedLazarusPtrHash) then
        print("Failed to cache the Tainted Lazarus player objects, since the hash for Tainted Lazarus and Dead Tainted Lazarus were the same.")
        return
    end

    mod.subPlayerHashMap[taintedLazarusPtrHash] = deadTaintedLazarus
    mod.subPlayerHashMap[deadTaintedLazarusPtrHash] = taintedLazarus
end

mod:load()
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, mod.taintedLazarusPlayers)
mod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, mod.preFlip, CollectibleType.COLLECTIBLE_FLIP)
mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.onUseClicker, CollectibleType.COLLECTIBLE_CLICKER)
mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.onFlip, CollectibleType.COLLECTIBLE_FLIP)
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.postGameStarted)
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, mod.postPlayerUpdate)
mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.postRender)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onExit)

----MCM----
function mod:setupMyModConfigMenuSettings()
	if(ModConfigMenu == nil) then
	  return
	end
	----INFO----
	ModConfigMenu.AddSpace(MOD_NAME_SHORT, "Info")
	ModConfigMenu.AddText(MOD_NAME_SHORT, "Info", function() return MOD_NAME end)
	ModConfigMenu.AddSpace(MOD_NAME_SHORT, "Info")
	ModConfigMenu.AddText(MOD_NAME_SHORT, "Info", function() return "Version " .. MAJOR_VERSION .. '.' .. MINOR_VERSION end)
	----STATS----
	ModConfigMenu.AddSetting(
		MOD_NAME_SHORT,
		"Stats",
		{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function()
				return mod.settings.stats.display
			end,
			Display = function()
				return "Display stats: " .. (mod.settings.stats.display and "on" or "off")
			end,
			OnChange = function(b)
				mod.settings.stats.display = b
				mod:save()
			end,
			Info = { "Display non-active tainted lazarus stats on the screen." }
		}
	)
	ModConfigMenu.AddSetting(
		MOD_NAME_SHORT,
		"Stats",
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return mod.settings.stats.x
			end,
			Minimum = 0,
			Maximum = 500,
			ModifyBy = 1,
			Display = function()
				return "Position X: " .. mod.settings.stats.x
			end,
			OnChange = function(b)
				mod.settings.stats.x = b
				mod:save()
			end,
			Info = { "Default = " .. mod.DefaultSettings.stats.x }
		}
	)
	ModConfigMenu.AddSetting(
		MOD_NAME_SHORT,
		"Stats",
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return mod.settings.stats.y
			end,
			Minimum = 0,
			Maximum = 500,
			ModifyBy = 1,
			Display = function()
				return "Position Y: " .. mod.settings.stats.y
			end,
			OnChange = function(b)
				mod.settings.stats.y = b
				mod:save()
			end,
			Info = { "Default = " .. mod.DefaultSettings.stats.y }
		}
	)
	ModConfigMenu.AddSetting(
		MOD_NAME_SHORT,
		"Stats",
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return mod.settings.stats.xShift
			end,
			Minimum = 0,
			Maximum = 100,
			ModifyBy = 1,
			Display = function()
				return "Horizontal shift: " .. mod.settings.stats.xShift
			end,
			OnChange = function(b)
				mod.settings.stats.xShift = b
				mod:save()
				mod:setStatShift()
			end,
			Info = {
				"'X' position UI-shift for hard difficulty, greed mode, or non-achievment runs.",
				"Default = " .. mod.DefaultSettings.stats.xShift,
			}
		}
	)
	ModConfigMenu.AddSetting(
		MOD_NAME_SHORT,
		"Stats",
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return mod.settings.stats.yShift
			end,
			Minimum = 0,
			Maximum = 100,
			ModifyBy = 1,
			Display = function()
				return "Vertical shift: " .. mod.settings.stats.yShift
			end,
			OnChange = function(b)
				mod.settings.stats.yShift = b
				mod:save()
				mod:setStatShift()
			end,
			Info = {
				"'Y' position UI-shift for hard difficulty, greed mode, or non-achievment runs.",
				"Default = " .. mod.DefaultSettings.stats.yShift,
			}
		}
	)
	ModConfigMenu.AddSetting(
		MOD_NAME_SHORT,
		"Stats",
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return mod.settings.stats.interval
			end,
			Minimum = 0,
			Maximum = 500,
			ModifyBy = 1,
			Display = function()
				return "Vertical space between stats: " .. mod.settings.stats.interval
			end,
			OnChange = function(b)
				mod.settings.stats.interval = b
				mod:save()
			end,
			Info = {
				"Vertical space between stats.",
				"Default = " .. mod.DefaultSettings.stats.interval,
			}
		}
	)
	ModConfigMenu.AddSetting(
		MOD_NAME_SHORT,
		"Stats",
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return mod.settings.stats.scale
			end,
			Minimum = 0.5,
			Maximum = 2,
			ModifyBy = 0.25,
			Display = function()
				return "Scale: " .. mod.settings.stats.scale
			end,
			OnChange = function(b)
				mod.settings.stats.scale = b - (b % 0.25)
				mod:save()
			end,
			Info = { "Default = " .. mod.DefaultSettings.stats.scale}
		}
	)
	ModConfigMenu.AddSetting(
		MOD_NAME_SHORT,
		"Stats",
		{
			Type = ModConfigMenu.OptionType.SCROLL,
			CurrentSetting = function()
				return mod.settings.stats.alpha
			end,
			Display = function()
				return "Transparency: $scroll" .. mod.settings.stats.alpha
			end,
			OnChange = function(b)
				mod.settings.stats.alpha = b
				mod:save()
			end,
			Info = {
				"Transparency of stat numbers without birthright. Default = " .. mod.DefaultSettings.stats.alpha,
				"0.1, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.75, 0.8, 0.9, 1",
			}
		}
	)
	ModConfigMenu.AddSetting(
		MOD_NAME_SHORT,
		"Stats",
		{
			Type = ModConfigMenu.OptionType.SCROLL,
			CurrentSetting = function()
				return mod.settings.stats.alphaBirthright
			end,
			Display = function()
				return "Transparency: $scroll" .. mod.settings.stats.alphaBirthright
			end,
			OnChange = function(b)
				mod.settings.stats.alphaBirthright = b
				mod:save()
			end,
			Info = {
				"Transparency of stat numbers with birthright. Default = " .. mod.DefaultSettings.stats.alphaBirthright,
				"0.1, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.75, 0.8, 0.9, 1",
			}
		}
	)
end
mod:setupMyModConfigMenuSettings()

--I am in your walls
local classIndices_Internal = {
    [1] = "Scout",
    [3] = "Soldier",
    [7] = "Pyro",
    [4] = "Demoman",
    [6] = "Heavyweapons",
    [9] = "Engineer",
    [5] = "Medic",
    [2] = "Sniper",
    [8] = "Spy",
}

local DEATH_INSULTS = {
	Scout = {
		"Jumping won't save you, %s",
	},
	Soldier = {
		"Unbind your attack key, %s",
	},
	Pyro = {
		"Hey %s! Did you know that the airblast force upgrade makes you take 50%% more damage?",
	},
	Demoman = {
		"Try using your movement keys next time, %s",
	},
	Heavyweapons = {
		"Consider playing a more interesting class, %s",
	},
	Engineer = {
		"Build yourself better gamesense, %s",
	},
	Medic = {
		"How's that canteen spam going for you, %s?",
	},
	Sniper = {
		"Thanks for standing still, %s!",
	},
	Spy = {
		"I hate the french",
	}

}

local function chatMessage(string)
	local message = "{blue}"
	.. "Time-Constraint{reset} : "
	.. string

	local allPlayers = ents.GetAllPlayers()
	for _, player in pairs(allPlayers) do
		player:AcceptInput("$DisplayTextChat", message)
	end

end

local function hasTag(tags, tagToFind)
	for _, tag in pairs(tags) do
		print(tag)
		if tag == tagToFind then
			return true
		end
	end
end

local function removeCallbacks(bot, callbacks)
	for _, callbackId in pairs(callbacks) do
		bot:RemoveCallback(callbackId)
	end
end

local rollbacks = {}

local function storeRollback()
	rollbacks = {}
	local classes = {"player", "obj_*"}

	for _, class in pairs(classes) do
		for _, ent in pairs(ents.FindAllByClass(class)) do
			if not ent:IsCombatCharacter() then
				goto continue
			end

			if ent.m_iTeamNum ~= 2 then
				goto continue
			end

			rollbacks[ent] = {
				Origin = ent:GetAbsOrigin() + Vector(0, 0, 10),
				Angles = ent:GetAbsAngles()
			}

			::continue::
		end
	end
end

local function revertRollback()
	local fade = Entity("env_fade", true)
	local properties = {
		holdtime = 1,
		duration = 0.5,
		rendercolor = "255, 255, 255",
		renderamt = 255
	}

	for name, value in pairs(properties) do
		fade:AcceptInput("$SetKey$"..name, value)
	end

	fade.Fade(fade)

	timer.Simple(0.6, function ()
		for ent, data in pairs(rollbacks) do
			if not IsValid(ent) or not ent:IsAlive() then
				goto continue
			end
	
			ent:SetAbsOrigin(data.Origin)
			ent:SetAbsAngles(data.Angles)
	
			::continue::
		end
	end)
end

local playersCallback = {}

local function Holder(bot)
	local allPlayers = ents.GetAllPlayers()

	for _, player in pairs(allPlayers) do
		if not player:IsRealPlayer() then
			goto continue
		end

		playersCallback[player] = {}
	
		playersCallback[player].died = player:AddCallback(ON_DEATH, function ()
			if not bot:IsAlive() then
				return
			end

			local allInsults = DEATH_INSULTS[classIndices_Internal[player.m_iClass]]
			local chosenInsult = allInsults[math.random(#allInsults)]
			
			local name = player:GetPlayerName()
	
			chatMessage(string.format(chosenInsult, name))
		end)

		::continue::
	end

	
	local callbacks = {}

	storeRollback()

	callbacks.died = bot:AddCallback(ON_DEATH, function()
		removeCallbacks(bot, callbacks)

		for player, plrCallbacks in pairs(playersCallback) do
			removeCallbacks(player, plrCallbacks)
		end
	end)
	callbacks.spawned = bot:AddCallback(ON_SPAWN, function()
		removeCallbacks(bot, callbacks)

		for player, plrCallbacks in pairs(playersCallback) do
			removeCallbacks(player, plrCallbacks)
		end
	end)
end

local function Handle1(bot)
	local callbacks = {}

	storeRollback()

	callbacks.died = bot:AddCallback(ON_DEATH, function()
		timer.Simple(0.5, function ()
			chatMessage("That's not supposed to happen")
		end)

		timer.Simple(1.7, function ()
			chatMessage("Let's do that again")
		end)

		timer.Simple(3.5, function ()
			revertRollback()
		end)

		removeCallbacks(bot, callbacks)
	end)
	callbacks.spawned = bot:AddCallback(ON_SPAWN, function()
		removeCallbacks(bot, callbacks)
	end)
end

local function Handle2(bot)
	local callbacks = {}

	storeRollback()

	chatMessage("My chariot will carry me to victory")

	callbacks.died = bot:AddCallback(ON_DEATH, function()
		timer.Simple(0.5, function ()
			chatMessage("Fatal miscalculations were made")
		end)

		timer.Simple(1.7, function ()
			chatMessage("No matter, we can redo")
		end)

		timer.Simple(3.5, function ()
			revertRollback()
		end)

		removeCallbacks(bot, callbacks)
	end)
	callbacks.spawned = bot:AddCallback(ON_SPAWN, function()
		removeCallbacks(bot, callbacks)
	end)
end

function OnWaveSpawnBot(bot, _, tags)
	if hasTag(tags, "realcontraint") then
		Holder(bot)
		return
	end
	if hasTag(tags, "timeconstraint1") then
		Handle1(bot)
		return
	end
	if hasTag(tags, "timeconstraint2") then
		Handle2(bot)
		return
	end
end
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
		"Unequip the Fan-o-War, %s",
	},
	Soldier = {
		"Unbind your attack key, %s",
		"Don't buy rocket specialist next time, %s",
	},
	Pyro = {
		"Hey %s! Did you know that the airblast force upgrade makes you take 50%% more damage?",
		"Hey %s! Did you know that equipping the scorch shot makes you take 150%% more damage?",
		"Hey %s! Unbind your airblast key",
	},
	Demoman = {
		"Try using your movement keys next time, %s",
		"Are you actually drunk, %s? You're playing like you are",
	},
	Heavyweapons = {
		"Consider playing a more interesting class, %s",
		"I hope that got you to leave a negative review on the end-of-operation survey, %s",
	},
	Engineer = {
		"Build yourself better gamesense, %s",
		"Sentry blocking going well, aye %s?",
	},
	Medic = {
		"How's that canteen spam going for you, %s?",
		"Try idling more %s, maybe that will work",
	},
	Sniper = {
		"Thanks for standing still, %s!",
	},
	Spy = {
		"I hate the french",
	}

}

local timeconstraint_alive = false
local cur_constraint = false -- current time constraint bot

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
		if tag == tagToFind then
			return true
		end
	end
end

local function removeCallbacks(bot, callbacks)
	if not IsValid(bot) then
		return
	end

	for _, callbackId in pairs(callbacks) do
		bot:RemoveCallback(callbackId)
	end
end
local function removeTimers(timers)
	for _, timerId in pairs(timers) do
		print(timerId)
		timer.Stop(timerId)
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

local function fade()
	local fadeEnt = Entity("env_fade", true)
	local properties = {
		holdtime = 1,
		duration = 0.5,
		rendercolor = "255, 255, 255",
		renderamt = 255
	}

	for name, value in pairs(properties) do
		fadeEnt:AcceptInput("$SetKey$"..name, value)
	end

	fadeEnt.Fade(fadeEnt)

	timer.Simple(1, function ()
		fadeEnt:Remove()
	end)
end

local function revertRollback()
	fade()

	timer.Simple(0.6, function ()
		for ent, data in pairs(rollbacks) do
			if not IsValid(ent) or not ent:IsAlive() then
				goto continue
			end
	
			-- ent:SetAbsOrigin(data.Origin)
			-- ent:SetAbsAngles(data.Angles)
			ent:Teleport(data.Origin, data.Angles)
	
			::continue::
		end
	end)
end

local activeShieldOwners = {}
ents.AddCreateCallback("entity_medigun_shield", function (shield)
	if not timeconstraint_alive then
		return
	end

	timer.Simple(0.1, function()
		if shield.Registered then
			return
		end

		if shield.m_iTeamNum ~= 2 then
			return
		end

		local shieldOwner = shield.m_hOwnerEntity

		if not IsValid(shieldOwner) then
			return
		end

		local handle = shieldOwner:GetHandleIndex()

		if activeShieldOwners[handle] then
			return
		end

		activeShieldOwners[handle] = true

		chatMessage("Projectile Shield?")

		-- aaaaaaaaaaa
		timer.Simple(0.8, function()
			local empText = "{blue}"
			.. "Time-Constraint"
			.. "{reset} has used their {9BBF4D}EMP{reset} Power Up Canteen!"

			shieldOwner.m_flRageMeter = 0

			local allPlayers = ents.GetAllPlayers()

			for _, player in pairs(allPlayers) do
				player:AcceptInput("$DisplayTextChat", empText)
				player:AcceptInput("$PlaySoundToSelf", "=35|mvm/mvm_used_powerup.wav")
			end

			activeShieldOwners[handle] = nil

			timer.Simple(0.8, function()
				chatMessage("I don't think so")
			end)
		end)
	end)
end)

function OnWaveInit()
	timeconstraint_alive = false
end

local playersCallback = {}

local function Holder(bot)
	timeconstraint_alive = bot
	print(timeconstraint_alive)

	local allPlayers = ents.GetAllPlayers()

	for _, player in pairs(allPlayers) do
		if not player:IsRealPlayer() then
			goto continue
		end

		playersCallback[player] = {}
	
		playersCallback[player].died = player:AddCallback(ON_DEATH, function ()
			timeconstraint_alive = false

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
	local timers = {}

	storeRollback()

	local milkers = {}

	timers.milkCheck = timer.Create(0.1, function()
		if not timeconstraint_alive then
			removeCallbacks(bot, callbacks)
			removeTimers(timers)
		end

		if not cur_constraint or not cur_constraint:IsAlive() then
			return
		end

		local milker = cur_constraint:GetConditionProvider(TF_COND_MAD_MILK)

		if not milker then
			return
		end

		local secondary = milker:GetPlayerItemBySlot(LOADOUT_POSITION_SECONDARY)

		-- prevents mistaking mad milk syringes from mad milk
		if secondary.m_iClassname ~= "tf_weapon_jar_milk" then
			return
		end

		local handle = milker:GetHandleIndex()

		if milkers[handle] then
			return
		end

		milkers[handle] = true

		chatMessage("Are you seriously using mad milk?")

		timer.Simple(0.8, function ()
			chatMessage("Disgusting")
		end)
		timer.Simple(1.5, function ()
			chatMessage("Here, have a better weapon. You're welcome")
			milker:GiveItem("The Winger")
			milker:WeaponSwitchSlot(LOADOUT_POSITION_SECONDARY)

			milkers[handle] = nil
		end)

	end, 0)

	callbacks.died = bot:AddCallback(ON_DEATH, function()
		removeCallbacks(bot, callbacks)
		removeTimers(timers)

		for player, plrCallbacks in pairs(playersCallback) do
			removeCallbacks(player, plrCallbacks)
			removeTimers(timers)
		end
	end)
	callbacks.spawned = bot:AddCallback(ON_SPAWN, function()
		removeCallbacks(bot, callbacks)
		removeTimers(timers)

		for player, plrCallbacks in pairs(playersCallback) do
			removeCallbacks(player, plrCallbacks)
			removeTimers(timers)
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

local function Handle3(bot)
	local callbacks = {}

	storeRollback()

	chatMessage("You know what. I believe we need to have an equalizer")

	timer.Simple(1, function ()
		chatMessage("I'm taking away your money")

		for _, player in pairs(ents.GetAllPlayers()) do
			player:SetCurrency(-1000)
		end
	end)
	timer.Simple(3, function ()
		chatMessage("I'm taking away your canteens")
		for _, player in pairs(ents.GetAllPlayers()) do
			if not player:IsRealPlayer() then
				goto continue
			end

			local canteen = player:GetPlayerItemBySlot(LOADOUT_POSITION_ACTION)

			if not canteen then
				goto continue
			end

			canteen.m_usNumCharges = 0

			::continue::
		end
	end)
	timer.Simple(5, function ()
		chatMessage("Now I'm taking away your life. Go back to spawn")
		fade()
		timer.Simple(1, function ()
			for _, player in pairs(ents.GetAllPlayers()) do
				if not player:IsRealPlayer() then
					goto continue
				end

				player:ForceRespawn()

				::continue::
			end
			
		end)
	end)

	callbacks.died = bot:AddCallback(ON_DEATH, function()
		timer.Simple(0.5, function ()
			chatMessage("This is getting tiresome")
		end)

		timer.Simple(1.7, function ()
			chatMessage("I have an idea")
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

local function endWave()
	for _, player in pairs(ents.GetAllPlayers()) do
		if player.m_iTeamNum ~= 3 then
			goto continue
		end

		if not player:IsAlive() then
			goto continue
		end

		if player:IsRealPlayer() then
			goto continue
		end

		player:Suicide()

		::continue::
	end
end

local function PvPBluWin(bluPlayer)
	chatMessage("Masterfully done my dear friend")

	timer.Simple(1, function ()
		chatMessage("Let us enjoy this victory together")
	end)
	timer.Simple(2, function ()
		chatMessage("I hope your buddies aren't too mad at you after that")
	end)

	endWave()
end
local function PvPRedWin()
	chatMessage("How embarrassing")

	endWave()
end

local redPlayersAlive = 0
local function checkPvPWinCond(bluPlayer)
	if redPlayersAlive <= 0 then
		PvPBluWin(bluPlayer)
	end
end

local function HandleFinal(bot)
	local callbacks = {}

	storeRollback()

	chatMessage("Seeing as I myself am entirely unable to best you all")

	timer.Simple(1.5, function ()
		chatMessage("I have decided that, in order to create a fair matchup")
	end)
	timer.Simple(4, function ()
		chatMessage("You will be pitted against your best player")
	end)

	local chosenPlayer
	timer.Simple(6.5, function ()
		local text = "And that means you, %s"
		local bestPlayer = {nil, -100000}

		for _, player in pairs(ents.GetAllPlayers()) do
			if not player:IsRealPlayer() then
				goto continue
			end

			local dmg = player.m_iDamageDone

			if dmg >= bestPlayer[2] then
				bestPlayer = {player, dmg}
			end

			::continue::
		end

		chosenPlayer = bestPlayer[1]
		
		chatMessage(string.format(text, chosenPlayer:GetPlayerName()))
	end)
	timer.Simple(8, function ()
		chatMessage("Step right on up fella, you're on my side now")
		local spawn = ents.FindByName("timeconstraint_fast")
		local spawnPos = spawn:GetAbsOrigin() + Vector(0, 0, 10)

		chosenPlayer:Teleport(spawnPos)
		chosenPlayer:AddCond(TF_COND_REPROGRAMMED)

		chosenPlayer:SetAttributeValue("max health additive bonus", 5000)
		chosenPlayer:SetAttributeValue("cannot pick up intelligence", 1)

		chosenPlayer.m_bUseBossHealthBar = true

		local chosenPlrCallbacks = {}
		chosenPlrCallbacks.died = chosenPlayer:AddCallback(ON_DEATH, function ()
			PvPRedWin()

			removeCallbacks(chosenPlayer, chosenPlrCallbacks)
		end)
	end)
	timer.Simple(10, function ()
		chatMessage("Now give me a show. And don't even think about letting your former friends win intentionally. I will be watching")

		for _, player in pairs(ents.GetAllPlayers()) do
			if not player:IsRealPlayer() then
				goto continue
			end

			player.m_bGlowEnabled = 1
			player:SetAttributeValue("min respawn time", 999999)

			local text = player ~= chosenPlayer and
				"ELIMINATE BLU PLAYER TO WIN" or
				"ELIMINATE ALL RED PLAYERS TO WIN"


			player:Print(PRINT_TARGET_CENTER, text)

			if player == chosenPlayer then
				goto continue
			end

			redPlayersAlive = redPlayersAlive + 1

			local plrCallbacks = {}
			plrCallbacks.died = player:AddCallback(ON_DEATH, function ()
				redPlayersAlive = redPlayersAlive - 1

				checkPvPWinCond(chosenPlayer)

				removeCallbacks(player, plrCallbacks)
			end)

			::continue::
		end

		for _, door in pairs(ents.FindAllByName("func_door")) do
			door:Remove()
		end

		-- incase somehow 1 manned
		checkPvPWinCond(chosenPlayer)
	end)

	callbacks.died = bot:AddCallback(ON_DEATH, function()
		removeCallbacks(bot, callbacks)
	end)
	callbacks.spawned = bot:AddCallback(ON_SPAWN, function()
		removeCallbacks(bot, callbacks)
	end)
end

local function checkBot(bot, tags)
	if hasTag(tags, "realcontraint") then
		Holder(bot)
		return
	end
	if hasTag(tags, "timeconstraint1") then
		Handle1(bot)
		return true
	end
	if hasTag(tags, "timeconstraint2") then
		Handle2(bot)
		return true
	end
	if hasTag(tags, "timeconstraint3") then
		Handle3(bot)
		return true
	end
	if hasTag(tags, "timeconstraintFinal") then
		HandleFinal(bot)
		return true
	end
end

function OnWaveSpawnBot(bot, _, tags)
	local result = checkBot(bot, tags)

	if result then
		cur_constraint = bot
	end
end